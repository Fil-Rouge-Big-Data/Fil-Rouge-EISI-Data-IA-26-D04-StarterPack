"""Tests de l'entrepôt décisionnel (schéma olap) sur le socle OLTP v8.42.

Tests d'intégration : base cible joignable (variables PG*). Se skippent proprement sinon ;
REQUIRE_DB=1 force l'échec (CI). Lancement : voir run_tests_docker.sh.

1. structure : 6 dimensions, 4 faits, 5 vues KPI ;
2. idempotence : rejouer l'ETL ne crée aucun doublon ;
3. réconciliation OLTP ↔ OLAP : mandats (volume et état dérivé), ventes (comptage et montants) — RB2 ;
4. isolation du compte technique SYS-MIGRATION (ADR-036) ;
5. formules financières (marge = honoraires − part chasseur) ;
6. RGPD : aucune donnée identifiante dans dim_client, statut d'anonymisation reflété (ADR-043, RB4) ;
7. D10 : une visite en couple compte une fois, la reconnaissance du chasseur ne compte pas ;
8. D13 / ADR-053 : chaque vente est rattachée au mandat en vigueur et au mandat initial de sa chaîne ;
9. les vues n'additionnent jamais deux fois une vente (revue PR #15) : sommes des vues = sommes brutes des faits ;
10. honoraires HT : conversion selon la base du mandat (TTC -> HT), rapprochée de l'OLTP (D19) ;
11. KPI-2 trésorerie : encaissement rapproché de l'acte, compromis rapprochés de v_compromis, honoraires
    estimés recalculés depuis le mandat, la vue de trésorerie n'additionne aucune vente deux fois ;
12. KPI-1 jusqu'à l'acte, motifs de résiliation et taux d'acceptation rapprochés de l'OLTP.
"""
import os
import pathlib

import psycopg
import pytest

ICI = pathlib.Path(__file__).resolve().parent
ETL = ICI.parent / "02_etl_chargement.sql"


def _conn():
    return psycopg.connect(host=os.environ.get("PGHOST", "127.0.0.1"), port=os.environ.get("PGPORT", "5433"),
                           user=os.environ.get("PGUSER", "chasse_migration"), dbname=os.environ.get("PGDATABASE", "chasse_v8"),
                           password=os.environ.get("PGPASSWORD", ""), autocommit=True)


@pytest.fixture(scope="session")
def conn():
    try:
        c = _conn()
    except Exception:
        if os.environ.get("REQUIRE_DB") == "1":
            pytest.fail("[REQUIRE_DB=1] Base cible non joignable — tests NON exécutés.")
        pytest.skip("Base cible non joignable (REQUIRE_DB=1 pour forcer l'échec).")
    yield c
    c.close()


def _un(conn, sql, params=None):
    with conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchone()[0]


# 1. structure -----------------------------------------------------------------------------------
def test_structure_etoile(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='olap' AND table_type='BASE TABLE'")
        tables = {r[0] for r in cur.fetchall()}
        cur.execute("SELECT table_name FROM information_schema.views WHERE table_schema='olap'")
        vues = {r[0] for r in cur.fetchall()}
    assert {"dim_temps", "dim_chasseur", "dim_gestionnaire", "dim_zone", "dim_bien", "dim_client"} <= tables
    assert {"fait_vente", "fait_remuneration_chasseur", "fait_mandat_cycle", "fait_activite_demande", "fait_compromis"} <= tables
    assert {"v_kpi_chiffre_affaires_mensuel", "v_kpi_performance_chasseurs", "v_kpi_conversion_funnel",
            "v_kpi_mandats_cycle_vie", "v_kpi_analyse_geographique", "v_kpi_tresorerie", "v_kpi_motifs_resiliation"} <= vues


# 2. idempotence ---------------------------------------------------------------------------------
def test_etl_idempotent(conn):
    compte = lambda: tuple(_un(conn, f"SELECT count(*) FROM olap.{t}") for t in
                           ("dim_chasseur", "dim_client", "fait_mandat_cycle", "fait_activite_demande", "fait_vente",
                            "fait_remuneration_chasseur", "fait_compromis"))
    avant = compte()
    with conn.cursor() as cur:
        cur.execute(ETL.read_text(encoding="utf-8"))
    assert compte() == avant, "le rejeu de l'ETL a créé des doublons"


# 3. réconciliation (RB2 : comptages ET montants) -------------------------------------------------
def test_reconciliation_mandats(conn):
    oltp = _un(conn, "SELECT count(*) FROM public.v_mandat vm WHERE EXISTS (SELECT 1 FROM public.demande_acquereur da "
                     "WHERE da.id_demande = vm.id_demande AND da.qualite = 'principal')")
    olap = _un(conn, "SELECT count(*) FROM olap.fait_mandat_cycle")
    assert oltp == olap, f"mandats : OLTP={oltp}, OLAP={olap}"
    ecarts = _un(conn, "SELECT count(*) FROM public.v_mandat vm JOIN olap.fait_mandat_cycle f ON f.id_mandat = vm.id_mandat "
                       "WHERE f.statut_projete <> vm.statut_calcule")
    assert ecarts == 0, "l'état projeté diverge de v_mandat (RB2)"


def test_reconciliation_ventes(conn):
    oltp_n, oltp_total = (0, 0)
    with conn.cursor() as cur:
        cur.execute("SELECT count(*), COALESCE(sum(montant_vente), 0) FROM public.acte a "
                    "JOIN public.v_acte_mandat am ON am.id_acte = a.id_acte WHERE am.id_mandat_en_vigueur IS NOT NULL")
        oltp_n, oltp_total = cur.fetchone()
        cur.execute("SELECT count(*), COALESCE(sum(montant_acte_net_vendeur), 0) FROM olap.fait_vente")
        olap_n, olap_total = cur.fetchone()
    assert (oltp_n, oltp_total) == (olap_n, olap_total), f"ventes : OLTP={oltp_n}/{oltp_total}, OLAP={olap_n}/{olap_total}"


# 4. compte technique ----------------------------------------------------------------------------
def test_isolation_sys_migration(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT est_technique FROM olap.dim_gestionnaire WHERE matricule = 'SYS-MIGRATION'")
        row = cur.fetchone()
        if row is None:
            pytest.skip("pas de compte SYS-MIGRATION dans cette base (jeu de test sans reprise)")
        assert row[0] is True
        cur.execute("SELECT delai_moyen_affectation_heures_humain FROM olap.v_kpi_conversion_funnel WHERE matricule = 'SYS-MIGRATION'")
        assert cur.fetchone()[0] is None, "le délai humain ne doit pas inclure le compte technique"


# 5. formules ------------------------------------------------------------------------------------
def test_formules_financieres(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT id_acte, honoraires_agence_ht, remuneration_chasseur_ht, marge_brute_ht, taux_marge_pct FROM olap.fait_vente")
        for id_acte, ca, part, marge, taux in cur.fetchall():
            assert marge == ca - part, f"marge incohérente sur {id_acte}"
            if ca > 0:
                assert float(taux) == round(float(marge) / float(ca) * 100, 2), f"taux incohérent sur {id_acte}"


# 6. RGPD ----------------------------------------------------------------------------------------
def test_rgpd_dim_client(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT column_name FROM information_schema.columns WHERE table_schema='olap' AND table_name='dim_client'")
        cols = {r[0] for r in cur.fetchall()}
    assert not ({"nom", "prenom", "email", "telephone", "annee_naissance"} & cols), "donnée identifiante dans dim_client"
    desync = _un(conn, "SELECT count(*) FROM olap.dim_client dc JOIN public.utilisateur u ON u.id_utilisateur = dc.id_client "
                       "WHERE dc.est_anonymise_rgpd <> (u.date_anonymisation IS NOT NULL)")
    assert desync == 0


# 7. D10 -----------------------------------------------------------------------------------------
def test_d10_une_visite_par_rendez_vous(conn):
    """Un couple d'acquéreurs + le chasseur sur un bien le même jour = 1 visite ; la reconnaissance du
    chasseur seul = 0 ; un chasseur qui est aussi client, mais pas acquéreur de la demande = 0."""
    c = _conn()
    c.autocommit = False
    try:
        with c.cursor() as cur:
            cur.execute("SELECT id_mandat, id_demande FROM public.mandat ORDER BY date_signature LIMIT 1")
            id_mandat, id_demande = cur.fetchone()
            cur.execute("SELECT id_proposition FROM public.proposition WHERE id_mandat = %s LIMIT 1", (id_mandat,))
            row = cur.fetchone()
            if row is None:
                pytest.skip("aucune proposition sur le premier mandat")
            id_prop = row[0]
            cur.execute("SELECT da.id_client FROM public.demande_acquereur da WHERE da.id_demande = %s AND da.qualite='principal'", (id_demande,))
            principal = cur.fetchone()[0]
            cur.execute("SELECT id_chasseur FROM public.mandat WHERE id_mandat = %s", (id_mandat,))
            chasseur = cur.fetchone()[0]
            # co-acquéreur : un autre client de la base, pas encore acquéreur de cette demande
            cur.execute("SELECT c.id_utilisateur FROM public.client c WHERE c.id_utilisateur <> %s AND NOT EXISTS "
                        "(SELECT 1 FROM public.demande_acquereur da WHERE da.id_demande = %s AND da.id_client = c.id_utilisateur) LIMIT 1",
                        (principal, id_demande))
            co = cur.fetchone()
            if co is None:
                pytest.skip("pas de second client disponible")
            cur.execute("INSERT INTO public.demande_acquereur (id_demande, id_client, qualite) VALUES (%s, %s, 'co_acquereur')", (id_demande, co[0]))
            cur.execute("SELECT olap.f_nb_visites(%s, NULL, false)", (id_mandat,))
            avant = cur.fetchone()[0]
            cur.execute("INSERT INTO public.visite (id_proposition, id_visiteur, date_visite, realisee) VALUES "
                        "(%s, %s, '2031-01-10', true), (%s, %s, '2031-01-10', true), (%s, %s, '2031-01-10', true), "   # couple + chasseur
                        "(%s, %s, '2031-01-08', true)",                                                              # reconnaissance seul
                        (id_prop, principal, id_prop, co[0], id_prop, chasseur, id_prop, chasseur))
            cur.execute("SELECT olap.f_nb_visites(%s, NULL, false)", (id_mandat,))
            apres = cur.fetchone()[0]
        assert apres == avant + 1, f"4 lignes de visite doivent compter pour 1 rendez-vous (avant={avant}, après={apres})"
    finally:
        c.rollback()
        c.close()


# 9. les vues n'additionnent pas deux fois (revue PR #15 : jointure de plusieurs faits sur une même clé) ------
def test_vues_sans_multiplication(conn):
    ca_vue = _un(conn, "SELECT COALESCE(sum(ca_honoraires_generes_ht), 0) FROM olap.v_kpi_performance_chasseurs")
    ca_fait = _un(conn, "SELECT COALESCE(sum(honoraires_agence_ht), 0) FROM olap.fait_vente")
    assert ca_vue == ca_fait, f"CA par chasseur : vue {ca_vue} / faits {ca_fait}"
    rem_vue = _un(conn, "SELECT COALESCE(sum(total_remuneration_ht), 0) FROM olap.v_kpi_performance_chasseurs")
    rem_fait = _un(conn, "SELECT COALESCE(sum(montant_remuneration_ht), 0) FROM olap.fait_remuneration_chasseur WHERE NOT est_annulee")
    assert rem_vue == rem_fait, f"rémunération par chasseur : vue {rem_vue} / faits {rem_fait}"
    ca_zone = _un(conn, "SELECT COALESCE(sum(ca_honoraires_ht), 0) FROM olap.v_kpi_analyse_geographique")
    ca_zone_fait = _un(conn, "SELECT COALESCE(sum(honoraires_agence_ht), 0) FROM olap.fait_vente WHERE id_zone IS NOT NULL")
    assert ca_zone == ca_zone_fait, f"CA par zone : vue {ca_zone} / faits {ca_zone_fait}"
    mandats_vue = _un(conn, "SELECT COALESCE(sum(nb_mandats_total), 0) FROM olap.v_kpi_performance_chasseurs")
    mandats_fait = _un(conn, "SELECT count(*) FROM olap.fait_mandat_cycle")
    assert mandats_vue == mandats_fait


def test_vues_sans_multiplication_avec_second_mandat(conn):
    """Le cas d'Angeline : un 2e mandat SANS vente pour le chasseur du seed ne doit pas changer son CA.
    Rejoué dans une transaction annulée, en recalculant la vue sur des faits temporairement enrichis."""
    c = _conn()
    c.autocommit = False
    try:
        with c.cursor() as cur:
            cur.execute("SELECT id_chasseur, COALESCE(sum(ca_honoraires_generes_ht), 0), COALESCE(sum(total_remuneration_ht), 0) "
                        "FROM olap.v_kpi_performance_chasseurs WHERE nb_ventes_conclues > 0 GROUP BY id_chasseur ORDER BY 2 DESC LIMIT 1")
            row = cur.fetchone()
            if row is None:
                pytest.skip("aucune vente dans l'entrepôt")
            id_chasseur, ca_avant, rem_avant = row
            cur.execute("SELECT id_client, id_zone FROM olap.fait_mandat_cycle WHERE id_chasseur = %s LIMIT 1", (id_chasseur,))
            id_client, id_zone = cur.fetchone()
            cur.execute("INSERT INTO olap.fait_mandat_cycle (id_mandat, id_date_signature, id_date_fin_theorique, id_chasseur, id_zone, id_client, "
                        "exclusif, statut_projete, duree_effective_jours) VALUES (gen_random_uuid(), 20250101, 20250701, %s, %s, %s, true, 'actif', 10)",
                        (id_chasseur, id_zone, id_client))
            cur.execute("SELECT ca_honoraires_generes_ht, total_remuneration_ht FROM olap.v_kpi_performance_chasseurs WHERE id_chasseur = %s", (id_chasseur,))
            ca_apres, rem_apres = cur.fetchone()
        assert (ca_apres, rem_apres) == (ca_avant, rem_avant), f"un mandat de plus a changé les montants : {ca_avant} -> {ca_apres}"
    finally:
        c.rollback()
        c.close()


# 10. honoraires HT (D19) ----------------------------------------------------------------------------
def test_honoraires_ht(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT f.id_acte, f.base_honoraires_mandat, f.taux_tva_mandat, f.honoraires_agence_brut, f.honoraires_agence_ht, vh.honoraires_total "
                    "FROM olap.fait_vente f JOIN public.v_honoraires vh ON vh.id_acte = f.id_acte")
        for id_acte, base, tva, brut, ht, total in cur.fetchall():
            assert brut == total, f"brut ≠ OLTP sur {id_acte}"
            attendu = round(total / (1 + tva / 100), 2) if base == "TTC" else total
            assert ht == attendu, f"HT incohérent sur {id_acte} : {ht} ≠ {attendu} (base {base}, TVA {tva})"
            assert ht <= brut


# 8. D13 / ADR-053 -------------------------------------------------------------------------------
def test_ventes_rattachees_a_la_chaine(conn):
    incoherents = _un(conn, "SELECT count(*) FROM olap.fait_vente f JOIN public.v_acte_mandat am ON am.id_acte = f.id_acte "
                            "WHERE f.id_mandat_en_vigueur <> am.id_mandat_en_vigueur OR f.id_mandat_initial <> am.id_mandat_initial "
                            "   OR f.est_hors_dispositif <> am.hors_dispositif")
    assert incoherents == 0
    sans_bien_mais_dispositif = _un(conn, "SELECT count(*) FROM olap.fait_vente WHERE NOT est_hors_dispositif AND id_bien IS NULL")
    assert sans_bien_mais_dispositif == 0, "une vente de la chaîne de vente a toujours un bien"


# 11. KPI-2 trésorerie ---------------------------------------------------------------------------
def test_encaissement_rapproche_de_l_acte(conn):
    ecarts = _un(conn, "SELECT count(*) FROM olap.fait_vente f JOIN public.acte a ON a.id_acte = f.id_acte "
                       "WHERE f.est_honoraires_encaisses <> a.honoraires_encaisses "
                       "   OR f.delai_acte_a_encaissement_jours IS DISTINCT FROM "
                       "      CASE WHEN a.honoraires_encaisses THEN a.date_encaissement - a.date_signature END")
    assert ecarts == 0, "encaissement de l'entrepôt différent de l'acte"


def test_compromis_rapproches(conn):
    oltp = _un(conn, "SELECT count(*) FROM public.compromis")
    olap = _un(conn, "SELECT count(*) FROM olap.fait_compromis")
    assert oltp == olap, f"compromis : OLTP={oltp}, OLAP={olap}"
    etat = _un(conn, "SELECT count(*) FROM olap.fait_compromis f JOIN public.v_compromis vc ON vc.id_compromis = f.id_compromis "
                     "WHERE f.statut_projete <> vc.statut_calcule")
    assert etat == 0, "état du compromis différent de v_compromis"
    # honoraires estimés recalculés indépendamment depuis le mandat (forfait + taux x offre, puis HT)
    with conn.cursor() as cur:
        cur.execute("SELECT f.id_compromis, f.honoraires_estimes_ht, m.forfait_honoraires, m.taux_honoraires, o.montant, m.base_honoraires, m.taux_tva "
                    "FROM olap.fait_compromis f JOIN public.compromis c ON c.id_compromis = f.id_compromis "
                    "JOIN public.offre_acquisition o ON o.id_offre = c.id_offre JOIN public.mandat m ON m.id_mandat = f.id_mandat")
        for id_c, estime, forfait, taux, montant, base, tva in cur.fetchall():
            brut = round(float(forfait or 0) + float(taux or 0) / 100 * float(montant), 2)
            attendu = round(brut / (1 + float(tva) / 100), 2) if base == "TTC" else brut
            assert abs(float(estime) - attendu) < 0.011, f"estimation incohérente sur {id_c} : {estime} ≠ {attendu}"


def test_tresorerie_sans_double_compte(conn):
    vue = _un(conn, "SELECT COALESCE(sum(honoraires_ht), 0) FROM olap.v_kpi_tresorerie WHERE nature IN ('encaisse', 'en_attente_notaire')")
    faits = _un(conn, "SELECT COALESCE(sum(honoraires_agence_ht), 0) FROM olap.fait_vente")
    assert vue == faits, f"trésorerie : vue {vue} / ventes {faits} ; chaque vente est soit encaissée, soit en attente"
    prevu = _un(conn, "SELECT COALESCE(sum(honoraires_ht), 0) FROM olap.v_kpi_tresorerie WHERE nature = 'prevu_compromis'")
    prevu_fait = _un(conn, "SELECT COALESCE(sum(honoraires_estimes_ht), 0) FROM olap.fait_compromis WHERE statut_projete = 'signe'")
    assert prevu == prevu_fait


def test_tresorerie_compromis_en_cours(conn):
    """Un compromis signé, acte prévu en mars 2031, apparaît en « prévu » ce mois-là ; un compromis caduc n'apparaît pas.
    Rejoué dans une transaction annulée, sur des faits temporairement enrichis."""
    c = _conn()
    c.autocommit = False
    try:
        with c.cursor() as cur:
            cur.execute("SELECT id_chasseur, id_mandat FROM olap.fait_mandat_cycle LIMIT 1")
            row = cur.fetchone()
            if row is None:
                pytest.skip("aucun mandat dans l'entrepôt")
            chasseur, mandat = row
            cur.execute("INSERT INTO olap.fait_compromis (id_compromis, id_date_signature, id_date_acte_prevue, id_chasseur, id_mandat, "
                        "statut_projete, montant_offre, honoraires_estimes_ht) VALUES "
                        "(gen_random_uuid(), 20301215, 20310315, %s, %s, 'signe', 300000, 9000), "
                        "(gen_random_uuid(), 20301215, 20310320, %s, %s, 'caduc', 250000, 7500)", (chasseur, mandat, chasseur, mandat))
            cur.execute("SELECT nb_dossiers, honoraires_ht FROM olap.v_kpi_tresorerie WHERE nature = 'prevu_compromis' AND annee = 2031 AND mois = 3")
            assert cur.fetchone() == (1, 9000), "seul le compromis signé doit être prévu en mars 2031"
    finally:
        c.rollback()
        c.close()


# 12. KPI-1 jusqu'à l'acte, motifs, acceptation ---------------------------------------------------
def test_entonnoir_jusqu_a_l_acte(conn):
    oltp = _un(conn, "SELECT count(DISTINCT m.id_demande) FROM public.acte a JOIN public.v_acte_mandat am ON am.id_acte = a.id_acte "
                     "JOIN public.mandat m ON m.id_mandat = am.id_mandat_en_vigueur "
                     "WHERE m.id_demande IN (SELECT id_demande FROM olap.fait_activite_demande)")
    olap = _un(conn, "SELECT COALESCE(sum(demandes_abouties_acte), 0) FROM olap.v_kpi_conversion_funnel")
    assert oltp == olap, f"demandes abouties à un acte : OLTP={oltp}, OLAP={olap}"
    incoherent = _un(conn, "SELECT count(*) FROM olap.fait_activite_demande WHERE a_eu_offre AND NOT a_abouti_mandat")
    assert incoherent == 0, "une offre suppose un mandat (la proposition est cadrée par un mandat)"


def test_motifs_et_acceptation(conn):
    resilies = _un(conn, "SELECT count(*) FROM olap.fait_mandat_cycle WHERE est_resilie")
    vue = _un(conn, "SELECT COALESCE(sum(nb_mandats_resilies), 0) FROM olap.v_kpi_motifs_resiliation")
    assert resilies == vue
    sans_motif = _un(conn, "SELECT count(*) FROM olap.fait_mandat_cycle WHERE est_resilie AND type_resiliation IS NULL")
    assert sans_motif == 0, "un mandat résilié a toujours un motif, au pire 'non_renseigne'"
    ecarts = _un(conn, "SELECT count(*) FROM olap.fait_mandat_cycle f WHERE f.nb_propositions_retenues > f.nb_propositions_soumises "
                       "OR f.nb_propositions_soumises <> (SELECT count(*) FROM public.proposition p WHERE p.id_mandat = f.id_mandat "
                       "AND p.statut IN ('soumis','retenu_visite','refuse_client'))")
    assert ecarts == 0

