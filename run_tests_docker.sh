#!/usr/bin/env bash
# ============================================================
# Rejoue la batterie de tests contre le conteneur PostgreSQL.
# Prérequis : `docker compose up -d` a démarré chasse_oltp
#             et le healthcheck est "healthy".
# ============================================================
set -euo pipefail

# Charge .env puis exige le mot de passe (aucun secret par défaut).
# (tr -d '\r' : un .env enregistré avec des fins de ligne Windows ne doit pas coller un retour chariot au mot de passe)
if [ -f .env ]; then set -a; eval "$(tr -d '\r' < .env)"; set +a; fi
export PYTHONUTF8=1   # évite les UnicodeEncodeError de la console Windows (cp1252)
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD manquant : copier .env.example en .env et y definir un secret}"

# Interpréteur Python : 'python3' si réellement utilisable, sinon 'python' (cas courant sous Windows).
# Un venv activé a la priorité : c'est lui qui porte psycopg/pytest (sous Windows il ne fournit
# que 'python', pas 'python3').
if [ -n "${VIRTUAL_ENV:-}" ] && python -c "import sys" >/dev/null 2>&1; then PY=python
elif python3 -c "import sys" >/dev/null 2>&1; then PY=python3
elif python -c "import sys" >/dev/null 2>&1; then PY=python
else echo "Python 3 introuvable (essayé : python3, python)." >&2; exit 1; fi

CONTAINER=chasse_oltp
DB=chasse_v8
USER=chasse_migration

echo "Attente que PostgreSQL soit prêt..."
until docker exec "$CONTAINER" pg_isready -U "$USER" -d "$DB" >/dev/null 2>&1; do
  sleep 1
done
echo "PostgreSQL prêt."

# Le schéma et le seed sont déjà chargés au premier démarrage
# (docker-entrypoint-initdb.d). Ici on exécute la batterie de tests
# en repartant d'un schéma propre pour être 100 % reproductible.
echo "Rechargement propre du schéma + seed..."
docker exec -i "$CONTAINER" psql -U "$USER" -d "$DB" -q \
  -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
for f in 01_ddl 02_triggers_vues 03_seed; do
  docker exec -i "$CONTAINER" psql -U "$USER" -d "$DB" -q -v ON_ERROR_STOP=1 \
    < "livrables/db/${f}.sql"
done

echo "Exécution de la batterie de tests..."
# run_tests.py attend psql en local ; on le fait pointer sur le conteneur
# via une variable d'environnement lue par le script (voir run_tests.py).
# PSQL_DOCKER_CONTAINER : psql est exécuté DANS le conteneur (aucun client psql requis sur l'hôte).
PSQL_DOCKER_CONTAINER="$CONTAINER" PGUSER="$USER" PGDATABASE="$DB" \
  "$PY" livrables/db/run_tests.py
