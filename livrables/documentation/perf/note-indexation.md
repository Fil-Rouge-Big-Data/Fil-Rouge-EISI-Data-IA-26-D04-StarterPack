# Note d'indexation — EXPLAIN avant / après (socle v8.42)

> **Livrable BC05** (grille : « note d'indexation, EXPLAIN avant/après : 1 page + captures »). Générée le 11/10/2026 par `livrables/db/perf/mesurer_index.py` sur PostgreSQL 16.15 (Debian 16.15-1.pgdg13+2) on x86_64-pc-linux-gnu. Jeu de volume synthétique `perf/01_jeu_volume.sql` ; index proposés `perf/02_index.sql`.

## Méthode

1. Jeu de données synthétique et **valide** (toutes les contraintes et déclencheurs du socle s'appliquent) : 202 `chasseur`, 20001 `mandat`, 100001 `bien`, 100001 `annonce`, 60001 `proposition`, 120000 `visite`, 6001 `acte`, 6001 `remuneration_chasseur`.
2. Quatre requêtes représentatives des usages : état des mandats d'un chasseur, critères du barème sur 12 mois, matching d'annonces, comptage des rendez-vous (D10).
3. Pour chaque requête, `EXPLAIN (ANALYZE, BUFFERS)` **sans** les index proposés (seules les clés primaires et unicités existent : PostgreSQL n'indexe pas les clés étrangères), puis **avec**. Meilleure de 3 exécutions, cache chaud, `ANALYZE` à jour.
4. Principe d'éco-conception (ENF-26) : un index n'est créé que si une requête le justifie ; index partiels quand le filtre est stable (`statut = 'active'`, `realisee`).

## Résultats

| Requête | Avant index | Après index | Après index + `random_page_cost = 1.1` | Gain (meilleur cas) | Blocs lus avant → après | Nœud racine avant → après |
|---|---|---|---|---|---|---|
| **Q1** Mandats actifs d'un chasseur (vue v_mandat : état dérivé  chaîne de vente) | 2977.57 ms | 55.42 ms | 63.73 ms | × 54 | 130 415 → 3 078 | Bitmap Heap Scan on mandat m → Bitmap Heap Scan on mandat m |
| **Q2** Ventes rémunérées et mandats signés d'un chasseur sur 12 mois (critères S3 et S4 du barème) | 6.40 ms | 0.19 ms | 0.17 ms | × 39 | 585 → 26 | Result → Result |
| **Q3** Matching : annonces actives d'une zone  d'un type et d'un budget  les 50 moins chères | 48.48 ms | 60.90 ms | 17.98 ms | × 3 | 2 616 → 2 465 | Limit → Limit |
| **Q4** D10 : rendez-vous de visite d'un mandat (ADR-049 §5  calcul du critère S5) | 72.58 ms | 0.23 ms | 0.20 ms | × 359 | 2 347 → 27 | Aggregate → Aggregate |

## Index retenus

| Index | Requête | Justification |
|---|---|---|
| `ix_mandat_chasseur_signature` (id_chasseur, date_signature) | Q1, Q2 | accès par chasseur puis par date ; évite le parcours de toute la table des mandats |
| `ix_remuneration_chasseur_date` (id_chasseur, date_calcul) | Q2 | critère S3 : ventes du chasseur sur 12 mois glissants |
| `ix_bien_zone_type` (id_zone, type_bien) | Q3 | matching : les biens d'une zone et d'un type |
| `ix_annonce_active_bien_prix` (id_bien, prix) **partiel** `statut = 'active'` | Q3 | seules les annonces actives sont candidates ; index petit et toujours pertinent |
| `ix_proposition_mandat` (id_mandat) | Q1, Q4 | clé étrangère la plus parcourue (mandat → propositions), non indexée par défaut |
| `ix_visite_proposition_date` (id_proposition, date_visite) **partiel** `realisee` | Q4 | rendez-vous réalisés d'une proposition (D10) |
| `ix_offre_proposition` (et l'index UNIQUE existant de `compromis.id_offre`) | Q1 | chaîne de vente remontée par `v_acte_mandat` et `v_mandat` |

## Ce qu'il faut retenir

- Ces index font partie du socle depuis la v8.43 (`01_ddl.sql`) ; le script les retire avant la mesure « avant » puis les recrée.
- Les gains les plus nets viennent des **clés étrangères non indexées** : sans index, chaque jointure parent → enfants balaie la table enfant entière.
- Les **index partiels** répondent à une requête précise avec un coût d'écriture et de stockage réduit (ENF-26).
- **Coût des index** : chaque insertion de proposition, visite ou annonce met à jour un index de plus ; sur les volumes cibles (5 000 mandats par semaine, ENF-03), le partitionnement par date des annonces et propositions (PO-15) est la suite logique, à chiffrer dans la note 3V.
- **Le gain de Q3 dépend du réglage** : avec les index seuls, Q3 passe de 48 à 61 ms (plus lent) ; c'est `random_page_cost = 1.1` qui la fait tomber à 18 ms. Ce réglage est à revalider sur les données réelles et sur plusieurs requêtes avant d'être posé en production (revue de la PR #16).
- **Réglage du planificateur** : `random_page_cost` vaut 4 par défaut (disque mécanique). Sur stockage SSD (bases managées de l'étude), 1.1 rend les accès par index moins chers aux yeux du planificateur ; c'est ce qui fait basculer Q3 d'une jointure par hachage avec parcours complet des annonces vers des boucles imbriquées sur index. À poser dans la configuration de l'instance, pas dans les requêtes.
- Limite : jeu synthétique uniforme (distribution régulière des biens par zone, des mandats par chasseur). Sur des données réelles, les statistiques (`ANALYZE`) et la sélectivité changent ; les index sont à **revalider** sur les données de production.

## Plans d'exécution

### Q1 — Mandats actifs d'un chasseur (vue v_mandat : état dérivé, chaîne de vente)

```sql
SELECT id_mandat, date_fin, statut_calcule FROM v_mandat WHERE id_chasseur = :chasseur AND statut_calcule = 'actif'
```

<details><summary>Plan avant index</summary>

```
Bitmap Heap Scan on mandat m  (cost=1338.30..4944.20 rows=1 width=52) (actual time=1390.234..2977.449 rows=10 loops=1)
  Recheck Cond: (id_chasseur = '0099593b-13ae-5365-c243-9088b1ad8862'::uuid)
  Filter: (COALESCE((SubPlan 4), CASE WHEN (date_resiliation IS NOT NULL) THEN 'resilie'::text WHEN f_mandat_clos_par_acte(id_mandat) THEN 'clos_succes'::text WHEN (SubPlan 5) THEN 'renouvele'::text WHEN (((date_debut + '6 mons'::interval))::date >= COALESCE((NULLIF(current_setting('chasse.date_reference'::text, true), ''::text))::date, CURRENT_DATE)) THEN 'actif'::text ELSE 'echu'::text END) = 'actif'::text)
  Rows Removed by Filter: 90
  Heap Blocks: exact=100
  Buffers: shared hit=130415
  ->  Bitmap Index Scan on uk_mandat_chasseur  (cost=0.00..1338.29 rows=100 width=0) (actual time=1.288..1.289 rows=100 loops=1)
        Index Cond: (id_chasseur = '0099593b-13ae-5365-c243-9088b1ad8862'::uuid)
        Buffers: shared hit=150
  SubPlan 1
    ->  Seq Scan on mandat_reprise mr  (cost=0.00..0.00 rows=1 width=32) (actual time=0.006..0.006 rows=0 loops=10)
          Filter: (id_mandat = m.id_mandat)
  SubPlan 2
    ->  Index Only Scan using uk_mandat_precedent on mandat s  (cost=0.29..8.30 rows=1 width=0) (actual time=0.015..0.015 rows=0 loops=10)
          Index Cond: (id_mandat_precedent = m.id_mandat)
          Heap Fetches: 0
          Buffers: shared hit=20
  SubPlan 4
    ->  Seq Scan on mandat_reprise mr_1  (cost=0.00..0.00 rows=1 width=32) (actual time=0.001..0.001 rows=0 loops=100)
          Filter: (id_mandat = m.id_mandat)
  SubPlan 5
    ->  Index Only Scan using uk_mandat_precedent on mandat s_1  (cost=0.29..8.30 rows=1 width=0) (actual time=0.014..0.014 rows=0 loops=70)
          Index Cond: (id_mandat_precedent = m.id_mandat)
          Heap Fetches: 0
          Buffers: shared hit=140
Planning:
  Buffers: shared hit=2
Planning Time: 0.906 ms
Execution Time: 2977.566 ms
```

</details>

<details><summary>Plan après index</summary>

```
Bitmap Heap Scan on mandat m  (cost=5.04..3610.94 rows=1 width=52) (actual time=44.199..55.354 rows=10 loops=1)
  Recheck Cond: (id_chasseur = '0099593b-13ae-5365-c243-9088b1ad8862'::uuid)
  Filter: (COALESCE((SubPlan 4), CASE WHEN (date_resiliation IS NOT NULL) THEN 'resilie'::text WHEN f_mandat_clos_par_acte(id_mandat) THEN 'clos_succes'::text WHEN (SubPlan 5) THEN 'renouvele'::text WHEN (((date_debut + '6 mons'::interval))::date >= COALESCE((NULLIF(current_setting('chasse.date_reference'::text, true), ''::text))::date, CURRENT_DATE)) THEN 'actif'::text ELSE 'echu'::text END) = 'actif'::text)
  Rows Removed by Filter: 90
  Heap Blocks: exact=100
  Buffers: shared hit=3078
  ->  Bitmap Index Scan on ix_mandat_chasseur_signature  (cost=0.00..5.04 rows=100 width=0) (actual time=0.021..0.021 rows=100 loops=1)
        Index Cond: (id_chasseur = '0099593b-13ae-5365-c243-9088b1ad8862'::uuid)
        Buffers: shared hit=2
  SubPlan 1
    ->  Seq Scan on mandat_reprise mr  (cost=0.00..0.00 rows=1 width=32) (actual time=0.001..0.001 rows=0 loops=10)
          Filter: (id_mandat = m.id_mandat)
  SubPlan 2
    ->  Index Only Scan using uk_mandat_precedent on mandat s  (cost=0.29..8.30 rows=1 width=0) (actual time=0.002..0.002 rows=0 loops=10)
          Index Cond: (id_mandat_precedent = m.id_mandat)
          Heap Fetches: 0
          Buffers: shared hit=20
  SubPlan 4
    ->  Seq Scan on mandat_reprise mr_1  (cost=0.00..0.00 rows=1 width=32) (actual time=0.001..0.001 rows=0 loops=100)
          Filter: (id_mandat = m.id_mandat)
  SubPlan 5
    ->  Index Only Scan using uk_mandat_precedent on mandat s_1  (cost=0.29..8.30 rows=1 width=0) (actual time=0.002..0.002 rows=0 loops=70)
          Index Cond: (id_mandat_precedent = m.id_mandat)
          Heap Fetches: 0
          Buffers: shared hit=140
Planning:
  Buffers: shared hit=2
Planning Time: 0.730 ms
Execution Time: 55.421 ms
```

</details>

<details><summary>Plan après index, random_page_cost = 1.1</summary>

```
Index Scan using ix_mandat_chasseur_signature on mandat m  (cost=0.29..2882.42 rows=1 width=52) (actual time=55.094..63.636 rows=10 loops=1)
  Index Cond: (id_chasseur = '0099593b-13ae-5365-c243-9088b1ad8862'::uuid)
  Filter: (COALESCE((SubPlan 4), CASE WHEN (date_resiliation IS NOT NULL) THEN 'resilie'::text WHEN f_mandat_clos_par_acte(id_mandat) THEN 'clos_succes'::text WHEN (SubPlan 5) THEN 'renouvele'::text WHEN (((date_debut + '6 mons'::interval))::date >= COALESCE((NULLIF(current_setting('chasse.date_reference'::text, true), ''::text))::date, CURRENT_DATE)) THEN 'actif'::text ELSE 'echu'::text END) = 'actif'::text)
  Rows Removed by Filter: 90
  Buffers: shared hit=3078
  SubPlan 1
    ->  Seq Scan on mandat_reprise mr  (cost=0.00..0.00 rows=1 width=32) (actual time=0.001..0.001 rows=0 loops=10)
          Filter: (id_mandat = m.id_mandat)
  SubPlan 2
    ->  Index Only Scan using uk_mandat_precedent on mandat s  (cost=0.29..2.51 rows=1 width=0) (actual time=0.002..0.003 rows=0 loops=10)
          Index Cond: (id_mandat_precedent = m.id_mandat)
          Heap Fetches: 0
          Buffers: shared hit=20
  SubPlan 4
    ->  Seq Scan on mandat_reprise mr_1  (cost=0.00..0.00 rows=1 width=32) (actual time=0.001..0.001 rows=0 loops=100)
          Filter: (id_mandat = m.id_mandat)
  SubPlan 5
    ->  Index Only Scan using uk_mandat_precedent on mandat s_1  (cost=0.29..2.51 rows=1 width=0) (actual time=0.002..0.002 rows=0 loops=70)
          Index Cond: (id_mandat_precedent = m.id_mandat)
          Heap Fetches: 0
          Buffers: shared hit=140
Planning:
  Buffers: shared hit=2
Planning Time: 0.714 ms
Execution Time: 63.729 ms
```

</details>

### Q2 — Ventes rémunérées et mandats signés d'un chasseur sur 12 mois (critères S3 et S4 du barème)

```sql
SELECT (SELECT count(*) FROM remuneration_chasseur WHERE id_chasseur = :chasseur AND date_calcul >= :d12 AND date_annulation IS NULL) AS ventes, (SELECT count(*) FROM mandat WHERE id_chasseur = :chasseur AND date_signature >= :d12) AS mandats
```

<details><summary>Plan avant index</summary>

```
Result  (cost=975.22..975.23 rows=1 width=16) (actual time=6.333..6.337 rows=1 loops=1)
  Buffers: shared hit=585
  InitPlan 1 (returns $0)
    ->  Aggregate  (cost=230.07..230.08 rows=1 width=8) (actual time=2.584..2.586 rows=1 loops=1)
          Buffers: shared hit=140
          ->  Seq Scan on remuneration_chasseur  (cost=0.00..230.01 rows=21 width=0) (actual time=0.193..2.571 rows=21 loops=1)
                Filter: ((date_annulation IS NULL) AND (date_calcul >= '2025-10-11'::date) AND (id_chasseur = '0099593b-13ae-5365-c243-9088b1ad8862'::uuid))
                Rows Removed by Filter: 5980
                Buffers: shared hit=140
  InitPlan 2 (returns $1)
    ->  Aggregate  (cost=745.14..745.15 rows=1 width=8) (actual time=3.736..3.737 rows=1 loops=1)
          Buffers: shared hit=445
          ->  Seq Scan on mandat  (cost=0.00..745.01 rows=49 width=0) (actual time=0.111..3.715 rows=49 loops=1)
                Filter: ((date_signature >= '2025-10-11'::date) AND (id_chasseur = '0099593b-13ae-5365-c243-9088b1ad8862'::uuid))
                Rows Removed by Filter: 19952
                Buffers: shared hit=445
Planning Time: 0.288 ms
Execution Time: 6.397 ms
```

</details>

<details><summary>Plan après index</summary>

```
Result  (cost=71.60..71.61 rows=1 width=16) (actual time=0.126..0.129 rows=1 loops=1)
  Buffers: shared hit=26
  InitPlan 1 (returns $0)
    ->  Aggregate  (cost=62.19..62.20 rows=1 width=8) (actual time=0.089..0.091 rows=1 loops=1)
          Buffers: shared hit=23
          ->  Bitmap Heap Scan on remuneration_chasseur  (cost=4.50..62.13 rows=21 width=0) (actual time=0.039..0.083 rows=21 loops=1)
                Recheck Cond: ((id_chasseur = '0099593b-13ae-5365-c243-9088b1ad8862'::uuid) AND (date_calcul >= '2025-10-11'::date))
                Filter: (date_annulation IS NULL)
                Heap Blocks: exact=21
                Buffers: shared hit=23
                ->  Bitmap Index Scan on ix_remuneration_chasseur_date  (cost=0.00..4.49 rows=21 width=0) (actual time=0.026..0.026 rows=21 loops=1)
                      Index Cond: ((id_chasseur = '0099593b-13ae-5365-c243-9088b1ad8862'::uuid) AND (date_calcul >= '2025-10-11'::date))
                      Buffers: shared hit=2
  InitPlan 2 (returns $1)
    ->  Aggregate  (cost=9.39..9.40 rows=1 width=8) (actual time=0.032..0.033 rows=1 loops=1)
          Buffers: shared hit=3
          ->  Index Only Scan using ix_mandat_chasseur_signature on mandat  (cost=0.29..9.27 rows=49 width=0) (actual time=0.013..0.024 rows=49 loops=1)
                Index Cond: ((id_chasseur = '0099593b-13ae-5365-c243-9088b1ad8862'::uuid) AND (date_signature >= '2025-10-11'::date))
                Heap Fetches: 0
                Buffers: shared hit=3
Planning Time: 0.257 ms
Execution Time: 0.188 ms
```

</details>

<details><summary>Plan après index, random_page_cost = 1.1</summary>

```
Result  (cost=26.82..26.83 rows=1 width=16) (actual time=0.110..0.112 rows=1 loops=1)
  Buffers: shared hit=26
  InitPlan 1 (returns $0)
    ->  Aggregate  (cost=23.21..23.22 rows=1 width=8) (actual time=0.081..0.082 rows=1 loops=1)
          Buffers: shared hit=23
          ->  Bitmap Heap Scan on remuneration_chasseur  (cost=1.60..23.16 rows=21 width=0) (actual time=0.035..0.075 rows=21 loops=1)
                Recheck Cond: ((id_chasseur = '0099593b-13ae-5365-c243-9088b1ad8862'::uuid) AND (date_calcul >= '2025-10-11'::date))
                Filter: (date_annulation IS NULL)
                Heap Blocks: exact=21
                Buffers: shared hit=23
                ->  Bitmap Index Scan on ix_remuneration_chasseur_date  (cost=0.00..1.59 rows=21 width=0) (actual time=0.022..0.023 rows=21 loops=1)
                      Index Cond: ((id_chasseur = '0099593b-13ae-5365-c243-9088b1ad8862'::uuid) AND (date_calcul >= '2025-10-11'::date))
                      Buffers: shared hit=2
  InitPlan 2 (returns $1)
    ->  Aggregate  (cost=3.59..3.60 rows=1 width=8) (actual time=0.025..0.025 rows=1 loops=1)
          Buffers: shared hit=3
          ->  Index Only Scan using ix_mandat_chasseur_signature on mandat  (cost=0.29..3.47 rows=49 width=0) (actual time=0.011..0.018 rows=49 loops=1)
                Index Cond: ((id_chasseur = '0099593b-13ae-5365-c243-9088b1ad8862'::uuid) AND (date_signature >= '2025-10-11'::date))
                Heap Fetches: 0
                Buffers: shared hit=3
Planning Time: 0.324 ms
Execution Time: 0.165 ms
```

</details>

### Q3 — Matching : annonces actives d'une zone, d'un type et d'un budget, les 50 moins chères

```sql
SELECT a.id_annonce, a.prix FROM annonce a JOIN bien b ON b.id_bien = a.id_bien WHERE b.id_zone = :zone AND b.type_bien = 'appartement' AND a.statut = 'active' AND a.prix BETWEEN 200000 AND 350000 ORDER BY a.prix LIMIT 50
```

<details><summary>Plan avant index</summary>

```
Limit  (cost=5481.47..5487.22 rows=50 width=21) (actual time=42.509..48.365 rows=50 loops=1)
  Buffers: shared hit=2616
  ->  Gather Merge  (cost=5481.47..5497.23 rows=137 width=21) (actual time=42.506..48.355 rows=50 loops=1)
        Workers Planned: 1
        Workers Launched: 1
        Buffers: shared hit=2616
        ->  Sort  (cost=4481.46..4481.80 rows=137 width=21) (actual time=37.193..37.202 rows=50 loops=2)
              Sort Key: a.prix
              Sort Method: top-N heapsort  Memory: 30kB
              Buffers: shared hit=2616
              Worker 0:  Sort Method: top-N heapsort  Memory: 30kB
              ->  Parallel Hash Join  (cost=1990.96..4476.91 rows=137 width=21) (actual time=10.519..36.911 rows=166 loops=2)
                    Hash Cond: (a.id_bien = b.id_bien)
                    Buffers: shared hit=2578
                    ->  Parallel Seq Scan on annonce a  (cost=0.00..2458.42 rows=10486 width=37) (actual time=0.032..24.061 rows=8750 loops=2)
                          Filter: (((prix)::numeric >= '200000'::numeric) AND ((prix)::numeric <= '350000'::numeric) AND (statut = 'active'::text))
                          Rows Removed by Filter: 41250
                          Buffers: shared hit=1429
                    ->  Parallel Hash  (cost=1981.36..1981.36 rows=768 width=16) (actual time=9.609..9.610 rows=666 loops=2)
                          Buckets: 2048  Batches: 1  Memory Usage: 112kB
                          Buffers: shared hit=1099
                          ->  Parallel Seq Scan on bien b  (cost=0.00..1981.36 rows=768 width=16) (actual time=0.050..8.892 rows=666 loops=2)
                                Filter: ((id_zone = '13ab0dd2-aa8e-5e78-a3c3-e16c2f02c92a'::uuid) AND (type_bien = 'appartement'::text))
                                Rows Removed by Filter: 49334
                                Buffers: shared hit=1099
Planning:
  Buffers: shared hit=16
Planning Time: 0.545 ms
Execution Time: 48.479 ms
```

</details>

<details><summary>Plan après index</summary>

```
Limit  (cost=4452.39..4452.52 rows=50 width=21) (actual time=60.785..60.802 rows=50 loops=1)
  Buffers: shared hit=2462 read=3
  ->  Sort  (cost=4452.39..4453.02 rows=249 width=21) (actual time=60.781..60.791 rows=50 loops=1)
        Sort Key: a.prix
        Sort Method: top-N heapsort  Memory: 30kB
        Buffers: shared hit=2462 read=3
        ->  Hash Join  (cost=1217.82..4444.12 rows=249 width=21) (actual time=4.303..60.349 rows=332 loops=1)
              Hash Cond: (a.id_bien = b.id_bien)
              Buffers: shared hit=2462 read=3
              ->  Seq Scan on annonce a  (cost=0.00..3179.02 rows=18011 width=37) (actual time=0.015..51.134 rows=17501 loops=1)
                    Filter: (((prix)::numeric >= '200000'::numeric) AND ((prix)::numeric <= '350000'::numeric) AND (statut = 'active'::text))
                    Rows Removed by Filter: 82500
                    Buffers: shared hit=1429
              ->  Hash  (cost=1200.55..1200.55 rows=1382 width=16) (actual time=3.946..3.948 rows=1333 loops=1)
                    Buckets: 2048  Batches: 1  Memory Usage: 79kB
                    Buffers: shared hit=1033 read=3
                    ->  Bitmap Heap Scan on bien b  (cost=22.46..1200.55 rows=1382 width=16) (actual time=0.582..3.254 rows=1333 loops=1)
                          Recheck Cond: ((id_zone = '13ab0dd2-aa8e-5e78-a3c3-e16c2f02c92a'::uuid) AND (type_bien = 'appartement'::text))
                          Heap Blocks: exact=1033
                          Buffers: shared hit=1033 read=3
                          ->  Bitmap Index Scan on ix_bien_zone_type  (cost=0.00..22.11 rows=1382 width=0) (actual time=0.296..0.296 rows=1333 loops=1)
                                Index Cond: ((id_zone = '13ab0dd2-aa8e-5e78-a3c3-e16c2f02c92a'::uuid) AND (type_bien = 'appartement'::text))
                                Buffers: shared read=3
Planning:
  Buffers: shared hit=100 read=2
Planning Time: 1.563 ms
Execution Time: 60.895 ms
```

</details>

<details><summary>Plan après index, random_page_cost = 1.1</summary>

```
Limit  (cost=3045.94..3046.06 rows=50 width=21) (actual time=17.726..17.748 rows=50 loops=1)
  Buffers: shared hit=5367
  ->  Sort  (cost=3045.94..3046.56 rows=249 width=21) (actual time=17.723..17.733 rows=50 loops=1)
        Sort Key: a.prix
        Sort Method: top-N heapsort  Memory: 30kB
        Buffers: shared hit=5367
        ->  Nested Loop  (cost=17.08..3037.67 rows=249 width=21) (actual time=0.639..17.407 rows=332 loops=1)
              Buffers: shared hit=5367
              ->  Bitmap Heap Scan on bien b  (cost=16.66..896.67 rows=1382 width=16) (actual time=0.563..5.260 rows=1333 loops=1)
                    Recheck Cond: ((id_zone = '13ab0dd2-aa8e-5e78-a3c3-e16c2f02c92a'::uuid) AND (type_bien = 'appartement'::text))
                    Heap Blocks: exact=1033
                    Buffers: shared hit=1036
                    ->  Bitmap Index Scan on ix_bien_zone_type  (cost=0.00..16.31 rows=1382 width=0) (actual time=0.253..0.254 rows=1333 loops=1)
                          Index Cond: ((id_zone = '13ab0dd2-aa8e-5e78-a3c3-e16c2f02c92a'::uuid) AND (type_bien = 'appartement'::text))
                          Buffers: shared hit=3
              ->  Index Scan using ix_annonce_active_bien_prix on annonce a  (cost=0.42..1.54 rows=1 width=37) (actual time=0.008..0.008 rows=0 loops=1333)
                    Index Cond: ((id_bien = b.id_bien) AND ((prix)::numeric >= '200000'::numeric) AND ((prix)::numeric <= '350000'::numeric))
                    Buffers: shared hit=4331
Planning:
  Buffers: shared hit=16
Planning Time: 0.615 ms
Execution Time: 17.983 ms
```

</details>

### Q4 — D10 : rendez-vous de visite d'un mandat (ADR-049 §5, calcul du critère S5)

```sql
SELECT count(DISTINCT (v.id_proposition, v.date_visite)) FROM visite v JOIN proposition p ON p.id_proposition = v.id_proposition JOIN demande_acquereur da ON da.id_demande = p.id_demande AND da.id_client = v.id_visiteur WHERE p.id_mandat = :mandat AND v.realisee = true
```

<details><summary>Plan avant index</summary>

```
Aggregate  (cost=4619.99..4620.00 rows=1 width=8) (actual time=72.447..72.454 rows=1 loops=1)
  Buffers: shared hit=2347
  ->  Sort  (cost=4619.99..4619.99 rows=1 width=20) (actual time=72.420..72.427 rows=3 loops=1)
        Sort Key: (ROW(v.id_proposition, v.date_visite))
        Sort Method: quicksort  Memory: 25kB
        Buffers: shared hit=2347
        ->  Nested Loop  (cost=1841.34..4619.98 rows=1 width=20) (actual time=14.821..72.328 rows=3 loops=1)
              Join Filter: (v.id_visiteur = da.id_client)
              Rows Removed by Join Filter: 3
              Buffers: shared hit=2342
              ->  Hash Join  (cost=1841.05..4594.07 rows=6 width=52) (actual time=14.786..72.143 rows=6 loops=1)
                    Hash Cond: (v.id_proposition = p.id_proposition)
                    Buffers: shared hit=2329
                    ->  Seq Scan on visite v  (cost=0.00..2438.00 rows=120000 width=36) (actual time=0.014..36.569 rows=120000 loops=1)
                          Filter: realisee
                          Buffers: shared hit=1238
                    ->  Hash  (cost=1841.01..1841.01 rows=3 width=32) (actual time=9.084..9.086 rows=3 loops=1)
                          Buckets: 1024  Batches: 1  Memory Usage: 9kB
                          Buffers: shared hit=1091
                          ->  Seq Scan on proposition p  (cost=0.00..1841.01 rows=3 width=32) (actual time=2.299..9.060 rows=3 loops=1)
                                Filter: (id_mandat = 'c15f0596-f56d-5dc9-ebb9-1b567b3f67fb'::uuid)
                                Rows Removed by Filter: 59998
                                Buffers: shared hit=1091
              ->  Index Only Scan using demande_acquereur_pkey on demande_acquereur da  (cost=0.29..4.30 rows=1 width=32) (actual time=0.017..0.018 rows=1 loops=6)
                    Index Cond: (id_demande = p.id_demande)
                    Heap Fetches: 0
                    Buffers: shared hit=13
Planning:
  Buffers: shared hit=60
Planning Time: 1.097 ms
Execution Time: 72.578 ms
```

</details>

<details><summary>Plan après index</summary>

```
Aggregate  (cost=65.57..65.58 rows=1 width=8) (actual time=0.164..0.166 rows=1 loops=1)
  Buffers: shared hit=27
  ->  Sort  (cost=65.56..65.56 rows=1 width=20) (actual time=0.155..0.157 rows=3 loops=1)
        Sort Key: (ROW(v.id_proposition, v.date_visite))
        Sort Method: quicksort  Memory: 25kB
        Buffers: shared hit=27
        ->  Nested Loop  (cost=9.03..65.55 rows=1 width=20) (actual time=0.085..0.141 rows=3 loops=1)
              Join Filter: (da.id_client = v.id_visiteur)
              Rows Removed by Join Filter: 3
              Buffers: shared hit=27
              ->  Nested Loop  (cost=4.60..28.82 rows=3 width=32) (actual time=0.028..0.046 rows=3 loops=1)
                    Buffers: shared hit=12
                    ->  Bitmap Heap Scan on proposition p  (cost=4.31..15.88 rows=3 width=32) (actual time=0.018..0.024 rows=3 loops=1)
                          Recheck Cond: (id_mandat = 'c15f0596-f56d-5dc9-ebb9-1b567b3f67fb'::uuid)
                          Heap Blocks: exact=3
                          Buffers: shared hit=5
                          ->  Bitmap Index Scan on ix_proposition_mandat  (cost=0.00..4.31 rows=3 width=0) (actual time=0.012..0.012 rows=3 loops=1)
                                Index Cond: (id_mandat = 'c15f0596-f56d-5dc9-ebb9-1b567b3f67fb'::uuid)
                                Buffers: shared hit=2
                    ->  Index Only Scan using demande_acquereur_pkey on demande_acquereur da  (cost=0.29..4.30 rows=1 width=32) (actual time=0.004..0.005 rows=1 loops=3)
                          Index Cond: (id_demande = p.id_demande)
                          Heap Fetches: 0
                          Buffers: shared hit=7
              ->  Bitmap Heap Scan on visite v  (cost=4.43..12.22 rows=2 width=36) (actual time=0.011..0.014 rows=2 loops=3)
                    Recheck Cond: ((p.id_proposition = id_proposition) AND realisee)
                    Heap Blocks: exact=6
                    Buffers: shared hit=15
                    ->  Bitmap Index Scan on ix_visite_proposition_date  (cost=0.00..4.43 rows=2 width=0) (actual time=0.007..0.007 rows=2 loops=3)
                          Index Cond: (id_proposition = p.id_proposition)
                          Buffers: shared hit=9
Planning:
  Buffers: shared hit=14
Planning Time: 0.584 ms
Execution Time: 0.228 ms
```

</details>

<details><summary>Plan après index, random_page_cost = 1.1</summary>

```
Aggregate  (cost=20.34..20.35 rows=1 width=8) (actual time=0.123..0.125 rows=1 loops=1)
  Buffers: shared hit=27
  ->  Sort  (cost=20.33..20.33 rows=1 width=20) (actual time=0.111..0.113 rows=3 loops=1)
        Sort Key: (ROW(v.id_proposition, v.date_visite))
        Sort Method: quicksort  Memory: 25kB
        Buffers: shared hit=27
        ->  Nested Loop  (cost=0.99..20.32 rows=1 width=20) (actual time=0.048..0.097 rows=3 loops=1)
              Join Filter: (da.id_client = v.id_visiteur)
              Rows Removed by Join Filter: 3
              Buffers: shared hit=27
              ->  Nested Loop  (cost=0.58..8.99 rows=3 width=32) (actual time=0.029..0.047 rows=3 loops=1)
                    Buffers: shared hit=12
                    ->  Index Scan using ix_proposition_mandat on proposition p  (cost=0.29..4.74 rows=3 width=32) (actual time=0.017..0.022 rows=3 loops=1)
                          Index Cond: (id_mandat = 'c15f0596-f56d-5dc9-ebb9-1b567b3f67fb'::uuid)
                          Buffers: shared hit=5
                    ->  Index Only Scan using demande_acquereur_pkey on demande_acquereur da  (cost=0.29..1.41 rows=1 width=32) (actual time=0.005..0.006 rows=1 loops=3)
                          Index Cond: (id_demande = p.id_demande)
                          Heap Fetches: 0
                          Buffers: shared hit=7
              ->  Index Scan using ix_visite_proposition_date on visite v  (cost=0.42..3.75 rows=2 width=36) (actual time=0.010..0.013 rows=2 loops=3)
                    Index Cond: (id_proposition = p.id_proposition)
                    Buffers: shared hit=15
Planning:
  Buffers: shared hit=14
Planning Time: 1.044 ms
Execution Time: 0.202 ms
```

</details>

## Rattachement RNCP40573

BC05 — « concevoir la base pour l'analytique et l'IA » : indexation justifiée par la mesure (preuve `EXPLAIN`). BC01 — numérique responsable : index partiels, pas d'index spéculatif (ENF-26).
