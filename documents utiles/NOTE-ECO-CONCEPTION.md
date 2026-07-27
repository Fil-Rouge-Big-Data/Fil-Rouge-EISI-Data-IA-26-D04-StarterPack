# 🌱 Note d'éco-conception — modèle

> **Fiche + modèle.** L'éco-conception (ou numérique responsable) vise à **réduire l'impact environnemental** d'un système informatique. C'est un fil rouge du titre RNCP40573, cité dans plusieurs blocs (**BC01, BC03, BC05**). Le projet impose un cas concret : arbitrer les **sauvegardes multi-fréquences**. Voir [`TRACABILITE-COMPETENCES.md`](./TRACABILITE-COMPETENCES.md).

## À quoi ça sert

Le numérique a une empreinte réelle : stockage, calcul, réseau consomment de l'énergie et des ressources. Éco-concevoir, c'est faire des choix techniques qui limitent cette empreinte **sans sacrifier le besoin métier**. Ce n'est pas de l'écologie de façade : c'est aussi souvent moins cher et plus performant.

> 🧠 Le réflexe : pour chaque choix, se demander « ai-je vraiment besoin de stocker/calculer/transférer autant ? ». La donnée la plus verte est celle qu'on ne produit pas.

## Les leviers principaux

* **Sobriété du stockage** : ne pas tout garder indéfiniment ; définir des durées de rétention.
* **Fréquence des traitements** : un rafraîchissement horaire consomme 24× plus qu'un quotidien — est-ce justifié ?
* **Optimisation des requêtes** : une requête bien indexée consomme moins de CPU (lien avec les index).
* **Cycle de vie de la donnée** : archiver le froid, purger l'inutile.

---

## Le cas imposé : les sauvegardes multi-fréquences

Le projet évoque des sauvegardes à la minute / heure / 12 h / 24 h. **Tout sauvegarder, tout le temps, coûte cher et lourd.** Il faut arbitrer.

| Fréquence | Bénéfice | Coût (stockage / énergie) | Justifié pour… |
| --- | --- | --- | --- |
| Chaque minute | perte de données quasi nulle | très élevé | données critiques uniquement (paiements ?) |
| Chaque heure | bon compromis | moyen | données métier importantes |
| Toutes les 12 h | léger | faible | données peu volatiles |
| Toutes les 24 h | minimal | très faible | référentiels, historique |

> À remplir : **quelles données méritent quelle fréquence, et pourquoi ?** Sauvegarder un référentiel de secteurs toutes les minutes n'a aucun sens ; un paiement, peut-être.

---

## Modèle à remplir

### Choix éco-conçus du projet
| Décision | Alternative plus lourde écartée | Gain environnemental |
| --- | --- | --- |
| _(ex. sauvegarde différentielle plutôt que complète)_ | _(sauvegarde complète à chaque fois)_ | _(moins de stockage)_ |
| _…_ | _…_ | _…_ |

### Politique de rétention
_(Combien de temps garde-t-on chaque type de sauvegarde avant purge ?)_

### Arbitrage des sauvegardes
_(Justifiez la fréquence retenue par type de donnée.)_

---

## Méthode pas à pas

1. **Inventorier** ce qui consomme (stockage des sauvegardes, fréquence des traitements, requêtes lourdes).
2. **Questionner chaque poste** : le besoin métier justifie-t-il ce coût ?
3. **Arbitrer** : réduire fréquence/rétention là où l'impact métier est faible.
4. **Documenter** les choix et les gains.

> ⚠️ À l'oral : « pourquoi cette fréquence de sauvegarde ? » est une question piège classique. Votre note d'éco-conception y répond.