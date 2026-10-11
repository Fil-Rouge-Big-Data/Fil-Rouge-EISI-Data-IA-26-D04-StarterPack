# Référentiel des colonnes — v841 (généré)

> ⚙️ **Fichier GÉNÉRÉ depuis `livrables/db/01_ddl.sql` : ne pas le modifier à la main.**
> Régénération : `python livrables/db/generer_dictionnaire_colonnes.py`. Contrôle : `python livrables/db/verifier_dictionnaire.py`.
>
> **38 tables, 337 colonnes**, une ligne par colonne : type, nullité, clés, défauts,
> règles et commentaires tels qu'écrits dans le DDL. Le **sens métier** et les justifications sont
> dans `dictionnaire-donnees-v841.md` ; ce fichier garantit l'**exhaustivité**.

Légende : **NN** = NOT NULL ; **PK** = clé primaire ; **UQ** = unique ; **FK** = clé étrangère.

---

## utilisateur

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_utilisateur` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `nom` | `text` | oui |  | CHECK (length(nom) <= 80) |  |
| `prenom` | `text` | oui |  | CHECK (length(prenom) <= 80) |  |
| `email` | `d_email` | oui | UQ |  |  |
| `telephone` | `d_tel` |  |  |  |  |
| `password_hash` | `text` | oui |  |  |  |
| `date_creation` | `timestamptz` | oui |  | DEFAULT now() |  |
| `actif` | `boolean` | oui |  | DEFAULT true |  |
| `date_anonymisation` | `timestamptz` |  |  |  |  |

**Contraintes de table :**
- `ck_utilisateur_anonymise` — `CHECK (date_anonymisation IS NULL OR actif = false)`


## client

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_utilisateur` | `uuid` | oui | PK FK→utilisateur(id_utilisateur) |  |  |
| `frais_dossier_offerts` | `boolean` | oui |  | DEFAULT false |  |
| `annee_naissance` | `smallint` |  |  | CHECK (annee_naissance BETWEEN 1900 AND 2100) |  |
| `primo_accedant` | `boolean` | oui |  | DEFAULT false |  |
| `code_postal_residence` | `text` |  |  | CHECK (code_postal_residence ~ '^[0-9]{5}$') |  |
| `canal_contact_prefere` | `text` |  |  | CHECK (canal_contact_prefere IN ('telephone','email','sms')) |  |
| `consentement_marketing` | `boolean` | oui |  | DEFAULT false |  |
| `date_consentement_marketing` | `timestamptz` |  |  |  |  |
| `niveau_vigilance` | `text` | oui |  | DEFAULT 'standard' ; CHECK (niveau_vigilance IN ('standard','renforcee')) |  |
| `date_derniere_verification` | `date` |  |  |  |  |
| `origine_fonds_declaree` | `text` |  |  |  |  |

**Contraintes de table :**
- `ck_client_consent_mkg` — `CHECK (consentement_marketing = false OR date_consentement_marketing IS NOT NULL)`


## chasseur

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_utilisateur` | `uuid` | oui | PK FK→utilisateur(id_utilisateur) |  |  |
| `type_habilitation` | `text` | oui |  | CHECK (type_habilitation IN ('carte_t','attestation')) |  |
| `numero_habilitation` | `text` | oui |  |  | n° carte T ou n° attestation |
| `date_validite_habilitation` | `date` | oui |  |  | carte T ou attestation en cours de validité (exigence métier) |
| `organisme_delivrance` | `text` | oui |  |  | CCI (depuis 2015), ex-préfecture |
| `organisme_garant` | `text` | oui |  |  |  |
| `montant_garantie_financiere` | `d_montant` | oui |  | CHECK (montant_garantie_financiere > 0) |  |
| `numero_rcp` | `text` | oui |  |  |  |
| `date_echeance_rcp` | `date` | oui |  |  |  |
| `statut_juridique` | `text` | oui |  | CHECK (statut_juridique IN ('salarie','agent_commercial','independant')) |  |
| `numero_rsac` | `text` |  |  |  |  |
| `date_entree_reseau` | `date` | oui |  |  |  |
| `date_sortie_reseau` | `date` |  |  |  |  |
| `capacite_max_mandats` | `smallint` | oui |  | CHECK (capacite_max_mandats > 0) |  |
| `budget_min_intervention` | `d_montant` |  |  |  |  |
| `budget_max_intervention` | `d_montant` |  |  |  |  |
| `taux_honoraires_defaut` | `d_taux` |  |  |  |  |

**Contraintes de table :**
- `ck_chasseur_sortie` — `CHECK (date_sortie_reseau IS NULL OR date_sortie_reseau >= date_entree_reseau)`
- `ck_chasseur_budget` — `CHECK (budget_min_intervention IS NULL OR budget_max_intervention IS NULL OR budget_min_intervention <= budget_max_intervention)`
- `ck_chasseur_rsac` — `CHECK (statut_juridique <> 'agent_commercial' OR numero_rsac IS NOT NULL)`
- `ck_chasseur_habilitation` — `CHECK (statut_juridique <> 'salarie' OR type_habilitation = 'attestation')`


## gestionnaire

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_utilisateur` | `uuid` | oui | PK FK→utilisateur(id_utilisateur) |  |  |
| `matricule` | `text` | oui | UQ |  |  |
| `date_entree_fonction` | `date` | oui |  |  |  |
| `date_sortie_fonction` | `date` |  |  |  |  |
| `equipe` | `text` |  |  |  |  |
| `capacite_max_leads` | `smallint` | oui |  | CHECK (capacite_max_leads > 0) |  |

**Contraintes de table :**
- `ck_gestionnaire_sortie` — `CHECK (date_sortie_fonction IS NULL OR date_sortie_fonction >= date_entree_fonction)`


## indisponibilite

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_utilisateur` | `uuid` | oui | PK FK→utilisateur(id_utilisateur) |  |  |
| `date_debut` | `date` | oui | PK |  |  |
| `date_fin` | `date` |  |  |  |  |
| `motif` | `text` | oui |  | CHECK (motif IN ('conge','arret','formation','autre')) |  |

**Contraintes de table :**
- `PRIMARY KEY (id_utilisateur, date_debut)`
- `ck_indispo_dates` — `CHECK (date_fin IS NULL OR date_fin >= date_debut)`


## zone

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_zone` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `type_zone` | `text` | oui |  | CHECK (type_zone IN ('ville','secteur')) |  |
| `pays` | `text` | oui |  |  |  |
| `code_iso_pays` | `char(2)` | oui |  | CHECK (code_iso_pays ~ '^[A-Z]{2}$') |  |
| `devise` | `char(3)` | oui |  | CHECK (devise ~ '^[A-Z]{3}$') |  |
| `ville` | `citext` | oui |  |  |  |
| `code_insee` | `char(5)` |  |  | CHECK (code_insee ~ '^([0-9]{2}\|2[AB])[0-9]{3}$') |  |
| `secteur` | `citext` |  |  |  |  |
| `code_postal` | `text` |  |  |  |  |

**Contraintes de table :**
- `ck_zone_secteur` — `CHECK ( (type_zone = 'ville' AND secteur IS NULL) OR (type_zone = 'secteur' AND secteur IS NOT NULL))`
- `ck_zone_cp_fr` — `CHECK (code_iso_pays <> 'FR' OR code_postal ~ '^[0-9]{5}$')`
- `ck_zone_insee_fr` — `CHECK (code_iso_pays <> 'FR' OR code_insee IS NOT NULL)`
- `uk_zone_geo` — `UNIQUE NULLS NOT DISTINCT (pays, ville, secteur)`


## demande

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_demande` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_gestionnaire` | `uuid` |  | FK→gestionnaire(id_utilisateur) |  | dénorm. maintenue par trigger |
| `id_chasseur` | `uuid` |  | FK→chasseur(id_utilisateur) |  | dénorm. |
| `date_depot` | `timestamptz` | oui |  |  |  |
| `canal` | `text` | oui |  | CHECK (canal IN ('site_web','parrainage','telephone','autre')) |  |
| `description_initiale` | `text` |  |  |  |  |
| `date_consentement` | `timestamptz` |  |  |  |  |
| `date_affectation` | `timestamptz` |  |  |  | fait : la demande a été affectée |
| `date_qualification` | `timestamptz` |  |  |  | fait : le chasseur a qualifié (version de critères post-affectation) |
| `id_mandat_courant` | `uuid` |  |  |  | FK ajoutée après création de mandat (ALTER, dépendance circulaire) |
| `date_sans_suite` | `timestamptz` |  |  |  |  |
| `motif_sans_suite` | `text` |  |  | CHECK (motif_sans_suite IN ('budget_irrealiste','injoignable','hors_zone','abandon','autre')) |  |
| `nb_relances` | `smallint` | oui |  | DEFAULT 0 |  |
| `statut_financement` | `text` |  |  | CHECK (statut_financement IN ('non_evalue','a_evaluer','accord_principe','refuse')) |  |
| `apport_disponible` | `d_montant` |  |  |  |  |
| `montant_pret_envisage` | `d_montant` |  |  |  |  |
| `date_accord_principe` | `date` |  |  |  |  |
| `date_validite_accord` | `date` |  |  |  |  |

**Contraintes de table :**
- `ck_demande_consent_web` — `CHECK (canal <> 'site_web' OR date_consentement IS NOT NULL)`
- `ck_demande_sans_suite` — `CHECK ((date_sans_suite IS NULL) = (motif_sans_suite IS NULL))`
- `ck_demande_validite_acc` — `CHECK (date_validite_accord IS NULL OR date_accord_principe IS NULL OR date_validite_accord >= date_accord_principe)`


## demande_acquereur

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_demande` | `uuid` | oui | PK FK→demande(id_demande) |  |  |
| `id_client` | `uuid` | oui | PK FK→client(id_utilisateur) |  |  |
| `qualite` | `text` | oui |  | CHECK (qualite IN ('principal','co_acquereur')) |  |

**Contraintes de table :**
- `PRIMARY KEY (id_demande, id_client)`


## affectation

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_affectation` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_demande` | `uuid` | oui | FK→demande(id_demande) |  |  |
| `id_gestionnaire` | `uuid` | oui | FK→gestionnaire(id_utilisateur) |  |  |
| `id_chasseur` | `uuid` |  | FK→chasseur(id_utilisateur) |  |  |
| `date_debut` | `timestamptz` | oui |  |  |  |
| `date_fin` | `timestamptz` |  |  |  |  |
| `motif` | `text` | oui |  | CHECK (motif IN ('initiale','surcharge','absence','desaccord_client','refus_chasseur','autre')) |  |

**Contraintes de table :**
- `ck_affectation_dates` — `CHECK (date_fin IS NULL OR date_fin >= date_debut)`
- `uk_affectation` — `UNIQUE (id_demande, date_debut)`


## demande_version

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_version` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_demande` | `uuid` | oui | FK→demande(id_demande) |  |  |
| `id_modifie_par` | `uuid` | oui | FK→utilisateur(id_utilisateur) |  |  |
| `no_version` | `smallint` | oui |  | CHECK (no_version > 0) |  |
| `date_creation` | `timestamptz` | oui |  |  |  |
| `motif_evolution` | `text` | oui |  |  |  |
| `type_bien` | `text` | oui |  | CHECK (type_bien IN ('appartement','maison','terrain','immeuble','autre')) |  |
| `destination` | `text` | oui |  | CHECK (destination IN ('principale','secondaire','locatif')) |  |
| `budget_max` | `d_montant` | oui |  | CHECK (budget_max > 0) |  |
| `surface_min` | `smallint` |  |  | CHECK (surface_min > 0) |  |
| `nb_pieces_min` | `smallint` |  |  | CHECK (nb_pieces_min >= 0) |  |
| `nb_chambres_min` | `smallint` |  |  | CHECK (nb_chambres_min >= 0) |  |
| `nb_occupants` | `smallint` |  |  | CHECK (nb_occupants > 0) |  |
| `dpe_max` | `d_dpe` |  |  |  |  |
| `rendement_brut_min` | `numeric(5,2)` |  |  |  |  |
| `travaux_acceptes` | `boolean` | oui |  | DEFAULT false |  |
| `pref_ascenseur` | `d_preference` | oui |  | DEFAULT 'indifferent' |  |
| `pref_balcon` | `d_preference` | oui |  | DEFAULT 'indifferent' |  |
| `pref_terrasse` | `d_preference` | oui |  | DEFAULT 'indifferent' |  |
| `pref_jardin` | `d_preference` | oui |  | DEFAULT 'indifferent' |  |
| `pref_parking` | `d_preference` | oui |  | DEFAULT 'indifferent' |  |
| `pref_cave` | `d_preference` | oui |  | DEFAULT 'indifferent' |  |
| `commentaire_criteres` | `text` |  |  |  |  |

**Contraintes de table :**
- `uk_version_no` — `UNIQUE (id_demande, no_version)`
- `uk_version_cible` — `UNIQUE (id_demande, id_version)`
- `ck_version_rendement` — `CHECK (destination = 'locatif' OR rendement_brut_min IS NULL)`


## version_zone

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_version` | `uuid` | oui | PK FK→demande_version(id_version) |  |  |
| `id_zone` | `uuid` | oui | PK FK→zone(id_zone) |  |  |

**Contraintes de table :**
- `PRIMARY KEY (id_version, id_zone)`


## chasseur_zone

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_utilisateur` | `uuid` | oui | PK FK→chasseur(id_utilisateur) |  |  |
| `id_zone` | `uuid` | oui | PK FK→zone(id_zone) |  |  |
| `role_intervention` | `text` | oui |  | CHECK (role_intervention IN ('principal','secondaire')) |  |

**Contraintes de table :**
- `PRIMARY KEY (id_utilisateur, id_zone)`


## mandat

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_mandat` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_demande` | `uuid` | oui | FK→demande(id_demande) |  |  |
| `id_version_contractuelle` | `uuid` | oui |  |  |  |
| `id_chasseur` | `uuid` | oui | FK→chasseur(id_utilisateur) |  |  |
| `id_signataire` | `uuid` | oui |  |  |  |
| `id_mandat_precedent` | `uuid` |  | UQ FK→mandat(id_mandat) |  | filiation renouvellement (ADR-030) |
| `numero_registre` | `text` | oui | UQ |  |  |
| `date_signature` | `date` | oui |  |  |  |
| `mode_signature` | `text` | oui |  | CHECK (mode_signature IN ('presentiel','en_ligne')) |  |
| `date_debut` | `date` | oui |  |  |  |
| `numero_habilitation_signature` | `text` |  |  |  |  |
| `validite_habilitation_signature` | `date` |  |  |  |  |
| `exclusif` | `boolean` | oui |  |  |  |
| `taux_honoraires` | `d_taux` |  |  |  |  |
| `base_honoraires` | `text` | oui |  | CHECK (base_honoraires IN ('HT','TTC')) |  |
| `taux_tva` | `d_taux` | oui |  |  |  |
| `forfait_honoraires` | `d_montant` |  |  |  |  |
| `qualite_signataire` | `text` | oui |  | CHECK (qualite_signataire IN ('nom_propre','procuration')) |  |
| `reference_procuration` | `text` |  |  |  |  |
| `date_resiliation` | `date` |  |  |  |  |
| `type_resiliation` | `text` |  |  | CHECK (type_resiliation IN ('abandon_client','abandon_chasseur','vente_externe','non_conformite… |  |
| `motif_resiliation` | `text` |  |  |  | détail libre (ex. reprise migration à requalifier) |

**Contraintes de table :**
- `fk_mandat_version` — `FOREIGN KEY (id_demande, id_version_contractuelle) REFERENCES demande_version (id_demande, id_version)`
- `fk_mandat_signataire` — `FOREIGN KEY (id_demande, id_signataire) REFERENCES demande_acquereur (id_demande, id_client)`
- `uk_mandat_precedent` — `UNIQUE (id_mandat_precedent)`
- `ck_mandat_pas_auto_precedent` — `CHECK (id_mandat_precedent <> id_mandat)`
- `uk_mandat_demande` — `UNIQUE (id_mandat, id_demande)`
- `uk_mandat_chasseur` — `UNIQUE (id_mandat, id_chasseur)`
- `fk_mandat_precedent_demande` — `FOREIGN KEY (id_mandat_precedent, id_demande) REFERENCES mandat (id_mandat, id_demande)`
- `ck_mandat_effet` — `CHECK (date_debut = date_signature)`
- `ck_mandat_remun` — `CHECK (taux_honoraires IS NOT NULL OR forfait_honoraires IS NOT NULL)`
- `ck_mandat_procur` — `CHECK (qualite_signataire <> 'procuration' OR reference_procuration IS NOT NULL)`
- `ck_mandat_resil` — `CHECK ((date_resiliation IS NULL) = (type_resiliation IS NULL))`


## mandat_reprise

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_mandat` | `uuid` | oui | PK FK→mandat(id_mandat) |  |  |
| `statut_repris` | `text` | oui |  | CHECK (statut_repris IN ('actif','echu','renouvele','resilie','clos_succes')) |  |
| `source` | `text` | oui |  |  | la source de reprise (traçabilité) |
| `date_reprise` | `timestamptz` | oui |  | DEFAULT now() |  |


## parrainage

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_parrainage` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_parrain` | `uuid` | oui | FK→utilisateur(id_utilisateur) |  | client ou prospect (art. 2) |
| `id_filleul` | `uuid` |  | FK→utilisateur(id_utilisateur) |  | renseigné quand le filleul a un compte |
| `filleul_nom` | `text` | oui |  |  |  |
| `filleul_prenom` | `text` | oui |  |  |  |
| `filleul_email` | `d_email` |  |  |  |  |
| `filleul_telephone` | `d_tel` |  |  |  |  |
| `type_contrat` | `text` | oui |  | CHECK (type_contrat IN ('vente','gerance','syndic')) | art. 8 |
| `date_declaration` | `date` | oui |  |  | art. 4 : préalable à tout contact |
| `date_fin_validite` | `date` | oui |  |  |  |
| `statut` | `text` | oui |  | DEFAULT 'declare' |  |
| `id_mandat_concretise` | `uuid` |  | FK→mandat(id_mandat) |  |  |
| `date_concretisation` | `date` |  |  |  |  |
| `rib_recu` | `boolean` | oui |  | DEFAULT false |  |
| `date_reception_rib` | `date` |  |  |  |  |
| `montant_retribution` | `d_montant` |  |  |  | 400 € à la rétribution |
| `date_versement` | `date` |  |  |  |  |

**Contraintes de table :**
- `CHECK (statut IN ('declare','mandat_signe','concretise','retribue','expire','rejete'))`
- `ck_parrainage_pas_auto` — `CHECK (id_filleul IS NULL OR id_filleul <> id_parrain)`
- `ck_parrainage_validite` — `CHECK (date_fin_validite >= date_declaration)`
- `ck_parrainage_concret` — `CHECK (statut NOT IN ('concretise','retribue') OR id_mandat_concretise IS NOT NULL)`
- `ck_parrainage_retribue` — `CHECK (statut <> 'retribue' OR (rib_recu AND date_versement IS NOT NULL AND montant_retribution IS NOT NULL))`
- `uk_parrainage_filleul_concretise` — `UNIQUE (id_filleul, id_mandat_concretise)`


## bien

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_bien` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_zone` | `uuid` | oui | FK→zone(id_zone) |  |  |
| `type_bien` | `text` | oui |  | CHECK (type_bien IN ('appartement','maison','terrain','immeuble','autre')) |  |
| `surface` | `numeric(8,2)` |  |  | CHECK (surface > 0) |  |
| `nb_pieces` | `smallint` |  |  | CHECK (nb_pieces >= 0) |  |
| `nb_chambres` | `smallint` |  |  | CHECK (nb_chambres >= 0) |  |
| `etage` | `smallint` |  |  |  |  |
| `dpe` | `d_dpe` |  |  |  |  |
| `adresse_indicative` | `text` |  |  |  |  |
| `code_postal` | `text` |  |  |  |  |
| `a_ascenseur` | `boolean` |  |  |  | NULL = non renseigné par la source (volontaire) |
| `a_balcon` | `boolean` |  |  |  |  |
| `a_terrasse` | `boolean` |  |  |  |  |
| `a_jardin` | `boolean` |  |  |  |  |
| `a_parking` | `boolean` |  |  |  |  |
| `a_cave` | `boolean` |  |  |  |  |


## annonce

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_annonce` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_bien` | `uuid` | oui | FK→bien(id_bien) |  |  |
| `source` | `text` | oui |  |  |  |
| `reference_source` | `text` | oui |  |  |  |
| `titre` | `text` |  |  |  |  |
| `description` | `text` |  |  |  |  |
| `prix` | `d_montant` | oui |  | CHECK (prix > 0) |  |
| `url` | `text` |  |  |  |  |
| `date_publication` | `timestamptz` |  |  |  |  |
| `date_ingestion` | `timestamptz` | oui |  |  |  |
| `date_derniere_vue` | `timestamptz` | oui |  |  |  |
| `statut` | `text` | oui |  | CHECK (statut IN ('active','retiree','vendue')) |  |

**Contraintes de table :**
- `uk_annonce_source` — `UNIQUE (source, reference_source)`
- `uk_annonce_bien` — `UNIQUE (id_bien, id_annonce)`


## proposition

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_proposition` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_demande` | `uuid` | oui | FK→demande(id_demande) |  | dénorm. (rend C8 déclarative) |
| `id_version` | `uuid` | oui |  |  |  |
| `id_bien` | `uuid` | oui | FK→bien(id_bien) |  |  |
| `id_annonce_reference` | `uuid` |  |  |  |  |
| `id_mandat` | `uuid` | oui |  |  | A1/R8b : mandat sous lequel la proposition est faite (FK composée ci-dessous) |
| `date_matching` | `timestamptz` | oui |  |  |  |
| `date_soumission_client` | `timestamptz` |  |  |  |  |
| `date_reponse_client` | `timestamptz` |  |  |  |  |
| `score_matching` | `numeric(5,2)` |  |  | CHECK (score_matching BETWEEN 0 AND 100) |  |
| `priorite_client` | `smallint` |  |  | CHECK (priorite_client > 0) | B6/US05 : le client priorise la sélection |
| `statut` | `text` | oui |  | CHECK (statut IN ('a_qualifier','soumis','retenu_visite','refuse_client','ecarte_chasseur')) |  |
| `motif_rejet` | `text` |  |  |  |  |

**Contraintes de table :**
- `fk_proposition_version` — `FOREIGN KEY (id_demande, id_version) REFERENCES demande_version (id_demande, id_version)`
- `fk_proposition_annonce` — `FOREIGN KEY (id_bien, id_annonce_reference) REFERENCES annonce (id_bien, id_annonce)`
- `fk_proposition_mandat` — `FOREIGN KEY (id_mandat, id_demande) REFERENCES mandat (id_mandat, id_demande)`
- `ck_proposition_rejet` — `CHECK (statut <> 'refuse_client' OR motif_rejet IS NOT NULL)`


## commentaire

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_commentaire` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_auteur` | `uuid` | oui | FK→utilisateur(id_utilisateur) |  |  |
| `id_demande` | `uuid` |  | FK→demande(id_demande) |  |  |
| `id_proposition` | `uuid` |  | FK→proposition(id_proposition) |  |  |
| `id_bien` | `uuid` |  | FK→bien(id_bien) |  |  |
| `type_contexte` | `text` | oui |  | CHECK (type_contexte IN ('note_recherche','debrief_visite','analyse_annonce','note_bien')) |  |
| `est_prive` | `boolean` | oui |  | DEFAULT false |  |
| `contenu` | `text` | oui |  |  |  |
| `date_creation` | `timestamptz` | oui |  | DEFAULT now() |  |

**Contraintes de table :**
- `ck_commentaire_cible` — `CHECK (num_nonnulls(id_demande, id_proposition, id_bien) = 1)`


## visite

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_visite` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_proposition` | `uuid` | oui | FK→proposition(id_proposition) |  |  |
| `id_visiteur` | `uuid` | oui | FK→utilisateur(id_utilisateur) |  |  |
| `date_visite` | `date` | oui |  |  |  |
| `realisee` | `boolean` | oui |  |  |  |
| `motif_annulation` | `text` |  |  |  |  |

**Contraintes de table :**
- `ck_visite_annulation` — `CHECK (realisee = true OR motif_annulation IS NOT NULL)`


## offre_acquisition

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_offre` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_proposition` | `uuid` | oui | FK→proposition(id_proposition) |  |  |
| `id_offre_precedente` | `uuid` |  | FK→offre_acquisition(id_offre) |  |  |
| `camp` | `text` | oui |  | CHECK (camp IN ('acquereur','vendeur')) |  |
| `saisi_par` | `text` | oui |  | CHECK (saisi_par IN ('chasseur','gestionnaire','client')) |  |
| `montant` | `d_montant` | oui |  | CHECK (montant > 0) |  |
| `date_signature` | `date` | oui |  |  |  |
| `date_transmission` | `date` |  |  |  |  |
| `date_validite` | `date` | oui |  |  |  |
| `statut` | `text` | oui |  | CHECK (statut IN ('en_cours','acceptee','refusee','caduque','retiree')) |  |
| `date_reponse` | `date` |  |  |  |  |

**Contraintes de table :**
- `ck_offre_transmission` — `CHECK (date_transmission IS NULL OR date_transmission >= date_signature)`
- `ck_offre_reponse` — `CHECK (statut = 'en_cours' OR date_reponse IS NOT NULL)`


## notaire

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_notaire` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `nom` | `text` | oui |  |  |  |
| `etude` | `text` | oui |  |  |  |
| `email` | `d_email` |  |  |  |  |
| `telephone` | `d_tel` |  |  |  |  |

**Contraintes de table :**
- `uk_notaire` — `UNIQUE (nom, etude)`


## compromis

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_compromis` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_offre` | `uuid` | oui | UQ FK→offre_acquisition(id_offre) |  | A30 : au plus un |
| `id_notaire` | `uuid` | oui | FK→notaire(id_notaire) |  |  |
| `date_signature` | `date` | oui |  |  |  |
| `fin_retractation` | `date` | oui |  |  |  |
| `depot_garantie` | `d_montant` |  |  |  |  |
| `sequestre` | `text` |  |  |  |  |
| `date_acte_prevue` | `date` |  |  |  |  |
| `date_caducite` | `date` |  |  |  |  |
| `motif_caducite` | `text` |  |  |  |  |

**Contraintes de table :**
- `ck_compromis_retract` — `CHECK (fin_retractation >= date_signature)`
- `ck_compromis_caducite` — `CHECK ((date_caducite IS NULL) = (motif_caducite IS NULL))`


## clause_suspensive

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_clause` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_compromis` | `uuid` | oui | FK→compromis(id_compromis) |  |  |
| `type_clause` | `text` | oui |  | CHECK (type_clause IN ('financement','urbanisme','servitude','vente_prealable')) |  |
| `description` | `text` |  |  |  |  |
| `date_butoir` | `date` | oui |  |  |  |
| `statut` | `text` | oui |  | CHECK (statut IN ('en_attente','levee','non_levee')) |  |


## acte

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_acte` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_compromis` | `uuid` | oui | UQ FK→compromis(id_compromis) |  | A33 : au plus un |
| `date_signature` | `date` | oui |  |  |  |
| `montant_vente` | `d_montant` | oui |  | CHECK (montant_vente > 0) |  |
| `honoraires_fixe` | `d_montant` |  |  |  |  |
| `honoraires_taux` | `d_taux` |  |  |  |  |
| `honoraires_encaisses` | `boolean` | oui |  | DEFAULT false |  |
| `date_encaissement` | `date` |  |  |  |  |

**Contraintes de table :**
- `ck_acte_honoraires` — `CHECK (honoraires_fixe IS NOT NULL OR honoraires_taux IS NOT NULL)`
- `ck_acte_encaissement` — `CHECK (honoraires_encaisses = false OR date_encaissement IS NOT NULL)`


## bareme

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_bareme` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_chasseur` | `uuid` |  | FK→chasseur(id_utilisateur) |  | NULL = barème par défaut |
| `date_debut_vigueur` | `date` | oui |  |  |  |
| `date_fin_vigueur` | `date` |  |  |  |  |
| `perimetre` | `uuid` |  |  |  |  |

**Contraintes de table :**
- `ck_bareme_vigueur` — `CHECK (date_fin_vigueur IS NULL OR date_fin_vigueur >= date_debut_vigueur)`
- `ex_bareme_vigueur` — `EXCLUDE USING gist ( perimetre WITH =, daterange(date_debut_vigueur, date_fin_vigueur, '[]') WITH && )`


## tranche_bareme

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_tranche` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_bareme` | `uuid` | oui | FK→bareme(id_bareme) |  |  |
| `montant_min` | `d_montant` | oui |  |  |  |
| `montant_max` | `d_montant` |  |  |  | NULL = +∞ |
| `taux_base` | `d_taux` | oui |  |  |  |

**Contraintes de table :**
- `ck_tranche_bornes` — `CHECK (montant_max IS NULL OR montant_max > montant_min)`
- `ex_tranche_chevauchement` — `EXCLUDE USING gist ( id_bareme WITH =, numrange(montant_min::numeric, montant_max::numeric, '[)') WITH && )`


## parametre_honoraires

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_parametre` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `montant_fixe` | `d_montant` | oui |  |  |  |
| `pourcentage` | `d_taux` | oui |  |  |  |
| `date_debut_vigueur` | `date` | oui |  |  |  |
| `date_fin_vigueur` | `date` |  |  |  |  |

**Contraintes de table :**
- `ck_param_honoraires_vigueur` — `CHECK (date_fin_vigueur IS NULL OR date_fin_vigueur >= date_debut_vigueur)`


## remuneration_chasseur

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_remuneration` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_acte` | `uuid` | oui | UQ FK→acte(id_acte) |  |  |
| `id_chasseur` | `uuid` | oui | FK→chasseur(id_utilisateur) |  |  |
| `id_mandat` | `uuid` | oui |  |  | A1/S1 : mandat à l'origine (FK composée ci-dessous) |
| `honoraires` | `d_montant` | oui |  |  | assiette = fixe + % * prix_acté |
| `score_delai` | `numeric(5,2)` | oui |  | CHECK (score_delai BETWEEN 0 AND 100) | délai mandat->acte (pond. 25) |
| `score_exclusivite` | `numeric(5,2)` | oui |  | CHECK (score_exclusivite BETWEEN 0 AND 100) | exclusivité (pond. 10) |
| `score_ventes` | `numeric(5,2)` | oui |  | CHECK (score_ventes BETWEEN 0 AND 100) | ventes réussies / 12 mois (pond. 25) |
| `score_mandats` | `numeric(5,2)` | oui |  | CHECK (score_mandats BETWEEN 0 AND 100) | mandats signés / 12 mois (pond. 15) |
| `score_visites` | `numeric(5,2)` | oui |  | CHECK (score_visites BETWEEN 0 AND 100) | visites avant achat (pond. 25) |
| `score_performance` | `numeric(5,2)` | oui |  | CHECK (score_performance BETWEEN 0 AND 100) | global (moyenne pondérée) |
| `taux_base` | `d_taux` | oui |  |  | taux de tranche appliqué |
| `majoration_anciennete` | `d_taux` | oui |  |  | majoration relative (+%) |
| `modulation_performance` | `numeric(6,4)` | oui |  |  | ± autour du pivot (relatif) |
| `taux_final` | `d_taux` | oui |  | CHECK (taux_final BETWEEN 20 AND 60) |  |
| `montant` | `d_montant` | oui |  |  | rémunération = taux_final * honoraires |
| `id_bareme_applique` | `uuid` | oui | FK→bareme(id_bareme) |  | barème figé (traçabilité) |
| `date_calcul` | `timestamptz` | oui |  | DEFAULT now() |  |
| `date_annulation` | `date` |  |  |  |  |
| `motif_annulation` | `text` |  |  |  |  |

**Contraintes de table :**
- `fk_remuneration_mandat` — `FOREIGN KEY (id_mandat, id_chasseur) REFERENCES mandat (id_mandat, id_chasseur)`
- `uk_remuneration_acte` — `UNIQUE (id_acte)`
- `ck_remun_annulation` — `CHECK ((date_annulation IS NULL) = (motif_annulation IS NULL))`


## facture_chasseur

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_facture` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_remuneration` | `uuid` | oui | UQ FK→remuneration_chasseur(id_remuneration) |  |  |
| `numero` | `text` | oui | UQ |  |  |
| `montant` | `d_montant` | oui |  |  |  |
| `date_emission` | `date` | oui |  |  |  |
| `statut` | `text` | oui |  | DEFAULT 'soumise' |  |
| `date_verification` | `date` |  |  |  |  |
| `id_verificateur` | `uuid` |  | FK→gestionnaire(id_utilisateur) |  |  |
| `motif_rejet` | `text` |  |  |  |  |
| `statut_paiement` | `text` |  |  | CHECK (statut_paiement IN ('programme','paye')) |  |
| `date_programmation` | `date` |  |  |  |  |
| `date_paiement` | `date` |  |  |  |  |

**Contraintes de table :**
- `CHECK (statut IN ('soumise','verifiee_conforme','rejetee'))`
- `ck_facture_paiement` — `CHECK (statut_paiement IS NULL OR statut = 'verifiee_conforme')`
- `ck_facture_paye` — `CHECK (statut_paiement <> 'paye' OR date_paiement IS NOT NULL)`
- `ck_facture_rejet` — `CHECK (statut <> 'rejetee' OR motif_rejet IS NOT NULL)`
- `ck_facture_verif` — `CHECK (statut = 'soumise' OR date_verification IS NOT NULL)`


## note_avis

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_note` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `id_proposition` | `uuid` | oui | UQ FK→proposition(id_proposition) |  | une note par proposition |
| `contenu` | `text` |  |  |  | conclusions rédigées |
| `montant_offre_suggere` | `d_montant` |  |  | CHECK (montant_offre_suggere > 0) | pré-remplit l'offre (US06) |
| `date_redaction` | `timestamptz` | oui |  | DEFAULT now() |  |
| `date_mise_a_disposition` | `timestamptz` |  |  |  | mise à dispo du client |


## document

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_document` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `type_document` | `text` | oui |  | CHECK (type_document IN ('audio','video','pdf','image','autre')) |  |
| `cle_objet` | `text` | oui |  |  | clé technique dans le bucket (S3/MinIO) |
| `uri` | `text` | oui |  |  | URI d'accès (présignée ou publique) |
| `mime_type` | `text` | oui |  |  | type MIME exact (audio/mpeg, video/mp4, application/pdf…) |
| `taille_octets` | `bigint` | oui |  | CHECK (taille_octets >= 0) |  |
| `hash_sha256` | `char(64)` | oui |  | CHECK (hash_sha256 ~ '^[0-9a-f]{64}$') | intégrité + dédoublonnage |
| `libelle` | `text` |  |  |  |  |
| `date_ajout` | `timestamptz` | oui |  | DEFAULT now() |  |


## note_avis_document

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_note` | `uuid` | oui | PK FK→note_avis(id_note) |  |  |
| `id_document` | `uuid` | oui | PK FK→document(id_document) |  |  |

**Contraintes de table :**
- `PRIMARY KEY (id_note, id_document)`


## facture_document

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_facture` | `uuid` | oui | PK FK→facture_chasseur(id_facture) |  |  |
| `id_document` | `uuid` | oui | PK FK→document(id_document) |  |  |

**Contraintes de table :**
- `PRIMARY KEY (id_facture, id_document)`


## indicateur

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `code_indicateur` | `text` | oui | PK |  |  |
| `libelle` | `text` | oui |  |  |  |
| `unite` | `text` | oui |  |  |  |
| `perimetre_role` | `text` | oui |  | CHECK (perimetre_role IN ('chasseur','gestionnaire','client')) |  |
| `sens_optimal` | `text` | oui |  | CHECK (sens_optimal IN ('croissant','decroissant')) |  |
| `mode_calcul` | `text` | oui |  |  |  |


## periode

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_periode` | `uuid` | oui | PK | DEFAULT uuidv7() |  |
| `type_periode` | `text` | oui |  | CHECK (type_periode IN ('mois','trimestre','annee')) |  |
| `date_debut` | `date` | oui |  |  |  |
| `date_fin` | `date` | oui |  |  |  |

**Contraintes de table :**
- `ck_periode_dates` — `CHECK (date_fin >= date_debut)`
- `uk_periode` — `UNIQUE (type_periode, date_debut)`


## observation

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_utilisateur` | `uuid` | oui | PK FK→utilisateur(id_utilisateur) |  |  |
| `code_indicateur` | `text` | oui | PK FK→indicateur(code_indicateur) |  |  |
| `id_periode` | `uuid` | oui | PK FK→periode(id_periode) |  |  |
| `valeur` | `numeric(14,4)` | oui |  |  |  |
| `date_calcul` | `timestamptz` | oui |  |  |  |

**Contraintes de table :**
- `PRIMARY KEY (id_utilisateur, code_indicateur, id_periode)`


## objectif

| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |
|---|---|---|---|---|---|
| `id_utilisateur` | `uuid` | oui | PK FK→utilisateur(id_utilisateur) |  |  |
| `code_indicateur` | `text` | oui | PK FK→indicateur(code_indicateur) |  |  |
| `id_periode` | `uuid` | oui | PK FK→periode(id_periode) |  |  |
| `valeur_cible` | `numeric(14,4)` | oui |  |  |  |
| `date_fixation` | `timestamptz` | oui |  |  |  |

**Contraintes de table :**
- `PRIMARY KEY (id_utilisateur, code_indicateur, id_periode)`
