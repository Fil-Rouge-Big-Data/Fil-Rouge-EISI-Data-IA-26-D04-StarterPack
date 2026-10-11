# Livrable — Socle OLTP v8.41 & Migration

> Fork du starter pack. Ce fichier oriente vers **notre livrable** ; le
> `Readme.md` d'origine (sujet, consignes) est conservé tel quel.

## Où est quoi

| Dossier | Contenu |
|---|---|
| `livrables/db/` | Base OLTP v8.41 : DDL, triggers/vues, seed, harnais de tests, sondes |
| `livrables/migration/` | Pipeline de migration E-T-L-V (idempotent, récurrent) + tests |
| `livrables/jobs/` | Job d'anonymisation RGPD + DAG Airflow |
| `livrables/documentation/adr/` | 32 ADR (décisions d'architecture tracées) |
| `livrables/documentation/merise/` | MCD, MLD, **MPD**, dictionnaire de données (v8.41) |
| `livrables/documentation/migration/` | Mapping source→cible, arbitrages, recadrage, rapport |
| `livrables/documentation/PASSATION-v8.41.md` | Point de passation pour les fils aval (Airflow, API, MinIO, OLAP) |
| `fixtures/` | Base source héritée (`PgSQL.sql`) |
| `user-stories/` | User stories Gherkin |

## Démarrage rapide

> Procédure détaillée, sorties attendues, arrêt/remise à zéro et dépannage :
> [`livrables/documentation/LANCEMENT-DOCKER.md`](livrables/documentation/LANCEMENT-DOCKER.md).

**Prérequis** : Docker Desktop, Python 3.10+ et, sous Windows, **Git Bash**. Aucun client `psql`
n'est nécessaire (la validation SQL et la batterie de contraintes s'exécutent dans le conteneur).

```bash
# 1. environnement Python (une fois), puis activation (à refaire dans chaque terminal)
python -m venv .venv
source .venv/Scripts/activate        # Git Bash/Windows ; Linux/macOS : source .venv/bin/activate
python -m pip install -r livrables/migration/requirements.txt

# 2. secret : OBLIGATOIRE, aucun mot de passe par défaut
cp .env.example .env                 # cmd : copy .env.example .env
#    puis renseigner POSTGRES_PASSWORD dans .env (ex. openssl rand -hex 16)

# 3. bases cible (5433) + source (5434), schémas chargés au premier démarrage
docker compose up -d
docker compose ps                    # les deux services doivent être « healthy »

# 4. migration + validation + tests, puis batterie de contraintes
./run_migration_docker.sh
./run_tests_docker.sh
```

**Sous Windows**, les scripts `.sh` sont des scripts **bash** : les lancer depuis **Git Bash**,
venv activé dans ce même terminal (pas `cmd`, et pas `python ./script.sh`). Les commandes
`docker compose …` fonctionnent depuis `cmd`, PowerShell ou Git Bash.

> **Sécurité (poste de développement uniquement).** Les ports PostgreSQL ne sont publiés que
> sur `127.0.0.1` : les bases ne sont pas joignables depuis le réseau local. `.env` (secret) est
> ignoré par Git. Ne pas réutiliser ce `docker-compose.yml` en production.

Sans Docker : exporter `SRC_*` / `DST_*`, créer les deux bases, charger
`livrables/db/01_ddl.sql` puis `02_triggers_vues.sql`, et suivre
`livrables/migration/README.md`.

## Tests (tout vert, vérifié par exécution)

| Batterie | Commande | Résultat |
|---|---|---|
| Contraintes DDL (harnais probant) | `python livrables/db/run_tests.py` | 23 rejets, chacun par la contrainte attendue, + 4 valides |
| Sondes (anti-régression intégrité) | `python livrables/db/run_sondes.py` | 12 fermées / 0 ouverte |
| Migration | `pytest livrables/migration/tests/` | 48 tests |
| Anonymisation RGPD | `pytest livrables/jobs/anonymisation/` | 7 tests |
| Documentation contre schéma | `python livrables/db/verifier_dictionnaire.py` | cohérente (38 tables, 8 vues, 337 colonnes) |


## Version PostgreSQL

Le `docker-compose.yml` lance **PostgreSQL 16.15** (testé). Le schéma cible **PG18** (`uuidv7()` natif) mais fonctionne en PG16/17 via une fonction de repli. **PG18+ recommandé en production** ; pour tester en PG18, remplacer `postgres:16.15` par `postgres:18` dans le compose.

## Points clés v8.41

- Clés **UUIDv7** (PG18, fallback PG16) — ADR-044.
- **États entièrement dérivés** (mandat/demande/compromis) : pas de statut stocké,
  calcul en vues ; seuls faits et flags persistés — ADR-048.
- Table `mandat_reprise` (« repris fait foi ») pour les états repris non recalculables (ADR-051).
- Intégrité renforcée (FK composées, exclusions barème, chaîne de vente) — ADR-045.
- Habilitation loi Hoguet (carte T ou attestation) — ADR-046.
- Parrainage conforme au règlement — ADR-034.
- RGPD : anonymisation automatisée, médias hors base (MinIO) — ADR-043, ADR-042.

> Code **ciblant PG18**, testé sur **PG16** via le repli `uuidv7()`.
