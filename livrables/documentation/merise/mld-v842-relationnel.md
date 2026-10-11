# MLD relationnel — v8.42 (généré)

> ⚙️ **Fichier GÉNÉRÉ depuis `livrables/db/01_ddl.sql`** par `sources/generer_mld.py` : ne pas le modifier à la main.
> Contrôle : `python livrables/documentation/merise/sources/generer_mld.py --verifier` (code 1 s'il est périmé).
> La section « Normalisation » est rédigée à la main (`sources/mld-normalisation.md`).

**38 relations, 340 attributs, 59 clés étrangères simples.** Notation : <u>souligné</u> = clé primaire, `#` = clé étrangère. Les types, nullités et défauts colonne par colonne sont dans `dictionnaire-colonnes-v841.md` ;
le sens métier dans `dictionnaire-donnees-v841.md` ; les cardinalités dans `mcd-v842-complet.md`.

## Règles de passage MCD → MLD appliquées

| Construction du MCD | Traduction relationnelle |
|---|---|
| Entité | Relation ; identifiant → clé primaire (UUIDv7, ADR-028 rév., ADR-044) |
| Association binaire (1,1)–(0,n) ou (0,1)–(0,n) | Clé étrangère côté (x,1) ; `NOT NULL` si (1,1) |
| Association binaire (0,1)–(0,1) | Clé étrangère `UNIQUE` côté porteur (ex. `acte.id_compromis`, `mandat.id_mandat_precedent`) |
| Association n,m | Relation dont la clé primaire est composée des clés des entités liées, plus les attributs portés |
| Association ternaire | Idem, clé à trois composantes (`observation`, `objectif`) |
| Héritage (sous-type) | Clé partagée : la clé primaire du sous-type est une clé étrangère vers le sur-type (ADR-026) |
| Contrainte d'intégrité fonctionnelle | Clé étrangère composée vers une clé unique composée (ex. `(id_mandat, id_demande)`) |

## Acteurs

**UTILISATEUR** (<u>id_utilisateur</u>, nom, prenom, email, telephone, password_hash, date_creation, actif, date_anonymisation)

- règles CHECK : `ck_utilisateur_anonymise`, `nom`, `prenom`

**CLIENT** (#<u>id_utilisateur</u>, frais_dossier_offerts, annee_naissance, primo_accedant, code_postal_residence, canal_contact_prefere, consentement_marketing, date_consentement_marketing, niveau_vigilance, date_derniere_verification, origine_fonds_declaree)

- `id_utilisateur` → `utilisateur(id_utilisateur)` (obligatoire)
- règles CHECK : `ck_client_consent_mkg`, `annee_naissance`, `code_postal_residence`, `canal_contact_prefere`, `niveau_vigilance`

**CHASSEUR** (#<u>id_utilisateur</u>, type_habilitation, numero_habilitation, date_validite_habilitation, organisme_delivrance, organisme_garant, montant_garantie_financiere, numero_rcp, date_echeance_rcp, statut_juridique, numero_rsac, date_entree_reseau, date_sortie_reseau, capacite_max_mandats, budget_min_intervention, budget_max_intervention, taux_honoraires_defaut)

- `id_utilisateur` → `utilisateur(id_utilisateur)` (obligatoire)
- règles CHECK : `ck_chasseur_sortie`, `ck_chasseur_budget`, `ck_chasseur_rsac`, `ck_chasseur_habilitation`, `type_habilitation`, `montant_garantie_financiere`, `statut_juridique`, `capacite_max_mandats`

**GESTIONNAIRE** (#<u>id_utilisateur</u>, matricule, date_entree_fonction, date_sortie_fonction, equipe, capacite_max_leads)

- `id_utilisateur` → `utilisateur(id_utilisateur)` (obligatoire)
- règles CHECK : `ck_gestionnaire_sortie`, `capacite_max_leads`

**INDISPONIBILITE** (#<u>id_utilisateur</u>, <u>date_debut</u>, date_fin, motif)

- `id_utilisateur` → `utilisateur(id_utilisateur)` (obligatoire)
- règles CHECK : `ck_indispo_dates`, `motif`

**PARRAINAGE** (<u>id_parrainage</u>, #id_parrain, #id_filleul, filleul_nom, filleul_prenom, filleul_email, filleul_telephone, type_contrat, date_declaration, date_fin_validite, statut, #id_mandat_concretise, date_concretisation, rib_recu, date_reception_rib, montant_retribution, date_versement)

- `id_parrain` → `utilisateur(id_utilisateur)` (obligatoire)
- `id_filleul` → `utilisateur(id_utilisateur)` (facultative)
- `id_mandat_concretise` → `mandat(id_mandat)` (facultative)
- unicité `uk_parrainage_filleul_concretise` : UNIQUE (id_filleul, id_mandat_concretise)
- règles CHECK : `ck_parrainage_pas_auto`, `ck_parrainage_validite`, `ck_parrainage_concret`, `ck_parrainage_retribue`, `type_contrat`

**CHASSEUR_ZONE** (#<u>id_utilisateur</u>, #<u>id_zone</u>, role_intervention)

- `id_utilisateur` → `chasseur(id_utilisateur)` (obligatoire)
- `id_zone` → `zone(id_zone)` (obligatoire)
- règles CHECK : `role_intervention`

## Demande

**DEMANDE** (<u>id_demande</u>, #id_gestionnaire, #id_chasseur, date_depot, canal, description_initiale, date_consentement, date_affectation, date_qualification, id_mandat_courant, date_sans_suite, motif_sans_suite, nb_relances, statut_financement, apport_disponible, montant_pret_envisage, date_accord_principe, date_validite_accord)

- `id_gestionnaire` → `gestionnaire(id_utilisateur)` (facultative)
- `id_chasseur` → `chasseur(id_utilisateur)` (facultative)
- règles CHECK : `ck_demande_consent_web`, `ck_demande_sans_suite`, `ck_demande_validite_acc`, `canal`, `motif_sans_suite`, `statut_financement`

**DEMANDE_VERSION** (<u>id_version</u>, #id_demande, #id_modifie_par, no_version, date_creation, motif_evolution, type_bien, destination, budget_max, surface_min, nb_pieces_min, nb_chambres_min, nb_occupants, dpe_max, rendement_brut_min, travaux_acceptes, pref_ascenseur, pref_balcon, pref_terrasse, pref_jardin, pref_parking, pref_cave, commentaire_criteres)

- `id_demande` → `demande(id_demande)` (obligatoire)
- `id_modifie_par` → `utilisateur(id_utilisateur)` (obligatoire)
- unicité `uk_version_no` : UNIQUE (id_demande, no_version)
- unicité `uk_version_cible` : UNIQUE (id_demande, id_version)
- règles CHECK : `ck_version_rendement`, `no_version`, `type_bien`, `destination`, `budget_max`, `surface_min`, `nb_pieces_min`, `nb_chambres_min`, `nb_occupants`

**DEMANDE_ACQUEREUR** (#<u>id_demande</u>, #<u>id_client</u>, qualite)

- `id_demande` → `demande(id_demande)` (obligatoire)
- `id_client` → `client(id_utilisateur)` (obligatoire)
- règles CHECK : `qualite`

**AFFECTATION** (<u>id_affectation</u>, #id_demande, #id_gestionnaire, #id_chasseur, date_debut, date_fin, motif)

- `id_demande` → `demande(id_demande)` (obligatoire)
- `id_gestionnaire` → `gestionnaire(id_utilisateur)` (obligatoire)
- `id_chasseur` → `chasseur(id_utilisateur)` (facultative)
- unicité `uk_affectation` : UNIQUE (id_demande, date_debut)
- règles CHECK : `ck_affectation_dates`, `motif`

**ZONE** (<u>id_zone</u>, type_zone, pays, code_iso_pays, devise, ville, code_insee, secteur, code_postal)

- unicité `uk_zone_geo` : UNIQUE NULLS NOT DISTINCT (pays, ville, secteur)
- règles CHECK : `ck_zone_secteur`, `ck_zone_cp_fr`, `ck_zone_insee_fr`, `type_zone`, `code_iso_pays`, `devise`, `code_insee`

**VERSION_ZONE** (#<u>id_version</u>, #<u>id_zone</u>)

- `id_version` → `demande_version(id_version)` (obligatoire)
- `id_zone` → `zone(id_zone)` (obligatoire)

**COMMENTAIRE** (<u>id_commentaire</u>, #id_auteur, #id_demande, #id_proposition, #id_bien, type_contexte, est_prive, contenu, date_creation)

- `id_auteur` → `utilisateur(id_utilisateur)` (obligatoire)
- `id_demande` → `demande(id_demande)` (facultative)
- `id_proposition` → `proposition(id_proposition)` (facultative)
- `id_bien` → `bien(id_bien)` (facultative)
- règles CHECK : `ck_commentaire_cible`, `type_contexte`

## Biens et prospection

**BIEN** (<u>id_bien</u>, #id_zone, type_bien, surface, nb_pieces, nb_chambres, etage, dpe, adresse_indicative, code_postal, a_ascenseur, a_balcon, a_terrasse, a_jardin, a_parking, a_cave)

- `id_zone` → `zone(id_zone)` (obligatoire)
- règles CHECK : `type_bien`, `surface`, `nb_pieces`, `nb_chambres`

**ANNONCE** (<u>id_annonce</u>, #id_bien, source, reference_source, titre, description, prix, url, date_publication, date_ingestion, date_derniere_vue, statut)

- `id_bien` → `bien(id_bien)` (obligatoire)
- unicité `uk_annonce_source` : UNIQUE (source, reference_source)
- unicité `uk_annonce_bien` : UNIQUE (id_bien, id_annonce)
- règles CHECK : `prix`, `statut`

**PROPOSITION** (<u>id_proposition</u>, #id_demande, id_version, #id_bien, id_annonce_reference, id_mandat, date_matching, date_soumission_client, date_reponse_client, score_matching, priorite_client, statut, motif_rejet)

- `id_demande` → `demande(id_demande)` (obligatoire)
- `id_bien` → `bien(id_bien)` (obligatoire)
- clé étrangère composée `fk_proposition_version` : FOREIGN KEY (id_demande, id_version) REFERENCES demande_version (id_demande, id_version)
- clé étrangère composée `fk_proposition_annonce` : FOREIGN KEY (id_bien, id_annonce_reference) REFERENCES annonce (id_bien, id_annonce)
- clé étrangère composée `fk_proposition_mandat` : FOREIGN KEY (id_mandat, id_demande) REFERENCES mandat (id_mandat, id_demande)
- règles CHECK : `ck_proposition_rejet`, `score_matching`, `priorite_client`, `statut`

**VISITE** (<u>id_visite</u>, #id_proposition, #id_visiteur, date_visite, realisee, motif_annulation)

- `id_proposition` → `proposition(id_proposition)` (obligatoire)
- `id_visiteur` → `utilisateur(id_utilisateur)` (obligatoire)
- règles CHECK : `ck_visite_annulation`

**NOTE_AVIS** (<u>id_note</u>, #id_proposition, contenu, montant_offre_suggere, date_redaction, date_mise_a_disposition)

- `id_proposition` → `proposition(id_proposition)` (obligatoire, unique)
- règles CHECK : `montant_offre_suggere`

**DOCUMENT** (<u>id_document</u>, type_document, cle_objet, uri, mime_type, taille_octets, hash_sha256, libelle, date_ajout)

- règles CHECK : `type_document`, `taille_octets`, `hash_sha256`

**NOTE_AVIS_DOCUMENT** (#<u>id_note</u>, #<u>id_document</u>)

- `id_note` → `note_avis(id_note)` (obligatoire)
- `id_document` → `document(id_document)` (obligatoire)

## Vente

**OFFRE_ACQUISITION** (<u>id_offre</u>, #id_proposition, #id_offre_precedente, camp, saisi_par, montant, date_signature, date_transmission, date_validite, statut, date_reponse)

- `id_proposition` → `proposition(id_proposition)` (obligatoire)
- `id_offre_precedente` → `offre_acquisition(id_offre)` (facultative)
- règles CHECK : `ck_offre_transmission`, `ck_offre_reponse`, `camp`, `saisi_par`, `montant`, `statut`

**COMPROMIS** (<u>id_compromis</u>, #id_offre, #id_notaire, date_signature, fin_retractation, depot_garantie, sequestre, date_acte_prevue, date_caducite, motif_caducite)

- `id_offre` → `offre_acquisition(id_offre)` (obligatoire, unique)
- `id_notaire` → `notaire(id_notaire)` (obligatoire)
- règles CHECK : `ck_compromis_retract`, `ck_compromis_caducite`

**CLAUSE_SUSPENSIVE** (<u>id_clause</u>, #id_compromis, type_clause, description, date_butoir, statut)

- `id_compromis` → `compromis(id_compromis)` (obligatoire)
- règles CHECK : `type_clause`, `statut`

**NOTAIRE** (<u>id_notaire</u>, nom, etude, email, telephone)

- unicité `uk_notaire` : UNIQUE (nom, etude)

**ACTE** (<u>id_acte</u>, #id_compromis, #id_mandat, source_information, date_connaissance, date_signature, montant_vente, honoraires_fixe, honoraires_taux, honoraires_encaisses, date_encaissement)

- `id_compromis` → `compromis(id_compromis)` (facultative, unique)
- `id_mandat` → `mandat(id_mandat)` (facultative, unique)
- règles CHECK : `ck_acte_honoraires`, `ck_acte_encaissement`, `ck_acte_origine`, `ck_acte_trace_hors_dispositif`, `source_information`, `montant_vente`

## Rémunération

**BAREME** (<u>id_bareme</u>, #id_chasseur, date_debut_vigueur, date_fin_vigueur, perimetre)

- `id_chasseur` → `chasseur(id_utilisateur)` (facultative)
- exclusion `ex_bareme_vigueur` : EXCLUDE USING gist ( perimetre WITH =, daterange(date_debut_vigueur, date_fin_vigueur, '[]') WITH && )
- règles CHECK : `ck_bareme_vigueur`

**TRANCHE_BAREME** (<u>id_tranche</u>, #id_bareme, montant_min, montant_max, taux_base)

- `id_bareme` → `bareme(id_bareme)` (obligatoire)
- exclusion `ex_tranche_chevauchement` : EXCLUDE USING gist ( id_bareme WITH =, numrange(montant_min::numeric, montant_max::numeric, '[)') WITH && )
- règles CHECK : `ck_tranche_bornes`

**PARAMETRE_HONORAIRES** (<u>id_parametre</u>, montant_fixe, pourcentage, date_debut_vigueur, date_fin_vigueur)

- règles CHECK : `ck_param_honoraires_vigueur`

**REMUNERATION_CHASSEUR** (<u>id_remuneration</u>, #id_acte, #id_chasseur, id_mandat, honoraires, score_delai, score_exclusivite, score_ventes, score_mandats, score_visites, score_performance, taux_base, majoration_anciennete, modulation_performance, taux_final, montant, #id_bareme_applique, date_calcul, date_annulation, motif_annulation)

- `id_acte` → `acte(id_acte)` (obligatoire, unique)
- `id_chasseur` → `chasseur(id_utilisateur)` (obligatoire)
- `id_bareme_applique` → `bareme(id_bareme)` (obligatoire)
- clé étrangère composée `fk_remuneration_mandat` : FOREIGN KEY (id_mandat, id_chasseur) REFERENCES mandat (id_mandat, id_chasseur)
- unicité `uk_remuneration_acte` : UNIQUE (id_acte)
- règles CHECK : `ck_remun_annulation`, `score_delai`, `score_exclusivite`, `score_ventes`, `score_mandats`, `score_visites`, `score_performance`, `taux_final`

**FACTURE_CHASSEUR** (<u>id_facture</u>, #id_remuneration, numero, montant, date_emission, statut, date_verification, #id_verificateur, motif_rejet, statut_paiement, date_programmation, date_paiement)

- `id_remuneration` → `remuneration_chasseur(id_remuneration)` (obligatoire, unique)
- `id_verificateur` → `gestionnaire(id_utilisateur)` (facultative)
- règles CHECK : `ck_facture_paiement`, `ck_facture_paye`, `ck_facture_rejet`, `ck_facture_verif`, `statut_paiement`

**FACTURE_DOCUMENT** (#<u>id_facture</u>, #<u>id_document</u>)

- `id_facture` → `facture_chasseur(id_facture)` (obligatoire)
- `id_document` → `document(id_document)` (obligatoire)

## Mandat et pilotage

**MANDAT** (<u>id_mandat</u>, #id_demande, id_version_contractuelle, #id_chasseur, id_signataire, #id_mandat_precedent, numero_registre, date_signature, mode_signature, date_debut, numero_habilitation_signature, validite_habilitation_signature, exclusif, taux_honoraires, base_honoraires, taux_tva, forfait_honoraires, qualite_signataire, reference_procuration, date_resiliation, type_resiliation, motif_resiliation)

- `id_demande` → `demande(id_demande)` (obligatoire)
- `id_chasseur` → `chasseur(id_utilisateur)` (obligatoire)
- `id_mandat_precedent` → `mandat(id_mandat)` (facultative, unique)
- clé étrangère composée `fk_mandat_version` : FOREIGN KEY (id_demande, id_version_contractuelle) REFERENCES demande_version (id_demande, id_version)
- clé étrangère composée `fk_mandat_signataire` : FOREIGN KEY (id_demande, id_signataire) REFERENCES demande_acquereur (id_demande, id_client)
- unicité `uk_mandat_precedent` : UNIQUE (id_mandat_precedent)
- unicité `uk_mandat_demande` : UNIQUE (id_mandat, id_demande)
- unicité `uk_mandat_chasseur` : UNIQUE (id_mandat, id_chasseur)
- clé étrangère composée `fk_mandat_precedent_demande` : FOREIGN KEY (id_mandat_precedent, id_demande) REFERENCES mandat (id_mandat, id_demande)
- règles CHECK : `ck_mandat_pas_auto_precedent`, `ck_mandat_effet`, `ck_mandat_remun`, `ck_mandat_procur`, `ck_mandat_resil`, `ck_mandat_vente_externe`, `mode_signature`, `base_honoraires`, `qualite_signataire`, `type_resiliation`

**MANDAT_REPRISE** (#<u>id_mandat</u>, statut_repris, source, date_reprise)

- `id_mandat` → `mandat(id_mandat)` (obligatoire)
- règles CHECK : `statut_repris`

**INDICATEUR** (<u>code_indicateur</u>, libelle, unite, perimetre_role, sens_optimal, mode_calcul)

- règles CHECK : `perimetre_role`, `sens_optimal`

**PERIODE** (<u>id_periode</u>, type_periode, date_debut, date_fin)

- unicité `uk_periode` : UNIQUE (type_periode, date_debut)
- règles CHECK : `ck_periode_dates`, `type_periode`

**OBSERVATION** (#<u>id_utilisateur</u>, #<u>code_indicateur</u>, #<u>id_periode</u>, valeur, date_calcul)

- `id_utilisateur` → `utilisateur(id_utilisateur)` (obligatoire)
- `code_indicateur` → `indicateur(code_indicateur)` (obligatoire)
- `id_periode` → `periode(id_periode)` (obligatoire)

**OBJECTIF** (#<u>id_utilisateur</u>, #<u>code_indicateur</u>, #<u>id_periode</u>, valeur_cible, date_fixation)

- `id_utilisateur` → `utilisateur(id_utilisateur)` (obligatoire)
- `code_indicateur` → `indicateur(code_indicateur)` (obligatoire)
- `id_periode` → `periode(id_periode)` (obligatoire)

## Domaines de valeurs (CREATE DOMAIN)

| Domaine | Définition |
|---|---|
| `d_email` | citext CHECK (VALUE ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$') |
| `d_dpe` | char(1) CHECK (VALUE IN ('A','B','C','D','E','F','G')) |
| `d_preference` | text CHECK (VALUE IN ('exige','souhaite','exclut','indifferent')) |
| `d_taux` | numeric(5,2) CHECK (VALUE BETWEEN 0 AND 100) |
| `d_montant` | numeric(12,2) CHECK (VALUE >= 0) |
| `d_tel` | text CHECK (VALUE ~ '^\+?[0-9 .\-]{6,20}$') |

## Normalisation

### Démarche

Le MLD est obtenu par les règles de passage ci-dessus, puis vérifié forme par forme. La cible est la **troisième forme normale (3FN)** pour toutes les relations transactionnelles ; les écarts sont des **dénormalisations décidées**, chacune tracée par un ADR, jamais des oublis.

### Première forme normale (1FN) — valeurs atomiques, pas de groupe répétitif

- Les critères de recherche de l'existant étaient un texte libre écrasé à chaque modification (`description_recherche`, anomalies A03 et A10c). Ils sont éclatés en attributs typés dans `demande_version` (`budget_max`, `surface_min`, `pref_balcon`…), une ligne par version : pas de liste dans une colonne, pas de perte d'historique.
- Les zones ciblées par une recherche et les zones d'intervention d'un chasseur sont des relations n,m (`version_zone`, `chasseur_zone`), pas des colonnes « zone_1, zone_2 ».
- Les documents joints sont des lignes de `document` reliées par `note_avis_document` et `facture_document`, pas des colonnes « pièce_jointe_n ».
- Seuls champs de texte libre conservés : `commentaire_criteres`, `description_initiale`, `contenu` (notes, commentaires), `motif_*`. Ils sont descriptifs ; aucune règle de gestion ne les lit.

### Deuxième forme normale (2FN) — tout attribut dépend de la clé entière

Concerne les relations à clé composée :

| Relation | Clé | Attributs portés | Dépendance |
|---|---|---|---|
| `demande_acquereur` | (id_demande, id_client) | `qualite` | la qualité (principal / co-acquéreur) n'a de sens que pour le couple |
| `chasseur_zone` | (id_chasseur, id_zone) | `role_intervention` | le rôle dépend du couple |
| `observation` | (id_utilisateur, code_indicateur, id_periode) | `valeur`, `date_calcul` | une mesure est propre au triplet |
| `objectif` | (id_utilisateur, code_indicateur, id_periode) | `valeur_cible`, `date_fixation` | idem |
| `version_zone`, `note_avis_document`, `facture_document` | couples de clés | — | aucun attribut : rien à vérifier |

Aucun attribut ne dépend d'une partie seulement de la clé.

### Troisième forme normale (3FN) — pas de dépendance transitive

Les dépendances transitives repérées, et ce qui en a été fait :

| Relation | Dépendance | Décision | Référence |
|---|---|---|---|
| `zone` | `code_iso_pays` → `pays`, `devise` | **Dénormalisation assumée** : le référentiel des pays n'est pas modélisé en phase 2 (un seul pays en production) ; la conformité par pays est différée (CDC v3.0, PO-6). À normaliser en phase 3 (relation `pays`) lors de l'ouverture européenne | ADR-ouverture-internationale |
| `demande` | `id_chasseur`, `date_affectation` dérivables de l'affectation ouverte | **Redondance maintenue par trigger** (`tg_affectation_sync`) : lecture directe du chasseur courant sans parcourir l'historique des affectations | ADR-048 |
| `demande` | `id_mandat_courant` dérivable des mandats | **Fait de gestion**, pas une dérivation : le gestionnaire désigne le mandat courant (renouvellements, reprise) | ADR-048 |
| `mandat` | `numero_habilitation_signature`, `validite_habilitation_signature` copiés du chasseur | **Gel juridique** : c'est l'habilitation *à la date de signature* qui compte (loi Hoguet) ; la valeur courante du chasseur change ensuite. Dépendance temporelle, pas transitive | ADR-039, ADR-046 |
| `remuneration_chasseur` | toutes les composantes du calcul (scores, taux, barème appliqué) | **Gel complet au jour de l'acte** : le calcul doit rester reconstituable si le barème ou les règles changent | ADR-049, ADR-052 |
| `acte` | `honoraires_fixe`, `honoraires_taux` face à `mandat.taux_honoraires` | Pas une dépendance : les honoraires constatés à l'acte peuvent différer du mandat (négociation, forfait) ; l'assiette est ce que le notaire collecte | ADR-049 |
| `parrainage` | `filleul_nom`, `filleul_prenom` face à `id_filleul` | Pas une dépendance : le filleul est déclaré avant d'exister comme utilisateur ; `id_filleul` est renseigné ensuite | ADR-034, ADR-parrainage |
| `mandat_reprise` | `statut_repris` face à l'état dérivé | **Fait historique non recalculable** (reprise de données) : il prime sur le calcul | ADR-051 |

### Forme normale de Boyce-Codd (FNBC) — clés candidates

Chaque relation a une clé primaire technique (UUIDv7) et, le cas échéant, une clé candidate métier déclarée `UNIQUE` : `utilisateur.email`, `gestionnaire.matricule`, `mandat.numero_registre`, `annonce(source, reference_source)`, `notaire(nom, etude)`, `facture_chasseur.numero`, `remuneration_chasseur.id_acte` (une rémunération par acte), `acte.id_compromis`, `acte.id_mandat`, `mandat.id_mandat_precedent` (successeur unique). Tout déterminant est une clé candidate : la FNBC est respectée.

### Ce que le modèle relationnel ne sait pas exprimer, et où c'est porté

| Règle | Pourquoi hors MLD | Portée par |
|---|---|---|
| Un acte a exactement une origine (compromis ou mandat) | contrainte sur deux colonnes facultatives | `CHECK ck_acte_origine` (MPD) |
| Deux barèmes ou deux tranches ne se chevauchent pas | contrainte d'intervalle | `EXCLUDE USING gist` (MPD, ADR-045) |
| Un renouvellement commence au moins 6 mois après le précédent | règle inter-lignes | trigger `tg_mandat_succession` (ADR-048) |
| Un acte hors dispositif exige un mandat exclusif en vigueur ; la rémunération porte sur le mandat en vigueur de la chaîne | règle inter-lignes et temporelle | triggers S24, S25, S26 et re-vérification différée (ADR-053, D13) |
| L'état d'un mandat, d'une demande, d'un compromis | dérivé, jamais stocké | vues `v_mandat`, `v_demande`, `v_compromis` (ADR-048) |

### Rattachement RNCP40573

BC05 — « Concevoir la base pour l'analytique et l'IA » : MLD normalisé, dénormalisations justifiées et tracées. BC03 — intégrité portée par le SGBD (clés, unicités, contraintes, déclencheurs). BC01 — chaque écart à la 3FN renvoie à une décision d'architecture.
