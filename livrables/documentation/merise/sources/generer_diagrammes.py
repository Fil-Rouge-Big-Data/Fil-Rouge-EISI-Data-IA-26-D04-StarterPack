#!/usr/bin/env python3
"""Régénère les images du MCD et du MLD (Graphviz).

- MCD : `mcd-concept.dot`, rédigé à la main (niveau conceptuel : entités et associations
  principales, avec leur sens métier).
- MLD : produit MÉCANIQUEMENT depuis `livrables/db/01_ddl.sql` (une flèche par couple
  parent → enfant relié par au moins une clé étrangère). Il ne peut donc pas dériver du schéma.

Usage :
    python livrables/documentation/merise/sources/generer_diagrammes.py
Écrit `mld-relationnel.dot` à côté de ce script, puis les PNG dans le dossier merise
si la commande `dot` (Graphviz) est disponible ; sinon, seulement les fichiers .dot.
"""
import pathlib
import re
import shutil
import subprocess
import sys

ICI = pathlib.Path(__file__).resolve().parent
MERISE = ICI.parent
DDL = MERISE.parents[1] / "db" / "01_ddl.sql"
VERSION = "v8.42"

# Tables ajoutées ou renommées depuis la v8.3 (encadré orange), et liens ajoutés en v8.42 (trait orange).
TABLES_RECENTES = {"mandat_reprise", "note_avis_document", "facture_document"}
LIENS_V842 = {("mandat", "acte")}


def cles_etrangeres(ddl_texte):
    """(tables, liens) : liens = couples distincts (parent, enfant) reliés par une clé étrangère."""
    sql = re.sub(r"--[^\n]*", "", ddl_texte)
    tables = {m.group(1): m.group(2) for m in re.finditer(r"CREATE TABLE (\w+) \((.*?)\n\);", sql, re.S)}
    liens = set()
    for enfant, corps in tables.items():
        for r in re.finditer(r"REFERENCES\s+(\w+)", corps):
            liens.add((r.group(1), enfant))
    for enfant, parent in re.findall(r"ALTER TABLE (\w+)\s+ADD CONSTRAINT \w+ FOREIGN KEY .*? REFERENCES (\w+)", sql, re.S):
        liens.add((parent, enfant))
    return sorted(tables), sorted(liens)


def dot_mld(tables, liens):
    lignes = [
        "// MLD — GÉNÉRÉ par generer_diagrammes.py depuis livrables/db/01_ddl.sql : ne pas modifier à la main.",
        "digraph MLD {",
        f'  graph [label="MLD {VERSION} — {len(tables)} tables, {len(liens)} liens (une flèche = une clé étrangère, parent → enfant)\\n'
        'encadré orange = table ajoutée ou renommée depuis la v8.3 ; trait orange = lien ajouté en v8.42", '
        'labelloc=t, fontname="Helvetica-Bold", fontsize=16, rankdir=LR, nodesep=0.35, ranksep=0.9, pad=0.2];',
        '  node [shape=box, style="rounded,filled", fontname="Helvetica", fontsize=10, fillcolor="#e8f0fe", color="#4a7bd0"];',
        '  edge [color="#9aa0a6", arrowsize=0.6, fontname="Helvetica"];',
    ]
    for t in tables:
        style = ' [fillcolor="#fff0e6", color="#e8710a", penwidth=2.5]' if t in TABLES_RECENTES else ""
        lignes.append(f"  {t}{style};")
    for parent, enfant in liens:
        if parent == enfant:
            lignes.append(f'  {parent} -> {enfant} [label="précédent", fontsize=8, style=dashed];')
        elif (parent, enfant) in LIENS_V842:
            lignes.append(f'  {parent} -> {enfant} [color="#e8710a", penwidth=2.2, label="hors dispositif", fontsize=8, fontcolor="#e8710a"];')
        else:
            lignes.append(f"  {parent} -> {enfant};")
    lignes.append("}")
    return "\n".join(lignes) + "\n"


def rendre(source, cible):
    dot = shutil.which("dot")
    if not dot:
        print(f"Graphviz absent : {source.name} écrit, {cible.name} non régénéré.")
        return False
    subprocess.run([dot, "-Tpng", "-Gdpi=110", str(source), "-o", str(cible)], check=True)
    print(f"Écrit : {cible}")
    return True


if __name__ == "__main__":
    tables, liens = cles_etrangeres(DDL.read_text(encoding="utf-8"))
    mld = ICI / "mld-relationnel.dot"
    mld.write_text(dot_mld(tables, liens), encoding="utf-8", newline="\n")
    print(f"MLD : {len(tables)} tables, {len(liens)} liens -> {mld.name}")
    ok = rendre(ICI / "mcd-concept.dot", MERISE / "mcd-v841-concept.png")
    ok = rendre(mld, MERISE / "mld-v841-relationnel.png") and ok
    sys.exit(0 if ok else 2)
