#!/usr/bin/env bash
# ============================================================
# Joue la migration complète contre les conteneurs Docker.
# Prérequis : `docker compose up -d` (postgres-oltp + postgres-source
#             "healthy"). Les schémas cible et source sont chargés au
#             premier démarrage par docker-entrypoint-initdb.d.
# ============================================================
set -euo pipefail

# Charge .env (comme le fait `docker compose`) puis exige le mot de passe :
# aucun secret par défaut n'est toléré (voir .env.example).
# (tr -d '\r' : un .env enregistré avec des fins de ligne Windows ne doit pas coller un retour chariot au mot de passe)
if [ -f .env ]; then set -a; eval "$(tr -d '\r' < .env)"; set +a; fi
export PYTHONUTF8=1   # évite les UnicodeEncodeError de la console Windows (cp1252)
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD manquant : copier .env.example en .env et y definir un secret}"

# Interpréteur Python : 'python3' si réellement utilisable, sinon 'python' (cas courant sous Windows,
# où 'python3' est absent ou n'est qu'un alias du Microsoft Store qui échoue).
# Un venv activé a la priorité : c'est lui qui porte psycopg/pytest (sous Windows il ne fournit
# que 'python', pas 'python3').
if [ -n "${VIRTUAL_ENV:-}" ] && python -c "import sys" >/dev/null 2>&1; then PY=python
elif python3 -c "import sys" >/dev/null 2>&1; then PY=python3
elif python -c "import sys" >/dev/null 2>&1; then PY=python
else echo "Python 3 introuvable (essayé : python3, python)." >&2; exit 1; fi

OLTP=chasse_oltp
SRC=chasse_source
USER=chasse_migration

echo "Attente des bases..."
until docker exec "$OLTP" pg_isready -U "$USER" -d chasse_v8 >/dev/null 2>&1; do sleep 1; done
until docker exec "$SRC" pg_isready -U "$USER" -d chasse_source >/dev/null 2>&1; do sleep 1; done
echo "Bases prêtes."

# Variables pour le pipeline Python (ports exposés côté hôte)
# Hôte : 127.0.0.1 et NON « localhost ». Le compose ne publie les ports que sur 127.0.0.1 (IPv4) ;
# sous Windows, « localhost » est d'abord essayé en IPv6 (::1), ce qui ajoute plusieurs dizaines de
# secondes PAR connexion (mesuré : ~30 s contre 0,03 s). L'hôte est volontairement imposé ici, quel que
# soit le contenu du .env. (CHASSE_HOTE / CHASSE_*_PORT : surcharges réservées aux tests du dépôt.)
HOTE="${CHASSE_HOTE:-127.0.0.1}"
export SRC_PGHOST="$HOTE" SRC_PGPORT="${CHASSE_SRC_PORT:-5434}" SRC_PGUSER="$USER" SRC_PGDATABASE=chasse_source
export DST_PGHOST="$HOTE" DST_PGPORT="${CHASSE_OLTP_PORT:-5433}" DST_PGUSER="$USER" DST_PGDATABASE=chasse_v8
export SRC_PGPASSWORD="$POSTGRES_PASSWORD"
export DST_PGPASSWORD="$POSTGRES_PASSWORD"

# --- Contrôles préalables : si quelque chose cloche, on le dit clairement avant de migrer ---
echo "Contrôles préalables..."
"$PY" - <<'PYEOF' || exit 1
import os, sys
try:
    import psycopg, yaml, pytest  # noqa: F401
except ImportError as e:
    print(f"\n[ERREUR] Dépendance Python manquante : {e.name}", file=sys.stderr)
    print("  Le venv n'est probablement pas activé dans CE terminal, ou les dépendances ne sont pas installées :", file=sys.stderr)
    print("    source .venv/Scripts/activate        (Linux/macOS : source .venv/bin/activate)", file=sys.stderr)
    print("    python -m pip install -r livrables/migration/requirements.txt", file=sys.stderr)
    sys.exit(1)
for pref, nom in (("SRC", "source"), ("DST", "cible")):
    h, p, u, d = (os.environ[f"{pref}_PG{k}"] for k in ("HOST", "PORT", "USER", "DATABASE"))
    try:
        psycopg.connect(host=h, port=p, user=u, dbname=d,
                        password=os.environ.get(f"{pref}_PGPASSWORD", ""), connect_timeout=5).close()
    except Exception as e:
        msg = str(e).strip().splitlines()[0]
        print(f"\n[ERREUR] Connexion impossible à la base {nom} ({u}@{h}:{p}/{d}).", file=sys.stderr)
        print(f"  Détail : {msg}", file=sys.stderr)
        if "authentication" in msg:
            print("  -> Le mot de passe de .env ne correspond pas à celui des volumes : il est fixé au PREMIER démarrage", file=sys.stderr)
            print("     et un changement ultérieur de POSTGRES_PASSWORD n'est pas pris en compte.", file=sys.stderr)
            print("     Remettre l'ancien mot de passe dans .env, ou repartir de zéro (EFFACE les données) :", file=sys.stderr)
            print("       docker compose down -v && docker compose up -d", file=sys.stderr)
        elif "refused" in msg or "could not connect" in msg or "timeout" in msg.lower():
            print("  -> Conteneurs arrêtés ou port occupé ? Vérifier : docker compose ps", file=sys.stderr)
        elif "does not exist" in msg:
            print("  -> Base absente : volumes à recréer (docker compose down -v && docker compose up -d).", file=sys.stderr)
        sys.exit(1)
print("  dépendances et connexions aux deux bases : OK")
PYEOF

# --- Remise à zéro du schéma cible : le script doit être rejouable quel que soit l'état précédent ---
# Sans cela, un jeu de test laissé par run_tests_docker.sh (ex. le compte m.roussel@chassimmo.fr, aussi
# présent dans la source sous un autre identifiant) fait échouer la migration sur l'unicité de l'e-mail.
# Les tests pytest qui suivent rechargent de toute façon ce schéma : son contenu est donc jetable.
# (Le journal de migration, schéma « staging », est conservé : 00_staging.sql est idempotent.)
echo "Remise à zéro du schéma cible (état reproductible)..."
for f in livrables/db/01_ddl.sql livrables/db/02_triggers_vues.sql livrables/migration/sql/00_staging.sql; do
  sortie="$(docker exec -i "$OLTP" psql -v ON_ERROR_STOP=1 -q -U "$USER" -d chasse_v8 < "$f" 2>&1)" || {
    echo "$sortie" >&2; echo "[ERREUR] Échec du chargement de $f" >&2; exit 1; }
done

echo "Migration en cours (le pipeline n'affiche rien avant la fin du traitement)..."
(cd livrables/migration && "$PY" -m src.run_migration --source historique)

echo "Validation SQL..."
docker exec -i "$OLTP" psql -v ON_ERROR_STOP=1 -U "$USER" -d chasse_v8 \
  < livrables/migration/sql/40_validate.sql

echo "Tests pytest..."
REQUIRE_DB=1 "$PY" -m pytest livrables/migration/tests/ -q
