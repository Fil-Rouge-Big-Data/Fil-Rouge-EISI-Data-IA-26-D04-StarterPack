# Étude d'opportunité — synthèse (2 pages)

> **Titre visé :** RNCP40573, bloc **BC02** (« formaliser une étude d'opportunité ») · incidences BC01, BC05.
> **R :** Matthieu Barre · **A :** Alexandre Kechaf · **C :** Angeline Gomez, Thérèse Nguyen, Product Owner (RACI v1.1).
> **Version :** 3.3 du 15/10/2026 — synthèse de deux pages, étude complète en annexe. Format cible de la grille d'évaluation : 1 à 2 pages.
> **Statut :** proposé — revue de l'A reçue le 13/10 (4 sur 5, ajustements intégrés), approbation formelle attendue.

## 1. Le problème

« Chasse Immo » (6 chasseurs indépendants, 18 mandats repris dont 11 actifs) travaille sur un SI hérité qui ne tient plus : **6 des 11 mandats actifs (55 %) ont dépassé l'échéance contractuelle de 6 mois fixée par l'énoncé** et sont contestables, la chaîne de valeur (bien, visite, offre, compromis, acte, honoraires) n'est **pas modélisée**, les critères de recherche sont du texte libre écrasé, les données personnelles sont en clair sans purge, et le backend est une **boîte noire sans mainteneur** (anomalie A11). La direction pilote à l'aveugle : aucun des cinq indicateurs demandés (entonnoir, délais et trésorerie, efficacité des visites, rentabilité et rémunération, performance sectorielle) n'existe.

**Coût de l'inaction : 151 400 € par an** — 45 000 € d'honoraires perdus (3 ventes contestées), 86 400 € de temps de prospection manuelle (6 chasseurs × 4 h/jour × 180 jours × 20 €/h), 20 000 € de provision pour risque CNIL. Hypothèses explicites, à mesurer.

## 2. Les options

Trois architectures comparées sur six critères pondérés (volumétrie 5, exploitation 5, analytique 4, international 3, IA 3, coût 3 ; grille de notation et sensibilité des poids en annexe §5.2) :

| Option | Principe | Score / 115 | Verdict |
|---|---|---|---|
| A — base unique indexée | tout sur une instance | 66 | écartée : contention entre saisie terrain et reporting, aucun espace pour l'IA |
| **B — OLTP + OLAP séparés** | socle transactionnel normalisé + entrepôt en étoile | **85** | **retenue** : couvre 3 à 5 ans, exploitable par une PME |
| C — sharding géographique | base distribuée par pays | 80 | ajournée (phase 3+) : exploitation 24/7 hors de portée, matching IA à réorganiser (non mesuré) ; ni prototypée ni chiffrée, ordre de grandeur en annexe §5.4 |

Le classement bascule vers C si le poids de l'exploitation descend à 2, ou si l'international pèse 5 avec une exploitation à 3 : dans les deux cas, il faut une capacité d'exploitation distribuée, visée en phase 3 avancée, d'où un report, pas un abandon. Le registre des risques (annexe §5.4) donne à chacun des 9 risques de B un traitement et un niveau résiduel visé, encore à atteindre, dont la non-adoption de l'outil par les chasseurs, traitée par un pilote (annexe §7.5) ; C en garde 3 élevés (exploitation distribuée, intégrité non distribuable, compétences rares).

## 3. Le coût et le retour

| | Montant | Base |
|---|---|---|
| Investissement initial (CAPEX) | **53 201 €** | 130 jours-homme à 350 €/j (coût complet d'un ingénieur junior interne) + 10 % de provision (13 j, dont 5 pour le pilote d'adoption) + environnements, audit de sécurité, conduite du changement |
| Exploitation an 1 (OPEX) | **12 268 €** | prix publics Scaleway Paris (bases managées HA 3 959 €, serveurs 724 €, stockage 73 €, licences Power BI pour 4 internes + supervision 972 €, IA 240 €, maintenance 1,5 j/mois 6 300 €) |
| Coût total an 1 | **65 469 €** | |
| Coût total 3 ans | **93 790 €** | OPEX ≈ 12 à 16 k€/an, montée en gamme de la base en an 3 |
| Gains estimés par an | **115 200 €** | **gains d'exploitation 70 200** : productivité des chasseurs 43 200 (2 h/jour libérées, à mesurer pendant le pilote) + pilotage du barème 27 000 · **risque évité 45 000** : honoraires sécurisés (3 ventes contestées, non mesurées) |
| **ROI an 1 / 3 ans** | **76 % / 268,5 %** | temps de retour estimé **6,8 mois d'exploitation** (≈ 12 mois après le GO avec une montée progressive des gains) |

**Solidité :** les gains d'exploitation couvrent seuls le coût de l'année 1 (ROI an 1 de +7,2 % sans le risque évité) ; le projet est remboursé dans l'année dès que **56,8 %** des gains se réalisent ; avec des gains divisés par deux, l'an 1 est déficitaire (−12 %) mais le ROI sur 3 ans reste **+84 %**. Réalisé par une ESN (530 à 730 €/j), le ROI an 1 tombe entre +26 % et −4 %, le ROI 3 ans reste positif. Seul le cumul des trois pires hypothèses (ESN au tarif haut, OPEX doublé, gains divisés par deux) rend le projet déficitaire sur 3 ans (−8,4 %) : c'est la limite de validité du business case.

**Périmètre chiffré :** la plateforme de données (socle, migration, entrepôt, contrat d'API, pré-matching). Le backend applicatif complet (API, authentification, droits, interfaces) n'est pas dans les 65 469 € : fourchette indicative de 60 à 90 j.h (21 à 32 k€), estimation par tâches à produire avant le GO. Les gains de productivité sont un gain de capacité d'indépendants, converti en ventes sous hypothèse ; les 27 000 € de pilotage sont une hypothèse non calculée (annexe §6.2).

**Mode de réalisation :** équipe interne avec au moins un ingénieur data recruté pour l'exploitation (traite le risque de perte de compétences, RB8, réplique du scénario A11) ; prestataire réservé aux expertises ponctuelles (audit de sécurité budgété), avec clause de transfert de compétences. L'option « tout apprentis » (21 081 €) est la moins chère mais exige un encadrement interne qui n'existe pas.

## 4. Ce qui est déjà prouvé

Le socle transactionnel de l'option B existe et passe sa recette : **v8.43** (38 tables, 9 vues, 7 index), fusionnée le 15/10/2026 — 40 rejets de contraintes, 8 cas valides, 12 sondes, 4 scénarios de concurrence à deux sessions, 39 tests de migration (52 lignes reprises, 73 anomalies journalisées), 8 tests RGPD, et l'entrepôt décisionnel (11 tests ; 17 avec la PR #19 en relecture). Le dossier d'architecture cible (v1.2 du 15/10) mesure les requêtes représentatives sous 65 ms sur 20 000 mandats et a testé le partitionnement. Hors périmètre chiffré : la volumétrie cible de l'énoncé (5 000 mandats par semaine), à établir par la note de dimensionnement 3V, qui conditionne la phase 3.

## 5. Recommandation

**GO pour la phase 2 selon l'option B, avec trois réserves** à lever avant la remise (points bloquants du cahier des charges v3.0) :

1. **PO-1** — acter le socle de référence par ADR et aligner la documentation ;
2. **PO-4** — compléter le registre RGPD, amorcé dans les notes transverses, et obtenir l'avis d'un délégué à la protection des données sur la base légale de la demande (PO-14) ;
3. **PO-11** — règles de rémunération : garde sur l'exclusivité du mandat (livrée en v8.42) et convention actée avec le Product Owner.

**Calendrier :** 14 semaines, quatre jalons avec critères d'acceptation, puis un pilote d'adoption avec deux chasseurs avant généralisation (annexe §7.1 et §7.5).

Décisions métier prises en équipe et présentées au Product Owner : journal des décisions D10 à D20. Deux questions lui sont posées (D13, mandat renouvelé ; D19, honoraires HT ou TTC), avec des réponses simulées le 11/10 en attendant les siennes ; D20 est actée, avec une question non bloquante (état « en litige » de l'acte) ; D18 est posée à l'équipe.

---

*Annexe : étude complète, mise à jour v3.3 (contexte, coût de l'inaction détaillé, SWOT, grille de notation, registre des risques, TCO, sources des prix, trajectoire de trésorerie, exploitation et continuité, planning et jalons, conduite du changement, annexe pédagogique Q1 à Q13).*
