-- ============================================================
-- Test de faisabilité du partitionnement de `proposition` et `annonce`
-- Dossier d'architecture cible § 4 · matrice de décision § 6 (conditions 1 et 2) · CDC technique ENF-04 / PO-15
-- Auteur : Matthieu Barre · 13/10/2026 · PostgreSQL 16.15, socle v8.42
-- Sans effet sur la base : tout se passe dans une transaction annulée.
-- Lancement :
--   docker exec -i chasse_oltp psql -U chasse_migration -d chasse_v8 -v ON_ERROR_STOP=0 < test-partitionnement.sql
-- Lecture : chaque bloc annonce le résultat attendu ; une ERREUR attendue est un résultat du test.
-- ============================================================
BEGIN;

-- Borne UUIDv7 d'une date : les 48 premiers bits d'un UUIDv7 sont les millisecondes depuis 1970.
CREATE FUNCTION pg_temp.borne_v7(ts timestamptz) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$
  SELECT (substr(h,1,8)||'-'||substr(h,9,4)||'-0000-0000-000000000000')::uuid
  FROM (SELECT lpad(to_hex((extract(epoch FROM ts)*1000)::bigint),12,'0') AS h) s $$;

\echo '=================== A. PAR IDENTIFIANT UUIDv7 ==================='
CREATE TABLE ta_prop (LIKE proposition INCLUDING DEFAULTS INCLUDING CONSTRAINTS) PARTITION BY RANGE (id_proposition);
\echo '--- A1. Clé primaire actuelle (id_proposition) : attendu OK'
ALTER TABLE ta_prop ADD PRIMARY KEY (id_proposition);
\echo '--- A2. Règle C8 (uk_proposition_active, test T3) : attendu ERREUR'
SAVEPOINT a2;
CREATE UNIQUE INDEX ON ta_prop (id_demande, id_bien) WHERE statut IN ('a_qualifier','soumis','retenu_visite');
ROLLBACK TO a2;
\echo '--- A3. Dédoublonnage des annonces (uk_annonce_source) : attendu ERREUR'
CREATE TABLE ta_ann (LIKE annonce INCLUDING DEFAULTS) PARTITION BY RANGE (id_annonce);
SAVEPOINT a3;
ALTER TABLE ta_ann ADD CONSTRAINT uk_ta_ann_source UNIQUE (source, reference_source);
ROLLBACK TO a3;
CREATE TABLE ta_prop_2025 PARTITION OF ta_prop FOR VALUES FROM (pg_temp.borne_v7('2025-01-01')) TO (pg_temp.borne_v7('2026-01-01'));
CREATE TABLE ta_prop_2026 PARTITION OF ta_prop FOR VALUES FROM (pg_temp.borne_v7('2026-01-01')) TO (pg_temp.borne_v7('2027-01-01'));
\echo '--- A4. Propositions d un mandat (Q4) : attendu = toutes les partitions lues'
EXPLAIN (COSTS OFF) SELECT * FROM ta_prop WHERE id_mandat = '88888888-0000-0000-0000-000000000001';
\echo '--- A5. Filtre par date de matching : attendu = toutes les partitions lues'
EXPLAIN (COSTS OFF) SELECT * FROM ta_prop WHERE date_matching >= '2026-01-01';
\echo '--- A6. Une proposition datée de 2025 créée aujourd hui : rangée selon sa date de CRÉATION'
INSERT INTO ta_prop (id_proposition, id_demande, id_version, id_bien, id_annonce_reference, id_mandat, date_matching, statut)
SELECT uuidv7(), p.id_demande, p.id_version, p.id_bien, p.id_annonce_reference, p.id_mandat, '2025-03-01', 'ecarte_chasseur'
FROM proposition p LIMIT 1;
SELECT tableoid::regclass AS partition, date_matching::date FROM ta_prop;

\echo '=================== B. PAR PÉRIODE (ENF-04) ==================='
CREATE TABLE tb_prop (LIKE proposition INCLUDING DEFAULTS INCLUDING CONSTRAINTS) PARTITION BY RANGE (date_matching);
\echo '--- B1. Clé primaire actuelle (id_proposition) : attendu ERREUR'
SAVEPOINT b1;
ALTER TABLE tb_prop ADD PRIMARY KEY (id_proposition);
ROLLBACK TO b1;
\echo '--- B2. Clé primaire élargie (id_proposition, date_matching) : attendu OK'
ALTER TABLE tb_prop ADD PRIMARY KEY (id_proposition, date_matching);
\echo '--- B3. Clé étrangère entrante sur id_proposition seul (visite, offre, commentaire, note_avis) : attendu ERREUR'
CREATE TABLE tb_visite (id_visite uuid PRIMARY KEY, id_proposition uuid);
SAVEPOINT b3;
ALTER TABLE tb_visite ADD FOREIGN KEY (id_proposition) REFERENCES tb_prop (id_proposition);
ROLLBACK TO b3;
\echo '--- B4. Règle C8 : attendu ERREUR'
SAVEPOINT b4;
CREATE UNIQUE INDEX ON tb_prop (id_demande, id_bien) WHERE statut IN ('a_qualifier','soumis','retenu_visite');
ROLLBACK TO b4;
\echo '--- B5. Dédoublonnage des annonces par date d ingestion : attendu ERREUR'
CREATE TABLE tb_ann (LIKE annonce INCLUDING DEFAULTS) PARTITION BY RANGE (date_ingestion);
SAVEPOINT b5;
ALTER TABLE tb_ann ADD CONSTRAINT uk_tb_ann_source UNIQUE (source, reference_source);
ROLLBACK TO b5;
CREATE TABLE tb_prop_2025 PARTITION OF tb_prop FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE tb_prop_2026 PARTITION OF tb_prop FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
\echo '--- B6. Propositions d un mandat (Q4) : attendu = toutes les partitions lues'
EXPLAIN (COSTS OFF) SELECT * FROM tb_prop WHERE id_mandat = '88888888-0000-0000-0000-000000000001';
\echo '--- B7. Filtre par période de matching : attendu = une seule partition lue'
EXPLAIN (COSTS OFF) SELECT * FROM tb_prop WHERE date_matching >= '2026-01-01';

ROLLBACK;
