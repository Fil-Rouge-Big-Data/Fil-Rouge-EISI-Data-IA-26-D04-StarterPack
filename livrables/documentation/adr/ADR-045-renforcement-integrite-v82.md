# ADR-045 — Renforcement d'intégrité (v8.2)

> **Statut :** Accepté · **Date :** 2026-10-06 · **Complète :** ADR-032 · **Déclencheur :** revue v8 (bloquants B1, B2, B3 ; sondes S1-S9).

## 1. Contexte

La revue v8 a montré, par des **sondes** (opérations interdites tentées contre le
schéma), que plusieurs incohérences passaient. Ce ne sont pas des cas théoriques :
une rémunération pouvait être rattachée à un chasseur qui n'est pas celui du
mandat, un barème pouvait avoir des tranches qui se chevauchent, une vente pouvait
naître d'un compromis non réalisé, un mandat pouvait être son propre précédent.

## 2. Décisions

### 2.1 FK composées : rattacher le contractuel au bon mandat (B1, S1-S3)

- `proposition.id_mandat` devient **NOT NULL** avec une **FK composée**
  `(id_mandat, id_demande) → mandat(id_mandat, id_demande)` : le mandat d'une
  proposition appartient à la même demande (clé `uk_mandat_demande`).
- `remuneration_chasseur` reçoit une **FK composée**
  `(id_mandat, id_chasseur) → mandat(id_mandat, id_chasseur)` (clé
  `uk_mandat_chasseur`) : le chasseur rémunéré **est** celui du mandat.

> Ceci corrige une erreur de la v8 : on avait retenu des FK simples en invoquant
> le rasoir d'Ockham. Ockham écarte des entités *inutiles*, pas une contrainte qui
> ferme un risque réel. Et comme les tables étaient vides, le coût d'ajout était
> minime — il serait devenu élevé une fois les données saisies.

### 2.2 Barème sans chevauchement ni trou (B3, S5-S6)

- Tranches en **intervalle semi-ouvert** `[montant_min, montant_max)` (borne haute
  NULL = +∞) : gère les montants au centime et supprime les trous entre tranches.
- Contrainte d'**exclusion** `btree_gist` : deux tranches du même barème ne peuvent
  se chevaucher (`ex_tranche_chevauchement`), et deux barèmes du même périmètre
  (défaut, ou même chasseur) ne peuvent être en vigueur simultanément
  (`ex_bareme_vigueur`). Extension `btree_gist` requise.

### 2.3 Chaîne de vente : pas de vente fictive (B2, S4)

Déclencheurs : un **compromis** ne peut porter que sur une **offre acceptée**
(`tg_compromis_offre_acceptee`) ; un **acte** ne peut porter que sur un
**compromis réalisé** (`tg_acte_compromis_realise`). Un CHECK ne suffit pas (règle
inter-lignes). L'acte trace l'**encaissement des honoraires** entreprise
(`honoraires_encaisses`, `date_encaissement`) : fait générateur de la rémunération
et de la concrétisation du parrainage.

### 2.4 Filiation de mandat (S9)

`ck_mandat_pas_auto_precedent` : un mandat ne peut pas être son propre précédent.
(La filiation « même demande » était déjà couverte par la FK composée, ADR-032.)

### 2.5 Gel de conformité nullable à la reprise (M1)

Les colonnes de gel de l'habilitation sur le mandat
(`numero_habilitation_signature`, `validite_habilitation_signature`) deviennent
**nullables**. `NULL` = « habilitation d'époque inconnue » (données reprises), ce
qui **n'est pas** une non-conformité — la vue `v_conformite_chasseur` ignore les
gels NULL. On évite ainsi le faux « hors carte » permanent que créait la sentinelle
`2000-01-01` de la v8.

## 3. Alternatives écartées

| Option | Rejet |
|---|---|
| FK simples (v8) | Ne garantissent pas la cohérence croisée chasseur/mandat et demande/mandat. |
| Triggers au lieu de FK composées | Procédural, plus lourd ; les clés existaient déjà pour des FK déclaratives. |
| Unicité sur `montant_min` seul (v8) | N'empêche pas le chevauchement de tranches ni les barèmes concurrents. |
| Sentinelle `2000-01-01` pour le gel (v8) | Produit une non-conformité permanente fausse. NULL est plus honnête. |

## 4. Conséquences

- **Positives :** les 9 sondes structurelles de la revue sont **fermées**,
  vérifié par la batterie `run_sondes.py` (rejet par la bonne contrainte).
- **Coûts :** extension `btree_gist` ; deux déclencheurs sur la chaîne de vente ;
  deux clés uniques techniques supplémentaires sur `mandat`.

## 5. Rattachement RNCP40573

| Bloc | Contribution |
|---|---|
| BC01 | Intégrité métier portée par le schéma, décisions tracées |
| BC03 | Contraintes déclaratives + déclencheurs ; harnais probant |
| BC05 | Données cohérentes en amont de l'analytique et de l'IA |
