# ⚖️ Matrice de décision — modèle

> **Fiche + modèle.** Une matrice de décision aide à **choisir entre plusieurs options de façon rationnelle et traçable**, en notant chaque option sur des critères pondérés. Le projet en réclame explicitement une en Phase 3 (choix d'architecture, **BC01**), mais elle sert à **tout choix important** que le Readme demande de faire « en conscience ». Voir [`TRACABILITE-COMPETENCES.md`](./TRACABILITE-COMPETENCES.md).

## À quoi ça sert

Quand plusieurs solutions sont possibles (quel type d'architecture ? quel SGBD ? étoile ou flocon ?), décider « au feeling » est risqué et indéfendable devant un jury. La matrice rend le choix **explicite** : on liste les critères qui comptent, on leur donne un poids, on note chaque option, et le total éclaire la décision.

> 🧠 La matrice n'a pas pour but de « calculer » la réponse à votre place. Elle **structure la réflexion** et **garde une trace** du raisonnement — exactement ce que le Readme exige (« les solutions doivent être choisies en conscience »).

---

## Comment ça marche

1. **Lister les options** à comparer (les colonnes).
2. **Lister les critères** de décision (les lignes) : performance, coût, scalabilité, sécurité, éco-conception, complexité…
3. **Pondérer chaque critère** (ex. de 1 = accessoire à 5 = crucial) selon son importance dans CE projet.
4. **Noter chaque option** sur chaque critère (ex. de 1 à 5).
5. **Calculer** : pour chaque case, note × poids ; puis somme par option.
6. **Lire le résultat** — et surtout, **le commenter** : le total n'est qu'un indicateur, la décision finale reste argumentée.

---

## Exemple (choix d'architecture, Phase 3)

> Barème : poids de 1 à 5, note de 1 à 5. Score d'une case = note × poids.

| Critère | Poids | Option A : tout dans une base | Option B : OLTP + OLAP séparés | Option C : microservices |
| --- | --- | --- | --- | --- |
| Performance sous charge | 5 | 2 → 10 | 5 → 25 | 4 → 20 |
| Simplicité de mise en œuvre | 3 | 5 → 15 | 3 → 9 | 1 → 3 |
| Scalabilité internationale | 5 | 1 → 5 | 4 → 20 | 5 → 25 |
| Coût / éco-conception | 3 | 4 → 12 | 3 → 9 | 2 → 6 |
| Sécurité / RGPD | 4 | 2 → 8 | 4 → 16 | 4 → 16 |
| **TOTAL** | | **50** | **79** | **70** |

> Lecture : l'option B l'emporte ici, mais la décision doit être **justifiée** (« on retient B car elle équilibre performance, scalabilité et sécurité sans la complexité des microservices, prématurée à ce stade »).

---

## Modèle vierge à remplir

| Critère | Poids (1-5) | Option 1 | Option 2 | Option 3 |
| --- | --- | --- | --- | --- |
| _…_ | _…_ | _… → …_ | _… → …_ | _… → …_ |
| _…_ | _…_ | | | |
| **TOTAL** | | | | |

**Décision retenue :** _(quelle option, et pourquoi — au-delà du seul score)_

**Options écartées :** _(pourquoi on ne les a pas choisies — le Readme demande d'écarter « en conscience »)_

---

## Autres matrices utiles (variantes)

* **Matrice d'impact / effort** : classer des actions selon leur impact (fort/faible) et l'effort requis (fort/faible) → repérer les « quick wins ».
* **Matrice de faisabilité** : évaluer une option sur faisabilité technique, économique, organisationnelle.

> ⚠️ À l'oral, une matrice de décision est un excellent support : elle montre que vos choix sont **méthodiques et défendables**, pas arbitraires.