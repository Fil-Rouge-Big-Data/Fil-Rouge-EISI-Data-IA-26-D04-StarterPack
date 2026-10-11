# ADR-030 — Mandat : durée fixe, fin calculée, renouvellement = nouveau mandat

> ℹ️ **Prolongé par ADR-048** (aucun statut de progression stocké) et complété par `ADR-030-addendum-duree-et-additifs.md`. Texte repris du dossier v7 (§8.7, archivé).

**Statut :** Accepté. **Blocs :** BC01 · BC03.

**Contexte.** L'audit du SI hérité a identifié l'anomalie A01 : un `statut` stocké qui contredit les dates (mandat « actif » mais expiré). Le premier réflexe de correction était de matérialiser `date_fin` (colonne générée) et de garder `duree_mois` paramétrable. Or le métier est stable : un mandat de recherche dure **6 mois**, et un renouvellement est juridiquement un **nouvel engagement** au registre Hoguet.

**Décision.** `mandat` ne stocke que `date_debut`. `date_fin`, `est_expire` et `statut_incoherent` sont **calculés en vue `v_mandat`** (durée constante de 6 mois). `duree_mois` et `date_fin` disparaissent comme colonnes. Le renouvellement crée un **nouveau mandat**, relié au précédent par `id_mandat_precedent` (filiation). Application stricte de la règle « si calculé, pas stocké » issue de l'audit.

**Alternatives écartées.**

| Option | Raison du rejet |
|---|---|
| `date_fin` en colonne générée + `duree_mois` | Réintroduit une donnée dérivée dans la table ; `GENERATED` impossible de toute façon (`current_date` non immuable pour l'expiration) |
| `duree_mois` paramétrable (plage 1–24) | Sur-généralise un cas qui n'existe pas : la durée est une constante métier, pas une variable |
| Renouvellement = prolongation de la ligne existante | Effacerait l'historique contractuel ; contraire à la tenue du registre (chaque engagement a son numéro) |

**Conséquences.** L'anomalie A01 devient **structurellement impossible** (ni durée ni fin ne sont saisissables), et non plus seulement corrigée. La filiation `id_mandat_precedent` rend la chaîne des renouvellements lisible pour l'analyse (durée de relation, taux de renouvellement). Validé à l'exécution : `date_fin` et l'incohérence calculées correctement, P7 (renouvellement avec filiation) accepté.
