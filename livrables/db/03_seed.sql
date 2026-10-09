-- ============================================================
-- Seed minimal valide v8.2 (UUID fixes pour référence dans les tests)
-- Ordre respectant les FK : acteurs -> demande -> mandat -> proposition.
-- ============================================================
SET search_path TO public;

-- Utilisateurs
INSERT INTO utilisateur (id_utilisateur, nom, prenom, email, password_hash, actif) VALUES
('11111111-0000-0000-0000-000000000001','Roussel','Marina','m.roussel@chassimmo.fr','x',true),  -- chasseur
('11111111-0000-0000-0000-000000000002','Durand','Paul','p.durand@chassimmo.fr','x',true),        -- gestionnaire
('11111111-0000-0000-0000-000000000003','Martin','Alice','alice.martin@mail.fr','x',true),        -- client
('11111111-0000-0000-0000-000000000004','Benali','Karim','karim.benali@mail.fr','x',true),        -- client 2
('11111111-0000-0000-0000-000000000005','Nguyen','Thomas','t.nguyen@chassimmo.fr','x',true);      -- chasseur+client (cumul)

-- Chasseurs (v8.2 : modèle habilitation Hoguet ; salarié -> attestation)
INSERT INTO chasseur (id_utilisateur, type_habilitation, numero_habilitation, date_validite_habilitation, organisme_delivrance, organisme_garant, montant_garantie_financiere, numero_rcp, date_echeance_rcp, statut_juridique, date_entree_reseau, capacite_max_mandats) VALUES
('11111111-0000-0000-0000-000000000001','attestation','ATT-3401','2027-01-01','CCI Herault','Galian',120000,'RCP1','2027-01-01','salarie','2023-03-15',15),
('11111111-0000-0000-0000-000000000005','attestation','ATT-3402','2027-01-01','CCI Herault','Galian',120000,'RCP2','2027-01-01','salarie','2023-06-01',15);

INSERT INTO gestionnaire (id_utilisateur, matricule, date_entree_fonction, capacite_max_leads) VALUES
('11111111-0000-0000-0000-000000000002','G001','2023-01-01',50);

INSERT INTO client (id_utilisateur) VALUES
('11111111-0000-0000-0000-000000000003'),
('11111111-0000-0000-0000-000000000004'),
('11111111-0000-0000-0000-000000000005');  -- cumul chasseur+client

-- Zone
INSERT INTO zone (id_zone, type_zone, pays, code_iso_pays, devise, ville, code_insee, secteur, code_postal) VALUES
('22222222-0000-0000-0000-000000000001','secteur','France','FR','EUR','Montpellier','34172','Ecusson','34000'),
('22222222-0000-0000-0000-000000000002','ville','France','FR','EUR','Lyon','69381',NULL,'69001');

-- Demande + acquéreur principal (transaction pour le trigger C4)
BEGIN;
INSERT INTO demande (id_demande, id_gestionnaire, date_depot, canal, date_consentement) VALUES
('33333333-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000002','2025-06-01','site_web','2025-06-01');
INSERT INTO demande_acquereur (id_demande, id_client, qualite) VALUES
('33333333-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000003','principal');
COMMIT;

-- Version de critères
INSERT INTO demande_version (id_version, id_demande, id_modifie_par, no_version, date_creation, motif_evolution, type_bien, destination, budget_max) VALUES
('44444444-0000-0000-0000-000000000001','33333333-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000003',1,'2025-06-02','initiale','appartement','principale',320000);

-- Mandat valide (signataire = acquéreur principal). AVANT la proposition (FK v8.2).
-- date_debut = date_signature (A12) ; gel habilitation renseigné (mandat applicatif).
INSERT INTO mandat (id_mandat, id_demande, id_version_contractuelle, id_chasseur, id_signataire, numero_registre, date_signature, mode_signature, date_debut, numero_habilitation_signature, validite_habilitation_signature, exclusif, taux_honoraires, base_honoraires, taux_tva, qualite_signataire) VALUES
('88888888-0000-0000-0000-000000000001','33333333-0000-0000-0000-000000000001','44444444-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000003','REG-2025-001','2025-06-05','presentiel','2025-06-05','ATT-3401','2027-01-01',true,3.0,'TTC',20.0,'nom_propre');

-- Bien + annonce
INSERT INTO bien (id_bien, id_zone, type_bien, surface, nb_pieces) VALUES
('55555555-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000001','appartement',65,3);
INSERT INTO annonce (id_annonce, id_bien, source, reference_source, prix, date_ingestion, date_derniere_vue, statut) VALUES
('66666666-0000-0000-0000-000000000001','55555555-0000-0000-0000-000000000001','bienici','REF123',315000,'2025-06-03','2025-06-03','active');

-- Proposition (v8.2 : rattachée au mandat de la même demande)
INSERT INTO proposition (id_proposition, id_demande, id_version, id_bien, id_annonce_reference, id_mandat, date_matching, statut) VALUES
('77777777-0000-0000-0000-000000000001','33333333-0000-0000-0000-000000000001','44444444-0000-0000-0000-000000000001','55555555-0000-0000-0000-000000000001','66666666-0000-0000-0000-000000000001','88888888-0000-0000-0000-000000000001','2025-06-04','soumis');

-- Indicateur + période close
INSERT INTO indicateur (code_indicateur, libelle, unite, perimetre_role, sens_optimal, mode_calcul) VALUES
('delai_affectation','Delai moyen affectation','heures','gestionnaire','decroissant','avg(date_affectation-date_depot)');
INSERT INTO periode (id_periode, type_periode, date_debut, date_fin) VALUES
('99999999-0000-0000-0000-000000000001','mois','2025-06-01','2025-06-30');

-- ADR-048 : désigner le mandat courant de la demande (fait de gestion).
UPDATE demande SET id_mandat_courant='88888888-0000-0000-0000-000000000001', date_affectation='2025-06-03'
WHERE id_demande='33333333-0000-0000-0000-000000000001';

-- ============================================================
-- v8.4 : chaîne rémunération complète (barème -> acte -> rémunération -> facture)
-- pour que le harnais exerce réellement ce sous-modèle.
-- ============================================================

-- Barème par défaut avec deux tranches (intervalles semi-ouverts)
INSERT INTO bareme (id_bareme, date_debut_vigueur) VALUES
('b0000000-0000-0000-0000-000000000001','2025-01-01');
INSERT INTO tranche_bareme (id_bareme, montant_min, montant_max, taux_base) VALUES
('b0000000-0000-0000-0000-000000000001',0,200000,40),
('b0000000-0000-0000-0000-000000000001',200000,NULL,45);

-- Chaîne de vente : l'offre (sur la proposition du seed) -> compromis réalisé -> acte
INSERT INTO offre_acquisition (id_offre,id_proposition,camp,saisi_par,montant,date_signature,date_validite,date_reponse,statut) VALUES
('0ff00000-0000-0000-0000-000000000001','77777777-0000-0000-0000-000000000001','acquereur','client',310000,'2025-06-20','2025-07-05','2025-06-22','acceptee');
INSERT INTO notaire (id_notaire,nom,etude) VALUES
('07a00000-0000-0000-0000-000000000001','Maitre Seed','Etude Seed');
INSERT INTO compromis (id_compromis,id_offre,id_notaire,date_signature,fin_retractation) VALUES
('c0a00000-0000-0000-0000-000000000001','0ff00000-0000-0000-0000-000000000001','07a00000-0000-0000-0000-000000000001','2025-07-10','2025-07-20');
INSERT INTO acte (id_acte,id_compromis,date_signature,montant_vente,honoraires_fixe,honoraires_encaisses,date_encaissement) VALUES
('ac700000-0000-0000-0000-000000000001','c0a00000-0000-0000-0000-000000000001','2025-08-01',310000,9300,true,'2025-08-05');

-- Rémunération GELÉE complète (5 composantes + global, taux dans [20,60])
INSERT INTO remuneration_chasseur (id_acte,id_chasseur,id_mandat,honoraires,
    score_delai,score_exclusivite,score_ventes,score_mandats,score_visites,score_performance,
    taux_base,majoration_anciennete,modulation_performance,taux_final,montant,id_bareme_applique) VALUES
('ac700000-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','88888888-0000-0000-0000-000000000001',
 9300, 80,90,85,70,60,77, 45,5,1.02,47.0, 4371.00,'b0000000-0000-0000-0000-000000000001');

-- Facture (une seule par rémunération grâce à UNIQUE)
INSERT INTO facture_chasseur (id_facture,id_remuneration,numero,montant,date_emission,statut,date_verification,id_verificateur) VALUES
('fac00000-0000-0000-0000-000000000001',(SELECT id_remuneration FROM remuneration_chasseur WHERE id_acte='ac700000-0000-0000-0000-000000000001'),
 'FAC-2025-001',4371.00,'2025-08-10','verifiee_conforme','2025-08-12','11111111-0000-0000-0000-000000000002');

-- Note d'avis (rattachée à la proposition) + document + liaison
INSERT INTO note_avis (id_note,id_proposition,contenu,montant_offre_suggere) VALUES
('07e00000-0000-0000-0000-000000000001','77777777-0000-0000-0000-000000000001','Bien conforme, bon rapport.',305000);
INSERT INTO document (id_document,type_document,cle_objet,uri,mime_type,taille_octets,hash_sha256) VALUES
('d0c00000-0000-0000-0000-000000000001','video','bucket/note1.mp4','https://minio/note1.mp4','video/mp4',10485760,
 'a1b2c3d4e5f60718293a4b5c6d7e8f901a2b3c4d5e6f708192a3b4c5d6e7f809');
INSERT INTO note_avis_document (id_note,id_document) VALUES
('07e00000-0000-0000-0000-000000000001','d0c00000-0000-0000-0000-000000000001');
