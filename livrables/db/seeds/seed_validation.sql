-- =============================================================================
--  Jeu de donnees de validation — schema chasse
--  NON REJOUABLE : les identifiants 1 a 4 sont codes en dur alors que les
--  cles primaires sont GENERATED ALWAYS AS IDENTITY. A n'executer que sur un
--  schema fraichement cree par V1__schema_initial.sql (revue PR #10, N1).
-- =============================================================================

SET search_path = chasse, public;

INSERT INTO utilisateur (nom, prenom, email, telephone, password_hash) VALUES
 ('Durand','Claire','claire.durand@example.com','+33 6 12 34 56 78','$2b$12$x'),
 ('Martin','Paul','paul.martin@example.com','+33 6 22 33 44 55','$2b$12$y'),
 ('Nguyen','Lea','lea.nguyen@example.com','+33 6 33 44 55 66','$2b$12$z'),
 ('Nguyen','Marc','marc.nguyen@example.com','+33 6 44 55 66 77','$2b$12$w');

INSERT INTO gestionnaire (id_utilisateur, matricule, date_entree_fonction, equipe)
VALUES (1,'G-0001','2024-01-15','Lyon');

INSERT INTO chasseur (id_utilisateur, numero_carte_t, date_validite_carte_t, prefecture_delivrance,
                      organisme_garant, montant_garantie_financiere, numero_rcp, date_echeance_rcp,
                      statut_juridique, numero_rsac, date_entree_reseau, taux_honoraires_defaut)
VALUES (2,'CPI6901202400012345','2027-06-30','Prefecture du Rhone','Galian',120000,'RCP-778812','2026-12-31',
        'agent_commercial','RSAC-69-2024-118','2024-02-01',4.50);

-- Couple acquereur : deux clients particuliers sur une meme recherche.
INSERT INTO client (id_utilisateur, annee_naissance, primo_accedant, code_postal_residence)
VALUES (3,1988,true,'69003'),
       (4,1986,true,'69003');

INSERT INTO zone (type_zone, libelle, code_insee, code_postal) VALUES ('ville','Lyon 4e','69384','69004');
INSERT INTO zone (id_zone_parent, type_zone, libelle, code_postal) VALUES (1,'quartier','Croix-Rousse','69004');
INSERT INTO chasseur_zone (id_utilisateur, id_zone, role_intervention) VALUES (2,1,'titulaire');

BEGIN;
INSERT INTO demande (canal, description_initiale, date_consentement)
VALUES ('site_web','Recherche T4 avec terrasse sur la Croix-Rousse', now());
INSERT INTO demande_acquereur (id_demande, id_client, qualite) VALUES (1,3,'principal'),(1,4,'co_acquereur');
COMMIT;

INSERT INTO affectation (id_demande, id_gestionnaire, id_chasseur) VALUES (1,1,2);

INSERT INTO demande_version (id_demande, id_modifie_par, no_version, type_bien, destination,
                             budget_max, surface_min, nb_pieces_min, nb_chambres_min, nb_occupants,
                             dpe_max, exige_terrasse, est_courante)
VALUES (1,3,1,'appartement','residence_principale',450000,85,4,3,4,'D',true,true);
INSERT INTO version_zone (id_version, id_zone) VALUES (1,2);

INSERT INTO mandat (id_demande, id_version_contractuelle, id_chasseur, id_signataire, numero_registre,
                    date_signature, mode_signature, date_debut, duree_mois, taux_honoraires,
                    base_honoraires, qualite_signataire)
VALUES (1,1,2,3,'REG-2025-0001','2025-03-10','en_ligne','2025-03-10',6,4.50,'TTC','en son nom propre');

INSERT INTO bien (id_zone, type_bien, surface, nb_pieces, nb_chambres, etage, dpe,
                  adresse_indicative, code_postal, a_terrasse, a_ascenseur)
VALUES (2,'appartement',92.5,4,3,3,'C','rue des Pierres Plantees','69004',true,NULL);

INSERT INTO annonce (id_bien, source, reference_source, titre, prix, url, date_publication) VALUES
 (1,'seloger','SL-98472','T4 avec terrasse Croix-Rousse',439000,'https://example.com/a1', now()),
 (1,'leboncoin','LBC-33110','Appartement 4 pieces terrasse',442000,'https://example.com/a2', now());

INSERT INTO proposition (id_demande, id_version, id_bien, id_annonce_reference, score_matching,
                         statut, date_soumission_client)
VALUES (1,1,1,1,87.50,'soumis_client', now());

INSERT INTO commentaire (id_auteur, id_proposition, type_contexte, est_prive, contenu)
VALUES (2,1,'analyse_annonce',true,'Vis-a-vis important cote cour, a verifier en visite.');

INSERT INTO indicateur VALUES
 ('delai_affectation_moyen','Delai moyen d''affectation d''un lead','heure','gestionnaire','decroissant',
  'moyenne de (date_affectation - date_depot) sur les demandes affectees dans la periode'),
 ('taux_transformation','Taux de transformation demande vers mandat','pourcentage','chasseur','croissant',
  'mandats signes / demandes prises en charge sur la periode');

INSERT INTO periode (type_periode, date_debut, date_fin) VALUES ('mois','2025-03-01','2025-03-31');
INSERT INTO observation (id_utilisateur, code_indicateur, id_periode, valeur, date_calcul)
VALUES (1,'delai_affectation_moyen',1,4.2000,'2025-04-01 06:00+02');
INSERT INTO objectif (id_utilisateur, code_indicateur, id_periode, valeur_cible)
VALUES (1,'delai_affectation_moyen',1,6.0000);
