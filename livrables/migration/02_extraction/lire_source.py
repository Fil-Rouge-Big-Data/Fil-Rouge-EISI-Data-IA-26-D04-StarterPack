import pandas as pd
from sqlalchemy import create_engine
import logging

def extraire_donnees(uri_source):
    """
    Extrait l'intégralité des données de la base source PostgreSQL héritée.
    """
    logging.info(f"Connexion à la source : {uri_source}")
    engine = create_engine(uri_source)
    donnees_brutes = {}
    try:
        # Schema hérité "Fil_Rouge_Depart"
        donnees_brutes['utilisateurs'] = pd.read_sql('SELECT * FROM "Fil_Rouge_Depart".utilisateurs', engine)
        donnees_brutes['mandats'] = pd.read_sql('SELECT * FROM "Fil_Rouge_Depart".mandats', engine)
        donnees_brutes['secteurs'] = pd.read_sql('SELECT * FROM "Fil_Rouge_Depart".secteurs', engine)
        
        logging.info(f"Extraction réussie : {len(donnees_brutes['utilisateurs'])} utilisateurs, "
                     f"{len(donnees_brutes['mandats'])} mandats, {len(donnees_brutes['secteurs'])} secteurs.")
    except Exception as e:
        logging.error(f"Erreur lors de l'extraction source : {e}")
        raise
    return donnees_brutes