from sqlalchemy import create_engine
import logging

def charger_donnees_cible(uri_cible, dict_dfs):
    """
    Insère les données transformées dans le schéma cible 'fil_rouge_cible'
    en respectant le graphe des dépendances FK.
    """
    logging.info(f"Connexion au serveur cible : {uri_cible}")
    engine = create_engine(uri_cible)

    # Ordre strict d'insertion pour respecter les contraintes de clés étrangères
    ordre_insertion = [
        ('SECTEUR', 'secteur'),
        ('PERSONNE', 'personne'),
        ('CLIENT', 'client'),
        ('CHASSEUR', 'chasseur'),
        ('DEMANDE', 'demande'),
        ('MANDAT', 'mandat'),
        ('DEMANDE_VERSION', 'demande_version')
    ]

    for table_sql, cle_dict in ordre_insertion:
        df = dict_dfs.get(cle_dict)
        if df is not None and not df.empty:
            logging.info(f"Chargement de la table fil_rouge_cible.{table_sql} ({len(df)} lignes)...")
            try:
                # Utilisation explicite du schéma fil_rouge_cible
                df.to_sql(table_sql.lower(), engine, schema='fil_rouge_cible', if_exists='append', index=False)
            except Exception as e:
                logging.error(f"Échec de l'insertion dans {table_sql}: {e}")
                raise