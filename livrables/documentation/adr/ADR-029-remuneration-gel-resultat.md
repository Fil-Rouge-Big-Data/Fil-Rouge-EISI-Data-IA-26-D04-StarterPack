# ADR-029 — Rémunération chasseur : gel du résultat, pas de la règle

> ⚠️ **Partiellement remplacé par ADR-049 et ADR-052.** La doctrine « geler le résultat » reste vraie, mais le gel est aujourd'hui complet : toutes les valeurs de calcul sont obligatoires, les cinq composantes du score sont conservées et le barème est une table versionnée (`bareme`, `tranche_bareme`). Les colonnes citées ci-dessous (`montant_part`, `reference_bareme`) sont devenues `montant` et `id_bareme_applique`. Texte repris du dossier v7 (§8.6, archivé).

**Statut :** Accepté (partiellement ouvert : règle de calcul en attente PO). **Blocs :** BC05 · BC02.

**Contexte.** Le Readme décrit une part du chasseur **variable dans le temps, par tranches de montant, et par chasseur** (ancienneté, performance). Sans support, la question métier centrale « combien touche ce chasseur sur cette vente » reste sans réponse — le même trou que la chaîne de valeur reportée à tort (ADR-024). Mais le PO a précisé que la **règle exacte** de calcul reste à définir, et qu'à ce titre elle relève du **calcul** (paramètre), non d'un fait à stocker — seule la **part figée au moment de la vente** doit être conservée.

**Décision.** Une seule table, `remuneration_chasseur`, qui **gèle** la part calculée à la signature de l'acte (`id_acte` → `id_chasseur`, `montant_part`, `date_calcul`, `reference_bareme` en trace). Même doctrine que `observation` (fait daté figé, ADR-025). La **grille de barème par tranches n'est pas modélisée** tant que sa forme n'est pas arrêtée.

**Alternatives écartées.**

| Option | Raison du rejet |
|---|---|
| Trois tables (barème + tranches + gel) tout de suite | Modélise une règle inconnue : risque de structurer à faux, dette immédiate |
| Reporter toute la rémunération en lot 2 | Laisse béant le cœur métier (part du chasseur) ; reproduit l'erreur ADR-024 |
| Colonne `taux_part` sur `chasseur` | Perd les trois variabilités (temps, tranche, chasseur) ; ne fige rien |

**Conséquences.** Le résultat est conservé et opposable dès maintenant (testé — P6) ; quand le PO livrera la règle, `reference_bareme` deviendra soit une FK vers une table de barèmes, soit une trace conservée — **décision différée sans dette structurelle**. Point ouvert n°1 (§9.2) maintenu, mais il ne bloque plus la structure.
