# ADR-039 — Gel de la conformité à la signature (snapshot carte T)

> **Statut :** Accepté · **Date :** 2026-10-02 · **Renvoi grille :** A8 · **Coordination :** migration D-FLAG.

## 1. Contexte

`v_conformite_chasseur` lisait la **carte T courante** du chasseur. Conséquence (R2-M7) : un mandat **signé avec une carte T expirée** sortait du contrôle dès que le chasseur renouvelait sa carte — la non-conformité d'époque devenait invisible.

## 2. Décision

**Geler** la conformité à la **signature du mandat** :

- `mandat` : `ADD numero_carte_t_signature`, `ADD validite_carte_t_signature` — copie de la carte T du chasseur **au moment de la signature**.
- `v_conformite_chasseur` : lire la **validité gelée** sur le mandat (et non la carte courante) pour statuer sur `mandat_hors_carte`.

**Coordination :** la migration (D-FLAG) étend la **même vue** avec `est_a_regulariser` (calculé, non stocké). Les deux modifications de `v_conformite_chasseur` doivent être faites **d'un seul tenant**.

## 3. Conséquences

- La conformité réglementaire d'un mandat reste **auditable dans le temps**, indépendamment des renouvellements de carte ultérieurs.
- Cohérent avec la doctrine de gel déjà appliquée à `taux_honoraires` et à la rémunération.

**RNCP40573** — BC03 : conformité réglementaire traçable ; BC05 : cohérence des contrôles dans le temps.
