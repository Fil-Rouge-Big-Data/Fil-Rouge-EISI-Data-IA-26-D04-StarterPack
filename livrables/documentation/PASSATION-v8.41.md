# Passation v8.41 — socle OLTP & migration (pour les fils aval)

> **Mode d'emploi.** Colle ce document en tête d'un nouveau fil (Airflow, API REST,
> MinIO, OLAP/Power BI…). Il donne le contexte du socle livré sans rejouer
> l'historique. Remplace la ligne « OBJECTIF DE CE FIL » par ta cible.

---

## OBJECTIF DE CE FIL
<!-- À COMPLÉTER : « Orchestration Airflow », « API REST backend »,
     « Object storage MinIO », « ETL OLAP + Power BI »… -->

---

## 1. Le projet en deux phrases

Refonte du SI d'un service de **chasse immobilière** (un chasseur cherche des biens
pour un particulier acheteur, sous mandat). Projet pédagogique **RNCP40573** —
entreprise, données et personnages **fictifs**. Date de référence : **25 juillet 2026**.

## 2. Ce qui est DÉJÀ LIVRÉ (v8.41 — ne pas refaire)

- **Base OLTP v8.41**, PostgreSQL 18 (compatible 16+), schéma `public`, clés
  **UUIDv7**. **38 tables, 8 vues**, DDL rejouable/transactionnel, testé.
- **Migration** de l'existant (base héritée) vers l'OLTP : pipeline **E-T-L-V**
  idempotent, **récurrent** (prévu pour les rachats, ADR-001), journal d'anomalies.
- **Job d'anonymisation RGPD** (routage prospect/client/transactionnel), DAG Airflow fourni.
- **Documentation** : 20 ADR, Merise complet (MCD, MLD, MPD, dictionnaire), tous v8.41.
- **Tests** : harnais de contraintes probant (23 rejets + 5 valides), batterie de
  sondes (5), migration (43), anonymisation (6).

Le dépôt Git est la source de vérité du code. Ce fil **consomme** ce socle.

## 3. Doctrine du modèle (à connaître absolument pour l'aval)

### 3.1 États entièrement dérivés (ADR-048) — IMPORTANT pour l'API et l'OLAP
Le modèle **ne stocke PAS les statuts de progression**. L'état se calcule dans des
vues, à partir des faits. Conséquence directe pour toi :

- **Ne lis jamais `mandat.statut`, `demande.statut`, `compromis.statut`** — ces
  colonnes **n'existent pas**. Lis `v_mandat.statut_calcule`,
  `v_demande.statut_calcule`, `v_compromis.statut_calcule`.
- Un mandat est **actif/échu** selon `date_debut + 6 mois` vs la date de référence
  (calcul, pas colonne). Un **succès** = il existe un acte rattaché. Un
  **renouvellement** = il existe un mandat successeur. Seuls **résiliation**
  (`date_resiliation`), **caducité** (`date_caducite`), **sans-suite**
  (`date_sans_suite`) sont des faits stockés (flags).
- `demande.id_mandat_courant` désigne le mandat en cours (fait de gestion).
- La version de critères courante = `v_version_courante` (max `no_version`).

### 3.2 Projection d'état `mandat_etat` (ADR-048 §3)
Table qui matérialise l'état du mandat. `origine='repris'` = fait historique non
recalculable (migrations de rachats), **fait foi**, jamais écrasé. `origine='calcule'`
= cache régénérable. **Un job de rafraîchissement incrémental** (à construire côté
Airflow) alimente les lignes `calcule` de la frange volatile — c'est un chantier
orchestration naturel.

### 3.3 Autres doctrines
- **Frontière OLTP/OLAP (ADR-025, 036)** : l'OLTP ne porte pas les mesures
  comparatives/agrégées (délais moyens, perf). Ça relève de l'**OLAP**.
- **Pas de techno par mode (Règle 6)** : une brique (NoSQL, Hadoop…) ne s'ajoute
  que si un besoin réel la démontre.
- **UUIDv7** : type `uuid`, généré ordonné ; bascule native en PG18.
- **Pas de DELETE physique** : cycle par faits/flags ; suppression = anonymisation.
- **RGPD** : anonymisation par UPDATE, octets média hors base.

## 3bis. Changements v8.41 CRITIQUES pour l'aval (API, OLAP)

Lis ceci avant de coder quoi que ce soit contre le schéma :

1. **Critères client = `pref_*`, plus de booléens `exige_*`** (ADR-052). Chaque critère
   (`pref_balcon`, `pref_jardin`, `pref_ascenseur`, `pref_terrasse`, `pref_parking`,
   `pref_cave` sur `demande_version`) prend 4 valeurs : `exige` · `souhaite` · `exclut` ·
   `indifferent`. **`exclut` = refus** : un bien qui possède ce critère doit être
   **rejeté** par le matching. `souhaite` = bonus, non bloquant.
2. **Score de rémunération** : composantes = `score_delai`, `score_exclusivite`,
   `score_ventes`, `score_mandats`, `score_visites` (+ `score_performance` global).
   Pondération (délai 25 · exclusivité 10 · ventes 25 · mandats 15 · visites 25) =
   dans le **moteur de calcul**, pas en base. Le nombre de visites se **compte**
   (visites réalisées, 12 mois glissants) ; aucune colonne compteur.
3. **Base nommée `chasse_v8`** (plus `chasse_v7`). Variables : `DST_PGDATABASE=chasse_v8`.
4. **Tests d'intégration bruyants** : `REQUIRE_DB=1` = échec si la base est absente
   (une CI ne doit jamais être verte sans avoir testé). Toujours lancer avec.
5. **Droit à rémunération** : dérivé de l'existence de l'acte (ADR-049) ; ventes
   externes = `mandat.type_resiliation='vente_externe'`, pas d'acte.

## 4. Repères techniques par fil

### Airflow / orchestration
- Patron de DAG fourni : `jobs/anonymisation/dag_anonymisation_rgpd.py` (Python qui
  déclenche un traitement et journalise).
- Deux jobs naturels : (a) **anonymisation RGPD** quotidienne (existe), (b)
  **rafraîchissement `mandat_etat`** incrémental (à construire, ADR-048 §3).
- La **migration récurrente** (rachats) est elle-même un workflow orchestrable
  (`migration/src/run_migration.py`, paramétrable par `config/sources.yml`).

### API REST / backend
- Stack cohérente : **Python** ; si ORM, **SQLAlchemy + Alembic** (versionnement
  retenu). Lire les **vues** pour les états, pas les colonnes (cf. §3.1).
- Règles métier déjà portées par la base (FK composées, triggers) : l'API ne les
  réimplémente pas, elle les respecte.
- RGPD : reset mot de passe au 1er login pour les comptes migrés (sentinelle).

### MinIO / object storage (ADR-042)
- Les fichiers média (note d'avis audio/vidéo, documents) vivent **hors OLTP**.
  La base ne stocke qu'une **URI** dans `document.uri`. MinIO (compatible S3) est
  retenu ; décision d'infra à finaliser côté backend.
- `note_avis` est rattachée au **mandat** ; `document_rattachement` est polymorphe
  (note_avis | facture_chasseur).

### OLAP / Power BI
- Partir des **vues** (`v_mandat`, `v_demande`, `v_charge_gestionnaire`…) et de
  `mandat_etat` pour les états.
- Les indicateurs agrégés (délais, performance) se calculent **côté OLAP**, pas en
  vue OLTP (ADR-036). Voir `merise/olap-v7-articulation.png`.

## 5. Fichiers à joindre selon le fil

- **Tous** : `sql/01_ddl.sql`, `sql/02_triggers_vues.sql`, `merise/mpd-v83.md`,
  `merise/dictionnaire-donnees-v83.md`.
- **Airflow** : `migration/src/`, `jobs/anonymisation/`, ADR-048 (§3), ADR-043, ADR-001.
- **API** : ADR-045 (intégrité), ADR-048 (états dérivés), ADR-039 (gel), le dictionnaire.
- **MinIO** : ADR-042, tables `document`/`document_rattachement`/`note_avis`.
- **OLAP** : ADR-025, ADR-036, `olap-v7-articulation.png`, les vues.

## 6. Ce que j'attends de l'assistant dans ce fil

- Travailler au **plus juste du besoin**, « nécessaire et suffisant », sans
  extrapoler. En cas de décision non spécifiée : **demander validation**, proposer
  des options.
- **Vérifier le code en l'exécutant** (pas de supposition), passes de contrôle,
  tracer les décisions (ADR si structurant).
- Pour les tests : écrire aussi des **tests négatifs / sondes** (tenter l'interdit),
  pas seulement des cas valides.
- Respecter les doctrines du §3.

## 7. Limite connue (transparence)

Le code **cible PG18** (`uuidv7()` natif) mais a été **testé sur PG16** via une
fonction de repli (PG18 non installable dans l'environnement de dev). À valider sur
une instance PG18 réelle.


## 8. Chantier OLAP / Airflow — point de départ (préparé par ce fil)

### 8.1 La projection d'état des mandats attend en OLAP (ADR-051)
L'état « calculé » des mandats (projection de performance, à grande échelle) a été
**volontairement laissé hors de l'OLTP** : il relève de l'OLAP. Côté OLTP, seule
`mandat_reprise` existe (l'état repris non recalculable). À construire côté OLAP :
une **table de faits / vue matérialisée** qui projette l'état et la performance des
mandats, alimentée par un DAG Airflow lisant `v_mandat`.

### 8.2 Sources OLTP pour l'OLAP (lire les VUES, pas les tables brutes)
- `v_mandat` (état calculé : actif/échu/succès/renouvelé/résilié) + `mandat_reprise`
- `v_demande` (cycle de la demande), `v_conformite_chasseur`, `v_charge_gestionnaire`
- `v_honoraires` (assiette), et `remuneration_chasseur` (part gelée + 5 composantes
  du score — déjà prêtes pour l'analyse de performance)

### 8.3 Pistes de modèle en étoile (à arbitrer dans le fil OLAP)
- **Faits candidats :** `fait_vente` (grain = acte : montant, honoraires, rémunération,
  délai), `fait_performance_chasseur` (grain = rémunération : les 5 composantes du
  score figées), `fait_activite_demande` (grain = demande : délais de cycle).
- **Dimensions :** temps, chasseur, gestionnaire, zone, type de bien, client.
- **Indicateurs comparatifs** (délais moyens, taux de réussite, charge) : **OLAP
  uniquement** — la vue OLTP `v_delai_affectation` a été retirée exprès (ADR-036).

### 8.4 Jobs Airflow naturels (DAG)
- Anonymisation RGPD quotidienne (existe : `jobs/anonymisation/`).
- **Alimentation OLAP** (nouveau) : extraire les vues OLTP -> transformer -> charger
  l'étoile ; rafraîchir la projection de performance des mandats (volet « calcule »
  de l'ADR-051, rafraîchissement incrémental sur la frange volatile).
- Migration récurrente des rachats (`migration/`, paramétrable par `sources.yml`).

### 8.5 Doctrine à respecter côté OLAP
- L'OLAP **dérive** de l'OLTP, jamais l'inverse. Reconstruire l'OLAP ne doit rien
  faire perdre à l'OLTP (c'est pourquoi `mandat_reprise` est resté en OLTP).
- Object storage média (MinIO) : les documents restent hors base ; l'OLAP n'en a
  pas besoin (il travaille sur des métadonnées/faits).

## 9. Points ouverts renvoyés (v8.41) — à traiter dans les fils concernés

| Point | Fil | Détail |
|---|---|---|
| **RLS / ENF-03** (accès restreint rémunération + IBAN + commentaires privés) | **API REST** | Reliquat hérité v7 (ADR-027). Ne touche ni MCD ni tables : couche d'accès. Dépend du mode d'authentification backend (`app.user_id` via `current_setting`), non arbitré. À implémenter : `ENABLE ROW LEVEL SECURITY` + politiques. |
| **Upsert / convergence** des corrections source | Migration récurrente (croissance) | Stratégie d'écriture du pipeline ; ne change pas le modèle ni l'aval (vérifié). Un ADR de stratégie sera à écrire. |
| **Projection de performance** (cache d'état des mandats) | OLAP / Airflow | ADR-051. |
| **Test « client transactionnel » + contrôle croisé budget (A03b)** | Collègue → v8.42 | Déjà écrits sur l'ancien modèle ; à reporter après adaptation. |
| **Réconciliation d'identité à la migration** : un compte déjà présent dans l'OLTP (créé par l'application, UUIDv7) avec le même e-mail qu'une personne du portefeuille repris (UUIDv5 déterministe) | Migration récurrente (croissance) | Constaté en pratique : le pipeline échoue proprement (transaction unique, rien d'écrit) sur `utilisateur_email_key`. Il faudra décider quoi faire : réutiliser l'identifiant existant (fusion), journaliser une anomalie et ignorer, ou refuser. Ne change pas le modèle ; à traiter dans l'ADR « stratégie d'upsert ». |
| **Fusion anonymisation** (nos gardes + sa détection à 6 sources) | v8.42 | Fusion réelle, à adapter au schéma v8.41. |
| **Habilitation** (ajouts du collègue sur ancien modèle `numero_carte_t`) | v8.42 | À reporter sur le modèle ADR-046. |
| **Suites de tests collègue** (25 rejets / 5 scénarios) | v8.42 | À additionner après adaptation au modèle v8.41. |

## 10. Sécurité de l'environnement Docker (revue v8.41)

> Lancer l'environnement (Docker + venv), vérifications et dépannage : `LANCEMENT-DOCKER.md` (même dossier).

**État vérifié** (analyse du `docker-compose.yml`, YAML parsé et contrôlé) :
ports publiés sur `127.0.0.1` uniquement · mot de passe `POSTGRES_PASSWORD` **obligatoire**
(plus de valeur par défaut) · images épinglées (`postgres:16.15`, pas `latest`) · aucun mode
`privileged`/`network_mode`/`cap_add`/socket Docker · scripts d'init montés en lecture seule ·
`.env` ignoré par Git.

**Non appliqué volontairement** (impossible à tester sans Docker, risque de casser le
démarrage de l'image PostgreSQL) : `no-new-privileges`, `cap_drop`, `read_only`, limites de
ressources, TLS, réseaux Docker dédiés. À envisager si l'environnement dépasse le poste local.

**À retenir pour le fil API REST / RLS (important) :** le compte `chasse_migration`
(créé via `POSTGRES_USER`) est **superutilisateur** du cluster. Or un superutilisateur
**contourne la RLS** (et le propriétaire d'une table aussi, sauf `FORCE ROW LEVEL SECURITY`).
Si l'application se connecte avec ce compte, **aucune politique RLS ne s'appliquera**.
→ Prévoir un **rôle applicatif distinct, sans droit superutilisateur, non propriétaire des
tables**, avant d'écrire les politiques ; réserver `chasse_migration` à la migration et aux
tests. Principe de moindre privilège à traiter dans le fil API.

<!-- Fin de la passation. Décris ton objectif en haut et joins les fichiers. -->
