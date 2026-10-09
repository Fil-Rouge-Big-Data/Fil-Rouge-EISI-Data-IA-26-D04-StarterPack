# Mapping des données — Existant → OLTP cible v8

**Projet :** Service de chasse immobilière — refonte du SI
**Source :** `fixtures/PgSQL.sql`, schéma `Fil_Rouge_Depart` (3 tables)
**Cible :** MPD v7 — `01_ddl.sql` + `02_triggers_vues.sql`, schéma `public`
**Date de référence projet :** 25 juillet 2026
**Statut :** proposé — à valider avant implémentation

> ⚠️ Entreprise, données et personnages fictifs. Note de travail destinée au Dossier Professionnel et à la soutenance.

---

## 0. Deltas v8 (par rapport au mapping v7 ci-dessous)

La logique de fond du mapping (pipeline E-T-L-V, UUID déterministe, arbitrages
A1–A11, D-FLAG, gestionnaire root) **reste valable en v8**. Les évolutions de
schéma v8 modifient le chargement sur quelques points, sans changer les
volumétries migrées :

| Table cible | Changement v8 | Effet sur la migration |
|---|---|---|
| `mandat` | `id_demande_signataire` supprimé (E5-m4) | retiré du `load` ; la FK signataire passe par `id_demande` |
| `mandat` | gel carte T à la signature (A8) | `numero_carte_t_signature` / `validite_carte_t_signature` = sentinelles du chasseur (cohérent D-FLAG) |
| `mandat` | `date_debut = date_signature` (A12) | déjà le cas en migration (source n'a qu'une date) |
| `client` | `frais_dossier_offerts` (E7) ; parrain supprimé | défaut `false` ; aucun parrainage en source |
| `zone` | `ville`/`secteur` en `citext` (E2) | transparent (les valeurs source passent) |
| `v_conformite_chasseur` | `est_a_regulariser` + validité gelée (A8/D-FLAG) | porté par le DDL v8 ; plus d'extension séparée |
| 7 tables nouvelles | rémunération, note_avis, documents | **vides** à la migration (aucune source) |

Les anomalies tracées, les volumétries (25 utilisateurs, 18 mandats…) et les
statuts recalculés sont **identiques à v7** : voir `rapport-migration.md`.

---

## 1. Objet et méthode de lecture

Ce document est le **pivot de la migration** : il fixe, colonne par colonne, comment chaque donnée de l'existant devient une donnée de la cible v7, et **quelle décision** comble les colonnes cible sans source. Il est la spécification que le code d'implémentation doit suivre à la lettre — et le document que le jury peut confronter au DDL.

**Conventions.**

- **Source → Cible** : une donnée reprise telle quelle (éventuellement typée/normalisée).
- **Comblé** : colonne cible NOT NULL ou signifiante, sans équivalent source → une valeur de remplissage est décidée ici.
- **Calculé** : la valeur cible est dérivée (jamais recopiée d'un champ source trompeur).
- **Reconstruit** : l'entité cible n'existe pas en source ; elle est fabriquée à partir d'une entité source (ex. un mandat source engendre une demande).
- **Écarté** : donnée source non reprise (avec motif), tracée au rapport « zéro déperdition ».
- **Codes anomalies (Axx)** : repris du registre d'audit du projet.

**Volumétrie source de référence** (annotée dans le fichier source, au 25/07/2026) : 6 chasseurs + 18 clients = 24 utilisateurs ; 18 mandats (11 actif, 3 termine, 2 expire, 2 suspendu) ; 10 secteurs.

---

## 2. Périmètre : ce qui est peuplé, ce qui reste vide

La cible v7 compte 28 tables ; la source n'en alimente qu'une fraction. Il faut l'assumer explicitement.

### 2.1 Tables peuplées par la migration

`utilisateur`, `client`, `chasseur`, `zone`, `demande`, `demande_acquereur`, `demande_version`, `version_zone`, `mandat`.

### 2.2 Tables reconstruites (fabriquées, pas copiées)

`demande`, `demande_acquereur`, `demande_version`, `version_zone` — aucune n'existe en source ; toutes sont dérivées des 18 mandats et de leur `description_recherche`.

### 2.3 Tables laissées vides (aucune source, et c'est correct)

`affectation`, `chasseur_zone`, `indisponibilite`, `bien`, `annonce`, `proposition`, `commentaire`, `visite`, `offre_acquisition`, `notaire`, `compromis`, `clause_suspensive`, `acte`, `remuneration_chasseur`, `indicateur`, `periode`, `observation`, `objectif`.

> **`gestionnaire` n'est plus vide (A1 v2)** : elle contient la ligne technique `SYS-MIGRATION` (voir §2.4). Les autres tables ci-dessus restent vides faute de source.

> **`chasseur_zone` et `affectation` — pourquoi vides.** `chasseur_zone` : voir arbitrage A11 (aucune source fiable pour la zone d'intervention déclarée). `affectation` : la relation chasseur↔demande est portée directement par `demande.id_chasseur` (dénormalisation renseignée à la migration) ; reconstituer un historique d'affectations que la source ne contient pas serait une invention. La table reste disponible pour l'usage applicatif futur.

### 2.4 Acteur technique créé par la migration

Un `utilisateur` + un `gestionnaire` techniques `SYS-MIGRATION` (D-ROOT) sont créés pour porter l'origine des demandes migrées. `actif=false`, exclu des statistiques. Détail en arbitrage D-ROOT.

> **Décision A1 (v2) — gestionnaire root de migration.** Les demandes reconstruites sont portées par un **gestionnaire technique `SYS-MIGRATION`** (system account : un `utilisateur` + un `gestionnaire`, `actif=false`, créés par la migration), et non laissées à `id_gestionnaire = NULL`. Motif : ne pas rendre l'aval (Power BI, KPI, migrations récurrentes) aveugle sur l'origine des données. Ce compte est exclu des statistiques opérationnelles (filtre `matricule='SYS-MIGRATION'`). Voir arbitrage A1 / D-ROOT. `gestionnaire` n'est donc **pas** une table vide : elle contient la seule ligne technique `SYS-MIGRATION`.

---

## 3. Décisions de comblement transverses

Trois décisions s'appliquent à plusieurs tables. Elles sont posées ici une fois.

### D1 — Génération des UUID (déterministe depuis clé naturelle)

La cible est en UUID (ADR-028), la source en entiers `IDENTITY`. Chaque UUID cible est dérivé de façon **déterministe et stable** d'une clé naturelle source, via UUIDv5 (namespace dédié + clé). Conséquence : rejouer la migration produit les **mêmes** UUID → idempotence, `ON CONFLICT DO NOTHING` fiable, et absence de collision lors des rachats futurs (chaque source a son propre espace de clés naturelles).

| Entité cible | Clé naturelle source retenue |
|---|---|
| `utilisateur` | `email` (UNIQUE en source comme en cible) |
| `zone` | `(pays, ville, secteur)` normalisé (= `uk_zone_geo`) |
| `demande`, `demande_version`, `mandat` | `mandats.id` source (préfixé par type pour éviter la collision entre les trois) |

> **Nuance à défendre.** L'UUIDv5 (déterministe) est retenu **pour la migration** afin de garantir la reproductibilité. Il n'entre pas en conflit avec le `DEFAULT gen_random_uuid()` (UUIDv4) du DDL : le `DEFAULT` ne s'applique qu'aux lignes créées **sans** UUID fourni (usage applicatif futur) ; la migration, elle, **fournit** l'UUID. Les deux coexistent sans contradiction.

### D2 — Mots de passe absents (RGPD)

`utilisateur.password_hash` est NOT NULL, sans source. Valeur de comblement : une **sentinelle non-authentifiable** (ex. `'!migrated:no-auth'`, qui ne peut correspondre à aucun hash valide), imposant un **reset au premier login**. Aucun mot de passe n'est inventé. *À tracer au registre RGPD : compte migré = identifiant sans secret, à ré-enrôler.*

### D3 — Données légales du chasseur absentes (9 colonnes NOT NULL)

C'est le comblement le plus lourd. `chasseur` exige 9 colonnes NOT NULL qu'aucune donnée source ne porte : `numero_carte_t`, `date_validite_carte_t`, `prefecture_delivrance`, `organisme_garant`, `montant_garantie_financiere`, `numero_rcp`, `date_echeance_rcp`, `statut_juridique`, `date_entree_reseau`, `capacite_max_mandats`.

**Décision (à valider par le métier).** Migrer avec des **valeurs sentinelles explicitement marquées « à régulariser »**, plutôt que d'exclure les chasseurs (ce qui casserait les FK des mandats). Détail au §5.3. **Alternative** : exclure les chasseurs non conformes — rejetée car elle rendrait 18 mandats orphelins. *Ce point doit être arbitré avec le métier avant production : ce sont des mentions légales obligatoires (carte T, RCP, garantie financière) ; les sentinelles sont un état transitoire de migration, pas un état acceptable en exploitation.*

---

## 4. Mapping table par table — Acteurs et géographie

### 4.1 `secteurs` (source) → `zone` (cible)

10 secteurs source → 10 zones. La cible unifie ville et secteur dans une seule table (`type_zone`), avec contrainte C10 : `type_zone='ville'` ⇒ `secteur IS NULL` ; `type_zone='secteur'` ⇒ `secteur IS NOT NULL`.

| Cible `zone` | Origine | Règle |
|---|---|---|
| `id_zone` | Comblé (D1) | UUIDv5 de `(pays, ville, secteur)` |
| `type_zone` | **Calculé** | `'secteur'` si `quartier` non NULL, sinon `'ville'` |
| `pays` | Comblé | `'France'` (les 10 secteurs sont français) |
| `code_iso_pays` | Comblé | `'FR'` — **2 lettres** (⚠ le code repo utilisait `FRA`, invalide ici : `char(2)`) |
| `devise` | Comblé | `'EUR'` (3 lettres, conforme `char(3)`) |
| `ville` | `secteurs.ville` | Repris tel quel (NOT NULL cible ✓ NOT NULL source) |
| `code_insee` | Comblé (référentiel externe) | Depuis le référentiel COG INSEE (déjà constitué à l'audit). NOT NULL requis pour FR par `ck_zone_insee_fr` |
| `secteur` | `secteurs.quartier` | Repris ; NULL si ville pure (respecte C10) |
| `code_postal` | `secteurs.code_postal` | Repris tel quel |

**Cas concrets.** Castelnau-le-Lez (34170) et Lattes (34970) ont `quartier = NULL` → `type_zone='ville'`, `secteur=NULL`. Les 8 autres → `type_zone='secteur'`.

> **Attention unicité `uk_zone_geo (pays, ville, secteur)` avec `NULLS NOT DISTINCT`.** Deux villes pures homonymes sans secteur entreraient en collision. Ici les 10 secteurs sont distincts sur `(ville, secteur)` → pas de collision. Le code de transformation devra néanmoins dédoublonner défensivement (une même ville peut apparaître plusieurs fois : Montpellier a 4 secteurs → 4 zones distinctes de type secteur, jamais de doublon car `secteur` diffère).

**`code_insee` — apport externe assumé.** L'existant ne porte aucun code commune. Les codes INSEE proviennent du référentiel constitué à l'audit (`CODES_INSEE`), et non des données : c'est un enrichissement tracé (A07), pas une reprise. Toute commune absente du référentiel doit faire **échouer** la transformation (erreur explicite), jamais produire un INSEE inventé.

### 4.2 `utilisateurs` (source, role='chasseur') → `utilisateur` + `chasseur`

6 chasseurs. Le tronc commun va dans `utilisateur`, les attributs métier dans `chasseur`.

**Vers `utilisateur` :**

| Cible | Origine | Règle |
|---|---|---|
| `id_utilisateur` | Comblé (D1) | UUIDv5 de `email` |
| `nom`, `prenom` | Repris | NOT NULL ✓ ; CHECK `length ≤ 80` respecté (source VARCHAR(80)) |
| `email` | Repris | Domaine `d_email` — les emails source `x@y.z` respectent le motif |
| `telephone` | Repris | Domaine `d_tel` `^\+?[0-9 .\-]{6,20}$` — les numéros source `06xxxxxxxx` (10 chiffres) passent |
| `password_hash` | Comblé (D2) | Sentinelle non-authentifiable |
| `date_creation` | `date_creation` source | DATE source → timestamptz cible (minuit) |
| `actif` | Comblé | `true` (chasseurs en activité) |
| `date_anonymisation` | — | NULL (contrainte C12 : NULL autorisé si actif) |

**Vers `chasseur` :** voir §5.3 (comblement D3) pour les 9 colonnes légales. Colonnes avec source :

| Cible | Origine | Règle |
|---|---|---|
| `id_utilisateur` | = UUID de l'utilisateur | FK vers `utilisateur` |
| `date_entree_reseau` | `date_creation` source | Interprétée comme entrée dans le réseau |
| `taux_honoraires_defaut` | `taux_commission` source | `NUMERIC(4,2)` source → `d_taux numeric(5,2)` cible ; valeurs 2.00–3.25 ✓ (BETWEEN 0 AND 100) |

### 4.3 `utilisateurs` (source, role='client') → `utilisateur` + `client`

18 clients. Tronc commun identique à 4.2 (mêmes règles UUID, email, tel, password, actif).

**Vers `client` :** la table `client` n'a **aucune colonne NOT NULL au-delà de la PK et des booléens à défaut** — le comblement est donc léger.

| Cible `client` | Origine | Règle |
|---|---|---|
| `id_utilisateur` | = UUID utilisateur | FK |
| `primo_accedant` | Comblé | `false` (défaut) — sauf enrichissement depuis `description_recherche` « premier achat » (voir note) |
| `consentement_marketing` | Comblé | `false` (défaut ; aucun consentement en source) — respecte `ck_client_consent_mkg` |
| `niveau_vigilance` | Comblé | `'standard'` (défaut) |
| Toutes autres colonnes | — | NULL (nullable en cible) |

> **`budget_max` source (client) n'est PAS repris sur `client`.** Le budget qualifie la **recherche**, pas la personne : il part vers `demande_version.budget_max` (voir §6.2). C'est une décision d'audit (A03) : `utilisateurs.budget_max` ne sert plus que de **contrôle croisé** avec le budget extrait du texte.

> **Note primo-accédant (optionnelle, à valider).** Une `description_recherche` contient « premier achat » (le mandat de l'utilisateur reclassé en A06, « T2 Figuerolles… premier achat, 40m2 min »). On pourrait en déduire `primo_accedant = true` pour ce client. **Prudence** : c'est une inférence depuis du texte libre, sur un seul cas. Proposition : la faire, mais la **tracer** (A03) comme déduction réversible. À défaut, `false` par défaut est sûr.

### 4.4 `utilisateurs.ville` (résidence) — traitement

`utilisateurs.ville` (résidence de la personne) et `secteurs.ville` (lieu de chasse) sont un **polysème** dans l'existant. La cible v7 **ne porte pas** de FK ville sur `utilisateur`/`client` (pas de colonne `id_zone` sur ces tables). Donc :

- **`utilisateurs.ville` n'est pas migré** vers une FK acteur (la cible ne l'attend pas).
- Il peut alimenter `client.code_postal_residence` **uniquement si** un code postal fiable est dérivable — or la source ne donne qu'un nom de ville, pas de code postal de résidence. → **Écarté** (A10b), tracé : information de résidence non structurée en cible sous cette forme.

> **Écart avec le code repo.** Le repo faisait de `utilisateurs.ville` une FK `id_ville` sur `personne`. La cible v7 n'a pas cette colonne → l'information de résidence individuelle n'a pas de réceptacle direct. C'est un choix de modélisation v7 assumé (la géographie pertinente est celle de la *recherche*, pas de la *résidence*).

---

## 5. Mapping — Chasseur : le comblement légal (D3 détaillé)

### 5.1 Colonnes chasseur avec source

Déjà couvertes en 4.2 : `date_entree_reseau` (← `date_creation`), `taux_honoraires_defaut` (← `taux_commission`).

### 5.2 Colonnes chasseur nullable → NULL

`numero_rsac` (requis seulement si `statut_juridique='agent_commercial'`), `date_sortie_reseau`, `budget_min_intervention`, `budget_max_intervention` → NULL.

### 5.3 Colonnes chasseur NOT NULL sans source → sentinelles « à régulariser »

| Cible | Sentinelle proposée | Respecte |
|---|---|---|
| `numero_carte_t` | `'A-REGULARISER-<uuid court>'` (UNIQUE requis → suffixe unique par chasseur) | UNIQUE ✓ |
| `date_validite_carte_t` | Date sentinelle passée (ex. `2000-01-01`) pour ressortir « expirée » en `v_conformite_chasseur` | signale la non-conformité |
| `prefecture_delivrance` | `'A_REGULARISER'` | — |
| `organisme_garant` | `'A_REGULARISER'` | — |
| `montant_garantie_financiere` | `0.01` (CHECK `> 0` interdit 0) | CHECK `> 0` ✓ |
| `numero_rcp` | `'A_REGULARISER'` | — |
| `date_echeance_rcp` | `2000-01-01` (ressort « expirée ») | signale la non-conformité |
| `statut_juridique` | `'salarie'` (valeur par défaut la plus neutre du CHECK) | CHECK ✓, n'exige pas de RSAC |
| `capacite_max_mandats` | valeur prudente, ex. `15` (CHECK `> 0`) | CHECK `> 0` ✓ |

> **Intelligence du choix.** Les dates sentinelles au `2000-01-01` ne sont pas neutres : elles font **ressortir chaque chasseur comme non conforme** dans la vue `v_conformite_chasseur` (carte T / RCP expirées). La migration produit ainsi elle-même la **liste de régularisation** — la non-conformité est visible, pas masquée. C'est préférable à des dates futures qui feraient croire à une conformité fictive.

> **Remontée active (D-FLAG).** Chaque sentinelle est journalisée dans la table `migration_anomalie` (schéma staging) et ressort dans la colonne calculée `est_a_regulariser` de `v_conformite_chasseur` (étendue). La couche applicative peut lire ce flag et **bloquer** (ex. interdire la signature d'un mandat par un chasseur non régularisé). Voir arbitrage D-FLAG.

> **⚠ Décision métier requise.** `statut_juridique='salarie'` par défaut est un choix de commodité (évite l'exigence de RSAC). S'il s'avère que certains chasseurs sont agents commerciaux, il faudra soit le renseigner, soit fournir un `numero_rsac`. À arbitrer avec le métier — tracé comme point ouvert.

---

## 6. Mapping — Reconstruction demande / version / mandat

Un mandat source engendre **quatre** entités cible : une `demande`, un lien `demande_acquereur`, une `demande_version` (courante), et un `mandat`. Plus les liens `version_zone`. C'est le cœur de la reconstruction.

### 6.1 `mandats` (source) → `demande` (reconstruite)

18 mandats → 18 demandes.

| Cible `demande` | Origine | Règle |
|---|---|---|
| `id_demande` | Comblé (D1) | UUIDv5 de `'demande:' + mandats.id` |
| `id_gestionnaire` | Comblé (A1) | UUID du gestionnaire root `SYS-MIGRATION` (traçabilité d'origine ; exclu des stats) |
| `id_chasseur` | `mandats.chasseur_id` → UUID | Dénormalisation cible (maintenue par trigger applicatif, ici renseignée directement) |
| `date_depot` | `mandats.date_debut` | Le dépôt de la demande est daté à la date de début du mandat (pas d'autre date en source) |
| `canal` | Comblé | **`'autre'`** — voir encadré ci-dessous ⚠ |
| `statut` | Comblé | `'en_recherche'` (un mandat signé implique une recherche active/menée) |
| `nb_relances` | Comblé | `0` (défaut) |
| `date_consentement` | — | NULL — possible **uniquement** parce que `canal <> 'site_web'` |
| autres dates/colonnes | — | NULL (nullable) |

> **⚠ Piège de contrainte C14/T14.** `ck_demande_consent_web` impose : `canal='site_web'` ⇒ `date_consentement NOT NULL`. Or l'existant n'a **aucun consentement**. Si l'on migrait avec `canal='site_web'`, il faudrait inventer une date de consentement — inacceptable (RGPD : on n'invente pas un consentement). **Décision : `canal='autre'`**, qui n'exige pas de consentement et reflète honnêtement que le canal réel est inconnu (mandats papier historiques). Tracé A10b. *Alternative `'parrainage'`/`'telephone'` : rejetées faute de preuve du canal ; `'autre'` est le seul honnête.*

### 6.2 `mandats` (source) → `demande_acquereur` (lien) + correction A06

Chaque demande a exactement **un acquéreur principal** (contrainte C4, trigger différé `tg_demande_acquereur`).

| Cible `demande_acquereur` | Origine | Règle |
|---|---|---|
| `id_demande` | = UUID demande | FK |
| `id_client` | `mandats.client_id` → UUID | Doit être un **client** (FK vers `client`, pas `utilisateur`) |
| `qualite` | Comblé | `'principal'` (un seul acquéreur connu par mandat source) |

> **⚠ Anomalie A06 — mandat id source où `client_id=3`.** L'utilisateur 3 est la chasseuse **Inès Delacroix**, pas un client. Insérer tel quel **violerait la FK** `demande_acquereur.id_client → client` (l'utilisateur 3 n'est pas dans `client`). **Décision d'audit reprise du travail existant** : reclasser vers le client **19 (Nina Girard)** — faisceau d'indices convergents établi à l'audit (budget 220000 = le sien et celui d'aucun autre, seul client sans mandat, même ville que le secteur visé). Tracé A06, **à valider par le métier avant production**. *Sans cette correction, ce mandat est immigrable.*

### 6.3 `mandats.description_recherche` (TEXT libre) → `demande_version`

18 mandats → 18 versions (toutes `no_version=1`, `est_courante=true`). C'est ici qu'intervient le **parsing conservé du code repo**, re-ciblé vers les booléens v7.

| Cible `demande_version` | Origine | Règle |
|---|---|---|
| `id_version` | Comblé (D1) | UUIDv5 de `'version:' + mandats.id` |
| `id_demande` | = UUID demande | FK ; alimente aussi `uk_version_cible (id_demande, id_version)` |
| `id_modifie_par` | `mandats.client_id` → UUID | Le client est réputé rédacteur de la version initiale |
| `no_version` | Comblé | `1` (CHECK `> 0` ✓) |
| `date_creation` | `mandats.date_debut` | timestamptz |
| `motif_evolution` | Comblé | `'Reprise de l''existant (migration)'` (NOT NULL) |
| `type_bien` | **Parsé** | Depuis le texte (« T3 », « Maison », « Loft »…) → CHECK `IN ('appartement','maison','terrain','immeuble','autre')` |
| `destination` | Comblé | `'principale'` (défaut ; aucune source. `ck_version_rendement` : rendement NULL ✓) |
| `budget_max` | **Parsé** | « budget 320000 » → `d_montant` ; CHECK `> 0` ✓. Contrôle croisé avec `utilisateurs.budget_max` (A03) |
| `surface_min` | **Parsé** | « 65m2 min » → smallint ; CHECK `> 0` |
| `nb_pieces_min` | **Parsé** | « T3 » ⇒ 3 ; « 4 pieces » ⇒ 4 |
| `nb_chambres_min` | **Parsé** | « 3 chambres » |
| `dpe_max` | **Parsé** | « DPE C max » → `d_dpe` char(1) A–G |
| `travaux_acceptes` | **Parsé** | « travaux OK » ⇒ true, sinon `false` (défaut) |
| `exige_ascenseur` … `exige_cave` | **Parsé** | Booléens : « balcon », « terrasse », « jardin », « parking », « cave », « ascenseur » ⇒ true si mentionné impératif |
| `est_courante` | Comblé | `true` (unique version) — respecte `ux_version_courante` |
| autres (`nb_occupants`, `rendement_brut_min`, `commentaire_criteres`) | — | NULL |

**Type de bien — mapping du vocabulaire source vers le CHECK cible :**

| Texte source | `type_bien` cible |
|---|---|
| « T2 », « T3 », « T4 », « T5 », « Appartement », « Loft » | `appartement` |
| « Maison », « Villa » | `maison` |
| (aucun terrain/immeuble dans l'échantillon) | — |

> **Perte de finesse assumée (A03).** La source distingue « Loft », « Villa » ; la cible v7 a un domaine fermé (`appartement/maison/terrain/immeuble/autre`). « Loft » → `appartement`, « Villa » → `maison`. Le libellé original n'est pas perdu : il reste dans `criteres_bruts`… **sauf que v7 n'a pas `criteres_bruts`.** Voir encadré ci-dessous. ⚠

> **⚠ Divergence à trancher — `criteres_bruts`.** Le code repo conservait le texte libre intégral dans une colonne `criteres_bruts` (garantie « zéro déperdition »). **La cible v7 n'a pas cette colonne** ; l'équivalent le plus proche est `commentaire_criteres text` (nullable). **Décision proposée** : stocker le `description_recherche` original **intégral** dans `commentaire_criteres`, préservant la traçabilité et le « zéro déperdition ». À valider — c'est la seule colonne v7 capable d'accueillir le texte source brut. Sans elle, tout ce que le parsing n'extrait pas serait perdu sans trace.

### 6.4 `mandats.secteur_id` + quartiers du texte → `version_zone`

La cible relie une version à une ou plusieurs zones via `version_zone (id_version, id_zone)`. La source a un `secteur_id` unique **plus** des quartiers parfois nommés dans le texte (« T3 Ecusson ou Beaux-Arts »).

| Cible `version_zone` | Origine | Règle |
|---|---|---|
| `id_version` | = UUID version | FK |
| `id_zone` | `mandats.secteur_id` → UUID zone + zones des quartiers cités | Union : le secteur déclaré ET tout quartier reconnu dans le texte |

> **Gain de la cible (A03).** L'existant ne portait qu'**un** secteur par mandat ; le texte « Ecusson ou Beaux-Arts » était donc partiellement perdu. `version_zone` étant n-n, on peut relier **plusieurs** zones. Chaque zone additionnelle détectée est tracée (A03).

### 6.5 `mandats` (source) → `mandat` (cible refondu, ADR-030)

Le cœur des pièges de contraintes. 18 mandats → 18 mandats.

| Cible `mandat` | Origine | Règle |
|---|---|---|
| `id_mandat` | Comblé (D1) | UUIDv5 de `'mandat:' + mandats.id` |
| `id_demande` | = UUID demande | FK |
| `id_version_contractuelle` | = UUID version | Via FK composée `fk_mandat_version (id_demande, id_version)` → `demande_version` |
| `id_chasseur` | `mandats.chasseur_id` → UUID | FK vers `chasseur` |
| `id_demande_signataire` | = `id_demande` | Contrainte `ck_mandat_signataire_demande` : doit **égaler** `id_demande` |
| `id_signataire` | = `id_client` (corrigé A06) → UUID | Via FK composée `fk_mandat_signataire (id_demande_signataire, id_signataire)` → `demande_acquereur`. Donc le signataire **doit** être l'acquéreur principal inséré en 6.2 |
| `id_mandat_precedent` | — | NULL (aucun renouvellement connu en source) |
| `numero_registre` | Comblé | `'MIGR-<id source>'` (UNIQUE requis ✓) |
| `date_signature` | `mandats.date_debut` | La date source est interprétée comme signature |
| `mode_signature` | Comblé | `'presentiel'` (mandats papier historiques ; CHECK `IN ('presentiel','en_ligne')`) |
| `date_debut` | `mandats.date_debut` | = date_signature ⇒ respecte `ck_mandat_effet` (`date_debut >= date_signature`) |
| `exclusif` | `mandats.exclusif` | Repris tel quel (boolean) |
| `statut` | **Calculé** (mapping ci-dessous) | CHECK `IN ('actif','renouvele','resilie','clos_succes')` |
| `taux_honoraires` | `chasseur.taux_commission` source | Renseigné ⇒ satisfait `ck_mandat_remun` (taux OU forfait requis) |
| `base_honoraires` | Comblé | `'TTC'` (NOT NULL ; CHECK `IN ('HT','TTC')`) — à confirmer métier |
| `taux_tva` | Comblé | `20.0` (NOT NULL ; TVA France) |
| `forfait_honoraires` | — | NULL (taux fourni, suffit à `ck_mandat_remun`) |
| `qualite_signataire` | Comblé | `'nom_propre'` (défaut ; CHECK `IN ('nom_propre','procuration')`. `'nom_propre'` n'exige pas `reference_procuration`) |
| `reference_procuration` | — | NULL (cohérent avec `nom_propre`) |
| `date_resiliation`, `motif_resiliation` | — | NULL, **sauf** statut `resilie` (voir mapping statut) |

> **⚠ Piège majeur — mapping des statuts.** Le domaine source `('actif','suspendu','termine','expire')` **ne correspond pas** au domaine cible `('actif','renouvele','resilie','clos_succes')`. Trois valeurs source n'existent pas en cible. Mapping proposé :

| Statut source | Statut cible | Justification |
|---|---|---|
| `actif` | `actif` | Repris — **mais** l'expiration réelle est recalculée en vue `v_mandat` (ADR-030), jamais recopiée. Un `actif` source dont `date_debut + 6 mois < 25/07/2026` ressortira `est_expire=true` en vue |
| `termine` | `clos_succes` | Un mandat terminé = mené à son terme (achat abouti). **À valider** : « terminé » pourrait aussi signifier « clos sans suite ». Faute de précision source, `clos_succes` est l'interprétation par défaut — tracé A04 |
| `expire` | `actif` | **Non repris comme statut** : l'expiration est **calculable** (A01), donc jamais stockée. Le statut de gestion reste `actif` ; la vue `v_mandat` signale l'expiration. C'est exactement la doctrine ADR-030 |
| `suspendu` | `resilie` (motivé) | **Tranché (A8 v2)** : `resilie` avec `motif_resiliation='suspendu (repris de l''existant, à requalifier)'` et `date_resiliation=date_debut`. Voir encadré |

> **✅ Tranché — statut `suspendu` → `resilie` motivé (A8 v2).** Le domaine cible n'a pas de `suspendu`. Décision métier : la suspension est portée par `resilie` avec un **motif explicite** `'suspendu (repris de l''existant, à requalifier)'` et `date_resiliation = date_debut` du mandat (la source ne date pas la suspension). C'est une **requalification tracée** (A04), pas une équivalence : le motif dit clairement qu'il s'agit d'une reprise à requalifier. La contrainte `ck_mandat_resil` (date + motif requis) est satisfaite. Ce choix est cohérent avec A7 : `resilie` n'étant jamais utilisé par la source (0 occurrence), il est libre pour porter `suspendu` sans collision avec `termine → clos_succes`.
>
> **Conséquence sur la ligne `date_resiliation`/`motif_resiliation` du tableau ci-dessus** : ces colonnes sont renseignées pour les 2 mandats `suspendu` (statut cible `resilie`), NULL pour tous les autres.

---

## 7. Synthèse des volumétries attendues (base des tests)

| Table cible | Lignes attendues | Dérivé de |
|---|---|---|
| `utilisateur` | 25 | 6 chasseurs + 18 clients + 1 technique (SYS-MIGRATION) |
| `chasseur` | 6 | rôle chasseur |
| `gestionnaire` | 1 | compte technique SYS-MIGRATION (A1/D-ROOT) |
| `client` | 18 | rôle client (A06 pointe vers le client existant 19, pas de 19ᵉ créé) — **voir note** |
| `zone` | 10 | 10 secteurs |
| `demande` | 18 | 18 mandats |
| `demande_acquereur` | 18 | 1 principal par demande |
| `demande_version` | 18 | 1 version courante par mandat |
| `version_zone` | ≥ 18 | ≥ 1 zone par version (plus si quartiers multiples) |
| `mandat` | 18 | 18 mandats |
| `chasseur_zone` | 0 (vide) | Arbitrage A11 — aucune source fiable |

> **Note client (A06 tranché).** L'utilisateur 3 est un chasseur reclassé « acquéreur » (A06) vers le client 19 (Nina Girard), qui est **déjà un client** existant. Aucun 19ᵉ client n'est créé : le total reste **18 clients**.

> **Note `chasseur_zone`.** Laissée **vide** à la migration (arbitrage A11) : la source n'a pas de relation fiable chasseur↔zone d'intervention, et la déduire des secteurs des mandats traités confondrait « a traité un mandat ici » avec « déclare intervenir ici ». Table enrichie ultérieurement par le métier.

---

## 8. Récapitulatif des points à valider (métier / modélisation)

| # | Point | Type | Défaut proposé |
|---|---|---|---|
| V1 | `gestionnaire` root `SYS-MIGRATION` porte les demandes | Modélisation | **Tranché (A1 v2)** : system account, exclu des stats |
| V2 | Sentinelles légales chasseur (D3) | **Métier** | Migrer + flag « à régulariser » |
| V3 | `statut_juridique='salarie'` par défaut | **Métier** | `salarie` |
| V4 | Correction A06 (chasseur 3 → client 19) | **Métier** | Reclasser vers client 19 |
| V5 | `canal='autre'` pour les demandes | Modélisation/RGPD | `autre` (pas de consentement inventé) |
| V6 | `criteres_bruts` → `commentaire_criteres` | Modélisation | Stocker le texte source intégral |
| V7 | Statut source `termine` → `clos_succes` | **Métier** | `clos_succes` |
| V8 | Statut source `suspendu` → `resilie` motivé | **Métier** | **Tranché (A8 v2)** : resilie + motif 'suspendu…', date≈date_debut |
| V9 | `base_honoraires='TTC'`, `taux_tva=20.0` | **Métier** | TTC / 20 % |
| V10 | `primo_accedant` déduit du texte « premier achat » | Modélisation | `false` (sûr) ou déduction tracée |
| V11 | `chasseur_zone` vide vs déduit | Modélisation | Vide, enrichi plus tard |

---

## 9. Rattachement RNCP40573

| Bloc | Contribution de ce mapping |
|---|---|
| **BC01** | Cartographie fine existant → cible ; décisions de comblement tracées |
| **BC02** | Points de validation métier isolés (§8) ; « zéro déperdition » vérifiable |
| **BC03** | Spécification d'implémentation respectant chaque contrainte du DDL |
| **BC05** | Socle OLTP correctement peuplé, prêt pour l'alimentation OLAP et l'IA |

> **À défendre en soutenance.** Le mapping ne « recopie » pas : il **reconstruit** (un mandat → demande + version + acquéreur + mandat), **recalcule** (l'expiration jamais recopiée, ADR-030), **comble en conscience** (sentinelles légales visibles, jamais masquées) et **trace tout écart** (A01, A03, A04, A06, A07, A10b). Les deux points les plus sensibles — le statut `suspendu` sans cible v7 (V8) et les mentions légales chasseur absentes (V2) — sont explicitement remontés au métier plutôt que résolus en douce.

---

## 10. Annexe — Registre des codes anomalies

Deux familles de codes coexistent dans ce dossier :

**Codes tracés en base** (`staging.migration_anomalie`, émis par le pipeline) — une ligne par occurrence :

| Code | Sens | Table concernée | Volume (run existant) |
|---|---|---|---|
| `T2` | `password_hash` absent → sentinelle, reset au 1er login (RGPD) | `utilisateur` | 24 |
| `A02` | Mentions légales chasseur absentes → sentinelles à régulariser (D3/A2) | `chasseur` | 6 |
| `A03` | Attribut déduit du texte libre (primo-accédant) — réversible (A10) | `client` | 1 |
| `A04` | Statut mandat requalifié (`suspendu`→`resilie` motivé) (A8) | `mandat` | 2 |
| `A06` | `client_id` pointant un chasseur → reclassé vers un client (A4) | `demande_acquereur` | 1 |
| `A07` | Code INSEE enrichi depuis référentiel externe (déclenché seulement si commune absente du référentiel) | `zone` | 0 |

> Les volumes correspondent à un **run unique sur base fraîche**. Le total varie si la base cumule plusieurs runs de test (l'idempotence empêche les doublons de données métier, mais le journal d'anomalies, lui, enregistre chaque run).

**Codes d'audit narratifs** (utilisés dans le raisonnement du mapping, non matérialisés en table car ils décrivent une *doctrine*, pas une ligne comblée) :

| Code | Sens |
|---|---|
| `A01` | Expiration d'un mandat : calculée (vue `v_mandat`), jamais stockée — donc rien à tracer ligne à ligne |
| `A10b` | Information sans réceptacle en cible (canal réel des demandes, résidence individuelle) : écartée, décrite globalement |
