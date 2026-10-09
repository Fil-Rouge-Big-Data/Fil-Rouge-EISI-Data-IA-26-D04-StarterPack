# ADR — Alternatives non retenues (refus motivés)

> **Numéro :** proposé ADR-035 · **Statut :** Accepté (décisions de ne pas faire)
> **Date :** 2026-10-02 · **Renvoi grille :** B5, E1, E3, E6.

## 1. Contexte

Les reviews ont proposé des modifications que l'équipe **choisit de ne pas appliquer**. Tracer un **refus motivé** est aussi important qu'une décision positive : cela évite de rouvrir le débat et démontre, en soutenance, que la proposition a été pesée. Fil directeur : **nécessaire et suffisant**, et **ne pas casser un besoin réel**.

## 2. Décisions

| ID | Proposition (review) | Décision | Motif |
|---|---|---|---|
| **B5** | Table `participant_visite` (visite multi-participants) | **Rejetée** | Le chasseur **pré-visite** (US 06), puis le client visite — **sa visite étant implicitement accompagnée du chasseur**. Le modèle enregistre le **visiteur principal** par ligne (`visite.id_visiteur`, FK unique) ; l'accompagnement du chasseur est **implicite** et n'exige pas de table de participants. À rouvrir seulement si des participants multiples explicites deviennent un besoin. |
| **E1** | Supprimer `est_courante` → vue `DISTINCT ON` | **Rejetée** | L'actuel satisfait **déjà** les deux besoins : l'historisation est **intacte** (toutes les versions restent dans `demande_version`) et la lecture de la version courante est **rapide** (index partiel `ux_version_courante`). La vue `DISTINCT ON` **dégraderait** la lecture, fréquente. |
| **E3** | Remplacer `demande.nb_relances` par une table `interaction`/`relance` | **Rejetée** | **Aucune US** ne demande l'historique des relances. On **garde le compteur minimal** `nb_relances`. Nécessaire et suffisant. |
| **E6** | RBAC strict « un email = un rôle » | **Rejetée** | Casserait un **besoin métier réel** : un professionnel peut aussi être client. Contredit **ADR-026** (héritage non exclusif, assumé). La complexité procédurale associée est le prix de ce besoin. |

## 3. Conséquences

- Pas de modification du schéma sur ces points ; le socle reste au **périmètre strictement utile**.
- Chaque refus est **réversible** et documenté (notamment B5 si une visite conjointe devient un vrai besoin).

## 4. Rattachement RNCP40573

BC01 — arbitrages tracés, y compris les décisions négatives ; BC03 — cohérence du modèle préservée (ADR-026).
