"""Fonctions de mapping source -> cible v7.

Deux responsabilités, toutes deux pures (sans I/O) pour être testables :
  1. UUID déterministe (T1) : clé naturelle source -> UUIDv5 stable.
  2. Parsing des critères en langage naturel -> colonnes booléennes/typées v7.

Le parsing reprend l'intelligence du code hérité (extraction de budget,
surface, pièces, type de bien) mais cible le modèle v7 : booléens exige_*,
travaux_acceptes, dpe_max, destination — et non l'ancienne table CARACTERISTIQUE.

Aucune donnée n'est inventée : ce que le texte ne dit pas reste None/False,
et le texte brut intégral est conservé par ailleurs dans commentaire_criteres
(arbitrage A6, garantie « zéro déperdition »).
"""
from __future__ import annotations

import re
import uuid

# Namespace dédié à cette migration (UUIDv5). Fixe et versionné :
# le changer changerait TOUS les UUID -> ne jamais le modifier.
NAMESPACE_MIGRATION = uuid.UUID("6f9b8c3e-2a1d-5e4f-8b7a-0c1d2e3f4a5b")


def uuid5_for(kind: str, natural_key: str) -> str:
    """UUID déterministe pour une entité cible.

    kind : préfixe logique ('utilisateur', 'zone', 'demande', 'mandat', ...).
    natural_key : clé naturelle normalisée (email, id source, tuple géo...).

    Rejouer produit le même UUID -> idempotence (arbitrage T1).
    """
    key = f"{kind}:{natural_key}".strip().lower()
    return str(uuid.uuid5(NAMESPACE_MIGRATION, key))


# --------------------------------------------------------------------------
# Parsing des critères (description_recherche libre -> attributs v7)
# --------------------------------------------------------------------------

# Vocabulaire source -> type_bien cible (domaine fermé v7).
_TYPE_BIEN_RULES = [
    (re.compile(r"\b(t[1-9]|studio|appartement|appart|loft|duplex)\b", re.I), "appartement"),
    (re.compile(r"\b(maison|villa|mas|longère|longere)\b", re.I), "maison"),
    (re.compile(r"\b(terrain|parcelle)\b", re.I), "terrain"),
    (re.compile(r"\b(immeuble)\b", re.I), "immeuble"),
]

# T3 -> 3 pièces (heuristique française courante : Tn = n pièces principales).
_T_N = re.compile(r"\bt\s*([1-9])\b", re.I)
_BUDGET = re.compile(r"budget\s*([0-9][0-9\s]{2,})", re.I)
_SURFACE = re.compile(r"([0-9]{2,4})\s*m2", re.I)
_PIECES = re.compile(r"([1-9])\s*pi[eè]ces?", re.I)
_CHAMBRES = re.compile(r"([1-9])\s*chambres?", re.I)
_DPE = re.compile(r"dpe\s*([a-g])\s*max", re.I)

# Booléens exige_* : mots-clés déclencheurs (présence = exigence).
_BOOL_KEYWORDS = {
    "exige_ascenseur": re.compile(r"\bascenseur\b", re.I),
    "exige_balcon":    re.compile(r"\bbalcon\b", re.I),
    "exige_terrasse":  re.compile(r"\bterrasse\b", re.I),
    "exige_jardin":    re.compile(r"\bjardin\b", re.I),
    "exige_parking":   re.compile(r"\b(parking|garage|place de parking)\b", re.I),
    "exige_cave":      re.compile(r"\bcave\b", re.I),
}
_TRAVAUX = re.compile(r"travaux\s*(ok|accept)", re.I)
_PRIMO = re.compile(r"premier\s+achat", re.I)


def _to_int(raw: str) -> int:
    """'320 000' / '320000' -> 320000."""
    return int(re.sub(r"\s+", "", raw))


def parse_criteres(description: str | None) -> dict:
    """Décompose une description_recherche libre en attributs v7.

    Renvoie un dict avec les clés attendues par demande_version.
    Tout ce qui n'est pas trouvé reste None (numérique) ou False (booléen) :
    on n'invente jamais un critère absent.
    """
    d = description or ""

    result: dict = {
        "type_bien": None,
        "budget_max": None,
        "surface_min": None,
        "nb_pieces_min": None,
        "nb_chambres_min": None,
        "dpe_max": None,
        "travaux_acceptes": False,
        "primo_accedant": False,
    }
    for key in _BOOL_KEYWORDS:
        result[key] = False

    # type_bien : première règle qui matche
    for rx, valeur in _TYPE_BIEN_RULES:
        if rx.search(d):
            result["type_bien"] = valeur
            break

    # budget
    m = _BUDGET.search(d)
    if m:
        result["budget_max"] = _to_int(m.group(1))

    # surface
    m = _SURFACE.search(d)
    if m:
        result["surface_min"] = int(m.group(1))

    # pièces : explicite "N pieces", sinon déduit du "Tn"
    m = _PIECES.search(d)
    if m:
        result["nb_pieces_min"] = int(m.group(1))
    else:
        m = _T_N.search(d)
        if m:
            result["nb_pieces_min"] = int(m.group(1))

    # chambres
    m = _CHAMBRES.search(d)
    if m:
        result["nb_chambres_min"] = int(m.group(1))

    # DPE max
    m = _DPE.search(d)
    if m:
        result["dpe_max"] = m.group(1).upper()

    # booléens exige_*
    # EXCL/ADR-052 : parser à 4 états d'intention (d_preference). Le modèle distingue
    # désormais 'exige', 'souhaite' (apprécié, non bloquant), 'exclut' (refus) et
    # 'indifferent' — là où l'ancien booléen mélangeait souhait et indifférence.
    #   « sans/pas de/aucun X »       -> exclut  (critère d'exclusion : refus du bien)
    #   « X apprécié/souhaité/ou »    -> souhaite (préférence non bloquante)
    #   « X » (mot seul)              -> exige
    #   X absent du texte             -> indifferent
    result["_criteres_requalifier"] = []   # exclut détecté : à confirmer en requalification
    # Règle de l'art : liste de négations enrichie (pas seulement « sans »).
    _EXCLUSION = re.compile(r"\b(sans|pas de|pas d'|aucun|aucune|non|hors)\b", re.I)
    _SOUHAIT   = re.compile(r"\b(ou|apprécié|apprecie|appréciée|souhaité|souhaite|souhaitée|si possible|idéalement|ideale?ment|de préférence|de preference)\b", re.I)
    for key, rx in _BOOL_KEYWORDS.items():
        pref_key = key.replace("exige_", "pref_")
        m = rx.search(d)
        if not m:
            result[pref_key] = "indifferent"
            continue
        deb, fin = max(0, m.start()-30), min(len(d), m.end()+30)
        ctx = d[deb:fin]
        if _EXCLUSION.search(ctx):
            result[pref_key] = "exclut"
            result["_criteres_requalifier"].append(pref_key)  # tracé pour requalif
        elif _SOUHAIT.search(ctx):
            result[pref_key] = "souhaite"
        else:
            result[pref_key] = "exige"

    # travaux acceptés / primo-accédant (déduction tracée, arbitrage A10)
    result["travaux_acceptes"] = bool(_TRAVAUX.search(d))
    result["primo_accedant"] = bool(_PRIMO.search(d))

    return result


# --------------------------------------------------------------------------
# Mapping des statuts de mandat (source -> cible v7) — arbitrages A7/A8
# --------------------------------------------------------------------------

def classifier_statut_source(statut_source: str) -> dict:
    """ADR-048 : le mandat n'a plus de colonne statut. On traduit le statut SOURCE
    en FAITS (date_resiliation) ou en ÉTAT REPRIS (mandat_etat), selon sa nature.

    Renvoie un dict décrivant quoi écrire :
    - actif / expire : rien à stocker — l'état se calcule de date_debut (v_mandat).
    - termine        : état REPRIS 'clos_succes' (succès connu, acte source absent).
    - suspendu       : abandon -> date_resiliation + motif (fait natif).
      (On ne passe PAS par mandat_etat : la résiliation est un fait stockable.)
    """
    s = (statut_source or "").strip().lower()
    if s in ("actif", "expire"):
        return {}  # rien : état dérivé
    if s == "termine":
        return {"etat_repris": "clos_succes",
                "_anomalie": ("A09", "statut source 'termine' -> etat repris 'clos_succes' (acte source absent)")}
    if s == "suspendu":
        return {"date_resiliation": True,  # posée = date_debut (faute de date source)
                "type_resiliation": "abandon_client",
                "motif_resiliation": "suspendu (repris de l'existant, à requalifier)",
                "_anomalie": ("A04", "statut source 'suspendu' -> resiliation (abandon)")}
    raise ValueError(f"Statut mandat source inconnu : {statut_source!r}")
