#!/usr/bin/env python3
"""Job d'anonymisation RGPD (ADR-043).

Anonymise — par UPDATE, jamais DELETE — les clients arrivés à échéance de
conservation, en routant selon leur catégorie :

  - prospect non client        : aucune demande      -> 3 ans après date_creation
  - client avec relation       : demandes, pas d'acte -> 3 ans après dernière activité
  - client avec transaction    : au moins un acte     -> conservation légale longue
                                                         (non anonymisé avant échéance)

« Anonymiser » = remplacer les données identifiantes (nom, prénom, email,
téléphone, password) par des valeurs neutres, poser actif=false et
date_anonymisation=now(). La ligne et son historique métier restent (stats, IA).

Idempotent : ne traite que les lignes où date_anonymisation IS NULL.
Le compte technique SYS-MIGRATION est toujours exclu.

Usage :
    python anonymiser.py --dry-run          # montre qui serait anonymisé, n'écrit rien
    python anonymiser.py                     # exécute
    python anonymiser.py --date-ref 2026-07-25 --seuil-ans 3
"""
from __future__ import annotations

import argparse
import os
import sys
from datetime import date, datetime, timezone

import psycopg

GESTIONNAIRE_MATRICULE_EXCLU = "SYS-MIGRATION"

# Requête de classement : pour chaque client, sa catégorie et sa date de référence
# (dernière activité connue). Un client « transactionnel » est repéré par la
# présence d'au moins un acte rattaché à l'une de ses demandes.
SQL_CANDIDATS = """
WITH acte_client AS (  -- clients ayant au moins un acte signé (chaîne acte->...->demande)
    SELECT DISTINCT da.id_client
    FROM acte a
    JOIN compromis co        ON co.id_compromis = a.id_compromis
    JOIN offre_acquisition o ON o.id_offre = co.id_offre
    JOIN proposition p       ON p.id_proposition = o.id_proposition
    JOIN demande_acquereur da ON da.id_demande = p.id_demande
),
activite AS (  -- S18 : dernière activité RÉELLE = max des dates de demande ET de mandat.
    SELECT id_client, max(dt) AS derniere_activite FROM (
        SELECT da.id_client, d.date_depot AS dt
          FROM demande_acquereur da JOIN demande d ON d.id_demande = da.id_demande
        UNION ALL
        SELECT m.id_signataire AS id_client, m.date_debut AS dt
          FROM mandat m
        UNION ALL  -- un mandat résilié borne la fin de relation à sa date de résiliation
        SELECT m.id_signataire, m.date_resiliation
          FROM mandat m WHERE m.date_resiliation IS NOT NULL
        UNION ALL  -- v8.4 : une VISITE récente = client actif
        SELECT da.id_client, v.date_visite::timestamptz
          FROM visite v JOIN proposition p ON p.id_proposition = v.id_proposition
          JOIN demande_acquereur da ON da.id_demande = p.id_demande
        UNION ALL  -- v8.4 : une OFFRE récente = client actif
        SELECT da.id_client, o.date_signature::timestamptz
          FROM offre_acquisition o JOIN proposition p ON p.id_proposition = o.id_proposition
          JOIN demande_acquereur da ON da.id_demande = p.id_demande
    ) x WHERE id_client IS NOT NULL GROUP BY id_client
)
SELECT
    u.id_utilisateur,
    u.nom, u.prenom, u.email,
    CASE
        WHEN ac.id_client IS NOT NULL THEN 'transactionnel'
        WHEN act.id_client IS NOT NULL THEN 'client_relation'
        ELSE 'prospect'
    END AS categorie,
    COALESCE(act.derniere_activite, u.date_creation) AS date_reference
FROM utilisateur u
JOIN client c       ON c.id_utilisateur = u.id_utilisateur
LEFT JOIN activite act   ON act.id_client = u.id_utilisateur
LEFT JOIN acte_client ac ON ac.id_client = u.id_utilisateur
WHERE u.date_anonymisation IS NULL           -- idempotence
  -- P-F (v8.41) : PAS de filtre actif=true. Un compte déjà désactivé (ex. hérité de
  -- la migration) mais jamais anonymisé doit aussi être traité à échéance, sinon ses
  -- données personnelles persistent indéfiniment (non-conformité RGPD). Les gardes
  -- ci-dessous (acteurs internes, mandat actif) restent le filet de sécurité.
  -- S17 : ne JAMAIS anonymiser une personne qui est aussi un acteur interne.
  AND NOT EXISTS (SELECT 1 FROM gestionnaire g WHERE g.id_utilisateur = u.id_utilisateur)
  AND NOT EXISTS (SELECT 1 FROM chasseur ch
                  WHERE ch.id_utilisateur = u.id_utilisateur
                    AND ch.date_sortie_reseau IS NULL)   -- chasseur encore en réseau
  -- S18 bis : ni un client ayant un mandat ACTIF en cours (ADR-048 : état calculé).
  AND NOT EXISTS (SELECT 1 FROM v_mandat m
                  WHERE m.id_signataire = u.id_utilisateur
                    AND m.statut_calcule = 'actif');
"""

# Anonymisation : neutralise les données identifiantes, conserve la ligne.
SQL_ANONYMISER = """
UPDATE utilisateur SET
    nom = 'ANONYMISE',
    prenom = 'ANONYMISE',
    email = 'anon+' || id_utilisateur || '@anonymise.invalid',
    telephone = NULL,
    password_hash = '!anonymised',
    actif = false,
    date_anonymisation = %(now)s
WHERE id_utilisateur = %(id)s
  AND date_anonymisation IS NULL;
"""


def _conn() -> psycopg.Connection:
    return psycopg.connect(
        host=os.environ.get("DST_PGHOST", "127.0.0.1"),
        port=os.environ.get("DST_PGPORT", "5433"),
        user=os.environ.get("DST_PGUSER", "chasse_migration"),
        dbname=os.environ.get("DST_PGDATABASE", "chasse_v8"),
        password=os.environ.get("DST_PGPASSWORD", ""),
        autocommit=False,
    )


def annees_entre(debut: date, fin: date) -> float:
    return (fin - debut).days / 365.25


def selectionner(conn, date_ref: date, seuil_ans: int):
    """Renvoie (a_anonymiser, conserves) selon les règles ADR-043."""
    a_anonymiser, conserves = [], []
    with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
        cur.execute(SQL_CANDIDATS)
        for r in cur.fetchall():
            cat = r["categorie"]
            ref = r["date_reference"]
            ref_date = ref.date() if isinstance(ref, datetime) else ref
            age = annees_entre(ref_date, date_ref)
            if cat == "transactionnel":
                # conservation légale longue : hors périmètre de ce job
                # (une échéance légale distincte, à valider juridiquement)
                conserves.append((r, cat, age, "conservation légale (acte signé)"))
            elif age >= seuil_ans:
                a_anonymiser.append((r, cat, age))
            else:
                conserves.append((r, cat, age, f"{age:.1f} ans < seuil {seuil_ans}"))
    return a_anonymiser, conserves


def main(argv=None):
    ap = argparse.ArgumentParser(description="Anonymisation RGPD (ADR-043)")
    ap.add_argument("--dry-run", action="store_true", help="n'écrit rien")
    ap.add_argument("--date-ref", default=None,
                    help="date de référence (défaut: aujourd'hui), format YYYY-MM-DD")
    ap.add_argument("--seuil-ans", type=int, default=3,
                    help="seuil de conservation en années (défaut 3)")
    args = ap.parse_args(argv)

    date_ref = (datetime.strptime(args.date_ref, "%Y-%m-%d").date()
                if args.date_ref else date.today())
    now = datetime.now(timezone.utc)

    with _conn() as conn:
        a_anon, conserves = selectionner(conn, date_ref, args.seuil_ans)

        print(f"[anonymisation RGPD] date_ref={date_ref} seuil={args.seuil_ans} ans")
        print(f"  candidats à anonymiser : {len(a_anon)}")
        print(f"  conservés              : {len(conserves)}")
        for r, cat, age in a_anon:
            print(f"    - {r['prenom']} {r['nom']} [{cat}] inactif {age:.1f} ans")

        if args.dry_run:
            print("  (DRY-RUN : aucune écriture)")
            return 0

        n = 0
        with conn.cursor() as cur:
            for r, cat, age in a_anon:
                cur.execute(SQL_ANONYMISER, {"id": r["id_utilisateur"], "now": now})
                n += cur.rowcount
        conn.commit()
        print(f"  [OK] {n} client(s) anonymisé(s).")
        return 0


if __name__ == "__main__":
    sys.exit(main())
