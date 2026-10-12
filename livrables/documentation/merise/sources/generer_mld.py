#!/usr/bin/env python3
"""Génère le MLD textuel (schéma relationnel Merise) depuis `livrables/db/01_ddl.sql`.

Forme : TABLE(<u>clé primaire</u>, attributs, #clé étrangère). Pour chaque relation : les références
(clé étrangère -> table cible, obligatoire ou non, unique ou non), les clés étrangères composées, les
unicités et les règles (CHECK, EXCLUDE). Les domaines de valeurs (CREATE DOMAIN) sont listés.
La section « Normalisation » est rédigée à la main (`mld-normalisation.md`) et insérée telle quelle.

Pourquoi générer : le MLD publié jusqu'ici (v5) avait dérivé de 33 tables du schéma réel. Celui-ci est
déduit du DDL et contrôlé par `--verifier` (code 1 s'il est périmé), comme le dictionnaire des colonnes.

Usage :
    python livrables/documentation/merise/sources/generer_mld.py             # (ré)écrit ../mld-v842-relationnel.md
    python livrables/documentation/merise/sources/generer_mld.py --verifier  # code 1 si le fichier est périmé
"""
import pathlib
import re
import sys

ICI = pathlib.Path(__file__).resolve().parent
MERISE = ICI.parent
DB_DIR = MERISE.parents[1] / "db"
sys.path.insert(0, str(DB_DIR))
sys.path.insert(0, str(ICI))
import generer_dictionnaire_colonnes as g  # noqa: E402
from generer_mcd import DOMAINES  # noqa: E402

VERSION = "v8.42"
CIBLE = MERISE / "mld-v842-relationnel.md"


def domaines_valeurs(ddl):
    out = []
    for m in re.finditer(r"CREATE DOMAIN (\w+)\s+AS\s+(.*?);", ddl, re.S):
        definition = re.sub(r"--[^\n]*", "", m.group(2))
        out.append((m.group(1), re.sub(r"\s+", " ", definition).strip()))
    return out


def relation(t, x):
    parts = []
    for c in x["colonnes"]:
        s = f"<u>{c['nom']}</u>" if c["pk"] else c["nom"]
        if c["fk"]:
            s = "#" + s
        parts.append(s)
    return f"**{t.upper()}** ({', '.join(parts)})"


def details(t, x):
    L = []
    for c in x["colonnes"]:
        if c["fk"]:
            quals = []
            quals.append("obligatoire" if c["nn"] else "facultative")
            if c["uq"]:
                quals.append("unique")
            L.append(f"- `{c['nom']}` → `{c['fk']}` ({', '.join(quals)})")
    for nom, definition in x["contraintes"]:
        d = re.sub(r"\s+", " ", definition).strip()
        if d.startswith("FOREIGN KEY"):
            L.append(f"- clé étrangère composée `{nom}` : {d}")
        elif d.startswith("UNIQUE") or d.startswith("EXCLUDE"):
            L.append(f"- {'unicité' if d.startswith('UNIQUE') else 'exclusion'} `{nom}` : {d}")
    checks = [nom for nom, d in x["contraintes"] if d.strip().startswith("CHECK")]
    checks += [c["nom"] for c in x["colonnes"] if "CHECK" in c["regle"]]
    if checks:
        L.append(f"- règles CHECK : {', '.join(f'`{n}`' for n in checks if n)}")
    return L


def generer():
    tables = g.lire_tables(DB_DIR)
    ddl = (DB_DIR / "01_ddl.sql").read_text(encoding="utf-8")
    nb_cols = sum(len(x["colonnes"]) for x in tables.values())
    nb_fk = sum(1 for x in tables.values() for c in x["colonnes"] if c["fk"])
    norm = (ICI / "mld-normalisation.md").read_text(encoding="utf-8") if (ICI / "mld-normalisation.md").exists() else ""
    L = [f"# MLD relationnel — {VERSION} (généré)", "",
         "> ⚙️ **Fichier GÉNÉRÉ depuis `livrables/db/01_ddl.sql`** par `sources/generer_mld.py` : ne pas le modifier à la main.",
         "> Contrôle : `python livrables/documentation/merise/sources/generer_mld.py --verifier` (code 1 s'il est périmé).",
         "> La section « Normalisation » est rédigée à la main (`sources/mld-normalisation.md`).", "",
         f"**{len(tables)} relations, {nb_cols} attributs, {nb_fk} clés étrangères simples.** Notation : <u>souligné</u> = clé primaire, "
         "`#` = clé étrangère. Les types, nullités et défauts colonne par colonne sont dans `dictionnaire-colonnes-v841.md` ;",
         "le sens métier dans `dictionnaire-donnees-v841.md` ; les cardinalités dans `mcd-v842-complet.md`.", "",
         "## Règles de passage MCD → MLD appliquées", "",
         "| Construction du MCD | Traduction relationnelle |", "|---|---|",
         "| Entité | Relation ; identifiant → clé primaire (UUIDv7, ADR-028 rév., ADR-044) |",
         "| Association binaire (1,1)–(0,n) ou (0,1)–(0,n) | Clé étrangère côté (x,1) ; `NOT NULL` si (1,1) |",
         "| Association binaire (0,1)–(0,1) | Clé étrangère `UNIQUE` côté porteur (ex. `acte.id_compromis`, `mandat.id_mandat_precedent`) |",
         "| Association n,m | Relation dont la clé primaire est composée des clés des entités liées, plus les attributs portés |",
         "| Association ternaire | Idem, clé à trois composantes (`observation`, `objectif`) |",
         "| Héritage (sous-type) | Clé partagée : la clé primaire du sous-type est une clé étrangère vers le sur-type (ADR-026) |",
         "| Contrainte d'intégrité fonctionnelle | Clé étrangère composée vers une clé unique composée (ex. `(id_mandat, id_demande)`) |", ""]
    vus = set()
    for dom, ts in DOMAINES.items():
        L += [f"## {dom}", ""]
        for t in ts:
            if t not in tables:
                continue
            vus.add(t)
            L += [relation(t, tables[t]), ""] + details(t, tables[t]) + [""]
    restantes = [t for t in tables if t not in vus]
    if restantes:
        L += ["## Autres relations", ""]
        for t in restantes:
            L += [relation(t, tables[t]), ""] + details(t, tables[t]) + [""]
    L += ["## Domaines de valeurs (CREATE DOMAIN)", "", "| Domaine | Définition |", "|---|---|"]
    for nom, definition in domaines_valeurs(ddl):
        L.append(f"| `{nom}` | {definition} |")
    L += ["", norm.strip(), ""]
    return "\n".join(L)


if __name__ == "__main__":
    contenu = generer()
    if "--verifier" in sys.argv:
        if not CIBLE.exists() or CIBLE.read_text(encoding="utf-8").replace("\r\n", "\n") != contenu:
            print(f"PÉRIMÉ : {CIBLE.name} ne correspond plus au DDL. Régénérer : python {pathlib.Path(__file__).as_posix()}")
            sys.exit(1)
        print(f"OK : {CIBLE.name} est à jour avec le DDL.")
    else:
        CIBLE.write_text(contenu, encoding="utf-8", newline="\n")
        print(f"Écrit : {CIBLE} ({contenu.count(chr(10))} lignes)")
