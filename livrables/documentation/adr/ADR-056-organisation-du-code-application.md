# ADR-056 — Organisation du code de l'application : une application en couches, modulaire, exposée par une API REST (phase 4)

> **Statut :** Proposé · **Date :** 2026-10-15 · **Complète :** ADR-054 (style d'API et authentification, Angeline Gomez), ADR-025 et ADR-036 (frontière OLTP / OLAP), ADR-048 (états dérivés) · **Déclencheur :** questions du formateur au point du 14/10 (« l'architecture de l'API est-elle en place ? MVC, services ou microservices, pourquoi ? »), revue croisée du 14/10 (Thérèse Nguyen : le backend n'est ni conçu ni chiffré) · **Rédaction :** Matthieu Barre · **Décision attendue de :** l'équipe, en atelier.

## 1. Contexte

Le socle de données existe et est recetté : base v8.43 (38 tables, 9 vues, gardes S1 à S28), migration, entrepôt. **Aucune ligne du backend applicatif n'est écrite.** L'ADR-054 choisit le *style* de l'API (REST décrit par un contrat OpenAPI, authentification déléguée à un fournisseur d'identité) mais ne dit pas **comment le code est organisé** ni **combien d'applications** on déploie. L'étude d'opportunité v3.2 constate que ce backend est hors du périmètre chiffré (fourchette indicative : 60 à 90 jours-homme).

Contraintes qui pèsent sur le choix :

| Contrainte | Source |
| --- | --- |
| Équipe de quatre apprenants ; l'entreprise fictive n'a ni exploitation 24 h/24 ni ingénieur dédié : la dépendance à une seule personne s'est déjà produite (anomalie A11, backend « boîte noire ») | audit, étude §3, matrice de décision C4 |
| L'intégrité métier est portée par la base : clés étrangères composées (`fk_proposition_mandat`, `fk_remuneration_mandat`), contraintes d'exclusion des barèmes, déclencheurs S24 à S28 | ADR-045, ADR-049, ADR-053 |
| Les états ne sont pas stockés, ils se lisent dans des vues (`v_mandat`, `v_demande`, `v_compromis`) | ADR-048 |
| Les règles de parcours qui ne sont pas des règles d'intégrité restent applicatives (ex. D15 : pas d'offre sans note d'avis, avec dérogation tracée) | journal des décisions |
| Les clients de l'API sont hétérogènes : site des particuliers, application des chasseurs, scripts d'ingestion d'annonces | cahier des charges fonctionnel, ADR-054 |
| Volume projeté faible en écriture (≈ 8 associations par seconde en hypothèse haute) ; la charge est en lecture et en calcul (matching) | dossier d'architecture cible |

## 2. Options étudiées

Deux questions distinctes, souvent confondues : **comment ranger le code d'une application** et **combien d'applications on déploie**.

| Option | Ce que c'est | Pour | Contre |
| --- | --- | --- | --- |
| **A. Une application, en couches, découpée en modules métier** (« monolithe modulaire ») | Un seul déploiement, une seule base. Trois couches : interface (routes et contrat), services (règles de parcours), accès aux données. Un module par domaine : demande, mandat, vente, rémunération, référentiels, documents, pilotage | Un seul composant à exploiter, déployer, sauvegarder, surveiller ; l'intégrité reste dans la base ; une transaction par cas d'usage ; un module peut être extrait plus tard sans réécrire les autres | Discipline nécessaire pour que les modules ne s'appellent pas n'importe comment ; montée en charge globale, pas par morceau |
| **B. MVC classique avec vues rendues par le serveur** | Modèle, vue, contrôleur dans une même application ; les écrans sont produits par le serveur | Simple pour un site seul | Pas de contrat d'interface pour l'application des chasseurs ni pour les scripts d'ingestion ; le contrôle d'accès par objet (ADR-054) est plus difficile à tester ; les règles métier finissent dans les contrôleurs |
| **C. Microservices par domaine** | Plusieurs applications déployées séparément, chacune avec sa base, qui communiquent par le réseau | Équipes indépendantes, montée en charge par morceau, technologies différentes possibles | Plusieurs applications à exploiter sans équipe d'exploitation ; les clés composées et les déclencheurs entre mandat, proposition et rémunération ne peuvent plus être portés par une seule base : l'intégrité serait à recoder dans le code, avec des transactions distribuées ; coût de développement et de test bien supérieur ; reproduit, en pire, le risque A11 |

MVC n'est pas une alternative à A : c'est un découpage de la couche interface. A en reprend l'idée (séparer ce qui reçoit la requête de ce qui applique la règle) en remplaçant la vue par un contrat d'API.

## 3. Décision

**Option A.** Une application unique, organisée ainsi :

1. **Couche interface** : les routes REST et les schémas d'entrée et de sortie, générés en contrat OpenAPI (ADR-054). Elle ne contient aucune règle métier : elle valide la forme, vérifie l'identité et le droit d'accès à l'objet demandé, puis appelle un service.
2. **Couche services** : une fonction par cas d'usage (déposer une demande, signer un mandat, soumettre une proposition, saisir un acte hors dispositif, calculer une rémunération après encaissement). C'est là que vivent les règles de parcours applicatives (D15, dérogations tracées, notifications) et la transaction : un cas d'usage = une transaction.
3. **Couche accès aux données** : les requêtes SQL et la lecture des vues d'état. Elle ne recalcule jamais un état (ADR-048) et ne duplique aucune règle d'intégrité portée par la base : si la base refuse, le service traduit l'erreur (code S24, S27, S28…) en réponse d'API compréhensible.
4. **Modules métier**, un par domaine du MCD : demande, mandat, vente (proposition, visite, offre, compromis, acte), rémunération, référentiels (zones, barèmes), documents (stockage objet, ADR-042), pilotage. Règle de dépendance : un module n'accède aux données d'un autre que par son service, jamais par ses tables.
5. **Transverse** : authentification et autorisation (ADR-054), journalisation des accès, pseudonymisation pour l'exposition à l'IA (note souveraineté, schéma d'exposition).

Pile proposée, à confirmer en atelier parce qu'elle engage les compétences de l'équipe : **Python, FastAPI** (contrat OpenAPI produit automatiquement), **SQLAlchemy** pour l'accès aux données, **Alembic** pour les migrations de schéma. Ce sont les outils déjà cités par l'étude d'opportunité (poste « serveurs applicatifs ») et par le point d'avancement.

**Pourquoi A plutôt que C, en trois phrases.** Nous n'avons pas l'équipe pour exploiter plusieurs applications, et l'énoncé insiste sur une entreprise qui a déjà perdu un système faute de pouvoir le maintenir. Nos garanties les plus importantes sont des contraintes de base entre tables de domaines différents : les séparer en plusieurs bases les détruirait. Le besoin qui justifierait des microservices, plusieurs équipes livrant sans s'attendre ou une partie à faire monter en charge seule, n'existe pas aujourd'hui ; le découpage en modules garde cette porte ouverte.

## 4. Conséquences

- **Tests.** Les scénarios des user stories deviennent des tests d'API sur le contrat OpenAPI (demande de la revue du 14/10) ; les tests de la base restent en place. Une règle d'intégrité est testée dans la base, une règle de parcours dans les services, jamais les deux.
- **Déploiement.** Un conteneur applicatif, l'instance PostgreSQL et le stockage objet : c'est le schéma de composants du dossier d'architecture cible, option B. L'extraction vers l'entrepôt lit la réplique, pas l'application.
- **Chiffrage.** Le backend reste hors des 65 469 € de l'étude ; une estimation par tâches est à produire par module avant le GO de la phase 4 (étude v3.2, §6.1).
- **Conditions de réexamen.** Plusieurs équipes de développement ; un module dont la charge diverge (le matching est le candidat) ; une obligation de localisation par pays. Le matching pourrait alors sortir en service à part sans toucher aux autres modules, parce que la couche services l'aura déjà isolé.

## 5. Ce qui n'est pas décidé ici

Le style d'API et l'authentification (ADR-054, à valider) ; le fournisseur d'identité ; l'hébergement du stockage objet (matrice, « à décider ») ; le dimensionnement (note 3V).

## 6. Rattachement RNCP40573

BC01 — comparer des architectures applicatives (en couches, MVC, microservices) et recommander selon le contexte : équipe, exploitation, intégrité, charge. BC03 — l'intégrité reste portée par le SGBD, l'application ne la duplique pas.
