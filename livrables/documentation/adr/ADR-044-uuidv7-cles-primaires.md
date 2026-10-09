# ADR-044 — UUIDv7 pour les clés primaires

> **Statut :** Accepté · **Date :** 2026-10-06 · **Révise :** ADR-028 · **Déclencheur :** revue v8 (point A), exigence SWOT (centaines de millions de lignes).

## 1. Contexte

Les clés primaires sont des UUID (ADR-028). La v8 et antérieures généraient des
**UUIDv4** (aléatoires) via `gen_random_uuid()`. La revue a rappelé un fait que
nos propres documents énonçaient mal : à grande échelle, les UUIDv4 fragmentent
les index B-tree, car chaque insertion tombe à une position aléatoire de l'index
(pages scindées en désordre, écritures dispersées, index qui gonfle, cache moins
efficace). La SWOT du projet annonce des **centaines de millions de lignes** sur
`annonce` et `proposition` : le sujet n'est pas théorique.

Deux imprécisions de nos docs à corriger : (a) `gen_random_uuid()` est **natif
depuis PostgreSQL 13**, il ne dépend pas de l'extension pgcrypto ; (b) `uuidv7()`
est **natif depuis PostgreSQL 18**, pas 16.

## 2. Décision

**Générer des UUIDv7** (ordonnés dans le temps) pour toutes les clés primaires.
Un UUIDv7 commence par un timestamp en millisecondes : les nouvelles lignes
s'insèrent **en fin d'index**, dans l'ordre, comme un auto-incrément, tout en
gardant l'unicité globale de l'UUID. La fragmentation disparaît.

**Le type de colonne reste `uuid`** dans tous les cas — seule la fonction de
génération change. Migrer de v4 à v7 n'est donc **pas** une migration
structurante.

### Implémentation : fonction `uuidv7()` avec repli

PostgreSQL 18 fournit `uuidv7()` nativement. Pour rester compatible avec
PostgreSQL 16/17 (et testable hors PG18), le DDL crée la fonction **seulement si
elle n'existe pas déjà** :

```sql
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='uuidv7') THEN
    CREATE FUNCTION uuidv7() RETURNS uuid AS $f$
      SELECT encode(set_bit(set_bit(
        overlay(uuid_send(gen_random_uuid())
          placing substring(int8send((extract(epoch from clock_timestamp())*1000)::bigint) from 3)
          from 1 for 6), 52,1),53,1),'hex')::uuid;
    $f$ LANGUAGE sql VOLATILE;
  END IF;
END $$;
```

En PG18, la fonction native est utilisée ; en PG16/17, le repli produit un UUIDv7
de même sémantique (48 bits de timestamp ms + version 7 + aléatoire).
L'ordonnancement temporel a été vérifié (UUID générés à quelques ms d'intervalle
sont croissants).

## 3. Alternatives écartées

| Option | Rejet |
|---|---|
| Garder UUIDv4, « on verra en PG18 » | Fragmentation subie dès maintenant sur les grosses tables ; or le changement est sans coût structurel, autant le faire tout de suite (le reviewer a raison sur ce point). |
| UUIDv7 généré **uniquement** côté application | Ne protège pas les insertions faites en SQL direct (migration, scripts, seed). La fonction en base couvre tous les chemins. |
| Clé auto-incrément (bigserial) | Perd l'unicité globale multi-source (rachats) et expose des compteurs ; contraire à ADR-028. |
| Attendre PG18 pour le `uuidv7()` natif seulement | La fonction de repli rend la valeur disponible dès PG16, sans attendre. |

## 4. Conséquences

- **Positives :** index compacts et peu fragmentés sur les tables à forte
  insertion ; moins d'écritures et de maintenance (REINDEX) ; portabilité PG16→18 ;
  migration v4→v7 non structurante (le type ne change pas).
- **Coûts :** une fonction SQL à embarquer tant que PG < 18 ; dépendance à
  `clock_timestamp()` pour l'horodatage (acceptable).
- **Migration de reprise :** les UUID **déterministes v5** utilisés par la
  migration (idempotence) ne changent pas — ils cohabitent avec le `DEFAULT
  uuidv7()` des insertions applicatives, sans conflit.

## 5. Rattachement RNCP40573

| Bloc | Contribution |
|---|---|
| BC01 | Décision de conception argumentée, chiffrée par l'échelle réelle |
| BC03 | Performance d'index traitée au niveau du schéma ; portabilité assurée |
| BC05 | Socle dimensionné pour les volumes annoncés (annonces, propositions) |
