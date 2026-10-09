# Archive — documents de modélisation v7

> ⚠️ **Obsolète.** Ces fichiers décrivent le modèle **v7** et ne décrivent plus le modèle courant (v8.41). Ne pas s'en servir pour écrire du code ni pour répondre à une question sur le schéma : utiliser `../dictionnaire-donnees-v841.md`, `../dictionnaire-colonnes-v841.md`, `../dossier-modelisation-v841.md` et `../mpd-v841.md`.

## Pourquoi ils sont conservés

Ils portent encore du contenu **sans équivalent** dans le dossier v8.41 :

- la **méthode Merise de bout en bout** (dossier, §1) ;
- la **preuve de normalisation** et les dénormalisations assumées (dossier, §5) ;
- l'**ouverture OLAP** : principe, scission de responsabilité, règles d'articulation (dossier, §7), reprise dans le document de passation vers le chantier OLAP ;
- les textes des **ADR 025 à 031**, désormais extraits en fichiers dans `../../adr/`.

## Ce qui a changé depuis la v7

| v7 | v8.41 |
| --- | --- |
| Statuts stockés (mandat, demande, compromis) | Aucun statut stocké : états dérivés par des vues (ADR-048) |
| Clés UUID aléatoires | UUIDv7 ordonnés dans le temps (ADR-044) |
| Rattachement polymorphe des documents | Tables de liaison à vraies clés étrangères (ADR-049) |
| Booléens d'exigence `exige_*` | Préférences à 4 états `pref_*` (ADR-052) |
| Note d'avis rattachée au mandat et au bien | Note d'avis rattachée à la proposition (ADR-049) |
| Rémunération : résultat gelé, barème en suspens | Gel complet, barème versionné, cinq composantes du score (ADR-049, ADR-052) |

## Contenu

`dossier-modelisation-v7.md` · `dictionnaire-donnees-v7.md` · `mpd-v7.md` · `mcd-v7-carte-ensemble.png` · `mld-v7-carte-relationnelle.png`
