\set ON_ERROR_STOP off
SET search_path = chasse, public;
\echo '=== TESTS NEGATIFS : chaque bloc DOIT echouer ==='

\echo '--- T1 commentaire rattache aux deux cibles (C2)'
INSERT INTO commentaire (id_auteur, id_demande, id_proposition, type_contexte, contenu)
VALUES (2, 1, 1, 'note_recherche', 'ko');

\echo '--- T2 second mandat actif sur la meme demande (C7)'
INSERT INTO mandat (id_demande, id_version_contractuelle, id_chasseur, id_signataire, numero_registre,
                    date_signature, mode_signature, date_debut, taux_honoraires, qualite_signataire)
VALUES (1,1,2,3,'REG-2025-0002','2025-04-01','en_ligne','2025-04-01',4.50,'en son nom propre');

\echo '--- T3 meme bien propose deux fois sur la meme recherche (C8)'
INSERT INTO proposition (id_demande, id_version, id_bien, score_matching) VALUES (1,1,1,90.00);

\echo '--- T4 signataire non acquereur de la demande (C5, desormais declaratif)'
-- statut non actif : isole fk_mandat_signataire de ux_mandat_actif, qui
-- rejetterait d'abord un second mandat actif (revue PR #10, point C4).
INSERT INTO mandat (id_demande, id_version_contractuelle, id_chasseur, id_signataire, numero_registre,
                    date_signature, mode_signature, date_debut, taux_honoraires, qualite_signataire, statut)
VALUES (1,1,2,1,'REG-2025-0003b','2025-04-02','en_ligne','2025-04-02',4.50,'en son nom propre','renouvele');

\echo '--- T5 seconde affectation ouverte sur la meme demande (C6)'
INSERT INTO affectation (id_demande, id_gestionnaire, id_chasseur, motif)
VALUES (1,1,2,'reaffectation_surcharge');

\echo '--- T6 mandat sans aucune remuneration convenue'
INSERT INTO mandat (id_demande, id_version_contractuelle, id_chasseur, id_signataire, numero_registre,
                    date_signature, mode_signature, date_debut, qualite_signataire)
VALUES (1,1,2,3,'REG-2025-0004','2025-04-03','en_ligne','2025-04-03','en son nom propre');

\echo '--- T7 prise d effet anterieure a la signature'
INSERT INTO mandat (id_demande, id_version_contractuelle, id_chasseur, id_signataire, numero_registre,
                    date_signature, mode_signature, date_debut, taux_honoraires, qualite_signataire)
VALUES (1,1,2,3,'REG-2025-0005','2025-04-04','presentiel','2025-04-01',4.50,'en son nom propre');

\echo '--- T8 signature par procuration sans reference du document'
INSERT INTO mandat (id_demande, id_version_contractuelle, id_chasseur, id_signataire, numero_registre,
                    date_signature, mode_signature, date_debut, taux_honoraires, qualite_signataire)
VALUES (1,1,2,4,'REG-2025-0006','2025-04-05','presentiel','2025-04-05',4.50,'par procuration');

\echo '--- T9 observation figee sur une periode non close (C9)'
INSERT INTO observation (id_utilisateur, code_indicateur, id_periode, valeur, date_calcul)
VALUES (2,'taux_transformation',1,55.0,'2025-03-15 10:00+01');

\echo '--- T10 annonce de reference rattachee a un autre bien'
INSERT INTO bien (id_zone, type_bien, surface, nb_pieces) VALUES (1,'maison',120,5);
INSERT INTO annonce (id_bien, source, reference_source, prix) VALUES (2,'seloger','SL-11111',600000);
INSERT INTO proposition (id_demande, id_version, id_bien, id_annonce_reference, score_matching)
VALUES (1,1,2,1,70.00);

\echo '--- T11 dpe hors domaine'
INSERT INTO bien (id_zone, type_bien, dpe) VALUES (1,'maison','Z');

\echo '--- T12 email malforme (domaine)'
INSERT INTO utilisateur (nom, prenom, email, password_hash) VALUES ('X','Y','pas-un-email','h');

\echo '--- T13 refus client sans motif'
INSERT INTO proposition (id_demande, id_version, id_bien, score_matching, statut)
VALUES (1,1,2,60.00,'refuse_client');

\echo '--- T14 lead web sans consentement RGPD'
INSERT INTO demande (canal) VALUES ('site_web');

\echo '--- T15 critere de rendement sur une residence principale'
INSERT INTO demande_version (id_demande, id_modifie_par, no_version, type_bien, destination,
                             budget_max, rendement_brut_min)
VALUES (1,3,9,'appartement','residence_principale',400000,5.5);

\echo '=== TESTS POSITIFS : doivent reussir ==='
\echo '--- P1 bascule automatique de la version courante'
INSERT INTO demande_version (id_demande, id_modifie_par, no_version, type_bien, budget_max,
                             surface_min, nb_pieces_min, est_courante, motif_evolution)
VALUES (1,3,2,'appartement',500000,80,4,true,'hausse du budget apres 3 visites');
SELECT no_version, est_courante FROM demande_version WHERE id_demande = 1 ORDER BY no_version;

\echo '--- P2 cloture puis reaffectation'
UPDATE affectation SET date_fin = now() WHERE id_demande = 1 AND date_fin IS NULL;
INSERT INTO affectation (id_demande, id_gestionnaire, id_chasseur, motif)
VALUES (1,1,2,'reaffectation_surcharge');
SELECT count(*) AS nb_affectations FROM affectation WHERE id_demande = 1;

\echo '--- P3 un bien, deux annonces, une seule proposition'
SELECT b.id_bien, count(DISTINCT a.id_annonce) AS annonces, count(DISTINCT p.id_proposition) AS propositions
FROM bien b LEFT JOIN annonce a ON a.id_bien = b.id_bien
            LEFT JOIN proposition p ON p.id_bien = b.id_bien
WHERE b.id_bien = 1 GROUP BY b.id_bien;

\echo '--- P4 signature par le co-acquereur, avec procuration'
INSERT INTO mandat (id_demande, id_version_contractuelle, id_chasseur, id_signataire, numero_registre,
                    date_signature, mode_signature, date_debut, taux_honoraires,
                    qualite_signataire, reference_procuration, statut)
VALUES (1,1,2,4,'REG-2025-0007','2025-09-15','presentiel','2025-09-15',4.50,
        'par procuration','PROC-2025-118','renouvele');
SELECT numero_registre, id_signataire, qualite_signataire FROM mandat ORDER BY id_mandat;

\echo '--- P5 cumul de roles : un chasseur peut etre client'
INSERT INTO client (id_utilisateur, annee_naissance) VALUES (2,1980);
SELECT u.prenom, (c.id_utilisateur IS NOT NULL) AS est_client,
       (ch.id_utilisateur IS NOT NULL) AS est_chasseur
FROM utilisateur u
LEFT JOIN client c ON c.id_utilisateur = u.id_utilisateur
LEFT JOIN chasseur ch ON ch.id_utilisateur = u.id_utilisateur
WHERE u.id_utilisateur = 2;

\echo '--- P6 cloture sans reaffectation : la denormalisation se vide (N3)'
UPDATE affectation SET date_fin = now() WHERE id_demande = 1 AND date_fin IS NULL;
SELECT id_chasseur, id_gestionnaire FROM demande WHERE id_demande = 1;

\echo '--- T16 suppression de l acquereur principal (N2)'
DELETE FROM demande_acquereur WHERE id_demande = 1 AND qualite = 'principal';

\echo '--- T17 suppression du principal sur une demande sans mandat (N2, cas isole)'
BEGIN;
INSERT INTO demande (canal, date_consentement) VALUES ('telephone', now());
INSERT INTO demande_acquereur (id_demande, id_client, qualite)
VALUES (currval(pg_get_serial_sequence('demande','id_demande')), 4, 'principal');
COMMIT;
DELETE FROM demande_acquereur
 WHERE id_demande = currval(pg_get_serial_sequence('demande','id_demande'));

\echo '--- T18 requalification du principal en co-acquereur (N2)'
UPDATE demande_acquereur SET qualite = 'co_acquereur'
 WHERE id_demande = currval(pg_get_serial_sequence('demande','id_demande'));
