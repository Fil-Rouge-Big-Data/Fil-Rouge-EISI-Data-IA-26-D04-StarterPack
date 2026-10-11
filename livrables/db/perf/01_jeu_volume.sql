-- ============================================================
-- 01_jeu_volume.sql — Jeu de données SYNTHÉTIQUE de volume pour la note d'indexation
-- À charger APRÈS 01_ddl.sql, 02_triggers_vues.sql et 03_seed.sql (réutilise le barème et le notaire du seed).
-- Volumes : 200 chasseurs, 20 gestionnaires, 20 000 clients / demandes / mandats, 50 zones,
--           100 000 biens et annonces, 60 000 propositions, 120 000 visites, 6 000 ventes rémunérées.
-- Déterministe (UUID = md5 d'une clé) et rejouable (ON CONFLICT DO NOTHING sur les clés naturelles).
-- Toutes les règles du socle s'appliquent (contraintes, triggers S24/S25/S26) : le jeu est VALIDE.
-- ============================================================
BEGIN;

-- Acteurs ---------------------------------------------------------------------------------------
INSERT INTO utilisateur (id_utilisateur, nom, prenom, email, password_hash, date_creation, actif)
SELECT md5('vol-chasseur-' || i)::uuid, 'Chasseur' || i, 'Vol', 'chasseur' || i || '@volume.test', 'x', '2023-01-01', true
FROM generate_series(1, 200) i ON CONFLICT DO NOTHING;
INSERT INTO chasseur (id_utilisateur, type_habilitation, numero_habilitation, date_validite_habilitation, organisme_delivrance,
                      organisme_garant, montant_garantie_financiere, numero_rcp, date_echeance_rcp, statut_juridique,
                      date_entree_reseau, capacite_max_mandats)
SELECT md5('vol-chasseur-' || i)::uuid, 'attestation', 'ATT-V-' || i, '2030-01-01', 'CCI', 'Garant', 120000,
       'RCP-V-' || i, '2030-01-01', 'salarie', '2023-01-01', 200
FROM generate_series(1, 200) i ON CONFLICT DO NOTHING;

INSERT INTO utilisateur (id_utilisateur, nom, prenom, email, password_hash, date_creation, actif)
SELECT md5('vol-gest-' || i)::uuid, 'Gestionnaire' || i, 'Vol', 'gest' || i || '@volume.test', 'x', '2023-01-01', true
FROM generate_series(1, 20) i ON CONFLICT DO NOTHING;
INSERT INTO gestionnaire (id_utilisateur, matricule, date_entree_fonction, capacite_max_leads)
SELECT md5('vol-gest-' || i)::uuid, 'VG-' || i, '2023-01-01', 5000 FROM generate_series(1, 20) i ON CONFLICT DO NOTHING;

INSERT INTO utilisateur (id_utilisateur, nom, prenom, email, password_hash, date_creation, actif)
SELECT md5('vol-client-' || i)::uuid, 'Client' || i, 'Vol', 'client' || i || '@volume.test', 'x', '2024-01-01', true
FROM generate_series(1, 20000) i ON CONFLICT DO NOTHING;
INSERT INTO client (id_utilisateur) SELECT md5('vol-client-' || i)::uuid FROM generate_series(1, 20000) i ON CONFLICT DO NOTHING;

-- Zones -----------------------------------------------------------------------------------------
INSERT INTO zone (id_zone, type_zone, pays, code_iso_pays, devise, ville, code_insee, secteur, code_postal)
SELECT md5('vol-zone-' || i)::uuid, 'secteur', 'France', 'FR', 'EUR', 'Ville' || ((i - 1) / 5 + 1),
       lpad((34000 + i)::text, 5, '0'), 'Secteur ' || i, lpad((34000 + i)::text, 5, '0')
FROM generate_series(1, 50) i ON CONFLICT DO NOTHING;

-- Demandes (gestionnaire, acquéreur principal, une version de critères) ----------------------------
INSERT INTO demande (id_demande, id_gestionnaire, date_depot, canal, date_consentement)
SELECT md5('vol-demande-' || i)::uuid, md5('vol-gest-' || (1 + i % 20))::uuid,
       date '2025-01-01' + (i % 540), 'autre', date '2025-01-01' + (i % 540)
FROM generate_series(1, 20000) i ON CONFLICT DO NOTHING;
INSERT INTO demande_acquereur (id_demande, id_client, qualite)
SELECT md5('vol-demande-' || i)::uuid, md5('vol-client-' || i)::uuid, 'principal' FROM generate_series(1, 20000) i ON CONFLICT DO NOTHING;
INSERT INTO demande_version (id_version, id_demande, id_modifie_par, no_version, date_creation, motif_evolution, type_bien, destination, budget_max)
SELECT md5('vol-version-' || i)::uuid, md5('vol-demande-' || i)::uuid, md5('vol-client-' || i)::uuid, 1,
       date '2025-01-01' + (i % 540), 'initiale', CASE WHEN i % 3 = 0 THEN 'maison' ELSE 'appartement' END, 'principale',
       150000 + (i % 15) * 50000
FROM generate_series(1, 20000) i ON CONFLICT DO NOTHING;

-- Mandats (un par demande, signé le jour du dépôt + 7 ; 60 % exclusifs) ----------------------------
INSERT INTO mandat (id_mandat, id_demande, id_version_contractuelle, id_chasseur, id_signataire, numero_registre, date_signature,
                    mode_signature, date_debut, exclusif, taux_honoraires, base_honoraires, taux_tva, qualite_signataire)
SELECT md5('vol-mandat-' || i)::uuid, md5('vol-demande-' || i)::uuid, md5('vol-version-' || i)::uuid,
       md5('vol-chasseur-' || (1 + i % 200))::uuid, md5('vol-client-' || i)::uuid, 'REG-V-' || i,
       date '2025-01-08' + (i % 540), 'presentiel', date '2025-01-08' + (i % 540), (i % 5 < 3), 3.0, 'TTC', 20.0, 'nom_propre'
FROM generate_series(1, 20000) i ON CONFLICT DO NOTHING;

-- Biens et annonces -------------------------------------------------------------------------------
INSERT INTO bien (id_bien, id_zone, type_bien, surface, nb_pieces)
SELECT md5('vol-bien-' || i)::uuid, md5('vol-zone-' || (1 + i % 50))::uuid,
       CASE WHEN i % 3 = 0 THEN 'maison' ELSE 'appartement' END, 20 + (i % 180), 1 + (i % 6)
FROM generate_series(1, 100000) i ON CONFLICT DO NOTHING;
INSERT INTO annonce (id_annonce, id_bien, source, reference_source, prix, date_ingestion, date_derniere_vue, statut)
SELECT md5('vol-annonce-' || i)::uuid, md5('vol-bien-' || i)::uuid, 'seloger', 'VOL-' || i, 100000 + (i % 80) * 10000,
       timestamp '2025-01-01' + (i % 540) * interval '1 day', timestamp '2026-07-01', CASE WHEN i % 10 = 0 THEN 'retiree' ELSE 'active' END
FROM generate_series(1, 100000) i ON CONFLICT DO NOTHING;

-- Propositions (3 par demande en moyenne : bien i, demande i % 20000) -----------------------------
INSERT INTO proposition (id_proposition, id_demande, id_version, id_bien, id_annonce_reference, id_mandat, date_matching, statut)
SELECT md5('vol-prop-' || i)::uuid, md5('vol-demande-' || (1 + i % 20000))::uuid, md5('vol-version-' || (1 + i % 20000))::uuid,
       md5('vol-bien-' || i)::uuid, md5('vol-annonce-' || i)::uuid, md5('vol-mandat-' || (1 + i % 20000))::uuid,
       date '2025-01-15' + ((1 + i % 20000) % 540), 'soumis'
FROM generate_series(1, 60000) i ON CONFLICT DO NOTHING;

-- Visites : chaque proposition visitée une fois par l'acquéreur ET le chasseur (même rendez-vous, D10)
INSERT INTO visite (id_visite, id_proposition, id_visiteur, date_visite, realisee)
SELECT md5('vol-visite-c-' || i)::uuid, md5('vol-prop-' || i)::uuid, md5('vol-client-' || (1 + i % 20000))::uuid,
       date '2025-01-20' + ((1 + i % 20000) % 540), true
FROM generate_series(1, 60000) i ON CONFLICT DO NOTHING;
INSERT INTO visite (id_visite, id_proposition, id_visiteur, date_visite, realisee)
SELECT md5('vol-visite-h-' || i)::uuid, md5('vol-prop-' || i)::uuid, md5('vol-chasseur-' || (1 + (1 + i % 20000) % 200))::uuid,
       date '2025-01-20' + ((1 + i % 20000) % 540), true
FROM generate_series(1, 60000) i ON CONFLICT DO NOTHING;

-- Ventes : 6 000 propositions (i = 1..6000, donc demande i, mandat i) -> offre acceptée -> compromis -> acte -> rémunération
INSERT INTO offre_acquisition (id_offre, id_proposition, camp, saisi_par, montant, date_signature, date_validite, date_reponse, statut)
SELECT md5('vol-offre-' || i)::uuid, md5('vol-prop-' || i)::uuid, 'acquereur', 'chasseur', 100000 + (i % 80) * 10000,
       date '2025-02-01' + (i % 540), date '2025-02-15' + (i % 540), date '2025-02-03' + (i % 540), 'acceptee'
FROM generate_series(1, 6000) i ON CONFLICT DO NOTHING;
INSERT INTO compromis (id_compromis, id_offre, id_notaire, date_signature, fin_retractation)
SELECT md5('vol-compromis-' || i)::uuid, md5('vol-offre-' || i)::uuid, '07a00000-0000-0000-0000-000000000001',
       date '2025-02-20' + (i % 540), date '2025-03-02' + (i % 540)
FROM generate_series(1, 6000) i ON CONFLICT DO NOTHING;
-- acte = mandat.date_debut + 120 jours : la chaîne du mandat est en vigueur (S26). La proposition i appartient
-- à la demande / au mandat (1 + i % 20000) : l'acte et la rémunération s'alignent dessus (garde S25).
INSERT INTO acte (id_acte, id_compromis, date_signature, montant_vente, honoraires_fixe, honoraires_taux, honoraires_encaisses, date_encaissement)
SELECT md5('vol-acte-' || i)::uuid, md5('vol-compromis-' || i)::uuid, date '2025-01-08' + ((1 + i % 20000) % 540) + 120,
       100000 + (i % 80) * 10000, 3000, 2.5, true, date '2025-01-08' + ((1 + i % 20000) % 540) + 125
FROM generate_series(1, 6000) i ON CONFLICT DO NOTHING;
INSERT INTO remuneration_chasseur (id_remuneration, id_acte, id_chasseur, id_mandat, honoraires, score_delai, score_exclusivite, score_ventes,
                                   score_mandats, score_visites, score_performance, taux_base, majoration_anciennete, modulation_performance,
                                   taux_final, montant, id_bareme_applique, date_calcul)
SELECT md5('vol-remun-' || i)::uuid, md5('vol-acte-' || i)::uuid, md5('vol-chasseur-' || (1 + (1 + i % 20000) % 200))::uuid, md5('vol-mandat-' || (1 + i % 20000))::uuid,
       3000 + (100000 + (i % 80) * 10000) * 0.025, 80, 100, 80, 70, 80, 80, 45, 5, 1.0, 47.0,
       round((3000 + (100000 + (i % 80) * 10000) * 0.025) * 0.47, 2), 'b0000000-0000-0000-0000-000000000001',
       (date '2025-01-08' + ((1 + i % 20000) % 540) + 120)::timestamptz
FROM generate_series(1, 6000) i ON CONFLICT DO NOTHING;

COMMIT;
ANALYZE;
