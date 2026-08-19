import logging
import os
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent
sys.path[:0] = [str(d) for d in sorted(RACINE.glob("0*_*"))]  # cf. tests/conftest.py

from sqlalchemy import create_engine

from inserer_donnees import charger_donnees_cible
from lire_source import extraire_donnees
from transformer import transformer_donnees

# Source et cible sont deux schémas de la même base DB_Cours : un seul moteur.
URI = os.environ["URI_POSTGRES"]  # postgresql://user:motDePasse@localhost:5433/DB_Cours


def tout_executer():
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    moteur = create_engine(URI)
    try:
        tables, rapport = transformer_donnees(extraire_donnees(moteur))
        charger_donnees_cible(moteur, tables)
        rapport.to_csv(RACINE / "rapport-de-reprise.csv", index=False)
        logging.info("Migration terminée — %s décisions tracées", len(rapport))
    finally:
        moteur.dispose()


if __name__ == "__main__":
    tout_executer()