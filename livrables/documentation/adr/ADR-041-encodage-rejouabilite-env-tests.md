# ADR-041 — Encodage, rejouabilité, environnement & traçabilité des tests

> **Statut :** Accepté · **Date :** 2026-10-02 · **Renvoi grille :** A10, A11, F1, F3, F5 (+ F2, F6).

## 1. Contexte

Le livrable visé est une **BDD OLTP fonctionnelle *avec ses tests***. Plusieurs défauts (R2) empêchaient de le garantir : encodage non représentatif, scripts non rejouables, environnement non fonctionnel, et surtout un **harnais de tests qui ne prouvait rien**.

## 2. Décisions

| Réf | Décision |
|---|---|
| **A10** | `docker-compose` : `POSTGRES_INITDB_ARGS="--encoding=UTF8 --locale=C.UTF-8"`. SQL_ASCII cassait l'unicité email `citext` sur les accents (S16) ; le seed sans accents masquait le défaut. |
| **A11** | En-tête DDL **rejouable et transactionnel** : `DROP/CREATE SCHEMA chasse` + `SET search_path` + `BEGIN…COMMIT`. Au 2ᵉ passage, le script échouait (`d_email already exists`, S15). |
| **F1** | **Harnais de tests probant** : `SET CONSTRAINTS ALL IMMEDIATE`, **SQLSTATE / nom de contrainte attendu par test**, **préflight** anti-faux-20/20, exécution via `docker exec`, **traçabilité test → user story**. Driver retenu : **`psycopg`** (expose `pgcode` et `diag.constraint_name`). |
| **F3** | Environnement : arborescence réalignée, devcontainer corrigé, **port hôte ≠ 5433** (conflit avec la stack du cours), mot de passe sorti en `.env`. |
| **F5** | Tests et reprise raisonnent au **25 juillet 2026** (date de référence), jamais sur `current_date`. |
| **F2 / F6** | Propreté doc : renommage des associations `Axx → ASxx`, étiquette C14, **collision de préfixe `Axx`** (grille vs migration) ; alignement **doc ↔ code** (48 index réellement livrés, rôles réels). |

## 3. Conséquences

- La base **tourne telle que livrée** et **se rejoue** sans intervention.
- Les tests deviennent **discriminants** et **tracés vers les US** : la preuve a de la valeur.
- Aucune de ces décisions ne touche la **structure** des tables (hors A10/A11 qui portent sur l'exécution).

**RNCP40573** — BC03 : intégrité prouvée ; BC05 : reproductibilité et traçabilité du livrable.
