# Arbitrages de migration — Version solidifiée (v2)

**Projet :** Service de chasse immobilière — refonte du SI
**Objet :** décisions figées des points ouverts du mapping, pour une migration implémentable sans zone grise
**Source :** `fixtures/PgSQL.sql` · **Cible :** MPD v7 (`01_ddl.sql`, `02_triggers_vues.sql`)
**Date de référence projet :** 25 juillet 2026
**Statut :** **validé** (arbitrages tranchés) — les lignes « Métier » restent à contresigner formellement avant production

> ⚠️ Entreprise, données et personnages fictifs. Note de travail destinée au Dossier Professionnel et à la soutenance.

---

> **Note v8.** Les arbitrages de migration (A1–A11, D-FLAG, D-ROOT, T1/T2)
> restent **valables en v8**. Deux précisions apportées par la v8 : (1) le gel
> de la carte T sur le mandat (ADR-039/A8) réutilise les mêmes sentinelles
> chasseur que A2 — la migration renseigne `numero_carte_t_signature` /
> `validite_carte_t_signature` avec ces sentinelles ; (2) `est_a_regulariser`
> (D-FLAG) est désormais porté par le DDL v8 (`v_conformite_chasseur`), fusionné
> d'un seul tenant avec le gel A8, sans extension de vue séparée.


## 1. Ce que change la v2 par rapport à la v1

| Réf | Évolution |
|---|---|
| A1 | **Renversé** : NULL → **gestionnaire root `SYS-MIGRATION`** (system account) qui porte les demandes migrées. Motif : ne pas rendre l'aval (Power BI, KPI, migrations récurrentes) aveugle sur l'origine des données. |
| A2 | **Précisé** : les sentinelles doivent **remonter activement** un état « à régulariser » lisible et bloquant en aval — mécanisme défini (D-FLAG). |
| A7 | **Confirmé et étayé** : `resilie` **n'existe pas** en source ⇒ `termine → clos_succes` est le mapping naturel. |
| A8 | **Renversé** : `actif` → **`resilie` avec `motif_resiliation = 'suspendu (repris de l''existant)'`**. La suspension source est portée comme une résiliation motivée. |
| A3 | **Confirmé** avec précision juridique : RSAC obligatoire pour les **mandataires / agents commerciaux uniquement**, pas tout agent immobilier. `salarie` par défaut reste correct. |
| D-FLAG | **Nouveau** : mécanisme de remontée des comblements (vue calculée + table d'anomalies de migration). |
| D-ROOT | **Nouveau** : spécification du gestionnaire root de migration. |

---

## 2. Comment lire ce tableau

Chaque arbitrage liste les **options réellement possibles**, le **choix retenu**, sa **justification** et son **coût assumé**. Colonne *Nature* : **Modélisation** (tranché par cohérence v7, décidable en interne), **Métier** (défaut de migration à contresigner), **Bloquant** (sans décision, une ligne est immigrable).

---

## 3. Tableau des arbitrages

### A1 — Rôle `gestionnaire` : gestionnaire root de migration `SYS-MIGRATION`

| | |
|---|---|
| **Nature** | Modélisation |
| **Contexte** | La v7 introduit le rôle `gestionnaire` ; l'existant ne le connaît pas. `demande.id_gestionnaire` est nullable. Laisser NULL rendrait l'aval aveugle : les KPI de charge, Power BI et surtout les **migrations récurrentes** (rachats) ne pourraient pas distinguer les demandes issues d'une migration. |
| **Options** | (a) NULL ; (b) **gestionnaire root `SYS-MIGRATION`** (un system account) ; (c) un gestionnaire root **par source** rachetée. |
| **Choix retenu** | **(b) gestionnaire root unique `SYS-MIGRATION`.** |
| **Justification** | Un *system account* est un pattern éprouvé : il donne une origine identifiable aux données importées sans inventer un acteur humain. (a) laisse un trou dans les agrégats aval. (c) sur-découpe : la distinction par source se fait déjà via la table d'anomalies (D-FLAG) et la config `sources.yml` ; un gestionnaire par source multiplierait des comptes sans bénéfice. (b) est nécessaire et suffisant. |
| **Coût assumé** | Un utilisateur/gestionnaire technique existe en base ; il doit être **exclu des statistiques opérationnelles** (ce n'est pas un gestionnaire réel). Spécifié en D-ROOT. |

### A2 — Mentions légales du chasseur absentes → sentinelles **remontées** (voir D-FLAG)

| | |
|---|---|
| **Nature** | **Métier** |
| **Contexte** | `chasseur` exige 9 colonnes légales NOT NULL, aucune en source. |
| **Options** | (a) Sentinelles « à régulariser » ; (b) Exclure les chasseurs ; (c) Bloquer la migration. |
| **Choix retenu** | **(a) Sentinelles — avec remontée active obligatoire (D-FLAG).** |
| **Justification** | (b) rendrait 18 mandats orphelins. (c) bloquerait le projet sur une donnée collectable en parallèle. (a) avance **et** rend le trou visible **et actionnable** : la sentinelle n'est pas seulement « consultable dans une vue », elle alimente un état `est_a_regulariser` que la couche applicative peut lire et sur lequel elle peut **bloquer** (voir D-FLAG). |
| **Coût assumé** | Les 6 chasseurs sont en état « non conforme » actif jusqu'à régularisation métier. C'est un état transitoire de migration, à contresigner. |

### A3 — Statut juridique du chasseur par défaut (`salarie`)

| | |
|---|---|
| **Nature** | **Métier** |
| **Contexte** | `statut_juridique` NOT NULL (`salarie \| agent_commercial \| independant`). `agent_commercial` exige un `numero_rsac` (`ck_chasseur_rsac`). **Précision juridique** : le RSAC (Registre Spécial des Agents Commerciaux) est obligatoire pour les **mandataires / agents commerciaux uniquement**, pas pour tout agent immobilier — un salarié agit sous la carte T de l'agence et n'a pas de RSAC (confirmé par le dossier de modélisation v7). |
| **Options** | (a) `salarie` ; (b) `independant` ; (c) `agent_commercial` + RSAC sentinelle. |
| **Choix retenu** | **(a) `salarie`.** |
| **Justification** | C'est la seule valeur sans contrainte supplémentaire : elle n'exige pas de RSAC. Précisément parce qu'on ignore le vrai statut, choisir celui qui n'invente pas une pièce légale de plus (le RSAC) est le plus prudent. (c) fabriquerait un numéro RSAC fictif. |
| **Coût assumé** | Si des chasseurs sont réellement mandataires, l'information est fausse jusqu'à correction. Remonté avec A2 via D-FLAG. |

### A4 — Anomalie A06 : chasseur en position de client (mandat `client_id = 3`)

| | |
|---|---|
| **Nature** | **Métier** (correction de donnée) |
| **Contexte** | Un mandat porte `client_id = 3` (la chasseuse Inès Delacroix). La FK `demande_acquereur.id_client → client` rejette cet insert. |
| **Options** | (a) Reclasser vers le client 19 (Nina Girard) ; (b) Exclure ce mandat ; (c) Créer un `client` pour l'utilisateur 3. |
| **Choix retenu** | **(a) Reclasser vers client 19.** |
| **Justification** | Faisceau vérifié sur les données : budget du mandat (220000) = celui de Nina Girard et d'aucun autre ; elle est le **seul** client sans mandat (client_id 7–24 sauf 19 en ont tous un) ; sa ville (Montpellier) = secteur visé (Figuerolles). (c) ferait d'une chasseuse sa propre cliente. |
| **Coût assumé** | Reconstitution, pas certitude : à valider avant production (A06). Sans elle, le mandat est immigrable. |

### A5 — Canal de la demande reconstruite (`autre`)

| | |
|---|---|
| **Nature** | Modélisation / RGPD |
| **Contexte** | `demande.canal` NOT NULL ; `ck_demande_consent_web` impose `canal='site_web' ⇒ date_consentement NOT NULL`. Aucun consentement ni canal en source. |
| **Options** | (a) `autre` ; (b) `site_web` + consentement fabriqué ; (c) `telephone`/`parrainage`. |
| **Choix retenu** | **(a) `autre`.** |
| **Justification** | (b) est une faute RGPD (consentement inventé). (c) prétend connaître un canal absent. (a) est honnête (mandats papier, canal réel inconnu) et n'exige aucun consentement. |
| **Coût assumé** | Provenance réelle des demandes perdue — absente de la source de toute façon. Tracé A10b. |

### A6 — Conservation du texte libre (`commentaire_criteres`)

| | |
|---|---|
| **Nature** | Modélisation |
| **Contexte** | La v7 n'a pas la colonne `criteres_bruts` du code repo. L'équivalent est `demande_version.commentaire_criteres` (nullable). |
| **Options** | (a) Stocker le texte source intégral dans `commentaire_criteres` ; (b) Ne pas le conserver ; (c) Ajouter `criteres_bruts` à la v7. |
| **Choix retenu** | **(a) `commentaire_criteres` = texte source intégral.** |
| **Justification** | (b) violerait « zéro déperdition » (perte de « charme ancien », « poutres », « vue mer »…). (c) modifierait le schéma cible pour un besoin de migration. (a) réutilise une colonne v7 prévue pour du commentaire de critères. |
| **Coût assumé** | Pour les lignes migrées, `commentaire_criteres` porte le brut source ; provenance traçable via `motif_evolution`. |

### A7 — Statut source `termine → clos_succes`

| | |
|---|---|
| **Nature** | **Métier** |
| **Contexte** | Domaine source `('actif','suspendu','termine','expire')`. **`resilie` n'existe pas en source** (0 occurrence, vérifié). Domaine cible `('actif','renouvele','resilie','clos_succes')` : seul `clos_succes` est une « fin normale ». |
| **Options** | (a) `clos_succes` ; (b) `resilie` ; (c) demander l'issue réelle. |
| **Choix retenu** | **(a) `clos_succes`.** |
| **Justification** | Puisque la source n'utilise jamais `resilie`, `termine` désigne un mandat mené à terme → `clos_succes` est le mapping naturel. `resilie` en cible est désormais réservé à la conversion de `suspendu` (A8), sans collision. (b) exigerait date + motif de résiliation (`ck_mandat_resil`) qu'un mandat *terminé* n'a pas. |
| **Coût assumé** | Si un « terminé » l'était sans achat, `clos_succes` le qualifie à tort. Tracé A04, requalifiable par le métier. |

### A8 — Statut source `suspendu → resilie` motivé

| | |
|---|---|
| **Nature** | **Métier** (résolu ; n'est plus bloquant) |
| **Contexte** | 2 mandats source `suspendu`. `suspendu` n'existe pas en v7. La cible a `resilie`, non utilisé par la source. |
| **Options** | (a) `actif` ; (b) **`resilie` + motif `'suspendu'`** ; (c) `clos_succes` ; (d) ajouter `suspendu` à la v7. |
| **Choix retenu** | **(b) `resilie`, avec `motif_resiliation = 'suspendu (repris de l''existant, à requalifier)'`** et `date_resiliation` = `date_debut` du mandat (faute de date de suspension source). |
| **Justification** | Décision métier : une suspension est plus proche d'une interruption (résiliation) que d'un mandat actif ou d'un succès. La cible ayant `resilie` libre (A7 confirme que la source n'a pas de `resilie`), on l'utilise pour porter la suspension **avec un motif explicite** — l'information n'est pas perdue, elle est requalifiée et tracée. `ck_mandat_resil` (date + motif requis) est satisfaite. (a) perdrait l'info de suspension ; (d) modifierait le schéma pour 2 lignes. |
| **Coût assumé** | `date_resiliation` est approximée à `date_debut` (la source ne date pas la suspension) — tracé A04. Le motif `'suspendu…'` signale clairement que c'est une reprise à requalifier, pas une vraie résiliation décidée. À contresigner. |

### A9 — Base et taux d'honoraires (`TTC` / `20 %`)

| | |
|---|---|
| **Nature** | **Métier** |
| **Contexte** | `mandat.base_honoraires` NOT NULL (`HT \| TTC`) et `taux_tva` NOT NULL, aucun en source. |
| **Options** | (a) `TTC` / `20.0` ; (b) `HT` / `20.0` ; (c) demander le barème réel. |
| **Choix retenu** | **(a) `TTC` / `20.0 %`.** |
| **Justification** | Clientèle de particuliers (résidentiel) : prix TTC = norme d'affichage ; 20 % = TVA de droit commun. `taux_honoraires` (taux réel du chasseur) est repris ; seule la présentation base/TVA est supposée. |
| **Coût assumé** | Si le barème réel diffère, valeurs à corriger. Impact limité. À contresigner. |

### A10 — `primo_accedant` déduit du texte (1 cas)

| | |
|---|---|
| **Nature** | Modélisation |
| **Contexte** | `client.primo_accedant` défaut `false`. Une `description_recherche` contient « premier achat » (le mandat reclassé A06). |
| **Options** | (a) `false` pour tous ; (b) `true` pour le client concerné, tracé. |
| **Choix retenu** | **(b) déduction tracée.** |
| **Justification** | L'information est présente et exploitable ; l'ignorer serait une perte. Inférence sur texte libre, donc tracée (A03) et réversible. |
| **Coût assumé** | Une déduction NLP peut se tromper ; la trace permet de la défaire. |

### A11 — Zones d'intervention des chasseurs (`chasseur_zone` vide)

| | |
|---|---|
| **Nature** | Modélisation |
| **Contexte** | `chasseur_zone` relie chasseurs et zones. Pas de relation fiable en source. |
| **Options** | (a) Vide ; (b) Déduire des mandats traités ; (c) Déduire de `utilisateurs.ville`. |
| **Choix retenu** | **(a) Vide**, enrichi ultérieurement. |
| **Justification** | (b) confond « a traité ici » et « déclare intervenir ici ». (c) réduit à la résidence, souvent faux. `chasseur_zone` est du paramétrage métier, pas une donnée à reconstituer. |
| **Coût assumé** | Le matching futur attend que le métier renseigne `chasseur_zone`. Aucune donnée fausse. |

---

## 4. Décisions de conception ajoutées en v2

### D-ROOT — Gestionnaire root de migration `SYS-MIGRATION`

| | |
|---|---|
| **Objet** | Porter les demandes migrées sous un acteur identifiable, sans inventer un gestionnaire humain. |
| **Implémentation** | Un `utilisateur` technique (nom `SYSTEME`, prénom `Migration`, email réservé type `sys-migration@interne.invalid`, `password_hash` sentinelle non-authentifiable, `actif=false`) + une ligne `gestionnaire` (`matricule='SYS-MIGRATION'`, `date_entree_fonction` = date du run, `capacite_max_leads` = valeur technique, ex. 32767). UUID déterministe (T1). |
| **Règle d'exclusion** | Cet acteur doit être **exclu de toutes les statistiques opérationnelles** (KPI gestionnaire, Power BI). Les vues et l'ETL OLAP filtreront `matricule = 'SYS-MIGRATION'`. À implémenter comme filtre standard. |
| **Justification** | Traçabilité de l'origine des données (essentiel pour les migrations récurrentes) ; `actif=false` empêche toute connexion ; l'exclusion analytique évite de polluer les indicateurs. |
| **Coût assumé** | Un compte technique en base, documenté et filtré partout en aval. |

### D-FLAG — Remontée des comblements : détection calculée + journal d'anomalies

| | |
|---|---|
| **Objet** | Rendre chaque sentinelle / comblement **lisible et actionnable** en aval (API, Power BI), et **tracer** l'audit « zéro déperdition ». Deux niveaux, séparés à dessein. |
| **Niveau 1 — Détection (calculée, pas stockée)** | Étendre `v_conformite_chasseur` d'une colonne synthétique `est_a_regulariser` (booléen : carte T ou RCP expirée/sentinelle, garantie sentinelle, mentions `'A_REGULARISER'`). La couche applicative lit cette vue et peut **bloquer** au-dessus (ex. interdire la signature d'un mandat par un chasseur `est_a_regulariser`). |
| **Niveau 2 — Traçabilité (persistée, hors OLTP métier)** | Table `migration_anomalie` dans le schéma de **staging** (pas dans `public`) : `(id, source, entite_cible, id_cible, code_anomalie, motif, valeur_sentinelle, date_run)`. Matérialise le rapport de reprise ; réutilisée à chaque run récurrent. |
| **Pourquoi pas un booléen `a_regulariser` stocké sur `chasseur`** | Cela dupliquerait une information **calculable** (les dates disent déjà la non-conformité) et pourrait **mentir** (booléen « ok » vs dates « expiré ») — exactement l'anomalie A01 que la v7 élimine. La doctrine v7 « si calculé, pas stocké » (ADR-030) impose la détection par vue. |
| **Justification** | Détection = source unique de vérité, jamais contredite par les dates ; traçabilité = audit réel hors du modèle transactionnel. Le blocage éventuel se décide **au niveau applicatif** (API), pas par une colonne métier figée. |
| **Coût assumé** | Une vue à étendre et une table de staging à créer et alimenter par le pipeline. Le comportement bloquant est une règle **applicative** à spécifier côté backend (hors migration). |

---

## 5. Sémantique « sentinelle » (clarification demandée)

Une **sentinelle** dans cette migration n'est jamais une valeur silencieuse « pour faire passer le NOT NULL ». Par construction (D-FLAG), toute sentinelle :

1. **est détectable** — soit par une date volontairement expirée (`2000-01-01`) qui ressort dans `v_conformite_chasseur`, soit par un marqueur texte (`'A_REGULARISER'`) ;
2. **remonte** dans `est_a_regulariser` (niveau applicatif) et dans `migration_anomalie` (audit) ;
3. **peut déclencher un blocage** au niveau au-dessus (API), selon la règle métier retenue.

Donc : **oui, une sentinelle implique toujours que l'information remonte.** C'est la définition retenue ici, pas une option.

---

## 6. Synthèse — reste à contresigner par le métier

| Réf | Décision par défaut | Risque si faux |
|---|---|---|
| A2 | Sentinelles légales chasseur + remontée D-FLAG | Chasseurs actifs sans mentions légales valides |
| A3 | `statut_juridique = salarie` | Statut juridique erroné (mandataires non détectés) |
| A4 | Reclassement A06 → client 19 | Mauvais acquéreur rattaché |
| A7 | `termine → clos_succes` | Succès déclaré à tort |
| A8 | `suspendu → resilie` motivé, date approximée | Résiliation à requalifier ; date de résiliation approximative |
| A9 | `TTC` / `20 %` | Présentation d'honoraires erronée |

A1, A5, A6, A10, A11, D-ROOT, D-FLAG, T1, T2 sont de nature **Modélisation** : décidables en interne, tranchés.

> **Note de traçabilité (question NoSQL).** Une question a été posée en séance : le NoSQL servira-t-il aux migrations des futurs rachats ? Réponse retenue : **non**. La cible reste relationnelle (OLTP v7) ; le pipeline E-T-L-V paramétrable par source **est** le mécanisme des rachats. Le NoSQL n'est pas un outil de migration mais un type de base ; il pourrait au mieux servir de *landing zone* pour une source très irrégulière ou pour l'ingestion d'annonces hétérogènes — à démontrer par un besoin réel (Règle 6 : pas de techno par mode). Point clos, sans ADR dédié.

---

## 7. Décisions transverses (rappel)

### T1 — UUID déterministe (UUIDv5 depuis clé naturelle)

Idempotence + absence de collision multi-source (ADR-028). Le mapping fournit explicitement chaque UUID ; ne contredit pas le `DEFAULT gen_random_uuid()` (qui ne s'applique qu'aux insertions sans UUID fourni).

### T2 — Mots de passe : sentinelle non-authentifiable + reset au 1ᵉʳ login

`password_hash` NOT NULL comblé par une valeur ne correspondant à aucun hash valide. Aucun compte migré connectable sans ré-enrôlement. Tracé RGPD.

---

## 8. Rattachement RNCP40573

| Bloc | Contribution |
|---|---|
| **BC01** | Décisions d'architecture tracées, alternatives écartées en conscience |
| **BC02** | Validations métier isolées ; pilotage du reste-à-décider ; gestionnaire root pour la traçabilité des runs récurrents |
| **BC03** | Chaque arbitrage respecte une contrainte du DDL ; D-FLAG place le blocage au bon niveau (applicatif) |
| **BC05** | Socle OLTP cohérent, traçable, prêt pour l'aval (OLAP/BI/IA) sans trou d'origine |

> **À défendre en soutenance.** Deux principes tiennent l'ensemble : *ne jamais inventer en silence* (toute sentinelle remonte, D-FLAG) et *ne jamais stocker ce qui se calcule* (détection par vue, pas de booléen figé — cohérent ADR-030). Le gestionnaire root répond à une vraie exigence des migrations récurrentes : garder l'origine des données. Le point le plus discutable — `suspendu → resilie` — est assumé comme une **requalification tracée**, pas une équivalence, avec un motif qui dit explicitement « à requalifier ».
