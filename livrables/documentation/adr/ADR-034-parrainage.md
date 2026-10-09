# ADR-034 — Parrainage (dispositif complet côté parrain)

> **Statut :** Accepté · **Date :** 2026-10-06 (révise la version v8) · **Source :** Règlement du dispositif de parrainage, Groupe Evoriel, version juin 2026.

## 1. Contexte

La v8 réduisait le parrainage à un unique drapeau `client.frais_dossier_offerts`
côté **filleul**, sans trace du dispositif réel. La revue a relevé l'absence de
source. Le **règlement Evoriel (juin 2026)**, fourni depuis, décrit un dispositif
précis qui récompense le **parrain**, avec un cycle et des conditions cumulatives.
Le modèle doit refléter ce dispositif, pas une version appauvrie.

## 2. Décision

Créer une table `parrainage` portant le dispositif complet, conforme au règlement.

### Points du règlement modélisés

| Règle (article) | Modélisation |
|---|---|
| Parrain = client **ou** prospect, pas collaborateur (art. 2) | `id_parrain → utilisateur` |
| Filleul personne physique, parrainé une seule fois (art. 3) | `id_filleul` + identité déclarée ; `uk_parrainage_filleul_concretise` |
| Déclaration préalable à tout contact (art. 4) | `date_declaration` |
| Durée de validité : vente/gérance 12 mois, syndic 24 mois (art. 5) | `type_contrat`, `date_fin_validite` |
| Produits éligibles : vente, gérance, syndic (art. 8) | `type_contrat CHECK` |
| Concrétisation = acte / prise d'effet / désignation AG (art. 9) | `statut`, `id_mandat_concretise`, `date_concretisation` |
| Rétribution 400 €/mandat, RIB sous 15 j, versement sous 3 mois (art. 10) | `montant_retribution`, `rib_recu`, `date_reception_rib`, `date_versement` |
| Auto-parrainage interdit (art. 12) | `ck_parrainage_pas_auto` |

### Cycle à états (`statut`)

`declare → mandat_signe → concretise → retribue`, plus `expire` (délai de validité
dépassé) et `rejete`. Contraintes : un parrainage `concretise`/`retribue` doit
porter un `id_mandat_concretise` (`ck_parrainage_concret`) ; un `retribue` doit
avoir RIB reçu + versement + montant (`ck_parrainage_retribue`).

> `client.frais_dossier_offerts` est conservé : c'est l'avantage éventuel côté
> filleul, distinct de la rétribution du parrain. Les deux coexistent.

## 3. Alternatives écartées

| Option | Rejet |
|---|---|
| Drapeau `frais_dossier_offerts` seul (v8) | Ne modélise ni le parrain, ni la rétribution, ni le cycle ; non conforme au règlement. |
| Table de liaison sans cycle | Perd les conditions cumulatives et les états (RIB, concrétisation, versement). |
| Gérer le code/token/attribution en base | Hors périmètre OLTP (géré applicativement, cf. règlement art. 4 : formulaire en ligne). |

## 4. Conséquences

- **Positives :** dispositif conforme et traçable ; sonde D2 (auto-parrainage) et
  D2b (rétribution sans conditions) fermées.
- **Coûts :** une table de plus ; le lien concrétisation↔mandat suppose un mandat
  (cohérent : la rétribution suit la signature puis la concrétisation).
- **À valider :** les règles « 3 parrainages/an/parrain » (art. 11) et « conflit =
  premier arrivé » (art. 7) ne sont pas portées par une contrainte de base
  (logique applicative) — backlog si une garantie en base est souhaitée.

## 5. Rattachement RNCP40573

| Bloc | Contribution |
|---|---|
| BC01 | Dispositif métier modélisé depuis une source réelle |
| BC03 | Cycle à états et conditions cumulatives portés par le schéma |
