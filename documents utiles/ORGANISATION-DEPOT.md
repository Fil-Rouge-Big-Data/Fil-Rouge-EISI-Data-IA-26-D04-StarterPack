# 🗃️ Organisation du dépôt & conventions — modèle

> **Fiche + modèle.** Le Readme du projet insiste : « quelqu'un doit pouvoir venir dans l'équipe en cours de route et comprendre ». Un dépôt bien rangé et des conventions claires servent directement cet objectif. Utile dès le lancement, transverse (soutient **BC02**).

## À quoi ça sert

Un projet à deux, sur plusieurs semaines, avec des dizaines de fichiers, devient vite un labyrinthe. Des règles simples de nommage et d'organisation évitent : les fichiers « rapport_final_v2_vraiment_final.md », les écrasements, et le « où as-tu mis le MCD ? ».

---

## Organisation de dossiers suggérée

```
Projet/
├── Readme.md                  ← porte d'entrée du projet
├── fixtures/                  ← données de départ (ne pas modifier)
├── documents utiles/          ← fiches de cours et modèles
├── livrables/                 ← VOS productions
│   ├── 1-audit/
│   ├── 2-modelisation/        ← MCD, migration.sql…
│   ├── 3-architecture/
│   └── 4-application/
└── decisions/                 ← vos ADR (journal de décisions)
```

> Adaptez, mais gardez une logique : **par phase** ou **par type de livrable**, pas en vrac à la racine.

## Conventions de nommage

* **Pas d'espaces ni d'accents** dans les noms de fichiers de code (`migration.sql`, pas `migration finale.sql`).
* **Pas de "final", "v2", "vraiment_final"** : c'est le rôle du versionnage (Git) de garder l'historique.
* **Préfixe par phase** si utile : `2-mcd-cible.md`, `3-matrice-archi.md`.
* **Cohérence** : choisissez une casse (kebab-case `mon-fichier` conseillé) et tenez-vous-y.

---

## Si vous utilisez Git

> Git garde l'historique de toutes les versions : plus besoin de dupliquer les fichiers.

### Messages de commit clairs
Format simple et lisible :
```
type: description courte à l'impératif

Exemples :
feat: ajoute le MCD cible de la Phase 2
fix: corrige la cardinalité mandat-client
docs: rédige la note de cadrage
```
Types courants : `feat` (nouveauté), `fix` (correction), `docs` (documentation), `refactor` (réorganisation).

### Bonnes pratiques
* **Commits petits et fréquents**, un par idée cohérente.
* **Ne jamais committer** de mots de passe ou de données personnelles réelles.
* **Un `.gitignore`** pour exclure les fichiers temporaires, les dumps volumineux, les secrets.
* **Travailler à deux** : se répartir les fichiers pour éviter les conflits, communiquer avant de modifier un fichier commun.

---

## Modèle à remplir

* **Structure de dossiers retenue :** _(la vôtre)_
* **Convention de nommage :** _(kebab-case ? préfixe par phase ?)_
* **Répartition binôme :** _(qui travaille sur quoi — voir RACI)_
* **Outil de versionnage :** _(Git ? dossier partagé ?)_

> ⚠️ À l'oral, un dépôt propre et navigable donne d'emblée une impression de sérieux. Un jury qui trouve facilement vos livrables est un jury bien disposé.