# Migration des données — Existant → OLTP cible v8

Module de migration du système hérité (schéma `Fil_Rouge_Depart`) vers la base
OLTP cible v8. Conçu **récurrent et paramétrable par source** (ADR-050) : le
premier run traite l'existant ; les rachats futurs réutilisent le même pipeline.

> ⚠️ Entreprise, données et personnages fictifs. Livrable pédagogique (RNCP40573).

---

## 1. Principe : pipeline E-T-L-V idempotent

```
SOURCE (base héritée, lecture seule)
   │  [E] Extract    lecture brute, sans modifier la source
   ▼
   │  [T] Transform  UUID déterministe, parsing des critères,
   │                 décisions de comblement et d'arbitrage
   ▼
OLTP v8 (schéma public)  ← [L] Load : transaction unique, ON CONFLICT DO NOTHING
   │  [V] Validate   contrôles SQL + batterie pytest
   ▼
staging.migration_anomalie   ← journal « zéro déperdition »
staging.migration_run        ← trace d'exécution (idempotence)
```

Trois propriétés tenues par conception :

- **Idempotent** — les UUID cible sont dérivés de façon déterministe des clés
  naturelles source (UUIDv5). Rejouer produit les mêmes UUID → `ON CONFLICT
  DO NOTHING` ne crée aucun doublon. Vérifié par `test_idempotence`.
- **Traçable** — toute sentinelle / décision de reprise est journalisée dans
  `staging.migration_anomalie` (D-FLAG). Rien n'est comblé en silence.
- **Sans perte** — le texte libre des critères, non entièrement structurable,
  est conservé intégral dans `demande_version.commentaire_criteres` (A6).

Les décisions de mapping et d'arbitrage sont documentées dans
`docs/mapping-donnees.md` et `docs/arbitrages-migration.md`.

---

## 2. Prérequis

- PostgreSQL 16 (extensions `citext`, `pg_trgm` — créées par le DDL v8 (pgcrypto retiré, E5-m12)).
- Python 3.12, dépendances dans `requirements.txt` (`psycopg[binary]`, `pytest`, `pyyaml`).
- Deux bases accessibles : la **source** (héritée) et la **cible** (OLTP v8).

Installation des dépendances :

```bash
pip install -r requirements.txt
```

---

## 3. Démarrage rapide (Docker)

Le `docker-compose.yml` à la racine du dépôt monte la cible OLTP v8 **et** la
source héritée, et charge automatiquement les schémas au premier démarrage.

```bash
cp .env.example .env            # ajuster le mot de passe si besoin
docker compose up -d            # démarre postgres-oltp (cible) + postgres-source
# les schémas v8 (cible) et Fil_Rouge_Depart (source) sont chargés au 1er up

# préparer la cible : structures de migration (journal d'anomalies)
psql "$DST_URL" -f migration/sql/00_staging.sql

# jouer la migration
python -m migration.src.run_migration --source historique

# valider
psql "$DST_URL" -f migration/sql/40_validate.sql
pytest migration/tests/
```

En local sans Docker, exporter les variables `SRC_*` / `DST_*` (voir
`.env.example`) puis lancer les mêmes commandes.

---

## 4. Configuration

Le pipeline lit sa configuration dans les variables d'environnement PostgreSQL
standard, préfixées par source :

| Préfixe | Rôle | Exemple |
|---|---|---|
| `SRC_*` | base source (héritée) | `SRC_PGDATABASE=chasse_source` |
| `DST_*` | base cible (OLTP v8) | `DST_PGDATABASE=chasse_v8` |

Voir `.env.example` pour la liste complète. Le label `--source` identifie la
source dans le journal (`staging.migration_run`, `migration_anomalie`) — utile
pour distinguer les runs récurrents (rachats).

---

## 5. Options d'exécution

```bash
python -m migration.src.run_migration --source historique          # run normal
python -m migration.src.run_migration --source historique --dry-run # tout, mais rollback
```

`--dry-run` exécute extract + transform + load puis **annule** (aucune écriture
persistée). Utile pour vérifier volumétries et anomalies avant un vrai run.

---

## 6. Tests

Cinq niveaux (`migration/tests/`) :

| Niveau | Fichier / classe | Base requise |
|---|---|---|
| Unitaires (parser, UUID, statuts) | `TestParser`, `TestUuid`, `TestStatuts` | non |
| Volumétrie | `test_volumetrie` | oui |
| Intégrité (orphelins, chaîne signataire) | `test_aucun_*`, `test_chaine_signataire` | oui |
| Cohérence métier (statuts, sentinelles, root) | `test_statuts_*`, `test_*_regulariser` | oui |
| Idempotence | `test_idempotence` | oui |

Les tests nécessitant une base se **skippent** proprement si aucune base n'est
joignable (utile en CI légère). Le SQL `sql/40_validate.sql` fournit les mêmes
contrôles en pur psql.

La batterie DDL v8 (`sql/run_tests.py`, 20 rejets + 5 valides) reste
indépendante et vérifie que le schéma cible tient — elle n'est pas affectée par
la migration.

---

## 7. Rapport de migration

Chaque run journalise :

- `staging.migration_run` — une ligne par exécution (début, fin, statut,
  lignes insérées, anomalies).
- `staging.migration_anomalie` — une ligne par comblement / décision tracée,
  avec code anomalie (`A02` sentinelles chasseur, `A06` reclassement acquéreur,
  `A07` INSEE enrichi, `T2` mots de passe…).

Exemple de lecture :

```sql
SELECT code_anomalie, count(*) FROM staging.migration_anomalie
GROUP BY code_anomalie ORDER BY 1;
```

---

## 8. Reprise sur erreur / rejouer

Le run est transactionnel : en cas d'échec, la cible est laissée intacte
(rollback) et `migration_run.statut='echec'` porte le message. Comme le pipeline
est idempotent, **rejouer est toujours sûr** : les lignes déjà présentes sont
ignorées (`ON CONFLICT DO NOTHING`).

Pour repartir d'une cible vierge : recharger `sql/01_ddl.sql`,
`sql/02_triggers_vues.sql`, puis `migration/sql/00_staging.sql`.
(En v8, la remontée D-FLAG `est_a_regulariser` et le gel carte T sont
portés directement par `02_triggers_vues.sql` — plus d'extension séparée.)

---

## 9. Ajouter une source rachetée (Phase 3)

1. Rédiger un mapping dédié (sur le modèle de `docs/mapping-donnees.md`).
2. Ajouter un extracteur si la source n'est pas PostgreSQL (le reste du pipeline
   est inchangé : la cible v8 est fixe).
3. Lancer avec un `--source <nom>` distinct : le journal et les UUID déterministes
   garantissent l'absence de collision entre sources.

---

## 10. Limites connues / points ouverts

- Le référentiel INSEE (`_INSEE_REF`) couvre les communes du jeu existant ; en
  production, le remplacer par une table COG complète.
- Les points « Métier » des arbitrages (A2, A3, A7, A8, A9) sont des défauts de
  migration à contresigner (voir `docs/arbitrages-migration.md` §6).
- Le comportement bloquant lié à `est_a_regulariser` (D-FLAG) est une règle
  **applicative** (backend), hors périmètre de ce module.

---

## 11. Rattachement RNCP40573

| Bloc | Contribution |
|---|---|
| **BC01** | Cartographie existant→cible, décisions tracées |
| **BC02** | Pipeline reproductible, journal d'anomalies, runs récurrents |
| **BC03** | Respect strict des contraintes du DDL cible ; tests automatisés |
| **BC05** | Socle OLTP peuplé, cohérent et traçable pour l'aval (OLAP/BI/IA) |
