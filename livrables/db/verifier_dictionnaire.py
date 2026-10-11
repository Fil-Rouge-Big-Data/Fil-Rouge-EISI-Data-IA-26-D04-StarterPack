#!/usr/bin/env python3
"""Vérifie que la documentation des données décrit bien le schéma RÉEL (01_ddl.sql + 02_triggers_vues.sql).

Pourquoi : une documentation écrite à la main dérive du schéma sans que personne ne s'en aperçoive
(table renommée, colonne supprimée ou inventée, compteur périmé). Cet outil est hors-ligne : il lit
le DDL, pas la base, et peut donc tourner en CI sans PostgreSQL.

Contrôles (toute ERREUR => code retour 1), sur le dictionnaire rédigé à la main :
  E1  une section « ## table » cite une table qui n'existe pas dans le DDL ;
  E2  une ligne de tableau cite, pour une table, une colonne qui n'existe pas ;
  E3  une table du DDL n'a aucune section dans le dictionnaire ;
  E4  un nombre de tables ou de vues annoncé ne correspond pas au schéma ;
  E5  une vue du DDL n'est citée nulle part ;
  E6  le référentiel exhaustif GÉNÉRÉ (dictionnaire-colonnes-*.md) est absent ou périmé ;
  E8  un « ADR-0NN » cité dans la documentation n'est défini nulle part (ni fichier, ni titre, ni journal du prof) ;
  E7  le dictionnaire, le dossier de modélisation ou le MPD cite entre accents graves un identifiant
      technique (snake_case) qui n'existe nulle part dans le SQL — table renommée, colonne supprimée,
      trigger renommé. Les lignes qui parlent explicitement d'un ancien nom (« ex- », « remplace »,
      « supprimé », « retiré »…) sont tolérées.

Sont ignorés : la section « Évolutions » (journal historique), les colonnes barrées ~~x~~ (suppressions
documentées) et les écritures abrégées « a/b/c » qui ne peuvent pas être résolues sans ambiguïté.

Usage :  python livrables/db/verifier_dictionnaire.py [dictionnaire.md] [dossier_db]
"""
import pathlib
import re
import sys

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))
import generer_dictionnaire_colonnes as g  # noqa: E402

DB_DIR = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ICI
MERISE_DIR = DB_DIR.parent / "documentation" / "merise"
# identifiants légitimes qui ne sont pas dans le SQL (noms d'environnement, de fichiers de configuration…)
TOLERES = {
    "chasse_v8", "chasse_source", "chasse_migration", "sources_yml",     # environnement
    "fait_vente", "fait_performance_chasseur", "fait_activite_demande",  # pistes de l'étoile OLAP : PRÉVUES, pas encore créées
    "network_mode", "cap_add", "cap_drop", "read_only",                  # options Docker Compose citées dans la doc de sécurité
}
# noms de contraintes générés automatiquement par PostgreSQL (ex. utilisateur_email_key) : absents du texte du DDL
AUTO_PG = re.compile(r"_(key|pkey|fkey|check|excl)$")


def trouver_dictionnaire():
    if len(sys.argv) > 1:
        return pathlib.Path(sys.argv[1])
    return MERISE_DIR / f"dictionnaire-donnees-{g.version_courante(MERISE_DIR)}.md"


def lire_vues():
    sql = DB_DIR / "02_triggers_vues.sql"
    return set(re.findall(r"CREATE (?:OR REPLACE )?VIEW (\w+)", sql.read_text(encoding="utf-8"))) if sql.exists() else set()


def identifiants(cellule):
    """Noms de colonnes cités dans la 1re cellule d'une ligne (les écritures abrégées « a/b » sont ignorées)."""
    cellule = re.sub(r"~~.*?~~", "", cellule).replace("`", "").replace("**", "").strip()
    return [m for m in (c.strip() for c in cellule.split(",")) if "/" not in m and re.fullmatch(r"[a-z][a-z0-9_]*", m)]


def main():
    dico = trouver_dictionnaire()
    if not dico.exists():
        print(f"Dictionnaire introuvable : {dico}", file=sys.stderr)
        return 2
    tables = {t: [c["nom"] for c in d["colonnes"]] for t, d in g.lire_tables(DB_DIR).items()}
    vues = lire_vues()
    texte = dico.read_text(encoding="utf-8")
    erreurs = []

    coupe = re.search(r"^# Évolutions", texte, re.M)           # journal historique exclu
    corps = texte[:coupe.start()] if coupe else texte

    courante, documentees, nb_sections, nb_lignes = None, set(), 0, 0
    for no, ligne in enumerate(corps.split("\n"), 1):
        titre = re.match(r"^## (.+)$", ligne)
        if titre:
            brut, courante = titre.group(1), None
            if re.match(r"(Annexe|Conventions)", brut):
                continue
            noms = re.findall(r"\b[a-z][a-z0-9_]*\b", re.sub(r"\(.*?\)", "", brut))
            courante = [n for n in noms if n in tables]
            for n in noms:
                if n not in tables and n not in vues:
                    erreurs.append(f"E1  ligne {no} : la section « {brut} » cite `{n}` : cette table n'existe pas dans le DDL")
            documentees.update(courante)
            nb_sections += 1
            continue
        if courante and ligne.startswith("|") and ligne.count("|") >= 2:
            cellule = ligne.split("|")[1].strip()
            if cellule.lower() in ("colonne", "élément", "table") or set(cellule) <= set("-: "):
                continue
            connues = {c for t in courante for c in tables[t]}
            for n in identifiants(cellule):
                nb_lignes += 1
                if n not in connues and n not in tables:
                    erreurs.append(f"E2  ligne {no} : `{n}` n'est pas une colonne de {', '.join(courante)}")

    for t in sorted(set(tables) - documentees):
        erreurs.append(f"E3  la table `{t}` existe dans le DDL mais n'a aucune section dans le dictionnaire")
    for m in re.finditer(r"(\d+)\s+tables?\b", corps):
        if int(m.group(1)) != len(tables):
            erreurs.append(f"E4  « {m.group(0)} » annoncé, mais le DDL contient {len(tables)} tables")
    for m in re.finditer(r"(\d+)\s+vues?\b", corps):
        if vues and int(m.group(1)) != len(vues):
            erreurs.append(f"E4  « {m.group(0)} » annoncé, mais le DDL contient {len(vues)} vues")
    for v in sorted(vues):
        if v not in corps:
            erreurs.append(f"E5  la vue `{v}` n'est citée nulle part dans le dictionnaire")

    version = re.search(r"-(v\d+)\.md$", dico.name)
    v = version.group(1) if version else g.version_courante(MERISE_DIR)
    annexe = MERISE_DIR / f"dictionnaire-colonnes-{v}.md"
    if not annexe.exists():
        erreurs.append(f"E6  le référentiel exhaustif {annexe.name} est absent : python livrables/db/generer_dictionnaire_colonnes.py")
    elif annexe.read_text(encoding="utf-8") != g.generer(DB_DIR, v):
        erreurs.append(f"E6  {annexe.name} est périmé par rapport au DDL : python livrables/db/generer_dictionnaire_colonnes.py")


    # E7 : identifiants cités entre accents graves qui n'existent plus dans le SQL
    brut = "\n".join(f.read_text(encoding="utf-8").lower() for f in (DB_DIR / "01_ddl.sql", DB_DIR / "02_triggers_vues.sql") if f.exists())
    # le CODE fait foi, pas les commentaires : un « ex-mandat_etat » écrit en commentaire ne rend pas ce nom « connu »
    sql = re.sub(r"comment on .*?;", "", re.sub(r"--[^\n]*", "", brut), flags=re.S)
    connus = set(re.findall(r"[a-z][a-z0-9_]*", sql)) | TOLERES
    historique = re.compile(r"\b(?:ex-|remplac|supprim|retir|anciennement|ancien|renomm|scind|n'existe plus|n'existent plus|plus de |historique|avant)|\(plus ", re.I)
    cibles = [dico, dico.with_name(f"dossier-modelisation-{v}.md"), dico.with_name(f"mpd-{v}.md")]
    cibles += sorted(dico.parent.parent.glob("PASSATION-v*.md"))     # le document qui alimente les prochains fils
    for doc in cibles:
        if not doc.exists():
            continue
        txt = doc.read_text(encoding="utf-8")
        cut = re.search(r"^# Évolutions", txt, re.M)
        for no, ligne in enumerate((txt[:cut.start()] if cut else txt).split("\n"), 1):
            if historique.search(ligne):
                continue
            for jeton in re.findall(r"`([a-z][a-z0-9_]*)`", ligne):
                if "_" in jeton and jeton not in connus and not AUTO_PG.search(jeton):
                    erreurs.append(f"E7  {doc.name} ligne {no} : `{jeton}` n'existe nulle part dans le SQL")


    # E8 : chaque ADR cité est défini quelque part (fichier, titre, numéro proposé, ou journal de décisions du prof)
    adr_dir = DB_DIR.parent / "documentation" / "adr"
    journal = DB_DIR.parents[1] / "documents utiles" / "JOURNAL-DE-DECISIONS.md"
    definis = set()
    for f in adr_dir.glob("ADR-*.md"):
        m = re.match(r"ADR-(\d{3})-", f.name)
        if m:
            definis.add(m.group(1))
        lignes = f.read_text(encoding="utf-8").split("\n")
        for l in lignes[:8]:                                  # « Numéro : proposé ADR-032 »
            definis.update(re.findall(r"(?:Numéro|proposé)[^\n]*?ADR-(\d{3})", l))
        for l in lignes:
            if l.startswith("#"):
                definis.update(re.findall(r"ADR-(\d{3})", l))
    if journal.exists():
        for l in journal.read_text(encoding="utf-8").split("\n"):
            if l.startswith("#"):
                definis.update(re.findall(r"ADR-(\d{3})", l))
    cites = {}
    cibles_e8 = cibles + sorted(adr_dir.glob("*.md")) + sorted((DB_DIR.parent / "documentation" / "migration").glob("*.md"))
    for doc in cibles_e8:
        if doc.exists():
            for n in set(re.findall(r"ADR-(\d{3})", doc.read_text(encoding="utf-8"))):
                cites.setdefault(n, set()).add(doc.name)
    for n in sorted(set(cites) - definis):
        erreurs.append(f"E8  ADR-{n} est cité ({', '.join(sorted(cites[n]))[:90]}) mais défini nulle part")

    n_col = sum(len(c) for c in tables.values())
    print(f"Dictionnaire : {dico.name}")
    print(f"Schéma       : {len(tables)} tables, {len(vues)} vues, {n_col} colonnes ({DB_DIR / '01_ddl.sql'})")
    print(f"Sections     : {nb_sections} ; tables documentées : {len(documentees)}/{len(tables)} ; "
          f"colonnes citées vérifiées : {nb_lignes}")
    if erreurs:
        print(f"\n{len(erreurs)} ERREUR(S) :")
        print("\n".join("  " + e for e in erreurs))
        return 1
    print("\nOK : la documentation est cohérente avec le schéma.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
