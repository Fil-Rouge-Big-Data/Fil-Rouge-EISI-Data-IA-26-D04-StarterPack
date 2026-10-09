-- ============================================================
-- 00_staging.sql — Schéma de travail de la migration
-- Périmètre : structures internes au pipeline, hors OLTP métier (public).
--   - staging.migration_anomalie : journal des comblements/sentinelles
--     (D-FLAG niveau 2 — voir docs/arbitrages-migration.md)
--   - staging.migration_run      : trace d'exécution (idempotence, audit)
-- M4/ADR-050 : rejouable SANS DROP -> l'historique des runs est PRÉSERVÉ
-- (essentiel pour l'audit des migrations récurrentes). Reset explicite : reset_staging.sql.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS staging;

-- Journal d'anomalies / décisions de comblement.
-- Trace d'exécution : une ligne par run, pour l'audit et le suivi d'idempotence.
CREATE TABLE IF NOT EXISTS staging.migration_run (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source          text        NOT NULL,
    date_debut      timestamptz NOT NULL DEFAULT now(),
    date_fin        timestamptz,
    statut          text        NOT NULL DEFAULT 'en_cours'
                     CHECK (statut IN ('en_cours','succes','echec','dry_run')),
    lignes_inserees integer,
    lignes_anomalies integer,
    message         text
);

COMMENT ON TABLE staging.migration_run IS
  'Trace d''exécution du pipeline (idempotence, audit, runs récurrents).';

-- Une ligne par sentinelle posée ou décision de reprise tracée.
CREATE TABLE IF NOT EXISTS staging.migration_anomalie (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_run          bigint      NOT NULL REFERENCES staging.migration_run(id),  -- M5 : rattachement au run
    source          text        NOT NULL,              -- ex. 'historique'
    entite_cible    text        NOT NULL,              -- ex. 'chasseur'
    id_cible        text,                              -- UUID cible concerné (texte pour souplesse)
    code_anomalie   text        NOT NULL,              -- ex. 'A02', 'A06'
    motif           text        NOT NULL,              -- explication lisible
    valeur_sentinelle text,                            -- valeur posée, le cas échéant
    date_run        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE staging.migration_anomalie IS
  'D-FLAG niveau 2 : trace persistée de tout comblement/sentinelle/décision de reprise.';


