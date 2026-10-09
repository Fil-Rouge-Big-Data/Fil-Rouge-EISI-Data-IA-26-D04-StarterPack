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

**Clarification (relecture v8.41) — mandat exclusif, mandat non exclusif et « trouvé par le client ».**

Le README du prof distingue deux cas :
- **mandat exclusif** : « même si le client trouve seul, le chasseur sera rémunéré » ;
- **mandat non exclusif** : « le chasseur pourra ne pas être rémunéré ».

Le modèle OLTP ne porte **aucune garde** sur cette distinction : la base ne sait pas qui a trouvé
le bien. C'est voulu — `origine_decouverte` a été retirée. Le droit à rémunération se lit
uniquement dans l'existence de l'acte. Voici comment les deux cas s'expriment :

| Situation | Mandat exclusif | Mandat non exclusif |
| --- | --- | --- |
| Vente menée par le chasseur (proposition → offre → compromis → acte) | Acte créé → rémunération | Acte créé → rémunération |
| Client trouve seul et achète via le chasseur | L'**API crée l'acte** (le mandat exclusif garantit la rémunération) → rémunération | L'**API décide** : elle peut créer l'acte ou non selon la politique commerciale |
| Client achète ailleurs (autre agence, PAP) | Impossible : la vente passe par un autre notaire, pas d'acte chez nous → `type_resiliation = 'vente_externe'` | Idem → `type_resiliation = 'vente_externe'` |

**La garde est métier, pas structurelle.** C'est l'application (API) qui décide de créer l'acte
quand le client a trouvé seul. Sur un mandat exclusif, elle **doit** le créer (le contrat
l'impose) ; sur un mandat non exclusif, elle **peut** ne pas le créer. La base n'a pas à connaître
cette règle : elle garantit seulement que si un acte existe, la rémunération est complète et
reconstituable.

La chaîne `proposition → offre → compromis → acte` **n'est pas une fiction** dans le cas
« client trouve seul, mandat exclusif » : le bien trouvé par le client est tout de même proposé
(le chasseur le valide), l'offre est formalisée, le compromis signé et l'acte passé. C'est le
parcours réel, documenté par le notaire. Les scores du chasseur (délai, visites) reflètent la
réalité de ce parcours, pas un parcours inventé.

Si un acte est créé à tort, la rémunération peut être annulée (`date_annulation` +
`motif_annulation`), mais la base ne refuse pas l'insertion.

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

## 5. Convention de comptage des visites (relecture v8.41)

**Contexte.** La table `visite` porte un `id_visiteur → utilisateur` sans unicité par proposition ou
par date : deux personnes (le chasseur et le client, un couple d'acquéreurs) peuvent visiter le même
bien le même jour et produire chacune une ligne.

**Convention retenue.** Une visite est un **fait par participant**. Le score de visites du chasseur
(`score_visites`, pondération 25) se calcule en comptant les **visites réalisées par le client** sur
les propositions du mandat concerné, sur les 12 mois glissants précédant l'acte :

```sql
SELECT count(*)
FROM visite v
JOIN proposition p ON p.id_proposition = v.id_proposition
WHERE p.id_mandat = :id_mandat
  AND v.realisee = true
  AND EXISTS (SELECT 1 FROM client c WHERE c.id_utilisateur = v.id_visiteur)
  AND v.date_visite BETWEEN :date_acte - INTERVAL '12 months' AND :date_acte
```

Ce comptage est une **règle OLAP** (ou du moteur de calcul de la rémunération), pas une contrainte
d'intégrité. La base ne porte pas de `UNIQUE` sur `(id_proposition, date_visite)` : cela interdirait
les visites à deux (couple acquéreur, chasseur + client), qui sont le cas majoritaire.

**Alternative écartée.** Ajouter une unicité `(id_proposition, date_visite, id_visiteur)` empêcherait
un même visiteur de revenir le même jour (contre-visite de contrôle), sans bénéfice pour l'intégrité.
