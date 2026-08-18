import logging
from sqlalchemy import text

# Ordre d'insertion strict pour respecter l'intégrité référentielle
TABLES_MIGRATION = [
    ("pays", "pays", "code_iso"),
    ("ville", "ville", "id_ville"),
    ("secteur", "secteur", "id_secteur"),
    ("personne", "personne", "id_personne"),
    ("client", "client", None),
    ("chasseur", "chasseur", None),
    ("demande", "demande", "id_demande"),
    ("mandat", "mandat", "id_mandat"),
    ("demande_version", "demande_version", "id_version"),
    ("caracteristique", "caracteristique", "id_caracteristique"),
    ("demande_secteur", "demande_secteur", None),
    ("demande_caracteristique", "demande_caracteristique", None),
]


def charger_donnees_cible(engine, dict_dfs, schema: str = "fil_rouge_cible"):
    """Insère les DataFrames dans le schéma cible au sein d'une transaction unique atomique.

    Recale les séquences PostgreSQL (SERIAL) après l'insertion des clés explicites.
    """
    logging.info("Début du chargement atomique dans le schéma '%s'...", schema)

    # 1. Transaction unique (Rollback automatique si une table échoue)
    with engine.begin() as conn:
        tables_chargees = 0

        for nom_table_sql, cle_dict, col_pk in TABLES_MIGRATION:
            df = dict_dfs.get(cle_dict)

            if df is None or df.empty:
                logging.warning("Table '%s' omise ou vide dans le jeu de données transformé.", nom_table_sql)
                continue

            logging.info("Chargement de %s.%s (%d lignes)...", schema, nom_table_sql, len(df))

            # Insertion via connexion transactionnelle
            df.to_sql(
                name=nom_table_sql,
                con=conn,
                schema=schema,
                if_exists="append",
                index=False,
                method="multi",
                chunksize=1000,
            )
            tables_chargees += 1

            # 2. Recalage des séquences PostgreSQL si la table possède une PK auto-incrémentée
            if col_pk and col_pk.startswith("id_"):
                sql_seq = text(f"""
                    SELECT setval(
                        pg_get_serial_sequence('{schema}.{nom_table_sql}', '{col_pk}'),
                        COALESCE((SELECT MAX({col_pk}) FROM {schema}.{nom_table_sql}), 1),
                        EXISTS (SELECT 1 FROM {schema}.{nom_table_sql})
                    );
                """)
                conn.execute(sql_seq)

    logging.info("Chargement réussi : %d tables insérées et séquences réalignées.", tables_chargees)