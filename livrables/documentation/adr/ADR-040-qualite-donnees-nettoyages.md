# ADR-040 — Qualité des données & nettoyages

> **Statut :** Accepté · **Date :** 2026-10-02 · **Renvoi grille :** E2, E5 · **PostgreSQL 16.15**.

## 1. Contexte

Correctifs de **qualité** et de **propreté** relevés par R2/R3 : certains sans impact fonctionnel (propreté), deux portant une **vraie correction**.

## 2. Décisions

| Réf | Changement DDL | Effet |
|---|---|---|
| **E2** | `zone.ville` / `zone.secteur` → `citext` (ou `CHECK (ville = lower(unaccent(ville)))`) | Neutralise les doublons orthographiques (« Montpellier » vs « montpellier ») qui polluaient le matching et l'unicité `(pays,ville,secteur)` |
| **E5-m5** | `periode` : `ADD UNIQUE(type_periode, date_debut)` | **Correction** : empêche deux périodes de même type et même début (fiabilise l'aval indicateurs) |
| **E5-m13** | `v_honoraires` : `round(honoraires_total, 2)` | **Correction** : évite une dérive au centime — ces honoraires sont l'**assiette** de la rémunération (cf. ADR-031) |
| **E5-m4** | `mandat` : supprimer `id_demande_signataire` + `ck_mandat_signataire_demande` ; utiliser `id_demande` dans la FK composée | Colonne redondante (le `CHECK` la forçait déjà égale à `id_demande`) |
| **E5-m3** | `ck_zone_insee_fr` : simplifier en `(code_iso_pays<>'FR' OR code_insee IS NOT NULL)` | Branche morte `ville IS NULL` (la colonne est `NOT NULL`) |
| **E5-m12** | `DROP EXTENSION pgcrypto` | `gen_random_uuid()` est **natif en PostgreSQL 16** — extension inutile |

## 3. Conséquences

- Deux corrections (m5, m13) fiabilisent respectivement les indicateurs et la base de calcul de rémunération.
- Les autres (m3, m4, m12) allègent le schéma sans impact fonctionnel.

**RNCP40573** — BC03 : intégrité et qualité de la donnée ; BC01 : nettoyages tracés.
