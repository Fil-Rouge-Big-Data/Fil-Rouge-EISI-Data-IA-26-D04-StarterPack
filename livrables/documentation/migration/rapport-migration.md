# Rapport de migration — run `historique` (cible v8)

> Généré depuis `staging.migration_run` et `staging.migration_anomalie`.
> Run unique sur base v8 fraîche.

## Exécution

- Source : `historique` · Statut : **succes** · Lignes : 150 · Anomalies : 34

## Volumétries produites

| Table | Lignes |
|---|---|
| `utilisateur` | 25 |
| `gestionnaire` | 1 |
| `chasseur` | 6 |
| `client` | 18 |
| `zone` | 10 |
| `demande` | 18 |
| `demande_acquereur` | 18 |
| `demande_version` | 18 |
| `version_zone` | 18 |
| `mandat` | 18 |

## Tables v8 vides à la migration (aucune source)

| Table | Lignes |
|---|---|
| `bareme` | 0 |
| `tranche_bareme` | 0 |
| `parametre_honoraires` | 0 |
| `facture_chasseur` | 0 |
| `remuneration_chasseur` | 0 |
| `note_avis` | 0 |
| `document` | 0 |
| `document_rattachement` | 0 |

## Statuts de mandat (recalculés)

| Statut | Nombre |
|---|---|
| actif | 13 |
| clos_succes | 3 |
| resilie | 2 |

## Anomalies tracées

| Code | Occ. | Motif |
|---|---|---|
| `A02` | 6 | Mentions légales chasseur absentes -> sentinelles à régulariser |
| `A03` | 1 | primo_accedant déduit du texte « premier achat » |
| `A04` | 2 | statut 'suspendu' converti en 'resilie' motivé |
| `A06` | 1 | client_id=3 (un chasseur) reclassé -> client 19 |
| `T2` | 24 | password_hash absent -> sentinelle, reset au 1er login |

## Spécifiques v8

- Gel carte T sur mandat : 18/18 renseignés
- Conformité (D-FLAG) : 6 chasseurs à régulariser
- Parrainage (E7) : 0 frais offerts (aucun à la migration)