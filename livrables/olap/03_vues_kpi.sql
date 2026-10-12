-- ============================================================
-- 03_vues_kpi.sql — Vues de restitution (Power BI), les 5 indicateurs de l'étude d'opportunité (§2.3)
-- KPI-1 entonnoir · KPI-2 délais et trésorerie · KPI-3 efficacité des visites · KPI-4 rentabilité et
-- rémunération · KPI-5 performance sectorielle. Source : schéma olap (01_schema_etoile.sql).
--
-- Règle d'or (revue de la PR #15) : JAMAIS deux tables de faits jointes directement sur une même clé
-- de dimension — chaque vente serait répétée autant de fois que le chasseur a de mandats, et les sommes
-- seraient multipliées. Chaque fait est agrégé dans sa propre CTE, puis les agrégats sont joints.
-- Le test test_vues_sans_multiplication rapproche les sommes des vues des sommes brutes des faits.
-- ============================================================

-- KPI-4 (a) : chiffre d'affaires et marge, par mois (un seul fait : fait_vente)
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
-- Trois faits, trois agrégats séparés, joints ensuite sur le chasseur.
-- Les rémunérations annulées sont exclues ; l'efficacité des visites exclut les ventes hors dispositif (D12).
CREATE OR REPLACE VIEW olap.v_kpi_performance_chasseurs AS
WITH mandats AS (
    SELECT id_chasseur,
           count(*)                                              AS nb_mandats_total,
           count(*) FILTER (WHERE statut_projete = 'actif')      AS nb_mandats_actifs,
           count(*) FILTER (WHERE est_succes)                    AS nb_mandats_clos_succes
    FROM olap.fait_mandat_cycle GROUP BY id_chasseur
), ventes AS (
    SELECT id_chasseur,
           count(*)                                              AS nb_ventes_conclues,
           count(*) FILTER (WHERE est_hors_dispositif)           AS nb_ventes_hors_dispositif,
           sum(honoraires_agence_ht)                             AS ca_honoraires_generes_ht,
           avg(nb_visites_effectuees) FILTER (WHERE NOT est_hors_dispositif) AS visites_moyennes_par_vente
    FROM olap.fait_vente GROUP BY id_chasseur
), remunerations AS (
    SELECT id_chasseur,
           sum(montant_remuneration_ht)                          AS total_remuneration_ht,
           avg(score_performance_global)                         AS score_moyen_global,
           avg(score_s1_delai)                                   AS score_moyen_delai,
           avg(score_s2_exclusivite)                             AS score_moyen_exclusivite,
           avg(score_s3_ventes)                                  AS score_moyen_ventes,
           avg(score_s4_mandats)                                 AS score_moyen_mandats,
           avg(score_s5_visites)                                 AS score_moyen_visites,
           avg(taux_final_pct)                                   AS taux_commission_moyen_pct
    FROM olap.fait_remuneration_chasseur WHERE NOT est_annulee GROUP BY id_chasseur
)
SELECT dc.id_chasseur, dc.nom_complet, dc.statut_juridique, dc.type_habilitation, dc.capacite_max_mandats,
       COALESCE(m.nb_mandats_total, 0)                 AS nb_mandats_total,
       COALESCE(m.nb_mandats_actifs, 0)                AS nb_mandats_actifs,
       COALESCE(m.nb_mandats_clos_succes, 0)           AS nb_mandats_clos_succes,
       COALESCE(v.nb_ventes_conclues, 0)               AS nb_ventes_conclues,
       COALESCE(v.nb_ventes_hors_dispositif, 0)        AS nb_ventes_hors_dispositif,
       COALESCE(v.ca_honoraires_generes_ht, 0.00)      AS ca_honoraires_generes_ht,
       COALESCE(r.total_remuneration_ht, 0.00)         AS total_remuneration_ht,
       round(r.score_moyen_global, 2)                  AS score_moyen_global,
       round(r.score_moyen_delai, 2)                   AS score_moyen_delai,
       round(r.score_moyen_exclusivite, 2)             AS score_moyen_exclusivite,
       round(r.score_moyen_ventes, 2)                  AS score_moyen_ventes,
       round(r.score_moyen_mandats, 2)                 AS score_moyen_mandats,
       round(r.score_moyen_visites, 2)                 AS score_moyen_visites,
       round(r.taux_commission_moyen_pct, 2)           AS taux_commission_moyen_pct,
       round(v.visites_moyennes_par_vente, 1)          AS visites_moyennes_par_vente,
       round(COALESCE(m.nb_mandats_clos_succes, 0)::numeric / NULLIF(m.nb_mandats_total, 0) * 100, 2) AS taux_transformation_mandat_pct
FROM olap.dim_chasseur dc
LEFT JOIN mandats m        ON m.id_chasseur = dc.id_chasseur
LEFT JOIN ventes v         ON v.id_chasseur = dc.id_chasseur
LEFT JOIN remunerations r  ON r.id_chasseur = dc.id_chasseur
ORDER BY ca_honoraires_generes_ht DESC, nb_mandats_total DESC;

-- KPI-1 : entonnoir des demandes par gestionnaire (un seul fait ; délais hors compte technique, ADR-036)
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

-- KPI-2 : cycle de vie des mandats et mandats dormants (un seul fait ; alerte 30 jours sans visite, D16)
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

-- KPI-5 : performance sectorielle. Deux notions de zone, séparées explicitement :
--   - la zone RECHERCHÉE (première zone ciblée par le mandat) : mandats engagés et taux de succès des mandats ;
--   - la zone DU BIEN vendu : ventes, volume, honoraires et marge (NULL pour une vente hors dispositif).
-- Le taux de succès compare des mandats et des ventes sur la MÊME notion (zone recherchée).
CREATE OR REPLACE VIEW olap.v_kpi_analyse_geographique AS
WITH mandats AS (
    SELECT id_zone, count(*) AS nb_mandats_engages
    FROM olap.fait_mandat_cycle WHERE id_zone IS NOT NULL GROUP BY id_zone
), ventes_zone_recherche AS (
    SELECT id_zone_recherche AS id_zone, count(*) AS nb_ventes_mandats_zone
    FROM olap.fait_vente WHERE id_zone_recherche IS NOT NULL GROUP BY id_zone_recherche
), ventes_zone_bien AS (
    SELECT id_zone,
           count(*)                           AS nb_ventes_finalisees,
           sum(montant_acte_net_vendeur)      AS volume_ventes_net_vendeur,
           sum(honoraires_agence_ht)          AS ca_honoraires_ht,
           sum(marge_brute_ht)                AS marge_brute_ht
    FROM olap.fait_vente WHERE id_zone IS NOT NULL GROUP BY id_zone
)
SELECT dz.id_zone, dz.nom_zone, dz.ville, dz.departement, dz.pays, dz.code_iso_pays,
       COALESCE(m.nb_mandats_engages, 0)              AS nb_mandats_engages,          -- zone recherchée
       COALESCE(vr.nb_ventes_mandats_zone, 0)         AS nb_ventes_mandats_zone,      -- zone recherchée
       round(COALESCE(vr.nb_ventes_mandats_zone, 0)::numeric / NULLIF(m.nb_mandats_engages, 0) * 100, 2) AS taux_succes_zone_pct,
       COALESCE(vb.nb_ventes_finalisees, 0)           AS nb_ventes_finalisees,        -- zone du bien
       COALESCE(vb.volume_ventes_net_vendeur, 0.00)   AS volume_ventes_net_vendeur,
       COALESCE(vb.ca_honoraires_ht, 0.00)            AS ca_honoraires_ht,
       COALESCE(vb.marge_brute_ht, 0.00)              AS marge_brute_ht
FROM olap.dim_zone dz
LEFT JOIN mandats m                ON m.id_zone = dz.id_zone
LEFT JOIN ventes_zone_recherche vr ON vr.id_zone = dz.id_zone
LEFT JOIN ventes_zone_bien vb      ON vb.id_zone = dz.id_zone
ORDER BY nb_mandats_engages DESC, ca_honoraires_ht DESC;
