"""Fixtures de test de la migration.

Stratégie : deux bases PostgreSQL (source + cible) sont supposées disponibles
et configurées via les variables d'environnement SRC_* / DST_* (comme le
pipeline). La fixture `migrated` recharge un schéma cible propre, joue la
migration une fois, et fournit une connexion à la cible.

Ces tests nécessitent une base réelle (test d'intégration). En l'absence de
base joignable, ils sont ignorés proprement (skip), pour ne pas casser une CI
qui n'aurait pas Postgres.
"""
import os
import sys
import pathlib

import psycopg
import pytest

SRC = pathlib.Path(__file__).resolve().parents[1] / "src"
sys.path.insert(0, str(SRC))

LIVRABLES = pathlib.Path(__file__).resolve().parents[2]
SQL_OLTP = LIVRABLES / "db"                       # 01_ddl, 02_triggers_vues
SQL_MIG = pathlib.Path(__file__).resolve().parents[1] / "sql"  # staging, vues, validate


def _dsn(prefix):
    return dict(
        host=os.environ.get(f"{prefix}_PGHOST", "127.0.0.1"),
        port=os.environ.get(f"{prefix}_PGPORT", "5433"),
        user=os.environ.get(f"{prefix}_PGUSER", "chasse_migration"),
        dbname=os.environ.get(f"{prefix}_PGDATABASE",
                              "chasse_source" if prefix == "SRC" else "chasse_v8"),
        password=os.environ.get(f"{prefix}_PGPASSWORD", ""),
    )


def _try_connect(prefix):
    try:
        return psycopg.connect(**_dsn(prefix), autocommit=True)
    except Exception:
        return None


def _skip_ou_echec(motif):
    """Règle de l'art (P-H) : un test d'intégration non exécuté ne doit PAS passer
    silencieusement (une CI verte sans base donne un faux sentiment de couverture).
    En CI (REQUIRE_DB=1), l'absence de base est un ÉCHEC bruyant ; en dev, un skip
    explicite. Évite le piège du skip silencieux signalé en revue."""
    if os.environ.get("REQUIRE_DB") == "1":
        pytest.fail(f"[REQUIRE_DB=1] {motif} — tests d'intégration NON exécutés.")
    pytest.skip(f"{motif} (dev : poser REQUIRE_DB=1 pour forcer l'échec en CI).")


@pytest.fixture(scope="session")
def dst_conn():
    c = _try_connect("DST")
    if c is None:
        _skip_ou_echec("Base cible non joignable")
    yield c
    c.close()


@pytest.fixture(scope="session")
def migrated(dst_conn):
    """Recharge un schéma cible propre + joue la migration une fois."""
    if _try_connect("SRC") is None:
        _skip_ou_echec("Base source non joignable")

    def run_sql(conn, path):
        with open(path, encoding="utf-8") as f:
            conn.execute(f.read())

    # schéma cible propre (DDL + triggers + extensions migration)
    dst_conn.execute("DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;")
    run_sql(dst_conn, SQL_OLTP / "01_ddl.sql")
    run_sql(dst_conn, SQL_OLTP / "02_triggers_vues.sql")
    run_sql(dst_conn, SQL_MIG / "00_staging.sql")
    # v8 : est_a_regulariser (D-FLAG) et le gel carte T (A8) sont désormais
    # portés par 02_triggers_vues.sql (v_conformite_chasseur), fusionnés d'un
    # seul tenant (ADR-039). Plus besoin d'une extension de vue séparée.

    # jouer la migration
    from run_migration import main as run_main
    rc = run_main(["--source", "historique"])
    assert rc == 0, "la migration a échoué"
    return dst_conn


def q1(conn, sql, params=None):
    """Helper : renvoie la 1re colonne de la 1re ligne."""
    cur = conn.execute(sql, params or ())
    row = cur.fetchone()
    return row[0] if row else None


@pytest.fixture(scope="session", autouse=True)
def _restore_after_all(dst_conn, migrated):
    """Garantit qu'une migration COMPLÈTE est committée APRÈS tous les tests.

    Pourquoi : le test de rollback (test_rollback_sur_echec) laisse la base vide
    parce qu'il recharge un schéma propre, casse une table, et vérifie le rollback.
    Sans cette fixture, les données migrées par le pipeline dans run_migration_docker.sh
    ne sont plus dans la base quand le script se termine — l'utilisateur voit une base vide.
    yield laisse tourner les tests, puis le teardown rejoue la migration."""
    yield  # tous les tests tournent ici
    # --- teardown de session : remettre les données migrées ---
    def run_sql(conn, path):
        with open(path, encoding="utf-8") as f:
            conn.execute(f.read())
    dst_conn.execute("DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;")
    run_sql(dst_conn, SQL_OLTP / "01_ddl.sql")
    run_sql(dst_conn, SQL_OLTP / "02_triggers_vues.sql")
    run_sql(dst_conn, SQL_MIG / "00_staging.sql")
    from run_migration import main as run_main
    run_main(["--source", "historique"])

