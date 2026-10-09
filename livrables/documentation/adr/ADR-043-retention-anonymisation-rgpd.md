# ADR-043 — Politique de rétention & anonymisation RGPD

> **Statut :** Accepté · **Date :** 2026-10-05 · **Déclencheur :** revue senior (point C) · **Lié à :** C12 (`ck_utilisateur_anonymise`), orchestration (Airflow).

## 1. Contexte

Le schéma porte depuis la v7 une colonne `utilisateur.date_anonymisation` et la
contrainte `ck_utilisateur_anonymise` (`date_anonymisation IS NULL OR actif = false`).
La structure d'anonymisation existe donc — mais **aucun processus ne la remplit**.
Une colonne RGPD sans traitement qui l'alimente est une intention, pas une
conformité. La revue a justement soulevé : « qui remplit cette colonne ? ».

Le principe de limitation de conservation (RGPD art. 5-1-e) impose de ne garder
les données que le temps nécessaire. La CNIL sanctionne le non-respect (ex. une
amende de 280 000 € en 2023 pour conservation de comptes inactifs > 3 ans sans
durée définie). Ce n'est donc pas un sujet théorique.

## 2. Décision

Mettre en place une **politique de rétention automatisée**, exécutée par un
**job planifié** (DAG Airflow quotidien, ou cron en attendant l'orchestration),
qui **anonymise** — et non supprime — les données arrivées à échéance.

### 2.1 Anonymiser, pas supprimer (cohérent avec le design existant)

Le modèle ne fait aucun `DELETE` physique : il porte le cycle de vie par des
statuts (`demande.statut`, `mandat.statut`…) et des dates (`date_sortie_reseau`,
`date_fin`, `actif`). L'anonymisation suit la même logique : un `UPDATE` qui
remplace les données identifiantes (nom, prénom, email, téléphone) par des
valeurs neutres, en **conservant la ligne** (et donc l'historique pour les
statistiques et le matching IA), et en posant `actif = false` +
`date_anonymisation = now()` (ce que la contrainte C12 autorise déjà).

> Un `is_deleted`/`deleted_at` générique n'est **pas** retenu : il ferait doublon
> avec les statuts et dates de fin existants, et créerait deux mécanismes
> concurrents pour exprimer le même cycle de vie (voir note de réponse à la revue).

### 2.2 Les durées dépendent du type de personne (règle non uniforme)

La durée « 3 ans » ne s'applique pas aveuglément. Il faut distinguer :

| Catégorie | Durée de conservation (base active) | Point de départ | Action à échéance |
|---|---|---|---|
| **Prospect non client** (compte sans mandat ni acte) | 3 ans | dernier contact / collecte | anonymisation |
| **Client avec relation commerciale** (demande, sans acte signé) | relation + 3 ans | fin de relation / dernier contact | anonymisation |
| **Client avec transaction** (acte signé) | durée du contrat + **archivage légal** (≈ 5 ans, voire plus pour les pièces liées à l'acte) | fin de relation | **conservation légale**, puis anonymisation partielle |

Conséquence : un client ayant **signé un acte** n'est pas anonymisable comme un
simple prospect — ses données transactionnelles relèvent d'obligations de
conservation plus longues (comptables, juridiques). Le job doit donc **router**
chaque personne selon son historique (présence d'un `mandat`, d'un `acte`) avant
d'anonymiser.

### 2.3 Forme du traitement

- **Fréquence :** quotidienne (idempotent : rejouer ne réanonymise pas une ligne déjà traitée, filtre `date_anonymisation IS NULL`).
- **Périmètre :** `utilisateur` (et par cascade logique les données identifiantes qu'il porte). Les lignes métier (demande, mandat, acte) **restent** — seules les données personnelles directes sont neutralisées.
- **Traçabilité :** journaliser chaque run (nb de personnes anonymisées, catégorie) — même esprit que `staging.migration_run`.
- **Exclusions :** le compte technique `SYS-MIGRATION` et tout compte sous obligation légale active ne sont jamais anonymisés.

## 3. Alternatives écartées

| Option | Rejet |
|---|---|
| Ne rien automatiser (anonymisation manuelle) | Non tenable à l'échelle et non conforme (la CNIL attend un processus défini) ; c'est le manque pointé par la revue. |
| `DELETE` physique à échéance | Perte de l'historique (stats, matching IA) et des pièces à conservation légale ; interdit de fait en transaction immobilière. |
| Durée unique « 3 ans pour tout » | Ignore les obligations de conservation longue des données transactionnelles (acte signé) → risque juridique inverse (suppression trop tôt). |
| Colonne `is_deleted`/`deleted_at` générique | Doublon avec statuts/dates existants ; deux mécanismes concurrents. |

## 4. Conséquences

- **Positives :** conformité RGPD effective (la colonne est enfin alimentée) ; historique et obligations légales préservés ; cohérent avec le design « pas de delete physique » ; s'intègre naturellement dans l'orchestration Airflow prévue.
- **Coûts :** un job à écrire et à opérer ; une règle de routage par catégorie (prospect / client / client transactionnel) à valider avec le métier et, idéalement, un conseil juridique pour figer les durées exactes des pièces liées à l'acte.
- **À faire (backlog) :** (1) implémenter le DAG/cron ; (2) valider les durées par catégorie avec le métier ; (3) définir précisément les champs neutralisés vs conservés ; (4) journaliser les runs.

## 5. Rattachement RNCP40573

| Bloc | Contribution |
|---|---|
| BC01 | Conformité RGPD traitée au niveau conception, pas seulement structurelle |
| BC02 | Processus défini, planifié, tracé ; backlog explicite |
| BC03 | Traitement par `UPDATE` cohérent avec l'intégrité du modèle |
| BC05 | Données historiques préservées pour l'aval analytique/IA, dans le respect légal |
