-- ============================================================
-- SCRIPT DDL — Création du schéma cible (PostgreSQL)
-- Version SANS les clés étrangères (uniquement les tables et PK)
-- ============================================================

DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

-- ==========================================
-- TYPES ENUM (PostgreSQL spécifique)
-- ==========================================
CREATE TYPE enum_origine_client AS ENUM ('Site Web', 'Bouche à oreille', 'Autre');
CREATE TYPE enum_canal_demande AS ENUM ('formulaire en ligne', 'téléphone', 'recommandation');
CREATE TYPE enum_statut_affectation AS ENUM ('proposée', 'acceptée', 'refusée', 'expirée');
CREATE TYPE enum_mode_signature AS ENUM ('en agence', 'hors établissement', 'électronique à distance');
CREATE TYPE enum_statut_mandat AS ENUM ('actif', 'suspendu', 'termine', 'resilie', 'expire');
CREATE TYPE enum_type_bien AS ENUM ('appartement', 'maison', 'loft', 'villa', 'non defini');
CREATE TYPE enum_dpe AS ENUM ('A', 'B', 'C', 'D', 'E', 'F', 'G');
CREATE TYPE enum_etat_attendu AS ENUM ('neuf', 'récent', 'ancien rénové', 'travaux acceptés');
CREATE TYPE enum_categorie_caract AS ENUM ('intérieur', 'extérieur', 'équipement', 'environnement');
CREATE TYPE enum_type_chauffage AS ENUM ('électrique', 'gaz', 'fioul', 'bois', 'pompe à chaleur');
CREATE TYPE enum_suite_donnee AS ENUM ('en attente', 'visite planifiée', 'rejetée', 'offre formulée');
CREATE TYPE enum_type_commentaire AS ENUM ('note interne', 'feedback client', 'rapport visite');
CREATE TYPE enum_media_pj AS ENUM ('image', 'pdf', 'video', 'document');
CREATE TYPE enum_emetteur_offre AS ENUM ('client', 'chasseur pour client');
CREATE TYPE enum_origine_decouverte AS ENUM ('chasseur', 'client_seul', 'tiers');
CREATE TYPE enum_statut_offre AS ENUM ('en cours', 'acceptée', 'refusée', 'caduque');
CREATE TYPE enum_statut_compromis AS ENUM ('signé', 'réitéré', 'caduc');
CREATE TYPE enum_motif_caducite AS ENUM ('refus prêt', 'droit préemption', 'rétractation acheteur', 'autre');
CREATE TYPE enum_type_clause AS ENUM ('obtention prêt', 'permis construire', 'vente précédent bien', 'autre');
CREATE TYPE enum_statut_clause AS ENUM ('en attente', 'levée', 'défaillie');
CREATE TYPE enum_statut_facture AS ENUM ('émise', 'payée', 'annulée', 'impayée');
CREATE TYPE enum_moyen_paiement AS ENUM ('virement', 'chèque', 'carte bancaire');

-- ==========================================
-- GÉOGRAPHIE
-- ==========================================
CREATE TABLE PAYS (
    code_iso VARCHAR(3) PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    devise VARCHAR(10),
    langue_defaut VARCHAR(10)
);

CREATE TABLE VILLE (
    id_ville SERIAL PRIMARY KEY,
    code_iso_pays VARCHAR(3) NOT NULL,
    nom VARCHAR(100) NOT NULL,
    code_postal VARCHAR(20)
);

CREATE TABLE SECTEUR (
    id_secteur SERIAL PRIMARY KEY,
    id_ville INT NOT NULL,
    quartier VARCHAR(100)
);

-- ==========================================
-- ACTEURS
-- ==========================================
CREATE TABLE PERSONNE (
    id_personne SERIAL PRIMARY KEY,
    id_ville INT,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    telephone VARCHAR(20),
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_consentement DATE,
    date_anonymisation DATE
);

CREATE TABLE CLIENT (
    id_personne INT PRIMARY KEY,
    origine enum_origine_client,
    date_premier_contact DATE
);

CREATE TABLE CHASSEUR (
    id_personne INT PRIMARY KEY,
    date_entree DATE NOT NULL,
    en_activite BOOLEAN DEFAULT TRUE
);

-- ==========================================
-- DEMANDE ET MANDAT
-- ==========================================
CREATE TABLE DEMANDE (
    id_demande SERIAL PRIMARY KEY,
    id_client INT NOT NULL,
    date_depot DATE NOT NULL,
    canal enum_canal_demande
);

CREATE TABLE AFFECTATION (
    id_affectation SERIAL PRIMARY KEY,
    id_demande INT NOT NULL,
    id_chasseur INT NOT NULL,
    date_proposition TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    statut enum_statut_affectation DEFAULT 'proposée',
    date_reponse TIMESTAMP,
    motif_refus VARCHAR(255)
);

CREATE TABLE MANDAT (
    id_mandat SERIAL PRIMARY KEY,
    id_demande INT NOT NULL,
    id_chasseur INT NOT NULL,
    date_signature DATE NOT NULL,
    mode_signature enum_mode_signature,
    date_fin DATE NOT NULL,
    exclusif BOOLEAN NOT NULL DEFAULT FALSE,
    statut enum_statut_mandat DEFAULT 'actif'
);

CREATE TABLE RENOUVELLEMENT_MANDAT (
    id_renouvellement SERIAL PRIMARY KEY,
    id_mandat INT NOT NULL,
    date_renouvellement DATE NOT NULL,
    nouvelle_date_fin DATE NOT NULL
);

CREATE TABLE DEMANDE_VERSION (
    id_version SERIAL PRIMARY KEY,
    id_demande INT NOT NULL,
    id_redacteur INT NOT NULL,
    no_version INT NOT NULL DEFAULT 1,
    date_modification TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motif VARCHAR(255),
    type_bien enum_type_bien,
    budget_max DECIMAL(12,2),
    surface_min INT,
    surface_terrain_min INT,
    nb_pieces_min INT,
    nb_chambres_min INT,
    nb_salles_bain_min INT,
    nb_places_parking_min INT,
    dpe_max enum_dpe,
    etat_attendu enum_etat_attendu,
    annee_construction_min INT,
    emmenagement_au_plus_tard DATE,
    est_courante BOOLEAN DEFAULT TRUE
);

CREATE TABLE CARACTERISTIQUE (
    id_caracteristique SERIAL PRIMARY KEY,
    libelle VARCHAR(100) NOT NULL,
    categorie enum_categorie_caract
);

CREATE TABLE DEMANDE_SECTEUR (
    id_version INT NOT NULL,
    id_secteur INT NOT NULL,
    PRIMARY KEY (id_version, id_secteur)
);

CREATE TABLE DEMANDE_CARACTERISTIQUE (
    id_version INT NOT NULL,
    id_caracteristique INT NOT NULL,
    PRIMARY KEY (id_version, id_caracteristique)
);

-- ==========================================
-- BIENS ET ANNONCES
-- ==========================================
CREATE TABLE BIEN (
    id_bien SERIAL PRIMARY KEY,
    id_secteur INT NOT NULL,
    reference_interne VARCHAR(50),
    type_bien enum_type_bien,
    surface_habitable DECIMAL(8,2),
    surface_terrain DECIMAL(8,2),
    nb_pieces INT,
    nb_chambres INT,
    nb_salles_bain INT,
    nb_places_parking INT,
    etage INT,
    annee_construction INT,
    type_chauffage enum_type_chauffage,
    dpe enum_dpe,
    ges enum_dpe,
    etat enum_etat_attendu,
    charges_copropriete DECIMAL(10,2),
    taxe_fonciere DECIMAL(10,2),
    date_disponibilite DATE,
    adresse VARCHAR(255)
);

CREATE TABLE BIEN_CARACTERISTIQUE (
    id_bien INT NOT NULL,
    id_caracteristique INT NOT NULL,
    PRIMARY KEY (id_bien, id_caracteristique)
);

CREATE TABLE ANNONCE (
    id_annonce SERIAL PRIMARY KEY,
    id_bien INT NOT NULL,
    source VARCHAR(100),
    type_emetteur VARCHAR(50),
    denomination_emetteur VARCHAR(100),
    contact_email VARCHAR(150),
    contact_telephone VARCHAR(20),
    prix_affiche DECIMAL(12,2),
    date_publication DATE,
    date_retrait DATE
);

-- ==========================================
-- PROPOSITION, VISITES, ET OFFRES
-- ==========================================
CREATE TABLE PROPOSITION (
    id_proposition SERIAL PRIMARY KEY,
    id_version INT NOT NULL,
    id_annonce INT NOT NULL,
    date_proposition TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    rang_pertinence INT,
    suite_donnee enum_suite_donnee DEFAULT 'en attente',
    motif_ecart TEXT
);

CREATE TABLE COMMENTAIRE (
    id_commentaire SERIAL PRIMARY KEY,
    id_proposition INT NOT NULL,
    id_auteur INT NOT NULL,
    type enum_type_commentaire,
    contenu TEXT NOT NULL,
    date_redaction TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE PIECE_JOINTE (
    id_piece SERIAL PRIMARY KEY,
    id_commentaire INT NOT NULL,
    media enum_media_pj,
    uri VARCHAR(255) NOT NULL
);

CREATE TABLE VISITE (
    id_visite SERIAL PRIMARY KEY,
    id_proposition INT NOT NULL,
    id_visiteur INT NOT NULL,
    date_visite DATE NOT NULL
);

CREATE TABLE OFFRE_ACQUISITION (
    id_offre SERIAL PRIMARY KEY,
    id_proposition INT NOT NULL,
    id_offre_precedente INT,
    emetteur enum_emetteur_offre,
    origine_decouverte enum_origine_decouverte,
    montant DECIMAL(12,2) NOT NULL,
    date_signature DATE NOT NULL,
    date_transmission DATE,
    date_validite DATE,
    statut enum_statut_offre DEFAULT 'en cours',
    date_reponse DATE
);

-- ==========================================
-- COMPROMIS ET ACTES (TUNNEL DE VENTE)
-- ==========================================
CREATE TABLE NOTAIRE (
    id_notaire SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    etude VARCHAR(150),
    email VARCHAR(150)
);

CREATE TABLE COMPROMIS (
    id_compromis SERIAL PRIMARY KEY,
    id_offre INT NOT NULL,
    id_notaire INT NOT NULL,
    date_signature DATE NOT NULL,
    fin_retractation DATE,
    depot_garantie DECIMAL(12,2),
    sequestre VARCHAR(100),
    date_acte_prevue DATE,
    statut enum_statut_compromis DEFAULT 'signé',
    motif_caducite enum_motif_caducite
);

CREATE TABLE CLAUSE_SUSPENSIVE (
    id_clause SERIAL PRIMARY KEY,
    id_compromis INT NOT NULL,
    type_clause enum_type_clause,
    description TEXT,
    date_butoir DATE,
    statut enum_statut_clause DEFAULT 'en attente'
);

CREATE TABLE ACTE (
    id_acte SERIAL PRIMARY KEY,
    id_compromis INT NOT NULL,
    date_signature DATE NOT NULL,
    montant_vente DECIMAL(12,2) NOT NULL,
    honoraires_fixe DECIMAL(10,2),
    honoraires_taux DECIMAL(5,2),
    honoraires_total DECIMAL(10,2)
);

-- ==========================================
-- RÉMUNÉRATION ET PERFORMANCE
-- ==========================================
CREATE TABLE BAREME (
    id_bareme SERIAL PRIMARY KEY,
    id_chasseur INT NOT NULL,
    date_debut DATE NOT NULL,
    date_fin DATE
);

CREATE TABLE TRANCHE_BAREME (
    id_tranche SERIAL PRIMARY KEY,
    id_bareme INT NOT NULL,
    montant_min DECIMAL(12,2) NOT NULL,
    montant_max DECIMAL(12,2),
    taux DECIMAL(5,2) NOT NULL
);

CREATE TABLE REMUNERATION (
    id_remuneration SERIAL PRIMARY KEY,
    id_acte INT NOT NULL,
    montant DECIMAL(12,2) NOT NULL,
    taux_applique DECIMAL(5,2),
    date_calcul TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE FACTURE (
    id_facture SERIAL PRIMARY KEY,
    id_remuneration INT NOT NULL,
    numero VARCHAR(50) UNIQUE NOT NULL,
    date_emission DATE NOT NULL,
    statut enum_statut_facture DEFAULT 'émise'
);

CREATE TABLE PAIEMENT (
    id_paiement SERIAL PRIMARY KEY,
    id_facture INT NOT NULL,
    date_paiement DATE NOT NULL,
    montant DECIMAL(12,2) NOT NULL,
    moyen enum_moyen_paiement,
    statut enum_statut_facture
);

CREATE TABLE INDICATEUR_PERFORMANCE (
    id_indicateur SERIAL PRIMARY KEY,
    id_chasseur INT NOT NULL,
    date_calcul DATE NOT NULL,
    nb_mandats_signes INT DEFAULT 0,
    nb_ventes_reussies INT DEFAULT 0,
    delai_moyen_semaines DECIMAL(5,2),
    part_exclusifs DECIMAL(5,2),
    nb_visites_moyen DECIMAL(5,2)
);
