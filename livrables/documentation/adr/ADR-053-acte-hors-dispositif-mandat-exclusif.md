# ADR-053 — Achat hors dispositif sous mandat exclusif : acte sans compromis (v8.42)

> **Statut :** Proposé · **Date :** 2026-10-09, révisé le 2026-10-11 (D13, re-vérification après coup) · **Complète :** ADR-049 (§2.3, §5) · **Déclencheur :** revue de la PR #13 (point 1, Angeline Gomez et Matthieu Barre ; remarques de l'approbation du 11/10), test de recette T-DR-01 (CDC v3.0, PO-11).

## 1. Contexte

L'ADR-049 dérive le droit à rémunération de l'existence d'un acte, et un acte n'existait qu'au bout de
la chaîne `proposition → offre → compromis → acte`. Sa clarification v8.41 classait donc l'achat
« ailleurs » (particulier à particulier, autre agence) comme **impossible** sous mandat exclusif.

Trois sources de l'énoncé disent le contraire :

| Source | Ce qu'elle dit |
| --- | --- |
| `Readme.md`, l. 75 | mandat exclusif : « même si le client trouve seul, le chasseur sera rémunéré » |
| `user-stories/00_regles_metier_mandat_remuneration.feature`, l. 15-19 | Alice trouve un bien « en dehors du dispositif du chasseur », l'achète, et Bruno est rémunéré |
| `user-stories/10_calcul_remuneration_chasseur.feature`, l. 40 | exclusif + « le client, en dehors du dispositif » → droit **ouvert** |

Le `.feature` 00 (l. 42-48) précise que le notaire a connaissance du mandat et collecte les honoraires à
l'acte : une vente hors dispositif produit donc bien un acte et des honoraires, que la base doit pouvoir
enregistrer. La PR #13 (v8.41) a corrigé l'ADR-049 §2.3 en conséquence ; le présent ADR met le schéma en œuvre.

**Pourquoi ce cas se produira.** Dans le parcours nominal, le chasseur organise la signature (Readme,
parcours du chasseur, étape 9) : le notaire connaît le mandat parce que le chasseur lui apporte le
dossier. Quand le client trouve seul, il va chez **son** notaire, qui n'est pas tenu de connaître le
mandat. L'agence apprend alors la vente par le client (clause d'information du mandat), par le notaire
s'il a été informé, ou après coup. D'où la traçabilité de la source et de la date de connaissance.

## 2. Options étudiées

| Option | Principe | Verdict |
| --- | --- | --- |
| **A. Fabriquer une proposition** | Saisir une proposition, une offre et un compromis que le chasseur n'a pas instruits | **Écartée** : faits inventés, scores du chasseur faussés (visites, délai) |
| **B. Fait « vente constatée » distinct** | Nouvelle table, rémunération rattachée à l'acte OU à la vente constatée | **Écartée** : 39ᵉ table, rémunération à double rattachement, refonte plus large du MCD |
| **C. Hors base (clause pénale)** | Traiter l'achat ailleurs comme une indemnité contentieuse, hors chaîne d'honoraires | **Écartée** : plus proche du droit réel (décret du 20/07/1972, art. 78, et jurisprudence sur la clause pénale), mais contraire à l'énoncé, qui fait collecter les honoraires par le notaire |
| **D. Chaîne amont facultative sur `acte`** | Un acte a soit un compromis, soit directement un mandat | **Retenue** |

## 3. Décision

Un **acte authentique reste un acte**, quelle que soit la façon dont la vente a été trouvée. Il a
**exactement une origine** :

| Origine | Colonne renseignée | Garde |
| --- | --- | --- |
| Vente menée par le chasseur | `acte.id_compromis` | compromis non caduc (`tg_acte_compromis_realise`, ADR-048) |
| Achat hors dispositif | `acte.id_mandat` | mandat **exclusif**, **en vigueur** à la date de l'acte (`tg_acte_hors_dispositif`) |

Mise en œuvre (v8.42) :

1. **`acte`** : `id_compromis` devient facultatif (toujours unique) ; ajout de `id_mandat uuid UNIQUE
   REFERENCES mandat` (au plus un achat hors dispositif par mandat) ;
   `CONSTRAINT ck_acte_origine CHECK ((id_compromis IS NULL) <> (id_mandat IS NULL))`.
   Un simple `OR` aurait accepté les deux colonnes remplies, avec deux mandats potentiellement différents.
2. **`tg_acte_hors_dispositif`** (S24) : un acte sans compromis doit référencer le mandat de sa **chaîne de
   renouvellement en vigueur** à la date de l'acte (commencé, non échu, non résilié avant), et ce mandat doit
   être **exclusif**. Si un renouvellement est en vigueur, c'est lui qu'il faut référencer, pas le mandat initial.
3. **`tg_remuneration_mandat_acte`** (S25 / S26) : la rémunération porte sur le mandat de la chaîne **en
   vigueur à la date de l'acte**, retrouvé par l'une ou l'autre origine (S25) ; si aucun mandat de la chaîne n'est
   en vigueur, le droit est fermé et l'insertion refusée (S26, `.feature` 10 l. 45-50). La FK composée
   `(id_mandat, id_chasseur)` garantissait déjà que le chasseur rémunéré est celui du mandat ; rien ne
   garantissait jusqu'ici que ce mandat était celui de la vente, ni qu'il était en vigueur.
3 bis. **Re-vérification après coup** : modifier le mandat (exclusivité, dates, résiliation, filiation) ou l'acte
   (mandat, compromis, date) après l'écriture ne doit pas les rendre incohérents. Deux **déclencheurs de
   contrainte différés** (`tg_mandat_reverification`, `tg_acte_reverification`) rejouent les mêmes contrôles au
   commit. Différés, pour qu'une transaction applicative puisse enchaîner les mises à jour (par exemple
   redater l'acte puis déplacer la rémunération sur le renouvellement) ; `SET CONSTRAINTS ALL IMMEDIATE`
   les force sans attendre le commit.
4. **`mandat`** : `CONSTRAINT ck_mandat_vente_externe CHECK (NOT (exclusif AND type_resiliation =
   'vente_externe'))` — sous mandat exclusif, l'achat ailleurs n'est pas une fin anticipée. Sans cette
   contrainte, un mandat payé apparaîtrait « résilié » : dans `v_mandat`, la résiliation est testée
   avant le succès.
4 ter. **Résiliation refusée après un acte** (S27, revue de la PR #14 point A) : `tg_mandat_resiliation_apres_acte`
   refuse toute résiliation d'un mandat qui a abouti (`f_mandat_clos_par_acte`). Sans cela, une résiliation posée
   après l'acte faisait passer le mandat en « résilié » dans `v_mandat`, la résiliation y étant testée avant le succès.
   **Sens inverse** (revue de la PR #16, Thérèse Nguyen, point 1) : la garde ne jouait que sur l'écriture du mandat.
   Résiliation saisie d'abord, puis acte appris après coup et daté d'avant : S24 l'acceptait, la rémunération suivait,
   et le mandat payé restait « résilié ». `tg_acte_mandat_resilie` refuse désormais tout acte dont le mandat en vigueur
   à sa date est résilié, pour les deux origines de l'acte et sur la chaîne de renouvellement (T38, T39) ; l'agence
   annule d'abord la résiliation, puis saisit l'acte. La ligne du mandat est verrouillée (`FOR SHARE`) pendant la
   vérification : une résiliation concurrente attend, puis est refusée par S27 (test de concurrence, deux ordres).
4 quater. **Rémunération seulement après encaissement** (S28, D20) : `tg_remuneration_encaissement` refuse une
   rémunération tant que `acte.honoraires_encaisses` est faux, et `tg_acte_encaissement_remunere` refuse d'annuler
   l'encaissement d'un acte déjà rémunéré. La règle « l'encaissement par l'entreprise est le fait générateur de la
   rémunération » (Readme, parcours du chasseur, étape 10) était écrite dans le DDL mais portée par aucune contrainte : en cas de litige client
   (contestation des honoraires, décision judiciaire attendue), rien n'empêchait de payer le chasseur avant l'issue.
   **Concurrence** (revue de la PR #16, point A) : la vérification verrouille la ligne de l'acte (`FOR SHARE`). Sans ce
   verrou, une rémunération et une annulation d'encaissement lancées en même temps passaient toutes deux (course
   reproduite le 13/10) ; le verrou de la clé étrangère (`FOR KEY SHARE`) ne bloque pas la mise à jour d'une colonne
   non clé. Test rejouable dans les deux ordres : `livrables/db/concurrence/test_concurrence_s27_s28.sh`, intégré à la
   recette. **Contrat d'isolation** (revue de la PR #16, Thérèse Nguyen, point 2) : la garantie vaut en `READ COMMITTED`,
   le niveau par défaut, celui de la recette et de l'application ; chaque ordre d'un trigger y voit un instantané frais
   après l'attente du verrou. En `REPEATABLE READ`, la transaction qui attend garde son instantané : elle doit échouer
   en erreur de sérialisation et être rejouée. Ce mode n'est pas testé et ne doit pas être activé pour ces écritures.
   **Test probant** (point 3) : le harnais vérifie que la transaction attendue réussit, que l'autre est refusée avec le
   code de la garde, qu'elle a réellement attendu le verrou (chevauchement mesuré) et que l'état final est celui attendu.
   **Rémunération annulée** (point 5) : une rémunération portant `date_annulation` reste une ligne ; elle continue
   d'interdire de décocher l'encaissement. C'est voulu : l'historique prime, et une correction d'encaissement après
   annulation passe par une correction explicite, tracée, pas par un contournement (T37, P10).
5. **Traçabilité** : `acte.source_information` (`client`, `notaire`, `autre`) et
   `acte.date_connaissance` (date à laquelle l'agence a appris la vente, distincte de la date de l'acte),
   obligatoires pour, et seulement pour, l'acte hors dispositif (`ck_acte_trace_hors_dispositif`).
6. **Vues dérivées** : `v_mandat` (`a_acte`, `clos_succes`) et `v_demande` (`close`) cherchent l'acte
   par ses deux origines. Sans cela, un mandat rémunéré hors dispositif serait resté « actif » puis « échu ».
   Les vues appellent `f_mandat_clos_par_acte`, qui trouve les actes de la chaîne **par index** (`f_actes_chaine`)
   avant d'appeler `f_mandat_en_vigueur_chaine`. La première version (sous-requête corrélée sur `v_acte_mandat`)
   évaluait la fonction de chaîne pour chaque acte et chaque mandat : sur 20 000 mandats et 6 000 actes, la
   requête « mandats actifs d'un chasseur » dépassait 3 minutes ; elle prend 78 ms après restructuration, et
   `v_mandat` complète 12,6 s (note d'indexation). Clés : `COST 10000` et `ROWS 2` sur les fonctions de chaîne.
7. **Anonymisation** (`anonymiser.py`) : un client dont l'acte est hors dispositif est « transactionnel »
   (conservation légale longue), et non un prospect anonymisé au bout de 3 ans.

`remuneration_chasseur` ne change pas de structure : elle pointe toujours `acte(id_acte)` et porte déjà
`id_mandat`. Le principe de l'ADR-049 (« la vente authentique fait foi et déclenche la rémunération ») reste
intact.

## 4. Ce qui ne change pas

- **Mandat non exclusif, client qui trouve seul et achète via le chasseur** : la chaîne normale s'applique ;
  l'API décide de créer ou non l'acte (ADR-049, clarification v8.41), conformément au Readme l. 76
  (« pourra ne pas être rémunéré »).
- **Mandat non exclusif, client qui achète ailleurs** : pas d'acte, le mandat se clôt
  (`type_resiliation = 'vente_externe'`).

## 5. Convention de score pour un acte hors dispositif

Les cinq composantes du score sont gelées et `NOT NULL` (ADR-049, ADR-052). Pour un acte hors dispositif :

| Composante | Convention proposée |
| --- | --- |
| `score_delai` | Calculée normalement : délai réel entre le mandat et l'acte |
| `score_exclusivite` | Calculée normalement (le mandat est exclusif par construction) |
| `score_ventes`, `score_mandats` | Calculées normalement (activité des 12 derniers mois) |
| `score_visites` | **Visites réelles** : rendez-vous du client sur les propositions du mandat (ADR-049 §5) ; **note neutre de 50** si aucun. Une note de 0 sanctionnerait le chasseur comme s'il avait fait 18 visites ; « 0 visite » convertie donnerait 100 pour un ciblage non fait |

Sur l'exemple de Bruno (`.feature` 10), l'écart entre les deux lectures extrêmes est de 540 €
(5 799,60 € à 6 339,60 €). L'entrepôt analytique exclut ces actes de l'indice d'efficacité des visites
(KPI-3). La convention est une **décision de l'équipe (D12)**, présentée au Product Owner.

## 5 bis. Comptage des visites — révision de l'ADR-049 §5 (D10)

Portée ici à la demande de la revue (PR #14, point D) : l'ADR-049 reste « Accepté » pour le principe, la règle de
comptage en vigueur est celle-ci.

**Convention.** En base, une visite est un **fait par participant** : chaque personne présente
produit une ligne. Pour le score, en revanche, l'unité est le **rendez-vous** (D10) :

| Qui est présent | Rendez-vous | Compte dans `score_visites` ? |
| --- | --- | --- |
| Chasseur seul (reconnaissance) | 1 | **Non** : travail préparatoire, il porte la note d'avis |
| Chasseur + 1 acquéreur | 1 | Oui |
| Chasseur + couple d'acquéreurs | 1 | Oui (et non 2) |
| Acquéreur(s) seul(s), avec le vendeur ou son agent | 1 | Oui |

Le score de visites du chasseur (`score_visites`, pondération 25) se calcule en comptant les
**rendez-vous réalisés** où au moins un **acquéreur de la demande** est présent, sur les propositions du
mandat, sur les 12 mois glissants précédant l'acte :

```sql
SELECT count(DISTINCT (v.id_proposition, v.date_visite))
FROM visite v
JOIN proposition p        ON p.id_proposition = v.id_proposition
JOIN demande_acquereur da ON da.id_demande = p.id_demande
                         AND da.id_client = v.id_visiteur
WHERE p.id_mandat = :id_mandat
  AND v.realisee = true
  AND v.date_visite BETWEEN :date_acte - INTERVAL '12 months' AND :date_acte
```

- `count(DISTINCT …)` : un couple produit deux lignes pour un seul rendez-vous ; un `count(*)` le
  compterait deux fois (5 visites en couple → 10 → note ≈ 47 au lieu de 80).
- `demande_acquereur` plutôt qu'un test sur `client` : un chasseur peut aussi être client (cumul) ; il
  ne doit pas être compté comme acquéreur de la demande sur laquelle il travaille.
- Limite : `date_visite` n'a pas d'heure ; deux rendez-vous sur le même bien le même jour comptent pour un.
- Vente hors dispositif : même requête (visites réelles sur les propositions du mandat) ; note neutre de
  50 si elle renvoie 0 (§2.3).

Ce comptage est une règle du moteur de calcul (OLAP, `olap.f_nb_visites`), pas une contrainte d'intégrité :
la base ne porte pas d'unicité sur `(id_proposition, date_visite)`, ce qui interdirait les visites à plusieurs.

## 6. Conséquences

- **Positives** : conformité à l'énoncé sur les deux types de mandat ; aucune proposition fictive ; la garde
  sur l'exclusivité, absente de la v8.41 (T-DR-01), existe désormais pour ce chemin ; la cohérence
  rémunération ↔ mandat de l'acte est garantie pour les deux origines.
- **À reporter** :
  - **MCD/MLD (images)** : cardinalité acte–compromis 1,1 → 0,1 côté acte ; nouvelle association
    acte–mandat (0,1 / 0,1). Le diagramme Mermaid du dossier de modélisation est à jour ; les images PNG
    restent à régénérer.
  - **Entrepôt OLAP** : fait (dossier OLAP v1.1, `livrables/olap/`) : `fait_vente` lit `v_acte_mandat` ; bien et zone
    sont nuls pour une vente hors dispositif, `est_hors_dispositif` la distingue.
- **Point ouvert** : le notaire de l'acte hors dispositif n'est pas enregistré (il l'est sur le compromis
  pour la chaîne normale). Le justificatif reçu se joint en `document`.
- **Point ouvert, D18 (revue de la PR #14, point B)** : un mandat qui a un acte classique accepte encore un acte
  hors dispositif (`UNIQUE (acte.id_mandat)` ne couvre que les actes hors dispositif). Proposition : une chaîne de
  mandats aboutit à au plus un acte, garde à ajouter dans S24 et dans le trigger de l'acte sur compromis. En
  attente de la décision de l'équipe.
- **D13 — chaîne de renouvellement (mis en œuvre, réponse du PO simulée le 11/10, à confirmer).** L'exemple
  de bout en bout du `.feature` 10 (Bruno) date l'acte après l'échéance du mandat initial et calcule pourtant une
  rémunération, alors que la ligne 46 ferme le droit pour un mandat **non renouvelé** ; le §4 des règles de calcul
  dit « sauf renouvellement ». Lecture retenue : le droit se juge sur la **chaîne de renouvellement**
  (`f_mandat_en_vigueur_chaine`), le délai S₁ part du **mandat initial** (`f_mandat_initial_chaine`,
  exposé par `v_acte_mandat.id_mandat_initial`). Voir le journal des décisions métier, D13.

## 7. Tests (harnais `run_tests.py`)

| Test | Vérifie | Rejeté par |
| --- | --- | --- |
| T24 | acte avec compromis **et** mandat | `ck_acte_origine` |
| T25 | acte sans compromis **ni** mandat | `ck_acte_origine` |
| T26 | acte hors dispositif sur mandat **non exclusif** | trigger S24 |
| T27 | acte hors dispositif **après l'échéance** du mandat | trigger S24 |
| T28 | rémunération sur un autre mandat que celui de l'acte | trigger S25 |
| T29 | `vente_externe` sur un mandat exclusif | `ck_mandat_vente_externe` |
| T30 | acte hors dispositif sans source ni date de connaissance | `ck_acte_trace_hors_dispositif` |
| T31 | acte redaté après l'échéance d'un mandat non renouvelé, rémunération existante (re-vérification différée) | trigger S26 |
| T32 | mandat exclusif rendu non exclusif après un acte hors dispositif (re-vérification différée) | trigger S24 |
| T33 | acte hors dispositif sur le mandat initial alors qu'un renouvellement est en vigueur | trigger S24 |
| T34 | acte hors dispositif redaté après l'échéance de sa chaîne | trigger S24 |
| T35 | résiliation d'un mandat qui a déjà abouti à un acte | trigger S27 |
| T36 | rémunération alors que les honoraires de l'acte ne sont pas encaissés (D20) | trigger S28 |
| T37 | encaissement annulé sur un acte déjà rémunéré (D20) | trigger S28 |

Depuis la v8.43, le harnais exige le **code** de la garde (`trigger:S24`…) dans le message de rejet : un rejet par
un autre trigger ne fait plus passer le test (revue PR #14, point C).
| P8 (valide) | achat hors dispositif sous mandat exclusif : acte + rémunération acceptés, mandat dérivé `clos_succes` | — |
| P9 (valide) | cas de Bruno (D13) : vente après l'échéance du mandat initial, sous renouvellement ; rémunération sur le renouvellement ; initial « renouvelé », renouvellement « clos en succès » ; `id_mandat_initial` = mandat initial | — |

Plus un test d'anonymisation : un client à achat hors dispositif est conservé (« transactionnel »).

## 8. Rattachement RNCP40573

BC03 (intégrité déclarative : clé étrangère facultative, contrainte d'exclusion mutuelle, gardes
inter-tables par trigger), BC01 (décision tracée, options comparées), BC05 (données fiables pour l'entrepôt).
