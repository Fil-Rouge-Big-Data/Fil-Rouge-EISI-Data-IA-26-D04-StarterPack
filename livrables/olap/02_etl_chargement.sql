-- ============================================================
-- 02_etl_chargement.sql — Alimentation de l'entrepôt (ELT en SQL, UPSERT idempotent)
-- Source : OLTP v8.42. Rejouable : chaque table est chargée par INSERT ... ON CONFLICT.
-- Lit les VUES d'état de l'OLTP (v_mandat, v_demande, v_acte_mandat, v_honoraires,
-- v_version_courante) : jamais de statut recalculé ici (ADR-048, ADR-051, RB1).
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. DIMENSIONS
-- ------------------------------------------------------------

-- A. Temps : calendrier 2020-2030
INSERT INTO olap.dim_temps (id_temps, date_jour, annee, trimestre, mois, nom_mois,
                            jour, jour_semaine, nom_jour, semaine_annee, est_weekend, est_ouvre)
SELECT to_char(d, 'YYYYMMDD')::integer,
       d::date,
       EXTRACT(YEAR FROM d)::integer,
       EXTRACT(QUARTER FROM d)::integer,
       EXTRACT(MONTH FROM d)::integer,
       (ARRAY['Janvier','Février','Mars','Avril','Mai','Juin','Juillet','Août','Septembre','Octobre','Novembre','Décembre'])[EXTRACT(MONTH FROM d)::integer],
       EXTRACT(DAY FROM d)::integer,
       EXTRACT(ISODOW FROM d)::integer,
       (ARRAY['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'])[EXTRACT(ISODOW FROM d)::integer],
       EXTRACT(WEEK FROM d)::integer,
       EXTRACT(ISODOW FROM d)::integer IN (6, 7),
       EXTRACT(ISODOW FROM d)::integer BETWEEN 1 AND 5
FROM generate_series('2020-01-01'::date, '2030-12-31'::date, '1 day'::interval) AS d
ON CONFLICT (id_temps) DO NOTHING;

-- B. Chasseur (habilitation Hoguet, ADR-046 ; pas d'e-mail dans l'entrepôt)
INSERT INTO olap.dim_chasseur (id_chasseur, nom, prenom, nom_complet, statut_juridique, type_habilitation,
                               numero_habilitation, organisme_delivrance, date_validite_habilitation,
                               date_entree_reseau, date_sortie_reseau, capacite_max_mandats, est_actif)
SELECT c.id_utilisateur, u.nom, u.prenom, u.prenom || ' ' || u.nom, c.statut_juridique, c.type_habilitation,
       c.numero_habilitation, c.organisme_delivrance, c.date_validite_habilitation,
       c.date_entree_reseau, c.date_sortie_reseau, c.capacite_max_mandats,
       (u.actif AND c.date_sortie_reseau IS NULL)
FROM public.chasseur c
JOIN public.utilisateur u ON u.id_utilisateur = c.id_utilisateur
ON CONFLICT (id_chasseur) DO UPDATE SET
    nom = EXCLUDED.nom, prenom = EXCLUDED.prenom, nom_complet = EXCLUDED.nom_complet,
    statut_juridique = EXCLUDED.statut_juridique, type_habilitation = EXCLUDED.type_habilitation,
    numero_habilitation = EXCLUDED.numero_habilitation, organisme_delivrance = EXCLUDED.organisme_delivrance,
    date_validite_habilitation = EXCLUDED.date_validite_habilitation, date_entree_reseau = EXCLUDED.date_entree_reseau,
    date_sortie_reseau = EXCLUDED.date_sortie_reseau, capacite_max_mandats = EXCLUDED.capacite_max_mandats,
    est_actif = EXCLUDED.est_actif;

-- C. Gestionnaire (compte technique SYS-MIGRATION isolé, ADR-036)
INSERT INTO olap.dim_gestionnaire (id_gestionnaire, matricule, nom, prenom, nom_complet, equipe, capacite_max_leads, est_technique)
SELECT g.id_utilisateur, g.matricule, u.nom, u.prenom, u.prenom || ' ' || u.nom, g.equipe, g.capacite_max_leads,
       (g.matricule = 'SYS-MIGRATION')
FROM public.gestionnaire g
JOIN public.utilisateur u ON u.id_utilisateur = g.id_utilisateur
ON CONFLICT (id_gestionnaire) DO UPDATE SET
    matricule = EXCLUDED.matricule, nom = EXCLUDED.nom, prenom = EXCLUDED.prenom, nom_complet = EXCLUDED.nom_complet,
    equipe = EXCLUDED.equipe, capacite_max_leads = EXCLUDED.capacite_max_leads, est_technique = EXCLUDED.est_technique;

-- D. Zone
INSERT INTO olap.dim_zone (id_zone, type_zone, nom_zone, ville, secteur, code_postal, code_insee, departement, pays, code_iso_pays, devise)
SELECT z.id_zone, z.type_zone,
       COALESCE(z.secteur || ' (' || z.ville || ')', z.ville),
       z.ville, z.secteur, z.code_postal, z.code_insee,
       CASE WHEN z.code_iso_pays = 'FR' THEN left(COALESCE(z.code_insee, z.code_postal), 2) END,
       z.pays, z.code_iso_pays, z.devise
FROM public.zone z
ON CONFLICT (id_zone) DO UPDATE SET
    type_zone = EXCLUDED.type_zone, nom_zone = EXCLUDED.nom_zone, ville = EXCLUDED.ville, secteur = EXCLUDED.secteur,
    code_postal = EXCLUDED.code_postal, code_insee = EXCLUDED.code_insee, departement = EXCLUDED.departement,
    pays = EXCLUDED.pays, code_iso_pays = EXCLUDED.code_iso_pays, devise = EXCLUDED.devise;

-- E. Bien
INSERT INTO olap.dim_bien (id_bien, type_bien, tranche_surface, surface, nb_pieces, nb_chambres, dpe, a_ascenseur, a_balcon_ou_terrasse, a_parking)
SELECT b.id_bien, b.type_bien,
       CASE WHEN b.surface IS NULL THEN 'Non renseignée'
            WHEN b.surface < 40 THEN '< 40 m²' WHEN b.surface < 70 THEN '40-70 m²'
            WHEN b.surface < 100 THEN '70-100 m²' ELSE '> 100 m²' END,
       b.surface, b.nb_pieces, b.nb_chambres, b.dpe,
       COALESCE(b.a_ascenseur, false), COALESCE(b.a_balcon OR b.a_terrasse, false), COALESCE(b.a_parking, false)
FROM public.bien b
ON CONFLICT (id_bien) DO UPDATE SET
    type_bien = EXCLUDED.type_bien, tranche_surface = EXCLUDED.tranche_surface, surface = EXCLUDED.surface,
    nb_pieces = EXCLUDED.nb_pieces, nb_chambres = EXCLUDED.nb_chambres, dpe = EXCLUDED.dpe,
    a_ascenseur = EXCLUDED.a_ascenseur, a_balcon_ou_terrasse = EXCLUDED.a_balcon_ou_terrasse, a_parking = EXCLUDED.a_parking;

-- F. Client : tranches seulement (RB4, k-anonymat), statut d'anonymisation reflété (ADR-043)
INSERT INTO olap.dim_client (id_client, tranche_budget, destination, primo_accedant, statut_financement, tranche_age, est_anonymise_rgpd)
SELECT c.id_utilisateur,
       CASE WHEN dv.budget_max IS NULL THEN 'Non défini'
            WHEN dv.budget_max < 200000 THEN '< 200 k€' WHEN dv.budget_max < 350000 THEN '200-350 k€'
            WHEN dv.budget_max < 500000 THEN '350-500 k€' WHEN dv.budget_max < 750000 THEN '500-750 k€'
            ELSE '> 750 k€' END,
       COALESCE(dv.destination, 'principale'),
       c.primo_accedant,
       d.statut_financement,
       CASE WHEN c.annee_naissance IS NULL THEN 'Inconnu'
            WHEN EXTRACT(YEAR FROM public.date_reference()) - c.annee_naissance < 30 THEN '< 30 ans'
            WHEN EXTRACT(YEAR FROM public.date_reference()) - c.annee_naissance < 45 THEN '30-45 ans'
            WHEN EXTRACT(YEAR FROM public.date_reference()) - c.annee_naissance < 60 THEN '45-60 ans'
            ELSE '> 60 ans' END,
       (u.date_anonymisation IS NOT NULL)
FROM public.client c
JOIN public.utilisateur u ON u.id_utilisateur = c.id_utilisateur
LEFT JOIN LATERAL (SELECT da.id_demande FROM public.demande_acquereur da
                   WHERE da.id_client = c.id_utilisateur ORDER BY (da.qualite = 'principal') DESC LIMIT 1) da_first ON true
LEFT JOIN public.demande d ON d.id_demande = da_first.id_demande
LEFT JOIN public.v_version_courante dv ON dv.id_demande = d.id_demande
ON CONFLICT (id_client) DO UPDATE SET
    tranche_budget = EXCLUDED.tranche_budget, destination = EXCLUDED.destination, primo_accedant = EXCLUDED.primo_accedant,
    statut_financement = EXCLUDED.statut_financement, tranche_age = EXCLUDED.tranche_age, est_anonymise_rgpd = EXCLUDED.est_anonymise_rgpd;

-- ------------------------------------------------------------
-- 2. FAITS
-- ------------------------------------------------------------

-- Fait 3 : cycle de vie des mandats (état lu dans v_mandat, jamais recalculé)
INSERT INTO olap.fait_mandat_cycle (id_mandat, id_date_signature, id_date_fin_theorique, id_chasseur, id_zone, id_client,
                                    id_mandat_precedent, exclusif, statut_projete, est_succes, est_renouvele, est_resilie, est_echu,
                                    duree_effective_jours, nb_propositions, nb_visites, jours_sans_visite)
SELECT vm.id_mandat,
       to_char(vm.date_signature, 'YYYYMMDD')::integer,
       to_char(vm.date_fin, 'YYYYMMDD')::integer,
       vm.id_chasseur,
       (SELECT vz.id_zone FROM public.version_zone vz WHERE vz.id_version = vm.id_version_contractuelle LIMIT 1),
       (SELECT da.id_client FROM public.demande_acquereur da WHERE da.id_demande = vm.id_demande AND da.qualite = 'principal' LIMIT 1),
       vm.id_mandat_precedent,
       vm.exclusif,
       vm.statut_calcule,
       vm.statut_calcule = 'clos_succes',
       vm.statut_calcule = 'renouvele',
       vm.statut_calcule = 'resilie',
       vm.statut_calcule = 'echu',
       GREATEST(0, COALESCE(vm.date_resiliation, LEAST(vm.date_fin, public.date_reference())) - vm.date_signature)::integer,
       (SELECT count(*)::integer FROM public.proposition p WHERE p.id_mandat = vm.id_mandat),
       olap.f_nb_visites(vm.id_mandat, NULL, false),
       CASE WHEN vm.statut_calcule = 'actif' THEN
            (public.date_reference() - COALESCE(
                (SELECT max(v.date_visite) FROM public.visite v JOIN public.proposition p ON p.id_proposition = v.id_proposition
                 WHERE p.id_mandat = vm.id_mandat AND v.realisee), vm.date_signature))::integer END
FROM public.v_mandat vm
WHERE EXISTS (SELECT 1 FROM public.demande_acquereur da WHERE da.id_demande = vm.id_demande AND da.qualite = 'principal')
ON CONFLICT (id_mandat) DO UPDATE SET
    id_date_signature = EXCLUDED.id_date_signature, id_date_fin_theorique = EXCLUDED.id_date_fin_theorique,
    id_chasseur = EXCLUDED.id_chasseur, id_zone = EXCLUDED.id_zone, id_client = EXCLUDED.id_client,
    id_mandat_precedent = EXCLUDED.id_mandat_precedent, exclusif = EXCLUDED.exclusif, statut_projete = EXCLUDED.statut_projete,
    est_succes = EXCLUDED.est_succes, est_renouvele = EXCLUDED.est_renouvele, est_resilie = EXCLUDED.est_resilie,
    est_echu = EXCLUDED.est_echu, duree_effective_jours = EXCLUDED.duree_effective_jours,
    nb_propositions = EXCLUDED.nb_propositions, nb_visites = EXCLUDED.nb_visites, jours_sans_visite = EXCLUDED.jours_sans_visite;

-- Fait 4 : activité des demandes (état lu dans v_demande)
INSERT INTO olap.fait_activite_demande (id_demande, id_date_depot, id_date_affectation, id_gestionnaire, id_chasseur, id_client,
                                        canal, statut_demande, delai_affectation_heures, delai_qualification_jours,
                                        a_abouti_mandat, nb_versions_criteres)
SELECT d.id_demande,
       to_char(d.date_depot, 'YYYYMMDD')::integer,
       CASE WHEN d.date_affectation IS NOT NULL THEN to_char(d.date_affectation, 'YYYYMMDD')::integer END,
       d.id_gestionnaire,
       d.id_chasseur,
       (SELECT da.id_client FROM public.demande_acquereur da WHERE da.id_demande = d.id_demande AND da.qualite = 'principal' LIMIT 1),
       d.canal,
       d.statut_calcule,
       CASE WHEN d.date_affectation IS NOT NULL THEN round((EXTRACT(EPOCH FROM (d.date_affectation - d.date_depot)) / 3600.0)::numeric, 2) END,
       CASE WHEN d.date_qualification IS NOT NULL AND d.date_affectation IS NOT NULL
            THEN round((EXTRACT(EPOCH FROM (d.date_qualification - d.date_affectation)) / 86400.0)::numeric, 2) END,
       EXISTS (SELECT 1 FROM public.mandat m WHERE m.id_demande = d.id_demande),
       (SELECT count(*)::integer FROM public.demande_version dv WHERE dv.id_demande = d.id_demande)
FROM public.v_demande d
WHERE d.id_gestionnaire IS NOT NULL
  AND EXISTS (SELECT 1 FROM public.demande_acquereur da WHERE da.id_demande = d.id_demande AND da.qualite = 'principal')
ON CONFLICT (id_demande) DO UPDATE SET
    id_date_depot = EXCLUDED.id_date_depot, id_date_affectation = EXCLUDED.id_date_affectation,
    id_gestionnaire = EXCLUDED.id_gestionnaire, id_chasseur = EXCLUDED.id_chasseur, id_client = EXCLUDED.id_client,
    canal = EXCLUDED.canal, statut_demande = EXCLUDED.statut_demande,
    delai_affectation_heures = EXCLUDED.delai_affectation_heures, delai_qualification_jours = EXCLUDED.delai_qualification_jours,
    a_abouti_mandat = EXCLUDED.a_abouti_mandat, nb_versions_criteres = EXCLUDED.nb_versions_criteres;

-- Fait 1 : ventes. Deux origines (ADR-053) : chaîne de vente (bien connu) ou hors dispositif (bien inconnu).
-- Mandat et chasseur = chaîne en vigueur à l'acte (v_acte_mandat, D13) ; délai S1 depuis le mandat initial.
INSERT INTO olap.fait_vente (id_acte, id_date_acte, id_chasseur, id_gestionnaire, id_zone, id_client, id_bien,
                             id_mandat_en_vigueur, id_mandat_initial, est_hors_dispositif, source_information, est_mandat_exclusif,
                             montant_acte_net_vendeur, honoraires_agence_ht, remuneration_chasseur_ht, marge_brute_ht, taux_marge_pct,
                             delai_depot_a_acte_jours, delai_mandat_a_acte_jours, nb_visites_effectuees, nb_propositions_recues)
SELECT a.id_acte,
       to_char(a.date_signature, 'YYYYMMDD')::integer,
       mv.id_chasseur,
       d.id_gestionnaire,
       b.id_zone,
       da.id_client,
       b.id_bien,
       am.id_mandat_en_vigueur,
       am.id_mandat_initial,
       am.hors_dispositif,
       a.source_information,
       mv.exclusif,
       a.montant_vente,
       vh.honoraires_total,
       COALESCE(rc.montant, 0.00),
       vh.honoraires_total - COALESCE(rc.montant, 0.00),
       round(((vh.honoraires_total - COALESCE(rc.montant, 0.00)) / NULLIF(vh.honoraires_total, 0) * 100)::numeric, 2),
       (a.date_signature - d.date_depot::date)::integer,
       (a.date_signature - mi.date_signature)::integer,
       olap.f_nb_visites(am.id_mandat_en_vigueur, a.date_signature, true),
       (SELECT count(*)::integer FROM public.proposition p3 WHERE p3.id_mandat IN (SELECT public.f_chaine_mandats(am.id_mandat_en_vigueur)))
FROM public.acte a
JOIN public.v_acte_mandat am     ON am.id_acte = a.id_acte
JOIN public.mandat mv            ON mv.id_mandat = am.id_mandat_en_vigueur
JOIN public.mandat mi            ON mi.id_mandat = am.id_mandat_initial
JOIN public.demande d            ON d.id_demande = mv.id_demande
JOIN public.demande_acquereur da ON da.id_demande = d.id_demande AND da.qualite = 'principal'
JOIN public.v_honoraires vh      ON vh.id_acte = a.id_acte
LEFT JOIN public.compromis co        ON co.id_compromis = a.id_compromis
LEFT JOIN public.offre_acquisition o ON o.id_offre = co.id_offre
LEFT JOIN public.proposition p       ON p.id_proposition = o.id_proposition
LEFT JOIN public.bien b              ON b.id_bien = p.id_bien
LEFT JOIN public.remuneration_chasseur rc ON rc.id_acte = a.id_acte AND rc.date_annulation IS NULL
ON CONFLICT (id_acte) DO UPDATE SET
    id_date_acte = EXCLUDED.id_date_acte, id_chasseur = EXCLUDED.id_chasseur, id_gestionnaire = EXCLUDED.id_gestionnaire,
    id_zone = EXCLUDED.id_zone, id_client = EXCLUDED.id_client, id_bien = EXCLUDED.id_bien,
    id_mandat_en_vigueur = EXCLUDED.id_mandat_en_vigueur, id_mandat_initial = EXCLUDED.id_mandat_initial,
    est_hors_dispositif = EXCLUDED.est_hors_dispositif, source_information = EXCLUDED.source_information,
    est_mandat_exclusif = EXCLUDED.est_mandat_exclusif, montant_acte_net_vendeur = EXCLUDED.montant_acte_net_vendeur,
    honoraires_agence_ht = EXCLUDED.honoraires_agence_ht, remuneration_chasseur_ht = EXCLUDED.remuneration_chasseur_ht,
    marge_brute_ht = EXCLUDED.marge_brute_ht, taux_marge_pct = EXCLUDED.taux_marge_pct,
    delai_depot_a_acte_jours = EXCLUDED.delai_depot_a_acte_jours, delai_mandat_a_acte_jours = EXCLUDED.delai_mandat_a_acte_jours,
    nb_visites_effectuees = EXCLUDED.nb_visites_effectuees, nb_propositions_recues = EXCLUDED.nb_propositions_recues;

-- Fait 2 : rémunération gelée (copie des composantes figées, ADR-049 / ADR-052). Zone via la chaîne de vente (NULL hors dispositif).
INSERT INTO olap.fait_remuneration_chasseur (id_remuneration, id_date_calcul, id_date_acte, id_chasseur, id_zone, id_acte, est_hors_dispositif,
                                             honoraires_assiette, score_s1_delai, score_s2_exclusivite, score_s3_ventes, score_s4_mandats,
                                             score_s5_visites, score_performance_global, taux_base_pct, majoration_anciennete_pct,
                                             modulation_performance_pct, taux_final_pct, montant_remuneration_ht, est_annulee)
SELECT rc.id_remuneration,
       to_char(rc.date_calcul, 'YYYYMMDD')::integer,
       to_char(a.date_signature, 'YYYYMMDD')::integer,
       rc.id_chasseur,
       b.id_zone,
       rc.id_acte,
       am.hors_dispositif,
       rc.honoraires,
       rc.score_delai, rc.score_exclusivite, rc.score_ventes, rc.score_mandats, rc.score_visites, rc.score_performance,
       rc.taux_base, rc.majoration_anciennete, rc.modulation_performance, rc.taux_final, rc.montant,
       (rc.date_annulation IS NOT NULL)
FROM public.remuneration_chasseur rc
JOIN public.acte a               ON a.id_acte = rc.id_acte
JOIN public.v_acte_mandat am     ON am.id_acte = a.id_acte
LEFT JOIN public.compromis co        ON co.id_compromis = a.id_compromis
LEFT JOIN public.offre_acquisition o ON o.id_offre = co.id_offre
LEFT JOIN public.proposition p       ON p.id_proposition = o.id_proposition
LEFT JOIN public.bien b              ON b.id_bien = p.id_bien
ON CONFLICT (id_remuneration) DO UPDATE SET
    id_date_calcul = EXCLUDED.id_date_calcul, id_date_acte = EXCLUDED.id_date_acte, id_chasseur = EXCLUDED.id_chasseur,
    id_zone = EXCLUDED.id_zone, id_acte = EXCLUDED.id_acte, est_hors_dispositif = EXCLUDED.est_hors_dispositif,
    honoraires_assiette = EXCLUDED.honoraires_assiette, score_s1_delai = EXCLUDED.score_s1_delai,
    score_s2_exclusivite = EXCLUDED.score_s2_exclusivite, score_s3_ventes = EXCLUDED.score_s3_ventes,
    score_s4_mandats = EXCLUDED.score_s4_mandats, score_s5_visites = EXCLUDED.score_s5_visites,
    score_performance_global = EXCLUDED.score_performance_global, taux_base_pct = EXCLUDED.taux_base_pct,
    majoration_anciennete_pct = EXCLUDED.majoration_anciennete_pct, modulation_performance_pct = EXCLUDED.modulation_performance_pct,
    taux_final_pct = EXCLUDED.taux_final_pct, montant_remuneration_ht = EXCLUDED.montant_remuneration_ht, est_annulee = EXCLUDED.est_annulee;

COMMIT;
