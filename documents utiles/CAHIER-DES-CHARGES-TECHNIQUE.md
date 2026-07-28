# 📐 Cahier des charges technique — fiche + exemple

> **Fiche + modèle.** Le cahier des charges technique (CDCT) traduit la note de cadrage en **exigences techniques précises** : ce que le système doit faire (exigences fonctionnelles) et comment il doit le faire (exigences non fonctionnelles — performance, sécurité, RGPD, accessibilité…). Exigé au bloc **BC02** (« Constituer un cahier des charges techniques respectant le RGPD et intégrant l'accessibilité PSH »). À produire en Phase 2-4 — voir [`TRACABILITE-COMPETENCES.md`](./TRACABILITE-COMPETENCES.md).

## À quoi ça sert

La [`NOTE-DE-CADRAGE.md`](./NOTE-DE-CADRAGE.md) répond à « pourquoi ce projet, pour qui, avec quelles limites ? ». Le cahier des charges technique va plus loin : il **spécifie** ce que la solution doit faire et sous quelles contraintes, de façon assez précise pour que l'équipe technique (ou un prestataire) puisse concevoir, développer et **recetter** sans avoir à deviner. C'est le document que le jury peut vous demander d'ouvrir pour vérifier que vos choix d'architecture répondent bien à un besoin exprimé — pas l'inverse.

> 🧠 Une exigence mal écrite ne se teste pas. Une bonne exigence est **vérifiable** : on doit pouvoir dire, à la recette, si elle est remplie ou non (voir [`PLAN-DE-TESTS.md`](./PLAN-DE-TESTS.md)).

### Note de cadrage vs cahier des charges technique

| | Note de cadrage | Cahier des charges technique |
| --- | --- | --- |
| Répond à | Pourquoi, pour qui, dans quelles limites ? | Quoi précisément, et sous quelles contraintes ? |
| Niveau | Stratégique / projet | Fonctionnel et technique |
| Public | Commanditaire, parties prenantes | Équipe technique, prestataires, recette |
| Rédigé | En premier (Phase 2) | En s'appuyant sur elle (Phase 2, affiné en 3-4) |

---

## Les rubriques (modèle à remplir)

### 1. Contexte et objectifs
_(Résumé bref — renvoyer vers la note de cadrage plutôt que tout réécrire.)_

### 2. Périmètre fonctionnel
* **Dans le périmètre :** _(ex. API de gestion des mandats, calcul de la rémunération des chasseurs)_
* **Hors périmètre :** _(ex. le site vitrine, l'appli mobile)_

### 3. Exigences fonctionnelles
_(Ce que le système doit permettre de faire — un identifiant, un énoncé vérifiable, la source. Numérotez : EF-01, EF-02…)_

| ID | Exigence | Source / parcours concerné |
| --- | --- | --- |
| EF-01 | _…_ | _…_ |

### 4. Exigences non fonctionnelles
_(Comment le système doit se comporter. Une ligne par exigence, numérotée ENF-01, ENF-02…)_

| Catégorie | ID | Exigence | Critère de vérification |
| --- | --- | --- | --- |
| Performance | ENF-01 | _…_ | _…_ |
| Disponibilité | ENF-02 | _…_ | _…_ |
| Sécurité | ENF-03 | _…_ | _…_ |
| RGPD | ENF-04 | _(renvoyer au [`REGISTRE-RGPD.md`](./REGISTRE-RGPD.md))_ | _…_ |
| Accessibilité (PSH) | ENF-05 | _…_ | _…_ |
| Éco-conception | ENF-06 | _(renvoyer à [`NOTE-ECO-CONCEPTION.md`](./NOTE-ECO-CONCEPTION.md))_ | _…_ |
| Scalabilité | ENF-07 | _…_ | _…_ |

### 5. Contraintes techniques
_(SGBD imposés ou écartés, hébergement, langages, compatibilité avec l'existant des `fixtures/`, intégrations externes…)_

### 6. Architecture cible
_(Schéma haut niveau ou renvoi vers le dossier d'architecture ; renvoyer vers [`MCD-MERISE.md`](./MCD-MERISE.md), [`OLTP.md`](./OLTP.md), [`OLAP.md`](./OLAP.md).)_

### 7. Données et confidentialité
_(Nature des données traitées, données sensibles, renvoi au [`REGISTRE-RGPD.md`](./REGISTRE-RGPD.md).)_

### 8. Livrables attendus
_(Liste concrète — cohérente avec la note de cadrage et la traçabilité des compétences.)_

### 9. Planning et jalons
_(Renvoyer vers la note de cadrage plutôt que dupliquer, sauf si le CDCT a son propre planning technique.)_

### 10. Critères de recette / acceptation
_(À quoi reconnaît-on que chaque exigence est satisfaite ? Renvoyer vers [`PLAN-DE-TESTS.md`](./PLAN-DE-TESTS.md).)_

### 11. Annexes
_(Glossaire, documents de référence — [`GLOSSAIRE-METIER.md`](./GLOSSAIRE-METIER.md), schémas…)_

---

## Exemple rempli (extrait — refonte de l'API mandats & performance chasseurs)

> Extrait volontairement condensé : dans votre livrable, chaque rubrique ci-dessus est développée.

**1. Contexte et objectifs** — Le SI actuel ne permet pas de calculer la performance des chasseurs de façon fiable ni d'absorber la croissance prévue (voir note de cadrage). Objectif : une API backend qui gère mandats, biens, visites, offres et calcul de rémunération.

**2. Périmètre**
* Dans le périmètre : API de gestion des mandats (création, renouvellement, exclusivité), calcul automatisé de la performance et de la rémunération des chasseurs, exposition des données au futur espace acquéreur.
* Hors périmètre : le rendu graphique du site web, l'appli chasseur-IA (Phase future, hors fil-rouge).

**3. Exigences fonctionnelles (extrait)**

| ID | Exigence | Source / parcours concerné |
| --- | --- | --- |
| EF-01 | Le système doit permettre de créer un mandat exclusif ou non-exclusif, valide 6 mois, renouvelable. | Parcours particulier, étape 3 |
| EF-02 | Le système doit recalculer la performance du chasseur à chaque signature d'acte authentique. | Parcours chasseur, étape 12 |
| EF-03 | Le système doit recalculer la performance à la baisse en cas de renouvellement de mandat sans achat sous 6 mois. | Parcours chasseur, étape 13 |

**4. Exigences non fonctionnelles (extrait)**

| Catégorie | ID | Exigence | Critère de vérification |
| --- | --- | --- | --- |
| Performance | ENF-01 | Le calcul de performance d'un chasseur doit s'exécuter en moins de 2 secondes pour un historique de 500 mandats. | Test de charge sur jeu de données représentatif |
| Sécurité | ENF-03 | L'accès aux données de rémunération est restreint au chasseur concerné et à son manager. | Revue des droits + test d'accès croisé |
| RGPD | ENF-04 | Les coordonnées des particuliers ne sont conservées que pendant la durée du mandat + durée légale. | Voir `REGISTRE-RGPD.md` |
| Accessibilité | ENF-05 | L'espace acquéreur respecte le RGAA niveau AA sur les parcours de consultation d'offres. | Audit accessibilité |
| Scalabilité | ENF-07 | L'architecture doit absorber plusieurs milliers de mandats/semaine sans dégradation de la lecture. | Voir dossier d'architecture + matrice de décision |

**5. Contraintes techniques** — Réutiliser les schémas fournis dans `fixtures/` comme point de départ de la migration (ne pas repartir de zéro pour les données existantes) ; SGBD MariaDB/MySQL ou PostgreSQL au choix, à justifier en ADR.

**6. Architecture cible** — Séparation OLTP (transactionnel, mandats/biens/visites) et OLAP (pilotage de la performance), voir `ADR-001` dans [`JOURNAL-DE-DECISIONS.md`](./JOURNAL-DE-DECISIONS.md).

**7. Données et confidentialité** — Données personnelles des particuliers et chasseurs (coordonnées, IBAN pour rémunération) : catégorie sensible, voir `REGISTRE-RGPD.md`.

**8. Livrables attendus** — API documentée, dossier de conception applicative, schéma OLTP/OLAP, plan de tests exécuté.

**10. Critères de recette** — Chaque exigence fonctionnelle (EF-xx) correspond à au moins un cas de test dans le plan de tests ; une exigence sans test n'est pas recevable.

---

## Méthode pas à pas

1. **Partir de la note de cadrage** validée : ne pas repartir de zéro sur le contexte et les objectifs.
2. **Décliner chaque objectif** en une ou plusieurs exigences fonctionnelles vérifiables (EF-xx).
3. **Ajouter les exigences non fonctionnelles** transverses : performance, sécurité, RGPD, accessibilité, éco-conception, scalabilité — ne pas les oublier, elles sont explicitement exigées au BC02.
4. **Relier chaque exigence à sa preuve** : un cas de test dans le plan de tests, une entrée dans le registre RGPD, etc.
5. **Faire relire et valider** (dans ce projet : par le formateur jouant le commanditaire).

> ⚠️ À l'oral, le cahier des charges technique montre que vos choix d'architecture **répondent à un besoin exprimé et vérifiable** — pas l'inverse. Le jury vérifie ici votre maîtrise du BC02 (pilotage) autant que votre rigueur technique.
