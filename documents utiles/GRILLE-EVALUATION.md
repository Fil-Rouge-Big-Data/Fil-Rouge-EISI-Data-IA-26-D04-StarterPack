# 📊 Grille d'auto-évaluation & calibrage des livrables

> Projet fil-rouge « Chasse immobilière » — RNCP40573 (cible BC05 + blocs communs BC01/BC02/BC03)

Ce document a deux fonctions :

1. **Calibrer la profondeur attendue** de chaque livrable (éviter aussi bien le bâclage que la sur-production) ;
2. Fournir une **grille d'auto-évaluation adossée aux compétences**, à remplir par le groupe avant la soutenance.

---

## 1. Calibrage des livrables

> Le titre s'évalue par **livrables + mise en situation + oral**, pas par volume. Un livrable court et juste vaut mieux qu'un dossier fleuve. Les formats ci-dessous sont des **cibles**, pas des minima à gonfler.

| Livrable | Format cible | Bloc principal |
| --- | --- | --- |
| Dossier d'audit de l'existant | Cartographie (1 schéma) + registre d'anomalies (tableau) + 1 à 2 pages d'analyse | BC01 |
| Note stratégique (axes d'évolution) | 2-3 pages | BC01 |
| Dossier d'architecture (croissance) | 1 schéma de composants + 1 matrice de décision + 2-3 pages | BC01 |
| Étude d'opportunité | 1-2 pages | BC02 |
| Note de cadrage | 3-4 pages | BC02 |
| Planning (Gantt) + jalons | 1 schéma + légende | BC02 |
| Matrice des risques + mitigation | 1 tableau | BC02 |
| RACI | 1 page | BC02 |
| MCD complet (cible) | 1 schéma + justifications des choix débattus | BC05 |
| Scripts SQL (`migration.sql`, requêtes) | Commentés, rejouables, transactionnels | BC05 |
| Note d'indexation (EXPLAIN avant/après) | 1 page + captures | BC05 |
| Schéma analytique (OLAP) + alimentation des données | 1 schéma + description (script SQL ou code) | BC05 |
| Note de dimensionnement 3V | 1-2 pages chiffrées | BC05 |
| Conception du modèle de matching + features | 2 pages (conception, pas entraînement) | BC05 |
| Schéma du programme d'IA | 1 schéma + description entrées/sorties | BC05 |
| Dossier de conception applicative + maquettes | Maquettes + patterns justifiés, 3-5 pages | BC03 |
| Plan de tests (unitaires + fonctionnels) | Scénarios + rapports d'exécution | BC03 |
| Registre RGPD | 1 tableau (finalité, base légale, durée, données sensibles) | transverse |
| Note d'éco-conception | 1-2 pages (dont arbitrage sauvegardes) | transverse |
| Note d'accessibilité PSH | 1 page | transverse |
| Note souveraineté/sécurité IA | 1 page | transverse |

---

## 2. Grille d'auto-évaluation par compétence

> Cotation suggérée : **NA** (non abordé) · **EC** (en cours) · **A** (acquis — preuve produite et défendable).

### BC05 — Big data & IA (bloc cible)

| Compétence | Preuve attendue | NA / EC / A |
| --- | --- | --- |
| Analyser 3V (volume, vélocité, variété) | Note de dimensionnement | ☐ |
| Concevoir/évaluer un modèle ML | Conception matching + features | ☐ |
| Extraction/transformation/chargement + qualité + RGPD | Schéma OLAP + description alimentation + note qualité | ☐ |
| Concevoir la base pour analytique/IA | MCD + migration + indexation | ☐ |
| Schématiser/concevoir un programme d'IA | Schéma du programme d'IA | ☐ |

### BC01 — Stratégie SI

| Compétence | Preuve attendue | NA / EC / A |
| --- | --- | --- |
| Cartographier le SI (analyse de risques) | Dossier d'audit | ☐ |
| Élaborer la stratégie SI | Note stratégique | ☐ |
| Comparer les architectures | Dossier d'architecture | ☐ |
| Analyser les composants d'architecture | Schéma de composants | ☐ |
| Arbitrer perf/scalabilité/sécurité/éco | Matrice de décision | ☐ |
| Présenter des solutions écoresponsables | Note éco + oral | ☐ |

### BC02 — Piloter des projets

| Compétence | Preuve attendue | NA / EC / A |
| --- | --- | --- |
| Étude d'opportunité | Document dédié | ☐ |
| Prioriser les fonctionnalités | Backlog priorisé | ☐ |
| CDC technique (RGPD + PSH) | CDC + registre RGPD + note PSH | ☐ |
| Modéliser les processus métier | Schémas BPMN | ☐ |
| Note de cadrage | Document dédié | ☐ |
| Planifier | Gantt + jalons | ☐ |
| Mitigation des risques | Matrice + PCA/PRA | ☐ |
| Engagement des parties prenantes | RACI + CR d'ateliers | ☐ |

### BC03 — Concevoir & développer

| Compétence | Preuve attendue | NA / EC / A |
| --- | --- | --- |
| Architecture applicative + maquettes | Dossier de conception | ☐ |
| Schématiser les processus métier | Schémas de processus | ☐ |
| Environnement + réduction d'impact éco | Note d'environnement | ☐ |
| Justifier les patterns | Dossier de conception | ☐ |
| Sécurité applicative | Code + note sécurité | ☐ |
| Scénarios de tests exécutés | Plan de tests + rapports | ☐ |
| Suivi qualité automatisé | Pipeline CI + indicateurs | ☐ |

### Transverses

| Exigence | Preuve attendue | NA / EC / A |
| --- | --- | --- |
| RGPD | Registre de traitement | ☐ |
| Éco-conception | Note dédiée | ☐ |
| Accessibilité PSH | Note dédiée | ☐ |
| Souveraineté/sécurité IA | Note dédiée | ☐ |

---

## 3. Travail en groupe, soutenance individuelle

> Le projet se **produit en groupe**, mais la **soutenance se passe seul** : chacun défend l'intégralité du travail devant le jury. Un livrable produit par un membre mais incompris des autres devient donc un risque de non-validation **pour ceux qui ne sauront pas l'expliquer**. Répartissez la production, mais **partagez la compréhension de tout**.
