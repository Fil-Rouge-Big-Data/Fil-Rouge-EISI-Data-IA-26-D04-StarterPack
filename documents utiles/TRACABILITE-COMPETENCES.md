# 🎯 Matrice de traçabilité des compétences — RNCP40573

> **Titre visé :** Expert en informatique et systèmes d'information (RNCP40573, niveau 7)
> **Bloc optionnel retenu :** BC05 — *Construire et implémenter des modèles de big data et d'IA* (seule option couverte ; BC04 et BC06 hors périmètre)
> **Blocs communs mobilisés :** BC01, BC02, BC03

Cette matrice relie **chaque compétence du référentiel** aux **étapes du projet fil-rouge** et aux **livrables** qui en font la preuve. C'est le document de référence pour :

* l'apprenant — savoir, à chaque étape, quelle compétence certificative il travaille ;
* le formateur — vérifier la couverture du référentiel ;
* le jury — retrouver la preuve de chaque compétence dans les livrables produits.

> **Rappel des modalités d'évaluation du titre** (identiques pour tous les blocs) : *mise en situation professionnelle reconstituée, production de livrable(s) et restitution orale* devant 2 professionnels externes + 1 représentant du certificateur.

---

## BC05 — Construire et implémenter des modèles de big data et d'IA (bloc cible)

| Compétence du référentiel (RNCP40573BC05) | Étape(s) du projet | Livrable(s) — preuve |
| --- | --- | --- |
| Analyser une problématique liée au traitement de *big data*, en évaluant les **volumes, la vélocité et la variété** des données, afin d'élaborer une stratégie coordonnée d'analyse. | Phase 3 (croissance) — dimensionnement « plusieurs milliers de mandats/semaine + international » | Note de dimensionnement 3V (volume/vélocité/variété) chiffrée |
| Concevoir et évaluer des **modèles statistiques et algorithmes d'apprentissage** (ML, *deep learning*…) en analysant les problématiques métier. | Phase 4 (IA) — matching bien/demande, scoring de faisabilité | Note de conception du modèle de matching + jeu de *features* documenté (conception, pas entraînement) |
| Optimiser l'exploitation des données en les **extrayant / transformant / chargeant**, en évaluant qualité et pertinence, dans le respect du **RGPD**. | Phase 2-3 — séparation OLTP/OLAP, alimentation du modèle décisionnel | Schéma analytique (OLAP) distinct + description de l'alimentation (script SQL ou code, aucun outil imposé) + note qualité des données |
| **Concevoir une base de données en analysant les exigences des traitements analytiques et d'IA**, afin d'optimiser les performances et de faciliter l'extraction de connaissances. | Phase 1-2 — MCD/MLD cible, migration, indexation | MCD complet + `migration.sql` + note d'indexation (EXPLAIN avant/après) |
| **Schématiser et concevoir un programme d'IA** répondant aux besoins fonctionnels du projet. | Phase 4 — chasseurs-IA, assistance au parcours | Schéma du programme d'IA (entrées/sorties, données mobilisées, points d'intégration au SI) |

---

## BC01 — Définir une stratégie de systèmes d'information (bloc commun)

| Compétence du référentiel (RNCP40573BC01) | Étape(s) du projet | Livrable(s) — preuve |
| --- | --- | --- |
| **Schématiser une cartographie du SI** en utilisant une méthode d'analyse de risques pour anticiper les besoins. | Phase 1 — audit de l'existant | Dossier d'audit : cartographie SI + registre des anomalies/risques |
| **Élaborer la stratégie informatique** à partir de la cartographie validée afin de proposer des axes d'évolution. | Phase 2 — préconisations besoin actuel | Note stratégique : axes d'évolution argumentés |
| **Comparer les différents types d'architectures** en identifiant leurs caractéristiques et cas d'usage. | Phase 3 — croissance/scalabilité | Dossier d'architecture : comparatif OLTP/OLAP, réplication, partitionnement, sharding |
| Analyser les composants d'architecture (fonctions, interactions, dépendances) pour évaluer la performance et proposer des améliorations. | Phase 3 | Dossier d'architecture : schéma de composants + points de performance |
| Comprendre avantages/inconvénients de chaque architecture (**performance, scalabilité, sécurité, éco-conception**) pour recommander la solution adaptée. | Phase 3 | Matrice de décision d'architecture (critères pondérés) |
| Présenter les préconisations SI aux parties prenantes, en mobilisant des solutions **pérennes et écoresponsables**. | Phase 2-3 + soutenance | Note d'éco-conception + restitution orale |

---

## BC02 — Piloter des projets informatiques (bloc commun)

| Compétence du référentiel (RNCP40573BC02) | Étape(s) du projet | Livrable(s) — preuve |
| --- | --- | --- |
| Analyser la problématique du client dans le cadre d'une transformation digitale et **formaliser une étude d'opportunité**. | Phase 1-2 | Étude d'opportunité |
| **Évaluer et organiser les fonctionnalités** requises en les priorisant selon importance et impact. | Phase 2 | Backlog priorisé (MoSCoW ou équivalent) |
| Constituer un **cahier des charges techniques respectant le RGPD** et intégrant l'**accessibilité PSH**. | Phase 2-4 | Cahier des charges technique + registre RGPD + note accessibilité |
| Décrire chaque fonctionnalité selon une **méthode de modélisation des processus métier**, en tenant compte de l'existant. | Phase 2-4 | Schémas BPMN / processus métier |
| **Rédiger une note de cadrage** (démarche, objectifs, délais, budget, ressources, qualité). | Phase 2 | Note de cadrage |
| **Planifier le projet** en décomposant les phases et allouant les ressources. | Toutes phases | Planning (Gantt) + jalons |
| Développer des **stratégies de mitigation des risques**. | Phase 1-3 | Matrice des risques + plan de mitigation + PCA/PRA |
| Coordonner et **gérer l'engagement des parties prenantes**. | Toutes phases | RACI + comptes rendus d'atelier |

---

## BC03 — Concevoir et développer une application informatique (bloc commun)

| Compétence du référentiel (RNCP40573BC03) | Étape(s) du projet | Livrable(s) — preuve |
| --- | --- | --- |
| **Concevoir une architecture applicative** selon la complexité du SI existant, afin de produire des **maquettes** validables. | Phase 4 — backend/API à reprendre de zéro | Dossier de conception applicative + maquettes |
| **Schématiser les processus métier** en tenant compte des contraintes, de l'existant et des vulnérabilités. | Phase 2-4 | Schémas de processus (parcours utilisateur → processus système) |
| Recommander un environnement informatique en intégrant les techniques de **réduction d'impact écologique**. | Phase 3-4 | Note d'environnement technique + volet green IT |
| **Justifier l'utilisation de patterns** (logiciel et classes) pour une architecture modulaire, réutilisable, maintenable. | Phase 4 | Dossier de conception : patterns justifiés |
| Développer des applications métier en appliquant des **pratiques de sécurité rigoureuses**. | Phase 4 | Extraits de code commentés + note sécurité |
| **Rédiger les scénarios de tests et les exécuter** pour détecter et corriger les erreurs. | Phase 4 | Plan de tests unitaires + fonctionnels + rapports d'exécution |
| Concevoir et réaliser un **suivi de la qualité** de l'application via un cycle automatisé. | Phase 4 | Pipeline CI (ou description) + indicateurs qualité |

---

## Exigences transverses (obligatoires, tous blocs)

Le référentiel RNCP40573 impose ces exigences dans **plusieurs blocs à la fois**. Elles ne sont pas optionnelles ; leur absence est rédhibitoire en jury.

| Exigence transverse | Blocs concernés | Livrable dédié |
| --- | --- | --- |
| **RGPD** — protection des données personnelles | BC02, BC03, BC05 | Registre de traitement (finalité, base légale, durée de conservation, données sensibles) |
| **Éco-conception / numérique responsable** | BC01, BC03, BC05 | Note d'éco-conception (dont arbitrage coût/rétention des sauvegardes) |
| **Accessibilité (PSH)** | BC02, BC03 | Note de préconisations d'accessibilité (espace acquéreur) |
| **Souveraineté & sécurité des données** | BC05 | Note sur l'ouverture des données à l'IA (accès, anonymisation, lecture seule) |

---

> ⚠️ **Chaque livrable devra pouvoir être défendu à l'oral.** Le jury peut demander à l'apprenant de justifier n'importe quel choix. Voir la section « Soutenance » du Readme principal et la `GRILLE-EVALUATION.md`.
