# ADR-051 — Scission de l'état du mandat : reprise (OLTP) vs projection (OLAP)

> **Statut :** Accepté · **Date :** 2026-10-07 · **Révise :** ADR-048 §3 · **Fonde :** ADR-025, ADR-036 (frontière OLTP/OLAP).

## 1. Contexte

L'ADR-048 avait introduit une table `mandat_etat(id_mandat, statut, origine, ...)`
avec `origine ∈ {repris, calcule}` pour porter à la fois :
- l'**état repris** à la migration (un succès connu dont l'acte n'a pas été repris) ;
- un futur **cache calculé** (projection de performance pour la lecture à l'échelle).

Une revue d'architecture a relevé que ces deux contenus sont de **natures
opposées** et n'ont pas leur place au même endroit :

| | `repris` | `calcule` |
|---|---|---|
| Nature | donnée **transactionnelle** d'origine | **projection analytique** |
| Recalculable ? | **non** (faits manquants) | **oui** (dérivée de v_mandat) |
| Si on la perd | perte définitive | régénérable |
| Lue par | l'OLTP (v_mandat) | l'analytique |

Loger un cache analytique dans une table OLTP viole la frontière OLTP/OLAP
(ADR-025/036) : l'OLAP dérive de l'OLTP, jamais l'inverse.

## 2. Décision

**Scinder l'ex-`mandat_etat` selon la nature de la donnée.**

### 2.1 OLTP — `mandat_reprise` (le repris seul)
Table OLTP qui ne porte **que** l'état repris : `mandat_reprise(id_mandat,
statut_repris, source, date_reprise)`. Plus de colonne `origine` (la table ne
contient qu'un seul type). C'est une donnée transactionnelle non recalculable,
**lue par `v_mandat`** (si une ligne de reprise existe, elle fait foi ; sinon
l'état est dérivé des faits). `source` trace de quelle reprise elle provient.

### 2.2 OLAP — projection de performance (différée, hors OLTP)
Le volet « cache calculé » (projection de l'état/performance des mandats pour la
lecture analytique à grande échelle) **ne vit pas dans l'OLTP**. Il relève de
l'**OLAP** : une table de faits ou une vue matérialisée, alimentée par un **DAG
Airflow** qui lit l'OLTP (via les vues) et charge l'OLAP. Non construit ici ;
tracé comme chantier du fil OLAP/Airflow.

## 3. Conséquences
- **Positives :** frontière OLTP/OLAP respectée ; modèle OLTP plus honnête (une
  table = une nature) ; `mandat_reprise` plus simple (plus de colonne `origine`).
- **Impacts :** renommage `mandat_etat` → `mandat_reprise` ; `v_mandat`, migration
  et tests adaptés (fait).
- **Règle d'or maintenue :** `v_mandat` reste la définition de référence de l'état
  calculé ; `mandat_reprise` ne porte que l'irremplaçable ; l'OLAP portera le cache.

## 4. Rattachement RNCP40573
BC01 (séparation des responsabilités), BC03 (intégrité, frontière respectée),
BC05 (OLTP propre, projection analytique côté OLAP).
