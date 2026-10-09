# MPD PostgreSQL — v8.41

**Modèle physique de données** — reflet d'implémentation de `sql/01_ddl.sql` +
`sql/02_triggers_vues.sql`. PostgreSQL 18 (compatible 16+).

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
| Résiliation / caducité / sans-suite = date + motif | **CHECK symétrique** `(date IS NULL) = (motif IS NULL)` |
| Habilitation salarié = attestation | `CHECK` (ADR-046) |
| Reproductibilité temporelle | fonction `date_reference()` (GUC, ADR-047) |

---

## 4. Fonctions et déclencheurs

**Fonctions utilitaires :** `uuidv7()` (génération de clé ordonnée, avec repli
PG16), `date_reference()` (date de contrôle paramétrable par GUC).

**Déclencheurs (règles inter-lignes, non exprimables en CHECK) :**
- `tg_demande_a_un_acquereur` — une demande a au moins un acquéreur (différé).
- `tg_demande_acquereur` — un seul acquéreur principal par demande.
- `tg_mandat_succession` — renouvellement ≥ 6 mois après le précédent (ADR-048).
- `tg_compromis_offre_acceptee` — compromis seulement sur offre acceptée.
- `tg_acte_compromis_valide` — acte seulement sur compromis non caduc (ADR-048).
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
| `v_mandat` | état du mandat (actif/échu/succès/renouvelé/résilié) ; **« repris fait foi »** via `mandat_etat` |
| `v_mandat_actif` | mandats au statut calculé `actif` |
| `v_demande` | cycle de la demande (dérivé des faits) |
| `v_compromis` | état du compromis (signé/réalisé/caduc) |
| `v_version_courante` | version au `no_version` max par demande |
| `v_honoraires` | assiette d'honoraires par acte (arrondie) |
| `v_conformite_chasseur` | habilitation/RCP expirée, `est_a_regulariser` |
| `v_charge_gestionnaire` | charge de leads par gestionnaire |

**Projection d'état `mandat_etat`** (ADR-048 §3) : matérialise l'état, `origine`
distinguant le fait repris (non recalculable, fait foi) du cache régénérable.

---

## 7. Sécurité & RGPD

- Mots de passe : empreinte seulement (`password_hash`) ; comptes migrés avec
  sentinelle + reset au 1er login (ADR-043).
- Anonymisation : par `UPDATE`, jamais `DELETE` ; contrainte C12
  (`date_anonymisation IS NULL OR actif = false`) ; job de rétention (ADR-043).
- Octets média : hors base (object storage MinIO/S3), seule l'URI stockée (ADR-042).
- Données sensibles (art. 9 RGPD) : **absentes** du schéma (minimisation).

---

## 8. Exploitation — traitements planifiés

| Job | Rôle | Référence |
|---|---|---|
| Anonymisation RGPD | anonymise les données arrivées à échéance (routage par catégorie) | ADR-043, `jobs/anonymisation/` |
| Rafraîchissement `mandat_etat` (cache) | met à jour les lignes `origine='calcule'` de la frange volatile | ADR-048 §3 (différé) |
| Migration récurrente | reprise des portefeuilles rachetés (pipeline E-T-L-V) | ADR-001, `migration/` |

---

## 9. Validation par exécution (v8.41)

Tout vérifié sur cluster PostgreSQL réel (code testé sur PG16 via le repli
`uuidv7()`, cible PG18) :
- DDL rejouable, 37 tables, 8 vues.
- Harnais de contraintes **probant** : 23 rejets (chacun par sa contrainte) + 5 valides.
- Batterie de **sondes** : 5 fermées, 0 ouverte.
- Migration : 153 lignes, 55 anomalies tracées ; 43 tests ; dérivation des états
  prouvée (le même mandat change d'état selon la date de référence).
