"""Tests de l'étape 03_transformation.

Jeu d'essai : un extrait **réel** des fixtures, réduit aux deux mandats qui
concentrent les cas difficiles — le mandat 8 (disjonction de secteurs et de
caractéristiques, statut contredit par les dates) et le mandat 13 (chasseur en
position de client, critère hors sujet). Aucune base de données n'est requise.
"""

import math
from datetime import date
from decimal import Decimal

import pandas as pd
import pytest

from transformer import extraire_criteres, transformer_donnees

SECTEURS = pd.DataFrame([(1, "Montpellier", "Écusson", "34000"),
                         (3, "Montpellier", "Beaux-Arts", "34090"),
                         (4, "Montpellier", "Figuerolles", "34070")],
                        columns=["id", "ville", "quartier", "code_postal"])

UTILISATEURS = pd.DataFrame(
    [(2, "chasseur", "Nguyen", "Thomas", "t.nguyen@chassimmo.fr", "0622334455", "Montpellier",
      Decimal("3.00"), None, date(2023, 6, 1)),
     (3, "chasseur", "Delacroix", "Inès", "i.delacroix@chassimmo.fr", "0633445566", "Lyon",
      Decimal("2.75"), None, date(2024, 1, 10)),
     (14, "client", "Rossi", "Giulia", "giulia.rossi@mail.fr", "0708091011", "Montpellier",
      None, Decimal("300000.00"), date(2025, 7, 4)),
     (19, "client", "Girard", "Nina", "nina.girard@mail.fr", "0713141516", "Montpellier",
      None, Decimal("220000.00"), date(2025, 12, 12))],
    columns=["id", "role", "nom", "prenom", "email", "telephone", "ville",
             "taux_commission", "budget_max", "date_creation"])

MANDATS = pd.DataFrame(
    [(8, 14, 2, 1, False, date(2025, 9, 15), "suspendu",
      "T3 Ecusson ou Beaux-Arts, budget 300000, charme ancien, poutres"),
     (13, 3, 2, 4, False, date(2026, 2, 10), "actif",
      "T2 Figuerolles, budget 220000, premier achat, 40m2 min")],
    columns=["id", "client_id", "chasseur_id", "secteur_id", "exclusif", "date_debut",
             "statut", "description_recherche"])


@pytest.fixture(scope="module")
def migration():
    return transformer_donnees({"secteurs": SECTEURS, "utilisateurs": UTILISATEURS, "mandats": MANDATS})


def test_scission_des_utilisateurs(migration):
    """A02 : clients et chasseurs séparés, chacun avec sa date métier."""
    tables, _ = migration
    assert list(tables["chasseur"]["id_personne"]) == [2, 3]
    assert list(tables["client"]["id_personne"]) == [14, 19]
    assert len(tables["personne"]) == 4  # aucune personne perdue à la scission


def test_aucun_chasseur_en_position_de_client(migration):
    """A06 : le mandat 13 est rattaché au client 19, la correction est tracée."""
    tables, rapport = migration
    assert not set(tables["demande"]["id_client"]) & set(tables["chasseur"]["id_personne"])
    assert tables["demande"].set_index("id_demande").loc[13, "id_client"] == 19
    assert (rapport["anomalie"] == "A06").sum() == 1


def test_date_fin_calculee_et_expiration_deduite(migration):
    """A01 / A04 : date_fin = signature + 6 mois, et l'expiration n'est plus stockée."""
    tables, _ = migration
    mandat = tables["mandat"].set_index("id_mandat")
    assert mandat.loc[8, "date_fin"] == date(2026, 3, 15)
    assert mandat.loc[8, "statut"] == "suspendu"  # statut décidé conservé, expiration calculée
    assert "expire" not in set(tables["mandat"]["statut"])


def test_criteres_structures(migration):
    """A03 : le texte libre devient des colonnes requêtables, typées pour la cible."""
    tables, _ = migration
    version = tables["demande_version"].set_index("id_version")
    assert version.loc[8, ["type_bien", "nb_pieces_min"]].tolist() == ["appartement", 3]
    assert version.loc[13, ["budget_max", "surface_min"]].tolist() == [Decimal("220000"), 40]
    assert version.loc[8, "criteres_bruts"] == MANDATS.loc[0, "description_recherche"]
    assert version.loc[8, "est_courante"] and version.loc[8, "no_version"] == 1


def test_secteurs_multiples_du_texte(migration):
    """Le mandat 8 vise deux quartiers ; l'existant n'en portait qu'un."""
    tables, _ = migration
    liens = tables["demande_secteur"]
    assert sorted(liens.loc[liens["id_version"] == 8, "id_secteur"]) == [1, 3]
    assert sorted(liens.loc[liens["id_version"] == 13, "id_secteur"]) == [4]


def test_taux_commission_repris_en_bareme(migration):
    """Rien ne se perd : le taux du chasseur devient un barème à tranche unique."""
    tables, _ = migration
    tranches = tables["tranche_bareme"].set_index("id_bareme")
    assert tranches.loc[2, "taux"] == Decimal("3.00")
    assert tranches.loc[2, "montant_min"] == 0


def test_tout_ecart_est_trace(migration):
    """« Zéro déperdition » (note de cadrage) : ce qui n'est pas repris est motivé."""
    _, rapport = migration
    assert any("premier achat" in decision
               for decision in rapport.loc[rapport["objet"] == "mandat 13", "decision"])
    assert any("secteurs [1, 3]" in decision
               for decision in rapport.loc[rapport["objet"] == "mandat 8", "decision"])
    assert set(rapport["anomalie"]) <= {"A01", "A02", "A03", "A04", "A06", "A07", "A08", "A10b", "A10c"}


def test_aucune_valeur_pandas_dans_les_tables(migration):
    """Les manquants valent None, jamais NaN ni pd.NA : les tables sont chargeables telles quelles."""
    tables, _ = migration
    valeurs = [valeur for table in tables.values() for valeur in table.to_numpy().ravel()]
    manquants = {type(v) for v in valeurs if v is None or v is pd.NA or (isinstance(v, float) and math.isnan(v))}
    assert manquants <= {type(None)}


@pytest.mark.parametrize("texte, attendu", [
    ("terrasse ou jardin", [("terrasse", False), ("jardin", False)]),  # disjonction → souhaits
    ("cave appreciee", [("cave", False)]),                             # modulateur → souhait
    ("balcon, calme", [("balcon", True), ("calme", True)]),            # critères éliminatoires
])
def test_caractere_imperatif_des_caracteristiques(texte, attendu):
    assert extraire_criteres(texte)["caracteristiques"] == attendu


@pytest.mark.parametrize("texte, champ, valeur", [
    ("Maison Castelnau, budget 240000, 80m2, jardin, travaux OK", "etat_attendu", "a_renover"),
    ("T3 Port Marianne, neuf ou recent", "etat_attendu", "recent"),
    ("Appartement Nantes, 4 pieces, dernier etage", "dernier_etage_exige", True),
    ("T3 Ecusson, budget 320000, 65m2 min, DPE C max", "dpe_max", "C"),
    ("Maison Ile de Nantes, 3 chambres", "nb_chambres_min", 3),
])
def test_extraction_des_champs(texte, champ, valeur):
    assert extraire_criteres(texte)["champs"][champ] == valeur
