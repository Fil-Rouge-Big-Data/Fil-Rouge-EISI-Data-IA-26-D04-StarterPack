-- ============================================================
-- 03_vues_kpi.sql — Vues de restitution (Power BI), les 5 indicateurs de l'étude d'opportunité (§2.3)
-- KPI-1 entonnoir · KPI-2 délais et trésorerie · KPI-3 efficacité des visites · KPI-4 rentabilité et
-- rémunération · KPI-5 performance sectorielle. Source : schéma olap (01_schema_etoile.sql).
-- ============================================================

-- KPI-4 (a) : chiffre d'affaires et marge, par mois
CREATE OR REPLACE VIEW olap.v_kpi_chiffre_affaires_mensuel AS
SELECT dt.annee, dt.mois, dt.nom_mois,
       count(fv.id_fait)                                                      AS nb_ventes,
       count(fv.id_fait) FILTER (WHERE fv.est_hors_dispositif)                 AS nb_ventes_hors_dispositif,
       COALESCE(sum(fv.montant_acte_net_vendeur), 0.00)                       AS volume_affaires_net_vendeur,
       COALESCE(sum(fv.honoraires_agence_ht), 0.00)                           AS ca_honoraires_agence_ht,
       COALESCE(sum(fv.remuneration_chasseur_ht), 0.00)                       AS total_part_chasseurs_ht,
       COALESCE(sum(fv.marge_brute_ht), 0.00)                                 AS marge_brute_agence_ht,
       round(COALESCE(sum(fv.marge_brute_ht), 0.00) / NULLIF(sum(fv.honoraires_agence_ht), 0.00) * 100, 2) AS taux_marge_brute_pct,
       round(COALESCE(avg(fv.honoraires_agence_ht), 0.00), 2)                 AS panier_moyen_honoraires_ht,
       round(COALESCE(avg(fv.delai_mandat_a_acte_jours), 0.00), 1)            AS delai_moyen_mandat_a_acte_jours
FROM olap.dim_temps dt
LEFT JOIN olap.fait_vente fv ON fv.id_date_acte = dt.id_temps
GROUP BY dt.annee, dt.mois, dt.nom_mois
HAVING count(fv.id_fait) > 0
ORDER BY dt.annee DESC, dt.mois DESC;

-- KPI-4 (b) et KPI-3 : performance et rémunération par chasseur.
-- Les rémunérations annulées sont exclues ; l'efficacité des visites exclut les ventes hors dispositif (D12).
CREATE OR REPLACE VIEW olap.v_kpi_performance_chasseurs AS
SELECT dc.id_chasseur, dc.nom_complet, dc.statut_juridique, dc.type_habilitation, dc.capacite_max_mandats,
       count(DISTINCT fmc.id_mandat)                                                 AS nb_mandats_total,
       count(DISTINCT fmc.id_mandat) FILTER (WHERE fmc.statut_projete = 'actif')     AS nb_mandats_actifs,
       count(DISTINCT fmc.id_mandat) FILTER (WHERE fmc.est_succes)                   AS nb_mandats_clos_succes,
       count(DISTINCT fv.id_acte)                                                    AS nb_ventes_conclues,
       count(DISTINCT fv.id_acte) FILTER (WHERE fv.est_hors_dispositif)              AS nb_ventes_hors_dispositif,
       COALESCE(sum(fv.honoraires_agence_ht), 0.00)                                  AS ca_honoraires_generes_ht,
       COALESCE(sum(frc.montant_remuneration_ht) FILTER (WHERE NOT frc.est_annulee), 0.00) AS total_remuneration_ht,
       round(avg(frc.score_performance_global) FILTER (WHERE NOT frc.est_annulee), 2) AS score_moyen_global,
       round(avg(frc.score_s1_delai)        FILTER (WHERE NOT frc.est_annulee), 2)    AS score_moyen_delai,
       round(avg(frc.score_s2_exclusivite)  FILTER (WHERE NOT frc.est_annulee), 2)    AS score_moyen_exclusivite,
       round(avg(frc.score_s3_ventes)       FILTER (WHERE NOT frc.est_annulee), 2)    AS score_moyen_ventes,
       round(avg(frc.score_s4_mandats)      FILTER (WHERE NOT frc.est_annulee), 2)    AS score_moyen_mandats,
       round(avg(frc.score_s5_visites)      FILTER (WHERE NOT frc.est_annulee), 2)    AS score_moyen_visites,
       round(avg(frc.taux_final_pct)        FILTER (WHERE NOT frc.est_annulee), 2)    AS taux_commission_moyen_pct,
       round(avg(fv.nb_visites_effectuees)  FILTER (WHERE NOT fv.est_hors_dispositif), 1) AS visites_moyennes_par_vente,
       round(count(DISTINCT fmc.id_mandat) FILTER (WHERE fmc.est_succes)::numeric
             / NULLIF(count(DISTINCT fmc.id_mandat), 0) * 100, 2)                     AS taux_transformation_mandat_pct
FROM olap.dim_chasseur dc
LEFT JOIN olap.fait_mandat_cycle fmc           ON fmc.id_chasseur = dc.id_chasseur
LEFT JOIN olap.fait_vente fv                   ON fv.id_chasseur = dc.id_chasseur
LEFT JOIN olap.fait_remuneration_chasseur frc  ON frc.id_chasseur = dc.id_chasseur
GROUP BY dc.id_chasseur, dc.nom_complet, dc.statut_juridique, dc.type_habilitation, dc.capacite_max_mandats
ORDER BY ca_honoraires_generes_ht DESC, nb_mandats_total DESC;

-- KPI-1 : entonnoir des demandes par gestionnaire (délais calculés hors compte technique, ADR-036)
CREATE OR REPLACE VIEW olap.v_kpi_conversion_funnel AS
SELECT dg.id_gestionnaire, dg.nom_complet, dg.matricule, dg.equipe, dg.est_technique,
       count(fad.id_fait)                                                              AS total_demandes_recues,
       count(fad.id_fait) FILTER (WHERE fad.statut_demande = 'nouveau')                AS demandes_en_attente,
       count(fad.id_fait) FILTER (WHERE fad.statut_demande IN ('affecte','qualifie','en_recherche','close')) AS demandes_prises_en_charge,
       count(fad.id_fait) FILTER (WHERE fad.a_abouti_mandat)                           AS demandes_transformees_en_mandat,
       count(fad.id_fait) FILTER (WHERE fad.statut_demande = 'sans_suite')             AS demandes_sans_suite,
       round(count(fad.id_fait) FILTER (WHERE fad.a_abouti_mandat)::numeric / NULLIF(count(fad.id_fait), 0) * 100, 2) AS taux_conversion_mandat_pct,
       round(avg(fad.delai_affectation_heures)  FILTER (WHERE NOT dg.est_technique), 2) AS delai_moyen_affectation_heures_humain,
       round(avg(fad.delai_qualification_jours) FILTER (WHERE NOT dg.est_technique), 2) AS delai_moyen_qualification_jours_humain
FROM olap.dim_gestionnaire dg
LEFT JOIN olap.fait_activite_demande fad ON fad.id_gestionnaire = dg.id_gestionnaire
GROUP BY dg.id_gestionnaire, dg.nom_complet, dg.matricule, dg.equipe, dg.est_technique
ORDER BY dg.est_technique ASC, total_demandes_recues DESC;

-- KPI-2 : cycle de vie des mandats et mandats dormants (alerte 30 jours sans visite, D16)
CREATE OR REPLACE VIEW olap.v_kpi_mandats_cycle_vie AS
SELECT fmc.statut_projete,
       count(fmc.id_fait)                                                        AS nb_mandats,
       count(fmc.id_fait) FILTER (WHERE fmc.exclusif)                            AS nb_exclusifs,
       round(count(fmc.id_fait) FILTER (WHERE fmc.exclusif)::numeric / NULLIF(count(fmc.id_fait), 0) * 100, 2) AS taux_exclusivite_pct,
       count(fmc.id_fait) FILTER (WHERE fmc.statut_projete = 'actif' AND fmc.jours_sans_visite > 30) AS nb_mandats_dormants,
       round(avg(fmc.duree_effective_jours), 1)                                   AS duree_moyenne_jours,
       round(avg(fmc.nb_propositions), 1)                                         AS propositions_moyennes_par_mandat,
       round(avg(fmc.nb_visites), 1)                                              AS visites_moyennes_par_mandat
FROM olap.fait_mandat_cycle fmc
GROUP BY fmc.statut_projete
ORDER BY nb_mandats DESC;

-- KPI-5 : performance sectorielle (les ventes hors dispositif, sans bien connu, n'ont pas de zone)
CREATE OR REPLACE VIEW olap.v_kpi_analyse_geographique AS
SELECT dz.id_zone, dz.nom_zone, dz.ville, dz.departement, dz.pays, dz.code_iso_pays,
       count(DISTINCT fmc.id_mandat)                                        AS nb_mandats_engages,
       count(DISTINCT fv.id_acte)                                           AS nb_ventes_finalisees,
       COALESCE(sum(fv.montant_acte_net_vendeur), 0.00)                     AS volume_ventes_net_vendeur,
       COALESCE(sum(fv.honoraires_agence_ht), 0.00)                         AS ca_honoraires_ht,
       COALESCE(sum(fv.marge_brute_ht), 0.00)                               AS marge_brute_ht,
       round(count(DISTINCT fv.id_acte)::numeric / NULLIF(count(DISTINCT fmc.id_mandat), 0) * 100, 2) AS taux_succes_zone_pct
FROM olap.dim_zone dz
LEFT JOIN olap.fait_mandat_cycle fmc ON fmc.id_zone = dz.id_zone
LEFT JOIN olap.fait_vente fv         ON fv.id_zone = dz.id_zone
GROUP BY dz.id_zone, dz.nom_zone, dz.ville, dz.departement, dz.pays, dz.code_iso_pays
ORDER BY nb_mandats_engages DESC, ca_honoraires_ht DESC;
