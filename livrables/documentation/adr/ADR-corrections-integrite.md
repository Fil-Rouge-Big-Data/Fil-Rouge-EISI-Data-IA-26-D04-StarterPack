# ADR — Corrections d'intégrité du socle

> **Numéro :** proposé ADR-032 · **Statut :** Accepté
> **Date :** 2026-10-02 · **Renvoi grille :** A3, A4, A5, A6 · **Sources :** R2, R3b (scénarios reproductibles S1, S3, S4).

## 1. Contexte

Plusieurs contraintes **annoncées** par le dossier v7 ne sont pas réellement **appliquées** par le schéma, prouvé par des scénarios reproductibles. Ce sont des **défauts d'intégrité** (pas des choix de conception) : le socle valide des données qu'il prétend refuser. Ils doivent être corrigés avant toute mise en service, indépendamment du reste.

## 2. Décision

Appliquer quatre corrections de contraintes.

| ID | Correction (DDL) | Défaut corrigé | Preuve |
|---|---|---|---|
| **A3** | Second **trigger de contrainte différé** `AFTER INSERT ON demande` imposant la règle C4 (« au moins un acquéreur principal ») | Une **demande sans acquéreur** est acceptée ; C4 ne porte que sur `demande_acquereur` | S1 |
| **A4** | `zone` : `ADD CONSTRAINT ck_zone_cp_fr CHECK (code_iso_pays <> 'FR' OR code_postal ~ '^[0-9]{5}$')` | `zone.code_postal = 'ABC'` accepté ; correctif annoncé (A07) mais absent | S4 |
| **A5** | `zone.code_insee` : regex → `^([0-9]{2}|2[AB])[0-9]{3}$` | Corse `2A004` **rejeté à tort** ; `1234A` **accepté à tort** | S3 |
| **A6** | `mandat` : `ADD UNIQUE(id_mandat_precedent)` + `CHECK`/FK « même demande que le mandat précédent » | `id_mandat_precedent` sans garde-fou : successeur non unique, pas de cohérence de demande, boucle possible | — |

## 3. Précisions

- **A3** — la règle « ≥ 1 acquéreur principal » est une contrainte **inter-tables** (demande ↔ demande_acquereur) : elle ne peut être qu'un trigger différé (vérifié en fin de transaction), d'où le second trigger en plus de l'existant. Un **test dédié** doit couvrir ce rejet (cf. F1).
- **A5** — la Corse utilise `2A`/`2B` en 2ᵉ/3ᵉ caractère INSEE ; la classe `[0-9A-B]` en dernière position laissait passer `1234A`. La nouvelle regex ancre le motif correct.
- **A6** — l'unicité du successeur garantit une **filiation linéaire** des renouvellements ; le `CHECK` de même demande empêche de chaîner des mandats de dossiers différents.

## 4. Alternatives écartées

Aucune alternative de conception : ce sont des **corrections de bugs**. La seule variante est l'ordre d'application — traitée dans l'ordre d'exécution de la grille (A + F1 en premier).

## 5. Conséquences

- Le socle **applique enfin** les invariants qu'il annonçait ; les tests correspondants deviennent **discriminants** (cf. F1).
- Impact fonctionnel nul sur les données valides ; seuls les cas illégitimes sont désormais rejetés.

## 6. Rattachement RNCP40573

BC03 — intégrité des données garantie par le SGBD ; BC01 — défauts tracés et corrigés en conscience ; validation par tests reproductibles (BC05).
