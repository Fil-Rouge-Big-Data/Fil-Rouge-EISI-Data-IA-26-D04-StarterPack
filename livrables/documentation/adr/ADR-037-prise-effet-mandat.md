# ADR-037 — Prise d'effet du mandat : `date_debut = date_signature`

> **Statut :** Accepté · **Date :** 2026-10-02 · **Renvoi grille :** A12 · **Clarifie :** ADR-030 §2.13.

## 1. Contexte

Le dossier (§2.13) affirmait une **prise d'effet distincte de la signature** (délai de rétractation de 14 jours), d'où un calcul de `date_fin` depuis `date_debut`. Or les user stories fixent explicitement la fin à **« signature + 6 mois »** (US 00 @duree-mandat : signé le 2026-02-25 → fin le 2026-08-25 ; US 07 @renouvellement). Il existait donc un **écart** potentiel à trancher.

## 2. Décision

On pose **`date_debut = date_signature`**. Dès lors `date_debut + 6 mois = signature + 6 mois` : **l'écart à l'énoncé est dissous**, sans recalcul.

- **Expliciter** la règle et **aligner le dossier §2.13** (qui affirme aujourd'hui l'inverse).
- **Verrouillage** au choix : `CHECK (date_debut = date_signature)`, ou suppression de la colonne redondante `date_debut` (la contrainte actuelle `ck_mandat_effet` autorisait `date_debut >= date_signature`).

## 3. Conséquences

- `date_fin` reste **dérivée** (cohérent ADR-030 : si calculable, ne pas stocker), et conforme aux US.
- **Réversibilité :** si un jour une prise d'effet décalée (rétractation) devient nécessaire, l'écart réapparaîtra et devra être tracé dans ADR-030.

**RNCP40573** — BC03 : règle temporelle cohérente et conforme aux US ; BC01 : écart tracé et levé.
