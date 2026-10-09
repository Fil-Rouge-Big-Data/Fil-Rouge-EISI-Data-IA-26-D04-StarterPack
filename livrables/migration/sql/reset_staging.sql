-- ============================================================
-- reset_staging.sql — Réinitialisation DESTRUCTIVE du schéma staging.
-- ⚠️ Efface tout l'historique des runs et anomalies. Pour le DEV uniquement,
-- JAMAIS en migration de production (l'audit récurrent doit être préservé).
-- ============================================================
DROP SCHEMA IF EXISTS staging CASCADE;
