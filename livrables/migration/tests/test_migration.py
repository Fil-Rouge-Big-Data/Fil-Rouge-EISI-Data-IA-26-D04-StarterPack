"""Batterie de tests de la migration.

5 niveaux (cf. mapping-donnees.md §7 et arbitrages) :
  - unitaires  : parser de critères, UUID déterministe, mapping statuts (sans base)
  - volumétrie : comptages source vs cible
  - intégrité  : zéro FK orpheline, chaîne signataire
  - métier     : statuts recalculés, sentinelles, gestionnaire root
  - idempotence: rejouer ne duplique rien
"""
import pytest
from conftest import q1

# Import du module testé (chemin injecté par conftest).
import mapping
from run_migration import main as run_main


# ==========================================================================
# NIVEAU 1 — UNITAIRES (sans base) : le cœur de la transformation
# ==========================================================================
class TestParser:
    def test_type_bien_loft_vers_appartement(self):
        assert mapping.parse_criteres("Loft Port Marianne")["type_bien"] == "appartement"

    def test_type_bien_maison(self):
        assert mapping.parse_criteres("Maison Castelnau")["type_bien"] == "maison"

    def test_budget_avec_espaces(self):
        assert mapping.parse_criteres("budget 320 000")["budget_max"] == 320000

    def test_t3_donne_3_pieces(self):
        assert mapping.parse_criteres("T3 Ecusson")["nb_pieces_min"] == 3

    def test_pieces_explicite_prioritaire(self):
        # "4 pieces" doit gagner même s'il y a un Tn ailleurs
        r = mapping.parse_criteres("T2 mais en fait 4 pieces")
        assert r["nb_pieces_min"] == 4

    def test_surface_et_dpe(self):
        r = mapping.parse_criteres("80m2, DPE C max")
        assert r["surface_min"] == 80 and r["dpe_max"] == "C"

    def test_pref_exige(self):
        # EXCL : mot seul -> exige
        r = mapping.parse_criteres("jardin, terrasse, parking, ascenseur, balcon, cave")
        assert all(r[k] == "exige" for k in
                   ("pref_jardin", "pref_terrasse", "pref_parking",
                    "pref_ascenseur", "pref_balcon", "pref_cave"))

    def test_pref_exclut(self):
        # EXCL : négation -> exclut (critère d'exclusion, le point clé de la revue)
        assert mapping.parse_criteres("maison sans jardin")["pref_jardin"] == "exclut"
        assert mapping.parse_criteres("pas de cave")["pref_cave"] == "exclut"
        assert mapping.parse_criteres("aucun balcon")["pref_balcon"] == "exclut"

    def test_pref_souhaite(self):
        # EXCL : apprécié/ou -> souhaite (non bloquant, distinct de indifferent)
        assert mapping.parse_criteres("jardin apprécié")["pref_jardin"] == "souhaite"
        assert mapping.parse_criteres("balcon ou terrasse")["pref_balcon"] == "souhaite"

    def test_pref_indifferent(self):
        # EXCL : critère absent -> indifferent (aucune valeur inventée)
        assert mapping.parse_criteres("studio lumineux")["pref_balcon"] == "indifferent"

    def test_exclusion_tracee(self):
        # un 'exclut' détecté est signalé pour requalification
        r = mapping.parse_criteres("maison sans jardin")
        assert "pref_jardin" in r.get("_criteres_requalifier", [])

    def test_travaux_et_primo(self):
        r = mapping.parse_criteres("travaux OK, premier achat")
        assert r["travaux_acceptes"] and r["primo_accedant"]

    def test_rien_invente(self):
        # texte vide -> rien de fabriqué ; critères -> indifferent
        r = mapping.parse_criteres("")
        assert r["budget_max"] is None and r["type_bien"] is None
        assert r["pref_balcon"] == "indifferent"


class TestUuid:
    def test_deterministe(self):
        assert mapping.uuid5_for("utilisateur", "a@b.c") == \
               mapping.uuid5_for("utilisateur", "a@b.c")

    def test_kinds_distincts(self):
        assert mapping.uuid5_for("demande", "5") != mapping.uuid5_for("mandat", "5")

    def test_casse_insensible(self):
        assert mapping.uuid5_for("utilisateur", "A@B.C") == \
               mapping.uuid5_for("utilisateur", "a@b.c")


class TestStatuts:
    # ADR-048 : le mandat n'a plus de statut. classifier_statut_source traduit le
    # statut SOURCE en faits (résiliation) ou état repris (mandat_etat).
    def test_actif_rien_a_stocker(self):
        assert mapping.classifier_statut_source("actif") == {}

    def test_expire_rien_a_stocker(self):
        # l'expiration est calculée par v_mandat, rien n'est stocké
        assert mapping.classifier_statut_source("expire") == {}

    def test_termine_etat_repris_clos_succes(self):
        r = mapping.classifier_statut_source("termine")
        assert r["etat_repris"] == "clos_succes"

    def test_suspendu_resiliation(self):
        r = mapping.classifier_statut_source("suspendu")
        assert r["date_resiliation"] is True
        assert "suspendu" in r["motif_resiliation"]

    def test_statut_inconnu_leve(self):
        with pytest.raises(ValueError):
            mapping.classifier_statut_source("zombie")


# ==========================================================================
# NIVEAU 2 — VOLUMÉTRIE
# ==========================================================================
@pytest.mark.parametrize("table,attendu", [
    ("utilisateur", 25),   # 24 source + 1 SYS-MIGRATION
    ("gestionnaire", 1),
    ("chasseur", 6),
    ("client", 18),
    ("zone", 10),
    ("demande", 18),
    ("demande_acquereur", 18),
    ("demande_version", 18),
    ("version_zone", 18),
    ("mandat", 18),
])
def test_volumetrie(migrated, table, attendu):
    assert q1(migrated, f"SELECT count(*) FROM {table}") == attendu


# ==========================================================================
# NIVEAU 3 — INTÉGRITÉ
# ==========================================================================
def test_aucun_acquereur_orphelin(migrated):
    assert q1(migrated,
        "SELECT count(*) FROM demande_acquereur da "
        "LEFT JOIN client c ON c.id_utilisateur=da.id_client "
        "WHERE c.id_utilisateur IS NULL") == 0

def test_aucun_mandat_sans_chasseur(migrated):
    assert q1(migrated,
        "SELECT count(*) FROM mandat m "
        "LEFT JOIN chasseur ch ON ch.id_utilisateur=m.id_chasseur "
        "WHERE ch.id_utilisateur IS NULL") == 0

def test_chaine_signataire(migrated):
    # v8/E5-m4 : id_demande_signataire supprimé ; la FK signataire passe par
    # id_demande. id_signataire doit être un acquéreur de la demande du mandat.
    assert q1(migrated,
        "SELECT count(*) FROM mandat m LEFT JOIN demande_acquereur da "
        "ON da.id_demande=m.id_demande AND da.id_client=m.id_signataire "
        "WHERE da.id_demande IS NULL") == 0


# ==========================================================================
# NIVEAU 4 — COHÉRENCE MÉTIER
# ==========================================================================
def test_etats_derives(migrated):
    # ADR-048 : états calculés par v_mandat (plus de colonne statut).
    # 3 termine -> clos_succes (repris) ; 2 suspendu -> resilie ; le reste actif/echu
    # selon la date de référence (ici date du jour : la plupart échus).
    assert q1(migrated, "SELECT count(*) FROM v_mandat WHERE statut_calcule='clos_succes'") == 3
    assert q1(migrated, "SELECT count(*) FROM v_mandat WHERE statut_calcule='resilie'") == 2
    # total cohérent
    assert q1(migrated, "SELECT count(*) FROM v_mandat") == 18

def test_termine_en_etat_repris(migrated):
    # ADR-051 : les 3 'termine' source -> mandat_reprise clos_succes (succès sans acte)
    assert q1(migrated,
        "SELECT count(*) FROM mandat_reprise WHERE statut_repris='clos_succes'") == 3

def test_suspendu_resilie(migrated):
    # les 2 'suspendu' source -> date_resiliation + motif
    assert q1(migrated,
        "SELECT count(*) FROM mandat WHERE date_resiliation IS NOT NULL "
        "AND motif_resiliation LIKE 'suspendu%%'") == 2

def test_gestionnaire_root_present_et_inactif(migrated):
    assert q1(migrated,
        "SELECT count(*) FROM gestionnaire g JOIN utilisateur u "
        "ON u.id_utilisateur=g.id_utilisateur "
        "WHERE g.matricule='SYS-MIGRATION' AND u.actif=false") == 1

def test_demandes_portees_par_root(migrated):
    # toutes les demandes migrées pointent le gestionnaire root
    assert q1(migrated,
        "SELECT count(DISTINCT id_gestionnaire) FROM demande") == 1

def test_chasseurs_tous_a_regulariser(migrated):
    # D-FLAG : les 6 chasseurs migrés ressortent non conformes
    assert q1(migrated,
        "SELECT count(*) FROM v_conformite_chasseur WHERE est_a_regulariser") == 6

def test_zero_deperdition_texte_brut(migrated):
    # chaque version conserve le texte source (A6)
    assert q1(migrated,
        "SELECT count(*) FROM demande_version "
        "WHERE commentaire_criteres IS NULL OR commentaire_criteres=''") == 0


# --- Spécifiques v8 ---
def test_v82_gel_habilitation_null_a_la_reprise(migrated):
    # M1 (v8.2) : l'habilitation d'époque est inconnue -> gel NULL (pas de fausse validité)
    assert q1(migrated,
        "SELECT count(*) FROM mandat "
        "WHERE numero_habilitation_signature IS NOT NULL") == 0

def test_v8_frais_dossier_defaut_false(migrated):
    # E7 : parrainage filleul-seul, aucun frais offert à la migration
    assert q1(migrated, "SELECT count(*) FROM client WHERE frais_dossier_offerts") == 0

def test_v8_tables_remuneration_vides(migrated):
    # aucune source pour la chaîne de rémunération -> tables structurellement vides
    for t in ("bareme", "tranche_bareme", "facture_chasseur",
              "remuneration_chasseur", "note_avis", "document"):
        assert q1(migrated, f"SELECT count(*) FROM {t}") == 0

def test_v82_conformite_pas_de_faux_hors_habilitation(migrated):
    # M1 (v8.2) : gel NULL -> aucun faux « hors habilitation » permanent
    assert q1(migrated,
        "SELECT count(*) FROM v_conformite_chasseur WHERE mandat_hors_habilitation") == 0

def test_anomalies_tracees(migrated):
    # v8.4/M4 : le journal CUMULE les runs (historique préservé). On compte sur le
    # DERNIER run uniquement (via id_run max).
    dernier = "(SELECT max(id_run) FROM staging.migration_anomalie)"
    assert q1(migrated,
        f"SELECT count(*) FROM staging.migration_anomalie "
        f"WHERE code_anomalie='A06' AND id_run={dernier}") >= 1
    assert q1(migrated,
        f"SELECT count(*) FROM staging.migration_anomalie "
        f"WHERE code_anomalie='A02' AND id_run={dernier}") == 6


# ==========================================================================
# NIVEAU 5 — IDEMPOTENCE
# ==========================================================================
def test_idempotence(migrated):
    """Rejouer la migration ne doit rien dupliquer.
    Règle de l'art (P-D) : l'idempotence se vérifie sur L'ENSEMBLE des tables
    migrées (invariance du compte de lignes), pas sur un seul échantillon —
    c'est le fondement des migrations récurrentes (rachats)."""
    tables = ["utilisateur", "client", "chasseur", "gestionnaire", "zone",
              "demande", "demande_acquereur", "demande_version", "mandat",
              "mandat_reprise"]
    avant = {t: q1(migrated, f"SELECT count(*) FROM {t}") for t in tables}
    rc = run_main(["--source", "historique"])
    assert rc == 0
    for t in tables:
        apres = q1(migrated, f"SELECT count(*) FROM {t}")
        assert avant[t] == apres, f"doublons au 2e run sur '{t}' ({avant[t]} -> {apres})"


# ==========================================================================
# NIVEAU 5 — ROBUSTESSE (P-G)
# ==========================================================================
def test_rollback_sur_echec(dst_conn):
    """Règle de l'art (P-G) : prouver que la transaction unique (ADR-050) annule
    TOUTES les données si le chargement échoue en cours de route, tout en laissant
    une trace de l'échec dans le journal. On PROVOQUE l'échec (on ne le décrit pas).

    Méthode : on charge un schéma cible propre, on casse volontairement une table
    cible (colonne manquante) pour faire échouer le load à mi-parcours, puis on
    vérifie : (a) le code retourne 1, (b) aucune donnée métier n'est committée,
    (c) le run est tracé 'echec' dans le journal (connexion séparée -> survit)."""
    import pathlib, subprocess, os
    # schéma cible propre
    REPO = pathlib.Path(__file__).resolve().parents[1]
    OLTP = REPO.parent / "db" if (REPO.parent / "db").exists() else REPO.parent / "sql"
    def run_sql(path):
        with open(path, encoding="utf-8") as f:
            dst_conn.execute(f.read())
    # recharger un schéma propre
    for f in ("01_ddl.sql", "02_triggers_vues.sql"):
        p = OLTP / f
        if p.exists():
            run_sql(p)
    run_sql(REPO / "sql" / "00_staging.sql")
    # casser la cible SANS dépendance : une contrainte impossible sur demande_version
    # (le load y insère forcément des versions no_version=1 -> violation -> échec).
    dst_conn.execute("ALTER TABLE demande_version ADD CONSTRAINT tmp_fail CHECK (no_version > 999)")
    dst_conn.commit()
    # compter avant
    avant_util = q1(dst_conn, "SELECT count(*) FROM utilisateur")
    # lancer la migration -> doit échouer
    rc = run_main(["--source", "historique"])
    assert rc == 1, "la migration aurait dû échouer (colonne manquante)"
    # (b) aucune donnée métier committée (rollback effectif)
    apres_util = q1(dst_conn, "SELECT count(*) FROM utilisateur")
    assert apres_util == avant_util, "le rollback n'a pas annulé les données !"
    # (c) le run est tracé en échec (journal sur connexion séparée)
    n_echec = q1(dst_conn, "SELECT count(*) FROM staging.migration_run WHERE statut='echec'")
    assert n_echec >= 1, "l'échec n'a pas été tracé dans le journal"
    # nettoyage : retirer la contrainte temporaire pour ne pas polluer la suite
    dst_conn.execute("ALTER TABLE demande_version DROP CONSTRAINT IF EXISTS tmp_fail")
    dst_conn.commit()
