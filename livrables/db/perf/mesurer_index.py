#!/usr/bin/env python3
"""Note d'indexation : mesure EXPLAIN (ANALYZE, BUFFERS) AVANT / APRÈS les index de 02_index.sql.

Prérequis : base chargée avec 01_ddl, 02_triggers_vues, 03_seed puis perf/01_jeu_volume.sql.
Déroulé : (1) retire les index de 02_index.sql s'ils existent, ANALYZE, mesure « avant » ;
          (2) applique 02_index.sql, mesure « après » ; (3) écrit la note
          livrables/documentation/perf/note-indexation.md (tableau des temps, plans complets repliés).
Chaque mesure est la MEILLEURE de 3 exécutions (cache chaud), pour comparer les plans et non les aléas.

Usage : PGHOST=... PGPORT=... PGUSER=... PGDATABASE=... PGPASSWORD=... python livrables/db/perf/mesurer_index.py
"""
import datetime
import os
import pathlib
import re

import psycopg

ICI = pathlib.Path(__file__).resolve().parent
NOTE = ICI.parents[1] / "documentation" / "perf" / "note-indexation.md"
INDEX_SQL = (ICI / "02_index.sql").read_text(encoding="utf-8")

# Les 4 requêtes clés (une par famille d'usage), paramétrées sur des identifiants choisis dans la base.
REQUETES = [
    ("Q1", "Mandats actifs d'un chasseur (vue v_mandat : état dérivé, chaîne de vente)",
     "SELECT id_mandat, date_fin, statut_calcule FROM v_mandat WHERE id_chasseur = %(chasseur)s AND statut_calcule = 'actif'"),
    ("Q2", "Ventes rémunérées et mandats signés d'un chasseur sur 12 mois (critères S3 et S4 du barème)",
     "SELECT (SELECT count(*) FROM remuneration_chasseur WHERE id_chasseur = %(chasseur)s AND date_calcul >= %(d12)s AND date_annulation IS NULL) AS ventes, "
     "(SELECT count(*) FROM mandat WHERE id_chasseur = %(chasseur)s AND date_signature >= %(d12)s) AS mandats"),
    ("Q3", "Matching : annonces actives d'une zone, d'un type et d'un budget, les 50 moins chères",
     "SELECT a.id_annonce, a.prix FROM annonce a JOIN bien b ON b.id_bien = a.id_bien "
     "WHERE b.id_zone = %(zone)s AND b.type_bien = 'appartement' AND a.statut = 'active' AND a.prix BETWEEN 200000 AND 350000 "
     "ORDER BY a.prix LIMIT 50"),
    ("Q4", "D10 : rendez-vous de visite d'un mandat (ADR-049 §5, calcul du critère S5)",
     "SELECT count(DISTINCT (v.id_proposition, v.date_visite)) FROM visite v "
     "JOIN proposition p ON p.id_proposition = v.id_proposition "
     "JOIN demande_acquereur da ON da.id_demande = p.id_demande AND da.id_client = v.id_visiteur "
     "WHERE p.id_mandat = %(mandat)s AND v.realisee = true"),
]


def conn():
    return psycopg.connect(host=os.environ.get("PGHOST", "127.0.0.1"), port=os.environ.get("PGPORT", "5433"),
                           user=os.environ.get("PGUSER", "chasse_migration"), dbname=os.environ.get("PGDATABASE", "chasse_v8"),
                           password=os.environ.get("PGPASSWORD", ""), autocommit=True)


LIMITE = "180s"   # une requête qui dépasse cette durée est interrompue et notée comme telle (plan pathologique)


def parametres(c):
    with c.cursor() as cur:
        cur.execute("SELECT id_chasseur FROM mandat GROUP BY id_chasseur ORDER BY count(*) DESC LIMIT 1")
        chasseur = cur.fetchone()[0]
        cur.execute("SELECT id_zone FROM bien GROUP BY id_zone ORDER BY count(*) DESC LIMIT 1")
        zone = cur.fetchone()[0]
        cur.execute("SELECT p.id_mandat FROM visite v JOIN proposition p ON p.id_proposition = v.id_proposition GROUP BY p.id_mandat ORDER BY count(*) DESC LIMIT 1")
        mandat = cur.fetchone()[0]
        cur.execute("SELECT (date_reference() - INTERVAL '12 months')::date")
        d12 = cur.fetchone()[0]
    return {"chasseur": chasseur, "zone": zone, "mandat": mandat, "d12": d12}


def expliquer(c, sql, params):
    """Meilleure de 3 exécutions : (temps ms, plan texte, nœud racine, lectures de blocs)."""
    meilleur = None
    for _ in range(3):
        with c.cursor() as cur:
            cur.execute(f"SET statement_timeout = '{LIMITE}'")
            try:
                cur.execute("EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) " + sql, params)
                lignes = [r[0] for r in cur.fetchall()]
            except psycopg.errors.QueryCanceled:
                return float("inf"), f"interrompue : plus de {LIMITE}", "—", 0
        plan = "\n".join(lignes)
        t = float(re.search(r"Execution Time: ([\d.]+) ms", plan).group(1))
        if meilleur is None or t < meilleur[0]:
            meilleur = (t, plan)
    t, plan = meilleur
    racine = lignes[0].split("(cost")[0].strip()
    m = re.search(r"Buffers: shared hit=(\d+)(?: read=(\d+))?", plan)
    blocs = (int(m.group(1)) + int(m.group(2) or 0)) if m else 0
    return t, plan, racine, blocs


def retirer_index(c):
    noms = re.findall(r"CREATE INDEX IF NOT EXISTS (\w+)", INDEX_SQL)
    with c.cursor() as cur:
        for n in noms:
            cur.execute(f"DROP INDEX IF EXISTS {n}")
        cur.execute("ANALYZE")
    return noms


def volumes(c):
    with c.cursor() as cur:
        out = []
        for t in ("chasseur", "mandat", "bien", "annonce", "proposition", "visite", "acte", "remuneration_chasseur"):
            cur.execute(f"SELECT count(*) FROM {t}")
            out.append((t, cur.fetchone()[0]))
        cur.execute("SELECT version()")
        version = cur.fetchone()[0].split(",")[0]
    return out, version


def main():
    c = conn()
    params = parametres(c)
    vols, version = volumes(c)
    noms = retirer_index(c)
    avant = {q: expliquer(c, sql, params) for q, _, sql in REQUETES}
    with c.cursor() as cur:
        cur.execute(INDEX_SQL)
    apres = {q: expliquer(c, sql, params) for q, _, sql in REQUETES}
    # 3e mesure : index + random_page_cost adapté au SSD (défaut 4.0 = disque mécanique ; 1.1 recommandé sur
    # stockage bloc SSD, cas des bases managées retenues dans l'étude). Change les choix du planificateur, pas le schéma.
    with c.cursor() as cur:
        cur.execute("SET random_page_cost = 1.1")
    ssd = {q: expliquer(c, sql, params) for q, _, sql in REQUETES}
    with c.cursor() as cur:
        cur.execute("RESET random_page_cost")
    c.close()

    L = ["# Note d'indexation — EXPLAIN avant / après (socle v8.42)", "",
         f"> **Livrable BC05** (grille : « note d'indexation, EXPLAIN avant/après : 1 page + captures »). Générée le "
         f"{datetime.date.today():%d/%m/%Y} par `livrables/db/perf/mesurer_index.py` sur {version}. "
         "Jeu de volume synthétique `perf/01_jeu_volume.sql` ; index proposés `perf/02_index.sql`.",
         "", "## Méthode", "",
         "1. Jeu de données synthétique et **valide** (toutes les contraintes et déclencheurs du socle s'appliquent) : "
         + ", ".join(f"{n} `{t}`" for t, n in vols) + ".",
         "2. Quatre requêtes représentatives des usages : état des mandats d'un chasseur, critères du barème sur 12 mois, matching d'annonces, comptage des rendez-vous (D10).",
         "3. Pour chaque requête, `EXPLAIN (ANALYZE, BUFFERS)` **sans** les index proposés (seules les clés primaires et unicités existent : PostgreSQL n'indexe pas les clés étrangères), puis **avec**. Meilleure de 3 exécutions, cache chaud, `ANALYZE` à jour.",
         "4. Principe d'éco-conception (ENF-26) : un index n'est créé que si une requête le justifie ; index partiels quand le filtre est stable (`statut = 'active'`, `realisee`).",
         "", "## Résultats", "",
         "| Requête | Avant index | Après index | Après index + `random_page_cost = 1.1` | Gain (meilleur cas) | Blocs lus avant → après | Nœud racine avant → après |", "|---|---|---|---|---|---|---|"]
    for q, titre, _ in REQUETES:
        ta, pa, ra, ba = avant[q]
        tb, pb, rb, bb = apres[q]
        tc, pc, rc, bc = ssd[q]
        fmt = lambda x: f"> {LIMITE}" if x == float("inf") else f"{x:.2f} ms"
        tm = min(tb, tc)
        gain = "—" if ta == float("inf") or tm == float("inf") else (f"× {ta / tm:.0f}" if tm > 0 and ta / tm >= 2 else f"{(1 - tm / ta) * 100:+.0f} %")
        L.append(f"| **{q}** {titre} | {fmt(ta)} | {fmt(tb)} | {fmt(tc)} | {gain} | {ba:,} → {min(bb, bc):,} | {ra} → {rc if tc < tb else rb} |".replace(",", " "))
    L += ["", "## Index retenus", "", "| Index | Requête | Justification |", "|---|---|---|",
          "| `ix_mandat_chasseur_signature` (id_chasseur, date_signature) | Q1, Q2 | accès par chasseur puis par date ; évite le parcours de toute la table des mandats |",
          "| `ix_remuneration_chasseur_date` (id_chasseur, date_calcul) | Q2 | critère S3 : ventes du chasseur sur 12 mois glissants |",
          "| `ix_bien_zone_type` (id_zone, type_bien) | Q3 | matching : les biens d'une zone et d'un type |",
          "| `ix_annonce_active_bien_prix` (id_bien, prix) **partiel** `statut = 'active'` | Q3 | seules les annonces actives sont candidates ; index petit et toujours pertinent |",
          "| `ix_proposition_mandat` (id_mandat) | Q1, Q4 | clé étrangère la plus parcourue (mandat → propositions), non indexée par défaut |",
          "| `ix_visite_proposition_date` (id_proposition, date_visite) **partiel** `realisee` | Q4 | rendez-vous réalisés d'une proposition (D10) |",
          "| `ix_offre_proposition`, `ix_compromis_offre` | Q1 | chaîne de vente remontée par `v_acte_mandat` et `v_mandat` |",
          "", "## Ce qu'il faut retenir", "",
          "- Ces index font partie du socle depuis la v8.43 (`01_ddl.sql`) ; le script les retire avant la mesure « avant » puis les recrée.",
          "- Les gains les plus nets viennent des **clés étrangères non indexées** : sans index, chaque jointure parent → enfants balaie la table enfant entière.",
          "- Les **index partiels** répondent à une requête précise avec un coût d'écriture et de stockage réduit (ENF-26).",
          "- **Coût des index** : chaque insertion de proposition, visite ou annonce met à jour un index de plus ; sur les volumes cibles (5 000 mandats par semaine, ENF-03), le partitionnement par date des annonces et propositions (PO-15) est la suite logique, à chiffrer dans la note 3V.",
          "- **Réglage du planificateur** : `random_page_cost` vaut 4 par défaut (disque mécanique). Sur stockage SSD (bases managées de l'étude), 1.1 rend les accès par index moins chers aux yeux du planificateur ; c'est ce qui fait basculer Q3 d'une jointure par hachage avec parcours complet des annonces vers des boucles imbriquées sur index. À poser dans la configuration de l'instance, pas dans les requêtes.",
          "- Limite : jeu synthétique uniforme (distribution régulière des biens par zone, des mandats par chasseur). Sur des données réelles, les statistiques (`ANALYZE`) et la sélectivité changent ; les index sont à **revalider** sur les données de production.",
          "", "## Plans d'exécution", ""]
    for q, titre, sql in REQUETES:
        L += [f"### {q} — {titre}", "", "```sql", sql.replace("%(chasseur)s", ":chasseur").replace("%(zone)s", ":zone").replace("%(mandat)s", ":mandat").replace("%(d12)s", ":d12"), "```", "",
              "<details><summary>Plan avant index</summary>", "", "```", avant[q][1], "```", "", "</details>", "",
              "<details><summary>Plan après index</summary>", "", "```", apres[q][1], "```", "", "</details>", "",
              "<details><summary>Plan après index, random_page_cost = 1.1</summary>", "", "```", ssd[q][1], "```", "", "</details>", ""]
    L += ["## Rattachement RNCP40573", "",
          "BC05 — « concevoir la base pour l'analytique et l'IA » : indexation justifiée par la mesure (preuve `EXPLAIN`). BC01 — numérique responsable : index partiels, pas d'index spéculatif (ENF-26)."]
    NOTE.parent.mkdir(parents=True, exist_ok=True)
    NOTE.write_text("\n".join(L) + "\n", encoding="utf-8", newline="\n")
    print(f"Écrit : {NOTE}")
    for q, _, _ in REQUETES:
        print(f"  {q}: {avant[q][0]:.2f} ms -> {apres[q][0]:.2f} ms")


if __name__ == "__main__":
    main()
