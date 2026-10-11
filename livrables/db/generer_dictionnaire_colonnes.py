#!/usr/bin/env python3
"""Génère le référentiel EXHAUSTIF des colonnes (une ligne par colonne) depuis le DDL.

Pourquoi : un dictionnaire écrit à la main finit par dériver du schéma (colonnes inventées, tables
oubliées). Ce fichier-ci ne peut pas dériver : il est produit mécaniquement par lecture de
`01_ddl.sql`. Le dictionnaire rédigé à la main (`dictionnaire-donnees-*.md`) garde le SENS MÉTIER ;
ce référentiel porte l'EXHAUSTIVITÉ (type, nullité, clés, défauts, règles, commentaires du DDL).

Usage :
    python livrables/db/generer_dictionnaire_colonnes.py             # (ré)écrit le fichier
    python livrables/db/generer_dictionnaire_colonnes.py --verifier  # code 1 s'il est périmé
"""
import pathlib
import re
import sys

DB_DIR = pathlib.Path(__file__).resolve().parent
MERISE_DIR = DB_DIR.parent / "documentation" / "merise"

NIVEAU_TABLE = {"CONSTRAINT", "PRIMARY", "UNIQUE", "FOREIGN", "CHECK", "EXCLUDE", "LIKE"}
SUITE = {"REFERENCES", "DEFAULT", "NOT", "NULL", "ON", "GENERATED", "USING", "WITH", "AND", "OR"}


def _parenthese_equilibree(texte, debut):
    """Sous-chaîne de `debut` (qui pointe sur '(') jusqu'à la parenthèse fermante correspondante
    (les parenthèses situées dans une chaîne entre apostrophes sont ignorées)."""
    profondeur, dans_chaine = 0, False
    for i in range(debut, len(texte)):
        c = texte[i]
        if c == "'":
            dans_chaine = not dans_chaine
        elif not dans_chaine:
            if c == "(":
                profondeur += 1
            elif c == ")":
                profondeur -= 1
                if profondeur == 0:
                    return texte[debut:i + 1]
    return texte[debut:]


def _compacter(texte, limite=110):
    texte = re.sub(r"\s+", " ", texte).strip()
    return texte if len(texte) <= limite else texte[:limite - 1] + "…"


def _cellule(texte):
    return texte.replace("|", "\\|")


def lire_tables(db_dir=DB_DIR):
    """{table: {"colonnes": [dict...], "contraintes": [(nom, définition)...]}} dans l'ordre du DDL."""
    ddl = (pathlib.Path(db_dir) / "01_ddl.sql").read_text(encoding="utf-8")
    resultat = {}
    for m in re.finditer(r"CREATE TABLE (\w+) \(\n(.*?)\n\);", ddl, re.S):
        elements, courant, profondeur = [], None, 0
        for brut in m.group(2).split("\n"):
            code, _, commentaire = brut.partition("--")
            code, commentaire = code.rstrip(), commentaire.strip()
            nu = code.strip()
            if profondeur == 0 and nu:
                mot = re.match(r"\w+", nu)
                premier = mot.group(0).upper() if mot else ""
                if premier in NIVEAU_TABLE:
                    courant = {"genre": "table", "texte": nu, "commentaire": commentaire}
                    elements.append(courant)
                elif premier in SUITE and courant is not None:
                    courant["texte"] += " " + nu
                    courant["commentaire"] = (courant["commentaire"] + " " + commentaire).strip()
                else:
                    courant = {"genre": "colonne", "texte": nu, "commentaire": commentaire}
                    elements.append(courant)
            elif courant is not None and (nu or commentaire) and (profondeur > 0 or nu):
                courant["texte"] += " " + nu
                courant["commentaire"] = (courant["commentaire"] + " " + commentaire).strip()
            sans_chaines = re.sub(r"'[^']*'", "''", code)      # une parenthèse dans une chaîne ('[)') ne compte pas
            profondeur += sans_chaines.count("(") - sans_chaines.count(")")

        colonnes, contraintes, cles_primaires, uniques_simples = [], [], set(), set()
        for e in elements:
            texte = e["texte"].rstrip(",").strip()
            if e["genre"] == "table":
                mc = re.match(r"CONSTRAINT\s+(\w+)\s+(.*)$", texte, re.S)
                nom, definition = (mc.group(1), mc.group(2)) if mc else ("", texte)
                if re.match(r"PRIMARY KEY\s*\(", definition):
                    cles_primaires |= {c.strip() for c in definition[definition.index("(") + 1:definition.index(")")].split(",")}
                mu = re.match(r"UNIQUE\s*\(\s*(\w+)\s*\)", definition)
                if mu:                                    # UNIQUE (une_colonne) : c'est la colonne qui est unique
                    uniques_simples.add(mu.group(1))
                contraintes.append((nom, _compacter(definition, 150)))
                continue
            nom_col, reste = re.match(r"(\w+)\s+(.*)$", texte, re.S).groups()
            reste_maj = reste.upper()
            type_ = re.match(r"\w+(?:\s*\(\s*\d+\s*(?:,\s*\d+\s*)?\))?", reste).group(0)
            fk = re.search(r"REFERENCES\s+(\w+)\s*\(\s*(\w+)\s*\)", reste)
            check = ""
            i = reste_maj.find("CHECK")
            if i >= 0 and "(" in reste[i:]:
                check = "CHECK " + _compacter(_parenthese_equilibree(reste, reste.index("(", i)), 90)
            defaut = re.search(r"\bDEFAULT\s+(.+?)(?=\s+(?:NOT NULL|NULL|CHECK|REFERENCES|UNIQUE|PRIMARY KEY)\b|\s*$)", reste, re.I)
            colonnes.append({
                "nom": nom_col,
                "type": re.sub(r"\s+", "", type_),
                "nn": "NOT NULL" in reste_maj or "PRIMARY KEY" in reste_maj,
                "pk": "PRIMARY KEY" in reste_maj,
                "uq": bool(re.search(r"\bUNIQUE\b", reste, re.I)),
                "fk": f"{fk.group(1)}({fk.group(2)})" if fk else "",
                "regle": " ; ".join(x for x in ((f"DEFAULT {defaut.group(1).strip()}" if defaut else ""), check) if x),
                "commentaire": e["commentaire"],
            })
        for c in colonnes:
            if c["nom"] in cles_primaires:
                c["pk"], c["nn"] = True, True
            if c["nom"] in uniques_simples:
                c["uq"] = True
        resultat[m.group(1)] = {"colonnes": colonnes, "contraintes": contraintes}
    return resultat


def version_courante(merise_dir=MERISE_DIR):
    for f in sorted(pathlib.Path(merise_dir).glob("dictionnaire-donnees-v*.md"), reverse=True):
        m = re.search(r"-(v\d+)\.md$", f.name)
        if m and m.group(1) != "v7":
            return m.group(1)
    return "v841"


def generer(db_dir=DB_DIR, version="v841"):
    tables = lire_tables(db_dir)
    n_col = sum(len(t["colonnes"]) for t in tables.values())
    sortie = [
        f"# Référentiel des colonnes — {version} (généré)", "",
        "> ⚙️ **Fichier GÉNÉRÉ depuis `livrables/db/01_ddl.sql` : ne pas le modifier à la main.**",
        "> Régénération : `python livrables/db/generer_dictionnaire_colonnes.py`. "
        "Contrôle : `python livrables/db/verifier_dictionnaire.py`.",
        ">",
        f"> **{len(tables)} tables, {n_col} colonnes**, une ligne par colonne : type, nullité, clés, défauts,",
        "> règles et commentaires tels qu'écrits dans le DDL. Le **sens métier** et les justifications sont",
        f"> dans `dictionnaire-donnees-{version}.md` ; ce fichier garantit l'**exhaustivité**.", "",
        "Légende : **NN** = NOT NULL ; **PK** = clé primaire ; **UQ** = unique ; **FK** = clé étrangère.", "", "---", "",
    ]
    for nom, t in tables.items():
        sortie += [f"## {nom}", "", "| Colonne | Type | NN | Clé / lien | Défaut / règle | Commentaire (DDL) |", "|---|---|---|---|---|---|"]
        for c in t["colonnes"]:
            cle = " ".join(x for x in ("PK" if c["pk"] else "", "UQ" if c["uq"] else "", f"FK→{c['fk']}" if c["fk"] else "") if x)
            sortie.append("| " + " | ".join([_cellule(f"`{c['nom']}`"), _cellule(f"`{c['type']}`"), "oui" if c["nn"] else "",
                                             _cellule(cle), _cellule(c["regle"]), _cellule(_compacter(c["commentaire"], 160))]) + " |")
        if t["contraintes"]:
            sortie += ["", "**Contraintes de table :**"]
            for n, d in t["contraintes"]:
                sortie.append(f"- {('`' + n + '` — ') if n else ''}`{_cellule(d)}`")
        sortie += ["", ""]
    return "\n".join(sortie).rstrip() + "\n"


def chemin_sortie(merise_dir=MERISE_DIR, version=None):
    return pathlib.Path(merise_dir) / f"dictionnaire-colonnes-{version or version_courante(merise_dir)}.md"


if __name__ == "__main__":
    version = version_courante()
    cible = chemin_sortie(version=version)
    contenu = generer(version=version)
    if "--verifier" in sys.argv:
        if not cible.exists() or cible.read_text(encoding="utf-8") != contenu:
            print(f"PÉRIMÉ : {cible.name} ne correspond plus au DDL. Régénérer : "
                  "python livrables/db/generer_dictionnaire_colonnes.py")
            sys.exit(1)
        print(f"OK : {cible.name} est à jour avec le DDL.")
    else:
        cible.write_text(contenu, encoding="utf-8")
        print(f"Écrit : {cible} ({contenu.count(chr(10))} lignes)")
