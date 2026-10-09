# ADR-050 — Migration robuste & multisource (v8.4)

> **Statut :** Accepté · **Date :** 2026-10-07 · **Complète :** (besoin confirmé par le PO : flux régulier de rachats) · **Déclencheur :** revue v8.1.

## 1. Contexte

Le PO a confirmé un **flux récurrent de rachats**. La revue v8.1 a montré que le
pipeline n'était pas prêt : UUID sans préfixe source (collisions), transaction non
atomique, validation non bloquante, et un `DROP SCHEMA staging` qui efface l'audit.

## 2. Décisions

### 2.1 UUID multisource (M1)
Les clés naturelles **locales à une source** (id de mandat, demande, version) sont
préfixées par la source : `uuid5_for("mandat", f"{source}:{id}")`. Deux agences
rachetées ayant chacune un mandat `id=1` ne collisionnent plus. Les clés
**globales** (email, géographie) ne sont pas préfixées (une personne reste la même
entre deux sources).

### 2.2 Transaction unique + journal indépendant (M2)
Les **données** migrées sont chargées dans **une seule transaction** (tout ou
rien). Le **journal** (`migration_run`, `migration_anomalie`) est écrit sur une
**connexion séparée en autocommit** : il **survit** à un rollback des données —
un échec doit laisser une trace « ce run a échoué, voici pourquoi », pas disparaître.
Le dry-run marque le run `dry_run` (plus de run fantôme « en_cours »).

### 2.3 Validation bloquante (M3) — ceinture + bretelles
Deux garde-fous aux mêmes contrôles d'intégrité :
- **SQL** (`40_validate.sql`, `RAISE EXCEPTION` + `ON_ERROR_STOP`) : garantit
  l'arrêt même en exécution manuelle, sans Python.
- **Python** (`_valider_bloquant`) : garantit l'arrêt dans le pipeline, avant commit.
Le léger doublon est assumé : chacun protège à son niveau.

### 2.4 Staging rejouable sans DROP (M4)
`00_staging.sql` est idempotent (`CREATE … IF NOT EXISTS`) et **préserve
l'historique** des runs — essentiel pour l'audit des migrations récurrentes. Un
reset destructif explicite existe à part (`reset_staging.sql`), réservé au dev.

### 2.5 Séparation existant / récurrent (pragmatique)
Le moteur (E-T-L-V, UUID, staging, validation) est commun ; ce qui est propre à
une source (mapping, anomalies, corrections comme A06) est **paramétré par
`sources.yml`** et isolable. Un futur rachat = une section YAML + une adaptation,
sans dupliquer le moteur. La séparation complète en modules `core/`+`sources/` est
différée au 2ᵉ rachat concret.

### 2.6 Parsing des critères (allégé)
Un mot-clé dans un contexte ambigu (« balcon ou terrasse », « jardin apprécié »,
« sans vis-à-vis ») n'est **pas** forcé en exigence ferme (le modèle booléen ne code
pas « apprécié ») : on reste à `false` et on **trace une anomalie** (A11) pour
requalification. On n'invente pas d'exigence.

## 3. Conséquences
- Pipeline prêt pour les rachats récurrents : pas de collision, atomique, auditable.
- Historique de migration préservé ; validation garantie en prod ET en dev.

## 4. Rattachement RNCP40573
BC02 (pilotage, audit, reproductibilité), BC03 (robustesse, intégrité), BC05 (socle pour les reprises).
