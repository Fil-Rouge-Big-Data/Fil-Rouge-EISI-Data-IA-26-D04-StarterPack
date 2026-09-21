# 💶 Règles de calcul de la rémunération du chasseur

> **Fiche + modèle.** Le Readme décrit la rémunération du chasseur en trois phrases : honoraires = fixe + pourcentage, barème par tranches variable dans le temps et par chasseur, performance calculée sur cinq critères. Trois phrases ne suffisent pas à écrire une ligne de code ni à modéliser une table. Ce document transforme ces phrases en **algorithme exécutable**, en distinguant systématiquement ce qui est **règle métier** (imposé par le Readme) de ce qui est **paramètre** (valeur qu'il faut trancher).
>
> Spécification exécutable associée : [`user-stories/10_calcul_remuneration_chasseur.feature`](../user-stories/10_calcul_remuneration_chasseur.feature).
> Vocabulaire : [`GLOSSAIRE-METIER.md`](./GLOSSAIRE-METIER.md) · Phase 2 · **BC02 / BC05**

## Sommaire

1. [Pourquoi ce document](#1-pourquoi-ce-document)
2. [Règle métier vs paramètre](#2-règle-métier-vs-paramètre)
3. [Vue d'ensemble du calcul](#3-vue-densemble-du-calcul)
4. [Étape 0 — Le droit à rémunération](#4-étape-0--le-droit-à-rémunération)
5. [Étape 1 — L'assiette : les honoraires](#5-étape-1--lassiette--les-honoraires)
6. [Étape 2 — Le score de performance](#6-étape-2--le-score-de-performance)
7. [Étape 3 — Le taux de tranche](#7-étape-3--le-taux-de-tranche)
8. [Étape 4 — Ancienneté et performance](#8-étape-4--ancienneté-et-performance)
9. [Étape 5 — Le montant et son arrondi](#9-étape-5--le-montant-et-son-arrondi)
10. [Exemple chiffré complet](#10-exemple-chiffré-complet)
11. [Conséquences sur le modèle de données](#11-conséquences-sur-le-modèle-de-données)
12. [Anomalies constatées sur l'existant](#12-anomalies-constatées-sur-lexistant)
13. [Décisions à trancher](#13-décisions-à-trancher)

---

## 1. Pourquoi ce document

Le constat de l'entreprise — « l'organisation actuelle de la base de données ne permet pas de gérer totalement nos besoins métiers » — se vérifie de façon spectaculaire sur la rémunération. La base existante porte la règle dans **une seule colonne** : `utilisateurs.taux_commission DECIMAL(4,2)`. Une colonne ne peut pas exprimer une grille qui varie simultanément **dans le temps**, **par tranche de montant** et **par chasseur**. Tant que la règle n'est pas écrite noir sur blanc, on ne peut ni prouver que le modèle actuel est insuffisant, ni dimensionner le modèle cible.

Ce document sert donc trois usages :

* **Phase 1 (audit)** — étayer le registre d'anomalies avec une démonstration chiffrée, et non une impression.
* **Phase 2 (modèle cible)** — dériver les tables `baremes_commission` et `paiements` de la règle plutôt que l'inverse.
* **Phase 4 (tests)** — alimenter le plan de tests unitaires ; chaque `Règle:` du fichier `.feature` associé devient une suite de cas.

---

## 2. Règle métier vs paramètre

C'est la distinction la plus importante du document. Confondre les deux, c'est présenter en soutenance des chiffres inventés comme des exigences client.

|                 | **Règle métier**                                      | **Paramètre**                                   |
|-----------------|-------------------------------------------------------|-------------------------------------------------|
| Origine         | Le Readme, le glossaire, le client                    | Une décision de conception                      |
| Exemple         | « les honoraires = un montant fixe + un pourcentage » | « le fixe vaut 3 000 € »                        |
| Si on la change | Le métier n'est plus respecté                         | Le calcul reste juste, le résultat change       |
| Où ça vit       | Dans le **code** et le **schéma**                     | Dans une **table de paramètres**, jamais en dur |

**Ce que le Readme impose (non négociable) :**

1. Les honoraires = **montant fixe + pourcentage du prix d'achat**, collectés par le notaire, en sus du prix.
2. La part du chasseur est une **fraction de ces honoraires**, pas du prix du bien.
3. Le barème est **par tranches de montant**, **variable dans le temps**, et **différent par chasseur**.
4. Le taux dépend de l'**ancienneté** et de la **performance** du chasseur.
5. La performance se calcule sur **exactement cinq critères** : délai mandat → acte *arrondi à la semaine inférieure*, exclusivité du mandat, nombre de ventes réussies, nombre de mandats signés, nombre de visites avant achat — **« moins il y en a, plus la rémunération monte »**.
6. Mandat **exclusif** : le chasseur est payé même si le client trouve seul. **Non-exclusif** : il peut ne pas l'être.
7. Le mandat vaut **6 mois**, renouvelable.

**Ce que ce document propose (à valider avec le client) :** toutes les valeurs numériques — le fixe, le pourcentage, les bornes de tranches, les taux, la notation des cinq critères, leurs poids, l'effet de l'ancienneté, l'amplitude de la modulation et les bornes du taux final. Elles sont signalées par la mention *(paramètre)*.

---

## 3. Vue d'ensemble du calcul

```
                acte authentique signé
                          │
         ┌────────────────▼────────────────┐
   0.    │ Droit à rémunération ?          │──── non ──► R = 0
         │ (exclusivité × origine × durée) │
         └────────────────┬────────────────┘
                         oui
                          │
   1.    H  = F + t × P                      assiette (honoraires entreprise)
   2.    S  = Σ poids × note(critère)        score de performance ∈ [0 ; 100]
   3.    r₀ = barème(chasseur, date, P)      taux de la tranche
   4.    r  = borne(r₀ × (1 + a + p))        a = ancienneté, p = performance
   5.    R  = arrondi(r × H)                 rémunération du chasseur
                          │
                          ▼
              valeurs figées dans `paiements`
```

L'ordre n'est pas indifférent : le score `S` est calculé **avant** le taux parce qu'il le module, et tout est calculé **à la date de l'acte** parce que le barème bouge.

---

## 4. Étape 0 — Le droit à rémunération

Aucun montant n'est calculé tant que le droit n'est pas établi. Le Readme croise deux dimensions : l'exclusivité du mandat et l'origine de la vente.

| Origine de la vente            | Mandat **exclusif** | Mandat **non-exclusif** |
|--------------------------------|---------------------|-------------------------|
| Le chasseur a présenté le bien | Rémunéré            | Rémunéré                |
| Le client a trouvé seul        | **Rémunéré**        | **Non rémunéré**        |
| Un chasseur d'une autre agence | *cas impossible*    | Non rémunéré            |

À quoi s'ajoute la condition de validité : `date_fin = date_signature + 6 mois`. Un acte signé après cette date n'ouvre aucun droit, sauf renouvellement du mandat.

> ⚠️ Le Readme écrit « le chasseur **pourra** ne pas être rémunéré » pour le mandat non-exclusif. Ce conditionnel est une **ambiguïté à lever avec le client** : est-ce une absence totale de rémunération, ou une indemnité forfaitaire couvrant le travail effectué ? Nous retenons R = 0 *(paramètre)*, mais le modèle doit prévoir le cas — d'où l'intérêt de stocker le **motif** du droit refusé dans `paiements`.

**Unicité du bénéficiaire** — en non-exclusif, plusieurs chasseurs peuvent travailler pour le même client, mais la vente ne rémunère que « le chasseur à l'origine de la transaction aboutie ». Il n'y a donc **jamais de partage** : la part chasseur va à un seul chasseur, à 100 %.

---

## 5. Étape 1 — L'assiette : les honoraires

$$H = F + t \times P$$

| Symbole | Signification                         | Nature        | Valeur retenue |
|---------|---------------------------------------|---------------|----------------|
| `P`     | Prix d'achat acté                     | donnée        | —              |
| `F`     | Part fixe des honoraires              | *(paramètre)* | **3 000,00 €** |
| `t`     | Part proportionnelle                  | *(paramètre)* | **2,5 %**      |
| `H`     | Honoraires encaissés par l'entreprise | résultat      | —              |

| Prix d'achat `P` | Honoraires `H` | `H` en % du prix |
|-----------------:|---------------:|-----------------:|
|        180 000 € |     7 500,00 € |           4,17 % |
|        250 000 € |     9 250,00 € |           3,70 % |
|        420 000 € |    13 500,00 € |           3,21 % |
|        620 000 € |    18 500,00 € |           2,98 % |
|        800 000 € |    23 000,00 € |           2,88 % |

La part fixe rend les honoraires **dégressifs en pourcentage** : elle protège la rentabilité des petits dossiers, dont le coût de traitement est le même que celui des gros. C'est précisément la raison d'être d'un « fixe + pourcentage » plutôt que d'un pourcentage seul.

**Trois points de vigilance :**

* `F` et `t` sont **versionnés dans le temps**, au même titre que le barème. On applique ceux en vigueur à la date de l'acte.
* Les honoraires sont payés **par l'acquéreur**, **séparément** du prix du bien, et **collectés par le notaire** pour le compte de l'entreprise. Le notaire est le tiers de confiance qui sécurise l'encaissement — il n'intervient pas dans le calcul.
* `H` est un montant **HT**. La TVA et la facturation du chasseur relèvent du cycle de paiement, pas du calcul de la part.

---

## 6. Étape 2 — Le score de performance

Les cinq critères sont **imposés** ; leur notation et leur pondération sont *(paramètres)*. Chaque critère est ramené sur une échelle 0–100 pour que les poids soient comparables entre eux.

Deux critères portent sur **la vente en cours** (transactionnels), trois sur **l'activité du chasseur** — comptés sur **douze mois glissants** précédant la date de l'acte *(paramètre : la fenêtre)*.

| #  | Critère (imposé)                                                      | Portée  | Notation *(paramètre)*                                                         | Poids |
|----|-----------------------------------------------------------------------|---------|--------------------------------------------------------------------------------|------:|
| S₁ | Délai signature du mandat → acte, **arrondi à la semaine inférieure** | vente   | ≤ 12 sem. : 100 · 13-20 : 80 · 21-28 : 60 · 29-36 : 40 · 37-48 : 20 · > 48 : 0 |  25 % |
| S₂ | Mandat exclusif ou non                                                | vente   | exclusif : 100 · non-exclusif : 60                                             |  10 % |
| S₃ | Nombre de ventes réussies                                             | 12 mois | `min(100 ; ventes × 20)`                                                       |  25 % |
| S₄ | Nombre de mandats signés                                              | 12 mois | `min(100 ; mandats × 10)`                                                      |  15 % |
| S₅ | Nombre de visites avant achat                                         | vente   | ≤ 3 : 100 · 4-6 : 80 · 7-9 : 60 · 10-12 : 40 · 13-15 : 20 · > 15 : 0           |  25 % |

$$\text{semaines} = \left\lfloor \frac{\text{date acte} - \text{date signature mandat}}{7} \right\rfloor$$

$$S = 0{,}25\,S_1 + 0{,}10\,S_2 + 0{,}25\,S_3 + 0{,}15\,S_4 + 0{,}25\,S_5$$

**Le sens de variation de S₁ et S₅ est inversé, et c'est voulu.** Le Readme est explicite : « au moins il y en a, au plus la rémunération monte ». Un chasseur qui trouve le bon bien en quatre visites et trois mois a mieux travaillé — pour le client comme pour l'entreprise — que celui qui en a fait visiter vingt en cinq mois. La performance récompense la **justesse du ciblage**, pas le volume d'activité.

**Pourquoi la fenêtre glissante ?** Sans elle, S₃ et S₄ ne feraient que croître avec l'ancienneté : un chasseur ne pourrait jamais voir son score baisser, et l'ancienneté serait comptée deux fois. Les douze mois glissants mesurent l'activité **récente**, l'ancienneté mesure l'expérience — deux choses distinctes.

**Trois interactions à connaître :**

* S₂ **avantage structurellement l'exclusivité** (100 contre 60), ce qui pousse le chasseur à faire signer des mandats exclusifs. C'est un choix d'entreprise assumé — l'exclusivité sécurise sa rémunération. À valider comme tel.
* S₃ et S₄ sont corrélés : un chasseur qui signe beaucoup de mandats vend plus. Une variante consiste à remplacer S₄ par le **taux de transformation** `ventes / mandats`, qui mesure l'efficacité plutôt que le volume. Nous conservons les deux critères séparés pour rester littéralement fidèle au Readme, mais la variante mérite d'être posée au client.
* S₁ et S₅ se dégradent tous deux quand la recherche s'éternise. Ils pèsent ensemble 50 % du score : le modèle est délibérément sévère sur les dossiers qui traînent.

---

## 7. Étape 3 — Le taux de tranche

Le barème est une grille **par tranches de montant**, **datée**, et **rattachée à un chasseur** — les trois dimensions du Readme.

> 🔑 **Le taux s'applique aux honoraires `H`, jamais au prix `P`.** Le Readme définit le barème comme « sa part de ce que paye le client à l'entreprise ». Se tromper d'assiette multiplie le résultat par trente.

| Tranche sur `P`     | `r₀` *(paramètre)* |
|---------------------|-------------------:|
| < 200 000 €         |               30 % |
| 200 000 – 349 999 € |               35 % |
| 350 000 – 499 999 € |               40 % |
| 500 000 – 749 999 € |               45 % |
| ≥ 750 000 €         |               50 % |

**Barème par palier, pas par tranches marginales.** Le scénario `@bareme` dit : « la part reversée correspond à **la** tranche du barème applicable à ce montant ». Un seul taux s'applique donc à la totalité des honoraires, sans découpage à la manière de l'impôt sur le revenu. C'est plus simple à expliquer à un chasseur — et c'est la lecture littérale de la règle.

> ⚠️ **Effet de seuil.** Le barème par palier crée une discontinuité aux bornes : à 349 999 € le taux est de 35 %, à 350 000 € il passe à 40 %. Sur les honoraires correspondants, cela représente un saut d'environ 600 € de rémunération pour 1 € de prix supplémentaire. C'est acceptable ici — le chasseur ne choisit pas le prix du bien, qui se négocie avec le vendeur — mais il faut l'avoir identifié. Un barème progressif le supprimerait, au prix d'un calcul moins lisible.

**Sélection de la ligne applicable :**

```sql
WHERE (chasseur_id = :chasseur OR chasseur_id IS NULL)   -- barème propre, sinon défaut
  AND :date_acte BETWEEN date_debut AND COALESCE(date_fin, '9999-12-31')
  AND :prix      BETWEEN montant_min AND COALESCE(montant_max, 999999999)
ORDER BY chasseur_id DESC   -- le barème nominatif prime sur le barème par défaut
LIMIT 1
```

Deux principes en découlent : un **barème par défaut** couvre tous les chasseurs (`chasseur_id IS NULL`), et un **barème nominatif** le surcharge quand il existe. C'est ce qui permet de négocier une grille avec un chasseur senior sans dupliquer la grille entière pour tout le monde.

---

## 8. Étape 4 — Ancienneté et performance

$$a = \min(2\% \times \text{années révolues} \;;\; 10\%) \qquad \textit{(paramètre)}$$

$$p = \frac{S - 50}{50} \times 20\% \qquad \textit{(paramètre)}$$

$$r = \text{borne}\big(r_0 \times (1 + a + p)\;;\; 20\%\;;\; 60\%\big)$$

| Composante      | Amplitude                     | Rôle                                                           |
|-----------------|-------------------------------|----------------------------------------------------------------|
| `a` ancienneté  | 0 % → +10 % (plafond à 5 ans) | Fidélise, reconnaît l'expérience acquise                       |
| `p` performance | −20 % → +20 %, pivot à S = 50 | Récompense le travail de **cette** vente et l'activité récente |
| bornes          | 20 % ≤ `r` ≤ 60 %             | Garantit une marge à l'entreprise et un plancher au chasseur   |

Ce sont des variations **relatives** : `+6 %` appliqué à un taux de base de 40 % donne 42,4 %, pas 46 %. Les deux effets s'additionnent avant d'être appliqués, ce qui évite qu'un chasseur ancien **et** performant voie ses bonus se composer de façon explosive.

**Le pivot à 50 est le point d'équilibre** : un chasseur exactement moyen touche le taux de sa tranche, ni plus ni moins. Au-dessus il gagne davantage, en dessous il est pénalisé. Le barème reste ainsi lisible : « 40 %, plus ou moins selon toi ».

> 📐 **Sur les bornes.** Avec la grille proposée, le plafond à 60 % **mord** : un chasseur de 5 ans d'ancienneté, au score maximal, sur un bien à 800 000 €, atteindrait 50 % × 1,30 = 65 % et se voit ramené à 60 %. Le plancher à 20 %, lui, **ne mord jamais** : le pire cas possible est 30 % × 0,80 = 24 %. C'est un garde-fou pour l'avenir, pas une contrainte active aujourd'hui — à conserver, car il protège le chasseur si la grille est un jour revue à la baisse.

---

## 9. Étape 5 — Le montant et son arrondi

$$R = \text{arrondi}_{2}\big(r \times H\big)$$

La chaîne d'arrondi doit être fixée explicitement, sinon deux implémentations donneront deux résultats à quelques centimes près — et un chasseur qui recompte trouvera l'écart.

| Grandeur         | Précision                          | Mode           |
|------------------|------------------------------------|----------------|
| Score `S`        | 1 décimale                         | demi supérieur |
| Taux final `r`   | 4 décimales (soit 0,01 point de %) | demi supérieur |
| Rémunération `R` | 2 décimales (centime)              | demi supérieur |

**Aucun arrondi intermédiaire** en dehors de ces trois : on calcule en pleine précision et on arrondit au moment de stocker. La marge de l'entreprise se déduit par différence — `H − R` — et n'est jamais arrondie séparément, sous peine de voir apparaître un centime fantôme.

---

## 10. Exemple chiffré complet

**Situation.** Bruno, 3 ans d'ancienneté, 4 ventes et 9 mandats sur douze mois. Mandat **exclusif** signé le 14/11/2025, acte authentique le 30/07/2026, **5 visites** avant achat, bien acquis **420 000 €**.

| Étape               | Détail du calcul                                   |        Résultat |
|---------------------|----------------------------------------------------|----------------:|
| **0. Droit**        | mandat exclusif, valide, vente issue du dispositif |          ouvert |
| **1. Honoraires**   | `3 000 + 2,5 % × 420 000`                          | **13 500,00 €** |
| S₁ délai            | `⌊258 j / 7⌋` = 36 sem. → tranche 29-36            |              40 |
| S₂ exclusivité      | exclusif                                           |             100 |
| S₃ ventes           | `min(100 ; 4 × 20)`                                |              80 |
| S₄ mandats          | `min(100 ; 9 × 10)`                                |              90 |
| S₅ visites          | 5 → tranche 4-6                                    |              80 |
| **2. Performance**  | `0,25×40 + 0,10×100 + 0,25×80 + 0,15×90 + 0,25×80` |  **73,5 / 100** |
| **3. Tranche**      | 420 000 ∈ [350 000 ; 500 000[                      |            40 % |
| 4a. Ancienneté      | `min(2 % × 3 ; 10 %)`                              |            +6 % |
| 4b. Performance     | `(73,5 − 50) / 50 × 20 %`                          |          +9,4 % |
| **4. Taux final**   | `40 % × (1 + 0,06 + 0,094)` = 40 % × 1,154         |     **46,16 %** |
| **5. Rémunération** | `46,16 % × 13 500`                                 |  **6 231,60 €** |
| Marge entreprise    | `13 500 − 6 231,60`                                |      7 268,40 € |

**Lecture de contrôle.** La rémunération de Bruno représente **1,48 % du prix du bien** (6 231,60 / 420 000). C'est l'ordre de grandeur attendu pour un chasseur, et c'est le chiffre à comparer aux 2,50–3,25 % de la colonne `taux_commission` de la base existante — voir ci-dessous.

---

## 11. Conséquences sur le modèle de données

Chaque règle ci-dessus contraint le modèle cible. Ces contraintes sont à reporter dans le [`MCD-MERISE.md`](./MCD-MERISE.md) et le [`OLTP.md`](./OLTP.md).

**1. `baremes_commission` — les trois dimensions sont des clés, pas des attributs.**

```
baremes_commission (
  id, chasseur_id NULL, date_debut, date_fin NULL,
  montant_min, montant_max NULL, taux
)
```

`chasseur_id NULL` = barème par défaut. `date_fin NULL` = en vigueur. La clé fonctionnelle est le **triplet** (chasseur, période, tranche) : c'est exactement ce qu'une colonne dans `utilisateurs` ne peut pas exprimer.

**2. `parametres_honoraires` — le fixe et le pourcentage sont eux aussi datés.**

```
parametres_honoraires ( id, date_debut, date_fin NULL, montant_fixe, taux_pourcentage )
```

**3. `paiements` — les valeurs doivent être figées, pas recalculables.**

```
paiements (
  id, vente_id, chasseur_id, date_calcul,
  prix_acte, honoraires, score_performance,
  bareme_id, taux_base, majoration_anciennete, modulation_performance, taux_final,
  montant_remuneration, statut, facture_id, date_paiement
)
```

C'est le point le plus important du document. Le barème varie dans le temps : si `paiements` ne stockait que `vente_id` et laissait le montant se recalculer à l'affichage, un changement de grille en 2027 **réécrirait rétroactivement** une rémunération de 2026. Non seulement le montant affiché ne correspondrait plus au virement effectué, mais l'entreprise serait incapable de justifier ses paiements passés lors d'un contrôle. On stocke donc **tous les termes du calcul**, y compris `bareme_id`, afin de pouvoir rejouer et expliquer le calcul des années plus tard.

**4. Les données nécessaires n'existent pas encore.** Le calcul consomme : la date de l'acte, la date de signature du mandat, le nombre de visites de la vente, et l'historique des ventes et mandats sur douze mois. La base existante ne contient que trois tables — `secteurs`, `utilisateurs`, `mandats` — sans `date_fin` de mandat, sans `visites`, sans `ventes`. **Aucun des cinq critères de performance n'est calculable en l'état.** C'est la démonstration la plus directe du constat de l'entreprise.

**5. Accès restreint.** Les montants de rémunération et l'IBAN du chasseur relèvent de l'exigence **ENF-03** du [`CAHIER-DES-CHARGES-TECHNIQUE.md`](./CAHIER-DES-CHARGES-TECHNIQUE.md) : accès limité au chasseur concerné et à son manager. À reporter au [`REGISTRE-RGPD.md`](./REGISTRE-RGPD.md).

---

## 12. Anomalies constatées sur l'existant

À verser au registre d'anomalies de la Phase 1.

| #  | Constat                                                                                                                                                                                                                                                                                                                                                     | Gravité  |
|----|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| A1 | `utilisateurs.taux_commission` est un scalaire unique par chasseur : ni tranche, ni date. Deux des trois dimensions imposées par le métier sont absentes.                                                                                                                                                                                                   | Bloquant |
| A2 | **L'unité du taux est indéterminée.** Sur l'exemple à 420 000 €, un `taux_commission` de 3,25 % appliqué au prix donnerait **13 650 €**, soit *davantage que la totalité des honoraires encaissés* (13 500 €). L'entreprise paierait le chasseur plus qu'elle n'encaisse. La colonne n'est donc ni un % du prix, ni cohérente avec le modèle métier décrit. | Bloquant |
| A3 | Aucune trace des honoraires : ni `montant_fixe`, ni `taux_pourcentage`, ni table de paiements. L'assiette du calcul n'est stockée nulle part.                                                                                                                                                                                                               | Bloquant |
| A4 | `mandats` n'a pas de `date_fin`. La règle des 6 mois est implicite, donc non vérifiable par la base.                                                                                                                                                                                                                                                        | Majeur   |
| A5 | Pas de table `visites` ni `ventes` : trois des cinq critères de performance sont incalculables, et le délai mandat → acte n'a pas de borne finale.                                                                                                                                                                                                          | Bloquant |
| A6 | `taux_commission` est `NULL` pour tous les clients — conséquence du mélange clients/chasseurs dans une table unique. Le champ n'a de sens que pour la moitié des lignes.                                                                                                                                                                                    | Majeur   |

---

## 13. Décisions à trancher

À porter au [`JOURNAL-DE-DECISIONS.md`](./JOURNAL-DE-DECISIONS.md) une fois arbitrées, et à documenter dans la [`MATRICE-DECISION.md`](./MATRICE-DECISION.md) si plusieurs options se valent.

| #  | Question                                                                     | Proposition de ce document                             |
|----|------------------------------------------------------------------------------|--------------------------------------------------------|
| D1 | Quelles valeurs pour `F` et `t` ?                                            | 3 000 € + 2,5 %                                        |
| D2 | Mandat non-exclusif, client trouvant seul : rien, ou indemnité forfaitaire ? | Rien (R = 0), mais motif tracé                         |
| D3 | Barème par palier ou progressif par tranches ?                               | Par palier, conforme à la lettre du scénario `@bareme` |
| D4 | Quelle fenêtre pour les critères de volume ?                                 | 12 mois glissants                                      |
| D5 | Conserver S₃ et S₄ séparés, ou introduire le taux de transformation ?        | Séparés, fidèles au Readme                             |
| D6 | Quels poids pour les cinq critères ?                                         | 25 / 10 / 25 / 15 / 25                                 |
| D7 | Quelle amplitude pour l'ancienneté et la performance ?                       | +10 % max et ±20 %                                     |
| D8 | Le plancher de 20 % doit-il rester alors qu'il ne mord jamais ?              | Oui, garde-fou pour les révisions futures              |
| D9 | Qui peut créer un barème nominatif, et avec quelle validation ?              | À définir dans le [`RACI.md`](./RACI.md)               |

---

## 14. Implémentation de référence en Python

Ce document annonce en introduction qu'il transforme trois phrases en **algorithme exécutable**. Voici cet algorithme. Le module ci-dessous n'est pas du pseudo-code : il s'exécute, et sa suite de tests rejoue **chaque tableau d'exemples** du fichier `.feature` associé. C'est la pièce qui ferme la boucle *Readme → règle → spécification Gherkin → code → test*.

### 14.1 Trois partis pris

**1. `Decimal`, jamais `float`.** Un centime d'écart sur un virement est un litige avec le chasseur. Le §9 impose l'arrondi **au demi supérieur**, qui n'est pas le comportement de `round()` : celui-ci arrondit au pair le plus proche. Sur des honoraires de 5 000,50 € à 25 %, le produit exact vaut 1 250,125 € — `Decimal` retient **1 250,13 €**, `float` retient **1 250,12 €**. L'écart est systématique, pas anecdotique.

**2. Les paramètres sont des données, pas du code.** C'est le §2 appliqué à l'implémentation : aucune valeur numérique métier n'apparaît dans une fonction de calcul. Le fixe, le pourcentage, les tranches, les poids, les bornes vivent tous dans des objets `Parametres*` que l'appelant fournit. Remplacer ces objets par des `SELECT` sur `parametres_honoraires` et `baremes_commission` est un exercice de branchement, pas de réécriture — c'est précisément le test qui prouve que la frontière règle / paramètre a été tenue.

**3. Une fonction pure, dont le résultat est la ligne de `paiements`.** `calculer_remuneration(vente, parametrage)` ne lit rien et n'écrit rien : elle reçoit un état, elle retourne un `Remuneration` qui contient **tous les termes du calcul**. Le §11-3 exige que ces termes soient figés en base ; le type de retour les expose donc un par un, prêts à être insérés.

### 14.2 Le module `remuneration.py`

**Outils et vocabulaire.** Les trois précisions du §9 sont des constantes, et les trois arrondis du calcul sont les trois seuls appels à `arrondi()`.

```python
"""Calcul de la rémunération du chasseur.

Implémentation de référence des règles décrites dans
« documents utiles/REGLES-CALCUL-REMUNERATION.md » et spécifiées dans
« user-stories/10_calcul_remuneration_chasseur.feature ».
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal, ROUND_HALF_UP
from enum import Enum

CENT = Decimal("0.01")      # rémunération : le centime
TAUX = Decimal("0.0001")    # taux : 0,01 point de %
NOTE = Decimal("0.1")       # score : 1 décimale


def arrondi(valeur: Decimal, precision: Decimal) -> Decimal:
    """Arrondi au demi supérieur (§9). Les trois seuls arrondis du calcul."""
    return valeur.quantize(precision, rounding=ROUND_HALF_UP)


class Exclusivite(Enum):
    EXCLUSIF = "exclusif"
    NON_EXCLUSIF = "non-exclusif"


class OrigineVente(Enum):
    CHASSEUR = "le chasseur"
    CLIENT_SEUL = "le client, en dehors du dispositif"
    AUTRE_AGENCE = "un chasseur d'une autre agence"


class MotifRefus(Enum):
    MANDAT_EXPIRE = "mandat échu à la date de l'acte"
    HORS_DISPOSITIF = "mandat non-exclusif et vente hors dispositif"
```

**Les paramètres.** Chaque `dataclass` correspond à une table du §11. `LigneBareme` porte les trois dimensions du Readme — chasseur, période, tranche — comme trois champs, ce qu'une colonne `taux_commission` ne peut structurellement pas faire (anomalie A1).

```python
@dataclass(frozen=True)
class ParametresHonoraires:
    """Table `parametres_honoraires` : H = F + t × P, daté."""
    date_debut: date
    montant_fixe: Decimal
    taux_pourcentage: Decimal
    date_fin: date | None = None


@dataclass(frozen=True)
class LigneBareme:
    """Une ligne de `baremes_commission` : (chasseur, période, tranche) → taux."""
    date_debut: date
    montant_min: Decimal
    taux: Decimal
    montant_max: Decimal | None = None
    date_fin: date | None = None
    chasseur_id: int | None = None      # None = barème par défaut


@dataclass(frozen=True)
class Palier:
    """Borne haute incluse → note. `maximum=None` = tranche ouverte."""
    maximum: Decimal | None
    note: Decimal


@dataclass(frozen=True)
class ParametresPerformance:
    poids_delai: Decimal
    poids_exclusivite: Decimal
    poids_ventes: Decimal
    poids_mandats: Decimal
    poids_visites: Decimal
    paliers_delai: tuple[Palier, ...]        # en semaines
    paliers_visites: tuple[Palier, ...]
    note_exclusif: Decimal
    note_non_exclusif: Decimal
    points_par_vente: Decimal
    points_par_mandat: Decimal
    fenetre_mois: int = 12


@dataclass(frozen=True)
class ParametresModulation:
    taux_par_annee: Decimal        # a = min(taux_par_annee × années ; plafond)
    plafond_anciennete: Decimal
    score_pivot: Decimal
    demi_amplitude_score: Decimal
    amplitude_performance: Decimal
    taux_plancher: Decimal
    taux_plafond: Decimal


@dataclass(frozen=True)
class Parametrage:
    """L'ensemble des paramètres. Une seule source de vérité."""
    honoraires: tuple[ParametresHonoraires, ...]
    bareme: tuple[LigneBareme, ...]
    performance: ParametresPerformance
    modulation: ParametresModulation
```

**L'entrée et la sortie.** `Vente` liste exactement ce que le calcul consomme — et donc ce que la base doit savoir produire. Les quatre derniers champs sont ceux qu'aucune table actuelle ne permet de renseigner (anomalies A4 et A5). `Remuneration` est le miroir de la table `paiements`.

```python
@dataclass(frozen=True)
class Vente:
    chasseur_id: int
    prix_acte: Decimal
    date_acte: date
    date_signature_mandat: date
    date_fin_mandat: date
    exclusivite: Exclusivite
    origine: OrigineVente
    nb_visites: int
    annees_anciennete: int          # années révolues à la date de l'acte
    ventes_12_mois: int             # hors vente en cours
    mandats_12_mois: int


@dataclass(frozen=True)
class Remuneration:
    droit_ouvert: bool
    motif_refus: MotifRefus | None = None
    honoraires: Decimal = Decimal("0.00")
    score_performance: Decimal = Decimal("0.0")
    notes: dict[str, Decimal] = field(default_factory=dict)
    taux_base: Decimal = Decimal("0")
    majoration_anciennete: Decimal = Decimal("0")
    modulation_performance: Decimal = Decimal("0")
    taux_final: Decimal = Decimal("0")
    montant: Decimal = Decimal("0.00")

    @property
    def marge_entreprise(self) -> Decimal:
        """Jamais arrondie séparément (§9) : simple différence."""
        return self.honoraires - self.montant


class BaremeIntrouvable(Exception):
    """Aucune ligne applicable : erreur de paramétrage, pas un cas métier."""
```

**Étape 0 — le droit.** Le refus retourne un **motif**, jamais un simple `False` : le §4 impose de tracer *pourquoi* le droit est fermé, pour pouvoir répondre au chasseur et pour rouvrir le débat de la décision D2 sans perdre l'historique.

```python
def droit_a_remuneration(vente: Vente) -> MotifRefus | None:
    """Retourne le motif de refus, ou None si le droit est ouvert."""
    if vente.date_acte > vente.date_fin_mandat:
        return MotifRefus.MANDAT_EXPIRE
    if vente.exclusivite is Exclusivite.EXCLUSIF:
        return None                            # payé même si le client trouve seul
    if vente.origine is OrigineVente.CHASSEUR:
        return None
    return MotifRefus.HORS_DISPOSITIF
```

**Étapes 1 et 2 — l'assiette et le score.** `note_par_paliers` factorise S₁ et S₅ : deux critères de sens opposé au bon sens commun, une seule mécanique. Changer une grille de notation, c'est changer un tuple de `Palier`, pas une cascade de `if`.

```python
def parametres_honoraires_applicables(
    parametrage: Parametrage, date_acte: date
) -> ParametresHonoraires:
    for p in parametrage.honoraires:
        if p.date_debut <= date_acte and (p.date_fin is None or date_acte <= p.date_fin):
            return p
    raise BaremeIntrouvable(f"aucun paramètre d'honoraires au {date_acte}")


def calculer_honoraires(prix: Decimal, p: ParametresHonoraires) -> Decimal:
    """H = F + t × P."""
    return arrondi(p.montant_fixe + p.taux_pourcentage * prix, CENT)


def note_par_paliers(valeur: Decimal, paliers: tuple[Palier, ...]) -> Decimal:
    """Paliers ordonnés du meilleur au moins bon ; le dernier est ouvert."""
    for palier in paliers:
        if palier.maximum is None or valeur <= palier.maximum:
            return palier.note
    return Decimal(0)


def semaines_ecoulees(debut: date, fin: date) -> int:
    """Délai mandat → acte, arrondi à la semaine inférieure (règle métier)."""
    return (fin - debut).days // 7


def noter_criteres(vente: Vente, p: ParametresPerformance) -> dict[str, Decimal]:
    semaines = Decimal(semaines_ecoulees(vente.date_signature_mandat, vente.date_acte))
    return {
        "delai": note_par_paliers(semaines, p.paliers_delai),
        "exclusivite": (
            p.note_exclusif
            if vente.exclusivite is Exclusivite.EXCLUSIF
            else p.note_non_exclusif
        ),
        "ventes": min(Decimal(100), Decimal(vente.ventes_12_mois) * p.points_par_vente),
        "mandats": min(Decimal(100), Decimal(vente.mandats_12_mois) * p.points_par_mandat),
        "visites": note_par_paliers(Decimal(vente.nb_visites), p.paliers_visites),
    }


def calculer_score(notes: dict[str, Decimal], p: ParametresPerformance) -> Decimal:
    poids = {
        "delai": p.poids_delai,
        "exclusivite": p.poids_exclusivite,
        "ventes": p.poids_ventes,
        "mandats": p.poids_mandats,
        "visites": p.poids_visites,
    }
    return arrondi(sum((notes[c] * poids[c] for c in poids), Decimal(0)), NOTE)
```

**Étapes 3 et 4 — le taux.** `taux_de_tranche` est la transcription ligne à ligne de la requête SQL du §7, tri compris : le barème nominatif prime sur le barème par défaut. Le tri secondaire sur `date_debut` retient la version la plus récente lorsque plusieurs périodes se recouvrent.

```python
def taux_de_tranche(
    parametrage: Parametrage, chasseur_id: int, date_acte: date, prix: Decimal
) -> Decimal:
    """Transcription de la requête SQL du §7 : le nominatif prime sur le défaut."""
    lignes = [
        l
        for l in parametrage.bareme
        if l.chasseur_id in (chasseur_id, None)
        and l.date_debut <= date_acte
        and (l.date_fin is None or date_acte <= l.date_fin)
        and l.montant_min <= prix
        and (l.montant_max is None or prix <= l.montant_max)
    ]
    if not lignes:
        raise BaremeIntrouvable(
            f"aucun barème pour le chasseur {chasseur_id}, {prix} € au {date_acte}"
        )
    lignes.sort(key=lambda l: (l.chasseur_id is not None, l.date_debut), reverse=True)
    return lignes[0].taux


def majoration_anciennete(annees: int, p: ParametresModulation) -> Decimal:
    return min(p.taux_par_annee * Decimal(annees), p.plafond_anciennete)


def modulation_performance(score: Decimal, p: ParametresModulation) -> Decimal:
    return (score - p.score_pivot) / p.demi_amplitude_score * p.amplitude_performance


def taux_final(
    taux_base: Decimal, a: Decimal, pf: Decimal, p: ParametresModulation
) -> Decimal:
    """Variations relatives, additionnées avant application, puis bornées."""
    brut = taux_base * (Decimal(1) + a + pf)
    return arrondi(min(max(brut, p.taux_plancher), p.taux_plafond), TAUX)
```

**L'orchestration.** L'ordre des cinq étapes est une règle métier (§3), pas un détail d'écriture : le score est calculé avant le taux parce qu'il le module, et tout est daté à l'acte. La fonction se lit comme le schéma du §3.

```python
def calculer_remuneration(vente: Vente, parametrage: Parametrage) -> Remuneration:
    motif = droit_a_remuneration(vente)
    if motif is not None:
        return Remuneration(droit_ouvert=False, motif_refus=motif)

    honoraires = calculer_honoraires(
        vente.prix_acte, parametres_honoraires_applicables(parametrage, vente.date_acte)
    )
    notes = noter_criteres(vente, parametrage.performance)
    score = calculer_score(notes, parametrage.performance)

    r0 = taux_de_tranche(parametrage, vente.chasseur_id, vente.date_acte, vente.prix_acte)
    a = majoration_anciennete(vente.annees_anciennete, parametrage.modulation)
    pf = modulation_performance(score, parametrage.modulation)
    r = taux_final(r0, a, pf, parametrage.modulation)

    return Remuneration(
        droit_ouvert=True,
        honoraires=honoraires,
        score_performance=score,
        notes=notes,
        taux_base=r0,
        majoration_anciennete=a,
        modulation_performance=pf,
        taux_final=r,
        montant=arrondi(r * honoraires, CENT),
    )
```

### 14.3 Le paramétrage proposé, isolé du calcul

Tout ce que le §13 laisse à trancher est rassemblé **ici et nulle part ailleurs**. Cette fonction est un jeu d'essai destiné aux tests et aux démonstrations : en production, elle est remplacée par une lecture des tables. Si le client arbitre D1 à 2 500 €, une seule ligne change et aucun test de règle ne bouge — seuls les résultats attendus se déplacent.

```python
def parametrage_par_defaut() -> Parametrage:
    d = Decimal
    debut = date(2026, 1, 1)
    return Parametrage(
        honoraires=(
            ParametresHonoraires(debut, d("3000.00"), d("0.025")),          # D1
        ),
        bareme=(
            LigneBareme(debut, d(0), d("0.30"), d(199999)),                 # D3
            LigneBareme(debut, d(200000), d("0.35"), d(349999)),
            LigneBareme(debut, d(350000), d("0.40"), d(499999)),
            LigneBareme(debut, d(500000), d("0.45"), d(749999)),
            LigneBareme(debut, d(750000), d("0.50")),
        ),
        performance=ParametresPerformance(                                  # D6
            poids_delai=d("0.25"),
            poids_exclusivite=d("0.10"),
            poids_ventes=d("0.25"),
            poids_mandats=d("0.15"),
            poids_visites=d("0.25"),
            paliers_delai=(
                Palier(d(12), d(100)), Palier(d(20), d(80)), Palier(d(28), d(60)),
                Palier(d(36), d(40)), Palier(d(48), d(20)), Palier(None, d(0)),
            ),
            paliers_visites=(
                Palier(d(3), d(100)), Palier(d(6), d(80)), Palier(d(9), d(60)),
                Palier(d(12), d(40)), Palier(d(15), d(20)), Palier(None, d(0)),
            ),
            note_exclusif=d(100),
            note_non_exclusif=d(60),
            points_par_vente=d(20),
            points_par_mandat=d(10),
        ),
        modulation=ParametresModulation(                                    # D7
            taux_par_annee=d("0.02"),
            plafond_anciennete=d("0.10"),
            score_pivot=d(50),
            demi_amplitude_score=d(50),
            amplitude_performance=d("0.20"),
            taux_plancher=d("0.20"),                                        # D8
            taux_plafond=d("0.60"),
        ),
    )
```

### 14.4 Vérification sur l'exemple du §10

```python
from datetime import date
from decimal import Decimal as D

vente = Vente(
    chasseur_id=1, prix_acte=D(420000), date_acte=date(2026, 7, 30),
    date_signature_mandat=date(2025, 11, 14), date_fin_mandat=date(2026, 8, 14),
    exclusivite=Exclusivite.EXCLUSIF, origine=OrigineVente.CHASSEUR,
    nb_visites=5, annees_anciennete=3, ventes_12_mois=4, mandats_12_mois=9,
)
resultat = calculer_remuneration(vente, parametrage_par_defaut())
```

Sortie obtenue :

```text
droit ouvert      : True
honoraires        : 13500.00 EUR
notes             : {'delai': '40', 'exclusivite': '100', 'ventes': '80',
                     'mandats': '90', 'visites': '80'}
score performance : 73.5 / 100
taux de base      : 0.40
anciennete        : 0.06
perf              : 0.0940
taux final        : 0.4616
remuneration      : 6231.60 EUR
marge entreprise  : 7268.40 EUR
```

Ligne pour ligne, c'est le tableau du §10. **Le document et le code ne divergent pas** — et si l'un des deux bouge sans l'autre, un test tombe.

### 14.5 Les tests rejouent le fichier `.feature`

Chaque `Plan du Scénario` du fichier Gherkin devient un `@pytest.mark.parametrize` dont les cas sont **les lignes du tableau d'exemples, recopiées telles quelles**. C'est le lien concret entre la spécification et la Phase 4 : la suite compte 55 cas, tous verts.

```python
@pytest.mark.parametrize("jours, semaines, note", [
    (84, 12, 100), (90, 12, 100), (139, 19, 80),
    (258, 36, 40), (300, 42, 20), (400, 57, 0),
])
def test_critere_delai(jours, semaines, note):
    acte = MANDAT + timedelta(days=jours)
    assert semaines_ecoulees(MANDAT, acte) == semaines
    v = vente_bruno(date_acte=acte, date_fin_mandat=acte)
    assert noter_criteres(v, PARAMS.performance)["delai"] == note


def test_calcul_de_bout_en_bout():
    r = calculer_remuneration(vente_bruno(), PARAMS)
    assert r.honoraires == D("13500.00")
    assert r.score_performance == D("73.5")
    assert r.taux_final == D("0.4616")
    assert r.montant == D("6231.60")
    assert r.marge_entreprise == D("7268.40")
```

| Règle du `.feature` | Fonction testée | Cas |
| --- | --- | ---: |
| `@droit-a-remuneration` | `droit_a_remuneration` | 6 |
| `@assiette` | `calculer_honoraires` | 5 |
| `@performance` | `noter_criteres`, `calculer_score` | 20 |
| `@bareme` | `taux_de_tranche` | 8 |
| `@modulation` | `majoration_anciennete`, `modulation_performance`, `taux_final` | 13 |
| `@montant` | `calculer_remuneration`, `arrondi` | 3 |

### 14.6 Ce que ce module ne fait pas — volontairement

| Hors périmètre                               | Pourquoi, et où cela se traite                                                                                                                                                                          |
|----------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Lire et écrire en base                       | Le calcul reste une fonction pure. La persistance est une couche au-dessus : elle charge le `Parametrage`, appelle la fonction, insère le `Remuneration` dans `paiements`.                              |
| Compter les ventes et mandats sur douze mois | Ce sont deux agrégats SQL sur `ventes` et `mandats`, à écrire une fois les tables créées. Le module les reçoit déjà calculés, ce qui garde la fenêtre glissante (D4) modifiable sans toucher au calcul. |
| Calculer l'ancienneté                        | Dépend de la date d'entrée du chasseur, donnée RH. Le module reçoit un nombre d'années révolues.                                                                                                        |
| Contrôler les droits d'accès                 | Exigence **ENF-03** : le montant et l'IBAN ne sont lisibles que par le chasseur concerné et son manager. Cela relève de la couche applicative, pas du calcul.                                           |
| Décider si le calcul doit être rejoué        | Non : le §11-3 l'interdit. Le résultat est figé à l'acte. Le module se contente de ne rien savoir de l'historique.                                                                                      |

> 💡 **Une conséquence utile pour la Phase 1.** Le type `Vente` est la liste minimale des données d'entrée du calcul. Confronté au schéma existant — trois tables, ni `ventes`, ni `visites`, ni `date_fin` de mandat — il montre qu'**aucune instance de `Vente` n'est constructible aujourd'hui**. L'argument de l'audit cesse d'être une opinion : il devient une dépendance non satisfaite, visible à la compilation.

---

> 🧠 **À retenir pour la soutenance.** Le jury ne vérifiera pas si le fixe vaut 3 000 € ou 2 500 € — c'est un paramètre. Il vérifiera que vous savez **distinguer** ce que le métier impose de ce que vous avez décidé, et que votre modèle de données **découle** de la règle. La table `baremes_commission` avec sa clé (chasseur, période, tranche) et le gel des valeurs dans `paiements` sont les deux points qui prouvent que la règle a été comprise avant d'être modélisée.
