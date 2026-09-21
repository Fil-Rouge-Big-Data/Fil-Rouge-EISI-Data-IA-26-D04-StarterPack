# outils/generer_annonces.py

Génère des jeux de données factices pour le projet :

- des **critères de recherche** (le futur modèle "demandes" structuré, à opposer au champ texte libre `mandats.description_recherche` de l'existant) ;
- des **annonces immobilières** correspondant à ces critères, avec un flux volontairement "sale" et hétérogène (champs absents ou renommés, dates dans des formats variés, géolocalisation pas toujours renseignée...), comme si les données provenaient de plusieurs sources différentes (agences, particuliers, plateformes).

Seuls les champs qui définissent la correspondance entre une annonce et sa recherche (ville, type de bien, prix, surface) sont garantis présents et cohérents avec le budget/la surface minimale demandés ; le reste des champs reste aléatoire.

Le script ne dépend d'aucune bibliothèque externe : uniquement la bibliothèque standard Python (3.x).

## Utilisation

Depuis la racine du projet :

```bash
python outils/generer_annonces.py
```

Le script est **cumulatif** : chaque exécution AJOUTE de nouveaux critères de recherche et de nouvelles annonces à ce qui a déjà été généré, sans jamais rien effacer. Pour repartir de zéro, supprimez le dossier `fixtures/annonces/` avant de relancer le script.

### Options

| Option | Défaut | Description |
| --- | --- | --- |
| `-r`, `--nombre-recherches` | `5` | Nombre de nouveaux critères de recherche à générer. |
| `--min-annonces` | `100` | Nombre minimum d'annonces générées par recherche. |
| `--max-annonces` | `1000` | Nombre maximum d'annonces générées par recherche. |

Exemple pour générer un petit jeu de données de test (10 recherches, 1 à 2 annonces chacune) :

```bash
python outils/generer_annonces.py -r 10 --min-annonces 1 --max-annonces 2
```

## Sorties

Le script crée (si besoin) et complète, à la racine du projet :

- `fixtures/annonces/recherches.csv` — tous les critères de recherche, un par ligne ;
- `fixtures/annonces/annonces.csv` — toutes les annonces, à plat (objets imbriqués aplatis avec un préfixe, ex. `contact.email`) ;
- `fixtures/annonces/json/annonce_XXXX.json` — une annonce par fichier JSON, numérotée séquentiellement.

Le dossier `fixtures/annonces/` est ignoré par git (voir `.gitignore`) : ce sont des données générées, pas des fixtures de référence versionnées.
