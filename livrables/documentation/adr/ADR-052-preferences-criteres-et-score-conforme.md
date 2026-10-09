# ADR-052 — Préférences de critères à 4 états & composantes du score conformes à la spec (v8.41)

> **Statut :** Accepté · **Date :** 2026-10-08 · **Complète :** ADR-031, ADR-049 · **Déclencheur :** revues de l'équipe (parsing des négations, composantes du score).

## 1. Contexte

Deux défauts relevés en revue ont été corrigés ensemble dans le patch v8.41 :

1. **Critères du client.** Le modèle codait chaque critère (balcon, jardin…) en booléen
   `exige_X` (2 états). Il ne pouvait pas exprimer « sans balcon » comme un **refus**, ni
   distinguer un **souhait** (« jardin apprécié ») d'une **indifférence**.
2. **Composantes du score.** La v8.4 portait `score_delai, score_reussite,
   score_satisfaction, score_volume, score_anciennete`. La spec (ADR-rémunération)
   définit 5 critères pondérés : **délai 25 · exclusivité 10 · ventes 25 · mandats 15 ·
   visites 25**. La v8.4 en omettait deux (35 % du score), en inventait une
   (`satisfaction`) et dupliquait l'ancienneté (déjà portée par `majoration_anciennete`).
   **Erreur introduite en v8.4** : les noms avaient été posés de mémoire au lieu d'être
   lus dans la spec.

## 2. Décisions

### 2.1 Préférences à 4 états (`d_preference`)
Les 6 booléens `exige_*` de `demande_version` deviennent `pref_*` de domaine
`d_preference ∈ { exige, souhaite, exclut, indifferent }` :

| Intention du client | Valeur | Exemple de formulation |
|---|---|---|
| doit l'avoir | `exige` | « avec balcon » |
| apprécié, non bloquant | `souhaite` | « jardin apprécié », « balcon ou terrasse » |
| refus (critère d'exclusion) | `exclut` | « sans / pas de / aucun balcon » |
| aucune contrainte | `indifferent` | critère absent |

Une seule colonne par critère (pas de doublement en `exclut_*`) : impact modèle minimal,
expressivité complète. Le parser de migration produit ces 4 états ; une exclusion
détectée est **tracée** (anomalie A11) pour requalification humaine.

### 2.2 Composantes du score conformes à la spec
`remuneration_chasseur` porte désormais `score_delai`, `score_exclusivite`,
`score_ventes`, `score_mandats`, `score_visites` (notes 0–100, figées) + le global
`score_performance`. La **pondération** vit dans le moteur de calcul, pas en base.
`score_satisfaction` et `score_anciennete` sont supprimés.

> Le nombre de visites se **compte** (visites réalisées sur 12 mois glissants) au
> calcul ; la table `visite` stocke un événement (1 visiteur, 1 date), aucun compteur.

## 3. Alternatives écartées
| Option | Rejet |
|---|---|
| Booléen `exclut_*` en plus de `exige_*` | Doublement des colonnes ; états incohérents possibles (exige ET exclut). |
| Garder le booléen, traiter « sans X » par simple regex | « sans balcon » deviendrait « indifférent » : le refus serait perdu. |
| Garder les composantes v8.4 | Non conformes à la spec ; 35 % du score absents. |

## 4. Conséquences
- Le matching aval (API, OLAP) lit des `pref_*` à 4 valeurs (et non des booléens) : à
  répercuter côté consommateurs (changement de type de colonne).
- `exclut` permet de **rejeter** un bien (« si balcon, refus ») : sémantique désormais
  portée par la donnée.
- Rémunération reconstituable conformément à la spec.

## 5. Rattachement RNCP40573
BC01 (modèle fidèle au besoin et à la spec), BC03 (domaine contraint, tests), BC05 (données exploitables pour le matching).
