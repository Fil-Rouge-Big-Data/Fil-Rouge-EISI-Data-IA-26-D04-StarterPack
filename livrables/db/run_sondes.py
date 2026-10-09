#!/usr/bin/env python3
"""Batterie de SONDES — teste que le schéma REFUSE ce qu'il doit refuser.

Différence avec run_tests.py : une sonde envoie une opération *interdite* et
vérifie qu'elle est rejetée PAR LA BONNE CONTRAINTE (SQLSTATE + nom). C'est le
harnais probant demandé par la revue (B5) : un rejet « par accident » (mauvaise
colonne, autre contrainte) compte comme un ÉCHEC.

Chaque sonde : (description, SQL, contrainte_attendue). On exécute dans une
transaction annulée (ROLLBACK), on capture l'erreur, et on vérifie que le nom
de contrainte violé correspond à l'attendu.

Usage : PGHOST=... PGPORT=... python run_sondes.py
"""
import os
import sys

import psycopg
from psycopg import errors

# Chaque sonde : (ref, description, sql_setup_puis_violation, contrainte_attendue)
# Le SQL doit finir par l'opération qui DOIT échouer. Les préalables valides
# sont inclus avant. 'contrainte' = nom attendu dans le diagnostic.

# HERMÉTICITÉ : les barèmes créés par les sondes sont datés de l'an 2000. Un barème par défaut de 2025+
# chevaucherait celui du jeu de test (03_seed.sql) et ferait échouer la sonde pour une mauvaise raison.
PREAMBULE = """
INSERT INTO utilisateur (id_utilisateur,nom,prenom,email,password_hash) VALUES
 ('5a000000-0000-0000-0000-000000000001','Ch','Sonde','ch.sonde@x.fr','x'),
 ('5a000000-0000-0000-0000-000000000002','Cl','Sonde','cl.sonde@x.fr','x'),
 ('5a000000-0000-0000-0000-000000000003','Ge','Sonde','ge.sonde@x.fr','x');
INSERT INTO chasseur (id_utilisateur,type_habilitation,numero_habilitation,date_validite_habilitation,
  organisme_delivrance,organisme_garant,montant_garantie_financiere,numero_rcp,date_echeance_rcp,
  statut_juridique,date_entree_reseau,capacite_max_mandats) VALUES
 ('5a000000-0000-0000-0000-000000000001','attestation','ATT-S','2030-01-01','CCI','G',120000,'R','2030-01-01','salarie','2024-01-01',15);
INSERT INTO client (id_utilisateur) VALUES ('5a000000-0000-0000-0000-000000000002');
INSERT INTO gestionnaire (id_utilisateur,matricule,date_entree_fonction,capacite_max_leads)
 VALUES ('5a000000-0000-0000-0000-000000000003','GS','2024-01-01',50);
INSERT INTO demande (id_demande,id_gestionnaire,date_depot,canal) VALUES
 ('5d000000-0000-0000-0000-000000000001','5a000000-0000-0000-0000-000000000003','2025-01-01','autre');
INSERT INTO demande_acquereur (id_demande,id_client,qualite) VALUES
 ('5d000000-0000-0000-0000-000000000001','5a000000-0000-0000-0000-000000000002','principal');
INSERT INTO demande_version (id_version,id_demande,id_modifie_par,no_version,date_creation,motif_evolution,type_bien,destination,budget_max)
 VALUES ('5e000000-0000-0000-0000-000000000001','5d000000-0000-0000-0000-000000000001','5a000000-0000-0000-0000-000000000002',1,'2025-01-02','initiale','appartement','principale',320000);
INSERT INTO mandat (id_mandat,id_demande,id_version_contractuelle,id_chasseur,id_signataire,numero_registre,
  date_signature,mode_signature,date_debut,exclusif,taux_honoraires,base_honoraires,taux_tva,qualite_signataire) VALUES
 ('5f000000-0000-0000-0000-000000000001','5d000000-0000-0000-0000-000000000001','5e000000-0000-0000-0000-000000000001',
  '5a000000-0000-0000-0000-000000000001','5a000000-0000-0000-0000-000000000002','REG-S1','2025-02-01','presentiel','2025-02-01',true,3.0,'TTC',20.0,'nom_propre');
"""

# Chaîne de vente jusqu'au compromis (offre acceptée -> compromis), partagée par les sondes
# qui ont besoin d'un acte. Préfixée par PREAMBULE à l'exécution.
CHAINE_ACTE = """
INSERT INTO zone (id_zone,type_zone,pays,code_iso_pays,devise,ville,code_insee,code_postal) VALUES
 ('5b000000-0000-0000-0000-000000000001','ville','France','FR','EUR','Sondeville','34172','34000');
INSERT INTO bien (id_bien,id_zone,type_bien) VALUES
 ('5b000000-0000-0000-0000-000000000002','5b000000-0000-0000-0000-000000000001','appartement');
INSERT INTO annonce (id_annonce,id_bien,source,reference_source,prix,date_ingestion,date_derniere_vue,statut) VALUES
 ('5b000000-0000-0000-0000-000000000003','5b000000-0000-0000-0000-000000000002','agence','RS',300000,'2025-03-01','2025-03-01','active');
INSERT INTO proposition (id_proposition,id_demande,id_version,id_bien,id_annonce_reference,id_mandat,date_matching,statut) VALUES
 ('5b000000-0000-0000-0000-000000000004','5d000000-0000-0000-0000-000000000001','5e000000-0000-0000-0000-000000000001',
  '5b000000-0000-0000-0000-000000000002','5b000000-0000-0000-0000-000000000003','5f000000-0000-0000-0000-000000000001','2025-03-02','soumis');
INSERT INTO offre_acquisition (id_offre,id_proposition,camp,saisi_par,montant,date_signature,date_validite,date_reponse,statut) VALUES
 ('5b000000-0000-0000-0000-000000000005','5b000000-0000-0000-0000-000000000004','acquereur','client',300000,'2025-03-10','2025-03-20','2025-03-12','acceptee');
INSERT INTO notaire (id_notaire,nom,etude) VALUES ('5b000000-0000-0000-0000-000000000006','N','E');
INSERT INTO compromis (id_compromis,id_offre,id_notaire,date_signature,fin_retractation) VALUES
 ('5c000000-0000-0000-0000-000000000001','5b000000-0000-0000-0000-000000000005','5b000000-0000-0000-0000-000000000006','2025-04-01','2025-04-11');
"""

# Rémunération complète valide SAUF le taux_final, injecté via {TAUX} (test aux limites).
CHAINE_REMU = CHAINE_ACTE + """
INSERT INTO acte (id_acte,id_compromis,date_signature,montant_vente,honoraires_fixe,honoraires_encaisses,date_encaissement) VALUES
 ('5c000000-0000-0000-0000-000000000002','5c000000-0000-0000-0000-000000000001','2025-05-01',300000,9000,true,'2025-05-05');
INSERT INTO bareme (id_bareme,date_debut_vigueur,date_fin_vigueur) VALUES ('5c000000-0000-0000-0000-000000000003','2000-01-01','2000-12-31');
INSERT INTO remuneration_chasseur (id_acte,id_chasseur,id_mandat,honoraires,
  score_delai,score_exclusivite,score_ventes,score_mandats,score_visites,score_performance,
  taux_base,majoration_anciennete,modulation_performance,taux_final,montant,id_bareme_applique) VALUES
 ('5c000000-0000-0000-0000-000000000002','5a000000-0000-0000-0000-000000000001','5f000000-0000-0000-0000-000000000001',
  9000,80,100,85,70,90,82,45,5,1.0,{TAUX},4000,'5c000000-0000-0000-0000-000000000003');
"""

SONDES = [
    # Règle de l'art : la sonde monte son jeu de données (PREAMBULE) puis tente l'interdit ;
    # tout est annulé à la fin. Plus de sonde « à helper » inactive.
    # (réf, description, SQL, contrainte attendue, avec_donnees)
    ("S9", "mandat son propre précédent",
     "UPDATE mandat SET id_mandat_precedent = id_mandat "
     "WHERE id_mandat='5f000000-0000-0000-0000-000000000001';",
     # Défense en profondeur : un mandat son propre précédent a un écart de 0 < 6 mois,
     # donc le trigger de succession (ADR-048) peut sauter AVANT le CHECK. Les deux
     # protections sont légitimes : la sonde exige un rejet par l'une OU l'autre.
     ("ck_mandat_pas_auto_precedent", "trigger:tg_mandat_succession"), True),

    ("S5", "deux tranches de barème qui se chevauchent",
     """
     WITH b AS (INSERT INTO bareme (date_debut_vigueur,date_fin_vigueur) VALUES ('2000-01-01','2000-12-31') RETURNING id_bareme),
     t1 AS (INSERT INTO tranche_bareme (id_bareme,montant_min,montant_max,taux_base)
            SELECT id_bareme,0,200000,40 FROM b RETURNING id_bareme)
     INSERT INTO tranche_bareme (id_bareme,montant_min,montant_max,taux_base)
     SELECT id_bareme,100000,300000,45 FROM t1;
     """, "ex_tranche_chevauchement"),

    ("S6", "deux barèmes par défaut en vigueur simultanée",
     """
     INSERT INTO bareme (id_chasseur,date_debut_vigueur,date_fin_vigueur) VALUES (NULL,'2000-01-01','2000-12-31');
     INSERT INTO bareme (id_chasseur,date_debut_vigueur,date_fin_vigueur) VALUES (NULL,'2000-06-01','2001-06-01');
     """, "ex_bareme_vigueur"),

    ("B3b", "tranche à bornes inversées",
     """
     WITH b AS (INSERT INTO bareme (date_debut_vigueur,date_fin_vigueur) VALUES ('2000-01-01','2000-12-31') RETURNING id_bareme)
     INSERT INTO tranche_bareme (id_bareme,montant_min,montant_max,taux_base)
     SELECT id_bareme,300000,100000,40 FROM b;
     """, "ck_tranche_bornes"),

    ("D1", "chasseur salarié avec carte T (doit être attestation)",
     """
     WITH u AS (INSERT INTO utilisateur (nom,prenom,email,password_hash,date_creation)
                VALUES ('S','H','sh@x.fr','x','2024-01-01') RETURNING id_utilisateur)
     INSERT INTO chasseur (id_utilisateur,type_habilitation,numero_habilitation,
       date_validite_habilitation,organisme_delivrance,organisme_garant,
       montant_garantie_financiere,numero_rcp,date_echeance_rcp,statut_juridique,
       date_entree_reseau,capacite_max_mandats)
     SELECT id_utilisateur,'carte_t','CT','2027-01-01','CCI','G',120000,'RCP','2027-01-01',
       'salarie','2024-01-01',15 FROM u;
     """, "ck_chasseur_habilitation"),

    ("D2", "auto-parrainage (parrain = filleul)",
     """
     WITH u AS (INSERT INTO utilisateur (nom,prenom,email,password_hash,date_creation)
                VALUES ('P','F','pf@x.fr','x','2024-01-01') RETURNING id_utilisateur)
     INSERT INTO parrainage (id_parrain,id_filleul,filleul_nom,filleul_prenom,
       type_contrat,date_declaration,date_fin_validite,statut)
     SELECT id_utilisateur,id_utilisateur,'X','Y','vente','2026-01-01','2027-01-01','declare' FROM u;
     """, "ck_parrainage_pas_auto"),

    # D2b : parrainage 'retribue' AVEC mandat concrétisé (ck_parrainage_concret
    # satisfaite) mais SANS RIB/versement -> doit violer ck_parrainage_retribue.
    # Nécessite un mandat réel -> sonde à helper (voir run_sondes avec données).
    ("D2b", "parrainage rétribué sans RIB ni versement",
     "INSERT INTO parrainage (id_parrain,filleul_nom,filleul_prenom,type_contrat,"
     "date_declaration,date_fin_validite,statut,id_mandat_concretise) VALUES "
     "('5a000000-0000-0000-0000-000000000002','X','Y','vente','2026-01-01','2027-01-01',"
     "'retribue','5f000000-0000-0000-0000-000000000001');",
     "ck_parrainage_retribue", True),

    ("Acte", "acte avec encaissement mais sans date",
     CHAINE_ACTE + "INSERT INTO acte (id_compromis,date_signature,montant_vente,honoraires_fixe,"
     "honoraires_encaisses) VALUES ('5c000000-0000-0000-0000-000000000001','2025-08-01',300000,5000,true);",
     "ck_acte_encaissement", True),

    # P-B (règle de l'art : TEST AUX LIMITES d'une borne) : taux_final borné [20,60].
    # On teste les 2 valeurs juste HORS borne (19.99 et 60.01) -> doivent être rejetées.
    # Les valeurs juste DANS la borne (20 et 60) sont vérifiées en scénarios valides
    # (voir run_tests.py) pour prouver que la borne n'est pas trop stricte.
    ("P-B1", "taux_final 19.99 (juste sous la borne 20)",
     CHAINE_REMU.replace("{TAUX}", "19.99"),
     "remuneration_chasseur_taux_final_check", True),
    ("P-B2", "taux_final 60.01 (juste au-dessus de la borne 60)",
     CHAINE_REMU.replace("{TAUX}", "60.01"),
     "remuneration_chasseur_taux_final_check", True),
]


def run_sonde(conn, ref, desc, sql, contrainte, avec_donnees=False):
    """Retourne (ok, message). Si avec_donnees, le jeu de données PREAMBULE est monté
    dans la même transaction (tout est annulé : la sonde doit échouer sur l'interdit)."""
    if sql is None:
        return None, "sonde sans SQL"
    if avec_donnees:
        sql = PREAMBULE + sql
    try:
        with conn.transaction():
            conn.execute(sql)
        return False, f"AUCUN rejet (l'opération interdite est passée !)"
    except psycopg.errors.Error as e:
        nom = getattr(e.diag, "constraint_name", None)
        attendues = contrainte if isinstance(contrainte, tuple) else (contrainte,)
        if nom in attendues:
            return True, f"rejeté par {nom}"
        # trigger métier : RAISE EXCEPTION (SQLSTATE P0001), sans nom de contrainte
        if any(a.startswith("trigger:") for a in attendues) and getattr(e, "sqlstate", "") == "P0001":
            return True, "rejeté par un trigger métier (RAISE)"
        return False, f"rejeté par '{nom}' au lieu de {attendues}"



# P-B (règle de l'art) : la borne ne doit pas être TROP stricte. Les valeurs EXACTEMENT
# sur la borne (20 et 60) doivent être ACCEPTÉES. Test miroir des sondes P-B1/P-B2.
ACCEPTATIONS = [
    ("P-B3", "taux_final 20.00 (borne basse incluse)", CHAINE_REMU.replace("{TAUX}", "20.0")),
    ("P-B4", "taux_final 60.00 (borne haute incluse)", CHAINE_REMU.replace("{TAUX}", "60.0")),
]


def run_acceptation(conn, ref, desc, sql):
    """Une écriture VALIDE aux limites doit passer (puis on annule). Retourne (ok, msg)."""
    try:
        with conn.transaction():
            conn.execute(PREAMBULE + sql)
            raise _Annule()          # succès -> on annule volontairement
    except _Annule:
        return True, "accepté (aux limites)"
    except psycopg.errors.Error as e:
        return False, f"REJETÉ à tort : {str(e).splitlines()[0][:70]}"


class _Annule(Exception):
    pass


def main():
    dsn = dict(
        host=os.environ.get("PGHOST", "127.0.0.1"),
        port=os.environ.get("PGPORT", "5433"),
        user=os.environ.get("PGUSER", "chasse_migration"),
        dbname=os.environ.get("PGDATABASE", "chasse_v8"),
    )
    conn = psycopg.connect(**dsn, autocommit=False)
    ok = ko = skip = 0
    print("=" * 70)
    print("SONDES — chaque opération interdite DOIT être rejetée par sa contrainte")
    print("=" * 70)
    for entree in SONDES:
        # format (réf, desc, sql, contrainte[, avec_donnees]) : 4e/5e éléments optionnels
        ref, desc, sql, contrainte = entree[:4]
        avec_donnees = entree[4] if len(entree) > 4 else False
        res, msg = run_sonde(conn, ref, desc, sql, contrainte, avec_donnees)
        if res is None:
            skip += 1
            print(f"  [SKIP] {ref:5} {desc:48} ({msg})")
        elif res:
            ok += 1
            print(f"  [OK  ] {ref:5} {desc:48} {msg}")
        else:
            ko += 1
            print(f"  [FAIL] {ref:5} {desc:48} {msg}")
    print("-" * 70)
    print("ACCEPTATIONS aux limites (une valeur valide DOIT passer)")
    for ref, desc, sql in ACCEPTATIONS:
        res, msg = run_acceptation(conn, ref, desc, sql)
        if res:
            ok += 1
            print(f"  [OK  ] {ref:5} {desc:48} {msg}")
        else:
            ko += 1
            print(f"  [FAIL] {ref:5} {desc:48} {msg}")
    print("=" * 70)
    print(f"SONDES : {ok} fermées / {ko} ouvertes (défauts) / {skip} à helper")
    print("=" * 70)
    conn.close()
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
