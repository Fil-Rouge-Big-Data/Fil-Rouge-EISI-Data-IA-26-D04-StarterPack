-- ============================================================
-- MPD v8.4 — Chasse immobilière — PostgreSQL 18 (compatible 16+)
-- Clés UUIDv7 (ADR-028 rév., ADR-044), mandat refondu (ADR-030),
-- chaîne de rémunération (ADR-031), corrections d'intégrité (ADR-032/045),
-- parrainage parrain (ADR-034 rév.), prise d'effet mandat (ADR-037),
-- gel conformité signature (ADR-039), habilitation Hoguet (ADR-046),
-- qualité & nettoyages (ADR-040).
-- ============================================================
-- En-tête rejouable et transactionnel (A11/ADR-041).
BEGIN;

DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
SET search_path TO public;

CREATE EXTENSION IF NOT EXISTS citext;      -- email insensible casse
CREATE EXTENSION IF NOT EXISTS pg_trgm;     -- rapprochement annonces
CREATE EXTENSION IF NOT EXISTS btree_gist;  -- contraintes d'exclusion (barème, ADR-045)

-- B4/ADR-047 : date de référence reproductible. Les vues qui jugent une
-- expiration (mandat échu, habilitation expirée) lisent cette fonction au lieu
-- de current_date. En production, aucune config -> current_date (comportement
-- normal). En contrôle de reprise ou test : SET chasse.date_reference = '2026-07-25'
-- rend le résultat déterministe, indépendant du jour d'exécution.
CREATE OR REPLACE FUNCTION date_reference() RETURNS date AS $$
  SELECT COALESCE(
    NULLIF(current_setting('chasse.date_reference', true), '')::date,
    current_date
  );
$$ LANGUAGE sql STABLE;

-- UUIDv7 (ADR-044) : clés ordonnées dans le temps -> pas de fragmentation
-- d'index sur les tables à forte insertion (annonce, proposition, visées à
-- des centaines de millions de lignes). En PostgreSQL 18, uuidv7() est NATIF.
-- Fallback ci-dessous pour PostgreSQL 16/17 : même sémantique (48 bits de
-- timestamp ms + version 7 + aléatoire), le type reste 'uuid' dans tous les cas.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'uuidv7') THEN
    CREATE FUNCTION uuidv7() RETURNS uuid AS $f$
      SELECT encode(
        set_bit(set_bit(
          overlay(uuid_send(gen_random_uuid())
                  placing substring(int8send((extract(epoch from clock_timestamp())*1000)::bigint) from 3)
                  from 1 for 6),
          52, 1), 53, 1), 'hex')::uuid;
    $f$ LANGUAGE sql VOLATILE;
  END IF;
END $$;

-- ------------------------------------------------------------
-- Domaines
-- ------------------------------------------------------------
CREATE DOMAIN d_email    AS citext        CHECK (VALUE ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$');
CREATE DOMAIN d_dpe      AS char(1)       CHECK (VALUE IN ('A','B','C','D','E','F','G'));
-- EXCL/ADR-052 : intention du client sur un critère (balcon, jardin…).
CREATE DOMAIN d_preference AS text CHECK (VALUE IN ('exige','souhaite','exclut','indifferent'));
CREATE DOMAIN d_taux     AS numeric(5,2)  CHECK (VALUE BETWEEN 0 AND 100);
CREATE DOMAIN d_montant  AS numeric(12,2) CHECK (VALUE >= 0);
CREATE DOMAIN d_tel      AS text          CHECK (VALUE ~ '^\+?[0-9 .\-]{6,20}$');

-- ------------------------------------------------------------
-- Acteurs
-- ------------------------------------------------------------
CREATE TABLE utilisateur (
    id_utilisateur      uuid PRIMARY KEY DEFAULT uuidv7(),
    nom                 text NOT NULL CHECK (length(nom) <= 80),
    prenom              text NOT NULL CHECK (length(prenom) <= 80),
    email               d_email NOT NULL UNIQUE,
    telephone           d_tel,
    password_hash       text NOT NULL,
    date_creation       timestamptz NOT NULL DEFAULT now(),
    actif               boolean NOT NULL DEFAULT true,
    date_anonymisation  timestamptz,
    CONSTRAINT ck_utilisateur_anonymise CHECK (date_anonymisation IS NULL OR actif = false)  -- C12
);

CREATE TABLE client (
    id_utilisateur              uuid PRIMARY KEY REFERENCES utilisateur(id_utilisateur),
    -- E7/ADR-034 : parrainage filleul-seul. Un unique drapeau ; code/unicité/
    -- token/attribution gérés hors OLTP. id_client_parrain/date_parrainage retirés.
    frais_dossier_offerts       boolean NOT NULL DEFAULT false,
    annee_naissance             smallint CHECK (annee_naissance BETWEEN 1900 AND 2100),
    primo_accedant              boolean NOT NULL DEFAULT false,
    code_postal_residence       text CHECK (code_postal_residence ~ '^[0-9]{5}$'),
    canal_contact_prefere       text CHECK (canal_contact_prefere IN ('telephone','email','sms')),
    consentement_marketing      boolean NOT NULL DEFAULT false,
    date_consentement_marketing timestamptz,
    niveau_vigilance            text NOT NULL DEFAULT 'standard' CHECK (niveau_vigilance IN ('standard','renforcee')),
    date_derniere_verification  date,
    origine_fonds_declaree      text,
    CONSTRAINT ck_client_consent_mkg   CHECK (consentement_marketing = false OR date_consentement_marketing IS NOT NULL)
);

CREATE TABLE chasseur (
    id_utilisateur              uuid PRIMARY KEY REFERENCES utilisateur(id_utilisateur),
    -- D1/ADR-046 (loi Hoguet) : le titulaire d'agence détient une CARTE T ; les
    -- négociateurs salariés / agents commerciaux exercent sous une ATTESTATION
    -- d'habilitation nominative rattachée à cette carte. Le numéro n'est donc PAS
    -- unique (plusieurs collaborateurs d'une agence relèvent de la même carte).
    type_habilitation           text NOT NULL CHECK (type_habilitation IN ('carte_t','attestation')),
    numero_habilitation         text NOT NULL,                   -- n° carte T ou n° attestation
    date_validite_habilitation  date NOT NULL,                   -- carte T ou attestation en cours de validité (exigence métier)
    organisme_delivrance        text NOT NULL,                   -- CCI (depuis 2015), ex-préfecture
    organisme_garant            text NOT NULL,
    montant_garantie_financiere d_montant NOT NULL CHECK (montant_garantie_financiere > 0),
    numero_rcp                  text NOT NULL,
    date_echeance_rcp           date NOT NULL,
    statut_juridique            text NOT NULL CHECK (statut_juridique IN ('salarie','agent_commercial','independant')),
    numero_rsac                 text,
    date_entree_reseau          date NOT NULL,
    date_sortie_reseau          date,
    capacite_max_mandats        smallint NOT NULL CHECK (capacite_max_mandats > 0),
    budget_min_intervention     d_montant,
    budget_max_intervention     d_montant,
    taux_honoraires_defaut      d_taux,
    CONSTRAINT ck_chasseur_sortie  CHECK (date_sortie_reseau IS NULL OR date_sortie_reseau >= date_entree_reseau),
    CONSTRAINT ck_chasseur_budget  CHECK (budget_min_intervention IS NULL OR budget_max_intervention IS NULL OR budget_min_intervention <= budget_max_intervention),
    CONSTRAINT ck_chasseur_rsac    CHECK (statut_juridique <> 'agent_commercial' OR numero_rsac IS NOT NULL),
    -- salarié -> attestation (ne peut détenir la carte T en propre) ; titulaire indépendant -> carte T possible.
    CONSTRAINT ck_chasseur_habilitation CHECK (statut_juridique <> 'salarie' OR type_habilitation = 'attestation')
);

CREATE TABLE gestionnaire (
    id_utilisateur       uuid PRIMARY KEY REFERENCES utilisateur(id_utilisateur),
    matricule            text NOT NULL UNIQUE,
    date_entree_fonction date NOT NULL,
    date_sortie_fonction date,
    equipe               text,
    capacite_max_leads   smallint NOT NULL CHECK (capacite_max_leads > 0),
    CONSTRAINT ck_gestionnaire_sortie CHECK (date_sortie_fonction IS NULL OR date_sortie_fonction >= date_entree_fonction)
);



CREATE TABLE indisponibilite (
    id_utilisateur uuid NOT NULL REFERENCES utilisateur(id_utilisateur),
    date_debut     date NOT NULL,
    date_fin       date,
    motif          text NOT NULL CHECK (motif IN ('conge','arret','formation','autre')),
    PRIMARY KEY (id_utilisateur, date_debut),
    CONSTRAINT ck_indispo_dates CHECK (date_fin IS NULL OR date_fin >= date_debut)
);

-- ------------------------------------------------------------
-- Référentiel géographique (ADR-022)
-- ------------------------------------------------------------
CREATE TABLE zone (
    id_zone       uuid PRIMARY KEY DEFAULT uuidv7(),
    type_zone     text NOT NULL CHECK (type_zone IN ('ville','secteur')),
    pays          text NOT NULL,
    code_iso_pays char(2) NOT NULL CHECK (code_iso_pays ~ '^[A-Z]{2}$'),
    devise        char(3) NOT NULL CHECK (devise ~ '^[A-Z]{3}$'),
    -- E2/ADR-040 : citext neutralise les doublons orthographiques
    -- (« Montpellier » vs « montpellier ») qui polluaient matching et unicité.
    ville         citext NOT NULL,
    -- A5/ADR-032 : regex INSEE corrigée — Corse 2A/2B en 2e-3e position ;
    -- « 1234A » (accepté à tort par l'ancienne classe) désormais rejeté.
    code_insee    char(5) CHECK (code_insee ~ '^([0-9]{2}|2[AB])[0-9]{3}$'),
    secteur       citext,
    code_postal   text,
    CONSTRAINT ck_zone_secteur CHECK (                                   -- C10
        (type_zone = 'ville'   AND secteur IS NULL) OR
        (type_zone = 'secteur' AND secteur IS NOT NULL)),
    -- A4/ADR-032 : code postal FR à 5 chiffres (défaut annoncé A07 mais absent en v7).
    CONSTRAINT ck_zone_cp_fr    CHECK (code_iso_pays <> 'FR' OR code_postal ~ '^[0-9]{5}$'),
    -- E5-m3/ADR-040 : branche morte « ville IS NULL » retirée (ville est NOT NULL).
    CONSTRAINT ck_zone_insee_fr CHECK (code_iso_pays <> 'FR' OR code_insee IS NOT NULL),
    CONSTRAINT uk_zone_geo UNIQUE NULLS NOT DISTINCT (pays, ville, secteur)  -- C11
);

-- ------------------------------------------------------------
-- Demande & recherche
-- ------------------------------------------------------------
CREATE TABLE demande (
    id_demande            uuid PRIMARY KEY DEFAULT uuidv7(),
    id_gestionnaire       uuid REFERENCES gestionnaire(id_utilisateur),  -- dénorm. maintenue par trigger
    id_chasseur           uuid REFERENCES chasseur(id_utilisateur),      -- dénorm.
    date_depot            timestamptz NOT NULL,
    canal                 text NOT NULL CHECK (canal IN ('site_web','parrainage','telephone','autre')),
    description_initiale  text,
    -- ADR-048 : PAS de colonne statut. Le cycle (nouveau/affecté/qualifié/
    -- en_recherche/close/sans_suite) est DÉRIVÉ dans v_demande à partir des FAITS
    -- déjà présents : date_affectation, date_qualification, id_mandat_courant,
    -- cloture (acte du mandat courant) et le flag sans-suite.
    date_consentement     timestamptz,
    date_affectation      timestamptz,   -- fait : la demande a été affectée
    date_qualification    timestamptz,   -- fait : le chasseur a qualifié (version de critères post-affectation)
    -- id_mandat_courant : désignation de gestion du mandat en cours (fait, pas calcul).
    -- Porte l'unicité « un mandat courant par demande » sans statut ni index temporel.
    id_mandat_courant     uuid,          -- FK ajoutée après création de mandat (ALTER, dépendance circulaire)
    -- sans-suite : le SEUL écart stocké (rupture du parcours attendu).
    date_sans_suite       timestamptz,
    motif_sans_suite      text CHECK (motif_sans_suite IN ('budget_irrealiste','injoignable','hors_zone','abandon','autre')),
    nb_relances           smallint NOT NULL DEFAULT 0,
    statut_financement    text CHECK (statut_financement IN ('non_evalue','a_evaluer','accord_principe','refuse')),
    apport_disponible     d_montant,
    montant_pret_envisage d_montant,
    date_accord_principe  date,
    date_validite_accord  date,
    CONSTRAINT ck_demande_consent_web  CHECK (canal <> 'site_web' OR date_consentement IS NOT NULL),   -- C14/T14
    -- ADR-048 : sans-suite = date + motif ensemble (symétrique).
    CONSTRAINT ck_demande_sans_suite   CHECK ((date_sans_suite IS NULL) = (motif_sans_suite IS NULL)),
    CONSTRAINT ck_demande_validite_acc CHECK (date_validite_accord IS NULL OR date_accord_principe IS NULL OR date_validite_accord >= date_accord_principe)
);

CREATE TABLE demande_acquereur (
    id_demande uuid NOT NULL REFERENCES demande(id_demande),
    id_client  uuid NOT NULL REFERENCES client(id_utilisateur),
    qualite    text NOT NULL CHECK (qualite IN ('principal','co_acquereur')),
    PRIMARY KEY (id_demande, id_client)
);
-- C4 (au plus un principal) : index partiel
CREATE UNIQUE INDEX ux_acquereur_principal ON demande_acquereur (id_demande) WHERE qualite = 'principal';

CREATE TABLE affectation (
    id_affectation  uuid PRIMARY KEY DEFAULT uuidv7(),
    id_demande      uuid NOT NULL REFERENCES demande(id_demande),
    id_gestionnaire uuid NOT NULL REFERENCES gestionnaire(id_utilisateur),
    id_chasseur     uuid REFERENCES chasseur(id_utilisateur),
    date_debut      timestamptz NOT NULL,
    date_fin        timestamptz,
    -- B3/US04 : 'refus_chasseur' — le chasseur n'accepte pas, la demande est réaffectée.
    motif           text NOT NULL CHECK (motif IN ('initiale','surcharge','absence','desaccord_client','refus_chasseur','autre')),
    CONSTRAINT ck_affectation_dates CHECK (date_fin IS NULL OR date_fin >= date_debut),
    CONSTRAINT uk_affectation UNIQUE (id_demande, date_debut)   -- clé alternative (ADR-015)
);
-- C6 (au plus une ouverte) : index partiel
CREATE UNIQUE INDEX ux_affectation_ouverte ON affectation (id_demande) WHERE date_fin IS NULL;

CREATE TABLE demande_version (
    id_version         uuid PRIMARY KEY DEFAULT uuidv7(),
    id_demande         uuid NOT NULL REFERENCES demande(id_demande),
    id_modifie_par     uuid NOT NULL REFERENCES utilisateur(id_utilisateur),
    no_version         smallint NOT NULL CHECK (no_version > 0),
    date_creation      timestamptz NOT NULL,
    motif_evolution    text NOT NULL,
    type_bien          text NOT NULL CHECK (type_bien IN ('appartement','maison','terrain','immeuble','autre')),
    destination        text NOT NULL CHECK (destination IN ('principale','secondaire','locatif')),
    budget_max         d_montant NOT NULL CHECK (budget_max > 0),
    surface_min        smallint CHECK (surface_min > 0),
    nb_pieces_min      smallint CHECK (nb_pieces_min >= 0),
    nb_chambres_min    smallint CHECK (nb_chambres_min >= 0),
    nb_occupants       smallint CHECK (nb_occupants > 0),
    dpe_max            d_dpe,
    rendement_brut_min numeric(5,2),
    travaux_acceptes   boolean NOT NULL DEFAULT false,
    -- EXCL/ADR-052 : préférence par critère à 4 états (au lieu d'un booléen à 2).
    -- Le domaine d_preference encode l'intention réelle du client : 'exige' (doit
    -- l'avoir), 'souhaite' (apprécié, non bloquant), 'exclut' (refus : critère
    -- d'exclusion), 'indifferent' (défaut). Règle de l'art : modéliser l'intention
    -- métier plutôt que de surcharger un booléen d'une sémantique qu'il ne porte pas.
    pref_ascenseur     d_preference NOT NULL DEFAULT 'indifferent',
    pref_balcon        d_preference NOT NULL DEFAULT 'indifferent',
    pref_terrasse      d_preference NOT NULL DEFAULT 'indifferent',
    pref_jardin        d_preference NOT NULL DEFAULT 'indifferent',
    pref_parking       d_preference NOT NULL DEFAULT 'indifferent',
    pref_cave          d_preference NOT NULL DEFAULT 'indifferent',
    commentaire_criteres text,
    -- ADR-048 : PAS de est_courante. La version courante = celle au no_version MAX
    -- par demande (dérivé). uk_version_no garantit déjà l'unicité du numéro.
    CONSTRAINT uk_version_no UNIQUE (id_demande, no_version),         -- ADR-015
    CONSTRAINT uk_version_cible UNIQUE (id_demande, id_version),      -- cible FK composées (ADR-016)
    CONSTRAINT ck_version_rendement CHECK (destination = 'locatif' OR rendement_brut_min IS NULL)  -- T15
);

CREATE TABLE version_zone (
    id_version uuid NOT NULL REFERENCES demande_version(id_version),
    id_zone    uuid NOT NULL REFERENCES zone(id_zone),
    PRIMARY KEY (id_version, id_zone)
);

CREATE TABLE chasseur_zone (
    id_utilisateur    uuid NOT NULL REFERENCES chasseur(id_utilisateur),
    id_zone           uuid NOT NULL REFERENCES zone(id_zone),
    role_intervention text NOT NULL CHECK (role_intervention IN ('principal','secondaire')),
    PRIMARY KEY (id_utilisateur, id_zone)
);

-- ------------------------------------------------------------
-- Mandat (ADR-030 : date_debut seule, date_fin/duree calculées en vue,
--          renouvellement = nouveau mandat avec filiation)
-- ------------------------------------------------------------
CREATE TABLE mandat (
    id_mandat              uuid PRIMARY KEY DEFAULT uuidv7(),
    id_demande             uuid NOT NULL REFERENCES demande(id_demande),
    id_version_contractuelle uuid NOT NULL,
    id_chasseur            uuid NOT NULL REFERENCES chasseur(id_utilisateur),
    -- E5-m4/ADR-040 : id_demande_signataire supprimé (redondant, le CHECK le
    -- forçait = id_demande). La FK signataire utilise directement id_demande.
    id_signataire          uuid NOT NULL,
    id_mandat_precedent    uuid REFERENCES mandat(id_mandat),   -- filiation renouvellement (ADR-030)
    numero_registre        text NOT NULL UNIQUE,
    date_signature         date NOT NULL,
    mode_signature         text NOT NULL CHECK (mode_signature IN ('presentiel','en_ligne')),
    date_debut             date NOT NULL,
    -- PAS de duree_mois, PAS de date_fin : 6 mois constant, calcul en vue v_mandat
    -- A8/ADR-039 : gel de la conformité carte T à la signature (snapshot).
    -- A8/ADR-039/D1 : gel de l'habilitation (carte T ou attestation) à la signature.
    -- M1/ADR-045 : NULLABLE. NULL = « habilitation inconnue à la reprise » (migration),
    -- ce qui n'est PAS une non-conformité ; renseigné pour tout mandat créé par l'appli.
    numero_habilitation_signature  text,
    validite_habilitation_signature date,
    exclusif               boolean NOT NULL,
    -- ADR-048 : PAS de colonne statut. L'état (actif/échu/succès/renouvelé/résilié)
    -- est entièrement DÉRIVÉ dans v_mandat à partir des faits (date_debut, filiation,
    -- existence d'un acte, date_resiliation). Seul l'abandon anticipé est un fait stocké.
    taux_honoraires        d_taux,
    base_honoraires        text NOT NULL CHECK (base_honoraires IN ('HT','TTC')),
    taux_tva               d_taux NOT NULL,
    forfait_honoraires     d_montant,
    qualite_signataire     text NOT NULL CHECK (qualite_signataire IN ('nom_propre','procuration')),
    reference_procuration  text,
    date_resiliation       date,
    -- ADR-049 : type de fin anticipée. 'vente_externe' = le client a acheté hors
    -- dispositif. Mandat NON exclusif : pas d'acte, le mandat se clôt. Mandat
    -- EXCLUSIF : droit ouvert, acte créé sans compromis (v8.42, ADR-049 §2.3).
    type_resiliation       text CHECK (type_resiliation IN ('abandon_client','abandon_chasseur','vente_externe','non_conformite','autre')),
    motif_resiliation      text,   -- détail libre (ex. reprise migration à requalifier)
    CONSTRAINT fk_mandat_version   FOREIGN KEY (id_demande, id_version_contractuelle)
        REFERENCES demande_version (id_demande, id_version),
    -- C5 déclarative (ADR-019) : signataire = acquéreur de LA demande (E5-m4 : via id_demande).
    CONSTRAINT fk_mandat_signataire FOREIGN KEY (id_demande, id_signataire)
        REFERENCES demande_acquereur (id_demande, id_client),
    -- A6/ADR-032 : filiation linéaire des renouvellements.
    CONSTRAINT uk_mandat_precedent  UNIQUE (id_mandat_precedent),               -- successeur unique
    CONSTRAINT ck_mandat_pas_auto_precedent CHECK (id_mandat_precedent <> id_mandat),  -- S9 : pas d'auto-filiation
    CONSTRAINT uk_mandat_demande    UNIQUE (id_mandat, id_demande),             -- cible FK proposition (B1)
    CONSTRAINT uk_mandat_chasseur   UNIQUE (id_mandat, id_chasseur),            -- cible FK rémunération (B1/S1)
    CONSTRAINT fk_mandat_precedent_demande FOREIGN KEY (id_mandat_precedent, id_demande)
        REFERENCES mandat (id_mandat, id_demande),                             -- même demande que le précédent
    -- A12/ADR-037 : prise d'effet = signature (date_fin = signature + 6 mois, dérivée).
    CONSTRAINT ck_mandat_effet     CHECK (date_debut = date_signature),         -- T7 (était >=)
    CONSTRAINT ck_mandat_remun     CHECK (taux_honoraires IS NOT NULL OR forfait_honoraires IS NOT NULL),  -- T6
    CONSTRAINT ck_mandat_procur    CHECK (qualite_signataire <> 'procuration' OR reference_procuration IS NOT NULL),  -- T8
    -- ADR-048 : la résiliation (abandon anticipé) est le SEUL événement non dérivable.
    -- Si date_resiliation est posée, un motif est requis (et inversement).
    CONSTRAINT ck_mandat_resil     CHECK ((date_resiliation IS NULL) = (type_resiliation IS NULL))
);

-- ADR-048 : FK differee demande.id_mandat_courant -> mandat (dependance circulaire
-- demande<->mandat, resolue par ALTER). Un mandat courant appartient a sa demande.
ALTER TABLE demande
  ADD CONSTRAINT fk_demande_mandat_courant
  FOREIGN KEY (id_mandat_courant, id_demande) REFERENCES mandat (id_mandat, id_demande);

-- ADR-048 §3 : projection d'état du mandat. Active des la v8.4, justifiee par le
-- flux recurrent de rachats (PO) : une partie de l'etat (le « repris ») n'est pas
-- calculable faute de faits, et doit etre portee. origine distingue le fait
-- historique precieux (repris) du cache regenerable (calcule).
-- ADR-051 : SCISSION de l'ex-mandat_etat. Cette table OLTP ne porte QUE l'état
-- REPRIS à la migration (un succès/état connu dont les faits — ex. l'acte — n'ont
-- pas été repris). C'est une donnée TRANSACTIONNELLE non recalculable, lue par
-- v_mandat et qui fait foi. Plus de colonne 'origine' : cette table ne contient
-- que du repris. Le volet « cache calculé » (projection de performance) relève de
-- l'OLAP (vue matérialisée / table de faits alimentée par Airflow), PAS de l'OLTP.
CREATE TABLE mandat_reprise (
    id_mandat     uuid PRIMARY KEY REFERENCES mandat(id_mandat),
    statut_repris text NOT NULL CHECK (statut_repris IN ('actif','echu','renouvele','resilie','clos_succes')),
    source        text NOT NULL,                 -- la source de reprise (traçabilité)
    date_reprise  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE mandat_reprise IS
  'ADR-051 : etat REPRIS a la migration (donnee transactionnelle non recalculable, '
  'fait foi dans v_mandat). Le cache calcule de performance releve de l OLAP, pas ici.';


-- ------------------------------------------------------------
-- Parrainage (D2/ADR-034 — source : règlement du dispositif de parrainage,
-- Groupe Evoriel, version juin 2026). Récompense le PARRAIN (400 €/mandat)
-- après concrétisation. Cycle à états et conditions cumulatives.
-- ------------------------------------------------------------
CREATE TABLE parrainage (
    id_parrainage        uuid PRIMARY KEY DEFAULT uuidv7(),
    id_parrain           uuid NOT NULL REFERENCES utilisateur(id_utilisateur),  -- client ou prospect (art. 2)
    id_filleul           uuid REFERENCES utilisateur(id_utilisateur),           -- renseigné quand le filleul a un compte
    -- Identité déclarée du filleul avant qu'il ait un compte (art. 4 : déclaration préalable).
    filleul_nom          text NOT NULL,
    filleul_prenom       text NOT NULL,
    filleul_email        d_email,
    filleul_telephone    d_tel,
    type_contrat         text NOT NULL CHECK (type_contrat IN ('vente','gerance','syndic')),  -- art. 8
    date_declaration     date NOT NULL,                                          -- art. 4 : préalable à tout contact
    -- durée de validité du contact selon le type (art. 5) : vente/gérance 12 mois, syndic 24 mois.
    date_fin_validite    date NOT NULL,
    statut               text NOT NULL DEFAULT 'declare'
                         CHECK (statut IN ('declare','mandat_signe','concretise','retribue','expire','rejete')),
    -- concrétisation (art. 9) : mandat signé par le filleul -> rattachement.
    id_mandat_concretise uuid REFERENCES mandat(id_mandat),
    date_concretisation  date,
    -- conditions de rétribution (art. 10) : RIB sous 15 j, versement 400 € sous 3 mois.
    rib_recu             boolean NOT NULL DEFAULT false,
    date_reception_rib   date,
    montant_retribution  d_montant,                                             -- 400 € à la rétribution
    date_versement       date,
    CONSTRAINT ck_parrainage_pas_auto  CHECK (id_filleul IS NULL OR id_filleul <> id_parrain),  -- art. 12
    CONSTRAINT ck_parrainage_validite  CHECK (date_fin_validite >= date_declaration),
    CONSTRAINT ck_parrainage_concret   CHECK (statut NOT IN ('concretise','retribue') OR id_mandat_concretise IS NOT NULL),
    CONSTRAINT ck_parrainage_retribue  CHECK (statut <> 'retribue' OR (rib_recu AND date_versement IS NOT NULL AND montant_retribution IS NOT NULL)),
    -- art. 3 : un filleul ne peut être parrainé qu'une seule fois (une fois concrétisé).
    CONSTRAINT uk_parrainage_filleul_concretise UNIQUE (id_filleul, id_mandat_concretise)
);
-- ADR-048 : C7 (au plus un mandat courant par demande) est désormais porté
-- MÉCANIQUEMENT par la colonne unique demande.id_mandat_courant (une seule valeur
-- par demande). Plus d'index partiel sur un statut temporel (qui aurait exigé une
-- fonction immutable, impossible avec date_reference()).

-- ------------------------------------------------------------
-- Biens & annonces
-- ------------------------------------------------------------
CREATE TABLE bien (
    id_bien           uuid PRIMARY KEY DEFAULT uuidv7(),
    id_zone           uuid NOT NULL REFERENCES zone(id_zone),
    type_bien         text NOT NULL CHECK (type_bien IN ('appartement','maison','terrain','immeuble','autre')),
    surface           numeric(8,2) CHECK (surface > 0),
    nb_pieces         smallint CHECK (nb_pieces >= 0),
    nb_chambres       smallint CHECK (nb_chambres >= 0),
    etage             smallint,
    dpe               d_dpe,
    adresse_indicative text,
    code_postal       text,
    a_ascenseur       boolean,   -- NULL = non renseigné par la source (volontaire)
    a_balcon          boolean,
    a_terrasse        boolean,
    a_jardin          boolean,
    a_parking         boolean,
    a_cave            boolean
);

CREATE TABLE annonce (
    id_annonce        uuid PRIMARY KEY DEFAULT uuidv7(),
    id_bien           uuid NOT NULL REFERENCES bien(id_bien),
    source            text NOT NULL,
    reference_source  text NOT NULL,
    titre             text,
    description       text,
    prix              d_montant NOT NULL CHECK (prix > 0),
    url               text,
    date_publication  timestamptz,
    date_ingestion    timestamptz NOT NULL,
    date_derniere_vue timestamptz NOT NULL,
    statut            text NOT NULL CHECK (statut IN ('active','retiree','vendue')),
    CONSTRAINT uk_annonce_source UNIQUE (source, reference_source),
    CONSTRAINT uk_annonce_bien   UNIQUE (id_bien, id_annonce)   -- cible FK composée proposition
);

CREATE TABLE proposition (
    id_proposition        uuid PRIMARY KEY DEFAULT uuidv7(),
    id_demande            uuid NOT NULL REFERENCES demande(id_demande),   -- dénorm. (rend C8 déclarative)
    id_version            uuid NOT NULL,
    id_bien               uuid NOT NULL REFERENCES bien(id_bien),
    id_annonce_reference  uuid,
    id_mandat             uuid NOT NULL,                                  -- A1/R8b : mandat sous lequel la proposition est faite (FK composée ci-dessous)
    date_matching         timestamptz NOT NULL,
    date_soumission_client timestamptz,
    date_reponse_client   timestamptz,
    score_matching        numeric(5,2) CHECK (score_matching BETWEEN 0 AND 100),
    priorite_client       smallint CHECK (priorite_client > 0),           -- B6/US05 : le client priorise la sélection
    statut                text NOT NULL CHECK (statut IN ('a_qualifier','soumis','retenu_visite','refuse_client','ecarte_chasseur')),
    motif_rejet           text,
    CONSTRAINT fk_proposition_version FOREIGN KEY (id_demande, id_version)
        REFERENCES demande_version (id_demande, id_version),
    CONSTRAINT fk_proposition_annonce FOREIGN KEY (id_bien, id_annonce_reference)
        REFERENCES annonce (id_bien, id_annonce),                        -- T10
    -- B1/R8b/ADR-045 : le mandat de la proposition appartient à la MÊME demande.
    -- Ferme S2 (proposition sans mandat) et S3 (mandat d'une autre demande).
    CONSTRAINT fk_proposition_mandat FOREIGN KEY (id_mandat, id_demande)
        REFERENCES mandat (id_mandat, id_demande),
    CONSTRAINT ck_proposition_rejet CHECK (statut <> 'refuse_client' OR motif_rejet IS NOT NULL)  -- T13
);

-- E4/grille : unicité PARTIELLE — un même bien ne peut être proposé deux fois
-- pour une demande TANT QUE la proposition est vivante ; une fois écartée/refusée,
-- on peut reproposer (ex. après baisse de prix). Remplace l'ancien uk_proposition (C8).
CREATE UNIQUE INDEX uk_proposition_active ON proposition (id_demande, id_bien)
    WHERE statut IN ('a_qualifier','soumis','retenu_visite');

CREATE TABLE commentaire (
    id_commentaire uuid PRIMARY KEY DEFAULT uuidv7(),
    id_auteur      uuid NOT NULL REFERENCES utilisateur(id_utilisateur),
    id_demande     uuid REFERENCES demande(id_demande),
    id_proposition uuid REFERENCES proposition(id_proposition),
    -- v8.4/DOC3b : 3e cible = un BIEN. Permet au chasseur de garder une note (souvent
    -- privée) sur un bien qu'il a déjà tenté de proposer (mémoire métier). Vraie FK.
    id_bien        uuid REFERENCES bien(id_bien),
    type_contexte  text NOT NULL CHECK (type_contexte IN ('note_recherche','debrief_visite','analyse_annonce','note_bien')),
    est_prive      boolean NOT NULL DEFAULT false,
    contenu        text NOT NULL,
    date_creation  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_commentaire_cible CHECK (num_nonnulls(id_demande, id_proposition, id_bien) = 1)  -- C2 : exactement une cible
    -- C18 (RG-01) : trigger tg_commentaire_prive (traverse l'héritage, pas exprimable en CHECK)
);

-- ------------------------------------------------------------
-- Chaîne de valeur (ADR-024)
-- ------------------------------------------------------------
CREATE TABLE visite (
    id_visite       uuid PRIMARY KEY DEFAULT uuidv7(),
    id_proposition  uuid NOT NULL REFERENCES proposition(id_proposition),
    id_visiteur     uuid NOT NULL REFERENCES utilisateur(id_utilisateur),
    date_visite     date NOT NULL,
    realisee        boolean NOT NULL,
    motif_annulation text,
    CONSTRAINT ck_visite_annulation CHECK (realisee = true OR motif_annulation IS NOT NULL)  -- C17
);

CREATE TABLE offre_acquisition (
    id_offre          uuid PRIMARY KEY DEFAULT uuidv7(),
    id_proposition    uuid NOT NULL REFERENCES proposition(id_proposition),
    id_offre_precedente uuid REFERENCES offre_acquisition(id_offre),
    camp              text NOT NULL CHECK (camp IN ('acquereur','vendeur')),
    saisi_par         text NOT NULL CHECK (saisi_par IN ('chasseur','gestionnaire','client')),
    -- ADR-049 : origine_decouverte SUPPRIMÉ. Le droit à rémunération se dérive de
    -- l'existence de l'acte. Chaîne standard : proposition->offre->compromis->acte.
    -- Mandat exclusif + vente hors dispositif : acte SANS compromis, rattaché
    -- directement au mandat (v8.42, ADR-049 §2.3). Mandat non exclusif + vente
    -- hors dispositif : pas d'acte, résiliation 'vente_externe'.
    montant           d_montant NOT NULL CHECK (montant > 0),
    date_signature    date NOT NULL,
    date_transmission date,
    date_validite     date NOT NULL,
    statut            text NOT NULL CHECK (statut IN ('en_cours','acceptee','refusee','caduque','retiree')),
    date_reponse      date,
    CONSTRAINT ck_offre_transmission CHECK (date_transmission IS NULL OR date_transmission >= date_signature),
    CONSTRAINT ck_offre_reponse CHECK (statut = 'en_cours' OR date_reponse IS NOT NULL)  -- C14
);
-- C13 (au plus une acceptée par proposition) : index partiel
CREATE UNIQUE INDEX ux_offre_acceptee ON offre_acquisition (id_proposition) WHERE statut = 'acceptee';

CREATE TABLE notaire (
    id_notaire uuid PRIMARY KEY DEFAULT uuidv7(),
    nom        text NOT NULL,
    etude      text NOT NULL,
    email      d_email,
    telephone  d_tel,
    CONSTRAINT uk_notaire UNIQUE (nom, etude)
);

CREATE TABLE compromis (
    id_compromis    uuid PRIMARY KEY DEFAULT uuidv7(),
    id_offre        uuid NOT NULL UNIQUE REFERENCES offre_acquisition(id_offre),   -- A30 : au plus un
    id_notaire      uuid NOT NULL REFERENCES notaire(id_notaire),
    date_signature  date NOT NULL,
    fin_retractation date NOT NULL,
    depot_garantie  d_montant,
    sequestre       text,
    date_acte_prevue date,
    -- ADR-048 : PAS de colonne statut. « signé » = le compromis existe ; « réalisé »
    -- = il existe un acte rattaché (dérivé) ; « caduc » = le seul écart stocké (flag).
    date_caducite   date,
    motif_caducite  text,
    CONSTRAINT ck_compromis_retract CHECK (fin_retractation >= date_signature),
    -- caducité = date + motif ensemble (symétrique).
    CONSTRAINT ck_compromis_caducite CHECK ((date_caducite IS NULL) = (motif_caducite IS NULL))  -- C15
);

CREATE TABLE clause_suspensive (
    id_clause    uuid PRIMARY KEY DEFAULT uuidv7(),
    id_compromis uuid NOT NULL REFERENCES compromis(id_compromis),
    type_clause  text NOT NULL CHECK (type_clause IN ('financement','urbanisme','servitude','vente_prealable')),
    description  text,
    date_butoir  date NOT NULL,
    statut       text NOT NULL CHECK (statut IN ('en_attente','levee','non_levee'))
);

CREATE TABLE acte (
    id_acte         uuid PRIMARY KEY DEFAULT uuidv7(),
    id_compromis    uuid NOT NULL UNIQUE REFERENCES compromis(id_compromis),   -- A33 : au plus un
    date_signature  date NOT NULL,
    montant_vente   d_montant NOT NULL CHECK (montant_vente > 0),
    honoraires_fixe d_montant,
    honoraires_taux d_taux,
    -- B2/US07 : encaissement des honoraires par l'entreprise. C'est le fait
    -- générateur de la rémunération du chasseur (« quand ce paiement est enregistré »)
    -- et, pour une vente, de la concrétisation du parrainage (règlement art. 9).
    honoraires_encaisses   boolean NOT NULL DEFAULT false,
    date_encaissement      date,
    CONSTRAINT ck_acte_honoraires CHECK (honoraires_fixe IS NOT NULL OR honoraires_taux IS NOT NULL),  -- C16
    CONSTRAINT ck_acte_encaissement CHECK (honoraires_encaisses = false OR date_encaissement IS NOT NULL)
);

-- ------------------------------------------------------------
-- Rémunération chasseur (ADR-029 : gel de la part au moment de la vente)
-- ------------------------------------------------------------
-- ------------------------------------------------------------
-- Référentiel de rémunération versionné (ADR-031, B1)
-- ------------------------------------------------------------
-- Barème de commission : par défaut (id_chasseur NULL) ou propre à un chasseur.
-- Variable dans le temps (dates de vigueur). Le barème propre prévaut au calcul.
CREATE TABLE bareme (
    id_bareme          uuid PRIMARY KEY DEFAULT uuidv7(),
    id_chasseur        uuid REFERENCES chasseur(id_utilisateur),   -- NULL = barème par défaut
    date_debut_vigueur date NOT NULL,
    date_fin_vigueur   date,
    -- clé de périmètre : un UUID nul représente « le barème par défaut », pour
    -- que l'exclusion ci-dessous traite tous les barèmes par défaut ensemble
    -- (COALESCE car GiST ne considère pas deux NULL comme égaux).
    perimetre          uuid GENERATED ALWAYS AS (COALESCE(id_chasseur, '00000000-0000-0000-0000-000000000000')) STORED,
    CONSTRAINT ck_bareme_vigueur CHECK (date_fin_vigueur IS NULL OR date_fin_vigueur >= date_debut_vigueur),
    -- S6/ADR-045 : pas deux barèmes du même périmètre (défaut, ou même chasseur)
    -- dont les périodes de vigueur se chevauchent.
    CONSTRAINT ex_bareme_vigueur EXCLUDE USING gist (
        perimetre WITH =,
        daterange(date_debut_vigueur, date_fin_vigueur, '[]') WITH &&
    )
);

-- Tranches d'un barème : taux de base PLAT par tranche de prix (pas de progressivité).
CREATE TABLE tranche_bareme (
    id_tranche   uuid PRIMARY KEY DEFAULT uuidv7(),
    id_bareme    uuid NOT NULL REFERENCES bareme(id_bareme),
    -- B3/ADR-045 : intervalle SEMI-OUVERT [montant_min, montant_max). Une borne
    -- haute NULL = tranche ouverte (jusqu'à +∞). Gère les montants à centimes
    -- (199 999,50 € tombe bien dans [100000, 200000)), plus de trou entre tranches.
    montant_min  d_montant NOT NULL,
    montant_max  d_montant,                                        -- NULL = +∞
    taux_base    d_taux NOT NULL,
    CONSTRAINT ck_tranche_bornes CHECK (montant_max IS NULL OR montant_max > montant_min),
    -- S5 : deux tranches du MÊME barème ne peuvent pas se chevaucher.
    CONSTRAINT ex_tranche_chevauchement EXCLUDE USING gist (
        id_bareme WITH =,
        numrange(montant_min::numeric, montant_max::numeric, '[)') WITH &&
    )
);

-- Paramètres d'honoraires entreprise, versionnés (OPTIONNEL — fournit/audite les
-- défauts en vigueur ; l'acte stocke déjà les honoraires appliqués, pas de doublon).
CREATE TABLE parametre_honoraires (
    id_parametre       uuid PRIMARY KEY DEFAULT uuidv7(),
    montant_fixe       d_montant NOT NULL,
    pourcentage        d_taux NOT NULL,
    date_debut_vigueur date NOT NULL,
    date_fin_vigueur   date,
    CONSTRAINT ck_param_honoraires_vigueur CHECK (date_fin_vigueur IS NULL OR date_fin_vigueur >= date_debut_vigueur)
);

CREATE TABLE remuneration_chasseur (
    id_remuneration  uuid PRIMARY KEY DEFAULT uuidv7(),
    id_acte          uuid NOT NULL REFERENCES acte(id_acte),
    id_chasseur      uuid NOT NULL REFERENCES chasseur(id_utilisateur),
    id_mandat        uuid NOT NULL,                              -- A1/S1 : mandat à l'origine (FK composée ci-dessous)
    -- ADR-049 : GEL COMPLET figé au jour de l'acte. Une rémunération existe pour
    -- CHAQUE acte. Mandat non exclusif : un acte n'existe que si le chasseur a mené
    -- la vente. Mandat exclusif : un acte existe aussi pour une vente hors dispositif
    -- (v8.42 : acte sans compromis, ADR-049 §2.3). Dans les deux cas :
    -- rémunération = droit ouvert. Pas de droit_ouvert à stocker.
    -- R1 : colonnes de gel NOT NULL (insert complet, pas de calcul par étapes).
    honoraires            d_montant NOT NULL,                    -- assiette = fixe + % * prix_acté
    -- R4 : les 5 COMPOSANTES du score conservées (gel complet, reconstituable juridiquement),
    -- en plus du score global. Figées : si les règles de calcul évoluent, l'ancien reste explicable.
    -- ADR-052 (correction) : les 5 composantes CONFORMES À LA SPEC (ADR-rémunération,
    -- pondération : délai 25 · exclusivité 10 · ventes 25 · mandats 15 · visites 25).
    -- Corrige la v8.4 qui portait des noms inventés (satisfaction) ou en doublon
    -- (anciennete, déjà couverte par majoration_anciennete ci-dessous).
    -- Chaque composante est la NOTE 0-100 du critère ; la pondération vit dans le
    -- moteur de calcul (OLAP/applicatif), pas en base.
    score_delai           numeric(5,2) NOT NULL CHECK (score_delai BETWEEN 0 AND 100),        -- délai mandat->acte (pond. 25)
    score_exclusivite     numeric(5,2) NOT NULL CHECK (score_exclusivite BETWEEN 0 AND 100),  -- exclusivité (pond. 10)
    score_ventes          numeric(5,2) NOT NULL CHECK (score_ventes BETWEEN 0 AND 100),       -- ventes réussies / 12 mois (pond. 25)
    score_mandats         numeric(5,2) NOT NULL CHECK (score_mandats BETWEEN 0 AND 100),      -- mandats signés / 12 mois (pond. 15)
    score_visites         numeric(5,2) NOT NULL CHECK (score_visites BETWEEN 0 AND 100),      -- visites avant achat (pond. 25)
    score_performance     numeric(5,2) NOT NULL CHECK (score_performance BETWEEN 0 AND 100),  -- global (moyenne pondérée)
    taux_base             d_taux NOT NULL,                       -- taux de tranche appliqué
    majoration_anciennete d_taux NOT NULL,                       -- majoration relative (+%)
    modulation_performance numeric(6,4) NOT NULL,                -- ± autour du pivot (relatif)
    -- R2 : taux final borné 20–60 % GARANTI PAR LE SGBD (règle métier US00/07,
    -- ajustable par migration de contrainte si le besoin métier évolue).
    taux_final            d_taux NOT NULL CHECK (taux_final BETWEEN 20 AND 60),
    montant               d_montant NOT NULL,                    -- rémunération = taux_final * honoraires
    id_bareme_applique    uuid NOT NULL REFERENCES bareme(id_bareme),  -- barème figé (traçabilité)
    date_calcul      timestamptz NOT NULL DEFAULT now(),
    -- R1 : annulation exceptionnelle = flag daté + motif (pas de statut, cohérent ADR-048).
    date_annulation  date,
    motif_annulation text,
    -- B1/S1/ADR-045 : le chasseur rémunéré EST celui du mandat (FK composée).
    CONSTRAINT fk_remuneration_mandat FOREIGN KEY (id_mandat, id_chasseur)
        REFERENCES mandat (id_mandat, id_chasseur),
    CONSTRAINT uk_remuneration_acte UNIQUE (id_acte),            -- A2 : un seul chasseur payé par acte
    CONSTRAINT ck_remun_annulation CHECK ((date_annulation IS NULL) = (motif_annulation IS NULL))
);

-- ------------------------------------------------------------
-- Pilotage / KPI (OLTP : source de vérité, ADR-025)
-- ------------------------------------------------------------
-- Cycle de facturation / paiement du chasseur (ADR-031, B2 / US07).
-- Paiement porté en colonnes (1:1, pas de paiement partiel dans les US).
CREATE TABLE facture_chasseur (
    id_facture         uuid PRIMARY KEY DEFAULT uuidv7(),
    -- v8.4 : UNIQUE -> une seule facture par rémunération (pas de double facturation).
    id_remuneration    uuid NOT NULL UNIQUE REFERENCES remuneration_chasseur(id_remuneration),
    numero             text NOT NULL UNIQUE,
    montant            d_montant NOT NULL,
    date_emission      date NOT NULL,
    statut             text NOT NULL DEFAULT 'soumise'
                        CHECK (statut IN ('soumise','verifiee_conforme','rejetee')),
    -- v8.4 : cycle de vérification tracé (qui, quand, pourquoi un rejet).
    date_verification  date,
    id_verificateur    uuid REFERENCES gestionnaire(id_utilisateur),
    motif_rejet        text,
    statut_paiement    text CHECK (statut_paiement IN ('programme','paye')),
    date_programmation date,
    date_paiement      date,
    -- cohérence du cycle : paiement seulement si facture conforme
    CONSTRAINT ck_facture_paiement CHECK (statut_paiement IS NULL OR statut = 'verifiee_conforme'),
    CONSTRAINT ck_facture_paye CHECK (statut_paiement <> 'paye' OR date_paiement IS NOT NULL),
    -- v8.4 : une facture rejetée doit porter un motif ; une vérifiée/rejetée une date.
    CONSTRAINT ck_facture_rejet CHECK (statut <> 'rejetee' OR motif_rejet IS NOT NULL),
    CONSTRAINT ck_facture_verif CHECK (statut = 'soumise' OR date_verification IS NOT NULL)
);

-- ------------------------------------------------------------
-- Note d'avis & documents média (US06, B4)
-- Octets stockés hors OLTP (object storage MinIO/S3) ; la base ne garde
-- que la métadonnée + l'URI. Voir ADR-042 (stockage média).
-- ------------------------------------------------------------
-- Note d'avis : rédigée par le chasseur APRÈS investigation, DANS le cadre
-- d'un mandat signé (l'engagement contractuel part du mandat, pas de la demande).
-- v8.4/DOC3a : la note d'avis est le livrable du chasseur sur un bien QU'IL A
-- PROPOSÉ. Rattachée à la PROPOSITION : on en déduit le bien ET le mandat, et on
-- garantit que le bien a bien été proposé sous ce mandat (plus de couple libre mandat+bien).
CREATE TABLE note_avis (
    id_note                 uuid PRIMARY KEY DEFAULT uuidv7(),
    id_proposition          uuid NOT NULL UNIQUE REFERENCES proposition(id_proposition),  -- une note par proposition
    contenu                 text,                                          -- conclusions rédigées
    montant_offre_suggere   d_montant CHECK (montant_offre_suggere > 0),   -- pré-remplit l'offre (US06)
    date_redaction          timestamptz NOT NULL DEFAULT now(),
    date_mise_a_disposition timestamptz                                    -- mise à dispo du client
);

-- Document média (métadonnée seule ; les octets vivent dans l'object storage).
CREATE TABLE document (
    id_document   uuid PRIMARY KEY DEFAULT uuidv7(),
    type_document text NOT NULL CHECK (type_document IN ('audio','video','pdf','image','autre')),
    -- v8.4/ADR-042 : fichier stocké sur object storage (MinIO/S3) ; la base ne garde
    -- que la référence + les métadonnées nécessaires sans ouvrir le stockage.
    cle_objet     text NOT NULL,              -- clé technique dans le bucket (S3/MinIO)
    uri           text NOT NULL,              -- URI d'accès (présignée ou publique)
    mime_type     text NOT NULL,              -- type MIME exact (audio/mpeg, video/mp4, application/pdf…)
    taille_octets bigint NOT NULL CHECK (taille_octets >= 0),
    hash_sha256   char(64) NOT NULL CHECK (hash_sha256 ~ '^[0-9a-f]{64}$'),  -- intégrité + dédoublonnage
    libelle       text,
    date_ajout    timestamptz NOT NULL DEFAULT now()
);

-- Rattachement polymorphe : un document -> N cibles, une cible -> N documents.
-- Cibles limitées à ce que les US justifient (note d'avis audio/vidéo ; facture).
-- v8.4/DOC1 : le rattachement polymorphe (sans FK stricte) est remplacé par DEUX
-- tables de liaison à VRAIES FK. Intégrité garantie par le SGBD. Il n'y a que deux
-- cibles légitimes (note d'avis, facture), donc deux tables suffisent.
CREATE TABLE note_avis_document (
    id_note     uuid NOT NULL REFERENCES note_avis(id_note),
    id_document uuid NOT NULL REFERENCES document(id_document),
    PRIMARY KEY (id_note, id_document)
);

CREATE TABLE facture_document (
    id_facture  uuid NOT NULL REFERENCES facture_chasseur(id_facture),
    id_document uuid NOT NULL REFERENCES document(id_document),
    PRIMARY KEY (id_facture, id_document)
);

CREATE TABLE indicateur (
    code_indicateur text PRIMARY KEY,
    libelle         text NOT NULL,
    unite           text NOT NULL,
    perimetre_role  text NOT NULL CHECK (perimetre_role IN ('chasseur','gestionnaire','client')),
    sens_optimal    text NOT NULL CHECK (sens_optimal IN ('croissant','decroissant')),
    mode_calcul     text NOT NULL
);

CREATE TABLE periode (
    id_periode   uuid PRIMARY KEY DEFAULT uuidv7(),
    type_periode text NOT NULL CHECK (type_periode IN ('mois','trimestre','annee')),
    date_debut   date NOT NULL,
    date_fin     date NOT NULL,
    CONSTRAINT ck_periode_dates CHECK (date_fin >= date_debut),
    -- E5-m5/ADR-040 : empêche deux périodes de même type et même début (fiabilise l'aval indicateurs).
    CONSTRAINT uk_periode UNIQUE (type_periode, date_debut)
);

CREATE TABLE observation (
    id_utilisateur  uuid NOT NULL REFERENCES utilisateur(id_utilisateur),
    code_indicateur text NOT NULL REFERENCES indicateur(code_indicateur),
    id_periode      uuid NOT NULL REFERENCES periode(id_periode),
    valeur          numeric(14,4) NOT NULL,
    date_calcul     timestamptz NOT NULL,
    PRIMARY KEY (id_utilisateur, code_indicateur, id_periode)
    -- C9 : trigger tg_observation_periode (période close à la date de calcul)
);

CREATE TABLE objectif (
    id_utilisateur  uuid NOT NULL REFERENCES utilisateur(id_utilisateur),
    code_indicateur text NOT NULL REFERENCES indicateur(code_indicateur),
    id_periode      uuid NOT NULL REFERENCES periode(id_periode),
    valeur_cible    numeric(14,4) NOT NULL,
    date_fixation   timestamptz NOT NULL,
    PRIMARY KEY (id_utilisateur, code_indicateur, id_periode)
);

COMMIT;
