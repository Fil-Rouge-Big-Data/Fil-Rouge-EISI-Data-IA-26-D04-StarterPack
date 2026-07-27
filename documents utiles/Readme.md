# 📁 Documents utiles

> Boîte à outils du projet fil-rouge **Chasse immobilière** (RNCP40573). On trouve ici les **fiches de cours** (pour comprendre une notion), les **modèles à remplir** (canevas de vos livrables) et les **documents de pilotage de l'évaluation**. Chaque fiche indique à quel **bloc de compétences** et à quelle **phase** du projet elle se rattache.

## À quoi sert ce dossier

Trois types de documents cohabitent :

* les **fiches de cours** expliquent une notion (à quoi ça sert, comment faire) ;
* les **modèles** sont des canevas à dupliquer et compléter pour produire vos livrables ;
* les **documents de cadrage** relient votre travail aux compétences évaluées.

> 💡 Règle simple : on **lit** une fiche de cours, on **remplit** un modèle (dans une copie, pas dans l'original). Beaucoup de documents font les deux : une partie explication, une partie à compléter.

---

## 🧭 Méthodologie & pilotage de projet

| Document | Type | À quoi ça sert | Quand · Bloc |
| --- | --- | --- | --- |
| [`MODELE-SWOT.md`](./MODELE-SWOT.md) | Fiche + modèle | Diagnostic stratégique (Forces / Faiblesses / Opportunités / Menaces) avant une décision | Phase 1 & 3 · **BC01** |
| [`NOTE-DE-CADRAGE.md`](./NOTE-DE-CADRAGE.md) | Fiche + modèle | Lancer officiellement le projet : objectifs, périmètre, livrables, jalons, risques | Phase 2 · **BC02** |
| [`MATRICE-DECISION.md`](./MATRICE-DECISION.md) | Fiche + modèle | Choisir entre plusieurs options de façon rationnelle et traçable (critères pondérés) | Tout choix important · **BC01** |
| [`RACI.md`](./RACI.md) | Fiche + modèle | Clarifier qui fait quoi (Réalise / Autorité / Consulté / Informé) | Dès le lancement · **BC02** |
| [`JOURNAL-DE-DECISIONS.md`](./JOURNAL-DE-DECISIONS.md) | Fiche + modèle | Garder la trace de chaque choix structurant (format ADR) | En continu · **BC02** |

## 🗄️ Données : conception & modélisation

| Document | Type | À quoi ça sert | Quand · Bloc |
| --- | --- | --- | --- |
| [`MCD-MERISE.md`](./MCD-MERISE.md) | Fiche + modèle | **Modéliser les données** avec Merise (entités, associations, cardinalités, MCD→MLD→SQL) | Phase 2 · **BC05** |
| [`FICHE-COURS-OLTP-OLAP.md`](./FICHE-COURS-OLTP-OLAP.md) | Fiche de cours | **Comprendre** OLTP & OLAP : sigles, nature, quand/pourquoi, à qui présenter, méthode | À lire en premier · **BC05** |
| [`OLTP.md`](./OLTP.md) | Fiche + modèle | Modéliser la base **transactionnelle** (le métier au quotidien, normalisée) | Phase 2 · **BC05** |
| [`OLAP.md`](./OLAP.md) | Fiche + modèle | Modéliser la base **analytique** (entrepôt de pilotage, en étoile) et son alimentation | Phase 3 · **BC05** |

> ▶️ **Ordre de lecture conseillé (données)** : `MCD-MERISE.md` pour modéliser, puis `FICHE-COURS-OLTP-OLAP.md` (le pourquoi) → `OLTP.md` → `OLAP.md`.

## 🛡️ Notes transverses obligatoires

> Exigées par le référentiel dans plusieurs blocs à la fois. Leur absence est pénalisante en jury.

| Document | Type | À quoi ça sert | Quand · Bloc |
| --- | --- | --- | --- |
| [`REGISTRE-RGPD.md`](./REGISTRE-RGPD.md) | Fiche + modèle | Documenter les traitements de données personnelles (finalité, base légale, durée) | Phase 2-4 · **BC02/03/05** |
| [`NOTE-ECO-CONCEPTION.md`](./NOTE-ECO-CONCEPTION.md) | Fiche + modèle | Réduire l'empreinte (dont l'arbitrage des sauvegardes multi-fréquences) | Phase 3 · **BC01/03/05** |
| [`SOUVERAINETE-SECURITE-IA.md`](./SOUVERAINETE-SECURITE-IA.md) | Fiche + modèle | Sécuriser l'ouverture des données à l'IA (lecture seule, anonymisation) | Phase 4 · **BC05** |
| [`PCA-PRA-MIGRATION.md`](./PCA-PRA-MIGRATION.md) | Fiche + modèle | Continuité, reprise après sinistre, migration de l'ancien vers le nouveau SI | Phase 3 · **BC02** |

## 🛠️ Développement & qualité

| Document | Type | À quoi ça sert | Quand · Bloc |
| --- | --- | --- | --- |
| [`PLAN-DE-TESTS.md`](./PLAN-DE-TESTS.md) | Fiche + modèle | Prouver que le logiciel fait ce qu'il doit (tests unitaires & fonctionnels) | Phase 4 · **BC03** |

## 🎯 Cadre de l'évaluation

| Document | Type | À quoi ça sert | Quand |
| --- | --- | --- | --- |
| [`TRACABILITE-COMPETENCES.md`](./TRACABILITE-COMPETENCES.md) | Référentiel | Relier chaque **compétence** RNCP40573 à l'**étape** et au **livrable** qui la prouve | Tout au long — votre boussole |
| [`GRILLE-EVALUATION.md`](./GRILLE-EVALUATION.md) | Modèle | Calibrer la **profondeur** des livrables + s'**auto-évaluer** avant la soutenance | En continu |
| [`TRAME-SOUTENANCE.md`](./TRAME-SOUTENANCE.md) | Fiche + modèle | Structurer l'oral et anticiper les questions du jury | Fin de projet |

## 📚 Ressources de projet

| Document | Type | À quoi ça sert | Quand |
| --- | --- | --- | --- |
| [`GLOSSAIRE-METIER.md`](./GLOSSAIRE-METIER.md) | Fiche | Le vocabulaire de la chasse immobilière (mandat, honoraires, DPE…) | À consulter au besoin |
| [`ORGANISATION-DEPOT.md`](./ORGANISATION-DEPOT.md) | Fiche + modèle | Ranger le dépôt et adopter des conventions (nommage, Git) | Dès le lancement |

---

## Comment démarrer

1. **Lisez [`TRACABILITE-COMPETENCES.md`](./TRACABILITE-COMPETENCES.md)** : la vue d'ensemble qui relie tout le projet aux compétences évaluées.
2. **Parcourez le [`GLOSSAIRE-METIER.md`](./GLOSSAIRE-METIER.md)** pour maîtriser le vocabulaire du domaine.
3. **Mettez en place [`ORGANISATION-DEPOT.md`](./ORGANISATION-DEPOT.md)** et une [`RACI.md`](./RACI.md) dès le début.
4. **À chaque phase**, ouvrez les documents correspondants (voir le tableau « Quand »).
5. **Tracez vos choix** au fil de l'eau dans le [`JOURNAL-DE-DECISIONS.md`](./JOURNAL-DE-DECISIONS.md).
6. **Avant chaque rendu**, repassez sur [`GRILLE-EVALUATION.md`](./GRILLE-EVALUATION.md) ; **avant la soutenance**, sur [`TRAME-SOUTENANCE.md`](./TRAME-SOUTENANCE.md).

> ⚠️ Rappel : tout ce que vous produisez doit pouvoir être **défendu à l'oral**. Ces documents vous aident à travailler juste, mais c'est votre **compréhension** que le jury évaluera.

---

## Correspondance blocs ↔ documents

| Bloc | Documents concernés |
| --- | --- |
| **BC01** — Stratégie SI | SWOT, Matrice de décision, Éco-conception |
| **BC02** — Piloter des projets | Note de cadrage, RACI, Journal de décisions, PCA/PRA/Migration, RGPD, Grille |
| **BC03** — Concevoir & développer | Plan de tests, RGPD, Éco-conception |
| **BC05** — Big data & IA | MCD/Merise, Fiche OLTP & OLAP, OLTP, OLAP, RGPD, Souveraineté IA |
| **Transverse** | Traçabilité, Grille, Trame de soutenance, Glossaire, Organisation du dépôt |

> Le détail compétence par compétence est dans [`TRACABILITE-COMPETENCES.md`](./TRACABILITE-COMPETENCES.md).

---

## Suivi de complétude *(à cocher au fil du projet)*

- [ ] Note de cadrage rédigée
- [ ] RACI + organisation du dépôt en place
- [ ] Audit de l'existant (avec SWOT)
- [ ] MCD / MLD cible
- [ ] `migration.sql`
- [ ] Registre RGPD
- [ ] Dossier d'architecture + matrice de décision
- [ ] Schéma OLAP + alimentation
- [ ] Note d'éco-conception
- [ ] PCA / PRA / plan de migration
- [ ] Dossier de conception applicative + maquettes
- [ ] Plan de tests exécuté
- [ ] Note souveraineté / sécurité IA
- [ ] Journal de décisions tenu à jour
- [ ] Soutenance préparée