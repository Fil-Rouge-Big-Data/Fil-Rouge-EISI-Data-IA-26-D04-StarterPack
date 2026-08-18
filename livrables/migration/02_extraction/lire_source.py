import logging

import pandas as pd

SCHEMA_SOURCE = "Fil_Rouge_Depart"
TABLES = ("secteurs", "utilisateurs", "mandats")


def extraire_donnees(engine):
    """Extrait les tables de l'existant (PostgreSQL, schéma Fil_Rouge_Depart).

    L'appelant crée le moteur et le libère (dispose).
    """
    logging.info("Connexion à la source : %s", engine.url.render_as_string(hide_password=True))
    donnees_brutes = {t: pd.read_sql(f'SELECT * FROM "{SCHEMA_SOURCE}".{t} ORDER BY id', engine)
                      for t in TABLES}
    logging.info("Extraction réussie : %s", {t: len(df) for t, df in donnees_brutes.items()})
    return donnees_brutes