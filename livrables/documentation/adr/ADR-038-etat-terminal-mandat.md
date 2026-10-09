# ADR-038 — État terminal du mandat échu

> ⚠️ **REMPLACÉ par ADR-048** (état du mandat entièrement dérivé). Conservé pour historique.

> **Statut :** Accepté · **Date :** 2026-10-02 · **Renvoi grille :** A7 · **Cohérent :** migration A8.

## 1. Contexte

La review R2-B4 relevait qu'un mandat **arrivé à terme sans vente** n'avait pas de statut cible correct, et que `statut='actif'` pouvait persister (mensonge temporel). Le traitement quotidien devait pouvoir le clôturer.

## 2. Décision — aucun changement de schéma

Un mandat échu sans vente est marqué **`statut = 'resilie'`** avec **`date_resiliation`** et **`motif_resiliation = 'échue'`** — valeurs déjà imposées par la contrainte `ck_mandat_resil`. On **n'ajoute pas** de valeur d'énumération dédiée. Le **traitement quotidien** pose ce statut à l'échéance.

Sémantique : `clos_succes` = vendu ; `resilie` + motif = fin sans succès (échu, ou suspendu repris — cf. migration A8 qui applique le même motif `resilie`).

## 3. Conséquences

- Le cas « échu » a enfin une **cible correcte** ; répond à R2-B4 en mode « détecté » (le job quotidien applique le statut).
- **Limite :** `resilie` regroupe « résilié » et « échu », distingués par le `motif`. Si un comptage propre échu/résilié devient nécessaire, passer le motif en **vocabulaire contrôlé** (ou ajouter une valeur `'echu'`).

**RNCP40573** — BC03 : état du mandat sans ambiguïté ; BC01 : décision et limite tracées.
