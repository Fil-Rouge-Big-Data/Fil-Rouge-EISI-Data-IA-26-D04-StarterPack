# Dossier d'architecture cible — absorber la croissance

> **Livrable :** Phase 3 · BC01 — grille d'évaluation : « 1 schéma de composants + 1 matrice de décision + 2-3 pages ».
> **Rédaction :** Matthieu Barre (R) · **Approbation :** Thérèse Nguyen (A) — mêmes rôles dans les trois versions du RACI. **Consultés :** Alexandre Kechaf ; Angeline Gomez, auteure de la matrice et de la SWOT de croissance.
> **Version :** 1.2 du 15/10/2026 (v1.1 du 13/10) · **Statut :** proposé, à valider en atelier.
> **v1.2 :** revue d'Angeline Gomez sur la PR #17 (mesure du matching, raison de la réserve sur le partitionnement, test A1 bis), socle v8.43, instance de secours distinguée de la réplique de lecture (revue de Thérèse Nguyen sur l'étude).
> **Ce dossier assemble, il ne remplace pas.** Exigences : *Cahier des charges technique* v1.2 (Angeline Gomez). Décision chiffrée : *Matrice de décision — architecture de croissance*. Diagnostic : *SWOT — diagnostic d'architecture de croissance*. Vision : *SI cible / ImmoHunter* et *Graphique SI cible* (Alexandre Kechaf). Ce dossier ajoute le rôle de chaque composant, le comparatif des architectures demandé par l'énoncé, la réponse aux exigences, et des **mesures** sur le socle réel.

## 1. Schéma de composants

![Schéma de composants](schema-composants.png)

*Image `schema-composants.png`, source Mermaid versionnée : [`schema-composants.mmd`](schema-composants.mmd).* Vert : réalisé · jaune : maquetté · gris pointillé : à construire.

```mermaid
flowchart LR
    LEG["SI hérité + agences rachetées"] -- "reprise multi-source" --> P
    W["Site web"] --> API
    L["Logiciel métier"] --> API
    ING["Ingestion d'annonces"] --> API
    API["Backend / API REST (phase 4)"] --> P[("OLTP primaire · PostgreSQL · v8.43")]
    API --> OBJ[("Stockage objet S3 · médias")]
    P -- "réplication" --> SEC[("Instance de secours · bascule automatique")]
    P -- "réplication" --> R[("Réplique de lecture")]
    P -- "sauvegardes" --> B[("Sauvegardes hors site UE")]
    R --> MATCH["Matching quotidien"]
    R --> AF["Airflow nocturne"]
    AF --> DW[("Entrepôt OLAP")]
    DW --> BI["Tableaux de bord"]
    P --> V["Vue pseudonymisée"] -.-> IA["Services IA (phase 4)"]
```

Il reprend l'architecture imposée par le cahier des charges technique (§3 : l'API seul point d'accès, l'IA par une vue pseudonymisée) et y ajoute les composants de croissance de la matrice : instance de secours, réplique de lecture, sauvegardes, entrepôt alimenté depuis la réplique de lecture.

## 2. Composants

| Composant | Fonction | Dépend de | État au 15/10 | Preuve |
| --- | --- | --- | --- | --- |
| **OLTP primaire** | Source de vérité ; porte les règles métier | — | ✅ réalisé, v8.43 | 38 tables, 9 vues, 7 index ; 40 rejets et 8 cas valides testés, 4 scénarios de concurrence |
| **Reprise multi-source** | Charge l'existant et chaque agence rachetée | OLTP | ✅ réalisé | 39 tests de migration |
| **Entrepôt OLAP** | Indicateurs de pilotage hors production | vues d'état de l'OLTP | ✅ réalisé, dans la même instance pour l'instant | 11 tests, rapprochements OLTP/OLAP |
| **Stockage objet S3** | Fichiers hors base ; la base garde clé, URI, empreinte | table `document` | 🟡 maquette du 12/10 | [note maquette MinIO](note-maquette-minio.md) |
| **Instance de secours** | Reprend le service si le primaire tombe (bascule automatique) ; recopie tout, y compris les erreurs | primaire, hébergeur (offre haute disponibilité) | ⏳ cible, décision de la matrice ; chiffrée dans l'étude (§6.1-B) | — |
| **Réplique de lecture** | Sert les lectures lourdes (chargement de l'entrepôt, exports) sans toucher au primaire | primaire | ⏳ cible ; distincte du secours, à chiffrer à part (étude §6.1) | — |
| **Sauvegardes** | Protègent de l'erreur humaine, que l'instance de secours recopie | hébergeur UE | ⏳ cible | PCA/PRA (Thérèse) |
| **Airflow** | Orchestre le chargement nocturne | réplique de lecture, entrepôt | ⏳ cible | script de chargement déjà idempotent |
| **API, matching, IA** | Parcours applicatif et futur IA | OLTP, réplique de lecture, vue pseudonymisée | ⏳ phase 4 | — |

**Dépendance critique.** Tout repose sur l'OLTP primaire, point unique de défaillance (SWOT, Fa1). Instance de secours et sauvegardes sont deux parades qui ne se remplacent pas : une suppression erronée est recopiée sur le secours dans la seconde.

## 3. Comparatif des architectures demandé par l'énoncé

| Architecture | Principe | Bon cas d'usage | Chez nous | Preuve |
| --- | --- | --- | --- | --- |
| **OLTP / OLAP séparés** | Une base pour travailler, une pour analyser | Indicateurs lourds qui ralentiraient la production | **Retenu**, imposé par l'énoncé | entrepôt livré, PR #15 |
| **Indexation** | Des sommaires qui évitent de tout relire | Requêtes fréquentes et sélectives | **Retenu** : 7 index, chacun justifié par une requête (ENF-26) | note d'indexation ; DDL en v8.43 (PR #16) |
| **Réplication** | Une copie tenue à jour en continu | Continuité de service (instance de secours) ; lectures lourdes (réplique de lecture) | **Retenu** comme cible (option B) : le secours est chiffré, la réplique de lecture reste à chiffrer | matrice § 6 ; étude §6.1 |
| **Partitionnement** | Couper une table par intervalle | Requêtes et purges par période | **En réserve** : par période, reprise des clés ; par identifiant, deux unicités métier sortent de la base | test du 13/10, § 4 |
| **Sharding** | Répartir les données sur plusieurs serveurs | Écritures qui saturent un serveur | **Écarté** : écritures projetées faibles, ≈ 8 associations/s en hypothèse haute | SWOT de croissance § 4 |

## 4. Mesures

**Indexation.** Jeu valide : 20 000 mandats, 100 000 biens et annonces, 60 000 propositions, 120 000 visites. PostgreSQL 16.15, une seule session.

| Requête représentative | Sans index | Avec index | Avec index et réglage SSD |
| --- | --- | --- | --- |
| Mandats actifs d'un chasseur | 2 978 ms | 55 ms | 64 ms |
| Critères du barème sur 12 mois | 6,4 ms | 0,2 ms | 0,2 ms |
| Matching : annonces d'une zone et d'un budget | 48 ms | **61 ms** | **18 ms** |
| Rendez-vous de visite d'un mandat | 73 ms | 0,2 ms | 0,2 ms |

Le matching montre qu'un index ne suffit pas : avec le réglage par défaut, prévu pour des disques mécaniques, le planificateur l'ignore et garde le plan d'avant (même nœud racine, 2 616 puis 2 465 blocs lus) ; l'écart de 48 à 61 ms tient à la mesure, pas à l'index. Le constat utile est le troisième : avec le coût d'accès aléatoire réglé pour un SSD, le planificateur prend l'index et la requête tombe à 18 ms. Ce réglage est donc une **condition**, pas une option.

**Partitionnement**, testé sur le DDL réel avec deux découpes. Script rejouable, sans effet sur la base : [`test-partitionnement.sql`](test-partitionnement.sql).

| Vérification | Par identifiant UUIDv7 | Par période (ENF-04) |
| --- | --- | --- |
| Clé primaire actuelle | ✅ conservée (A1) | ❌ doit inclure la date (B1, B2) |
| Clés étrangères de 4 tables vers `proposition` | ✅ conservées (A1 bis) | ❌ la date doit y être recopiée : reprise de données (B3) |
| Règle « un bien proposé une fois tant que la proposition vit » (C8) | ❌ sort de la base (A2) | ❌ sort de la base (B4) |
| Dédoublonnage des annonces ingérées | ❌ sort de la base (A3) | ❌ sort de la base (B5) |
| Requête « propositions d'un mandat » | ❌ toutes les partitions lues (A4) | ❌ toutes les partitions lues (B6) |
| Requête par période de matching | ❌ toutes les partitions lues (A5) | ✅ une seule partition lue (B7) |

**Conséquence.** Les deux découpes échouent pour des raisons différentes. Par période, la clé primaire et les clés étrangères doivent inclure la date : c'est une reprise de données (B1 à B3). Par identifiant, clés et clés étrangères sont conservées (A1, A1 bis), mais les deux unicités métier — la règle C8 et le dédoublonnage des annonces — ne peuvent plus être portées par la base (A2, A3), et les requêtes par période lisent toutes les partitions (A5). Dans les deux cas, une garantie du socle quitte la base ; c'est cela, et pas la seule reprise de données, qui rend l'exigence ENF-04 (« partitionnables par période sans reprise de données ») non tenable avec le modèle v8.43. Les conditions 1 et 2 du § 6 de la matrice échouent : c'est la réponse au point ouvert PO-15 du cahier des charges.

## 5. Réponse aux exigences du cahier des charges technique

| Exigence | Réponse de l'architecture | État |
| --- | --- | --- |
| **ENF-01** sélection < 2 s sur 2 000 000 de biens, 20 req/s | Index de matching + réglage SSD ; lectures lourdes déportées sur une réplique de lecture (à chiffrer) | 🟡 18 ms mesurés sur 100 000 biens, en une session : encourageant, **pas une preuve** |
| **ENF-02** rémunération < 2 s sur 780 000 mandats | Index par chasseur et par mandat | 🟡 < 1 ms par critère sur 20 000 mandats, à prouver au volume |
| **ENF-03** 5 000 mandats/semaine, 70 000 annonces/jour | Une instance suffit en écriture ; lectures déportées | 🟡 hypothèse, non mesurée |
| **ENF-04** partitionnable sans reprise | — | ❌ non tenable, § 4 : **à amender** |
| **ENF-06, ENF-24** RPO/RTO, sauvegarde par nature | Instance de secours (bascule automatique) + sauvegardes hors site | ⏳ PCA/PRA |
| **ENF-07, ENF-08** intégrité par le SGBD | Contraintes et gardes dans la base | ✅ testé |
| **ENF-20** IA par vue pseudonymisée | Vue dédiée en lecture seule | ⏳ phase 4 |
| **ENF-25, ENF-29, ENF-38** médias hors base, liens signés, réversibilité | Stockage objet S3, empreinte en base | 🟡 maquette ; liens signés à faire |
| **ENF-26** chaque index justifié | Note d'indexation | ✅ |

**Ce que les mesures ne prouvent pas.** Le jeu est 20 fois plus petit que le stock de biens de référence (2 000 000) et 250 fois plus petit pour les propositions (15 000 000 sur 3 ans), sans charge concurrente. ENF-01 à ENF-03 restent à démontrer sur le jeu de recette au volume que le cahier prévoit (§ 6.1).

## 6. Améliorations proposées

| # | Amélioration | Porteur | Déclencheur |
| --- | --- | --- | --- |
| 1 | Régler le coût d'accès aléatoire pour SSD dans la configuration de l'instance | exploitation | dès la mise en production |
| 2 | Ne jamais lire la vue d'état des mandats en entier : 12,6 s sur 20 000 mandats. L'API filtre ; les listes complètes passent par l'entrepôt | backend | contrat d'API |
| 3 | Amender ENF-04 : partitionnement en réserve, accepté avec reprise de données s'il devient nécessaire | équipe, Angeline | atelier |
| 4 | Seuil de déclenchement du partitionnement : ENF-01 dépassée en recette au volume | Matthieu, Angeline | note 3V |
| 5 | Porter le jeu de volume aux grandeurs du cahier (§ 2) et y ajouter un test de charge | Matthieu | phase 3 |
| 6 | Stockage objet S3 managé européen, liens signés à durée limitée | équipe | choix de l'hébergeur |
| 7 | Chiffrer la réplique de lecture à part de l'instance de secours incluse dans l'offre haute disponibilité | Matthieu | étude v3.3, atelier |

## 7. Limites

Une seule session, pas de test de charge. Réplique, bascule et sauvegardes non testées : leurs objectifs relèvent du PCA/PRA. Le constat MinIO (image officielle plus librement distribuée, console retirée des versions gratuites) date du 12/10 et motive l'amélioration 6.
