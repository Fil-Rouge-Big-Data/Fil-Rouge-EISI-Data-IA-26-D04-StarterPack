# Lancer l'environnement (Docker + venv Python)

Procédure pour démarrer les deux bases PostgreSQL, rejouer la migration et les tests.
Écrite pour Windows (Docker Desktop + Git Bash), valable à l'identique sous Linux/macOS.

> ⚠️ Poste de développement uniquement : ne pas réutiliser ce `docker-compose.yml` en production.

---

## 0. Prérequis

| Outil | Pourquoi | Vérification |
|---|---|---|
| **Docker Desktop** (démarré) | héberge les deux bases | `docker --version` |
| **Python 3.10+** | pipeline de migration et tests | `python --version` |
| **Git Bash** (fourni avec Git for Windows) | les deux scripts `.sh` sont des scripts **bash** | ouvrir « Git Bash » |

Aucun client `psql` n'est nécessaire : la validation SQL et la batterie de contraintes
s'exécutent **dans le conteneur** (`docker exec`).

---

## 1. Environnement Python (venv)

À faire **une seule fois**, depuis la racine du dépôt :

```bash
python -m venv .venv
```

Puis **activer** le venv. L'activation est **propre à chaque terminal** : à refaire dans
chaque fenêtre où l'on lance les scripts.

| Terminal | Commande d'activation |
|---|---|
| **Git Bash** (Windows) | `source .venv/Scripts/activate` |
| cmd | `.venv\Scripts\activate.bat` |
| PowerShell | `.venv\Scripts\Activate.ps1` (si refusé : `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`) |
| Linux / macOS | `source .venv/bin/activate` |

Le prompt affiche alors `(.venv)`. Installer les dépendances (une fois) :

```bash
python -m pip install -r livrables/migration/requirements.txt
```

> Les scripts détectent le venv actif et l'utilisent en priorité (variable `VIRTUAL_ENV`).
> `.venv/` est ignoré par Git : il ne sera jamais commité.

---

## 2. Définir le mot de passe (obligatoire)

```bash
cp .env.example .env          # cmd : copy .env.example .env
```

Éditer `.env` et renseigner `POSTGRES_PASSWORD=` avec un secret en **lettres et chiffres
uniquement** (les caractères spéciaux sont interprétés par Compose ou bash) :

- Git Bash / Linux / macOS : `openssl rand -hex 16`
- PowerShell : `-join ((48..57)+(65..90)+(97..122) | Get-Random -Count 24 | % {[char]$_})`

Sans mot de passe, `docker compose up` s'arrête avec
`required variable POSTGRES_PASSWORD is missing a value` : c'est voulu (aucun mot de passe par
défaut). `.env` est ignoré par Git. **Ne jamais coller son contenu dans un message ou une PR.**

---

## 3. Démarrer les bases et vérifier

```bash
docker compose up -d
docker compose ps
```

Attendu : `chasse_oltp` et `chasse_source` à l'état **(healthy)**, ports
`127.0.0.1:5433->5432/tcp` et `127.0.0.1:5434->5432/tcp`.

Vérifier que les ports ne sont pas exposés sur le réseau :

```bash
docker compose port postgres-oltp 5432        # attendu : 127.0.0.1:5433
docker compose port postgres-source 5432      # attendu : 127.0.0.1:5434
```

Vérifier que les schémas ont été chargés au premier démarrage :

```bash
docker exec chasse_oltp psql -U chasse_migration -d chasse_v8 -c "SELECT table_type, count(*) FROM information_schema.tables WHERE table_schema='public' GROUP BY 1 ORDER BY 1"
docker exec chasse_source psql -U chasse_migration -d chasse_source -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='Fil_Rouge_Depart'"
```

Attendu : `BASE TABLE | 38`, `VIEW | 8` (soit **46** si on ne filtre pas le type), et `3` pour la source.

---

## 4. Rejouer la migration et les tests

Dans **Git Bash**, venv activé, depuis la racine du dépôt :

```bash
./run_migration_docker.sh      # migration + validation SQL + 48 tests
./run_tests_docker.sh          # batterie de contraintes
```

Sorties attendues :

| Script | Attendu |
|---|---|
| `run_migration_docker.sh` | `[OK] source=historique lignes=153 anomalies=73`, `Validation OK`, `48 passed` |
| `run_tests_docker.sh` | `REJETS : 23/23 correctement rejetés`, `VALIDES : 4/4 correctement acceptés` |

> ⚠️ **Les deux scripts remettent le schéma de `chasse_v8` à zéro** (`DROP SCHEMA public CASCADE`
> puis rechargement) avant de s'exécuter : ils peuvent donc être lancés **dans n'importe quel
> ordre**, mais n'y conserver aucune donnée à garder. Le journal de migration, lui (`staging`), est
> préservé d'un lancement à l'autre.

Optionnel, depuis le venv (Git Bash) : tests d'anonymisation RGPD et batterie de sondes.

```bash
export PGPASSWORD="<ton mot de passe>"
export REQUIRE_DB=1 DST_PGHOST=127.0.0.1 DST_PGPORT=5433 DST_PGUSER=chasse_migration \
       DST_PGDATABASE=chasse_v8 DST_PGPASSWORD="$PGPASSWORD"
python -m pytest livrables/jobs/anonymisation -q                       # attendu : 7 passed
PGHOST=127.0.0.1 PGPORT=5433 PGUSER=chasse_migration PGDATABASE=chasse_v8 \
  python livrables/db/run_sondes.py                                    # attendu : 12 fermées / 0 ouvertes
```

`REQUIRE_DB=1` fait **échouer** les tests d'intégration si la base est injoignable, au lieu de
les ignorer en silence.

---

## 5. Se connecter à la base

```bash
docker exec -it chasse_oltp psql -U chasse_migration -d chasse_v8
```

---

## 6. Arrêter, repartir de zéro

| Besoin | Commande | Effet |
|---|---|---|
| Arrêter | `docker compose down` | conteneurs supprimés, **données conservées** (volumes) |
| Redémarrer | `docker compose up -d` | reprend les mêmes données |
| **Tout remettre à zéro** | `docker compose down -v` puis `docker compose up -d` | ⚠️ **supprime les volumes** : les bases sont recréées et les scripts SQL rechargés |

Les scripts d'initialisation (`01_ddl.sql`, …) ne s'exécutent qu'au **premier démarrage d'un
volume vide**. Après une modification des fichiers SQL, il faut `down -v` pour qu'elle soit
rechargée.

---

## 6bis. Vérifier la documentation

La documentation des données (dictionnaire, dossier de modélisation, MPD, passation) peut dériver du schéma. Deux commandes, sans base de données :

```bash
python livrables/db/generer_dictionnaire_colonnes.py   # régénère le référentiel exhaustif des colonnes
python livrables/db/verifier_dictionnaire.py           # échoue si la documentation ne décrit plus le schéma
```

`run_tests_docker.sh` lance déjà le second à la fin. Un code `E1`…`E8` indique ce qui dérive : section ou colonne inexistante, table non documentée, compteur faux, vue jamais citée, référentiel périmé, identifiant disparu cité dans le texte, ADR cité sans définition.

## 7. Dépannage

| Symptôme | Cause | Solution |
|---|---|---|
| `required variable POSTGRES_PASSWORD is missing a value` | pas de `.env`, ou mot de passe vide | étape 2 |
| `SyntaxError: invalid decimal literal` en lançant un `.sh` | script lancé avec `python` | lancer `./run_….sh` depuis **Git Bash** |
| `Python 3 introuvable` | Python absent du PATH | installer Python 3.10+, cocher « Add to PATH » |
| `ModuleNotFoundError: psycopg` / `yaml` | dépendances non installées, ou venv non activé **dans ce terminal** | étape 1 |
| `bind: address already in use` (5433/5434) | un PostgreSQL local occupe déjà le port | l'arrêter, ou changer le port **hôte** dans `docker-compose.yml` (`127.0.0.1:55433:5432`) et les variables `*_PGPORT` |
| `46` au lieu de `38` | la requête compte aussi les 8 vues | filtrer sur `table_type` (étape 3) : 38 tables + 8 vues |
| `$'\r' : commande introuvable` | script enregistré avec des fins de ligne Windows (CRLF) | convertir en LF (éditeur) ; un `git clone` conserve LF grâce à `.gitattributes` |
| `docker : commande introuvable` dans Git Bash | Docker Desktop non démarré ou PATH | démarrer Docker Desktop, rouvrir Git Bash |
| Les scripts sont **très lents**, ou semblent figés sur « Migration… » (Windows) | `localhost` est d'abord essayé en IPv6 (`::1`) alors que Docker n'écoute qu'en IPv4 : chaque connexion perd du temps (mesuré sur un poste Windows : ~30 s, plafonné par le délai de la mesure, contre 0,03 s pour `127.0.0.1`), et un lancement ouvre 16 connexions | corrigé : les scripts imposent `127.0.0.1`, même si ton `.env` contient `localhost`. Dans tes propres commandes, utilise **toujours `127.0.0.1`**, jamais `localhost` |
| `ImportError: no pq wrapper available` ou `No module named 'psycopg_binary'` | commande lancée avec le Python **du système**, venv non activé dans ce terminal | activer le venv (le prompt doit commencer par `(.venv)`) ; `python -c "import sys; print(sys.prefix)"` doit afficher un chemin `.venv` |
| `export : commande introuvable`, ou erreur sur `<<'EOF'`, dans PowerShell ou cmd | commande écrite pour Git Bash lancée dans un autre terminal | lancer les commandes `export …` et `<<EOF` dans **Git Bash**. En PowerShell : `$env:PGPASSWORD = "…"` |
| `[ECHEC] duplicate key value violates unique constraint "utilisateur_email_key"` pendant la migration | la base cible contenait déjà un compte avec ce même e-mail **sous un autre identifiant** : typiquement le jeu de test chargé par `run_tests_docker.sh` (le compte `m.roussel@chassimmo.fr` existe aussi dans la source) | corrigé : `run_migration_docker.sh` remet le schéma à zéro avant de migrer. Rien n'est écrit en cas d'échec (transaction unique) |
| `[!! ECHEC : mauvaise contrainte] Txx … -> rejeté par A AU LIEU DE B` dans `run_tests_docker.sh` | le test est bien rejeté, mais par une autre contrainte que celle qu'il vise : il ne prouve donc rien sur la règle B (souvent un jeu de données qui bute plus tôt) | corriger le SQL du test pour qu'il atteigne B, ou la table `ATTENDU` de `livrables/db/run_tests.py` si c'est la règle qui a changé |
