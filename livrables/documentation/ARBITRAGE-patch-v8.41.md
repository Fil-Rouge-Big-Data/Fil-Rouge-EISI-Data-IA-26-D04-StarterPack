# Arbitrage des points ouverts — patch v8.4 → v8.41 (RÉALISÉ)

> **STATUT : patch réalisé et vérifié.** Décisions prises pour le patch **v8.41** (micro-ajustements après v8.4).
> Chaque point : problématique, décision, et note « règles de l'art » le cas échéant.
> Construit en s'appuyant sur les skills `testing-strategy` et `code-review`.
> ⚠️ Données fictives — RNCP40573.

---

## Cadre

La v8.41 est un **patch** (micro-ajustements), pas une refonte. Deux sujets
volontairement **hors patch**, rattachés au chantier « migration récurrente /
croissance » (ils ne cassent pas l'aval — voir note P-E) :
- l'**upsert** / convergence des corrections source ;
- la **projection de performance OLAP** de `mandat_reprise` (déjà acté, ADR-051).

Deux points **laissés au collègue** pour la v8.41 (il les a déjà écrits sur
l'ancien modèle, il les reportera sur la branche après adaptation) :
- le **test client transactionnel avec acte** (anonymisation) ;
- le **contrôle croisé budget (A03b)**.


## Statut final des décisions (vérifié par exécution)

| Point | Décision | Statut v8.41 | Preuve |
|---|---|---|---|
| EXCL | `pref_*` 4 états (exige/souhaite/exclut/indifferent) | ✅ **Fait** | Parser 4 états : 5 tests ; ADR-052 |
| SCORE | Composantes conformes à la spec | ✅ **Fait** (correction d'une erreur v8.4) | Colonnes vérifiées vs schéma réel ; ADR-052 |
| P-A | 3 sondes à helper → implémentées | ✅ **Fait** | 12 sondes fermées, 0 à helper |
| P-B | CHECK taux testé aux limites | ✅ **Fait** | 19,99/60,01 rejetés ; 20/60 acceptés |
| P-C | A10b journalisée | ✅ **Fait** | 18 anomalies A10b tracées |
| P-D | Idempotence sur toutes les tables | ✅ **Fait** | Test sur 10 tables |
| P-E | Upsert / migration récurrente | ⏭️ **Reporté** (hors patch, sans impact aval) | Chantier croissance |
| P-F | Anonymisation `actif=false` | ✅ **Fait** | Test dédié (7/7) |
| P-G | Test de rollback | ✅ **Fait** | Échec provoqué → rien committé, run tracé |
| P-H | Scories v7 + skips bruyants | ✅ **Fait** | `chasse_v8` ; `REQUIRE_DB=1` échoue sans base |
| RLS (ENF-03) | Renvoyé au fil API | ⏭️ **Reporté** (ne touche pas le MCD) | Dépend de l'auth backend |
| Test transactionnel + A03b | Collègue | ⏭️ **v8.42** | — |

### Enseignements du patch (à garder pour la suite)
- Une sonde peut révéler une **défense en profondeur** : S9 est rejetée par le trigger
  de succession avant le CHECK. Les deux protègent ; le test accepte l'un ou l'autre.
- Tester **aux limites** (19,99 / 20 / 60 / 60,01) prouve que la borne est exacte dans
  les deux sens, pas seulement qu'elle bloque.
- **Un harnais « probant » doit comparer à la contrainte ATTENDUE, pas seulement constater un rejet.**
  La première version acceptait n'importe quelle contrainte violée. Après l'enrichissement du jeu de test
  (v8.4), trois tests (T17, T18, T21) étaient rejetés par une autre contrainte (`ux_offre_acceptee`,
  `fk_proposition_version`) et ne prouvaient rien : défaut vu en relisant la sortie d'un lancement réel, pas
  les totaux. Corrigé : table `ATTENDU` (une contrainte par test), SQLSTATE exposé, et test de mutation
  (suppression de 3 contraintes en base -> les 3 tests correspondants échouent bien).
- **Ne jamais nommer de mémoire** : l'erreur sur le score venait d'un nommage « générique »
  sans relire la spec. Le dictionnaire est désormais vérifié automatiquement vs le schéma.

---

## Décisions

### EXCL — « sans balcon » = exclusion (changement de modèle léger)
**Problème.** Le modèle code les critères en booléens `exige_X` (2 états :
exige / indifférent). Il ne sait pas exprimer « sans balcon » = **refus** (critère
d'exclusion), ni distinguer « apprécié » (souhait) de « indifférent ».

**Décision.** Remplacer chaque booléen `exige_X` par un champ à **valeurs
contrôlées** : `pref_X ∈ { exige, souhaite, exclut, indifferent }`. Une seule
colonne par critère (impact modèle minimal, pas de doublement en `exclut_*`), mais
expressivité complète. Le parser mappe : « avec/exigé » → `exige` ; « apprécié /
souhaité / ou » → `souhaite` ; « sans / pas de / aucun » → `exclut` ; absent →
`indifferent`. Un `exclut` détecté est tracé (anomalie de requalification).

> Règle de l'art : modéliser l'intention métier réelle (3-4 états) plutôt que de
> forcer un booléen à porter une sémantique qu'il ne peut pas exprimer.

**Impact aval.** Changement de type de colonnes (booléen → texte contraint) : à
répercuter sur le matching et, le cas échéant, sur les vues. À vérifier au patch.

---

### P-A — 3 sondes « à helper » → implémentées
**Problème.** S9, D2b, Acte étaient désactivées faute de jeu de données.
**Décision.** Les **implémenter** en montant le jeu de données dans la sonde (dans
une transaction annulée), comme un test fonctionnel. Plus de sonde inactive.

> Règle de l'art : une protection annoncée doit être **démontrée** par un test qui
> l'exerce réellement, pas supposée.

---

### P-B — CHECK taux 20-60 testé aux bornes
**Problème.** La contrainte existe mais n'est jouée par aucun test.
**Décision.** Ajouter un **test aux limites** (règles de l'art) : 19,99 rejeté /
20,00 accepté / 60,00 accepté / 60,01 rejeté. Monter l'acte « libre » nécessaire.

> Règle de l'art (testing-strategy) : tester les **valeurs limites** d'une borne,
> pas seulement une valeur « au milieu ».

---

### P-C — A10b (ville écartée) journalisée
**Problème.** Anomalie annoncée dans le mapping, non écrite.
**Décision.** L'**implémenter** : écrire une ligne `staging.migration_anomalie`
code `A10b` quand une ville source est écartée. Cohérence doc ↔ code rétablie.

---

### P-D — Idempotence testée sur toutes les tables
**Problème.** Le test d'idempotence ne couvre bien que `utilisateur`.
**Décision.** **Étendre** : vérifier l'invariance du nombre de lignes de **chaque
table** entre un 1ᵉʳ et un 2ᵉ run (compte identique = idempotent).

> Règle de l'art : l'idempotence d'un pipeline se teste sur **l'ensemble** des
> sorties, pas un échantillon ; c'est le fondement des migrations récurrentes.

---

### P-E — ON CONFLICT / migration récurrente → HORS patch (reporté)
**Problème.** `ON CONFLICT DO NOTHING` = insert-only : une correction source
(email, critère) n'est pas reprise à un re-run.

**Décision.** **Reporté** au chantier « migration récurrente / croissance ».
Justification vérifiée : l'upsert est une **stratégie d'écriture du pipeline**, il
ne change **ni le modèle, ni les tables, ni les contraintes**. L'aval (API REST,
Power BI, OLAP) lit le **résultat** dans les tables, pas la façon dont les lignes y
sont arrivées → **développer l'aval maintenant et ajouter l'upsert plus tard ne
casse rien** et n'impose aucune migration structurante (les champs à converger
existent déjà). Le besoin n'apparaît qu'au **re-rachat d'une source corrigée**,
donc pas avant ce chantier.

> Note : à tracer par un ADR « stratégie d'upsert / convergence » quand le chantier
> s'ouvrira (colonnes autoritaires côté source, gestion des conflits, traçabilité
> des valeurs écrasées).

---

### P-F — Anonymisation des comptes `actif=false` échus
**Problème.** Le job ne sélectionne que `actif=true` → un compte **désactivé mais
jamais anonymisé** (typiquement hérité de la migration) garde ses données perso
indéfiniment. Risque RGPD réel.
**Décision.** **Corriger** : le job traite aussi les comptes `actif=false` arrivés
à échéance, **en conservant toutes les gardes** (jamais un client sous mandat
actif, exclusion gestionnaires/chasseurs en réseau — ADR-048). Fusion avec la
détection fine du collègue (6 sources) prévue en parallèle.

---

### P-G — Test de rollback de la transaction unique
**Problème.** La transaction unique (ADR-050) est censée tout annuler en cas
d'échec, mais rien ne le prouve.
**Décision.** Ajouter un **test qui injecte une erreur** en cours de chargement et
vérifie qu'**aucune donnée n'est committée** (rollback effectif), tandis que le
**journal du run** conserve bien la trace de l'échec.

> Règle de l'art : un mécanisme de sécurité (rollback) doit être prouvé par un test
> qui **provoque** la condition d'échec, pas seulement décrit.

---

### P-H — Purge des scories de nommage v7
**Problème.** `chasse_v7` partout (`.env.example`, défauts code, docker-compose),
commentaire « MPD v7 », etc. Cause en prime des **skips silencieux** de tests
quand la base réelle porte un autre nom.
**Décision.** **Renommer `chasse_v7` → `chasse_v8`** partout, purger toutes les
mentions « v7 » résiduelles. **Et** faire en sorte que les tests d'intégration
**signalent** « base non trouvée, tests non exécutés » au lieu de se skipper en
silence (une CI ne doit pas être verte sans avoir testé).

> Règle de l'art : un test qui ne s'exécute pas doit **échouer bruyamment** ou
> l'annoncer, jamais passer silencieusement (faux sentiment de couverture).

---

## Points de fusion avec le travail du collègue (hors ce patch, au merge)

| Sujet | Action | Nature |
|---|---|---|
| Parsing négation | **Garder le nôtre** (couvre le sien) ; prendre juste ses mots `pas de / aucun` dans la négation ; + modèle EXCL | pas une fusion |
| Suites de tests | **Additionner** (23+4 et 25+5 ne se recouvrent pas) **après adaptation de ses tests au modèle v8.4** | addition |
| Anonymisation | **Fusion réelle** : nos gardes + sa détection (6 sources), après adaptation au schéma v8.4 | fusion |
| Test transactionnel + A03b | **Laissés au collègue** pour v8.41 | report |
| Habilitation | Ses ajouts reposent sur l'ancien modèle (`numero_carte_t`) → il les reporte sur la branche après adaptation | adaptation |

---

## Plan de patch v8.41 (ordre proposé)

1. **P-H** scories v7 + skips bruyants (débloque les tests pour tout le reste).
2. **EXCL** modèle `pref_X` + parser (changement de modèle, à faire tôt).
3. **P-A, P-B** sondes + test borne taux (couverture d'intégrité).
4. **P-C** A10b, **P-D** idempotence complète, **P-G** rollback (migration).
5. **P-F** anonymisation `actif=false` (+ préparer la fusion détection collègue).
6. Reporté : **P-E** upsert, test transactionnel + A03b (collègue), OLAP.

Chaque modification sera **vérifiée par exécution** et les choix « règles de l'art »
annotés en commentaire dans le code.

---

## Reliquats détectés en cours de patch (revue collègue)

### SCORE — composantes non conformes à la spec → CORRIGÉ en v8.41
La v8.4 portait `score_delai, score_reussite, score_satisfaction, score_volume,
score_anciennete` : noms inventés (satisfaction), doublon (anciennete vs
majoration_anciennete), et **35 % manquants** (exclusivité 10, visites 25).
**Corrigé** : composantes conformes à l'ADR-rémunération (délai 25 · exclusivité 10
· ventes 25 · mandats 15 · visites 25). Erreur introduite en v8.4 faute d'avoir lu
la spec — réparée.

> NB visites : la table `visite` stocke un événement (1 visiteur, 1 date), PAS un
> « nombre de personnes ». Le nombre de visites se **compte** (COUNT sur 12 mois
> glissants) au calcul du score ; rien à stocker ni à retirer.

### RLS / ENF-03 — accès restreint rémunération & IBAN → RENVOYÉ au fil API REST
Reliquat **hérité de la v7** (ADR-027 prévoyait la RLS pour les commentaires
privés, jamais implémentée). La revue l'étend justement aux **montants de
rémunération et IBAN**. Décision : **ne pas implémenter en v8.41** car la RLS ne
touche NI le MCD NI la structure des tables (c'est une couche d'accès), et elle
**dépend du mode d'authentification backend** (`app.user_id` via
`current_setting`), non arbitré, qui relève du fil API REST.
→ **Point ouvert renvoyé au fil API REST** : y implémenter `ENABLE ROW LEVEL
SECURITY` + politiques (commentaires privés ADR-027, montants rémunération, IBAN
facture) une fois le mécanisme d'injection d'identité figé.
