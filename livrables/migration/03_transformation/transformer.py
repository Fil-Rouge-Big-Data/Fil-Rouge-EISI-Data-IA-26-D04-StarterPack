"""Transformation : du modèle hérité (3 tables) vers le modèle cible.

Contrat du module — `03_transformation/` doit être dans `sys.path` (un dossier
préfixé d'un chiffre n'est pas importable par son nom) :

    from transformer import transformer_donnees
    tables, rapport = transformer_donnees(donnees_brutes)  # sortie de extraire_donnees()

* `tables` : dict `{nom de table cible: DataFrame}`, **ordonné pour un chargement
  direct** (parents avant enfants). Les valeurs manquantes valent `None`, jamais
  `NaN` : elles sont prêtes pour un INSERT comme pour un `to_sql`.
* `rapport` : DataFrame `objet / anomalie / decision`, indexé sur les codes du
  registre d'anomalies. Toute donnée corrigée, déduite ou écartée y laisse une
  ligne. La note de cadrage exige « zéro déperdition » : ce rapport est ce qui
  permet de le vérifier, et de motiver les rares cas où la reprise à l'identique
  est impossible (critère hors sujet, disjonction que le modèle ne porte pas).

Les identifiants de l'existant sont **conservés** (`utilisateurs.id` →
`PERSONNE.id_personne`, `mandats.id` → `DEMANDE`/`MANDAT`/`DEMANDE_VERSION`) :
la migration reste comparable ligne à ligne en 05_validation. Le chargement doit
donc repositionner les séquences après insertion.

Aucune écriture ni connexion ici : entrée DataFrames, sortie DataFrames.
"""

import logging
import re
import unicodedata
from datetime import date
from decimal import Decimal

import pandas as pd

from referentiels import (CARACTERISTIQUES, CODES_INSEE, CORRECTIONS_CLIENT, ETATS_ATTENDUS,
                          HORS_SUJET, MODULATEURS, PAYS, STATUTS_MANDAT, TYPES_BIEN)

DATE_REFERENCE = date(2026, 7, 25)  # « aujourd'hui » du projet, jamais la date système
DUREE_MANDAT = pd.DateOffset(months=6)  # Readme.md : le mandat vaut 6 mois

# Contrat de sortie de DEMANDE_VERSION : colonnes fixes, quels que soient les
# critères réellement extraits du texte libre.
COLONNES_VERSION = ("id_version", "id_demande", "id_redacteur", "no_version", "date_modification",
                    "motif", "type_bien", "budget_max", "surface_min", "nb_pieces_min",
                    "nb_chambres_min", "dpe_max", "etat_attendu", "dernier_etage_exige",
                    "criteres_bruts", "est_courante")
COLONNES_ENTIERES = ["surface_min", "nb_pieces_min", "nb_chambres_min"]


def _normaliser(texte):
    """Minuscules, sans accent, espaces resserrés : la forme de comparaison du texte libre."""
    sans_accent = unicodedata.normalize("NFKD", str(texte)).encode("ascii", "ignore").decode()
    return re.sub(r"\s+", " ", sans_accent).strip().lower()


def _demoduler(terme):
    """« cave appreciee » → ('cave', False) : un souhait n'est pas un critère éliminatoire."""
    for modulateur in MODULATEURS:
        if terme.endswith(" " + modulateur):
            return terme[: -len(modulateur) - 1].strip(), False
    return terme, True


def extraire_criteres(texte):
    """Décompose une `description_recherche` en critères structurés (A03).

    Retourne un dict à trois clés :
    * `champs` — colonnes de DEMANDE_VERSION extraites du texte ;
    * `caracteristiques` — couples (clé du référentiel, est_imperatif) ;
    * `ecarts` — tout ce qui n'est pas repris tel quel, avec son motif.

    La localisation n'est pas traitée ici : elle est résolue contre le
    référentiel des secteurs par `transformer_donnees`.
    """
    champs = {"dernier_etage_exige": False}  # NOT NULL en cible : jamais laissé vide
    caracteristiques, ecarts = [], []
    for segment in _normaliser(texte).split(","):
        segment = segment.strip()
        if m := re.match(r"t(\d)\b", segment):  # « T3 Ecusson » : type ET nombre de pièces
            champs.update(type_bien="appartement", nb_pieces_min=int(m[1]))
        elif m := re.match(r"(%s)\b" % "|".join(TYPES_BIEN), segment):
            champs["type_bien"] = TYPES_BIEN[m[1]]
        elif m := re.fullmatch(r"budget (\d+)", segment):
            champs["budget_max"] = Decimal(m[1])  # Decimal : la cible est en DECIMAL(12,2)
        elif m := re.fullmatch(r"(\d+) ?m2( min)?", segment):
            champs["surface_min"] = int(m[1])
            if not m[2]:
                ecarts.append(f"surface « {segment} » reprise en minimum : sémantique indéterminable, "
                              "la source ne dit pas si elle est exacte (dictionnaire de données)")
        elif m := re.fullmatch(r"(\d+) pieces?", segment):
            champs["nb_pieces_min"] = int(m[1])
        elif m := re.fullmatch(r"(\d+) chambres?", segment):
            champs["nb_chambres_min"] = int(m[1])
        elif m := re.fullmatch(r"dpe ([a-g]) max", segment):
            champs["dpe_max"] = m[1].upper()
        elif segment == "dernier etage":
            champs["dernier_etage_exige"] = True
        elif segment in ETATS_ATTENDUS:
            champs["etat_attendu"] = ETATS_ATTENDUS[segment]
            if " ou " in segment:
                ecarts.append(f"état « {segment} » ramené à « {ETATS_ATTENDUS[segment]} » : "
                              "le modèle ne porte qu'un état attendu")
        else:  # tout le reste est qualitatif → référentiel des caractéristiques
            for terme in segment.split(" ou "):  # « terrasse ou jardin »
                terme, imperatif = _demoduler(terme)
                if terme in CARACTERISTIQUES:
                    caracteristiques.append((terme, imperatif and " ou " not in segment))
                elif terme in HORS_SUJET:
                    ecarts.append(f"« {terme} » écarté : {HORS_SUJET[terme]}")
                else:
                    ecarts.append(f"« {terme} » non repris : absent du référentiel des caractéristiques")
            if " ou " in segment:
                ecarts.append(f"disjonction « {segment} » : aucune structure logique en cible, "
                              "les deux termes sont repris en non impératifs")
    return {"champs": champs, "caracteristiques": caracteristiques, "ecarts": ecarts}


def transformer_donnees(donnees_brutes):
    """Construit les tables cibles et le rapport de reprise à partir de l'existant."""
    secteurs_src = donnees_brutes["secteurs"]
    utilisateurs_src = donnees_brutes["utilisateurs"]
    mandats_src = donnees_brutes["mandats"].copy()  # copie : la correction A06 modifie une ligne
    traces = []

    def tracer(objet, anomalie, decision):
        traces.append({"objet": objet, "anomalie": anomalie, "decision": decision})

    # --- Géographie : PAYS → VILLE → SECTEUR ---------------------------------
    # `secteurs.ville` (lieu de chasse) et `utilisateurs.ville` (résidence) sont
    # un polysème dans l'existant : une seule et même commune en cible.
    noms_villes = sorted(set(secteurs_src["ville"]) | set(utilisateurs_src["ville"].dropna()))
    ville = pd.DataFrame({"id_ville": range(1, len(noms_villes) + 1),
                          "code_iso_pays": PAYS["code_iso"], "nom": noms_villes,
                          "code_insee": [CODES_INSEE[nom] for nom in noms_villes]})
    ids_ville = dict(zip(ville["nom"], ville["id_ville"]))
    tracer("VILLE", "A07", f"{len(ville)} communes dédoublonnées entre secteurs et résidences ; "
           "code_insee absent de l'existant, renseigné depuis le COG INSEE")

    secteur = pd.DataFrame({"id_secteur": secteurs_src["id"],
                            "id_ville": secteurs_src["ville"].map(ids_ville),
                            "quartier": secteurs_src["quartier"],
                            "code_postal": secteurs_src["code_postal"]})

    # --- Acteurs : PERSONNE → CLIENT / CHASSEUR ------------------------------
    personne = pd.DataFrame({"id_personne": utilisateurs_src["id"],
                             "id_ville": utilisateurs_src["ville"].map(ids_ville),
                             "nom": utilisateurs_src["nom"], "prenom": utilisateurs_src["prenom"],
                             "email": utilisateurs_src["email"],
                             "telephone": utilisateurs_src["telephone"],
                             "date_creation": utilisateurs_src["date_creation"]})
    tracer("PERSONNE", "A10b", "aucun consentement ni durée de conservation dans l'existant : "
           "date_consentement et date_anonymisation laissées NULL, à recollecter")

    chasseurs = utilisateurs_src[utilisateurs_src["role"] == "chasseur"]
    clients = utilisateurs_src[utilisateurs_src["role"] == "client"]
    chasseur = pd.DataFrame({"id_personne": chasseurs["id"], "date_entree": chasseurs["date_creation"]})
    client = pd.DataFrame({"id_personne": clients["id"], "date_premier_contact": clients["date_creation"]})
    tracer("CLIENT / CHASSEUR", "A02", f"{len(clients)} clients et {len(chasseurs)} chasseurs scindés ; "
           "date_creation éclatée selon son sens réel (premier contact / entrée dans l'entreprise) ; "
           "origine et en_activite absents de l'existant, laissés au défaut")

    # --- Rémunération : le taux du chasseur devient son barème ---------------
    bareme = pd.DataFrame({"id_bareme": chasseurs["id"], "id_chasseur": chasseurs["id"],
                           "date_debut": chasseurs["date_creation"]})
    tranche_bareme = pd.DataFrame({"id_tranche": chasseurs["id"], "id_bareme": chasseurs["id"],
                                   "montant_min": 0, "taux": chasseurs["taux_commission"]})
    tracer("BAREME", "A08", "taux_commission repris en un barème par chasseur, ouvert à sa date "
           "d'entrée, à tranche unique [0 ; ∞[ : l'existant ne connaît pas les tranches")

    # --- Référentiel des caractéristiques (MCD cible) ------------------------
    caracteristique = pd.DataFrame(
        [{"id_caracteristique": rang, "libelle": libelle, "categorie": categorie}
         for rang, (libelle, categorie) in enumerate(CARACTERISTIQUES.values(), 1)])
    ids_caracteristique = dict(zip(CARACTERISTIQUES, caracteristique["id_caracteristique"]))

    # --- A06 : un chasseur en position de client -----------------------------
    for id_mandat, id_client in CORRECTIONS_CLIENT.items():
        ligne_ciblee = mandats_src["id"] == id_mandat
        ancien = mandats_src.loc[ligne_ciblee, "client_id"].item()
        mandats_src.loc[ligne_ciblee, "client_id"] = id_client
        tracer(f"mandat {id_mandat}", "A06", f"client_id {ancien} (chasseur) → {id_client} : "
               "correction de saisie reconstituée, à valider par le métier avant production")

    # --- DEMANDE / AFFECTATION / MANDAT --------------------------------------
    demande = pd.DataFrame({"id_demande": mandats_src["id"], "id_client": mandats_src["client_id"],
                            "date_depot": mandats_src["date_debut"]})
    affectation = pd.DataFrame({"id_affectation": mandats_src["id"], "id_demande": mandats_src["id"],
                                "id_chasseur": mandats_src["chasseur_id"], "statut": "acceptee",
                                "date_proposition": mandats_src["date_debut"],
                                "date_reponse": mandats_src["date_debut"]})
    tracer("DEMANDE / AFFECTATION", "A08", "l'existant ne connaît ni demande ni affectation : un "
           "mandat signé vaut une demande déposée et une affectation acceptée à sa date de début ; "
           "canal et motif_refus laissés NULL")

    mandat = pd.DataFrame({"id_mandat": mandats_src["id"], "id_demande": mandats_src["id"],
                           "id_chasseur": mandats_src["chasseur_id"],
                           "date_signature": mandats_src["date_debut"],
                           "date_debut_periode": mandats_src["date_debut"],
                           "date_fin": (pd.to_datetime(mandats_src["date_debut"]) + DUREE_MANDAT).dt.date,
                           "exclusif": mandats_src["exclusif"],
                           "statut": mandats_src["statut"].map(STATUTS_MANDAT)})
    tracer("MANDAT", "A04", "date_debut interprétée comme date de signature ; date_fin calculée à "
           "signature + 6 mois ; mode_signature et numero_registre absents de l'existant, laissés NULL")
    nb_recalcules = int((mandats_src["statut"] == "expire").sum())
    # Le registre d'anomalies nomme les mandats concernés par A01 : la liste est
    # recalculée ici sur les données plutôt que reprise, un identifiant erroné
    # dans le registre ne pouvant pas fausser la migration.
    expires = mandat.loc[(mandat["date_fin"] < DATE_REFERENCE)
                         & mandat["statut"].isin(["actif", "suspendu"]), "id_mandat"]
    tracer("MANDAT", "A01", f"statut « expire » non repris car calculable : {nb_recalcules} mandats "
           f"ramenés à leur dernier statut décidé ; au {DATE_REFERENCE:%d/%m/%Y}, {len(expires)} mandats "
           f"sont expirés d'après date_fin (v_mandat_etat) contre {nb_recalcules} déclarés par "
           f"l'existant — mandats {sorted(expires)}")

    # --- DEMANDE_VERSION et ses liaisons -------------------------------------
    quartiers = [(int(s.id), _normaliser(s.quartier))
                 for s in secteurs_src.itertuples() if pd.notna(s.quartier)]
    budgets_client = utilisateurs_src.set_index("id")["budget_max"]
    versions, liens_secteur, liens_caracteristique = [], [], []

    for ligne in mandats_src.itertuples():
        objet = f"mandat {ligne.id}"
        criteres = extraire_criteres(ligne.description_recherche)
        champs = criteres["champs"]
        for ecart in criteres["ecarts"]:
            tracer(objet, "A03", ecart)

        # Le budget qualifie la recherche, pas la personne : celui du texte fait
        # foi, `utilisateurs.budget_max` ne sert plus que de contrôle.
        budget_declare = budgets_client[ligne.client_id]
        if champs.setdefault("budget_max", budget_declare) != budget_declare:
            tracer(objet, "A03", f"budget divergent : {champs['budget_max']} dans le texte contre "
                   f"{budget_declare} sur la fiche client — le texte fait foi")

        versions.append({"id_version": ligne.id, "id_demande": ligne.id,
                         "id_redacteur": ligne.client_id, "no_version": 1, "est_courante": True,
                         "date_modification": ligne.date_debut,
                         "motif": "Reprise de l'existant (migration)",
                         "criteres_bruts": ligne.description_recherche, **champs})

        # Localisation : le secteur déclaré, plus tout quartier nommé dans le
        # texte. DEMANDE_SECTEUR a précisément été créée pour ça — le MCD cible
        # cite le cas « Ecusson ou Beaux-Arts », que l'existant ne pouvait pas
        # porter avec son unique `secteur_id`.
        secteurs_lies = {int(ligne.secteur_id)} if pd.notna(ligne.secteur_id) else set()
        texte_normalise = _normaliser(ligne.description_recherche)
        secteurs_lies |= {id_secteur for id_secteur, quartier in quartiers if quartier in texte_normalise}
        if len(secteurs_lies) > 1:
            tracer(objet, "A03", f"secteurs {sorted(secteurs_lies)} : le texte en nomme plusieurs, "
                   "tous repris — l'existant n'en portait qu'un")
        liens_secteur += [{"id_version": ligne.id, "id_secteur": id_secteur} for id_secteur in sorted(secteurs_lies)]
        liens_caracteristique += [{"id_version": ligne.id, "id_caracteristique": ids_caracteristique[cle],
                                   "est_imperatif": imperatif} for cle, imperatif in criteres["caracteristiques"]]

    demande_version = pd.DataFrame(versions, columns=COLONNES_VERSION)
    demande_version[COLONNES_ENTIERES] = demande_version[COLONNES_ENTIERES].astype("Int64")
    tracer("DEMANDE_VERSION", "A10c", f"{len(demande_version)} versions initiales créées "
           "(no_version = 1, est_courante) ; description_recherche conservée intégralement en "
           "criteres_bruts, seule trace de l'état d'origine")

    # --- Assemblage : ordre d'insertion, parents avant enfants ---------------
    tables = {"pays": pd.DataFrame([PAYS]), "ville": ville, "secteur": secteur, "personne": personne,
              "client": client, "chasseur": chasseur, "bareme": bareme, "tranche_bareme": tranche_bareme,
              "caracteristique": caracteristique, "demande": demande, "affectation": affectation,
              "mandat": mandat, "demande_version": demande_version,
              "demande_secteur": pd.DataFrame(liens_secteur),
              "demande_caracteristique": pd.DataFrame(liens_caracteristique)}
    # NaN / NA sont des artefacts pandas, pas des valeurs : la cible attend NULL.
    tables = {nom: df.astype(object).where(df.notna(), None) for nom, df in tables.items()}

    logging.info("Transformation réussie : %s", {nom: len(df) for nom, df in tables.items()})
    logging.info("Rapport de reprise : %s décisions tracées", len(traces))
    return tables, pd.DataFrame(traces, columns=["objet", "anomalie", "decision"])
