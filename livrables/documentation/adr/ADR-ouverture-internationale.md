# ADR — Ouverture internationale : validation des champs conditionnée au pays

> **Numéro :** à figer avec le lot d'ADR (proposé : ADR-033) · **Statut :** Accepté (design acté, implémentation Phase 3)
> **Date :** 2026-10-02
> **Portée :** réponses aux arbitrages D1 (carte T), D2 (code postal), D3 (délai de rétractation) et D4 (scraping, ouverture Phase 4).
> **Principe directeur :** *on ne retire jamais une protection ; on la rend conditionnelle au pays.*

## 1. Contexte

La v7 est volontairement **franco-centrée** : certaines contraintes encodent le droit français (carte T obligatoire pour le chasseur, délai de rétractation SRU de 10 jours, code postal à 5 chiffres). La Phase 3 de la feuille de route prévoit une **expansion internationale** (Espagne, Allemagne, Royaume-Uni, BeNeLux, Italie, Suisse).

La review R1 proposait de **lever** ces contraintes (`DROP NOT NULL`, regex relâchée). C'est **écarté** : cela affaiblirait l'intégrité du socle français **actuel** — un chasseur FR sans carte T (illégal) deviendrait insérable, des codes postaux FR invalides seraient acceptés. L'enjeu n'est pas de *supprimer* une règle, mais de la rendre **dépendante du pays** : obligatoire là où le droit l'exige, inapplicable (et donc nullable) ailleurs.

## 2. Décision

Adopter un modèle **piloté par la donnée** : un référentiel `config_pays` déclare, pour chaque pays, quelles règles s'appliquent ; un **trigger** `tg_valide_champs_pays` applique ces règles à l'écriture. Ajouter un pays devient une **insertion de ligne de configuration**, sans modification de schéma.

**L'implémentation est reportée en Phase 3** (on reste mono-pays FR aujourd'hui, et les contraintes `NOT NULL`/regex actuelles *sont* exactement la configuration FR). Le présent ADR **fige l'architecture** pour que la bascule soit mécanique le jour venu, et pour documenter l'ouverture en restitution.

## 3. Design cible

### 3.1 Référentiel `config_pays`

Une ligne par pays, porteuse des flags et paramètres de conformité :

| Colonne | Rôle | Valeur FR |
|---|---|---|
| `code_iso_pays` (PK) | pays ISO-3166 | `FR` |
| `carte_t_requise` | le chasseur doit-il une carte T (ou équiv.) ? | `true` |
| `delai_retractation_jours` | délai légal de rétractation (NULL = aucun) | `10` |
| `regex_code_postal` | format attendu du code postal | `^[0-9]{5}$` |
| `devise` | devise **par défaut** du pays (ne remplace ni `zone.devise` existant ni l'additif C2 ; sert de valeur par défaut) | `EUR` |

*(Versionnable par dates de vigueur si le droit évolue ; non requis au lancement.)*

### 3.2 Pays porté par les lignes opérationnelles

- `chasseur.code_pays_exercice char(2) NOT NULL DEFAULT 'FR'`
- `client.code_iso_pays_residence char(2) NOT NULL DEFAULT 'FR'` *(= l'additif C3)*
- `compromis` / `bien` : le pays est déjà disponible via `zone.code_iso_pays`.

### 3.3 Application par trigger `tg_valide_champs_pays`

Un `CHECK` SQL **ne peut pas interroger une autre table** ; la règle « obligatoire selon le pays » est donc portée par un **trigger** (data-driven), qui lit `config_pays` pour le pays de la ligne et valide :

- **Chasseur** — si `carte_t_requise` et `numero_carte_t IS NULL` → rejet.
- **Client** — si `regex_code_postal IS NOT NULL` et `code_postal_residence` ne correspond pas → rejet. *(FR conserve `^[0-9]{5}$`, donc aucun affaiblissement.)*
- **Compromis** — si `delai_retractation_jours IS NOT NULL` alors `fin_retractation` est exigé ; sinon il est autorisé NULL.

Principe clé, conforme à ce que vise l'équipe : **les champs non pertinents pour un pays sont autorisés à NULL**, les champs pertinents sont exigés — le tout décidé par la **donnée de configuration**, pas par le schéma.

### 3.4 Document légal du chasseur

La pièce légale (carte T française, ou son équivalent étranger) se range dans l'entité `document` (cf. ADR documents), avec un **type requis déterminé par le pays**. Le trigger vérifie la présence du document du type attendu selon `config_pays`.

## 4. Plan de transition (mécanique, le jour de la Phase 3)

1. Créer `config_pays` ; **seed de la ligne FR** reproduisant à l'identique les règles actuelles.
2. Ajouter les colonnes pays (`chasseur.code_pays_exercice`, le `code_iso_pays_residence` client).
3. Remplacer les contraintes FR en dur (`numero_carte_t NOT NULL`, `fin_retractation NOT NULL`, regex code postal) par le trigger `tg_valide_champs_pays`.
4. **Comportement FR strictement identique** après bascule ; chaque nouveau pays = une ligne `config_pays`.

Tant que la Phase 3 n'est pas lancée, **rien ne change** : les contraintes actuelles tiennent lieu de configuration FR implicite.

## 5. D4 — Ouverture Phase 4 (scraping / ingestion d'annonces)

Distincte de l'internationalisation, consignée ici comme **ouverture Phase 4** (non implémentée) : le scraping ingère des **annonces avant tout rapprochement** à un bien du référentiel. Cela suppose de rendre `annonce.id_bien` **nullable** et d'ajouter un statut `en_attente_matching`. Aujourd'hui, `annonce.id_bien` est `NOT NULL` (intégrité voulue). La bascule se fera dans une **zone de staging / landing-zone** dédiée au flux brut, sans dégrader l'OLTP métier. Un commentaire sera ajouté dans le DDL à l'emplacement concerné pour marquer l'ouverture.

## 6. Alternatives écartées

| Option | Rejet |
|---|---|
| `DROP NOT NULL` global (R1) | Affaiblit l'intégrité **FR actuelle** ; perte de conformité. |
| `CHECK` conditionnels en dur par pays (`code_pays<>'FR' OR …`) | Viable en interim (c'est déjà le motif de `ck_zone_insee_fr`), mais **fige les règles dans le schéma** → un `ALTER` par pays, non maintenable à l'échelle. |
| Une table/colonne par pays | Sur-ingénierie ; explosion du schéma. |

## 7. Conséquences

- **Positives :** intégrité FR **préservée** dès maintenant ; internationalisation **activable par la donnée** (une ligne de config), DDL minimal à la bascule ; récit d'architecture clair pour la soutenance (« du franco-centré figé vers une conformité paramétrable »).
- **Coûts :** un trigger procédural sur les écritures `chasseur`/`client`/`compromis` (fréquence faible, coût négligeable) ; un référentiel à tenir à jour par pays ouvert.
- **Dépendances :** embarque l'additif **C3** (pays de résidence client) et un pays d'exercice sur le chasseur comme prérequis du design.

## 8. Rattachement RNCP40573

| Bloc | Contribution |
|---|---|
| BC01 | Décision d'architecture tracée ; alternative « DROP NOT NULL » écartée en conscience |
| BC03 | Les règles de conformité restent portées par le SGBD (trigger + référentiel), pas déléguées à l'applicatif |
| BC05 | Ouverture d'évolutivité (international, scraping) documentée sans dette sur le socle courant |
