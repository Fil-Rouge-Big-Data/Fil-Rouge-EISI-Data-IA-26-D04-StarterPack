# MPD PostgreSQL — v8.41

**Modèle physique de données** — reflet d'implémentation de `livrables/db/01_ddl.sql` +
`livrables/db/02_triggers_vues.sql`. PostgreSQL 18 (compatible 16+).

> ⚠️ Entreprise et données fictives. Livrable pédagogique (RNCP40573).
> Document autonome ; les décisions sont tracées par ADR.

---

## 1. Choix d'implémentation

| Choix | Détail | ADR |
|---|---|---|
| SGBD | PostgreSQL 18 (fallback 16+) | ADR-044 |
| Clés primaires | **UUIDv7** (`DEFAULT uuidv7()`), ordonnées dans le temps | ADR-044 |
| Schéma | `public`, DDL rejouable et transactionnel (`DROP/CREATE SCHEMA` + `BEGIN/COMMIT`) | ADR-041 |
| Extensions | `citext` (casse), `pg_trgm` (matching), `btree_gist` (exclusions) | ADR-040/045 |
| Encodage | UTF-8 | ADR-041 |
| États | **jamais stockés** : dérivés en vues ; seuls les faits et écarts (flags) sont persistés | ADR-048 |

---

## 2. Domaines applicatifs

| Domaine | Base | Contrainte |
|---|---|---|
| `d_email` | citext | motif email |
| `d_tel` | text | motif téléphone |
| `d_montant` | numeric(12,2) | ≥ 0 |
| `d_taux` | numeric(5,2) | 0–100 |
| `d_dpe` | char(1) | A–G |
| `d_preference` | text | exige / souhaite / exclut / indifferent (ADR-052) |

---

## 3. Traduction physique des contraintes

| Règle métier | Implémentation physique |
|---|---|
| Unicité email, matricule, n° registre | `UNIQUE` |
| Signataire = acquéreur de la demande | **FK composée** `(id_demande, id_signataire)` |
| Proposition sous le bon mandat (même demande) | **FK composée** `(id_mandat, id_demande)` (ADR-045) |
| Chasseur rémunéré = chasseur du mandat | **FK composée** `(id_mandat, id_chasseur)` (ADR-045) |
| Barème sans chevauchement (tranches, vigueur) | **EXCLUDE USING gist** (ADR-045) |
| Un mandat courant par demande | colonne scalaire `demande.id_mandat_courant` (unicité mécanique, ADR-048) |
| Succession 6 mois entre mandats | **trigger** `tg_mandat_succession` (inter-lignes) |
| Chaîne de vente (offre acceptée → compromis → acte) | **triggers** (inter-lignes, ADR-045) |
| Fin anticipée du mandat = date + type | **CHECK symétrique** `(date_resiliation IS NULL) = (type_resiliation IS NULL)` (`ck_mandat_resil`) ; type contrôlé dont `vente_externe` (ADR-049) |
| Caducité (compromis) et sans-suite (demande) = date + motif | **CHECK symétrique** `(date IS NULL) = (motif IS NULL)` |
| Rémunération gelée complète | colonnes de calcul **NOT NULL**, 5 composantes du score bornées 0–100, `taux_final` borné **[20 ; 60]** par CHECK (ADR-049) |
| Une seule facture par rémunération ; vérification tracée | `UNIQUE (id_remuneration)` + CHECK de vérification et de rejet (ADR-049) |
| Note d'avis rattachée à la proposition, une par proposition | `UNIQUE (id_proposition)` + FK (ADR-049) |
| Commentaire : exactement une cible | `CHECK (num_nonnulls(id_demande, id_proposition, id_bien) = 1)` |
| Documents ↔ note d'avis / facture | tables de liaison à **vraies clés étrangères** (plus de rattachement polymorphe) |
| Empreinte de fichier | `CHECK (hash_sha256 ~ '^[0-9a-f]{64}$')` |
| Préférence de critère à 4 états | domaine `d_preference` (ADR-052) |
| Habilitation salarié = attestation | `CHECK` (ADR-046) |
| Reproductibilité temporelle | fonction `date_reference()` (GUC, ADR-047) |

---

## 4. Fonctions et déclencheurs

**Fonctions utilitaires :** `uuidv7()` (génération de clé ordonnée, avec repli
PG16), `date_reference()` (date de contrôle paramétrable par GUC).

**Déclencheurs (règles inter-lignes, non exprimables en CHECK) :**
- `tg_demande_a_un_acquereur` — une demande a au moins un acquéreur (différé).
- `tg_demande_acquereur` — un seul acquéreur principal par demande (différé).
- `tg_affectation_sync` — une affectation ouverte synchronise gestionnaire, chasseur et date d'affectation sur la demande.
- `tg_mandat_succession` — renouvellement ≥ 6 mois après le précédent (ADR-048).
- `tg_compromis_offre_acceptee` — compromis seulement sur une offre acceptée.
- `tg_acte_compromis_realise` — pas d'acte sur un compromis caduc.
- `tg_commentaire_prive` — un client ne peut pas poster de commentaire privé (RG-01).
- `tg_observation_periode` — observation dans une période close.

---

## 5. Stratégie d'indexation

- **Clés UUIDv7** : index B-tree compacts, peu fragmentés (insertions ordonnées).
- **Unicités partielles** : `uk_proposition_active` (reproposer un bien après
  baisse de prix) ; les unicités de progression stockée ont disparu (ADR-048).
- **Exclusions GiST** : `ex_tranche_chevauchement`, `ex_bareme_vigueur`.
- **FK** : index implicites sur les colonnes référencées à forte jointure.

---

## 6. Vues (états dérivés — ADR-048/030)

| Vue | Calcule |
|---|---|
| `v_mandat` | état du mandat (actif/échu/succès/renouvelé/résilié) ; **« repris fait foi »** via `mandat_reprise` |
| `v_mandat_actif` | mandats au statut calculé `actif` |
| `v_demande` | cycle de la demande (dérivé des faits) |
| `v_compromis` | état du compromis (signé/réalisé/caduc) |
| `v_version_courante` | version au `no_version` max par demande |
| `v_honoraires` | assiette d'honoraires par acte (arrondie) |
| `v_conformite_chasseur` | habilitation/RCP expirée, `est_a_regulariser` |
| `v_charge_gestionnaire` | charge de leads par gestionnaire |

**Table `mandat_reprise`** (ADR-051, ex-`mandat_etat`) : état *repris* à la migration, donnée transactionnelle
non recalculable qui fait foi dans `v_mandat`. Le cache d'état calculé n'existe plus en OLTP : il relève de l'OLAP.

---

## 7. Sécurité & RGPD

- Mots de passe : empreinte seulement (`password_hash`) ; comptes migrés avec
  sentinelle + reset au 1er login (ADR-043).
- Anonymisation : par `UPDATE`, jamais `DELETE` ; contrainte C12
  (`date_anonymisation IS NULL OR actif = false`) ; job de rétention (ADR-043).
- Octets média : hors base (object storage MinIO/S3), seule l'URI stockée (ADR-042).
- Données sensibles (art. 9 RGPD) : **absentes** du schéma (minimisation).
- **Accès restreint (RLS)** : non implémenté. Les montants de rémunération, les IBAN et les commentaires privés
  ne sont pas encore protégés en lecture ; renvoyé au fil API REST, car cela dépend du mode d'authentification
  du backend (ADR-027). À noter : un superutilisateur contourne la RLS, il faudra un rôle applicatif dédié.

---

## 8. Exploitation — traitements planifiés

| Job | Rôle | Référence |
|---|---|---|
| Anonymisation RGPD | anonymise les données arrivées à échéance (routage par catégorie) | ADR-043, `livrables/jobs/anonymisation/` |
| Projection de performance des mandats | hors OLTP : relève de l'OLAP (fil Airflow) | ADR-051 |
| Migration récurrente | reprise des portefeuilles rachetés (pipeline E-T-L-V) | ADR-050, `livrables/migration/` |

---

## 9. Validation par exécution (v8.41)

Vérifié sur PostgreSQL 16.15 (code visant PostgreSQL 18 : le `uuidv7()` natif n'a pas été essayé, le repli
l'a été) :
- DDL rejouable : **38 tables, 8 vues, 337 colonnes**.
- Harnais de contraintes : **23 rejets, chacun par la contrainte attendue**, + 4 écritures valides.
- Batterie de **sondes** : 12 fermées, 0 ouverte (hermétiques : mêmes résultats quel que soit l'état de la base).
- Migration : 153 lignes, 73 anomalies tracées ; 48 tests ; dérivation des états prouvée (le même mandat
  change d'état selon la date de référence).
- Anonymisation RGPD : 7 tests.
- Documentation : `python livrables/db/verifier_dictionnaire.py` contrôle le dictionnaire contre le DDL.
