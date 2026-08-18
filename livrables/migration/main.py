import logging
from extraction.lire_source import extraire_donnees
from transformation.split_utilisateurs import transformer_personnes
from transformation.traite_anomalies import corriger_anomalies_relationnelles
from transformation.calcul_mandats import transformer_mandats_et_demandes
from transformation.parse_criteres import generer_demandes_versions
from chargement.inserer_donnees import charger_donnees_cible

# URI des bases (Port 5433 pour PostgreSQL)
URI_SOURCE = 'postgresql://admin:password@localhost:5433/DB_Cours'
URI_CIBLE = 'postgresql://admin:password@localhost:5433/DB_Cours'

def tout_executer():
    logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
    logging.info("=== INITIALISATION DU PIPELINE ETL CHASSE IMMO ===")

    try:
        # 1. EXTRACTION
        brutes = extraire_donnees(URI_SOURCE)

        # 2. TRANSFORMATIONS & NETTOYAGE
        mandats_corriges = corriger_anomalies_relationnelles(brutes['mandats'])
        df_personne, df_client, df_chasseur = transformer_personnes(brutes['utilisateurs'])
        df_demande, df_mandat = transformer_mandats_et_demandes(mandats_corriges)
        df_demande_version = generer_demandes_versions(mandats_corriges)

        # Mapping de la table SECTEUR vers la structure cible
        df_secteur = brutes['secteurs'].copy()
        df_secteur.rename(columns={'id': 'id_secteur'}, inplace=True)
        df_secteur['id_ville'] = None  # FK optionnelle

        dict_donnees_transformees = {
            'secteur': df_secteur[['id_secteur', 'id_ville', 'quartier']],
            'personne': df_personne,
            'client': df_client,
            'chasseur': df_chasseur,
            'demande': df_demande,
            'mandat': df_mandat,
            'demande_version': df_demande_version
        }

        # 3. CHARGEMENT
        charger_donnees_cible(URI_CIBLE, dict_donnees_transformees)

        logging.info("=== PIPELINE ETL EXÉCUTÉ AVEC SUCCÈS ===")
        logging.info("Exécutez 05_validation/controles.sql pour valider le résultat dans PostgreSQL.")

    except Exception as e:
        logging.error(f"Arrêt critique du pipeline : {e}")

if __name__ == "__main__":
    tout_executer()