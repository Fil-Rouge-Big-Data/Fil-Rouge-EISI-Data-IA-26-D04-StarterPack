# ADR — Chaîne de rémunération du chasseur (barème, calcul, facturation, paiement)

> ℹ️ **Règle du droit à rémunération révisée par ADR-049 (v8.4).** La colonne `origine_decouverte` est supprimée : le droit se dérive de l'existence de l'acte (un acte est toujours une vente menée par le chasseur ; une vente externe ne crée pas d'acte). La pondération du score (délai 25 · exclusivité 10 · ventes 25 · mandats 15 · visites 25) reste la référence ; ses composantes sont précisées par ADR-052.

> **Numéro :** à figer avec le lot d'ADR (proposé : ADR-031) · **Statut :** Accepté
> **Date :** 2026-10-02 · **Date de référence projet :** 25 juillet 2026
> **Remplace/étend :** ADR-029 (barème reporté « point ouvert PO »)
> **Sources faisant foi :** user stories `00_regles_metier_mandat_remuneration`, `07_chasseur_remuneration_et_performance`, `10_calcul_remuneration_chasseur` (+ `documents utiles/REGLES-CALCUL-REMUNERATION.md` pour les valeurs). Renvois grille : B1, B2 ; cohérence A1, A2, A12 ; migration A9.

## 1. Contexte

La règle de rémunération, le cycle de facturation et l'algorithme chiffré ont été **émis a posteriori** de la v7 : celle-ci ne conservait que `remuneration_chasseur.montant_part` + `reference_bareme` (texte libre). Or les US imposent désormais un calcul **déterministe, auditable et figé au jour de l'acte**, un **barème variable dans le temps et par chasseur**, et un **cycle facture → vérification → paiement**. Le texte libre ne permet ni de reproduire, ni d'auditer, ni d'expliquer un montant.

Principe directeur des US (`10`, en-tête) : **les règles sont métier** (invariantes), **les valeurs numériques sont des paramètres** proposés par le PO (donc versionnables). Cela commande de **stocker le barème et les paramètres** plutôt que de les coder en dur, et de **geler** les éléments de calcul sur l'acte.

## 2. Décision

Modéliser dans l'**OLTP** la chaîne complète :

1. un **barème versionné** (par défaut + propre au chasseur) et les **paramètres d'honoraires** versionnés ;
2. le **gel** des éléments de calcul sur la ligne de rémunération, à la date de l'acte ;
3. le **droit à rémunération** (exclusivité × origine de la vente) ;
4. le **cycle facture → vérification → paiement** ;
5. la **frontière OLTP/OLAP** : le score qui **sert le paiement** est figé en OLTP ; seule l'exploitation **comparative** de la performance va en OLAP.

## 3. Règles métier (invariantes)

Ordre de calcul, **figé au jour de l'acte authentique** :

> droit → assiette (honoraires) → score de performance → taux de tranche → modulation (ancienneté + performance) → bornage → montant arrondi.

| Étape | Règle |
|---|---|
| **Droit** | Ouvert/fermé selon exclusivité × origine (table §3.1). Acte signé après l'échéance du mandat → **fermé**, rémunération **0,00 €**. **Un seul** chasseur rémunéré par vente (celui à l'origine de la transaction aboutie). |
| **Assiette** | `honoraires = montant_fixe + pourcentage × prix_acté`. Le taux s'applique **aux honoraires**, jamais au prix du bien. Les honoraires sont collectés par le notaire en sus du prix. |
| **Score** | Moyenne pondérée de 5 critères notés 0-100. Volumes (ventes, mandats) comptés sur **12 mois glissants** avant l'acte. |
| **Taux de tranche** | Taux **plat** de la tranche du **prix** (aucune progressivité entre tranches ; le taux s'applique à la totalité des honoraires). **Le barème propre au chasseur prévaut** sur le barème par défaut. Barème **en vigueur à la date de l'acte**. |
| **Modulation** | `taux_final = taux_base × (1 + majoration_ancienneté + modulation_performance)` (majorations **relatives**). |
| **Bornage** | `taux_final` borné à **[20 %, 60 %]**. |
| **Montant** | `rémunération = taux_final × honoraires`, arrondi au **centime, au demi supérieur**. |
| **Gel** | Éléments figés à l'acte, **jamais recalculés** : honoraires, score, taux de base, modulations, taux final, montant. Un changement de barème postérieur ne modifie pas une rémunération déjà calculée. |

### 3.1 Droit à rémunération

| Exclusivité | Origine de la vente | Droit |
|---|---|---|
| exclusif | le chasseur | ouvert |
| exclusif | le client, hors dispositif | ouvert |
| non-exclusif | le chasseur | ouvert |
| non-exclusif | le client, hors dispositif | fermé |
| non-exclusif | un chasseur d'une autre agence | fermé |

## 4. Paramètres (proposés — versionnés, à contresigner PO)

Valeurs en vigueur au 30/07/2026 (source `REGLES-CALCUL-REMUNERATION.md`) :

**Honoraires entreprise :** `montant_fixe = 3 000,00 €` · `pourcentage = 2,5 %`.

**Barème de commission par défaut (taux de base par tranche de prix) :**

| Montant min | Montant max | Taux de base |
|---|---|---|
| 0 | 199 999 | 30 % |
| 200 000 | 349 999 | 35 % |
| 350 000 | 499 999 | 40 % |
| 500 000 | 749 999 | 45 % |
| 750 000 | — | 50 % |

**Pondération des critères de performance :** délai mandat→acte **25** · exclusivité **10** · ventes réussies **25** · mandats signés **15** · visites avant achat **25**.

**Ancienneté :** +2 % **relatifs** par année révolue, plafond **+10 %**.
**Performance :** `(score − 50) × 0,4 %`, soit ±20 % autour d'un pivot de 50.
**Bornes taux final :** [20 %, 60 %]. **Arrondi :** centime, demi supérieur.

*Exemple de bout en bout (US 10) :* Bruno, mandat exclusif signé le 14/11/2025, 3 ans d'ancienneté, 4 ventes / 9 mandats sur 12 mois, 5 visites, acte le 30/07/2026 à 420 000 € → honoraires **13 500 €**, score **73,5**, taux de base 40 %, ancienneté +6 %, performance +9,4 % → taux final **46,16 %**, rémunération **6 231,60 €** (marge entreprise 7 268,40 €).

## 5. Modèle de données (OLTP)

**Référentiel versionné (B1)**
- `bareme` : `id_bareme`, `id_chasseur` **nullable** (NULL = barème par défaut ; renseigné = barème propre), `date_debut_vigueur`, `date_fin_vigueur`.
- `tranche_bareme` : `id_bareme` (FK), `montant_min`, `montant_max` **nullable** (tranche ouverte), `taux_base`. Contrainte de non-chevauchement par barème.
- `parametre_honoraires` (**optionnel**) : `montant_fixe`, `pourcentage`, `date_debut_vigueur`, `date_fin_vigueur` — **valeurs par défaut versionnées**. L'`acte` stocke déjà les honoraires **appliqués** (`honoraires_fixe`, `honoraires_taux`) ; cette table ne sert qu'à fournir/auditer les défauts en vigueur, **pas à dupliquer** le montant.

**Fait rémunération figé (B1)**
- `remuneration_chasseur` : ajout des colonnes de **gel** `honoraires`, `score_performance`, `taux_base`, `majoration_anciennete`, `modulation_performance`, `taux_final`, `montant` ; `reference_bareme` → **FK** vers le `bareme`/`tranche_bareme` appliqué ; `UNIQUE(id_acte)` (A2 : un seul chasseur payé).
- **Droit à rémunération — aucune nouvelle colonne** : on **réutilise l'existant** `offre_acquisition.origine_decouverte` (`chasseur | client | tiers`) et `mandat.exclusif`, lus via la chaîne `acte → compromis → offre → proposition → mandat` (A1). Le droit se résume à `exclusif OU origine = 'chasseur'` → les 3 valeurs suffisent (`tiers` = hors dispositif / autre agence). *(À sécuriser : rendre `origine_decouverte` non nul sur l'offre acceptée qui mène à un acte.)* Le droit résolu est **figé** sur la ligne de rémunération.

**Cycle facturation / paiement (B2)**
- `facture_chasseur` : `id_facture`, `id_remuneration` (FK), `numero`, `montant`, `date_emission`, `statut` (`soumise | verifiee_conforme | rejetee`) + rattachement possible à un `document` (B4).
- Paiement porté en colonnes sur la facture (1:1, pas de paiement partiel dans les US) : `statut_paiement` (`programme | paye`), `date_programmation`, `date_paiement`.

## 6. Frontière OLTP / OLAP

- **OLTP :** le **score figé** sur la rémunération et ses 5 notes composantes (ils **servent le paiement**, calculés à l'acte depuis les faits OLTP — ventes/mandats sur 12 mois). Le référentiel barème/paramètres. Le fait rémunération et le cycle facture/paiement.
- **OLAP :** l'exploitation **comparative** de la performance (classements, tendances affichées au chasseur après paiement), et toute somme/moyenne des montants. Exclure `SYS-MIGRATION` (migration D-ROOT).
- Le calcul sur **12 mois glissants** au moment de l'acte ne bascule pas en OLAP : c'est une entrée d'un paiement, figée.

## 7. Alternatives écartées

| Option | Rejet |
|---|---|
| Conserver seulement `montant_part` (+ texte) | Non auditable, non reproductible — l'US 10 exige un calcul explicable et figé. |
| Coder le barème/paramètres en dur | Contredit « valeurs = paramètres versionnés » ; barème variable dans le temps et par chasseur. |
| Calculer la rémunération en OLAP | Couplerait un **paiement** à la couche analytique ; l'US impose un gel transactionnel à l'acte. |
| Barème unique sans override chasseur | Contredit l'US 10 (« barème propre au chasseur prévaut »). |
| Table `paiement_chasseur` séparée | Sur-normalise : les US ne prévoient pas de paiement partiel → colonnes sur la facture suffisent. |

## 8. Conséquences

- **Positives :** rémunération déterministe, auditable, reproductible ; barème gouverné et historisé ; audit « zéro déperdition » sur le montant ; cycle facture/paiement traçable (US 07).
- **Coûts :** 2 tables de barème (`bareme`, `tranche_bareme`) + 1 table de paramètres d'honoraires *optionnelle* + 1 table facture + colonnes de gel ; le **droit** (exclusivité, origine) réutilise l'existant, sans nouvelle colonne ; les **valeurs** de paramètres restent à contresigner par le PO ; l'assiette se branche sur `v_honoraires` existant, base `TTC`/`20 %` (migration A9).
- **À spécifier hors modèle :** le moteur de calcul (application/procédure) qui applique ces règles et écrit le gel ; les scénarios de test tracés vers les US (structure_projet §tests).

## 9. Rattachement RNCP40573

| Bloc | Contribution |
|---|---|
| BC01 | Décision d'architecture tracée, alternatives écartées en conscience |
| BC03 | Chaque règle métier est portée par une contrainte/structure OLTP ; le gel garantit l'auditabilité |
| BC05 | Socle OLTP cohérent alimentant proprement l'aval (OLAP/BI) sans recalcul rétroactif |
