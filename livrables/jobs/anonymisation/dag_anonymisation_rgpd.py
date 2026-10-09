"""DAG Airflow — anonymisation RGPD quotidienne (ADR-043).

Exécute chaque nuit le job d'anonymisation : route les clients par catégorie
(prospect / client / transactionnel) et anonymise ceux arrivés à échéance.

Le DAG ne contient pas la logique métier : il orchestre le module `anonymiser`
(même code que le cron / la ligne de commande). Principe « un DAG = du Python
qui déclenche un traitement et journalise », cohérent avec le reste du projet.

Installation : déposer ce fichier dans le dossier `dags/` d'Airflow. Les
variables de connexion (DST_PGHOST, …) sont fournies par l'environnement
Airflow ou une connexion Airflow dédiée.
"""
from __future__ import annotations

from datetime import datetime, timedelta

# Imports Airflow isolés : le fichier reste importable (tests, lint) même
# sans Airflow installé — seul le scheduler Airflow a besoin de ces modules.
try:
    from airflow import DAG
    from airflow.operators.python import PythonOperator
    AIRFLOW = True
except ImportError:  # hors Airflow (CI, lint)
    AIRFLOW = False


def _run_anonymisation(**context):
    """Tâche : exécute le job. seuil et date de référence paramétrables."""
    import sys, pathlib
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    from anonymiser import main
    # date de référence = date logique du run Airflow (idempotence temporelle)
    ds = context.get("ds")  # 'YYYY-MM-DD'
    argv = ["--seuil-ans", "3"]
    if ds:
        argv += ["--date-ref", ds]
    rc = main(argv)
    if rc != 0:
        raise RuntimeError("job d'anonymisation en échec")


if AIRFLOW:
    default_args = {
        "owner": "data-eng",
        "retries": 1,
        "retry_delay": timedelta(minutes=10),
    }

    with DAG(
        dag_id="anonymisation_rgpd",
        description="Anonymisation quotidienne des clients à échéance (ADR-043)",
        schedule="0 2 * * *",            # tous les jours à 02:00
        start_date=datetime(2026, 1, 1),
        catchup=False,
        default_args=default_args,
        tags=["rgpd", "retention", "oltp"],
    ) as dag:
        PythonOperator(
            task_id="anonymiser_clients_echus",
            python_callable=_run_anonymisation,
        )
