# ADR-047 — Date de référence reproductible dans les vues

> **Statut :** Accepté · **Date :** 2026-10-06 · **Déclencheur :** revue v8 (bloquant B4). · **Fonde :** ADR-041 (F5, tests au 25/07/2026).

## 1. Contexte

Les vues `v_mandat` et `v_conformite_chasseur` jugeaient l'expiration (mandat
échu, habilitation expirée) avec `current_date`. Résultat : la vue renvoie un
résultat **différent selon le jour d'exécution**. Or l'ADR-041 (F5) exige des
contrôles de reprise **reproductibles**, datés au 25/07/2026. Un test qui dépend
de la date du jour n'est pas rejouable.

## 2. Décision

Introduire une fonction `date_reference()` que les vues de jugement temporel
appellent au lieu de `current_date` :

```sql
CREATE OR REPLACE FUNCTION date_reference() RETURNS date AS $$
  SELECT COALESCE(
    NULLIF(current_setting('chasse.date_reference', true), '')::date,
    current_date);
$$ LANGUAGE sql STABLE;
```

- **En production** : aucune configuration → `current_date` (comportement normal).
- **En contrôle / test** : `SET chasse.date_reference = '2026-07-25'` rend le
  résultat déterministe, indépendant du jour.

Le paramètre est un **GUC de session** (`chasse.date_reference`), pas une table.

## 3. Alternatives écartées

| Option | Rejet |
|---|---|
| Garder `current_date` (v8) | Vues non reproductibles ; contredit ADR-041/F5. |
| Table `parametre(cle, valeur)` | Introduit une dépendance de données dans chaque vue et la question « qui remplit la table » — le défaut même reproché à `date_anonymisation`. Lourd pour une date de contrôle. |
| Paramètre passé à chaque requête | Impossible pour une vue (pas de paramètre). |

## 4. Conséquences

- **Positives :** vues reproductibles en test/contrôle, comportement normal en
  prod, sans dépendance de données. Vérifié (GUC lu → 2026-07-25 ; absent → date du jour).
- **Coûts :** une fonction `STABLE` ; penser à poser le GUC dans les scripts de
  contrôle de reprise.

## 5. Rattachement RNCP40573

| Bloc | Contribution |
|---|---|
| BC02 | Contrôles de reprise reproductibles et traçables |
| BC03 | Logique temporelle paramétrable proprement |
