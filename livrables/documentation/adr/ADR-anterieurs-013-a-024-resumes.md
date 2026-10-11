# ADR antérieurs (013 à 024) — résumés

> ℹ️ **Résumés repris du dossier de modélisation v7 (§8.1, archivé).** Ces décisions ont été prises avant la v8 ; leur texte intégral n'est plus dans le dépôt. Certaines sont dépassées : l'ADR-023 (statut `expire`) est sans objet depuis ADR-048 (aucun statut stocké).

## ADR-013 (révisé)

**Décision.** Produire le DDL complet et le valider **par exécution réelle**

**Points clés.** A révélé deux défauts invisibles à la relecture (ordre index/déclencheur, transactions différées)

## ADR-015

**Décision.** Clés techniques sur `affectation` et `demande_version`, clé composée conservée sur `indisponibilite`

**Points clés.** Clé naturelle **toujours** maintenue en alternative : la contrainte d'identification relative est préservée

## ADR-016 (élargi)

**Décision.** Contraintes de double chemin par **FK composées vers clés alternatives**

**Points clés.** Quatre classes d'incohérence deviennent impossibles plutôt qu'improbables ; contrôle applicatif écarté (contournable par tout accès direct)

## ADR-017

**Décision.** `CHECK (IN ...)` partout, aucun `ENUM`

**Points clés.** Les listes évoluent ; un CHECK se remplace en transaction, un ENUM verrouille. Table de référence écartée (19 tables de 2 colonnes pour des listes stables)

## ADR-018

**Décision.** Retrait de la clientèle professionnelle (B2B)

**Points clés.** Client = particulier, spécialisation de UTILISATEUR. Retour arrière non additif (déplacerait une PK) — signalé au PO

## ADR-019

**Décision.** La contrainte de signature devient **déclarative**

**Points clés.** FK composée vers `demande_acquereur` remplace 13 lignes de PL/pgSQL ; s'applique aux chargements en masse, survit aux désactivations de déclencheurs

## ADR-022

**Décision.** ZONE restructurée en table unique à colonnes hiérarchiques

**Points clés.** Exigence PO. Violation 3FN **déclarée** (§5.1) ; l'égalité de libellés remplace une FK : normalisation d'import critique

## ADR-023

**Décision.** `expire` retiré des statuts saisissables de MANDAT

**Points clés.** Fermeture de l'anomalie A01 à la source : un statut ne peut plus contredire les dates (lecture par `v_mandat`)

## ADR-024

**Décision.** Réintégration de la chaîne de valeur (6 entités)

**Points clés.** Reporter en lot 2 ce qu'on a soi-même qualifié d'anomalie (A08) est indéfendable ; coût de migration nul (tables vides) ; sans ACTE, les honoraires n'ont pas de fait générateur. **Réserve d'honnêteté** : le report n'était pas une décision mais une inertie — la relecture périodique des reports devrait être un point de revue
