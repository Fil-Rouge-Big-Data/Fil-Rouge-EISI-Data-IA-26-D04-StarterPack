# ADR-049 — Rémunération gelée, droit dérivé & documents (v8.4)

> **Statut :** Accepté · **Date :** 2026-10-07 · **Complète :** ADR-031, ADR-042 · **Déclencheur :** revue v8.1.

## 1. Contexte

La revue v8.1 a montré que le sous-modèle rémunération n'était « gelé » qu'en
intention (colonnes nullables, borne de taux en commentaire, droit non tracé), et
que le rattachement des documents reposait sur un polymorphe sans intégrité.

## 2. Décisions

### 2.1 Gel complet de la rémunération (R1, R4)
Les colonnes de calcul deviennent **NOT NULL** : une rémunération est insérée
**complète** (le calcul se fait à l'instant de l'acte, à partir des perfs du
chasseur à ce moment — pas de calcul par étapes). Les **5 composantes** du score
(délai, réussite, satisfaction, volume, ancienneté) sont **conservées** en plus du
score global : le gel doit être **reconstituable juridiquement** même si les règles
de calcul évoluent. Une annulation exceptionnelle est un **flag daté** + motif
(`date_annulation`, `motif_annulation`), pas un statut (cohérent ADR-048).

### 2.2 Borne de taux garantie (R2)
`CHECK (taux_final BETWEEN 20 AND 60)` : la borne métier (US 00/07) est **garantie
par le SGBD**, plus un simple commentaire. Ajustable par migration de contrainte si
le besoin métier évolue (documenté sur la colonne).

### 2.3 Droit à rémunération : dérivé, non stocké (R3)
**`origine_decouverte` est supprimé.** Le droit se **dérive de l'existence de
l'acte** : un acte n'existe que si la vente a été menée par le chasseur via sa
chaîne `proposition → offre → compromis → acte`. Une **vente externe** (mandat non
exclusif, le client achète ailleurs) **ne crée pas d'acte** : elle clôt le mandat
via `type_resiliation = 'vente_externe'`. Donc : **une rémunération existe ⟺ un acte
existe ⟺ le droit est ouvert**. Rien à vérifier, rien à stocker.

> Simplification majeure : la revue proposait de tracer le droit (colonne +
> contrainte conditionnelle). L'analyse métier montre que c'est inutile — l'acte
> *est* la preuve du droit. On retire deux colonnes (`origine_decouverte`,
> `droit_ouvert` envisagé) et une contrainte conditionnelle.

### 2.4 Facturation (point mineur)
`facture_chasseur` : `UNIQUE(id_remuneration)` (pas de double facturation) +
cycle de vérification tracé (`date_verification`, `id_verificateur`, `motif_rejet`).

### 2.5 Documents & note d'avis
- **`document`** enrichi des métadonnées MinIO : `cle_objet`, `mime_type`,
  `taille_octets`, `hash_sha256` (intégrité + dédoublonnage).
- **Rattachement polymorphe remplacé** par deux tables de liaison à vraies FK :
  `note_avis_document`, `facture_document`. Intégrité portée par le SGBD.
- **`note_avis` rattachée à `id_proposition`** (au lieu de mandat+bien libre) :
  on en déduit bien + mandat, et on garantit que le bien a été proposé.
- **`commentaire`** étendu à une 3ᵉ cible `id_bien` (note métier, souvent privée,
  du chasseur sur un bien déjà tenté), vraie FK, CHECK « exactement une cible ».

## 3. Conséquences
- Rémunération auditable et reconstituable (exigence juridique) ; borne garantie.
- Modèle simplifié (droit dérivé, polymorphe éliminé).
- `origine_decouverte` retiré : à vérifier qu'aucun code aval ne s'y appuyait (fait).

## 4. Rattachement RNCP40573
BC01 (décisions tracées), BC03 (intégrité SGBD, gel juridique), BC05 (données fiables pour l'aval).
