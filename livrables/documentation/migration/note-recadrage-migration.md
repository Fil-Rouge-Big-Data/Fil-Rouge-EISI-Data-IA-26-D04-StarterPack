# Note de re-cadrage — Migration des données

**Projet :** Service de chasse immobilière — refonte du SI
**Titre visé :** Expert en informatique et SI — RNCP40573 (BC01 · BC02 · BC03 · BC05)
**Objet :** acter que le code de migration présent dans le dépôt vise une cible périmée, et fixer la cible de référence pour la reprise
**Date de référence projet :** 25 juillet 2026
**Statut :** proposé — à valider avant construction

> ⚠️ Entreprise, données et personnages fictifs. Note de travail destinée au Dossier Professionnel et à la soutenance.

---

> **Note v8.** Cette note de recadrage (bascule du code hérité vers la cible v7)
> **reste valable** : la cible a simplement évolué de v7 à v8 (voir
> `merise/dossier-modelisation-v8.md`). Le raisonnement — audit de l'écart,
> réutilisation du parsing, réécriture ciblée — s'applique à l'identique.


## 1. Pourquoi cette note

Le dépôt `Fil-Rouge-EISI-Data-IA-26-D04-StarterPack` contient déjà une chaîne de migration (`livrables/migration/`) et un schéma versionné (`livrables/db/migrations/`). Un audit de ces éléments montre qu'ils **ne visent pas le modèle de données cible retenu** (MPD v7, `01_ddl.sql`). Poursuivre la construction sans trancher ce point produirait une migration alimentant une base qui n'existe plus au dossier.

Cette note fait trois choses : elle **constate** l'écart, elle **fixe** la cible de référence, et elle **distingue** ce qui est conservé de ce qui est réécrit. Elle ne produit aucun code : c'est le point de contrôle qui autorise les étapes suivantes (mapping détaillé, puis implémentation).

---

## 2. Constat d'audit

La chaîne de migration du dépôt est **de bonne facture méthodologique** — traçabilité des décisions de reprise, rapport « zéro déperdition », tests unitaires sans base, référentiels externes justifiés. Le problème n'est pas la qualité d'exécution : c'est la **cible**.

Trois versions du modèle cohabitent dans le dépôt, et aucune n'est la v7 :

| Élément du dépôt | Version implicite | Indice |
|---|---|---|
| `livrables/db/migrations/V1__schema_initial.sql` | **v5** | En-tête : « v5 : la clientèle est exclusivement composée de particuliers… CLIENT redevient un sous-type de UTILISATEUR » |
| `livrables/migration/01_schema/ddl_tables.sql` | **v6-ish** | Clés `SERIAL`, table `CARACTERISTIQUE` générique, `PAYS/VILLE/SECTEUR` |
| Code Python `03_transformation/` | aligné sur le v6-ish | Produit `PERSONNE`, `BAREME`, `RENOUVELLEMENT_MANDAT`, `CARACTERISTIQUE` |

Or la cible de référence du dossier de modélisation est la **v7** (`01_ddl.sql`, `02_triggers_vues.sql`), qui acte plusieurs décisions structurantes **postérieures** au code du dépôt.

### 2.1 Écarts structurants (bloquants)

| Dimension | Dépôt (code actuel) | Cible v7 (`01_ddl.sql`) | ADR |
|---|---|---|---|
| Clés primaires | `SERIAL` (entiers) | `uuid DEFAULT gen_random_uuid()` | ADR-028 |
| Nommage / schéma | `PERSONNE`, `MANDAT`… dans `fil_rouge_cible` | minuscules dans `public` | — |
| Acteur central | `PERSONNE` + `CLIENT`/`CHASSEUR` | `utilisateur` + `client`/`chasseur`/**`gestionnaire`** | ADR-026 |
| Mandat — durée | `date_fin` **stockée** (calculée en Python) | `date_debut` seule ; `date_fin` **en vue `v_mandat`** | ADR-030 |
| Renouvellement | table `RENOUVELLEMENT_MANDAT` | `id_mandat_precedent` (filiation) | ADR-030 |
| Critères de recherche | table `CARACTERISTIQUE` générique + jonction | **booléens** `exige_balcon`, `exige_terrasse`… sur `demande_version` | ADR-031 |
| Référentiel géo | `PAYS`/`VILLE`/`SECTEUR` (3 tables) | `zone` unifiée (`type_zone` ∈ ville/secteur) | ADR-022 |
| Rémunération | `BAREME`/`TRANCHE_BAREME`/`REMUNERATION` | `remuneration_chasseur` (gel de la part, ADR-029) | ADR-029 |
| Code pays | `FRA` (3 lettres) | `FR` (2 lettres, `code_iso_pays char(2)`) | contrainte C |
| Versions de demande | `no_version` + `criteres_bruts` | idem, mais vers colonnes v7 (booléens, `destination`) | — |

L'ADR-031 est l'exemple le plus net : le dépôt construit précisément la table `CARACTERISTIQUE` que la v7 a **explicitement écartée** au profit de booléens fermés. Le code n'est donc pas « en retard » — il implémente une décision **inverse** de la décision retenue.

### 2.2 Écarts d'outillage (à réaligner)

| Sujet | Dépôt | Décidé pour la reprise | Justification |
|---|---|---|---|
| Versionnement schéma | Flyway (`V1__…`), figé en **v5** | **Alembic** | Cohérence stack Python ; migrations de données en Python ; pas de JVM (voir journal de décisions, décision migration-02) |
| Chargement (load) | `pandas.to_sql` direct | **Staging + mapping UUID + `INSERT…SELECT`** | Idempotence, traçabilité ligne à ligne, Phase 3-ready (voir journal, décision migration-03) |
| Transformation | Python/pandas (regex critères) | **Conservée** pour le parsing, re-ciblée v7 | Le parsing de texte libre est intrinsèquement Python ; seul le *mapping de sortie* change |

---

## 3. Cible de référence retenue

> **Décision.** La cible unique et de référence de la migration est le **MPD v7** matérialisé par `01_ddl.sql` (structure), `02_triggers_vues.sql` (déclencheurs et vues) et le seed `03_seed.sql`. Toute production de migration vise cette cible. Les DDL v5/v6 du dépôt sont considérés comme **historiques** et ne sont plus alimentés.

Cette décision est cohérente avec le dossier de modélisation v7, qui documente les ADR-025 à 031 comme les décisions les plus récentes du projet et fournit la structure exécutée et testée (`01_ddl.sql`, `02_triggers_vues.sql`). Le code de migration du dépôt, lui, est antérieur à ces ADR : il précède la bascule vers les booléens (ADR-031), les clés UUID (ADR-028) et la refonte du mandat (ADR-030).

---

## 4. Ce qui est conservé, ce qui est réécrit

La reprise n'est **pas** une remise à zéro. Le travail intellectuel du dépôt est en grande partie réutilisable ; c'est la cible d'arrivée qui change.

### 4.1 Conservé (matière réutilisable)

| Élément du dépôt | Réutilisation | Adaptation nécessaire |
|---|---|---|
| `extraire_criteres()` — parsing du texte libre | **Cœur réutilisé** : décomposition de `description_recherche` | Sortie re-mappée vers **booléens** v7 au lieu de `CARACTERISTIQUE` |
| Logique de rapport / traçabilité (`objet/anomalie/decision`) | Conservée telle quelle | Ré-ancrer les codes anomalies sur la cible v7 |
| Référentiels externes (`CODES_INSEE`, correction A06) | Conservés | `code_insee` va dans `zone` ; `FRA`→`FR` |
| Correction A06 (chasseur id 3 en position de client → client 19) | Décision d'audit conservée | Inchangée sur le fond |
| Style de tests unitaires sans base (`test_transformation.py`) | Conservé et complété | Ajout des tests **en base** (volumétrie, intégrité, idempotence) |
| Structure E→T→L→V + `main.py` + rapport CSV | Squelette conservé | Load re-basculé vers staging + `INSERT…SELECT` |

### 4.2 Réécrit (aligné v7)

- **DDL cible** : abandon des DDL v5/v6 du dépôt ; la structure vient de `01_ddl.sql` v7, versionnée sous **Alembic**.
- **Mapping de sortie de la transformation** : UUID (mapping déterministe depuis clés naturelles), booléens de critères, `zone` unifiée, ajout `gestionnaire`, mandat sans `date_fin`, filiation de renouvellement.
- **Chargement** : staging (`migration_staging`) + table de correspondance `id_source ↔ uuid` + `INSERT…SELECT` transactionnel idempotent, en remplacement du `to_sql` direct.

---

## 5. Cas de comblement rendus nécessaires par la v7

La v7 introduit des tables et colonnes **sans équivalent source**, qui n'existaient pas dans la cible v6 du dépôt. Ces cas devront être tranchés dans le mapping détaillé (étape suivante). Aperçu des plus sensibles :

| Cible v7 | Absence en source | Piste de comblement (à trancher au mapping) |
|---|---|---|
| `gestionnaire` (rôle nouveau) | Aucun gestionnaire dans l'existant | Table vide à la migration, ou gestionnaire « pivot » synthétique pour porter les demandes reconstruites |
| `utilisateur.password_hash` (NOT NULL) | Aucun mot de passe | Sentinelle + reset obligatoire au 1ᵉʳ login (RGPD) |
| `chasseur.numero_carte_t` et garanties légales (NOT NULL) | Absents | Sentinelle + flag « à régulariser », ou exclusion — décision métier |
| `zone.code_iso_pays='FR'`, `devise='EUR'` | Implicites | Valeurs par défaut ; `code_insee` depuis le référentiel externe conservé |
| `demande` / `demande_version` | N'existent pas | Reconstruites : un mandat source ⇒ une demande + une version courante |
| `mandat.statut='actif'` mensonger | Statut faux | Recalcul de l'expiration via `v_mandat` (ADR-030), jamais recopié |
| Critères booléens `exige_*` | Texte libre | Issus du parsing conservé, mappés vers les 6 booléens + `travaux_acceptes` |

Ce tableau n'est qu'un **repérage** ; le livrable qui tranche chaque colonne est `docs/migration/mapping-donnees.md` (étape 1).

---

## 6. Suite immédiate (rien n'est construit avant validation)

1. **Cette note** — re-cadrage (à valider).
2. **`docs/migration/mapping-donnees.md`** — mapping exhaustif source → v7, décisions de comblement colonne par colonne.
3. **`migration/README.md`** — plan opératoire (pipeline E-T-L-V, prérequis, tests, rapport).
4. **Implémentation** — code re-ciblé v7, staging + mapping UUID, Alembic, tests en base. **Seulement après** validation des points 2 et 3.

---

## 7. Rattachement RNCP40573

| Bloc | Contribution de cette note |
|---|---|
| **BC01** | Cartographie de l'écart entre l'existant du dépôt et la cible ; décision d'architecture tracée |
| **BC02** | Pilotage : point de contrôle avant construction, évite le retravail ; distinction conservé/réécrit |
| **BC03** | Cadrage technique de la reprise (outillage, moteur, versionnement) |
| **BC05** | Alignement de la chaîne data sur le socle OLTP v7 réellement cible |

> **À défendre en soutenance.** Assumer la bascule comme une **décision de pilotage**, pas comme une correction subie : un code de migration antérieur visait une cible qui a évolué (ADR-025 à 031) ; la relecture a détecté l'écart avant la construction, ce qui est précisément le rôle d'un point de contrôle. Le travail d'audit (parsing, traçabilité, corrections) est préservé ; seule la cible d'arrivée est réalignée.
