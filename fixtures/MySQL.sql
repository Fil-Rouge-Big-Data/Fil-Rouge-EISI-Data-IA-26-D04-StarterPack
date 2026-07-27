-- ============================================================
-- FIXTURES — Projet : Chasse immobilière
-- Cible : MariaDB/MySQL (stack du cours, port 3306)
-- Rejouable : DROP + CREATE + INSERT
--
-- ⚠️ CE SCHÉMA REPRESENTE L'EXISTANT
--    C'est l'existant "hérité" qu'il conviendra de faire
--    évoluer / migrer.
--    NE PAS corriger ou modifier ce fichier (voir énoncé).
--
-- ------------------------------------------------------------
-- Ce fichier est truffé d'annotations laissées par le consultant
-- passé avant vous (préfixe "-- [consultant]"). Il a manifestement
-- été surpris par l'état du schéma et des données. Ses remarques
-- ne sont PAS des consignes : ce sont des observations. À vous de
-- décider, en audit, lesquelles sont fondées et ce que vous en
-- faites.
-- ============================================================

DROP DATABASE IF EXISTS Fil_Rouge_Depart;
CREATE DATABASE Fil_Rouge_Depart CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE Fil_Rouge_Depart;

-- ------------------------------------------------------------
-- Table secteurs : les secteurs de chasse actuels
-- [consultant] La seule table à peu près saine du lot. Même ici,
-- [consultant] un code postal en VARCHAR sans le moindre contrôle,
-- [consultant] et aucune contrainte d'unicité sur (ville,quartier).
-- ------------------------------------------------------------
CREATE TABLE secteurs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ville VARCHAR(80) NOT NULL,
    quartier VARCHAR(80),
    code_postal VARCHAR(10) NOT NULL
);

INSERT INTO secteurs (ville, quartier, code_postal) VALUES
('Montpellier', 'Écusson',        '34000'),
('Montpellier', 'Port Marianne',  '34000'),
('Montpellier', 'Beaux-Arts',     '34090'),
('Montpellier', 'Figuerolles',    '34070'),
('Castelnau-le-Lez', NULL,        '34170'),
('Lattes',      NULL,             '34970'),
('Lyon',        'Croix-Rousse',   '69004'),
('Lyon',        'Confluence',     '69002'),
('Nantes',      'Île de Nantes',  '44200'),
('Sète',        'Centre',         '34200');

-- ------------------------------------------------------------
-- Table utilisateurs
-- [consultant] Alors là... clients ET chasseurs dans la MÊME table,
-- [consultant] départagés par une colonne "role". Résultat : la moitié
-- [consultant] des colonnes est vide selon les lignes. taux_commission
-- [consultant] n'a de sens que pour un chasseur, budget_max que pour un
-- [consultant] client. On stocke donc du NULL par conception. Je n'ose
-- [consultant] imaginer les requêtes que ça oblige à écrire côté appli.
-- ------------------------------------------------------------
CREATE TABLE utilisateurs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    role ENUM('client','chasseur') NOT NULL,
    nom VARCHAR(80) NOT NULL,
    prenom VARCHAR(80) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    telephone VARCHAR(20),
    ville VARCHAR(80),
    taux_commission DECIMAL(4,2) NULL COMMENT 'chasseurs uniquement (%)',
    budget_max DECIMAL(12,2) NULL COMMENT 'clients uniquement (EUR)',
    date_creation DATE NOT NULL
);

-- Chasseurs (id 1 à 6)
INSERT INTO utilisateurs (role, nom, prenom, email, telephone, ville, taux_commission, budget_max, date_creation) VALUES
('chasseur','Roussel', 'Marina',  'm.roussel@chassimmo.fr',  '0611223344','Montpellier', 2.50, NULL, '2023-03-15'),
('chasseur','Nguyen',  'Thomas',  't.nguyen@chassimmo.fr',   '0622334455','Montpellier', 3.00, NULL, '2023-06-01'),
('chasseur','Delacroix','Inès',   'i.delacroix@chassimmo.fr','0633445566','Lyon',        2.75, NULL, '2024-01-10'),
('chasseur','Baldini', 'Marco',   'm.baldini@chassimmo.fr',  '0644556677','Nantes',      2.50, NULL, '2024-09-22'),
('chasseur','Kone',    'Awa',     'a.kone@chassimmo.fr',     '0655667788','Montpellier', 3.25, NULL, '2025-02-14'),
('chasseur','Perrin',  'Lucas',   'l.perrin@chassimmo.fr',   '0666778899','Sète',        2.00, NULL, '2025-11-03');

-- Clients (id 7 à 24)
-- [consultant] Certains clients n'ont pas de téléphone (NULL). Pas de
-- [consultant] contrainte, pas de validation de format d'email non plus.
INSERT INTO utilisateurs (role, nom, prenom, email, telephone, ville, taux_commission, budget_max, date_creation) VALUES
('client','Martin',   'Alice',   'alice.martin@mail.fr',   '0701020304','Montpellier', NULL, 320000.00, '2025-01-08'),
('client','Benali',   'Karim',   'karim.benali@mail.fr',   '0702030405','Lyon',        NULL, 450000.00, '2025-02-19'),
('client','Dubois',   'Chloé',   'chloe.dubois@mail.fr',   '0703040506','Montpellier', NULL, 280000.00, '2025-03-02'),
('client','Petit',    'Jean',    'jean.petit@mail.fr',     NULL,        'Nantes',      NULL, 390000.00, '2025-03-27'),
('client','Garcia',   'Lucia',   'lucia.garcia@mail.fr',   '0705060708','Montpellier', NULL, 550000.00, '2025-04-11'),
('client','Moreau',   'Paul',    'paul.moreau@mail.fr',    '0706070809','Castelnau-le-Lez', NULL, 240000.00, '2025-05-30'),
('client','Lefevre',  'Emma',    'emma.lefevre@mail.fr',   '0707080910','Lyon',        NULL, 610000.00, '2025-06-15'),
('client','Rossi',    'Giulia',  'giulia.rossi@mail.fr',   '0708091011','Montpellier', NULL, 300000.00, '2025-07-04'),
('client','Fournier', 'Hugo',    'hugo.fournier@mail.fr',  '0709101112','Sète',        NULL, 260000.00, '2025-08-21'),
('client','Andre',    'Sofia',   'sofia.andre@mail.fr',    NULL,        'Lattes',      NULL, 420000.00, '2025-09-09'),
('client','Mercier',  'Louis',   'louis.mercier@mail.fr',  '0711121314','Montpellier', NULL, 350000.00, '2025-10-17'),
('client','Blanc',    'Léa',     'lea.blanc@mail.fr',      '0712131415','Nantes',      NULL, 480000.00, '2025-11-25'),
('client','Girard',   'Nina',    'nina.girard@mail.fr',    '0713141516','Montpellier', NULL, 220000.00, '2025-12-12'),
('client','Bonnet',   'Adam',    'adam.bonnet@mail.fr',    '0714151617','Lyon',        NULL, 700000.00, '2026-01-06'),
('client','Dupont',   'Zoé',     'zoe.dupont@mail.fr',     '0715161718','Montpellier', NULL, 310000.00, '2026-02-20'),
('client','Lambert',  'Théo',    'theo.lambert@mail.fr',   NULL,        'Sète',        NULL, 290000.00, '2026-03-30'),
('client','Roux',     'Manon',   'manon.roux@mail.fr',     '0717181920','Montpellier', NULL, 260000.00, '2026-05-15'),
('client','Faure',    'Ethan',   'ethan.faure@mail.fr',    '0718192021','Castelnau-le-Lez', NULL, 330000.00, '2026-06-28');

-- ------------------------------------------------------------
-- Table mandats
-- [consultant] Une liste "à plat". Le mandat est censé durer 6 mois et
-- [consultant] pouvoir être renouvelé... mais je ne trouve NI date de
-- [consultant] signature, NI date de fin, NI mode de signature. Comment
-- [consultant] savent-ils quand un mandat expire ? Mystère.
-- [consultant] Les critères de recherche du client sont carrément noyés
-- [consultant] dans un champ TEXT en langage naturel ("budget 320000,
-- [consultant] 65m2 min, balcon..."). Impossible à filtrer proprement.
-- [consultant] client_id et chasseur_id pointent tous les deux vers
-- [consultant] "utilisateurs" sans distinction : rien ne garantit qu'un
-- [consultant] client_id soit vraiment un client. J'ai d'ailleurs un
-- [consultant] doute sur au moins une ligne ci-dessous (à vérifier).
-- ------------------------------------------------------------
CREATE TABLE mandats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    client_id INT NOT NULL,
    chasseur_id INT NOT NULL,
    secteur_id INT,
    exclusif TINYINT(1) NOT NULL DEFAULT 0,
    date_debut DATE NOT NULL,
    statut ENUM('actif','suspendu','termine','expire') NOT NULL DEFAULT 'actif',
    description_recherche TEXT,
    FOREIGN KEY (client_id)  REFERENCES utilisateurs(id),
    FOREIGN KEY (chasseur_id) REFERENCES utilisateurs(id),
    FOREIGN KEY (secteur_id) REFERENCES secteurs(id)
);

INSERT INTO mandats (client_id, chasseur_id, secteur_id, exclusif, date_debut, statut, description_recherche) VALUES
( 7, 1, 1, 1, '2025-02-01', 'termine', 'T3 Ecusson, budget 320000, 65m2 min, balcon, calme, DPE C max'),
( 8, 3, 7, 0, '2025-03-10', 'expire',  'T4 Croix-Rousse, budget 450000, 85m2, terrasse ou jardin'),
( 9, 1, 3, 0, '2025-04-05', 'termine', 'T2 Beaux-Arts, budget 280000, 45m2 min, lumineux, proche tram'),
(10, 4, 9, 1, '2025-05-20', 'actif',   'Maison Ile de Nantes, budget 390000, 3 chambres, petit exterieur'),
(11, 2, 2, 1, '2025-06-18', 'termine', 'T4 Port Marianne, budget 550000, 90m2, parking, ascenseur, vue'),
(12, 5, 5, 0, '2025-07-22', 'expire',  'Maison Castelnau, budget 240000, 80m2, jardin, travaux OK'),
(13, 3, 8, 1, '2025-09-01', 'actif',   'Loft Confluence, budget 610000, 100m2, standing, terrasse'),
(14, 2, 1, 0, '2025-09-15', 'suspendu','T3 Ecusson ou Beaux-Arts, budget 300000, charme ancien, poutres'),
(15, 6,10, 1, '2025-10-02', 'actif',   'T3 Sete centre, budget 260000, vue mer si possible, 60m2'),
(16, 5, 6, 0, '2025-11-14', 'actif',   'Villa Lattes, budget 420000, 4 pieces, piscine ou jardin sud'),
(17, 1, 2, 1, '2026-01-05', 'actif',   'T3 Port Marianne, budget 350000, neuf ou recent, balcon, parking'),
(18, 4, 9, 0, '2026-01-20', 'actif',   'Appartement Nantes, budget 480000, 4 pieces, dernier etage'),
-- [consultant] Celle-ci me chiffonne : client_id = 3. Or l'utilisateur 3
-- [consultant] est un CHASSEUR (Inès Delacroix). Un chasseur "client" de
-- [consultant] son propre métier ? Soit c'est une faute de saisie, soit
-- [consultant] le modèle laisse vraiment passer n'importe quoi. Les deux
-- [consultant] sans doute.
( 3, 2, 4, 0, '2026-02-10', 'actif',   'T2 Figuerolles, budget 220000, premier achat, 40m2 min'),
(20, 3, 8, 1, '2026-03-01', 'actif',   'T5 Confluence, budget 700000, 120m2, prestations haut de gamme'),
(21, 1, 1, 0, '2026-03-25', 'actif',   'T3 Ecusson, budget 310000, ancien renove, cave appreciee'),
(22, 6,10, 0, '2026-04-12', 'suspendu','Maison Sete, budget 290000, 3 pieces, garage'),
(23, 5, 3, 1, '2026-05-28', 'actif',   'T2 Beaux-Arts, budget 260000, 45m2, balcon, DPE D max'),
(24, 2, 5, 1, '2026-07-01', 'actif',   'Maison Castelnau, budget 330000, 90m2, 3 chambres, jardin');

-- ------------------------------------------------------------
-- Contrôles rapides après import
-- ------------------------------------------------------------
SELECT role, COUNT(*) AS nb FROM utilisateurs GROUP BY role;
SELECT statut, COUNT(*) AS nb FROM mandats GROUP BY statut;
SELECT COUNT(*) AS nb_secteurs FROM secteurs;

-- Répartition attendue (au 25/07/2026) :
--   utilisateurs : 6 chasseurs + 18 clients = 24
--   mandats      : 18 lignes -> 11 actif, 3 termine, 2 expire, 2 suspendu
--   secteurs     : 10
--
-- [consultant] Petit test pour la route : combien de mandats "actif" ont
-- [consultant] en réalité dépassé leurs 6 mois de validité au 25/07/2026 ?
-- [consultant] (date_debut + 6 mois < aujourd'hui). Le statut "actif"
-- [consultant] ne veut donc pas dire grand-chose en l'état.
