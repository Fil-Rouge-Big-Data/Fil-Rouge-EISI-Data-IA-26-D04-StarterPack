#!/usr/bin/env python3
"""Génère le MCD complet (notation Merise) depuis `livrables/db/01_ddl.sql`.

Pourquoi : la grille d'évaluation attend « un MCD complet (cible) avec cardinalités ». Un schéma
dessiné à la main dérive du DDL à chaque version ; celui-ci est DÉDUIT des clés : il ne peut pas
mentir sur les cardinalités.

Règles de rétro-conception (DDL -> Merise) :
  - table dont la clé primaire est une clé étrangère vers utilisateur -> SOUS-TYPE (héritage par clé partagée) ;
  - table dont toutes les colonnes de clé primaire sont des FK   -> ASSOCIATION n,m (attributs = autres colonnes) ;
  - autre table                                                  -> ENTITÉ (attributs = colonnes non FK, identifiant = clé primaire) ;
  - colonne FK d'une entité                                      -> association binaire :
        côté porteur de la FK : (1,1) si NOT NULL, (0,1) sinon ;
        côté référencé        : (0,1) si la FK est UNIQUE, (0,n) sinon ;
  - FK composée dont une seule colonne n'est pas déjà une FK     -> association vers l'entité résolue par cette colonne ;
  - FK composée dont toutes les colonnes sont déjà des FK        -> contrainte d'intégrité fonctionnelle (CIF), listée, non dessinée.

Produits :
  - `mcd-complet.dot` -> `../mcd-v842-complet.png` : vue d'ensemble (entités compactes, toutes les associations) ;
  - `mcd-<domaine>.dot` -> `../mcd-v842-<domaine>.png` : un schéma par domaine, attributs complets ;
  - `../mcd-v842-complet.md` : tableaux (entités, sous-types, associations, cardinalités, CIF) + justifications
    rédigées à la main (`mcd-justifications.md`).

Usage :
    python livrables/documentation/merise/sources/generer_mcd.py
Les PNG sont rendus si la commande `dot` (Graphviz) est disponible ; sinon seuls les .dot et le .md sont écrits.
"""
import html
import pathlib
import re
import shutil
import subprocess
import sys

ICI = pathlib.Path(__file__).resolve().parent
MERISE = ICI.parent
DB_DIR = MERISE.parents[1] / "db"
sys.path.insert(0, str(DB_DIR))
import generer_dictionnaire_colonnes as g  # noqa: E402

VERSION = "v8.42"

# Domaines (dossier de modélisation §5) : un schéma détaillé par domaine.
DOMAINES = {
    "Acteurs": ["utilisateur", "client", "chasseur", "gestionnaire", "indisponibilite", "parrainage", "chasseur_zone"],
    "Demande": ["demande", "demande_version", "demande_acquereur", "affectation", "zone", "version_zone", "commentaire"],
    "Biens et prospection": ["bien", "annonce", "proposition", "visite", "note_avis", "document", "note_avis_document"],
    "Vente": ["offre_acquisition", "compromis", "clause_suspensive", "notaire", "acte"],
    "Rémunération": ["bareme", "tranche_bareme", "parametre_honoraires", "remuneration_chasseur", "facture_chasseur", "facture_document"],
    "Mandat et pilotage": ["mandat", "mandat_reprise", "indicateur", "periode", "observation", "objectif"],
}
SLUGS = {"Acteurs": "acteurs", "Demande": "demande", "Biens et prospection": "biens", "Vente": "vente",
         "Rémunération": "remuneration", "Mandat et pilotage": "mandat-pilotage"}

# Nom métier des associations : (table porteuse, colonne FK) -> verbe. À défaut, le nom de la colonne.
NOMS = {
    ("client", "id_utilisateur"): "est un", ("chasseur", "id_utilisateur"): "est un", ("gestionnaire", "id_utilisateur"): "est un",
    ("demande", "id_gestionnaire"): "est suivie par", ("demande", "id_chasseur"): "est affectée à",
    ("demande", "id_mandat_courant"): "a pour mandat courant",
    ("demande_version", "id_demande"): "versionne", ("demande_version", "id_modifie_par"): "est modifiée par",
    ("affectation", "id_demande"): "porte sur", ("affectation", "id_gestionnaire"): "est décidée par", ("affectation", "id_chasseur"): "affecte",
    ("mandat", "id_demande"): "donne lieu à", ("mandat", "id_chasseur"): "est signé par le chasseur",
    ("mandat", "id_mandat_precedent"): "renouvelle", ("mandat", "id_version_contractuelle"): "fige les critères de",
    ("mandat", "id_signataire"): "est signé par le client", ("mandat_reprise", "id_mandat"): "reprend l'état de",
    ("bien", "id_zone"): "est situé dans", ("annonce", "id_bien"): "décrit",
    ("proposition", "id_demande"): "répond à", ("proposition", "id_version"): "selon la version", ("proposition", "id_bien"): "propose",
    ("proposition", "id_annonce_reference"): "s'appuie sur", ("proposition", "id_mandat"): "est cadrée par",
    ("visite", "id_proposition"): "visite", ("visite", "id_visiteur"): "est effectuée par",
    ("note_avis", "id_proposition"): "donne l'avis sur",
    ("commentaire", "id_auteur"): "est rédigé par", ("commentaire", "id_demande"): "commente la demande",
    ("commentaire", "id_proposition"): "commente la proposition", ("commentaire", "id_bien"): "commente le bien",
    ("offre_acquisition", "id_proposition"): "formalise", ("offre_acquisition", "id_offre_precedente"): "remplace",
    ("compromis", "id_offre"): "concrétise", ("compromis", "id_notaire"): "est instrumenté par",
    ("clause_suspensive", "id_compromis"): "conditionne",
    ("acte", "id_compromis"): "réalise", ("acte", "id_mandat"): "achat hors dispositif sous",
    ("bareme", "id_chasseur"): "est propre à", ("tranche_bareme", "id_bareme"): "découpe",
    ("remuneration_chasseur", "id_acte"): "est générée par", ("remuneration_chasseur", "id_chasseur"): "rémunère",
    ("remuneration_chasseur", "id_mandat"): "au titre du mandat", ("remuneration_chasseur", "id_bareme_applique"): "applique",
    ("facture_chasseur", "id_remuneration"): "facture", ("facture_chasseur", "id_verificateur"): "est vérifiée par",
    ("parrainage", "id_parrain"): "parraine", ("parrainage", "id_filleul"): "devient", ("parrainage", "id_mandat_concretise"): "se concrétise par",
    ("indisponibilite", "id_utilisateur"): "indisponible",
    ("observation", "id_utilisateur"): "mesure", ("observation", "code_indicateur"): "selon l'indicateur", ("observation", "id_periode"): "sur la période",
    ("objectif", "id_utilisateur"): "est fixé à", ("objectif", "code_indicateur"): "vise l'indicateur", ("objectif", "id_periode"): "pour la période",
}
NOMS_NM = {"demande_acquereur": "acquiert pour", "note_avis_document": "joint", "facture_document": "joint",
           "chasseur_zone": "intervient sur", "version_zone": "cible", "observation": "observe", "objectif": "vise"}

CIF_SENS = {
    "fk_mandat_signataire": "le signataire du mandat est un acquéreur de SA demande (ADR-019)",
    "fk_mandat_version": "la version contractuelle du mandat appartient à SA demande",
    "fk_mandat_precedent_demande": "un renouvellement porte sur la même demande que le mandat précédent (ADR-032)",
    "fk_proposition_mandat": "le mandat qui cadre la proposition est un mandat de la même demande (ADR-045)",
    "fk_proposition_version": "la version de critères de la proposition appartient à la même demande",
    "fk_proposition_annonce": "l'annonce de référence décrit le bien proposé",
    "fk_remuneration_mandat": "le chasseur rémunéré est le chasseur du mandat (ADR-045, S1)",
}
NL = "\\n"  # saut de ligne Graphviz dans un libellé


def analyser():
    tables = g.lire_tables(DB_DIR)
    cols = {t: {c["nom"]: c for c in x["colonnes"]} for t, x in tables.items()}
    pk = {t: [c["nom"] for c in x["colonnes"] if c["pk"]] for t, x in tables.items()}
    fk_simple = {t: {c["nom"]: re.match(r"(\w+)\(", c["fk"]).group(1) for c in x["colonnes"] if c["fk"]} for t, x in tables.items()}

    sous_types, assoc_nm, entites = {}, [], []
    for t in tables:
        if len(pk[t]) == 1 and pk[t][0] in fk_simple[t] and fk_simple[t][pk[t][0]] == "utilisateur":
            sous_types[t] = "utilisateur"               # héritage : les rôles de l'utilisateur
        elif len(pk[t]) >= 2 and all(c in fk_simple[t] for c in pk[t]):
            assoc_nm.append(t)
        else:
            entites.append(t)

    associations, cifs = [], []
    for t in tables:
        if t in assoc_nm:
            continue
        for col, cible in fk_simple[t].items():
            if t in sous_types and col == pk[t][0]:
                continue                                    # lien d'héritage, pas une association
            c = cols[t][col]
            associations.append(dict(porteur=t, colonne=col, cible=cible, nom=NOMS.get((t, col), col.replace("id_", "")),
                                     card_porteur="1,1" if c["nn"] else "0,1", card_cible="0,1" if c["uq"] else "0,n"))
        for nom, definition in tables[t]["contraintes"]:
            m = re.match(r"FOREIGN KEY \(([^)]+)\) REFERENCES (\w+) \(([^)]+)\)", definition)
            if not m:
                continue
            src = [c.strip() for c in m.group(1).split(",")]
            cible_t, dst = m.group(2), [c.strip() for c in m.group(3).split(",")]
            nouvelles = [c for c in src if c not in fk_simple[t]]
            if not nouvelles:
                cifs.append((t, nom, cible_t, CIF_SENS.get(nom, definition)))
                continue
            col = nouvelles[0]
            col_dst = dst[src.index(col)]
            # cible réelle : si la table référencée est une association n,m, on remonte à l'entité
            entite_cible = fk_simple[cible_t].get(col_dst, cible_t) if cible_t in assoc_nm else cible_t
            c = cols[t][col]
            associations.append(dict(porteur=t, colonne=col, cible=entite_cible, nom=NOMS.get((t, col), col.replace("id_", "")),
                                     card_porteur="1,1" if c["nn"] else "0,1", card_cible="0,n", cif=nom))
            cifs.append((t, nom, cible_t, CIF_SENS.get(nom, definition)))
    return tables, cols, pk, fk_simple, sous_types, assoc_nm, entites, associations, cifs


def attributs(t, cols, pk, fk_simple):
    ident = [c for c in pk[t] if c not in fk_simple[t]]
    autres = [c for c in cols[t] if c not in pk[t] and c not in fk_simple[t]]
    return ident, autres


# ----------------------------------------------------------------------------------------------
# Dessin (Graphviz)
# ----------------------------------------------------------------------------------------------
def label_entite(t, cols, pk, fk_simple, sous_types, complet=True, externe=False):
    """Boîte Merise : nom, identifiant souligné, attributs (ou leur nombre en mode compact)."""
    ident, autres = attributs(t, cols, pk, fk_simple)
    bg, bord = ("#eeeeee", "#9aa0a6") if externe else ("#dbe6f7", "#4a7bd0")
    rows = [f'<TR><TD BGCOLOR="{bg}"><B>{t.upper()}</B></TD></TR>']
    if not externe:
        for a in ident:
            rows.append(f'<TR><TD ALIGN="LEFT"><U>{html.escape(a)}</U></TD></TR>')
        if t in sous_types:
            rows.append('<TR><TD ALIGN="LEFT"><I>(identifiant hérité)</I></TD></TR>')
        if complet:
            rows.extend(f'<TR><TD ALIGN="LEFT">{html.escape(a)}</TD></TR>' for a in autres)
        elif autres:
            rows.append(f'<TR><TD ALIGN="LEFT"><I>{len(autres)} attributs</I></TD></TR>')
    return (f'[shape=none, margin=0, label=<<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="3" '
            f'COLOR="{bord}">{"".join(rows)}</TABLE>>]')


def label_assoc_nm(t, cols, pk, fk_simple):
    autres = [c for c in cols[t] if c not in pk[t] and c not in fk_simple[t]]
    lab = f"<B>{NOMS_NM.get(t, t)}</B>" + "".join(f"<BR/>{html.escape(a)}" for a in autres)
    return f'[shape=ellipse, style=filled, fillcolor="#fff8e1", color="#c77700", label=<{lab}>]'


def _noeud_assoc(i, a):
    v842 = (a["porteur"], a["colonne"]) == ("acte", "id_mandat")
    return f'  a{i} [shape=ellipse, style=filled, fillcolor="#fff8e1", color="{"#e8710a" if v842 else "#c77700"}", label="{a["nom"]}"];'


def _aretes(assocs_bin, assocs_nm, heritages, pk, fk_simple):
    A = []
    for t, parent in heritages:
        A.append(f'  {parent} -- {t} [color="#4a7bd0:#4a7bd0", penwidth=1.2, label="est un"];')
    for t in assocs_nm:
        for c in pk[t]:
            A.append(f'  {fk_simple[t][c]} -- {t} [taillabel="0,n"];')
    for i, a in assocs_bin:
        v842 = (a["porteur"], a["colonne"]) == ("acte", "id_mandat")
        style = ' color="#e8710a" fontcolor="#e8710a" penwidth=2' if v842 else ""
        A.append(f'  {a["porteur"]} -- a{i} [taillabel="{a["card_porteur"]}"{style}];')
        A.append(f'  a{i} -- {a["cible"]} [headlabel="{a["card_cible"]}"{style}];')
    return A


def _graphe(titre, moteur, noeuds, aretes):
    # Vue d'ensemble en colonnes (dot, haut -> bas) ; domaines de gauche à droite.
    # (fdp donnerait un placement plus compact, mais n'est pas disponible dans tous les paquets Graphviz.)
    if moteur == "global":
        mise_en_page = "rankdir=TB, nodesep=0.25, ranksep=0.7"
    else:
        mise_en_page = "rankdir=LR, nodesep=0.35, ranksep=1.0"
    tete = f'  graph [label="{titre}", labelloc=t, fontname="Helvetica-Bold", fontsize=16, pad=0.3, splines=true, {mise_en_page}];'
    lignes = ["// GÉNÉRÉ par generer_mcd.py depuis livrables/db/01_ddl.sql : ne pas modifier à la main.",
              "graph MCD {", tete, '  node [fontname="Helvetica", fontsize=10];',
              '  edge [fontname="Helvetica-Bold", fontsize=10, color="#555555"];'] + noeuds + aretes + ["}"]
    return "\n".join(lignes) + "\n"


def dot_global(tables, cols, pk, fk_simple, sous_types, assoc_nm, entites, associations, cifs):
    """Vue d'ensemble : toutes les entités (compactes), toutes les associations et cardinalités."""
    titre = (f"MCD complet {VERSION} — vue d'ensemble (notation Merise, déduit des clés du DDL){NL}"
             f"{len(entites)} entités, {len(sous_types)} sous-types, {len(assoc_nm)} associations n,m, {len(associations)} associations binaires · "
             f"identifiant souligné · (min,max) = cardinalités · trait double = héritage · orange = ajouté en v8.42{NL}"
             "les attributs sont détaillés dans les schémas par domaine")
    N = [f"  {t} {label_entite(t, cols, pk, fk_simple, sous_types, complet=False)};" for t in list(entites) + list(sous_types)]
    N += [f"  {t} {label_assoc_nm(t, cols, pk, fk_simple)};" for t in assoc_nm]
    N += [_noeud_assoc(i, a) for i, a in enumerate(associations)]
    return _graphe(titre, "global", N, _aretes(list(enumerate(associations)), assoc_nm, list(sous_types.items()), pk, fk_simple))


def dot_domaine(nom, tables, cols, pk, fk_simple, sous_types, assoc_nm, entites, associations, cifs):
    """Un domaine en détail : ses entités avec tous leurs attributs ; les entités voisines en gris."""
    dom = set(DOMAINES[nom]) & set(tables)
    bin_ = [(i, a) for i, a in enumerate(associations) if a["porteur"] in dom or a["cible"] in dom]
    nm = [t for t in assoc_nm if t in dom or any(fk_simple[t][c] in dom for c in pk[t])]
    her = [(t, parent) for t, parent in sous_types.items() if t in dom or parent in dom]
    voisins = set()
    for _, a in bin_:
        voisins |= {a["porteur"], a["cible"]}
    for t in nm:
        voisins |= {fk_simple[t][c] for c in pk[t]}
    for t, parent in her:
        voisins |= {t, parent}
    voisins -= dom
    voisins -= set(assoc_nm)
    titre = (f"MCD {VERSION} — domaine « {nom} » : entités et attributs complets{NL}"
             "en gris : entités des autres domaines, détaillées dans leur propre schéma")
    N = [f"  {t} {label_entite(t, cols, pk, fk_simple, sous_types, complet=True)};" for t in dom if t not in assoc_nm]
    N += [f"  {t} {label_entite(t, cols, pk, fk_simple, sous_types, externe=True)};" for t in sorted(voisins)]
    N += [f"  {t} {label_assoc_nm(t, cols, pk, fk_simple)};" for t in nm]
    N += [_noeud_assoc(i, a) for i, a in bin_]
    return _graphe(titre, "dot", N, _aretes(bin_, nm, her, pk, fk_simple))


# ----------------------------------------------------------------------------------------------
# Document
# ----------------------------------------------------------------------------------------------
def markdown(tables, cols, pk, fk_simple, sous_types, assoc_nm, entites, associations, cifs):
    just = (ICI / "mcd-justifications.md").read_text(encoding="utf-8") if (ICI / "mcd-justifications.md").exists() else ""
    L = [f"# MCD complet — {VERSION} (vue de contrôle générée depuis le DDL)", "",
         "> ⚙️ **Schémas et tableaux GÉNÉRÉS depuis `livrables/db/01_ddl.sql`** par `sources/generer_mcd.py` : les cardinalités sont",
         "> déduites des clés (NOT NULL, UNIQUE, clés étrangères) et ne peuvent pas dériver du schéma réel. La section",
         "> « Justifications » est rédigée à la main (`sources/mcd-justifications.md`).", "",
         "> **Statut méthodologique.** En Merise, le MCD précède le MLD et le MPD : les MCD de **conception** sont ceux de",
         "> l'atelier de convergence d'août 2026 (Confluence, « MCD - Mermaid Code #01 ») et du dossier de modélisation (§3).",
         "> Ce document est une **rétro-ingénierie du schéma réel** : il sert de vue de contrôle à jour, pour vérifier que",
         "> le modèle implémenté est bien celui qui a été conçu, et pour retrouver chaque choix débattu. Il ne remplace pas",
         "> la démarche de conception, il la vérifie.", "",
         f"**{len(entites)} entités, {len(sous_types)} sous-types, {len(assoc_nm)} associations n,m, {len(associations)} associations binaires, "
         f"{len(cifs)} contraintes d'intégrité fonctionnelle.** Lecture Merise : une entité porte son identifiant (souligné) et ses attributs ;",
         "les clés étrangères du MLD n'apparaissent pas comme attributs, elles sont les associations.", "",
         "## Vue d'ensemble", "",
         f"![MCD complet {VERSION} — vue d'ensemble](mcd-v842-complet.png)", "",
         "## Schémas par domaine (attributs complets)", ""]
    for d in DOMAINES:
        L += [f"### {d}", "", f"![MCD {VERSION} — {d}](mcd-v842-{SLUGS[d]}.png)", ""]
    L += ["## Entités et identifiants", "", "| Entité | Identifiant | Attributs (hors clés étrangères) |", "|---|---|---|"]
    for t in entites:
        ident, autres = attributs(t, cols, pk, fk_simple)
        L.append(f"| `{t}` | {', '.join(f'`{c}`' for c in ident) or '—'} | {', '.join(f'`{c}`' for c in autres) or '—'} |")
    L += ["", "## Sous-types (héritage par clé partagée)", "", "| Sous-type | Sur-type | Attributs propres |", "|---|---|---|"]
    for t, parent in sous_types.items():
        _, autres = attributs(t, cols, pk, fk_simple)
        L.append(f"| `{t}` | `{parent}` | {', '.join(f'`{c}`' for c in autres) or '—'} |")
    L += ["", "## Associations n,m (tables de liaison)", "", "| Association | Entités liées | Attributs portés |", "|---|---|---|"]
    for t in assoc_nm:
        autres = [c for c in cols[t] if c not in pk[t] and c not in fk_simple[t]]
        L.append(f"| `{t}` (« {NOMS_NM.get(t, t)} ») | {' × '.join(f'`{fk_simple[t][c]}`' for c in pk[t])} | {', '.join(f'`{c}`' for c in autres) or '—'} |")
    L += ["", "## Associations binaires et cardinalités", "",
          "Cardinalité côté porteur : **(1,1)** si la clé étrangère est obligatoire, **(0,1)** sinon. Côté référencé : **(0,1)** si elle est unique, **(0,n)** sinon.", "",
          "| Entité porteuse | Association | Entité référencée | Porteur | Référencé | Colonne (MLD) |", "|---|---|---|---|---|---|"]
    for a in associations:
        cif = f" — FK composée {a['cif']}" if a.get("cif") else ""
        L.append(f"| `{a['porteur']}` | {a['nom']} | `{a['cible']}` | ({a['card_porteur']}) | ({a['card_cible']}) | `{a['colonne']}`{cif} |")
    L += ["", "## Contraintes d'intégrité fonctionnelle (CIF)", "",
          "Portées par des clés étrangères composées : elles ne créent pas d'association, elles garantissent la cohérence entre deux associations.", "",
          "| Table | Contrainte | Vers | Sens |", "|---|---|---|---|"]
    for t, nom, cible, sens in cifs:
        L.append(f"| `{t}` | {nom} | `{cible}` | {sens} |")
    L += ["", just.strip(), ""]
    return "\n".join(L)


def rendre(source, cible):
    dot_bin = shutil.which("dot")
    if not dot_bin:
        print(f"Graphviz absent : {source.name} écrit, {cible.name} non régénéré.")
        return False
    subprocess.run([dot_bin, "-Tpng", "-Gdpi=96", str(source), "-o", str(cible)], check=True)  # le moteur (fdp / dot) est déclaré dans le .dot
    print(f"Écrit : {cible}")
    return True


if __name__ == "__main__":
    donnees = analyser()
    tables, cols, pk, fk_simple, sous_types, assoc_nm, entites, associations, cifs = donnees
    (ICI / "mcd-complet.dot").write_text(dot_global(*donnees), encoding="utf-8", newline="\n")
    for d, slug in SLUGS.items():
        (ICI / f"mcd-{slug}.dot").write_text(dot_domaine(d, *donnees), encoding="utf-8", newline="\n")
    (MERISE / "mcd-v842-complet.md").write_text(markdown(*donnees), encoding="utf-8", newline="\n")
    print(f"MCD : {len(entites)} entités, {len(sous_types)} sous-types, {len(assoc_nm)} assoc. n,m, {len(associations)} assoc. binaires, {len(cifs)} CIF")
    sans_nom = [(a["porteur"], a["colonne"]) for a in associations if (a["porteur"], a["colonne"]) not in NOMS]
    if sans_nom:
        print("associations sans nom métier :", sans_nom)
    ok = rendre(ICI / "mcd-complet.dot", MERISE / "mcd-v842-complet.png")
    for slug in SLUGS.values():
        ok = rendre(ICI / f"mcd-{slug}.dot", MERISE / f"mcd-v842-{slug}.png") and ok
    sys.exit(0 if ok else 2)
