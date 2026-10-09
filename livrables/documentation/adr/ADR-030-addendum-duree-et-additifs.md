# Addendum ADR-030 — Durée de mandat constante & additifs internationaux différés

> **Complète :** ADR-030 (« si calculable, ne pas stocker »). **Statut :** Accepté
> **Date :** 2026-10-02 · **Renvoi grille :** C6 (refus) ; C1, C2, C4, C5 (différés).

## 1. C6 — Refus de `duree_mois`

**Décision : ne pas ajouter `mandat.duree_mois`.**

La review R1 proposait une colonne `duree_mois` pour gérer des durées variables à l'international. Or la durée du mandat est une **convention contractuelle de l'entreprise**, fixée à **6 mois** et confirmée par **US 00 @duree-mandat** (« durée de validité de 6 mois, renouvelable »). C'est donc une **constante**, pas une donnée variable — y compris à l'étranger, la convention restant celle de l'entreprise.

Conformément à la doctrine d'**ADR-030** (« si une valeur est une constante/calculable, elle n'a pas à être stockée »), on **ne crée pas** la colonne. `date_fin = signature + 6 mois` reste dérivée (cf. A12 : `date_debut = date_signature`, écart à l'énoncé dissous).

## 2. C1 à C5 — Additifs internationaux différés

Ces additifs sont **rétro-compatibles** (nouvelle colonne `DEFAULT`, domaine élargi, unicité composite) : **les différer ne crée aucune dette** (un simple `ALTER` le jour venu). N'étant pas requis en **mono-pays FR**, ils sont **différés en Phase 3**, où ils accompagneront l'ouverture internationale (voir `ADR-ouverture-internationale.md`).

| ID | Additif | Statut |
|---|---|---|
| C1 | Domaine `d_dpe` → `varchar(3)` (DE/IT) | Différé — *à avancer si l'international est au prochain sprint (recréation de domaine un peu coûteuse)* |
| C2 | `devise` sur `demande_version` + `mandat` (DEFAULT EUR) | Différé |
| C3 | `client.code_iso_pays_residence` (DEFAULT FR) | Différé — **prérequis du design international** (embarqué par son ADR) |
| C4 | `mandat UNIQUE(code_iso_pays, numero_registre)` | Différé (collision inter-filiales aux rachats) |
| C5 | `bien` latitude/longitude (nullable) | Différé (matching IA, Phase 4) |

*(C3 est rappelé ici pour complétude ; il est porté par `ADR-ouverture-internationale.md`.)*

## 3. Conséquences

- Aucun ajout prématuré au schéma ; le socle reste au périmètre FR nécessaire.
- Les évolutions internationales sont **tracées et prêtes**, sans dette.

## 4. Rattachement RNCP40573

BC01 — décisions et reports tracés ; BC03 — cohérence avec la doctrine ADR-030 ; BC05 — évolutivité documentée.
