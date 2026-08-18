-- ============================================================
-- SCRIPT DDL — Création du schéma cible (PostgreSQL)
-- ============================================================

-- Nettoyage de la base
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

CREATE TABLE commune (
    id_commune SERIAL PRIMARY KEY,
    nom VARCHAR(80) NOT NULL,
    code_officiel VARCHAR(10),
    pays VARCHAR(50) DEFAULT 'France'
);

CREATE TABLE secteur (
    id_secteur SERIAL PRIMARY KEY,
    id_commune INT NOT NULL,
    quartier VARCHAR(80),
    code_postal VARCHAR(10) NOT NULL,
    FOREIGN KEY (id_commune) REFERENCES commune(id_commune)
);

CREATE TABLE personne (
    id_personne SERIAL PRIMARY KEY,
    nom VARCHAR(80) NOT NULL,
    prenom VARCHAR(80) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    telephone VARCHAR(20),
    date_creation DATE NOT NULL,
    date_consentement DATE,
    date_anonymisation DATE
);

CREATE TABLE client (
    id_client INT PRIMARY KEY,
    origine VARCHAR(50) DEFAULT 'Site Web' CHECK (origine IN ('Site Web', 'Bouche à oreille', 'Autre')),
    date_premier_contact DATE,
    FOREIGN KEY (id_client) REFERENCES personne(id_personne)
);

CREATE TABLE chasseur (
    id_chasseur INT PRIMARY KEY,
    date_entree DATE NOT NULL,
    en_activite BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (id_chasseur) REFERENCES personne(id_personne)
);

CREATE TABLE demande (
    id_demande SERIAL PRIMARY KEY,
    id_client INT NOT NULL,
    id_chasseur_affecte INT,
    date_depot DATE NOT NULL,
    canal VARCHAR(50) DEFAULT 'formulaire en ligne' CHECK (canal IN ('formulaire en ligne', 'téléphone', 'recommandation')),
    FOREIGN KEY (id_client) REFERENCES client(id_client),
    FOREIGN KEY (id_chasseur_affecte) REFERENCES chasseur(id_chasseur)
);

CREATE TABLE mandat (
    id_mandat SERIAL PRIMARY KEY,
    id_demande INT NOT NULL,
    date_signature DATE NOT NULL,
    mode_signature VARCHAR(50) DEFAULT 'en agence' CHECK (mode_signature IN ('en agence', 'hors établissement', 'électronique à distance')),
    date_fin DATE NOT NULL,
    exclusif BOOLEAN NOT NULL DEFAULT FALSE,
    statut VARCHAR(50) NOT NULL DEFAULT 'actif' CHECK (statut IN ('actif', 'suspendu', 'termine', 'resilie', 'expire')),
    FOREIGN KEY (id_demande) REFERENCES demande(id_demande)
);

CREATE TABLE demande_version (
    id_version SERIAL PRIMARY KEY,
    id_demande INT NOT NULL,
    no_version INT NOT NULL DEFAULT 1,
    id_personne_redacteur INT NOT NULL,
    date_modification TIMESTAMP NOT NULL,
    motif VARCHAR(255) DEFAULT 'Création initiale',
    type_bien VARCHAR(50) DEFAULT 'non defini' CHECK (type_bien IN ('appartement', 'maison', 'loft', 'villa', 'non defini')),
    budget_max DECIMAL(12,2),
    surface_min INT,
    nb_pieces_min INT,
    nb_chambres_min INT,
    dpe_max VARCHAR(1) CHECK (dpe_max IN ('A','B','C','D','E','F','G')),
    etat_attendu VARCHAR(50) CHECK (etat_attendu IN ('neuf', 'récent', 'ancien rénové', 'travaux acceptés')),
    emmenagement_au_plus_tard DATE,
    description_libre TEXT,
    FOREIGN KEY (id_demande) REFERENCES demande(id_demande),
    FOREIGN KEY (id_personne_redacteur) REFERENCES personne(id_personne)
);

CREATE TABLE demande_secteur (
    id_version INT NOT NULL,
    id_secteur INT NOT NULL,
    PRIMARY KEY (id_version, id_secteur),
    FOREIGN KEY (id_version) REFERENCES demande_version(id_version),
    FOREIGN KEY (id_secteur) REFERENCES secteur(id_secteur)
);

CREATE TABLE bareme (
    id_bareme SERIAL PRIMARY KEY,
    id_chasseur INT NOT NULL,
    date_debut DATE NOT NULL,
    date_fin DATE,
    FOREIGN KEY (id_chasseur) REFERENCES chasseur(id_chasseur)
);

CREATE TABLE tranche_bareme (
    id_tranche SERIAL PRIMARY KEY,
    id_bareme INT NOT NULL,
    montant_min DECIMAL(12,2) NOT NULL,
    montant_max DECIMAL(12,2),
    taux DECIMAL(4,2) NOT NULL,
    FOREIGN KEY (id_bareme) REFERENCES bareme(id_bareme)
);
