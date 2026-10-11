# MPD PostgreSQL — v7 (extrait autonome)

**Plateforme de chasse immobilière** · Extrait du dossier de modélisation v7 (section 6), à jour des ADR-025 à 031.
Structure exécutée et validée sur PostgreSQL 16.15 (20 rejets + 5 scénarios valides).
Brique de travail : point de départ de la BDD OLTP, de la migration et de la chaîne OLAP.
Scripts exécutables associés : sql/01_ddl.sql, sql/02_triggers_vues.sql, sql/03_seed.sql, sql/run_tests.py.

# 6. MPD — Modèle physique de données (PostgreSQL 16.15)

Implémentation du MLD sur PostgreSQL. **La structure v7 complète (28 tables) a été exécutée et validée sur PostgreSQL 16.15**, avec clés UUID (ADR-028), mandat refondu (ADR-030) et table `remuneration_chasseur` (ADR-029) : batterie de **20 tentatives d'écriture invalides toutes rejetées** et **5 scénarios valides tous acceptés** — §6.9. Le DDL exécuté est reproductible (`sql/01_ddl.sql`, `sql/02_triggers_vues.sql`).

> **Environnement validé** — PostgreSQL 16.15 · extensions `pgcrypto` 1.3, `citext` 1.6, `pg_trgm` 1.6 · scripts de test Python 3.12.3. Ces versions alimentent le fichier d'environnement du dépôt.

## 6.1 Choix d'implémentation

| Sujet | Retenu | Écarté | Raison |
|---|---|---|---|
| Clés primaires | `uuid DEFAULT gen_random_uuid()` | `bigint IDENTITY`, hybride bigint+uuid | **ADR-028** : la fusion de bases lors des rachats (Phase 3) impose des clés sans collision par construction. Le bigint impose une réattribution de toutes les clés à chaque acquisition ; l'hybride double les clés à maintenir sans bénéfice à cette échelle. UUID nécessaire et suffisant |
| Génération UUID | `gen_random_uuid()` (pgcrypto, UUIDv4) | `uuidv7()` | `uuidv7()` (ordonné dans le temps, index moins fragmentés) n'existe nativement qu'en **PostgreSQL 18**. En 16.15 on retient l'UUIDv4 aléatoire ; migration vers v7 possible sans changer le type le jour du passage en PG 18+ |
| Chaînes | `text` + contrainte de longueur | `varchar(n)` | Aucune différence de performance ; élargir une longueur devient un changement de contrainte, pas de type |
| Email | domaine `d_email` sur `citext` | `text` + `lower()` applicatif | La casse ne doit pas créer deux comptes : `citext` porte l'insensibilité dans le type, donc dans l'index unique |
| Énumérations | `CHECK (col IN (...))` | type `ENUM` | Un `ENUM` impose `ALTER TYPE` verrouillant ; un `CHECK` se remplace dans une transaction (ADR-017) |
| Horodatage | `timestamptz` | `timestamp` | Un consentement a une valeur juridique : perdre le fuseau est une perte d'information |
| Dates contractuelles | `date` | `timestamptz` | Une signature est datée du jour, pas de la seconde |
| Montants | `numeric(12,2)` via domaine | `float` / `money` | `float` inexact sur des sommes ; `money` dépend de la locale serveur |
| Unicités conditionnelles | index uniques partiels | déclencheurs | Le `WHERE` exprime nativement « au plus un actif », sans code |
| Durée et fin du mandat | **rien de stocké** : `date_debut` seule, `date_fin` et expiration en vue | colonnes `duree_mois` + `date_fin` | **ADR-030** : la durée est une constante métier (6 mois), le renouvellement crée un nouveau mandat. « Si calculé, pas stocké » — la règle même issue de l'audit de l'anomalie A01. Ni `duree_mois` ni `date_fin` ne subsistent comme colonnes |
| Expiration des mandats | vue `v_mandat` | `CHECK (... >= CURRENT_DATE)` ou colonne générée | Un `CHECK` n'est réévalué qu'à l'écriture ; une colonne `GENERATED` exige une expression immuable, or `current_date` ne l'est pas. L'expiration est donc **entièrement dérivée** en vue |
| Recherche textuelle | index GIN `pg_trgm` sur les titres | `LIKE '%...%'` seul | Rapprochement d'annonces approchantes sans moteur externe |

**Refonte du mandat (ADR-030).** La table `mandat` ne porte que `date_debut` (durée fixe de 6 mois). `date_fin`, `est_expire` et `statut_incoherent` sont **tous** calculés en vue — testé et vérifié à l'exécution (un mandat `actif` débuté le 2025-06-05 ressort `date_fin = 2025-12-05`, `est_expire = true`, `statut_incoherent = true`) :

```sql
CREATE VIEW v_mandat AS
SELECT m.*,
       (m.date_debut + INTERVAL '6 months')::date            AS date_fin,
       ((m.date_debut + INTERVAL '6 months')::date < current_date) AS est_expire,
       (m.statut = 'actif'
        AND (m.date_debut + INTERVAL '6 months')::date < current_date) AS statut_incoherent
FROM mandat m;
```

`statut_incoherent` recrée le contrôle de l'anomalie A01 du SI hérité sans jamais stocker la valeur — mais l'incohérence devient désormais **structurellement impossible** à créer, puisque ni la durée ni la fin ne sont saisissables. Le renouvellement crée un nouveau mandat, relié au précédent par `id_mandat_precedent` (filiation).

## 6.2 Domaines

| Domaine | Base | Règle |
|---|---|---|
| `d_email` | `citext` | Format d'adresse, insensible à la casse |
| `d_dpe` | `char(1)` | Lettre A à G |
| `d_taux` | `numeric(5,2)` | Entre 0 et 100 |
| `d_montant` | `numeric(12,2)` | Positif ou nul |
| `d_tel` | `text` | Chiffres, espaces, points, tirets, préfixe international optionnel |

## 6.3 Traduction physique des contraintes

| # | Contrainte | Mécanisme PostgreSQL | Objet |
|---|---|---|---|
| C1 | Rôles cumulables | Aucun : trois tables filles indépendantes, sans discriminant | — |
| C2 | Commentaire à cible unique | `CHECK (num_nonnulls(id_demande, id_proposition) = 1)` | `ck_commentaire_cible` |
| C3 | Identifications relatives | Clé composée ou UNIQUE alternatif | `uk_affectation`, `uk_version_no` |
| C4 (au plus un) | Acquéreur principal | `CREATE UNIQUE INDEX ... WHERE qualite = 'principal'` | `ux_acquereur_principal` |
| C4 (au moins un) | Acquéreur obligatoire | Déclencheur de contrainte différé | `tg_demande_acquereur` |
| C5 | Signataire acquéreur | FK composée (id_demande, id_signataire) → demande_acquereur | `fk_mandat_signataire` |
| C6 | Une affectation ouverte | `CREATE UNIQUE INDEX ... WHERE date_fin IS NULL` | `ux_affectation_ouverte` |
| C7 | Un mandat actif | `CREATE UNIQUE INDEX ... WHERE statut = 'actif'` | `ux_mandat_actif` |
| C8 | Bien proposé une fois | UNIQUE (id_demande, id_bien) + FK composée | `uk_proposition`, `fk_proposition_version` |
| C9 | Période close | Déclencheur BEFORE sur observation | `tg_observation_periode` |
| C10–C12, C14–C17 | Cohérences intra-ligne | Contraintes `CHECK` déclaratives | `ck_zone_secteur`, `ck_utilisateur_anonymise`, `ck_offre_reponse`, `ck_compromis_caducite`, `ck_acte_honoraires`, `ck_visite_annulation` (l'unicité géographique C11 est portée par `uk_zone_geo`, ci-dessous) |
| C11 | Unicité géographique | `UNIQUE NULLS NOT DISTINCT (pays, ville, secteur)` | `uk_zone_geo` |
| C13 | Une offre acceptée | `CREATE UNIQUE INDEX ... WHERE statut = 'acceptee'` | `ux_offre_acceptee` |
| C18 | Client jamais privé (RG-01, v7) | Déclencheur BEFORE sur commentaire : rejet si `est_prive` et auteur ∈ client sans rôle chasseur/gestionnaire | `tg_commentaire_prive` *(nouveau v7)* |

### Deux points d'exécution à connaître (validés en v5)

**Transaction obligatoire pour C4.** La contrainte « au moins un acquéreur » étant vérifiée en fin de transaction, la création d'une demande et de son acquéreur doit tenir dans une même transaction (`BEGIN ... COMMIT`) — hors transaction explicite, la première instruction s'auto-valide et déclenche le rejet. À documenter pour les développeurs et toute reprise de données.

**Ordre BEFORE pour `est_courante`.** PostgreSQL vérifie l'index unique partiel à l'insertion, donc avant tout déclencheur AFTER : la bascule de l'ancienne version courante arriverait trop tard. Le déclencheur est en BEFORE — seule sortie, un index unique partiel ne pouvant être différé.

## 6.4 Fonctions et déclencheurs

| Déclencheur | Table | Moment | Rôle |
|---|---|---|---|
| `tg_demande_acquereur` | demande | AFTER, différé | Refuse une demande sans acquéreur principal (C4) |
| `tg_observation_periode` | observation | BEFORE | Refuse de figer un indicateur sur une période non close (C9) |
| `tg_version_courante` | demande_version | BEFORE | Bascule l'ancienne version courante à faux |
| `tg_affectation_sync` | affectation | AFTER | Met à jour `demande.id_gestionnaire`/`id_chasseur`, renseigne `date_affectation` au premier passage, fait évoluer le statut |
| `tg_commentaire_prive` *(v7)* | commentaire | BEFORE | Rejette `est_prive = vrai` si l'auteur est client sans être chasseur ni gestionnaire (C18/RG-01) |

## 6.5 Stratégie d'indexation

86 index (v6), dont les implicites des PK/UNIQUE. Principes :

- **FK toutes couvertes** : PostgreSQL n'indexe pas les colonnes référençantes ; sans index, toute suppression dans la table référencée parcourt la table fille. Partiels quand la colonne est majoritairement nulle.
- **Index partiels** sur les lignes utiles : mandats actifs, annonces actives, affectations ouvertes, versions courantes, acquéreurs principaux, offres acceptées. Sur `annonce`, l'index partiel sur les actives divise sa taille par un facteur croissant avec l'âge de la base.
- **Index de matching** `ix_bien_matching (id_zone, type_bien, surface, nb_pieces)` : ordre de sélectivité réel (la zone élimine le plus). Pas de booléens (peu sélectifs).
- **Trigramme** `ix_annonce_titre_trgm` (GIN) pour le rapprochement d'annonces au dédoublonnage.

> À recalibrer sur plans d'exécution mesurés (`pg_stat_statements`) dès les premiers volumes réels.

## 6.6 Vues

| Vue | Rôle |
|---|---|
| `v_mandat` *(v6)* | Expose `est_expire` et `statut_incoherent` sans les stocker |
| `v_mandat_actif` | **Seul point de lecture** des mandats en cours : filtre statut **et** échéance — aucune lecture ne remonte de mandat périmé même si la bascule a échoué |
| `v_honoraires` *(v6)* | Expose `honoraires_total = fixe + taux × montant_vente` |
| `v_version_courante` | Version de critères servant au matching |
| `v_charge_gestionnaire` | Leads en cours, capacité, taux de charge |
| `v_conformite_chasseur` | Cartes T et RCP expirées, et **mandats signés hors validité de carte** — le risque juridique le plus direct |
| `v_delai_affectation` | Délai dépôt → affectation, par gestionnaire et canal |

Les trois dernières sont les **sources de calcul** des indicateurs figés dans `observation`.

**Table `remuneration_chasseur` (ADR-029).** La part du chasseur sur une vente est un **fait daté figé** au moment de l'acte (même doctrine que `observation` pour les KPI) : elle relie `id_acte` (fait générateur) à `id_chasseur`, porte `montant_part` et `date_calcul`, et trace la règle appliquée dans `reference_bareme` (texte). La **règle exacte de calcul** (tranches, effet ancienneté/performance) reste à obtenir du PO : tant qu'elle n'est pas connue, elle n'est pas modélisée en dur — on gèle le résultat, on ne présume pas de la formule (point ouvert n°1). Testé : P6 (gel d'une part) accepté.

## 6.7 Sécurité

**Rôles applicatifs**

| Rôle | Droits |
|---|---|
| `chasse_migration` | Propriétaire du schéma, seul habilité au DDL |
| `chasse_app` | SELECT, INSERT, UPDATE sur les tables métier. Aucun DELETE hors purge |
| `chasse_scraper` | INSERT, UPDATE sur `bien` et `annonce` uniquement |
| `chasse_kpi` | SELECT sur les vues, INSERT sur `observation` |
| `chasse_lecture` | SELECT sur les vues (informatique décisionnelle, extraction OLAP §7) |

Le compte applicatif ne doit **pas** être propriétaire des tables (un propriétaire ignore la RLS).

**Notes privées (C18/RG-01).** Deux niveaux complémentaires : le déclencheur `tg_commentaire_prive` bloque l'**écriture** interdite (testé — T20 rejeté, P4/P5 acceptés) ; la **RLS** protège la **lecture** (« un commentaire privé n'est visible que du chasseur du mandat, du gestionnaire affecté et de l'auteur »), y compris exports et consoles d'administration. L'identité applicative est portée par `SET app.user_id` en début de transaction (le backend injecte l'utilisateur courant), lu par les politiques via `current_setting('app.user_id')` — mécanisme retenu (plutôt qu'un rôle PostgreSQL par utilisateur, ingérable à l'échelle, ou un contrôle purement applicatif, contournable par accès direct). Le client étant un `utilisateur` au même titre que le chasseur, la politique s'appuie sur `demande_acquereur` et `affectation`, pas sur la seule appartenance à une table de rôle.

**Données personnelles**

| Donnée | Traitement |
|---|---|
| `password_hash` | bcrypt/argon2, jamais réversible |
| `annee_naissance` | Année seule (minimisation, actée au MCD) |
| LCB-FT (`niveau_vigilance`, `origine_fonds_declaree`) | Conservation encadrée : 5 ans après fin de relation d'affaires |
| `demande.date_consentement` | Conservée aussi longtemps que la donnée qu'elle légitime |
| Purge demandes sans suite | Cascade versions/propositions/commentaires. **Jamais** vers un mandat |
| Comptes inactifs | **Anonymisation en place** (`date_anonymisation`, C12), pas suppression : un signataire de mandat ne peut disparaître du registre |

## 6.8 Exploitation — traitements planifiés

| Traitement | Fréquence | Rôle |
|---|---|---|
| Clôture des mandats échus (`actif`→`clos_succes`/autre) | Quotidien | L'**expiration** est déjà dérivée par `v_mandat` (ADR-030) ; ce traitement ne fait plus que faire évoluer le *statut de gestion*, sans jamais pouvoir contredire l'échéance |
| Passage des annonces à `retiree` | Quotidien | Sept jours sans observation par le scraper |
| Contrôle de cohérence `demande.statut` | Nocturne | Détecte la divergence de la dénormalisation non contrainte |
| **Calcul et gel des indicateurs** | Mensuel, période close | Alimente `observation` — source du fait OLAP dérivé (§7) |
| Purge / anonymisation RGPD | Mensuel | **Suppression** des demandes sans suite et données sans valeur légale (> 24 mois) ; **anonymisation** des données à valeur légale — un signataire de mandat n'est jamais supprimé (décision arbitrage n°4) |
| `VACUUM ANALYZE` ciblé | Hebdomadaire | `annonce` et `proposition` (plus fortes mises à jour) |

**Volumétrie.** `annonce` et `proposition` sont les tables à surveiller ; au-delà de quelques dizaines de millions de lignes, partitionnement par intervalle sur `date_ingestion` / `date_matching` — les colonnes existent déjà, l'évolution est possible sans changement de modèle.

**Versions de schéma.** Toute évolution passe par un outil de migration versionnée (Flyway/Liquibase/Alembic — au choix de la stack, point ouvert). **Aucune modification manuelle en base**, y compris en préproduction.

## 6.9 Validation par exécution (v7)

La structure v7 a été validée par **exécution réelle** sur PostgreSQL 16.15 (ADR-013), sur la structure définitive : clés UUID, mandat refondu, `remuneration_chasseur`, chaîne de valeur complète. La démarche a de nouveau prouvé sa valeur : un défaut de **jeu de test** (compromis inséré depuis une table `notaire` vide, donnant un faux négatif) n'a été visible qu'à l'exécution et a été corrigé — illustration concrète que « spécifié » n'est pas « validé ».

**20 rejets vérifiés / 20.** Les 15 de la batterie historique — commentaire à double cible (T1), second mandat actif (T2), bien proposé deux fois (T3), signataire non acquéreur (T4), seconde affectation ouverte (T5), mandat sans rémunération (T6), effet antérieur à signature (T7), procuration sans référence (T8), observation sur période ouverte (T9), annonce d'un autre bien (T10), DPE hors A–G (T11), email malformé (T12), refus sans motif (T13), lead web sans consentement (T14), rendement sur résidence principale (T15) — **plus les 5 nouveaux** : offre acceptée en double (T16, C13), compromis caduc sans motif (T17, C15), acte sans honoraires (T18, C16), visite annulée sans motif (T19, C17), **commentaire privé posé par un client** (T20, C18/RG-01).

**5 scénarios valides / 5** : un bien / deux annonces / une proposition (P3), chasseur posant un commentaire privé (P4), **cumul chasseur+client** posant un commentaire privé — le rôle *effectif* prime (P5), **gel d'une rémunération chasseur** (P6, ADR-029), **renouvellement créant un nouveau mandat avec filiation** (P7, ADR-030).

> La batterie est reproductible (`sql/run_tests.py`). Reste à étendre au fil de l'implémentation : tests de la RLS `app.user_id` (lecture des commentaires privés), une fois le backend et son mode d'authentification en place (point ouvert n°3).
