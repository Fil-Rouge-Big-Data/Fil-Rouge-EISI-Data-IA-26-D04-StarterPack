# Job d'anonymisation RGPD

Implémente la politique de rétention de l'**ADR-043** : anonymise — par `UPDATE`,
jamais `DELETE` — les clients arrivés à échéance de conservation.

> ⚠️ Entreprise et données fictives. Livrable pédagogique (RNCP40573).

---

## Règles de routage (ADR-043)

Le job classe chaque client puis décide :

| Catégorie | Critère | Conservation | À échéance |
|---|---|---|---|
| **Prospect** | aucune demande | 3 ans après `date_creation` | anonymisé |
| **Client (relation)** | demandes, aucun acte | 3 ans après dernière activité | anonymisé |
| **Client (transaction)** | au moins un acte signé | conservation légale longue | **conservé** |

« Anonymiser » = remplacer nom/prénom/email/téléphone/mot de passe par des
valeurs neutres, poser `actif = false` et `date_anonymisation = now()`. La ligne
et l'historique métier restent (statistiques, IA). Conforme à la contrainte C12
(`date_anonymisation IS NULL OR actif = false`).

Le compte technique `SYS-MIGRATION` est toujours exclu.

---

## Usage

```bash
# variables de connexion (comme la migration)
export DST_PGHOST=127.0.0.1 DST_PGPORT=5433 \
       DST_PGUSER=chasse_migration DST_PGDATABASE=chasse_v8

# aperçu sans écriture
python anonymiser.py --dry-run --date-ref 2026-07-25 --seuil-ans 3

# exécution
python anonymiser.py --date-ref 2026-07-25 --seuil-ans 3
```

Sans `--date-ref`, la date du jour est utilisée. `--seuil-ans` vaut 3 par défaut.

**Idempotent** : ne traite que les lignes où `date_anonymisation IS NULL`.
Rejouer ne ré-anonymise pas.

---

## Planification

Deux modes, au choix selon l'avancement de l'infrastructure :

- **Cron** (en attendant Airflow) :
  ```cron
  0 2 * * *  cd /chemin/jobs/anonymisation && python anonymiser.py >> /var/log/anonymisation.log 2>&1
  ```
- **Airflow** : déposer `dag_anonymisation_rgpd.py` dans le dossier `dags/`.
  Le DAG tourne chaque nuit à 02:00, réutilise exactement le même module
  `anonymiser` et prend la date logique du run comme date de référence.

---

## Tests

```bash
pytest test_anonymiser.py
```

Six tests d'intégration (base cible requise, sinon skip) : routage prospect
ancien/récent, respect de C12, neutralisation des données, idempotence, et
exclusion de `SYS-MIGRATION`. La non-anonymisation des clients transactionnels
est garantie par la requête de classement (catégorie `transactionnel` → conservé).

---

## Points ouverts (backlog ADR-043)

- Durées exactes de conservation des pièces liées à l'acte : à figer avec le
  métier / un conseil juridique (la catégorie transactionnelle est aujourd'hui
  conservée sans date de purge).
- Champs précis à neutraliser vs conserver pour les clients transactionnels
  (anonymisation partielle à l'échéance légale).
- Journalisation des runs dans une table dédiée (sur le modèle de
  `staging.migration_run`).
