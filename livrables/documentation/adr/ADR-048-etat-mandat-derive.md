# ADR-048 — État du mandat entièrement dérivé (remplace ADR-038)

> **Statut :** Accepté · **Date :** 2026-10-06 · **Remplace :** ADR-038 · **Fonde :** ADR-030 (si calculable, pas stocké). · **Déclencheur :** revue v8 (M3), analyse de cohérence.

## 1. Contexte

Le mandat portait une colonne `statut` (`actif`, `renouvele`, `resilie`,
`clos_succes`). La revue (M3) a montré une contradiction : l'ADR-038 mappait
`expire → resilie`, la migration faisait `expire → actif`. Au-delà du conflit,
l'analyse a révélé un défaut de fond : **la plupart de ces états sont calculables**
et n'avaient pas à être stockés, en contradiction avec l'ADR-030.

Constats :
- `actif` / `expire` dérivent de `date_debut` (+ 6 mois) et de `date_reference()`.
- `clos_succes` (succès) **n'appartient pas au mandat** : la vente est un `acte`,
  qui porte déjà le lien vers le mandat. « A réussi » = « a un acte rattaché ».
- `renouvele` dérive de la filiation : un mandat est renouvelé s'il existe un
  mandat dont `id_mandat_precedent` le désigne.
- Seul l'**abandon** (résiliation anticipée) est un fait non dérivable : c'est une
  décision humaine, qui doit être enregistrée.

## 2. Décision — le mandat ne stocke que des faits

**Suppression de la colonne `statut`** du mandat (et de ses CHECK). Le mandat ne
stocke plus que des **faits** :

- `date_debut` (= `date_signature`, ADR-037) ;
- `id_mandat_precedent` (filiation, ADR-045) ;
- `date_resiliation` + `motif_resiliation` (le **seul** événement non calculable :
  l'abandon anticipé ; NULL = non résilié).

Tout « état » devient **calculé** dans `v_mandat` :

| État | Règle de calcul |
|---|---|
| résilié | `date_resiliation IS NOT NULL` (seul fait stocké) |
| succès | existe un `acte` rattaché au mandat (via la chaîne) |
| renouvelé | existe un mandat `m2` avec `m2.id_mandat_precedent = id_mandat` |
| actif | non résilié, sans acte, `date_reference() < date_debut + 6 mois` |
| échu (infructueux) | non résilié, sans acte, sans successeur, `date_reference() >= date_debut + 6 mois` |

### 2.1 Règle de succession (n → n+1)

Un renouvellement ne peut commencer **avant** le terme du précédent :
**`date_debut(n+1) >= date_debut(n) + 6 mois`**. Il n'y a **pas** de borne
supérieure : reprendre après une pause (8 mois, un an) est un cas métier normal.
Contrôle inter-lignes → déclencheur sur `mandat`.

### 2.2 Contraintes exprimées sur le calcul, pas sur un statut stocké

Les règles qui référençaient `statut='actif'` s'expriment sur l'**expression
calculée**. Exemple : l'unicité « un seul mandat actif par demande » devient un
index unique sur l'expression d'activité (demande + condition calculée), plutôt
qu'un `UNIQUE(... WHERE statut='actif')`. On calcule, on ne stocke pas par confort
de requête.

## 3. Projection d'état `mandat_etat` — active dès la v8.3

### 3.1 Pourquoi une projection matérialisée, et pourquoi maintenant

Le PO a confirmé un **flux récurrent de migration** : le service rachète
régulièrement le portefeuille d'autres entreprises (ADR-001). Or les mandats
repris arrivent avec un **état connu** (la source nous dit « vendu », « résilié »)
mais **sans tous les faits sous-jacents** : on sait qu'une vente a eu lieu, mais
on n'a pas l'acte qui, dans notre modèle, *définit* le succès.

Ceci crée une population permanente — qui grandit à chaque rachat — d'états
**non recalculables** : `v_mandat`, qui dérive l'état des faits, classerait un
mandat « vendu mais sans acte repris » en `echu`, perdant le succès. Inventer un
faux acte serait pire (données fabriquées).

> **Justification retenue :** on matérialise l'état du mandat non pas par confort
> de requête ni par anticipation de performance, mais **parce qu'une partie de cet
> état — l'état repris — n'est pas calculable, et qu'un besoin métier récurrent
> (le flux de rachats confirmé par le PO) l'impose.** C'est le besoin qui active
> la table, conformément à la Règle 6 (pas de techno sans besoin démontré).

### 3.2 Structure et règle « repris fait foi »

Table `mandat_etat(id_mandat, statut, origine, date_calcul)` avec
`origine ∈ {repris, calcule}` :

- **`repris`** — état constaté à la migration, **non recalculable** (faits
  manquants). Il **fait foi** et n'est **jamais écrasé** par un recalcul.
- **`calcule`** — projection du calcul de `v_mandat`, **régénérable**, rafraîchie
  par un job incrémental (volet performance ci-dessous).

Règle de lecture de l'état « officiel » d'un mandat :
1. s'il existe une ligne `origine='repris'` → elle fait foi ;
2. sinon, l'état dérivé de `v_mandat` (calcul à la volée, ou sa projection `calcule`).

### 3.3 Volet performance (rafraîchissement incrémental)

Le job qui alimente les lignes `calcule` ne recalcule que la **frange volatile** :
les états `resilie`, `clos_succes`, `renouvele` sont **terminaux et figés** une
fois atteints ; seuls `actif`/`echu` récents peuvent changer. À grande échelle,
cette frange est une fraction minime du total. Le job ne touche **jamais** les
lignes `repris`.

### 3.4 Règle d'or (anti « mensonge temporel »)

`v_mandat` reste la **définition de référence** de l'état calculé. Les lignes
`calcule` de `mandat_etat` sont un cache destructible : en cas de divergence,
le calcul gagne et le cache est régénéré. Seules les lignes `repris` sont des
**faits historiques** précieux, à préserver. La colonne `origine` garantit qu'on
ne confond jamais le cache jetable et le fait repris.

## 4. Alternatives écartées

| Option | Rejet |
|---|---|
| Colonne `statut` stockée (ADR-038) | Contredit ADR-030 ; crée le « mensonge temporel » ; a produit la contradiction M3. |
| `expire → resilie` à la migration (ADR-038) | Fige une information calculable ; mélange échu et résilié. |
| Vue matérialisée classique (full refresh) | Recalcule tout, y compris les états terminaux figés ; non scalable inutilement. |
| Projection incrémentale dès maintenant | Sur-architecture : aucun besoin de perf démontré au stade OLTP initial. |

## 5. Conséquences

- **Positives :** cohérence totale avec ADR-030 ; M3 **dissous** (plus de statut à
  contredire) ; mandat réduit à ses faits ; trajectoire de scalabilité tracée.
- **Impacts :** retrait de `mandat.statut` et CHECK associés ; refonte de
  `v_mandat` (5 états calculés) ; migration simplifiée (plus de mapping de statut,
  seuls les `suspendu` source posent une `date_resiliation`) ; index d'unicité du
  mandat actif sur expression calculée ; mise à jour tests/sondes.
- **Limite :** `resilie` + `motif` distingue abandon volontaire et échéance si
  besoin (le motif porte la nuance).

## 6. Rattachement RNCP40573

| Bloc | Contribution |
|---|---|
| BC01 | Doctrine de dérivation appliquée sans compromis ; trajectoire de croissance tracée |
| BC03 | État porté par des vues ; faits seuls stockés ; contraintes sur calcul |
| BC05 | Modèle scalable, cache d'état prêt à activer si la volumétrie l'exige |
