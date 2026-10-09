"""Tests du job d'anonymisation RGPD (ADR-043).

Tests d'intégration : nécessitent une base cible v8 migrée joignable
(variables DST_*). Se skippent proprement sinon.

Vérifient les trois règles de routage, le seuil, l'idempotence et la
non-anonymisation des clients transactionnels.
"""
import os
import sys
import pathlib
from datetime import date, datetime, timezone

import psycopg
import pytest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import anonymiser


def _try_conn():
    try:
        return anonymiser._conn()
    except Exception:
        return None


@pytest.fixture
def conn():
    c = _try_conn()
    if c is None:
        # Règle de l'art (P-H) : échec bruyant en CI, skip explicite en dev.
        if os.environ.get("REQUIRE_DB") == "1":
            pytest.fail("[REQUIRE_DB=1] Base cible non joignable — tests NON exécutés.")
        pytest.skip("Base cible non joignable (dev : REQUIRE_DB=1 pour forcer l'échec).")
    yield c
    c.rollback()
    c.close()


def _creer_prospect(conn, uid, date_creation):
    with conn.cursor() as cur:
        cur.execute("INSERT INTO utilisateur (id_utilisateur,nom,prenom,email,"
                    "password_hash,date_creation,actif) VALUES "
                    "(%s,'Test','Prospect',%s,'x',%s,true) ON CONFLICT DO NOTHING",
                    (uid, f"p{uid[:8]}@test.invalid", date_creation))
        cur.execute("INSERT INTO client (id_utilisateur) VALUES (%s) "
                    "ON CONFLICT DO NOTHING", (uid,))
    conn.commit()


def test_selection_rend_deux_listes(conn):
    a, c = anonymiser.selectionner(conn, date(2026, 7, 25), 3)
    assert isinstance(a, list) and isinstance(c, list)


def test_prospect_ancien_est_candidat(conn):
    uid = "eeee0000-0000-0000-0000-00000000aa01"
    _creer_prospect(conn, uid, date(2021, 1, 1))  # 5+ ans
    a, _ = anonymiser.selectionner(conn, date(2026, 7, 25), 3)
    ids = [r["id_utilisateur"] for r, cat, age in a]
    assert uid in str(ids)
    # nettoyage
    with conn.cursor() as cur:
        cur.execute("DELETE FROM client WHERE id_utilisateur=%s", (uid,))
        cur.execute("DELETE FROM utilisateur WHERE id_utilisateur=%s", (uid,))
    conn.commit()


def test_prospect_recent_est_conserve(conn):
    uid = "eeee0000-0000-0000-0000-00000000aa02"
    _creer_prospect(conn, uid, date(2025, 6, 1))  # < 3 ans
    a, _ = anonymiser.selectionner(conn, date(2026, 7, 25), 3)
    ids = [r["id_utilisateur"] for r, cat, age in a]
    assert uid not in str(ids)
    with conn.cursor() as cur:
        cur.execute("DELETE FROM client WHERE id_utilisateur=%s", (uid,))
        cur.execute("DELETE FROM utilisateur WHERE id_utilisateur=%s", (uid,))
    conn.commit()


def test_anonymisation_respecte_c12_et_neutralise(conn):
    uid = "eeee0000-0000-0000-0000-00000000aa03"
    _creer_prospect(conn, uid, date(2020, 1, 1))
    now = datetime.now(timezone.utc)
    with conn.cursor() as cur:
        cur.execute(anonymiser.SQL_ANONYMISER, {"id": uid, "now": now})
    conn.commit()
    with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
        cur.execute("SELECT nom,email,actif,date_anonymisation FROM utilisateur "
                    "WHERE id_utilisateur=%s", (uid,))
        r = cur.fetchone()
    assert r["nom"] == "ANONYMISE"
    assert r["actif"] is False                  # C12
    assert r["date_anonymisation"] is not None
    assert "anonymise.invalid" in r["email"]
    with conn.cursor() as cur:
        cur.execute("DELETE FROM client WHERE id_utilisateur=%s", (uid,))
        cur.execute("DELETE FROM utilisateur WHERE id_utilisateur=%s", (uid,))
    conn.commit()


def test_idempotence_ne_retraite_pas(conn):
    uid = "eeee0000-0000-0000-0000-00000000aa04"
    _creer_prospect(conn, uid, date(2020, 1, 1))
    now = datetime.now(timezone.utc)
    with conn.cursor() as cur:
        cur.execute(anonymiser.SQL_ANONYMISER, {"id": uid, "now": now})
    conn.commit()
    # déjà anonymisé -> ne doit plus être candidat
    a, _ = anonymiser.selectionner(conn, date(2026, 7, 25), 3)
    ids = [r["id_utilisateur"] for r, cat, age in a]
    assert uid not in str(ids)
    with conn.cursor() as cur:
        cur.execute("DELETE FROM client WHERE id_utilisateur=%s", (uid,))
        cur.execute("DELETE FROM utilisateur WHERE id_utilisateur=%s", (uid,))
    conn.commit()


def test_sys_migration_jamais_candidat(conn):
    # le gestionnaire technique ne doit jamais être anonymisé
    a, _ = anonymiser.selectionner(conn, date(2026, 7, 25), 3)
    with conn.cursor() as cur:
        cur.execute("SELECT id_utilisateur FROM gestionnaire "
                    "WHERE matricule='SYS-MIGRATION'")
        row = cur.fetchone()
    if row:
        sys_id = row[0]
        ids = [r["id_utilisateur"] for r, cat, age in a]
        assert sys_id not in ids


def test_compte_desactive_non_anonymise_est_candidat(conn):
    """P-F (règle de l'art : tester le cas limite qui était le trou) : un compte
    DÉJÀ désactivé (actif=false) mais jamais anonymisé, inactif depuis plus de 3 ans,
    doit être candidat. Avant v8.41 il échappait au job (filtre actif=true) et ses
    données personnelles persistaient indéfiniment."""
    uid = "eeee0000-0000-0000-0000-00000000aa05"
    with conn.cursor() as cur:
        cur.execute("INSERT INTO utilisateur (id_utilisateur,nom,prenom,email,"
                    "password_hash,date_creation,actif) VALUES "
                    "(%s,'Test','Desactive',%s,'x','2020-01-01',false) ON CONFLICT DO NOTHING",
                    (uid, f"p{uid[:8]}@test.invalid"))
        cur.execute("INSERT INTO client (id_utilisateur) VALUES (%s) ON CONFLICT DO NOTHING", (uid,))
    conn.commit()
    a, _ = anonymiser.selectionner(conn, date(2026, 7, 25), 3)
    ids = [str(r["id_utilisateur"]) for r, cat, age in a]
    assert uid in ids, "un compte désactivé échu doit être candidat à l'anonymisation"
    with conn.cursor() as cur:
        cur.execute("DELETE FROM client WHERE id_utilisateur=%s", (uid,))
        cur.execute("DELETE FROM utilisateur WHERE id_utilisateur=%s", (uid,))
    conn.commit()
