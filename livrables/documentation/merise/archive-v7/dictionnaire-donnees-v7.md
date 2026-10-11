# Dictionnaire des données — v7 (extrait autonome)

**Plateforme de chasse immobilière** · Extrait du dossier de modélisation v7 (section 2), à jour des ADR-025 à 031.
Brique de travail : source de référence pour le MLD, le MPD et la migration.

# 2. Dictionnaire des données

**Convention.** La colonne « Type » indique le type pressenti (artefact Merise antérieur au MCD, à titre de cadrage). La colonne « Contraintes » — ajout v7 — anticipe les règles de validité qui seront portées par les niveaux logique et physique : `PK` (clé primaire), `FK→table` (clé étrangère), `U` (unique), `NN` (not null), `D:` (valeur par défaut), `CK:` (contrôle de valeur), `GEN:` (colonne générée). Un attribut sans `NN` est nullable, et la justification du NULL est donnée quand elle porte un sens métier.

Identifiants préfixés `#`. **R** = identification relative.

## 2.1 UTILISATEUR

Personne physique disposant d'un accès. Sur-type des trois rôles. Héritage **non exclusif et non total** : un utilisateur peut cumuler les rôles ou n'en avoir aucun.

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_utilisateur` | entier | PK | Identifiant technique, stable même en cas de changement d'email |
| `nom` / `prenom` | varchar(80) | NN | Identité civile, obligatoire sur les actes signés |
| `email` | varchar(255) | U, NN, CK: format | Identifiant de connexion. Insensible à la casse (citext au MPD) |
| `telephone` | varchar(20) | CK: format | Canal privilégié en qualification. NULL accepté : tous les canaux d'entrée ne le collectent pas |
| `password_hash` | texte | NN | Empreinte bcrypt/argon2. Attribut technique, absent du MCD |
| `date_creation` | timestamp | NN, D: now() | Ancienneté du compte, base des purges RGPD |
| `actif` | booléen | NN, D: vrai | Suspension sans suppression : mandats et commentaires historiques restent rattachés |
| `date_anonymisation` | timestamp | CK: NULL ou NOT actif | Horodate la procédure d'anonymisation RGPD ; sans elle, on ne prouve ni qu'elle a eu lieu, ni quand. Un compte anonymisé est nécessairement inactif (C12) |

## 2.2 CLIENT

Spécialisation de `UTILISATEUR`. **Particulier acquéreur** (le B2B est hors périmètre — ADR-018), agissant pour son compte ou celui de son foyer.

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_utilisateur` | entier | PK, FK→utilisateur | Clé primaire = clé étrangère vers le sur-type (héritage R7) |
| `id_client_parrain` | entier | FK→client | Association réflexive PARRAINE. NULL : la plupart des clients ne sont pas parrainés |
| `date_parrainage` | date | CK: NN si parrain | Rend la viralité et la récompense de parrain calculables |
| `annee_naissance` | smallint | CK: plage plausible | Durée d'emprunt mobilisable, segmentation. **Année seule** plutôt que date : même usage métier, exposition RGPD moindre (minimisation) |
| `primo_accedant` | booléen | NN, D: faux | Segment au comportement distinct (PTZ, décision plus longue). Discriminant de premier plan des taux de transformation |
| `code_postal_residence` | varchar(10) | CK: format FR | Distinct de la zone recherchée. Détecte les mobilités entrantes, au cycle plus long |
| `canal_contact_prefere` | varchar(20) | CK: liste | Téléphone, email, SMS. Conditionne le taux de réponse aux propositions |
| `consentement_marketing` | booléen | NN, D: faux | Distinct du consentement au traitement du lead (porté par DEMANDE). La prospection exige son propre consentement |
| `date_consentement_marketing` | timestamp | CK: NN si consentement | Un consentement non horodaté n'est pas démontrable |
| `niveau_vigilance` | varchar(20) | NN, D: standard, CK: liste | Standard ou renforcée. Obligation LCB-FT, applicable aux personnes physiques |
| `date_derniere_verification` | date | — | Une vérification d'identité a une durée de validité ; sans date, la conformité n'est pas démontrable |
| `origine_fonds_declaree` | texte | — | Déclaration LCB-FT, exigible sur les montages atypiques (donation, vente à l'étranger) |

> **Deux attributs volontairement écartés** (minimisation RGPD) : les **revenus bruts** (une tranche suffit à tout usage métier) et la **situation familiale** (le besoin réel — combien de personnes vivront dans le logement — est un critère de recherche : `demande_version.nb_occupants`).

## 2.3 CHASSEUR

Spécialisation de `UTILISATEUR`. Seul acteur soumis à une obligation légale directe : la loi Hoguet encadre l'exercice, et un mandat signé hors conditions est nul.

**Volet conformité**

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_utilisateur` | entier | PK, FK→utilisateur | Héritage R7 |
| `numero_carte_t` | varchar(30) | NN, U | Carte professionnelle transaction. Mention obligatoire sur le mandat |
| `date_validite_carte_t` | date | NN | Carte délivrée pour trois ans. Un mandat signé carte expirée est nul : sans cette date, aucun contrôle possible |
| `prefecture_delivrance` | varchar(60) | NN | Mention obligatoire sur le mandat et au registre |
| `organisme_garant` | varchar(80) | NN | Garantie financière : mention légale obligatoire du mandat |
| `montant_garantie_financiere` | numeric(12,2) | NN, CK: > 0 | Idem |
| `numero_rcp` | varchar(40) | NN | Responsabilité civile professionnelle, obligatoire |
| `date_echeance_rcp` | date | NN | Renouvellement annuel : sans échéance, pas de contrôle de conformité |
| `statut_juridique` | varchar(30) | NN, CK: liste | Salarié, agent commercial, indépendant. Conditionne rémunération et régime fiscal |
| `numero_rsac` | varchar(30) | CK: NN si agent commercial | Registre spécial des agents commerciaux, obligatoire pour les mandataires uniquement |

**Volet exploitation**

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `date_entree_reseau` | date | NN | Ancienneté. Neutralise le biais d'un arrivant récent dans tout classement |
| `date_sortie_reseau` | date | CK: ≥ entrée | Sortie sans suppression |
| `capacite_max_mandats` | smallint | NN, CK: > 0 | Plafond de mandats actifs simultanés : un chasseur saturé rend un service dégradé |
| `budget_min_intervention` / `budget_max_intervention` | numeric(12,2) | CK: min ≤ max | Segment d'expertise : un chasseur haut de gamme n'est pas interchangeable |
| `taux_honoraires_defaut` | numeric(5,2) | CK: 0–100 | Valeur proposée, **recopiée et figée au mandat** — deux données distinctes |

> Les **zones d'intervention** et **spécialités** sont des associations n-n (`chasseur_zone`), pas des colonnes : un chasseur *est* territorial, sa valeur ajoutée est la connaissance d'un marché local. L'affectation devient alors calculable : zone ∩ budget ∩ typologie ∩ charge disponible.

## 2.4 GESTIONNAIRE

Spécialisation de `UTILISATEUR`. Cinq colonnes suffisent : l'essentiel de ce qui rend ses KPI calculables se stocke sur `DEMANDE` et `AFFECTATION`.

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_utilisateur` | entier | PK, FK→utilisateur | Héritage R7 |
| `matricule` | varchar(20) | U, NN | Rapprochement SIRH et paie variable. Distinct de l'identifiant technique |
| `date_entree_fonction` | date | NN | Ancienneté dans le rôle : comparer un arrivant de mars à un ancien fausse tout classement |
| `date_sortie_fonction` | date | CK: ≥ entrée | Sortie du rôle sans suppression du compte. Un booléen `actif` ne dit pas *quand* |
| `equipe` | varchar(40) | — | Maille d'agrégation des KPI. En lot 2 : entité EQUIPE avec responsable |
| `capacite_max_leads` | smallint | NN, CK: > 0 | Plafond de leads simultanés. Alimente l'affectation et la détection de surcharge |

## 2.5 INDISPONIBILITE

Entité à identification relative sur `UTILISATEUR`. Congés, arrêts, formations.

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_utilisateur` | entier | PK (composée), FK→utilisateur | Identification relative : n'existe que rattachée à un utilisateur |
| `# date_debut` **R** | date | PK (composée) | Identifiant relatif |
| `date_fin` | date | CK: ≥ début | Absence en cours si nulle |
| `motif` | varchar(60) | NN, CK: liste | Congé, arrêt, formation : le retrait de charge n'est pas traité pareil |

> Sans cette entité, un acteur en congé apparaît lent ou improductif : tout KPI de délai est biaisé. Un booléen `disponible` ne convient pas — ni daté, ni historisable.

## 2.6 ZONE

Référentiel géographique **restructuré en v6 (ADR-022)** : table unique portant tous les niveaux, hiérarchie par colonnes (l'auto-association ENGLOBE a disparu). Alimenté par import officiel (COG INSEE).

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_zone` | entier | PK | Identifiant du référentiel |
| `type_zone` | varchar(20) | NN, CK: ville \| secteur | Granularité de ciblage de la ligne |
| `pays` | varchar(80) | NN | Niveau supérieur, requis par l'ouverture internationale (Phase 3) |
| `code_iso_pays` | char(2) | NN, CK: format ISO | Clé de rapprochement stable, insensible aux variantes de libellé |
| `devise` | char(3) | NN, CK: format ISO | Un budget de 400 000 ne veut rien dire hors devise. Rattachée au pays, elle suit le bien et le mandat |
| `ville` | varchar(120) | NN | Commune |
| `code_insee` | char(5) | CK: NN si France | Obligatoire pour les villes françaises, nul ailleurs |
| `secteur` | varchar(120) | CK: cohérent avec type_zone (C10) | Quartier. Nul sur les lignes de type `ville` |
| `code_postal` | varchar(10) | CK: format FR si France | Contrôle de format — action corrective A07, absente du SI hérité |

Contrainte structurante : `UNIQUE NULLS NOT DISTINCT (pays, ville, secteur)` (C11). **Conséquence à assumer** : l'égalité `(pays, ville)` remplace une clé étrangère hiérarchique — la normalisation des libellés à l'import devient critique (« Montpellier » ≠ « montpellier »). L'unicité bloque le doublon exact, pas le doublon orthographique. Voir aussi la dénormalisation assumée n°6 (§5.1).

## 2.7 DEMANDE

La recherche, du lead brut à sa clôture. Porte les horodatages du cycle de vie sans lesquels aucun KPI de délai n'existe (doctrine §1.2, voie 1).

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_demande` | entier | PK | Identifiant de la recherche |
| `id_gestionnaire` | entier | FK→gestionnaire *(dénorm.)* | Liste de travail permanente ; maintenue par déclencheur depuis `affectation` (§5.1) |
| `id_chasseur` | entier | FK→chasseur *(dénorm.)* | Idem |
| `date_depot` | timestamp | NN | Origine de tous les délais du parcours |
| `canal` | varchar(30) | NN, CK: liste | Site web, parrainage, téléphone. Le taux de transformation varie fortement selon l'origine |
| `description_initiale` | texte | — | Verbatim du client, non structuré. Matière première de la qualification |
| `statut` | varchar(30) | NN, CK: liste | État métier suivi par le gestionnaire. Partiellement dérivable, mais porte `sans_suite` et `close` qu'aucune association n'exprime |
| `date_consentement` | timestamp | CK: NN si canal web (C14/T14) | Consentement RGPD au traitement du lead. Propre à la demande : un même particulier peut en déposer plusieurs |
| `date_affectation` | timestamp | — | **Le KPI n°1 du gestionnaire** : sans cette date, le délai de prise en charge est incalculable |
| `date_qualification` | timestamp | — | Sépare le temps gestionnaire du temps chasseur |
| `date_cloture` | timestamp | — | Durée de cycle complète, dénominateur de tous les taux |
| `motif_sans_suite` | varchar(40) | CK: NN si statut sans_suite | Budget irréaliste, injoignable, hors zone… Les leads perdus sont plus instructifs que les gagnés |
| `nb_relances` | smallint | NN, D: 0 | Effort investi avant abandon : distingue le lead mort du lead sous-travaillé |
| `statut_financement` | varchar(30) | CK: liste | Variable de contrôle sans laquelle le taux de transformation est illisible |
| `apport_disponible` | numeric(12,2) | CK: ≥ 0 | Détermine le budget réel, souvent éloigné du budget déclaré |
| `montant_pret_envisage` | numeric(12,2) | CK: ≥ 0 | Complète l'apport pour la faisabilité |
| `date_accord_principe` | date | — | Point de bascule du lead qualifiable |
| `date_validite_accord` | date | CK: ≥ accord | **Un accord de principe expire** : un mandat qui court au-delà travaille sur un budget qui n'existe plus |

> Le financement appartient au **projet**, pas à la personne : le même client peut avoir un accord sur une recherche et rien sur une autre. D'où son rattachement à DEMANDE.

## 2.8 DEMANDE_ACQUEREUR *(table de jonction, association A4)*

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_demande` | entier | PK (composée), FK→demande | — |
| `# id_client` | entier | PK (composée), FK→client | — |
| `qualite` | varchar(20) | NN, CK: principal \| co_acquereur | Exactement un `principal` par demande (C4). Le couple acquéreur est le cas majoritaire — c'est lui qui justifie la n-n |

## 2.9 AFFECTATION

Réification de l'affectation (doctrine §1.2, voie 2). **Cinq KPI gestionnaire sur six en dépendent** : sans elle, une réaffectation efface le travail du premier gestionnaire.

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_affectation` | entier | PK | Clé technique (ADR-015) ; clé naturelle maintenue en alternative |
| `id_demande` | entier | NN, FK→demande, U(id_demande, date_debut) | Rattachement + clé alternative préservant l'identification relative |
| `id_gestionnaire` | entier | NN, FK→gestionnaire | Pilote |
| `id_chasseur` | entier | FK→chasseur | NULL tant que non confiée à un chasseur |
| `date_debut` **R** | timestamp | NN | Identifiant relatif d'origine |
| `date_fin` | timestamp | CK: ≥ début ; au plus une ligne ouverte par demande (C6) | Affectation en cours si nulle. Reconstitue la charge à toute date passée |
| `motif` | varchar(60) | NN, CK: liste | Initiale, surcharge, absence, désaccord client. Le taux de réaffectation est un signal managérial |

## 2.10 DEMANDE_VERSION

Historisation des critères V1 → V2 → V3, sans écrasement (exigence Readme Phase 2).

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_version` | entier | PK | Clé technique (ADR-015) |
| `id_demande` | entier | NN, FK→demande, U(id_demande, no_version), U(id_demande, id_version) | 1re unicité : préserve l'identification relative. 2e : cible des FK composées de mandat et proposition (ADR-016) |
| `id_modifie_par` | entier | NN, FK→utilisateur | Auteur de l'évolution (client ou chasseur) |
| `no_version` **R** | smallint | NN, CK: > 0 | Il n'existe pas de « version 2 » dans l'absolu, seulement la version 2 de la recherche n°417 |
| `date_creation` | timestamp | NN | Base du KPI de dérive du besoin |
| `motif_evolution` | varchar(255) | NN | Raison de l'ajustement : alimente l'analyse des concessions d'acquéreurs |
| `type_bien` | varchar(30) | NN, CK: liste | Typologie recherchée |
| `destination` | varchar(30) | NN, CK: principale \| secondaire \| locatif | **Le plus discriminant** : explique pourquoi deux clients au même budget refusent des biens opposés. `revente` retirée (activité professionnelle, ADR-018) |
| `budget_max` | numeric(12,2) | NN, CK: > 0 | L'écart V1 → version courante mesure la concession budgétaire |
| `surface_min` | smallint | CK: > 0 | Critère éliminatoire |
| `nb_pieces_min` / `nb_chambres_min` | smallint | CK: ≥ 0 | Critères éliminatoires de distribution |
| `nb_occupants` | smallint | CK: > 0 | Le besoin réel derrière le nombre de chambres |
| `dpe_max` | char(1) | CK: A–G | Contraintes locatives croissantes sur les passoires thermiques |
| `rendement_brut_min` | numeric(5,2) | CK: NN seulement si destination = locatif (T15) | Critère de l'investisseur particulier |
| `travaux_acceptes` | booléen | NN, D: faux | Sépare le clé-en-main de l'acheteur à potentiel |
| `exige_ascenseur` … `exige_cave` | booléen ×6 | NN, D: faux | Six critères d'équipement symétriques des `a_*` du bien. Rédhibitoires par construction |
| `commentaire_criteres` | texte | — | Préférences non modélisées, hors matching. Note unique, atomique au sens 1FN |
| `est_courante` | booléen | NN ; une seule vraie par demande *(dénorm.)* | Requêtée à chaque cycle de matching ; bascule automatique par déclencheur (§5.1) |

## 2.11 VERSION_ZONE *(jonction, A10)* et 2.12 CHASSEUR_ZONE *(jonction, A2)*

| Table | Attributs | Contraintes | Justification |
|---|---|---|---|
| `version_zone` | `# id_version`, `# id_zone` | PK composée, FK des deux côtés | Zones ciblées par une version de critères |
| `chasseur_zone` | `# id_utilisateur`, `# id_zone`, `role_intervention` | PK composée, FK, role NN CK: liste | Territorialité du chasseur, avec rôle (principal/secondaire) |
## 2.13 MANDAT

Le contrat (loi Hoguet).

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_mandat` | entier | PK | Identifiant du contrat |
| `id_demande` | entier | NN, FK→demande ; au plus un mandat actif par demande (C7) | Demande contractualisée |
| `id_version_contractuelle` | entier | NN, FK composée (id_demande, id_version)→demande_version | Fige le périmètre d'origine, opposable en litige. Les versions postérieures valent avenant tacite ; le matching s'exécute sur la version courante |
| `id_chasseur` | entier | NN, FK→chasseur | Mandataire désigné explicitement, figé à la signature (l'affectation étant réversible, on ne peut pas le déduire) |
| `id_signataire` | entier | NN, FK composée (id_demande, id_signataire)→demande_acquereur | **Le signataire est un acquéreur de la demande** (C5) — contrainte déclarative depuis ADR-019 |
| `numero_registre` | varchar(30) | U, NN | Numéro d'ordre au registre des mandats. Obligation légale, sans rupture de séquence |
| `date_signature` | date | NN | Date de l'engagement |
| `mode_signature` | varchar(20) | NN, CK: presentiel \| en_ligne | Conditionne le régime de preuve |
| `date_debut` | date | NN, CK: ≥ signature (T7) | **Prise d'effet ≠ signature** : 14 jours de rétractation en démarchage à domicile (clientèle 100 % consommateurs). **Seule donnée temporelle stockée** (ADR-030) |
| `id_mandat_precedent` | entier | FK→mandat | Filiation de renouvellement : le renouvellement crée un **nouveau** mandat (nouveau numéro de registre) relié au précédent. NULL pour un mandat initial |
| `exclusif` | booléen | NN | Exclusif ou simple. Conditionne le taux et les obligations réciproques |
| `statut` | varchar(20) | NN, CK: actif \| renouvele \| resilie \| clos_succes | **`expire` retiré des valeurs saisissables (ADR-023)** : l'expiration se lit par les dates via la vue `v_mandat`, un statut ne peut plus contredire les dates |
| `taux_honoraires` | numeric(5,2) | CK: 0–100 ; taux ou forfait requis (T6) | Figé à la signature : survit à toute évolution du taux du chasseur |
| `base_honoraires` | varchar(4) | NN, CK: HT \| TTC | Un particulier raisonne TTC ; la mention explicite évite le contentieux |
| `taux_tva` | numeric(5,2) | NN, CK: 0–100 | Figé au contrat : taux du jour de signature |
| `forfait_honoraires` | numeric(12,2) | CK: ≥ 0 ; taux ou forfait requis | Rémunération forfaitaire alternative ou complémentaire |
| `qualite_signataire` | varchar(60) | NN, CK: nom_propre \| procuration | Cas réel entre particuliers (conjoint absent, expatriation) |
| `reference_procuration` | varchar(255) | CK: NN si procuration (T8) | Référence du document |
| `date_resiliation` | date | CK: NN si statut resilie | Un statut `resilie` sans date n'est pas opposable |
| `motif_resiliation` | texte | CK: NN si statut resilie | Exigé par la tenue du registre |

## 2.14 BIEN

Le bien physique, distinct de ses publications.

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_bien` | entier | PK | Identifiant du bien réel |
| `id_zone` | entier | NN, FK→zone | Localisation (référentiel) |
| `type_bien` | varchar(30) | NN, CK: liste | Apparié au critère de la version |
| `surface` | numeric(8,2) | CK: > 0 | Surface habitable consolidée entre sources |
| `nb_pieces` / `nb_chambres` | smallint | CK: ≥ 0 | Critères d'appariement directs |
| `etage` | smallint | — | Combiné à `a_ascenseur`, critère éliminatoire fréquent |
| `dpe` | char(1) | CK: A–G (domaine d_dpe, T11) | Diagnostic énergétique |
| `adresse_indicative` | varchar(255) | — | Rue ou secteur : l'adresse exacte n'est pas publiée par les portails |
| `code_postal` | varchar(10) | — | Conservé tel que capté par le scraper |
| `a_ascenseur` … `a_cave` | booléen ×6 | *nullable volontaire* | **NULL = « non renseigné par la source »**, distinct de FALSE : sans cette nuance, tout bien scrapé sans mention d'ascenseur serait écarté et le matching se viderait |

## 2.15 ANNONCE

La publication d'un bien sur une source. Un appartement publié sur deux portails = deux annonces, un seul bien.

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_annonce` | entier | PK | Identifiant de la publication |
| `id_bien` | entier | NN, FK→bien, U(id_bien, id_annonce) | Clé alternative : cible de la FK composée de proposition (T10) |
| `source` | varchar(40) | NN, U(source, reference_source) | Sans elle, le dédoublonnage ne fonctionne pas |
| `reference_source` | varchar(60) | NN | Identifiant chez la plateforme d'origine. NN car `NULL ≠ NULL` neutraliserait l'unicité |
| `titre` / `description` | varchar(255) / texte | — | Contenu éditorial, variable selon la source |
| `prix` | numeric(12,2) | NN, CK: > 0 | **Appartient à l'annonce, pas au bien** : deux portails affichent souvent deux prix |
| `url` | texte | — | Lien présenté au client |
| `date_publication` | timestamp | — | Ancienneté sur le marché : un bien qui stagne est négociable |
| `date_ingestion` | timestamp | NN | Première capture par le scraper. Colonne de partitionnement future |
| `date_derniere_vue` | timestamp | NN | Mise à jour à chaque passage : sans elle, impossible de détecter un retrait |
| `statut` | varchar(20) | NN, CK: active \| retiree \| vendue | **Proposer un bien vendu est la faute la plus visible pour un client** |

## 2.16 PROPOSITION

Le bien tel que soumis au client. Trois dates, non une seule.

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_proposition` | entier | PK | Identifiant |
| `id_demande` | entier | NN, FK *(dénorm.)*, U(id_demande, id_bien) | Dénormalisation **indispensable** : rend C8 (« un bien proposé une seule fois par recherche, toutes versions confondues ») déclarative |
| `id_version` | entier | NN, FK composée (id_demande, id_version)→demande_version | Garde-fou de la dénormalisation : la version appartient bien à la demande |
| `id_bien` | entier | NN, FK→bien | Le bien proposé — sur le **bien**, pas l'annonce : dédoublonnage structurel |
| `id_annonce_reference` | entier | FK composée (id_bien, id_annonce_reference)→annonce | L'annonce de référence appartient au bien proposé (T10) |
| `date_matching` | timestamp | NN | Détection algorithmique |
| `date_soumission_client` | timestamp | — | **Réactivité du chasseur** : délai détection → présentation |
| `date_reponse_client` | timestamp | — | **Réactivité du client**, taux de réponse |
| `score_matching` | numeric(5,2) | CK: 0–100 | Sa corrélation au taux d'acceptation mesure la qualité de l'algorithme |
| `statut` | varchar(30) | NN, CK: liste (a_qualifier, soumis, retenu_visite, refuse_client, ecarte_chasseur) | Cycle de vie de la proposition |
| `motif_rejet` | texte | CK: NN si refuse_client (T13) | Le refus client est toujours motivé : donnée d'apprentissage la plus riche du système |

## 2.17 COMMENTAIRE

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_commentaire` | entier | PK | Identifiant de la note |
| `id_auteur` | entier | NN, FK→utilisateur | Auteur |
| `id_demande` | entier | FK→demande ; exactement une cible (C2) | Rattachement à une recherche |
| `id_proposition` | entier | FK→proposition ; exactement une cible (C2) | Ou à une proposition — jamais les deux (`num_nonnulls = 1`) |
| `type_contexte` | varchar(30) | NN, CK: liste | Note de recherche, débrief de visite, analyse d'annonce |
| `est_prive` | booléen | NN, D: faux ; **RG-01 : jamais vrai si auteur client** (ADR-027) | Vrai = note interne, invisible du client — condition de la franchise des débriefs. RLS via `app.user_id` en complément du contrôle applicatif (§6.7) |
| `contenu` | texte | NN | Corps de la note |
| `date_creation` | timestamp | NN, D: now() | Reconstitution chronologique du dossier |

## 2.18 VISITE *(réintégrée v6, ADR-024)*

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_visite` | entier | PK | — |
| `id_proposition` | entier | NN, FK→proposition | Une visite découle d'une proposition (A26) |
| `id_visiteur` | entier | NN, FK→utilisateur | Participant (A27) — client ou chasseur *(déduit du MLD v6)* |
| `date_visite` | date | NN | Support du statut `retenu_visite` de PROPOSITION, jusqu'ici sans objet |
| `realisee` | booléen | NN | Une visite programmée puis annulée est une information : fiabilité du client et du vendeur |
| `motif_annulation` | texte | CK: NN si non réalisée (C17) | Obligatoire si annulée |

## 2.19 OFFRE_ACQUISITION *(réintégrée v6)*

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_offre` | entier | PK | — |
| `id_proposition` | entier | NN, FK→proposition ; **au plus une offre acceptée par proposition** (C13, index unique partiel) | Une offre porte sur une proposition (A28) |
| `id_offre_precedente` | entier | FK→offre_acquisition | Auto-association SUCCÈDE À (A29) : la chaîne des contre-offres porte l'écart de négociation, indicateur de valeur du chasseur |
| `camp` | varchar(20) | NN, CK: acquereur \| vendeur | Une contre-offre vient de l'autre côté |
| `saisi_par` | varchar(20) | NN, CK: chasseur \| gestionnaire \| client | Trace de responsabilité sur un acte engageant |
| `origine_decouverte` | varchar(20) | CK: chasseur \| client \| tiers | **Détermine si les honoraires sont dus** : un bien trouvé par le client seul peut échapper au mandat (non exclusif) |
| `montant` | numeric(12,2) | NN, CK: > 0 | Strictement positif |
| `date_signature` | date | NN | — |
| `date_transmission` | date | CK: ≥ signature *(déduit)* | — |
| `date_validite` | date | NN | **Une offre a une durée de validité** : sans elle, on ne sait pas si elle est opposable |
| `statut` | varchar(20) | NN, CK: en_cours \| acceptee \| refusee \| caduque \| retiree | — |
| `date_reponse` | date | CK: NN si statut ≠ en_cours (C14) | Une offre tranchée porte sa date de réponse |

## 2.20 COMPROMIS *(réintégré v6)*

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_compromis` | entier | PK | — |
| `id_offre` | entier | NN, **U**, FK→offre_acquisition | Une offre donne au plus un compromis (A30) |
| `id_notaire` | entier | NN, FK→notaire | Instrumenté par un notaire (A31) |
| `date_signature` | date | NN | — |
| `fin_retractation` | date | NN, CK: ≥ signature *(déduit)* | Les 10 jours du code de la construction : un compromis en rétractation n'est pas acquis |
| `depot_garantie` | numeric(12,2) | CK: ≥ 0 | Montant séquestré |
| `sequestre` | texte | — | Dépositaire du séquestre |
| `date_acte_prevue` | date | — | Écart prévu/réalisé : fiabilité du tunnel |
| `statut` | varchar(20) | NN, CK: signe \| caduc \| realise | — |
| `motif_caducite` | varchar(30) | CK: NN si caduc (C15) | Les échecs sont plus instructifs que les succès |

## 2.21 CLAUSE_SUSPENSIVE *(réintégrée v6)*

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_clause` | entier | PK | — |
| `id_compromis` | entier | NN, FK→compromis | Portée par un compromis (A32) |
| `type_clause` | varchar(30) | NN, CK: financement \| urbanisme \| servitude \| vente_prealable | La clause de financement non levée est la 1re cause de caducité : sans elle, le taux d'échec n'est pas analysable |
| `description` | texte | — | — |
| `date_butoir` | date | NN | Échéance de levée |
| `statut` | varchar(20) | NN, CK: en_attente \| levee \| non_levee *(déduit)* | — |

## 2.22 ACTE *(réintégré v6)*

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_acte` | entier | PK | — |
| `id_compromis` | entier | NN, **U**, FK→compromis | Un compromis donne au plus un acte (A33) |
| `date_signature` | date | NN | **Fait générateur des honoraires** |
| `montant_vente` | numeric(12,2) | NN, CK: > 0 | Prix réellement payé : l'écart au prix affiché mesure la négociation |
| `honoraires_fixe` | numeric(12,2) | CK: ≥ 0 ; au moins un des deux modes (C16) | — |
| `honoraires_taux` | numeric(5,2) | CK: 0–100 ; au moins un des deux modes | — |

> **`honoraires_total` volontairement absent** : déductible de `fixe + taux × montant_vente`. Le stocker serait la même faute que `mandats.statut` du SI hérité (donnée calculable matérialisée sans garde-fou). Exposé par la vue `v_honoraires` (§6.6).

## 2.23 NOTAIRE *(réintégré v6)*

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_notaire` | entier | PK | — |
| `nom` | varchar(80) | NN, U(nom, etude) | — |
| `etude` | varchar(120) | NN | — |
| `email` / `telephone` | varchar(255) / varchar(20) | CK: formats | Coordonnées de l'étude |

## 2.24 INDICATEUR

Référentiel des KPI suivis. Contient la **définition**, jamais la valeur.

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# code_indicateur` | varchar(40) | PK | Code stable, ex. `delai_affectation_moyen` |
| `libelle` | varchar(160) | NN | Intitulé des tableaux de bord |
| `unite` | varchar(20) | NN | Heures, %, euros, nombre : une valeur nue est ininterprétable |
| `perimetre_role` | varchar(20) | NN, CK: chasseur \| gestionnaire \| client | Un indicateur n'a pas de sens hors de son périmètre |
| `sens_optimal` | varchar(10) | NN, CK: croissant \| decroissant | Un délai bas est bon, un taux haut aussi : la machine ne le devine pas |
| `mode_calcul` | texte | NN | Formule documentée : rend le chiffre auditable et opposable |

> **Ajouter un indicateur est une insertion de données, jamais une évolution de schéma** — l'inverse de colonnes `nb_leads_traites` sur l'acteur.

## 2.25 PERIODE

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_periode` | entier | PK | — |
| `type_periode` | varchar(20) | NN, CK: mois \| trimestre \| annee | Un même indicateur se gèle à plusieurs mailles |
| `date_debut` / `date_fin` | date | NN, CK: fin ≥ début | Bornes explicites : évite l'ambiguïté des périodes glissantes |

## 2.26 OBSERVATION *(ternaire A24)* et 2.27 OBJECTIF *(ternaire A25)*

| Table | Attributs | Contraintes | Justification |
|---|---|---|---|
| `observation` | `# id_utilisateur`, `# code_indicateur`, `# id_periode`, `valeur`, `date_calcul` | PK ternaire, 3 FK, valeur NN, date_calcul NN ; **période close à la date de calcul** (C9, déclencheur) | Fait daté et figé : « le 3/09, on a mesuré que Durand affichait 4,2 h de délai moyen sur août ». Non recalculable à l'identique — **sert de base à la rémunération variable** (source de vérité, ADR-025) |
| `objectif` | `# id_utilisateur`, `# code_indicateur`, `# id_periode`, `valeur_cible`, `date_fixation` | PK ternaire, 3 FK, NN | Un objectif se fixe *avant* la période, une mesure se calcule *après* : les fusionner produirait des occurrences à moitié vides |

## 2.28 REMUNERATION_CHASSEUR *(nouveau v7, ADR-029)*

Gel de la part revenant au chasseur sur une vente, figée au moment de l'acte. Même doctrine que `observation` : un fait daté, non recalculé si le barème change ensuite.

| Attribut | Type | Contraintes | Justification |
|---|---|---|---|
| `# id_remuneration` | entier | PK | Identifiant technique |
| `id_acte` | entier | NN, FK→acte, U(id_acte, id_chasseur) | **Fait générateur** : la part se calcule à la signature de l'acte |
| `id_chasseur` | entier | NN, FK→chasseur | Bénéficiaire de la part |
| `montant_part` | numeric(12,2) | NN, CK: ≥ 0 | La part figée, en euros. Non recalculable à l'identique si la grille évolue |
| `date_calcul` | timestamp | NN, D: now() | Horodate le gel |
| `reference_bareme` | texte | — | Trace de la règle appliquée (ex. « grille 2026-S1, ancienneté > 2 ans »). La **règle exacte de calcul** est à obtenir du PO ; tant qu'elle est inconnue, elle n'est pas structurée en dur — on gèle le résultat sans présumer de la formule (point ouvert n°1) |

> **Ce qui n'est PAS modélisé, volontairement** : la grille de barème par tranches elle-même. C'est du **calcul** (paramètre), pas un fait à figer dans le socle transactionnel tant que sa forme n'est pas arrêtée. Quand le PO livrera la règle, `reference_bareme` pourra devenir une FK vers une table de barèmes, ou rester une trace — décision différée sans dette structurelle.
