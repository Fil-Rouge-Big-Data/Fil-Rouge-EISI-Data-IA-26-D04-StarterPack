-- =============================================================================
--  Plateforme de chasse immobiliere — MPD PostgreSQL 16 — v5
--  Schema : chasse
--  v5 : la clientele est exclusivement composee de particuliers.
--       CLIENT redevient un sous-type de UTILISATEUR ; les entreprises,
--       les beneficiaires effectifs et la table de representation sont retires.
-- =============================================================================

BEGIN;

-- Rejouabilité : le script recrée le schéma à neuf. Destructif par
-- construction — réservé aux environnements de développement et d'intégration.
DROP SCHEMA IF EXISTS chasse CASCADE;

-- Les extensions sont installées dans public, APRÈS le DROP et AVANT tout
-- SET search_path. L'ordre importe : sans clause WITH SCHEMA elles
-- atterriraient dans chasse et le DROP les emporterait à chaque rejeu ;
-- et placées avant le DROP, un IF NOT EXISTS ne les déplacerait pas depuis
-- chasse — le schéma serait ensuite détruit avec elles.
CREATE EXTENSION IF NOT EXISTS citext  WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;

CREATE SCHEMA chasse;
SET search_path = chasse, public;

-- ----------------------------------------------------------------- DOMAINES
CREATE DOMAIN d_email     AS citext        CHECK (VALUE ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$');
CREATE DOMAIN d_dpe       AS char(1)       CHECK (VALUE IN ('A','B','C','D','E','F','G'));
CREATE DOMAIN d_taux      AS numeric(5,2)  CHECK (VALUE >= 0 AND VALUE <= 100);
CREATE DOMAIN d_montant   AS numeric(12,2) CHECK (VALUE >= 0);
CREATE DOMAIN d_telephone AS text          CHECK (VALUE ~ '^\+?[0-9 .\-]{6,20}$');

-- ============================================================ 1. ACTEURS
CREATE TABLE utilisateur (
    id_utilisateur bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom            text        NOT NULL CHECK (char_length(nom) BETWEEN 1 AND 80),
    prenom         text        NOT NULL CHECK (char_length(prenom) BETWEEN 1 AND 80),
    email          d_email     NOT NULL UNIQUE,
    telephone      d_telephone,
    password_hash  text        NOT NULL,
    date_creation  timestamptz NOT NULL DEFAULT now(),
    actif          boolean     NOT NULL DEFAULT true
);
COMMENT ON TABLE utilisateur IS 'Personne physique. Sur-type des trois roles : client, chasseur, gestionnaire. Roles cumulables.';

-- v5 : le client est un particulier, donc une personne physique identifiee
-- par son compte. La specialisation remplace la table CLIENT autonome de la v4.
CREATE TABLE client (
    id_utilisateur              bigint PRIMARY KEY REFERENCES utilisateur(id_utilisateur) ON DELETE CASCADE,
    id_client_parrain           bigint REFERENCES client(id_utilisateur),
    date_parrainage             date,
    annee_naissance             smallint CHECK (annee_naissance BETWEEN 1900 AND 2020),
    primo_accedant              boolean     NOT NULL DEFAULT false,
    code_postal_residence       text,
    canal_contact_prefere       text        NOT NULL DEFAULT 'email'
        CHECK (canal_contact_prefere IN ('telephone','email','sms')),
    consentement_marketing      boolean     NOT NULL DEFAULT false,
    date_consentement_marketing timestamptz,
    niveau_vigilance            text        NOT NULL DEFAULT 'standard'
        CHECK (niveau_vigilance IN ('standard','renforcee')),
    date_derniere_verification  date,
    origine_fonds_declaree      text,
    CONSTRAINT ck_client_consent    CHECK (NOT consentement_marketing OR date_consentement_marketing IS NOT NULL),
    CONSTRAINT ck_client_parrain    CHECK (id_client_parrain IS NULL OR id_client_parrain <> id_utilisateur),
    CONSTRAINT ck_client_parrainage CHECK ((id_client_parrain IS NULL) = (date_parrainage IS NULL))
);

CREATE TABLE chasseur (
    id_utilisateur              bigint PRIMARY KEY REFERENCES utilisateur(id_utilisateur) ON DELETE CASCADE,
    numero_carte_t              text        NOT NULL UNIQUE,
    date_validite_carte_t       date        NOT NULL,
    prefecture_delivrance       text        NOT NULL,
    organisme_garant            text        NOT NULL,
    montant_garantie_financiere d_montant   NOT NULL,
    numero_rcp                  text        NOT NULL,
    date_echeance_rcp           date        NOT NULL,
    statut_juridique            text        NOT NULL
        CHECK (statut_juridique IN ('salarie','agent_commercial','independant')),
    numero_rsac                 text,
    date_entree_reseau          date        NOT NULL,
    date_sortie_reseau          date,
    capacite_max_mandats        smallint    NOT NULL DEFAULT 12 CHECK (capacite_max_mandats > 0),
    budget_min_intervention     d_montant,
    budget_max_intervention     d_montant,
    taux_honoraires_defaut      d_taux      NOT NULL,
    CONSTRAINT ck_chasseur_sortie CHECK (date_sortie_reseau IS NULL OR date_sortie_reseau >= date_entree_reseau),
    CONSTRAINT ck_chasseur_budget CHECK (budget_max_intervention IS NULL
                                      OR budget_min_intervention IS NULL
                                      OR budget_max_intervention >= budget_min_intervention),
    CONSTRAINT ck_chasseur_rsac   CHECK (statut_juridique <> 'agent_commercial' OR numero_rsac IS NOT NULL)
);

CREATE TABLE gestionnaire (
    id_utilisateur       bigint PRIMARY KEY REFERENCES utilisateur(id_utilisateur) ON DELETE CASCADE,
    matricule            text     NOT NULL UNIQUE,
    date_entree_fonction date     NOT NULL,
    date_sortie_fonction date,
    equipe               text     NOT NULL,
    capacite_max_leads   smallint NOT NULL DEFAULT 40 CHECK (capacite_max_leads > 0),
    CONSTRAINT ck_gestionnaire_sortie CHECK (date_sortie_fonction IS NULL OR date_sortie_fonction >= date_entree_fonction)
);

CREATE TABLE indisponibilite (
    id_utilisateur bigint NOT NULL REFERENCES utilisateur(id_utilisateur) ON DELETE CASCADE,
    date_debut     date   NOT NULL,
    date_fin       date,
    motif          text   NOT NULL CHECK (motif IN ('conge','arret','formation','autre')),
    PRIMARY KEY (id_utilisateur, date_debut),
    CONSTRAINT ck_indispo_bornes CHECK (date_fin IS NULL OR date_fin >= date_debut)
);

-- ======================================================= 2. REFERENTIEL ZONE
CREATE TABLE zone (
    id_zone        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_zone_parent bigint REFERENCES zone(id_zone),
    type_zone      text NOT NULL CHECK (type_zone IN ('ville','quartier','code_postal')),
    libelle        text NOT NULL,
    code_insee     char(5),
    code_postal    text,
    CONSTRAINT ck_zone_insee  CHECK (type_zone <> 'ville' OR code_insee IS NOT NULL),
    CONSTRAINT ck_zone_parent CHECK (id_zone_parent IS NULL OR type_zone <> 'ville'),
    CONSTRAINT ck_zone_boucle CHECK (id_zone_parent IS NULL OR id_zone_parent <> id_zone)
);
CREATE UNIQUE INDEX ux_zone_insee ON zone(code_insee) WHERE type_zone = 'ville';

CREATE TABLE chasseur_zone (
    id_utilisateur    bigint NOT NULL REFERENCES chasseur(id_utilisateur) ON DELETE CASCADE,
    id_zone           bigint NOT NULL REFERENCES zone(id_zone),
    role_intervention text   NOT NULL DEFAULT 'titulaire'
        CHECK (role_intervention IN ('titulaire','renfort')),
    PRIMARY KEY (id_utilisateur, id_zone)
);

-- ============================================================== 3. RECHERCHE
CREATE TABLE demande (
    id_demande            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_gestionnaire       bigint      REFERENCES gestionnaire(id_utilisateur),
    id_chasseur           bigint      REFERENCES chasseur(id_utilisateur),
    date_depot            timestamptz NOT NULL DEFAULT now(),
    canal                 text        NOT NULL CHECK (canal IN ('site_web','parrainage','telephone')),
    description_initiale  text,
    statut                text        NOT NULL DEFAULT 'en_attente_affectation'
        CHECK (statut IN ('en_attente_affectation','affectee','qualifiee','sous_mandat','close','sans_suite')),
    date_consentement     timestamptz,
    date_affectation      timestamptz,
    date_qualification    timestamptz,
    date_cloture          timestamptz,
    motif_sans_suite      text CHECK (motif_sans_suite IN ('budget_irrealiste','injoignable','hors_zone','deja_engage','autre')),
    nb_relances           smallint    NOT NULL DEFAULT 0 CHECK (nb_relances >= 0),
    statut_financement    text        NOT NULL DEFAULT 'non_evalue'
        CHECK (statut_financement IN ('non_evalue','en_cours','accord_principe','accord_ferme','refuse')),
    apport_disponible     d_montant,
    montant_pret_envisage d_montant,
    date_accord_principe  date,
    date_validite_accord  date,
    CONSTRAINT ck_demande_consent   CHECK (canal <> 'site_web' OR date_consentement IS NOT NULL),
    CONSTRAINT ck_demande_sanssuite CHECK (statut <> 'sans_suite' OR motif_sans_suite IS NOT NULL),
    CONSTRAINT ck_demande_chrono    CHECK (date_affectation IS NULL OR date_affectation >= date_depot),
    CONSTRAINT ck_demande_chrono2   CHECK (date_qualification IS NULL OR date_affectation IS NOT NULL),
    CONSTRAINT ck_demande_accord    CHECK (date_validite_accord IS NULL OR date_accord_principe IS NULL
                                        OR date_validite_accord >= date_accord_principe)
);

CREATE TABLE demande_acquereur (
    id_demande bigint NOT NULL REFERENCES demande(id_demande) ON DELETE CASCADE,
    id_client  bigint NOT NULL REFERENCES client(id_utilisateur),
    qualite    text   NOT NULL CHECK (qualite IN ('principal','co_acquereur')),
    PRIMARY KEY (id_demande, id_client)
);
CREATE UNIQUE INDEX ux_acquereur_principal ON demande_acquereur(id_demande) WHERE qualite = 'principal';

CREATE TABLE affectation (
    id_affectation  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_demande      bigint      NOT NULL REFERENCES demande(id_demande) ON DELETE CASCADE,
    id_gestionnaire bigint      NOT NULL REFERENCES gestionnaire(id_utilisateur),
    id_chasseur     bigint      REFERENCES chasseur(id_utilisateur),
    date_debut      timestamptz NOT NULL DEFAULT now(),
    date_fin        timestamptz,
    motif           text        NOT NULL DEFAULT 'affectation_initiale'
        CHECK (motif IN ('affectation_initiale','reaffectation_surcharge','reaffectation_absence','reaffectation_client','autre')),
    CONSTRAINT uk_affectation        UNIQUE (id_demande, date_debut),
    CONSTRAINT ck_affectation_bornes CHECK (date_fin IS NULL OR date_fin >= date_debut)
);
CREATE UNIQUE INDEX ux_affectation_ouverte ON affectation(id_demande) WHERE date_fin IS NULL;

CREATE TABLE demande_version (
    id_version           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_demande           bigint      NOT NULL REFERENCES demande(id_demande) ON DELETE CASCADE,
    id_modifie_par       bigint      NOT NULL REFERENCES utilisateur(id_utilisateur),
    no_version           smallint    NOT NULL CHECK (no_version > 0),
    date_creation        timestamptz NOT NULL DEFAULT now(),
    motif_evolution      text,
    type_bien            text        NOT NULL CHECK (type_bien IN ('appartement','maison','loft','terrain','immeuble')),
    destination          text        NOT NULL DEFAULT 'residence_principale'
        CHECK (destination IN ('residence_principale','residence_secondaire','locatif')),
    budget_max           d_montant   NOT NULL,
    surface_min          smallint    CHECK (surface_min > 0),
    nb_pieces_min        smallint    CHECK (nb_pieces_min > 0),
    nb_chambres_min      smallint    CHECK (nb_chambres_min >= 0),
    nb_occupants         smallint    CHECK (nb_occupants > 0),
    dpe_max              d_dpe,
    rendement_brut_min   numeric(5,2) CHECK (rendement_brut_min >= 0),
    travaux_acceptes     boolean     NOT NULL DEFAULT true,
    exige_ascenseur      boolean     NOT NULL DEFAULT false,
    exige_balcon         boolean     NOT NULL DEFAULT false,
    exige_terrasse       boolean     NOT NULL DEFAULT false,
    exige_jardin         boolean     NOT NULL DEFAULT false,
    exige_parking        boolean     NOT NULL DEFAULT false,
    exige_cave           boolean     NOT NULL DEFAULT false,
    commentaire_criteres text,
    est_courante         boolean     NOT NULL DEFAULT false,
    CONSTRAINT uk_version_no        UNIQUE (id_demande, no_version),
    CONSTRAINT uk_version_alt       UNIQUE (id_demande, id_version),
    CONSTRAINT ck_version_chambres  CHECK (nb_chambres_min IS NULL OR nb_pieces_min IS NULL OR nb_chambres_min < nb_pieces_min),
    CONSTRAINT ck_version_rendement CHECK (rendement_brut_min IS NULL OR destination = 'locatif')
);
CREATE UNIQUE INDEX ux_version_courante ON demande_version(id_demande) WHERE est_courante;

CREATE TABLE version_zone (
    id_version bigint NOT NULL REFERENCES demande_version(id_version) ON DELETE CASCADE,
    id_zone    bigint NOT NULL REFERENCES zone(id_zone),
    PRIMARY KEY (id_version, id_zone)
);

-- ====================================================== 4. CONTRACTUALISATION
CREATE TABLE mandat (
    id_mandat                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_demande               bigint   NOT NULL,
    id_version_contractuelle bigint   NOT NULL,
    id_chasseur              bigint   NOT NULL REFERENCES chasseur(id_utilisateur),
    id_signataire            bigint   NOT NULL,
    numero_registre          text     NOT NULL UNIQUE,
    date_signature           date     NOT NULL,
    mode_signature           text     NOT NULL CHECK (mode_signature IN ('presentiel','en_ligne')),
    date_debut               date     NOT NULL,
    duree_mois               smallint NOT NULL DEFAULT 6 CHECK (duree_mois BETWEEN 1 AND 24),
    date_fin                 date GENERATED ALWAYS AS
                                ((date_debut + (duree_mois * INTERVAL '1 month'))::date) STORED,
    exclusif                 boolean  NOT NULL DEFAULT true,
    statut                   text     NOT NULL DEFAULT 'actif'
        CHECK (statut IN ('actif','expire','renouvele','resilie','clos_succes')),
    taux_honoraires          d_taux,
    base_honoraires          text     NOT NULL DEFAULT 'TTC' CHECK (base_honoraires IN ('HT','TTC')),
    taux_tva                 d_taux   NOT NULL DEFAULT 20.00,
    forfait_honoraires       d_montant,
    qualite_signataire       text     NOT NULL DEFAULT 'en son nom propre',
    reference_procuration    text,
    date_resiliation         date,
    motif_resiliation        text,
    CONSTRAINT fk_mandat_demande    FOREIGN KEY (id_demande) REFERENCES demande(id_demande),
    CONSTRAINT fk_mandat_version    FOREIGN KEY (id_demande, id_version_contractuelle)
        REFERENCES demande_version(id_demande, id_version),
    -- v5 : le signataire est necessairement un acquereur de la demande.
    -- La verification devient declarative : elle etait procedurale en v4.
    CONSTRAINT fk_mandat_signataire FOREIGN KEY (id_demande, id_signataire)
        REFERENCES demande_acquereur(id_demande, id_client),
    CONSTRAINT ck_mandat_effet        CHECK (date_debut >= date_signature),
    CONSTRAINT ck_mandat_remuneration CHECK (num_nonnulls(taux_honoraires, forfait_honoraires) >= 1),
    CONSTRAINT ck_mandat_procuration  CHECK (qualite_signataire = 'en son nom propre' OR reference_procuration IS NOT NULL),
    CONSTRAINT ck_mandat_resiliation  CHECK (statut <> 'resilie'
        OR (date_resiliation IS NOT NULL AND motif_resiliation IS NOT NULL)),
    CONSTRAINT ck_mandat_resil_date   CHECK (date_resiliation IS NULL OR date_resiliation >= date_debut)
);
CREATE UNIQUE INDEX ux_mandat_actif ON mandat(id_demande) WHERE statut = 'actif';

-- ============================================================ 5. OFFRE
CREATE TABLE bien (
    id_bien            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_zone            bigint NOT NULL REFERENCES zone(id_zone),
    type_bien          text   NOT NULL CHECK (type_bien IN ('appartement','maison','loft','terrain','immeuble')),
    surface            numeric(8,2) CHECK (surface > 0),
    nb_pieces          smallint CHECK (nb_pieces > 0),
    nb_chambres        smallint CHECK (nb_chambres >= 0),
    etage              smallint,
    dpe                d_dpe,
    adresse_indicative text,
    code_postal        text,
    a_ascenseur        boolean,
    a_balcon           boolean,
    a_terrasse         boolean,
    a_jardin           boolean,
    a_parking          boolean,
    a_cave             boolean
);

CREATE TABLE annonce (
    id_annonce        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_bien           bigint      NOT NULL REFERENCES bien(id_bien) ON DELETE CASCADE,
    source            text        NOT NULL,
    reference_source  text        NOT NULL,
    titre             text,
    description       text,
    prix              d_montant   NOT NULL,
    url               text,
    date_publication  timestamptz,
    date_ingestion    timestamptz NOT NULL DEFAULT now(),
    date_derniere_vue timestamptz NOT NULL DEFAULT now(),
    statut            text        NOT NULL DEFAULT 'active'
        CHECK (statut IN ('active','retiree','vendue')),
    CONSTRAINT uk_annonce_source UNIQUE (source, reference_source),
    CONSTRAINT uk_annonce_bien   UNIQUE (id_bien, id_annonce)
);

CREATE TABLE proposition (
    id_proposition         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_demande             bigint      NOT NULL,
    id_version             bigint      NOT NULL,
    id_bien                bigint      NOT NULL,
    id_annonce_reference   bigint,
    date_matching          timestamptz NOT NULL DEFAULT now(),
    date_soumission_client timestamptz,
    date_reponse_client    timestamptz,
    score_matching         numeric(5,2) NOT NULL CHECK (score_matching BETWEEN 0 AND 100),
    statut                 text        NOT NULL DEFAULT 'a_qualifier'
        CHECK (statut IN ('a_qualifier','soumis_client','retenu_visite','refuse_client','ecarte_chasseur')),
    motif_rejet            text,
    CONSTRAINT fk_proposition_demande FOREIGN KEY (id_demande) REFERENCES demande(id_demande) ON DELETE CASCADE,
    CONSTRAINT fk_proposition_version FOREIGN KEY (id_demande, id_version)
        REFERENCES demande_version(id_demande, id_version),
    CONSTRAINT fk_proposition_bien    FOREIGN KEY (id_bien) REFERENCES bien(id_bien),
    CONSTRAINT fk_proposition_annonce FOREIGN KEY (id_bien, id_annonce_reference)
        REFERENCES annonce(id_bien, id_annonce),
    CONSTRAINT uk_proposition         UNIQUE (id_demande, id_bien),
    CONSTRAINT ck_proposition_rejet   CHECK (statut <> 'refuse_client' OR motif_rejet IS NOT NULL),
    CONSTRAINT ck_proposition_chrono  CHECK (date_soumission_client IS NULL OR date_soumission_client >= date_matching),
    CONSTRAINT ck_proposition_chrono2 CHECK (date_reponse_client IS NULL OR date_soumission_client IS NOT NULL)
);

CREATE TABLE commentaire (
    id_commentaire bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_auteur      bigint      NOT NULL REFERENCES utilisateur(id_utilisateur),
    id_demande     bigint      REFERENCES demande(id_demande) ON DELETE CASCADE,
    id_proposition bigint      REFERENCES proposition(id_proposition) ON DELETE CASCADE,
    type_contexte  text        NOT NULL
        CHECK (type_contexte IN ('note_recherche','debrief_visite','analyse_annonce')),
    est_prive      boolean     NOT NULL DEFAULT true,
    contenu        text        NOT NULL,
    date_creation  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_commentaire_cible CHECK (num_nonnulls(id_demande, id_proposition) = 1)
);

-- ============================================================ 6. PILOTAGE
CREATE TABLE indicateur (
    code_indicateur text PRIMARY KEY,
    libelle         text NOT NULL,
    unite           text NOT NULL CHECK (unite IN ('heure','jour','pourcentage','euro','nombre')),
    perimetre_role  text NOT NULL CHECK (perimetre_role IN ('chasseur','gestionnaire','client','global')),
    sens_optimal    text NOT NULL CHECK (sens_optimal IN ('croissant','decroissant')),
    mode_calcul     text NOT NULL
);

CREATE TABLE periode (
    id_periode   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type_periode text NOT NULL CHECK (type_periode IN ('mois','trimestre','annee')),
    date_debut   date NOT NULL,
    date_fin     date NOT NULL,
    CONSTRAINT uk_periode        UNIQUE (type_periode, date_debut),
    CONSTRAINT ck_periode_bornes CHECK (date_fin > date_debut)
);

CREATE TABLE observation (
    id_utilisateur  bigint        NOT NULL REFERENCES utilisateur(id_utilisateur) ON DELETE CASCADE,
    code_indicateur text          NOT NULL REFERENCES indicateur(code_indicateur),
    id_periode      bigint        NOT NULL REFERENCES periode(id_periode),
    valeur          numeric(14,4) NOT NULL,
    date_calcul     timestamptz   NOT NULL DEFAULT now(),
    PRIMARY KEY (id_utilisateur, code_indicateur, id_periode)
);

CREATE TABLE objectif (
    id_utilisateur  bigint        NOT NULL REFERENCES utilisateur(id_utilisateur) ON DELETE CASCADE,
    code_indicateur text          NOT NULL REFERENCES indicateur(code_indicateur),
    id_periode      bigint        NOT NULL REFERENCES periode(id_periode),
    valeur_cible    numeric(14,4) NOT NULL,
    date_fixation   timestamptz   NOT NULL DEFAULT now(),
    PRIMARY KEY (id_utilisateur, code_indicateur, id_periode)
);

-- ====================================================== 7. INDEX DE TRAVAIL
CREATE INDEX ix_client_parrain       ON client(id_client_parrain) WHERE id_client_parrain IS NOT NULL;
CREATE INDEX ix_demande_gestionnaire ON demande(id_gestionnaire) WHERE id_gestionnaire IS NOT NULL;
CREATE INDEX ix_demande_chasseur     ON demande(id_chasseur) WHERE id_chasseur IS NOT NULL;
CREATE INDEX ix_demande_statut       ON demande(statut, date_depot DESC);
CREATE INDEX ix_acquereur_client     ON demande_acquereur(id_client);
CREATE INDEX ix_affectation_gest     ON affectation(id_gestionnaire, date_debut DESC);
CREATE INDEX ix_affectation_chasseur ON affectation(id_chasseur, date_debut DESC) WHERE id_chasseur IS NOT NULL;
CREATE INDEX ix_version_demande      ON demande_version(id_demande, no_version DESC);
CREATE INDEX ix_version_modifie      ON demande_version(id_modifie_par);
CREATE INDEX ix_versionzone_zone     ON version_zone(id_zone);
CREATE INDEX ix_chasseurzone_zone    ON chasseur_zone(id_zone);
CREATE INDEX ix_mandat_chasseur      ON mandat(id_chasseur, statut);
CREATE INDEX ix_mandat_echeance      ON mandat(date_fin) WHERE statut = 'actif';
CREATE INDEX ix_mandat_signataire    ON mandat(id_signataire);
CREATE INDEX ix_mandat_version       ON mandat(id_version_contractuelle);
CREATE INDEX ix_bien_matching        ON bien(id_zone, type_bien, surface, nb_pieces);
CREATE INDEX ix_annonce_bien         ON annonce(id_bien);
CREATE INDEX ix_annonce_active       ON annonce(statut, date_derniere_vue DESC) WHERE statut = 'active';
CREATE INDEX ix_annonce_prix         ON annonce(prix) WHERE statut = 'active';
CREATE INDEX ix_annonce_titre_trgm   ON annonce USING gin (titre gin_trgm_ops);
CREATE INDEX ix_proposition_version  ON proposition(id_version);
CREATE INDEX ix_proposition_bien     ON proposition(id_bien);
CREATE INDEX ix_proposition_statut   ON proposition(id_demande, statut);
CREATE INDEX ix_commentaire_demande  ON commentaire(id_demande) WHERE id_demande IS NOT NULL;
CREATE INDEX ix_commentaire_prop     ON commentaire(id_proposition) WHERE id_proposition IS NOT NULL;
CREATE INDEX ix_commentaire_auteur   ON commentaire(id_auteur);
CREATE INDEX ix_observation_periode  ON observation(id_periode, code_indicateur);
-- Couverture des cinq dernières clés étrangères (revue PR #10, point C3).
-- Sans elles, toute suppression dans la table référencée provoque un
-- parcours complet de la table fille.
CREATE INDEX ix_zone_parent           ON zone(id_zone_parent) WHERE id_zone_parent IS NOT NULL;
CREATE INDEX ix_mandat_demande        ON mandat(id_demande);
CREATE INDEX ix_observation_indicateur ON observation(code_indicateur);
CREATE INDEX ix_objectif_indicateur   ON objectif(code_indicateur);
CREATE INDEX ix_objectif_periode      ON objectif(id_periode);

-- ================================================ 8. FONCTIONS ET TRIGGERS

-- C4 (totalite) : toute demande possede un acquereur principal.
CREATE FUNCTION trg_demande_acquereur() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM demande_acquereur
                   WHERE id_demande = NEW.id_demande AND qualite = 'principal') THEN
        RAISE EXCEPTION 'DEMANDE % sans acquereur principal', NEW.id_demande;
    END IF;
    RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER tg_demande_acquereur
    AFTER INSERT OR UPDATE ON demande
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION trg_demande_acquereur();

-- C4 (pendant) : la suppression ou la requalification de l'acquéreur principal
-- laissait la demande sans principal, sans aucun rejet (revue PR #10, point N2).
-- Le garde-fou doit exister des deux côtés de l'association.
CREATE FUNCTION trg_acquereur_principal() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE cible bigint := COALESCE(NEW.id_demande, OLD.id_demande);
BEGIN
    -- Si la demande elle-même a disparu (cascade), il n'y a rien à garantir.
    IF NOT EXISTS (SELECT 1 FROM demande WHERE id_demande = cible) THEN
        RETURN NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM demande_acquereur
                   WHERE id_demande = cible AND qualite = 'principal') THEN
        RAISE EXCEPTION 'DEMANDE % sans acquereur principal', cible;
    END IF;
    RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER tg_acquereur_principal
    AFTER UPDATE OR DELETE ON demande_acquereur
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION trg_acquereur_principal();

-- C9 : on ne fige pas un indicateur sur une periode non close.
CREATE FUNCTION trg_observation_periode() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE fin date;
BEGIN
    SELECT date_fin INTO fin FROM periode WHERE id_periode = NEW.id_periode;
    IF NEW.date_calcul::date <= fin THEN
        RAISE EXCEPTION 'Periode % non close a la date de calcul %', NEW.id_periode, NEW.date_calcul;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_observation_periode
    BEFORE INSERT OR UPDATE ON observation
    FOR EACH ROW EXECUTE FUNCTION trg_observation_periode();

-- Doit etre BEFORE : l'index unique partiel est verifie a l'insertion de la ligne,
-- donc avant tout declenchement AFTER. Un trigger AFTER echouerait sur ux_version_courante.
CREATE FUNCTION trg_version_courante() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    UPDATE demande_version
       SET est_courante = false
     WHERE id_demande = NEW.id_demande
       AND id_version IS DISTINCT FROM NEW.id_version
       AND est_courante;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_version_courante
    BEFORE INSERT OR UPDATE OF est_courante ON demande_version
    FOR EACH ROW WHEN (NEW.est_courante)
    EXECUTE FUNCTION trg_version_courante();

-- Synchronisation de la denormalisation demande.id_gestionnaire / id_chasseur.
-- La denormalisation reflete l'affectation OUVERTE. Elle est donc recalculee
-- a chaque ecriture, y compris a la cloture : sans cela, demande.id_chasseur
-- conservait l'ancien chasseur apres une cloture sans reaffectation
-- (revue PR #10, point N3).
CREATE FUNCTION trg_affectation_sync() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE cible bigint := COALESCE(NEW.id_demande, OLD.id_demande);
        ouverte affectation%ROWTYPE;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM demande WHERE id_demande = cible) THEN
        RETURN NULL;
    END IF;
    SELECT * INTO ouverte FROM affectation
     WHERE id_demande = cible AND date_fin IS NULL;
    UPDATE demande
       SET id_gestionnaire  = ouverte.id_gestionnaire,
           id_chasseur      = ouverte.id_chasseur,
           date_affectation = COALESCE(date_affectation, ouverte.date_debut),
           statut           = CASE WHEN statut = 'en_attente_affectation'
                                        AND ouverte.id_demande IS NOT NULL
                                   THEN 'affectee' ELSE statut END
     WHERE id_demande = cible;
    RETURN NULL;
END $$;
CREATE TRIGGER tg_affectation_sync
    AFTER INSERT OR UPDATE OR DELETE ON affectation
    FOR EACH ROW EXECUTE FUNCTION trg_affectation_sync();

-- ============================================================== 9. VUES
CREATE VIEW v_mandat_actif AS
SELECT m.* FROM mandat m
WHERE m.statut = 'actif' AND m.date_fin >= current_date;
COMMENT ON VIEW v_mandat_actif IS 'Seul point de lecture des mandats en cours : un CHECK sur current_date serait inoperant.';

CREATE VIEW v_version_courante AS
SELECT v.* FROM demande_version v WHERE v.est_courante;

CREATE VIEW v_charge_gestionnaire AS
SELECT a.id_gestionnaire,
       count(*) FILTER (WHERE a.date_fin IS NULL) AS leads_en_cours,
       g.capacite_max_leads,
       round(100.0 * count(*) FILTER (WHERE a.date_fin IS NULL)
             / nullif(g.capacite_max_leads, 0), 1) AS taux_charge_pct
FROM affectation a
JOIN gestionnaire g ON g.id_utilisateur = a.id_gestionnaire
GROUP BY a.id_gestionnaire, g.capacite_max_leads;

CREATE VIEW v_conformite_chasseur AS
SELECT c.id_utilisateur, c.numero_carte_t, c.date_validite_carte_t, c.date_echeance_rcp,
       (c.date_validite_carte_t < current_date) AS carte_expiree,
       (c.date_echeance_rcp     < current_date) AS rcp_expiree,
       count(m.id_mandat) FILTER (WHERE m.date_signature > c.date_validite_carte_t) AS mandats_hors_validite
FROM chasseur c
LEFT JOIN mandat m ON m.id_chasseur = c.id_utilisateur
GROUP BY c.id_utilisateur, c.numero_carte_t, c.date_validite_carte_t, c.date_echeance_rcp;

CREATE VIEW v_delai_affectation AS
SELECT d.id_demande, d.id_gestionnaire, d.canal,
       extract(epoch FROM (d.date_affectation - d.date_depot)) / 3600.0 AS delai_heures
FROM demande d
WHERE d.date_affectation IS NOT NULL;

COMMIT;
