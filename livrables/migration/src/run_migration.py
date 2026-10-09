#!/usr/bin/env python3
"""Orchestrateur de la migration Existant -> OLTP cible v7.

Pipeline E-T-L-V idempotent :
  [E] Extract   : lecture de la base source (schéma hérité), sans la modifier.
  [T] Transform : mapping en mémoire (UUID déterministe, parsing critères,
                  décisions de comblement et d'arbitrage).
  [L] Load      : écriture dans l'OLTP v7 en une transaction, ON CONFLICT
                  DO NOTHING (rejouer = même état).
  [V] Validate  : contrôles délégués à validate.py / tests.

Configuration par variables d'environnement PostgreSQL standard, préfixées
SRC_ (source) et DST_ (cible). Voir .env.example.

Usage :
    python -m src.run_migration --source historique
    python -m src.run_migration --source historique --dry-run
"""
from __future__ import annotations

import argparse
import os
import sys
from datetime import date, datetime, timezone

import psycopg

# Import robuste : que le module soit lancé via -m src.run_migration
# (package) ou directement depuis le dossier src/.
try:
    from .mapping import parse_criteres, uuid5_for, classifier_statut_source
except ImportError:  # exécution directe
    from mapping import parse_criteres, uuid5_for, classifier_statut_source

# --------------------------------------------------------------------------
# Registre des codes anomalies (aligné sur docs/mapping-donnees.md et
# docs/arbitrages-migration.md). Un code = une catégorie de décision tracée.
# --------------------------------------------------------------------------
CODES_ANOMALIE = {
    "A02": "Mentions légales chasseur absentes -> sentinelles à régulariser (D3/A2)",
    "A03": "Attribut déduit du texte libre (ex. primo-accédant) — réversible (A10)",
    "A04": "Statut mandat requalifié (suspendu -> resilie motivé) (A8)",
    "A06": "client_id pointant un chasseur -> reclassé vers un client (A4)",
    "A07": "code INSEE enrichi depuis un référentiel externe (non issu des données)",
    "T2":  "password_hash absent -> sentinelle, reset au 1er login (RGPD)",
}

# --------------------------------------------------------------------------
# Constantes de comblement (arbitrages — voir docs/arbitrages-migration.md)
# --------------------------------------------------------------------------
SENTINELLE_PASSWORD = "!migrated:no-auth"            # T2
SENTINELLE_TEXTE = "A_REGULARISER"                   # D3
DATE_SENTINELLE = date(2000, 1, 1)                   # D3 (ressort "expiré")
GESTIONNAIRE_MATRICULE = "SYS-MIGRATION"             # A1 / D-ROOT
GESTIONNAIRE_EMAIL = "sys-migration@interne.invalid"

# UUID du gestionnaire root (déterministe, cf. T1)
ID_GESTIONNAIRE_ROOT = uuid5_for("gestionnaire", GESTIONNAIRE_MATRICULE)

# Correction A06 : mandat dont client_id=3 (une chasseuse) -> client 19.
def _charger_config_source(source: str) -> dict:
    """M7 : lit config/sources.yml pour la source donnée (correction A06, etc.)."""
    import yaml
    import pathlib
    cfg_path = pathlib.Path(__file__).resolve().parents[1] / "config" / "sources.yml"
    try:
        with open(cfg_path, encoding="utf-8") as f:
            cfg = yaml.safe_load(f)
        src_cfg = (cfg.get("sources") or {}).get(source, {}) or {}
        # YAML peut rendre les clés en str ; on normalise en int.
        raw = src_cfg.get("correction_a06", {}) or {}
        return {int(k): int(v) for k, v in raw.items()}
    except FileNotFoundError:
        return {}


def _conn(prefix: str) -> psycopg.Connection:
    """Connexion à partir des variables d'env préfixées (SRC_ ou DST_)."""
    return psycopg.connect(
        host=os.environ.get(f"{prefix}_PGHOST", "127.0.0.1"),
        port=os.environ.get(f"{prefix}_PGPORT", "5433"),
        user=os.environ.get(f"{prefix}_PGUSER", "chasse_migration"),
        dbname=os.environ.get(f"{prefix}_PGDATABASE", "chasse_v8"),
        password=os.environ.get(f"{prefix}_PGPASSWORD", ""),
        autocommit=False,
    )


# ==========================================================================
# [E] EXTRACT
# ==========================================================================
def extract(src: psycopg.Connection) -> dict:
    """Lit la source telle quelle. Renvoie des listes de dicts."""
    src.execute('SET search_path TO "Fil_Rouge_Depart"')
    out = {}
    with src.cursor(row_factory=psycopg.rows.dict_row) as cur:
        cur.execute("SELECT id, ville, quartier, code_postal FROM secteurs ORDER BY id")
        out["secteurs"] = cur.fetchall()
        cur.execute("SELECT id, nom, prenom, email, telephone, role, ville, "
                    "budget_max, taux_commission, date_creation "
                    "FROM utilisateurs ORDER BY id")
        out["utilisateurs"] = cur.fetchall()
        cur.execute("SELECT id, client_id, chasseur_id, secteur_id, exclusif, "
                    "date_debut, statut, description_recherche "
                    "FROM mandats ORDER BY id")
        out["mandats"] = cur.fetchall()
    return out


# ==========================================================================
# [T] TRANSFORM  (+ anomalies collectées au passage)
# ==========================================================================
class Transform:
    def __init__(self, source_label: str):
        self.source = source_label
        self.correction_a06 = _charger_config_source(source_label)  # M7 : depuis sources.yml
        self.anomalies: list[dict] = []
        self.etats_repris: list[dict] = []        # ADR-048 : lignes mandat_etat origine=repris
        self.mandat_courant: dict[str, str] = {}  # ADR-048 : id_demande -> id_mandat courant
        # index id_source -> uuid, par entité, pour recomposer les FK
        self.uid_util: dict[int, str] = {}
        self.uid_zone: dict[int, str] = {}
        self.uid_demande: dict[int, str] = {}
        self.uid_version: dict[int, str] = {}

    def _anomalie(self, entite, id_cible, code, motif, sentinelle=None):
        self.anomalies.append(dict(source=self.source, entite_cible=entite,
                                   id_cible=id_cible, code_anomalie=code,
                                   motif=motif, valeur_sentinelle=sentinelle))

    # --- zones ---------------------------------------------------------
    def zones(self, secteurs):
        rows = []
        for s in secteurs:
            key = f"France|{s['ville']}|{s['quartier'] or ''}"
            uid = uuid5_for("zone", key)
            self.uid_zone[s["id"]] = uid
            type_zone = "secteur" if s["quartier"] else "ville"
            rows.append(dict(
                id_zone=uid, type_zone=type_zone, pays="France",
                code_iso_pays="FR", devise="EUR", ville=s["ville"],
                code_insee=self._insee(s), secteur=s["quartier"],
                code_postal=s["code_postal"],
            ))
        return rows

    def _insee(self, s):
        # Référentiel externe minimal (A07). En production : table COG complète.
        # Ici, dérivation depuis le code postal pour l'Hérault (34) du jeu de test.
        insee = _INSEE_REF.get((s["ville"], s["code_postal"]))
        if insee is None:
            self._anomalie("zone", self.uid_zone.get(s["id"]), "A07",
                           f"INSEE absent du référentiel pour {s['ville']} {s['code_postal']}",
                           None)
        return insee

    # --- utilisateurs / clients / chasseurs ----------------------------
    def acteurs(self, utilisateurs):
        util, clients, chasseurs = [], [], []
        for u in utilisateurs:
            uid = uuid5_for("utilisateur", u["email"])
            self.uid_util[u["id"]] = uid
            util.append(dict(
                id_utilisateur=uid, nom=u["nom"], prenom=u["prenom"],
                email=u["email"], telephone=u["telephone"],
                password_hash=SENTINELLE_PASSWORD,
                date_creation=datetime.combine(u["date_creation"],
                                               datetime.min.time(), timezone.utc),
                actif=True,
            ))
            self._anomalie("utilisateur", uid, "T2",
                           "password_hash absent -> sentinelle, reset au 1er login",
                           SENTINELLE_PASSWORD)
            if u["role"] == "chasseur":
                chasseurs.append(self._chasseur(u, uid))
            else:
                clients.append(dict(
                    id_utilisateur=uid, primo_accedant=False,
                    consentement_marketing=False, niveau_vigilance="standard",
                ))
        return util, clients, chasseurs

    def _chasseur(self, u, uid):
        # 9 colonnes légales sans source -> sentinelles remontées (D3 / A2).
        self._anomalie("chasseur", uid, "A02",
                       "Mentions légales chasseur absentes -> sentinelles à régulariser",
                       SENTINELLE_TEXTE)
        return dict(
            id_utilisateur=uid,
            # D1 (v8.2) : modèle habilitation. salarié -> attestation (ck_chasseur_habilitation).
            type_habilitation="attestation",
            numero_habilitation=f"{SENTINELLE_TEXTE}-{uid[:8]}",
            date_validite_habilitation=DATE_SENTINELLE,
            organisme_delivrance=SENTINELLE_TEXTE,
            organisme_garant=SENTINELLE_TEXTE,
            montant_garantie_financiere=0.01,
            numero_rcp=f"{SENTINELLE_TEXTE}-{uid[:8]}",
            date_echeance_rcp=DATE_SENTINELLE,
            statut_juridique="salarie",              # A3
            date_entree_reseau=u["date_creation"],
            capacite_max_mandats=15,
            taux_honoraires_defaut=u["taux_commission"],
        )

    def gestionnaire_root(self):
        """Acteur technique SYS-MIGRATION (A1 / D-ROOT)."""
        util = dict(
            id_utilisateur=ID_GESTIONNAIRE_ROOT, nom="SYSTEME", prenom="Migration",
            email=GESTIONNAIRE_EMAIL, telephone=None,
            password_hash=SENTINELLE_PASSWORD,
            date_creation=datetime.now(timezone.utc), actif=False,
        )
        gest = dict(
            id_utilisateur=ID_GESTIONNAIRE_ROOT, matricule=GESTIONNAIRE_MATRICULE,
            date_entree_fonction=date.today(), capacite_max_leads=32767,
        )
        return util, gest

    # --- demandes / versions / acquéreurs / mandats --------------------
    def mandats(self, mandats):
        demandes, acquereurs, versions, version_zones, mandat_rows = [], [], [], [], []
        for m in mandats:
            # M1/ADR-050 : les id source sont LOCAUX à chaque source. On préfixe par
            # la source pour éviter les collisions entre rachats (agence A mandat id=1
            # vs agence B mandat id=1). Les clés globales (email, géo) ne sont PAS préfixées.
            id_demande = uuid5_for("demande", f"{self.source}:{m['id']}")
            id_version = uuid5_for("version", f"{self.source}:{m['id']}")
            self.uid_demande[m["id"]] = id_demande
            self.uid_version[m["id"]] = id_version

            # correction A06 : client_id pointant un chasseur (M7 : config YAML)
            client_src = m["client_id"]
            if client_src in self.correction_a06:
                corrige = self.correction_a06[client_src]
                self._anomalie("demande_acquereur", id_demande, "A06",
                               f"client_id={client_src} (un chasseur) reclassé -> client {corrige}",
                               str(corrige))
                client_src = corrige
            id_client = self.uid_util[client_src]
            id_chasseur = self.uid_util[m["chasseur_id"]]

            # demande (portée par le gestionnaire root — A1)
            # P-C : le canal réel de la demande n'a pas de réceptacle fiable en source
            # (mandats papier historiques) -> 'autre', tracé A10b (promis au mapping).
            self._anomalie("demande", id_demande, "A10b",
                           "canal réel inconnu (source sans réceptacle) -> 'autre'")
            demandes.append(dict(
                id_demande=id_demande, id_gestionnaire=ID_GESTIONNAIRE_ROOT,
                id_chasseur=id_chasseur, date_depot=m["date_debut"],
                canal="autre", nb_relances=0,
                date_affectation=m["date_debut"],  # ADR-048 : fait (la demande est affectée)
            ))
            acquereurs.append(dict(
                id_demande=id_demande, id_client=id_client, qualite="principal",
            ))

            # version courante (parsing des critères)
            crit = parse_criteres(m["description_recherche"])
            # v8.4 : signaler les critères ambigus non transformés en exigence ferme.
            if crit.get("_criteres_requalifier"):
                self._anomalie("demande_version", id_version, "A11",
                               "critères d'exclusion détectés (à confirmer) : "
                               + ",".join(crit["_criteres_requalifier"]))
            versions.append(dict(
                id_version=id_version, id_demande=id_demande,
                id_modifie_par=id_client, no_version=1,
                date_creation=datetime.combine(m["date_debut"],
                                               datetime.min.time(), timezone.utc),
                motif_evolution="Reprise de l'existant (migration)",
                type_bien=crit["type_bien"] or "autre",
                destination="principale",
                budget_max=crit["budget_max"],
                surface_min=crit["surface_min"],
                nb_pieces_min=crit["nb_pieces_min"],
                nb_chambres_min=crit["nb_chambres_min"],
                dpe_max=crit["dpe_max"],
                travaux_acceptes=crit["travaux_acceptes"],
                pref_ascenseur=crit["pref_ascenseur"],
                pref_balcon=crit["pref_balcon"],
                pref_terrasse=crit["pref_terrasse"],
                pref_jardin=crit["pref_jardin"],
                pref_parking=crit["pref_parking"],
                pref_cave=crit["pref_cave"],
                commentaire_criteres=m["description_recherche"],  # A6 zéro déperdition
            ))
            # primo-accédant déduit (A10) -> mémorisé pour patch client
            if crit["primo_accedant"]:
                self._anomalie("client", id_client, "A03",
                               "primo_accedant déduit du texte « premier achat »", "true")
                self._primo_clients = getattr(self, "_primo_clients", set())
                self._primo_clients.add(id_client)

            # version_zone : secteur déclaré du mandat
            version_zones.append(dict(id_version=id_version,
                                      id_zone=self.uid_zone[m["secteur_id"]]))

            # ADR-048 : le mandat n'a plus de statut. On classe le statut SOURCE
            # en faits (résiliation) ou état repris (mandat_etat).
            id_mandat = uuid5_for("mandat", f"{self.source}:{m['id']}")
            cls = classifier_statut_source(m["statut"])
            if "_anomalie" in cls:
                code, motif = cls.pop("_anomalie")
                self._anomalie("mandat", id_mandat, code, motif)
            # M1/A08 : habilitation d'époque inconnue (gel laissé NULL).
            self._anomalie("mandat", id_mandat, "A08",
                           "habilitation à la signature inconnue (reprise) -> gel NULL")
            # ADR-051 : état repris éventuel (ex. 'termine' -> clos_succes) dans
            # mandat_reprise (OLTP, donnée transactionnelle non recalculable).
            if cls.get("etat_repris"):
                self.etats_repris.append(dict(id_mandat=id_mandat,
                                              statut_repris=cls["etat_repris"],
                                              source=self.source))
            # résiliation (suspendu) : fait natif, date = date_debut faute de date source
            date_resil = m["date_debut"] if cls.get("date_resiliation") else None
            type_resil = cls.get("type_resiliation")
            motif_resil = cls.get("motif_resiliation")
            id_chasseur_uid = self.uid_util[m["chasseur_id"]]
            row = dict(
                id_mandat=id_mandat, id_demande=id_demande,
                id_version_contractuelle=id_version, id_chasseur=id_chasseur,
                id_signataire=id_client,
                numero_registre=f"MIGR-{m['id']}",
                date_signature=m["date_debut"], mode_signature="presentiel",
                date_debut=m["date_debut"],
                numero_habilitation_signature=None,
                validite_habilitation_signature=None,
                exclusif=m["exclusif"],
                taux_honoraires=None,  # rempli au load depuis chasseur
                base_honoraires="TTC", taux_tva=20.0, qualite_signataire="nom_propre",
                date_resiliation=date_resil,
                type_resiliation=type_resil,
                motif_resiliation=motif_resil,
                _chasseur_src=m["chasseur_id"],
            )
            mandat_rows.append(row)
            # ADR-048 : désigner ce mandat comme courant de sa demande SI non résilié
            # et non terminé (sinon la demande n'a plus de mandat courant).
            if not date_resil and not cls.get("etat_repris"):
                self.mandat_courant[id_demande] = id_mandat
        return demandes, acquereurs, versions, version_zones, mandat_rows


# Référentiel INSEE (COG) — communes réellement présentes dans la source.
# Clé = (ville, code_postal). En production : table COG complète chargée à part.
# Le code INSEE est celui de la COMMUNE (il ne dépend pas du quartier/CP interne).
_INSEE_REF = {
    ("Montpellier", "34000"): "34172",
    ("Montpellier", "34070"): "34172",
    ("Montpellier", "34090"): "34172",
    ("Castelnau-le-Lez", "34170"): "34057",
    ("Lattes", "34970"): "34129",
    ("Sète", "34200"): "34301",
    ("Lyon", "69004"): "69384",   # Lyon 4e arrondissement (Croix-Rousse)
    ("Lyon", "69002"): "69382",   # Lyon 2e arrondissement (Confluence)
    ("Nantes", "44200"): "44109",
}


# ==========================================================================
# [L] LOAD
# ==========================================================================
def _insert(cur, table, rows, conflict_cols):
    """INSERT ... ON CONFLICT DO NOTHING générique et idempotent."""
    if not rows:
        return 0
    cols = [c for c in rows[0].keys() if not c.startswith("_")]
    collist = ", ".join(cols)
    placeholders = ", ".join(f"%({c})s" for c in cols)
    conflict = f" ON CONFLICT ({conflict_cols}) DO NOTHING" if conflict_cols else ""
    sql = f"INSERT INTO {table} ({collist}) VALUES ({placeholders}){conflict}"
    n = 0
    for r in rows:
        cur.execute(sql, {c: r[c] for c in cols})
        n += cur.rowcount
    return n


def load(dst, t: Transform, data, run_id, jrn, dry_run=False):
    # Ordre de transformation : zones et acteurs d'abord (peuplent les index
    # uid_zone / uid_util), puis les mandats qui en dépendent pour les FK.
    zones = t.zones(data["secteurs"])
    util, clients, chasseurs = t.acteurs(data["utilisateurs"])
    g_util, g_gest = t.gestionnaire_root()
    demandes, acquereurs, versions, version_zones, mandats = t.mandats(data["mandats"])

    # patch primo-accédant déduit (A10)
    primo = getattr(t, "_primo_clients", set())
    for c in clients:
        if c["id_utilisateur"] in primo:
            c["primo_accedant"] = True

    # taux du mandat = taux du chasseur (dénormalisation contrôlée)
    taux_by_uid = {c["id_utilisateur"]: c["taux_honoraires_defaut"] for c in chasseurs}
    for m in mandats:
        m["taux_honoraires"] = taux_by_uid[t.uid_util[m["_chasseur_src"]]]

    total = 0
    with dst.cursor() as cur:
        # ordre des FK
        cur.execute("SET session_replication_role = 'origin'")
        total += _insert(cur, "utilisateur", [g_util] + util, "id_utilisateur")
        total += _insert(cur, "gestionnaire", [g_gest], "id_utilisateur")
        total += _insert(cur, "chasseur", chasseurs, "id_utilisateur")
        total += _insert(cur, "client", clients, "id_utilisateur")
        total += _insert(cur, "zone", zones, "id_zone")
        total += _insert(cur, "demande", demandes, "id_demande")
        total += _insert(cur, "demande_acquereur", acquereurs, "id_demande, id_client")
        total += _insert(cur, "demande_version", versions, "id_version")
        total += _insert(cur, "version_zone", version_zones, "id_version, id_zone")
        total += _insert(cur, "mandat", mandats, "id_mandat")
        # ADR-051 : états repris dans mandat_reprise (OLTP)
        total += _insert(cur, "mandat_reprise", t.etats_repris, "id_mandat")
        # ADR-048 : désigner le mandat courant de chaque demande (fait de gestion)
        for id_dem, id_man in t.mandat_courant.items():
            cur.execute("UPDATE demande SET id_mandat_courant=%s WHERE id_demande=%s",
                        (id_man, id_dem))
        # M3 : VALIDATION BLOQUANTE côté données, AVANT commit. Si un contrôle
        # d'intégrité échoue, on lève -> main rollback les données (rien de corrompu).
        _valider_bloquant(cur)

    # M2/M5 : anomalies écrites via le JOURNAL (connexion autocommit), donc
    # conservées même si les données rollback (dry-run ou échec).
    with jrn.cursor() as jc:
        _insert(jc, "staging.migration_anomalie",
                [dict(a, id_run=run_id, id_cible=str(a["id_cible"])) for a in t.anomalies], None)

    # NB : le commit/rollback des DONNÉES est géré par main (transaction unique).
    return total, len(t.anomalies)


def _valider_bloquant(cur):
    """M3 : contrôles d'intégrité qui LÈVENT une erreur si une anomalie est trouvée.
    Doublon volontaire avec sql/40_validate.sql (garantie côté pipeline Python ;
    le SQL garantit côté exécution manuelle). Les requêtes sont les mêmes."""
    controles = [
        ("acquéreur orphelin",
         "SELECT count(*) FROM demande_acquereur da LEFT JOIN client c "
         "ON c.id_utilisateur=da.id_client WHERE c.id_utilisateur IS NULL"),
        ("mandat sans chasseur",
         "SELECT count(*) FROM mandat m LEFT JOIN chasseur ch "
         "ON ch.id_utilisateur=m.id_chasseur WHERE ch.id_utilisateur IS NULL"),
        ("signataire non acquéreur",
         "SELECT count(*) FROM mandat m LEFT JOIN demande_acquereur da "
         "ON da.id_demande=m.id_demande AND da.id_client=m.id_signataire "
         "WHERE da.id_demande IS NULL"),
    ]
    for libelle, sql in controles:
        cur.execute(sql)
        n = cur.fetchone()[0]
        if n:
            raise RuntimeError(f"validation bloquante échouée : {libelle} ({n} cas)")


# ==========================================================================
# MAIN
# ==========================================================================
def main(argv=None):
    ap = argparse.ArgumentParser(description="Migration Existant -> OLTP v7")
    ap.add_argument("--source", default="historique", help="label de la source")
    ap.add_argument("--dry-run", action="store_true",
                    help="exécute tout mais annule (rollback) — ne charge rien")
    args = ap.parse_args(argv)

    # M2/ADR-050 : connexion JOURNAL séparée (autocommit) pour migration_run et
    # migration_anomalie. Le journal doit SURVIVRE même si les données rollback
    # (un échec doit laisser une trace « ce run a échoué, voici pourquoi »).
    jrn = _conn("DST"); jrn.autocommit = True
    with _conn("SRC") as src, _conn("DST") as dst:
        run_id = _open_run(jrn, args.source)
        try:
            data = extract(src)
            t = Transform(args.source)
            # M2 : tout le chargement des données dans UNE transaction (dst).
            n_rows, n_anom = load(dst, t, data, run_id, jrn, dry_run=args.dry_run)
            if args.dry_run:
                dst.rollback()
                _close_run(jrn, run_id, "dry_run", n_rows, n_anom, "dry-run (rollback)")
            else:
                dst.commit()
                _close_run(jrn, run_id, "succes", n_rows, n_anom, None)
            print(f"[OK] source={args.source} lignes={n_rows} anomalies={n_anom}"
                  f"{' (DRY-RUN, rollback)' if args.dry_run else ''}")
            return 0
        except Exception as e:  # noqa
            dst.rollback()  # données annulées...
            _close_run(jrn, run_id, "echec", None, None, str(e)[:500])  # ...mais le run reste tracé
            print(f"[ECHEC] {e}", file=sys.stderr)
            return 1
        finally:
            jrn.close()


def _open_run(jrn, source):
    # jrn est en autocommit : le run est tracé immédiatement et indépendamment.
    with jrn.cursor() as cur:
        cur.execute("INSERT INTO staging.migration_run (source) VALUES (%s) RETURNING id",
                    (source,))
        return cur.fetchone()[0]


def _close_run(jrn, rid, statut, n_rows, n_anom, msg):
    with jrn.cursor() as cur:
        cur.execute("UPDATE staging.migration_run SET date_fin=now(), statut=%s, "
                    "lignes_inserees=%s, lignes_anomalies=%s, message=%s WHERE id=%s",
                    (statut, n_rows, n_anom, msg, rid))


if __name__ == "__main__":
    sys.exit(main())
