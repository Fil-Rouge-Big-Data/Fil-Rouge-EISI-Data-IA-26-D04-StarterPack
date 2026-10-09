# ADR-036 — Frontière OLTP / OLAP des indicateurs

> **Statut :** Accepté · **Date :** 2026-10-02 · **Renvoi grille :** A9 · **Fonde :** ADR-025 (séparation OLTP/OLAP).

## 1. Contexte

Plusieurs vues et tables mêlent **état opérationnel** et **indicateurs comparatifs**. Il faut un critère net pour décider ce qui reste dans l'OLTP (vérité opérationnelle) et ce qui relève de l'OLAP (analyse).

## 2. Décision — le critère

> Une **dérivation par ligne** (l'état d'une entité), même calculée, reste **OLTP**. Un **agrégat comparatif** (`avg`/`count … GROUP BY` un acteur, sur une période passée) qui ne pilote aucune transaction est un **KPI → OLAP**.

| Objet | Destination | Raison |
|---|---|---|
| `v_mandat`, `v_mandat_actif`, `v_honoraires`, `v_version_courante`, `v_conformite_chasseur` | **OLTP** | Dérivations par ligne / contrôles opérationnels |
| `v_charge_gestionnaire` (état courant) | **OLTP** | Gate d'affectation (charge instantanée) |
| `v_delai_affectation` (`avg(délai) GROUP BY gestionnaire`) | **OLAP** → `DROP VIEW` (A9) | Mesure comparative, ne pilote rien ; calcul OLAP sur `affectation` historisée |
| `observation` (valeur figée de KPI) | **OLTP si elle sert un paiement** (score de rémunération) ; sinon **OLAP** | Fait figé auditable vs exploitation comparative |
| `indicateur`, `periode`, `objectif` | **OLTP** | Référentiel / cibles (pas des KPI calculés) |
| Classements, tendances, sommes/moyennes | **OLAP** | Agrégats comparatifs |

## 3. Pièges actés

- `current_date` et les **12 mois glissants** utilisés pour **servir un paiement** (score de rémunération figé à l'acte) restent **OLTP**.
- La **valeur par ligne** ne part jamais en OLAP ; seule sa somme/moyenne.
- **`SYS-MIGRATION`** est exclu de toute vue/KPI opérationnel et de l'ETL OLAP (migration D-ROOT).

## 4. Conséquences

Un seul objet quitte le DDL OLTP (`v_delai_affectation`). Le reste est une règle d'**alimentation** : ne pas dupliquer en OLTP ce qui se calcule en OLAP à partir des faits.

**RNCP40573** — BC05 : socle OLTP propre alimentant l'aval sans recalcul rétroactif.
