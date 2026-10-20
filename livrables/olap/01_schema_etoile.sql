-- ============================================================
-- 01_schema_etoile.sql — Entrepôt décisionnel (schéma olap), modèle en étoile
-- Socle source : OLTP v8.42 (38 tables, 9 vues). Rejouable (IF NOT EXISTS).
-- Références : ADR-025 (scission OLTP/OLAP), ADR-036 (frontière des indicateurs),
--              ADR-049 / ADR-052 (rémunération gelée), ADR-051 (état repris),
--              ADR-053 (acte à double origine), journal des décisions D10, D12, D13.
-- Relecture du 13/10 face aux promesses de l'étude (§2.3) : KPI-1 prolongé jusqu'à l'acte,
-- KPI-2 complété par la trésorerie (encaissement, compromis en cours), motifs de résiliation,
-- taux d'acceptation des propositions.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS olap;

-- ------------------------------------------------------------
-- Règle de comptage des visites (D10) : une visite = un rendez-vous (bien, date) où au moins
-- un acquéreur de la demande est présent et qui a eu lieu. Une visite en couple compte UNE fois ;
-- la visite de reconnaissance du chasseur seul ne compte pas. Même règle que l'ADR-049 §5.
-- p_chaine = true : sur toute la chaîne de renouvellement du mandat (D13), sinon sur ce mandat seul.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION olap.f_nb_visites(p_mandat uuid, p_date_limite date DEFAULT NULL, p_chaine boolean DEFAULT false)
RETURNS integer AS $$
    SELECT count(DISTINCT (v.id_proposition, v.date_visite))::integer
    FROM public.visite v
    JOIN public.proposition p        ON p.id_proposition = v.id_proposition
    JOIN public.demande_acquereur da ON da.id_demande = p.id_demande AND da.id_client = v.id_visiteur
    WHERE (p.id_mandat = p_mandat OR (p_chaine AND p.id_mandat IN (SELECT public.f_chaine_mandats(p_mandat))))
      AND v.realisee = true
      AND (p_date_limite IS NULL OR v.date_visite <= p_date_limite);
$$ LANGUAGE sql STABLE;

-- ============================================================
-- DIMENSIONS
-- ============================================================

-- 1. Temps (calendrier)
CREATE TABLE IF NOT EXISTS olap.dim_temps (
    id_temps        integer PRIMARY KEY,                 -- YYYYMMDD
    date_jour       date NOT NULL UNIQUE,
    annee           integer NOT NULL,
    trimestre       integer NOT NULL CHECK (trimestre BETWEEN 1 AND 4),
    mois            integer NOT NULL CHECK (mois BETWEEN 1 AND 12),
    nom_mois        varchar(20) NOT NULL,
    jour            integer NOT NULL CHECK (jour BETWEEN 1 AND 31),
    jour_semaine    integer NOT NULL CHECK (jour_semaine BETWEEN 1 AND 7),  -- 1 = lundi
    nom_jour        varchar(20) NOT NULL,
    semaine_annee   integer NOT NULL CHECK (semaine_annee BETWEEN 1 AND 53),
    est_weekend     boolean NOT NULL,
    est_ouvre       boolean NOT NULL
);

-- 2. Chasseur (habilitation Hoguet : carte T ou attestation, ADR-046)
CREATE TABLE IF NOT EXISTS olap.dim_chasseur (
    id_chasseur                 uuid PRIMARY KEY,
    nom                         varchar(100) NOT NULL,
    prenom                      varchar(100) NOT NULL,
    nom_complet                 varchar(200) NOT NULL,
    statut_juridique            varchar(50),             -- salarie, agent_commercial, independant
    type_habilitation           varchar(20),             -- carte_t, attestation
    numero_habilitation         varchar(50),
    organisme_delivrance        varchar(100),
    date_validite_habilitation  date,
    date_entree_reseau          date,
    date_sortie_reseau          date,
    capacite_max_mandats        integer,
    est_actif                   boolean NOT NULL DEFAULT true
);

-- 3. Gestionnaire (flag est_technique : compte SYS-MIGRATION neutralisé, ADR-036)
CREATE TABLE IF NOT EXISTS olap.dim_gestionnaire (
    id_gestionnaire       uuid PRIMARY KEY,
    matricule             varchar(50),
    nom                   varchar(100) NOT NULL,
    prenom                varchar(100) NOT NULL,
    nom_complet           varchar(200) NOT NULL,
    equipe                varchar(100),
    capacite_max_leads    integer,
    est_technique         boolean NOT NULL DEFAULT false
);

-- 4. Zone (géographie ; pays et devise portés dès la phase 2, ADR-ouverture-internationale)
CREATE TABLE IF NOT EXISTS olap.dim_zone (
    id_zone               uuid PRIMARY KEY,
    type_zone             varchar(20) NOT NULL,
    nom_zone              varchar(150) NOT NULL,
    ville                 varchar(100) NOT NULL,
    secteur               varchar(100),
    code_postal           varchar(10),
    code_insee            varchar(10),
    departement           varchar(10),
    pays                  varchar(50) NOT NULL,
    code_iso_pays         char(2) NOT NULL,
    devise                char(3)
);

-- 5. Bien (typologie)
CREATE TABLE IF NOT EXISTS olap.dim_bien (
    id_bien               uuid PRIMARY KEY,
    type_bien             varchar(50) NOT NULL,
    tranche_surface       varchar(50) NOT NULL,
    surface               numeric(8,2),
    nb_pieces             integer,
    nb_chambres           integer,
    dpe                   char(1),
    a_ascenseur           boolean,
    a_balcon_ou_terrasse  boolean,
    a_parking             boolean
);

-- 6. Client (profil par tranches, aucune donnée directement identifiante : RB4, ADR-043)
CREATE TABLE IF NOT EXISTS olap.dim_client (
    id_client             uuid PRIMARY KEY,
    tranche_budget        varchar(50) NOT NULL,
    destination           varchar(50),
    primo_accedant        boolean NOT NULL DEFAULT false,
    statut_financement    varchar(50),
    tranche_age           varchar(20),
    est_anonymise_rgpd    boolean NOT NULL DEFAULT false
);

-- ============================================================
-- FAITS
-- ============================================================

-- Fait 1 : ventes (un acte = une vente). Deux origines (ADR-053) : chaîne de vente
-- (compromis -> bien connu) ou achat hors dispositif (bien et zone inconnus -> NULL).
-- Le chasseur et le mandat sont ceux de la chaîne de renouvellement EN VIGUEUR à l'acte (D13) ;
-- le délai mandat -> acte part du mandat INITIAL (S1, D13).
CREATE TABLE IF NOT EXISTS olap.fait_vente (
    id_fait                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    id_acte                     uuid NOT NULL UNIQUE,
    id_date_acte                integer NOT NULL REFERENCES olap.dim_temps(id_temps),
    id_chasseur                 uuid NOT NULL REFERENCES olap.dim_chasseur(id_chasseur),
    id_gestionnaire             uuid REFERENCES olap.dim_gestionnaire(id_gestionnaire),
    id_zone                     uuid REFERENCES olap.dim_zone(id_zone),              -- zone DU BIEN vendu (NULL hors dispositif)
    id_zone_recherche           uuid REFERENCES olap.dim_zone(id_zone),              -- zone RECHERCHÉE par le mandat (KPI-5, taux de succès)
    id_client                   uuid NOT NULL REFERENCES olap.dim_client(id_client),
    id_bien                     uuid REFERENCES olap.dim_bien(id_bien),
    id_mandat_en_vigueur        uuid NOT NULL,
    id_mandat_initial           uuid NOT NULL,

    est_hors_dispositif         boolean NOT NULL DEFAULT false,
    source_information          varchar(20),             -- client, notaire, autre (hors dispositif)
    est_mandat_exclusif         boolean NOT NULL DEFAULT false,

    montant_acte_net_vendeur    numeric(12,2) NOT NULL,
    -- Honoraires : l'OLTP calcule l'assiette comme l'énoncé la définit (fixe + % du prix), dans la base du
    -- mandat (HT ou TTC). L'entrepôt garde ce brut ET le convertit en HT (revue PR #15, décision D19).
    honoraires_agence_brut      numeric(10,2) NOT NULL,
    base_honoraires_mandat      varchar(3) NOT NULL,                                 -- HT / TTC
    taux_tva_mandat             numeric(5,2) NOT NULL,
    honoraires_agence_ht        numeric(10,2) NOT NULL,
    remuneration_chasseur_ht    numeric(10,2) NOT NULL,                              -- montant gelé par l'OLTP, réputé HT (D19)
    marge_brute_ht              numeric(10,2) NOT NULL,
    taux_marge_pct              numeric(5,2) NOT NULL,

    delai_depot_a_acte_jours    integer,
    delai_mandat_a_acte_jours   integer,                 -- depuis le mandat initial (D13)
    nb_visites_effectuees       integer NOT NULL DEFAULT 0,   -- rendez-vous d'acquéreurs (D10), chaîne du mandat
    nb_propositions_recues      integer NOT NULL DEFAULT 0,

    -- KPI-2 trésorerie : l'argent est-il arrivé ? (S28/D20 : pas de rémunération avant encaissement)
    est_honoraires_encaisses    boolean NOT NULL DEFAULT false,
    id_date_encaissement        integer REFERENCES olap.dim_temps(id_temps),
    delai_acte_a_encaissement_jours integer                  -- NULL tant que non encaissé
);

-- Fait 2 : rémunération gelée (copie des composantes figées à l'acte, ADR-049 / ADR-052).
-- Une rémunération = un droit ouvert ; l'annulation exceptionnelle est un flag daté.
CREATE TABLE IF NOT EXISTS olap.fait_remuneration_chasseur (
    id_fait                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    id_remuneration             uuid NOT NULL UNIQUE,
    id_date_calcul              integer NOT NULL REFERENCES olap.dim_temps(id_temps),
    id_date_acte                integer NOT NULL REFERENCES olap.dim_temps(id_temps),
    id_chasseur                 uuid NOT NULL REFERENCES olap.dim_chasseur(id_chasseur),
    id_zone                     uuid REFERENCES olap.dim_zone(id_zone),
    id_acte                     uuid NOT NULL,
    est_hors_dispositif         boolean NOT NULL DEFAULT false,

    honoraires_assiette         numeric(10,2) NOT NULL,
    score_s1_delai              numeric(5,2) NOT NULL,
    score_s2_exclusivite        numeric(5,2) NOT NULL,
    score_s3_ventes             numeric(5,2) NOT NULL,
    score_s4_mandats            numeric(5,2) NOT NULL,
    score_s5_visites            numeric(5,2) NOT NULL,
    score_performance_global    numeric(5,2) NOT NULL,

    taux_base_pct               numeric(5,2) NOT NULL,
    majoration_anciennete_pct   numeric(5,2) NOT NULL,
    modulation_performance_pct  numeric(6,4) NOT NULL,
    taux_final_pct              numeric(5,2) NOT NULL,
    montant_remuneration_ht     numeric(10,2) NOT NULL,
    est_annulee                 boolean NOT NULL DEFAULT false
);

-- Fait 3 : cycle de vie des mandats (état dérivé de v_mandat ; « repris fait foi », ADR-051)
CREATE TABLE IF NOT EXISTS olap.fait_mandat_cycle (
    id_fait                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    id_mandat                   uuid NOT NULL UNIQUE,
    id_date_signature           integer NOT NULL REFERENCES olap.dim_temps(id_temps),
    id_date_fin_theorique       integer NOT NULL REFERENCES olap.dim_temps(id_temps),
    id_chasseur                 uuid NOT NULL REFERENCES olap.dim_chasseur(id_chasseur),
    id_zone                     uuid REFERENCES olap.dim_zone(id_zone),
    id_client                   uuid NOT NULL REFERENCES olap.dim_client(id_client),
    id_mandat_precedent         uuid,

    exclusif                    boolean NOT NULL,
    statut_projete              varchar(30) NOT NULL,    -- actif, renouvele, clos_succes, resilie, echu
    est_succes                  boolean NOT NULL DEFAULT false,
    est_renouvele               boolean NOT NULL DEFAULT false,
    est_resilie                 boolean NOT NULL DEFAULT false,
    est_echu                    boolean NOT NULL DEFAULT false,

    type_resiliation            varchar(30),             -- motif d'une résiliation datée ; 'non_renseigne' si état repris sans motif (ADR-051)

    duree_effective_jours       integer NOT NULL,
    nb_propositions             integer NOT NULL DEFAULT 0,
    nb_propositions_soumises    integer NOT NULL DEFAULT 0,   -- montrées au client (soumis, retenu_visite, refuse_client)
    nb_propositions_retenues    integer NOT NULL DEFAULT 0,   -- retenues par le client : statut retenu_visite, visite réalisée ou offre
    nb_visites                  integer NOT NULL DEFAULT 0,   -- rendez-vous d'acquéreurs (D10), ce mandat seul
    jours_sans_visite           integer                       -- alerte « mandat dormant » (D16, étude §6.2)
);

-- Fait 4 : activité des demandes (entonnoir, KPI-1 ; état dérivé de v_demande)
CREATE TABLE IF NOT EXISTS olap.fait_activite_demande (
    id_fait                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    id_demande                  uuid NOT NULL UNIQUE,
    id_date_depot               integer NOT NULL REFERENCES olap.dim_temps(id_temps),
    id_date_affectation         integer REFERENCES olap.dim_temps(id_temps),
    id_gestionnaire             uuid NOT NULL REFERENCES olap.dim_gestionnaire(id_gestionnaire),
    id_chasseur                 uuid REFERENCES olap.dim_chasseur(id_chasseur),
    id_client                   uuid NOT NULL REFERENCES olap.dim_client(id_client),

    canal                       varchar(50) NOT NULL,
    statut_demande              varchar(30) NOT NULL,
    delai_affectation_heures    numeric(8,2),
    delai_qualification_jours   numeric(8,2),
    a_abouti_mandat             boolean NOT NULL DEFAULT false,
    -- KPI-1 complet (étude §2.3) : demande -> mandat -> visite -> offre -> acte
    a_eu_visite                 boolean NOT NULL DEFAULT false,   -- au moins un rendez-vous réalisé avec un acquéreur de la demande (D10)
    a_eu_offre                  boolean NOT NULL DEFAULT false,
    a_abouti_acte               boolean NOT NULL DEFAULT false,   -- y compris achat hors dispositif (ADR-053)
    nb_versions_criteres        integer NOT NULL DEFAULT 1
);

-- Fait 5 : compromis (KPI-2, trésorerie prévisionnelle). Un compromis signé et non caduc annonce un acte,
-- donc des honoraires à venir, 10 à 14 semaines plus tard (étude §2.3). Les honoraires sont ESTIMÉS
-- d'après le mandat qui cadre la proposition (forfait + taux x montant de l'offre, même formule que
-- v_honoraires), convertis en HT selon la base du mandat (D19). Le montant réel est celui de l'acte.
CREATE TABLE IF NOT EXISTS olap.fait_compromis (
    id_fait                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    id_compromis                uuid NOT NULL UNIQUE,
    id_date_signature           integer NOT NULL REFERENCES olap.dim_temps(id_temps),
    id_date_acte_prevue         integer REFERENCES olap.dim_temps(id_temps),
    id_chasseur                 uuid NOT NULL REFERENCES olap.dim_chasseur(id_chasseur),
    id_zone                     uuid REFERENCES olap.dim_zone(id_zone),
    id_mandat                   uuid NOT NULL,
    statut_projete              varchar(10) NOT NULL,    -- signe, realise, caduc (lu dans v_compromis)
    montant_offre               numeric(12,2) NOT NULL,
    honoraires_estimes_ht       numeric(10,2) NOT NULL
);

-- ============================================================
-- INDEX
-- ============================================================
CREATE INDEX IF NOT EXISTS ix_olap_fait_vente_temps        ON olap.fait_vente(id_date_acte);
CREATE INDEX IF NOT EXISTS ix_olap_fait_vente_chasseur     ON olap.fait_vente(id_chasseur);
CREATE INDEX IF NOT EXISTS ix_olap_fait_vente_zone         ON olap.fait_vente(id_zone);
CREATE INDEX IF NOT EXISTS ix_olap_fait_vente_client       ON olap.fait_vente(id_client);
CREATE INDEX IF NOT EXISTS ix_olap_fait_remun_temps        ON olap.fait_remuneration_chasseur(id_date_calcul);
CREATE INDEX IF NOT EXISTS ix_olap_fait_remun_chasseur     ON olap.fait_remuneration_chasseur(id_chasseur);
CREATE INDEX IF NOT EXISTS ix_olap_fait_mandat_signature   ON olap.fait_mandat_cycle(id_date_signature);
CREATE INDEX IF NOT EXISTS ix_olap_fait_mandat_chasseur    ON olap.fait_mandat_cycle(id_chasseur);
CREATE INDEX IF NOT EXISTS ix_olap_fait_mandat_statut      ON olap.fait_mandat_cycle(statut_projete);
CREATE INDEX IF NOT EXISTS ix_olap_fait_demande_depot      ON olap.fait_activite_demande(id_date_depot);
CREATE INDEX IF NOT EXISTS ix_olap_fait_demande_gest       ON olap.fait_activite_demande(id_gestionnaire);
CREATE INDEX IF NOT EXISTS ix_olap_fait_demande_statut     ON olap.fait_activite_demande(statut_demande);
CREATE INDEX IF NOT EXISTS ix_olap_fait_compromis_prevue   ON olap.fait_compromis(id_date_acte_prevue);
