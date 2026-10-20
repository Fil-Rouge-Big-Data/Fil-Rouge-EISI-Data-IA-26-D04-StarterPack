# 📊 Étude d'Opportunité — Transformation Digitale & Refonte du SI

> **Titre visé :** Expert en informatique et systèmes d'information — **RNCP40573** (Niveau 7)  
> **Bloc de compétences cible :**  
> * **BC02 (Cœur) :** *« Analyser la problématique du client dans le cadre d'une transformation digitale et formaliser une étude d'opportunité. »*  
> * **Incidences directes :** **BC01** (Stratégie d'évolution et cartographie du SI) et **BC05** (Bases de données analytiques, décisionnel et IA).  
> **Phase du projet :** Phase 2a — Cadrage stratégique, audit & arbitrage d'investissement  
> **Rédigé par :** Matthieu Barre (R) · **Approbation :** Alexandre Kechaf (A) · **Consultés :** Angeline Gomez, Thérèse Nguyen, Product Owner (C) — *RACI v1.1 du 01/09/2026*  
> **Version :** 3.3 du 15/10/2026 — revues de Thérèse Nguyen (14/10) et d'Angeline Gomez (PR #17, 14/10) intégrées : formulations ramenées au niveau des preuves, périmètre chiffré explicité, références alignées sur le socle v8.43 (voir §10, Historique des versions)  
> **Date de référence projet :** 25 juillet 2026  
> **Statut :** Proposé — en attente d'approbation par l'Accountable (Alexandre Kechaf)  
> **Documents de référence :** Cahier des charges technique v3.0 (08/10/2026) · Socle OLTP v8.43 (PR #16 fusionnée le 15/10/2026 ; recette initiale v8.41 rejouée le 09/10/2026) · RACI v1.1 (01/09/2026)  

---

### Gouvernance du livrable (extrait du RACI v1.1)

**Rôles sur la présente étude :**

| Rôle RACI | Personne | Responsabilité sur ce livrable |
|---|---|---|
| **R** — Réalise | **Matthieu Barre** | Rédaction de l'étude, chiffrage, analyse multicritère et de sensibilité |
| **A** — Approuve | **Alexandre Kechaf** | Validation de l'étude avant remise |
| **C** — Consultée | **Angeline Gomez** | Diagnostic SWOT, cahier des charges technique, RGPD |
| **C** — Consultée | **Thérèse Nguyen** | Continuité d'activité, recette, cahier des charges technique |
| **C** — Consulté | **Jeff** (Product Owner, formateur) | Expression des besoins, arbitrages d'affaires, décision GO / NO-GO |
| **I** — Informé | Jury | — |

**Livrables amont mobilisés par l'étude :**

| Livrable (RACI v1.1) | R | A | Utilisé en |
|---|---|---|---|
| Audit de l'existant | Alexandre Kechaf | Matthieu Barre | §2.2, §3 |
| Cartographie du SI hérité | Matthieu Barre, Alexandre Kechaf | Angeline Gomez | §2.2 |
| Analyse de risques EBIOS RM | Matthieu Barre | Thérèse Nguyen | §2.2, §7.1 |
| Dossier SWOT | Angeline Gomez | Matthieu Barre | §4 |
| Cahier des charges technique | Angeline Gomez | Thérèse Nguyen | §2.2, §2.4, §2.5 |
| Dossier d'architecture cible & matrice de décision | Matthieu Barre | Thérèse Nguyen | §5 |
| PCA/PRA & stratégie de sauvegarde | Alexandre Kechaf | Thérèse Nguyen | §6.4 |
| Contrôles & recette migration | Matthieu Barre | Thérèse Nguyen | §2.4, §7.2 |

*R = Réalise (Responsible), A = Approuve (Accountable), C = Consulté (Consulted), I = Informé (Informed).*

---

## Sommaire

1. Synthèse exécutive & décision d'investissement (GO / NO-GO)
2. Contexte métier & définition de la problématique client
   * 2.1 Le modèle économique de « Chasse Immo »
   * 2.2 La rupture opérationnelle du système d'information hérité
   * 2.3 Les 5 besoins décisionnels clés exprimés par la direction & le Product Owner
   * 2.4 État des points ouverts du cahier des charges technique (v3.0, §15)
   * 2.5 Responsabilité sociétale & environnementale (inclusion PSH & éco-conception)
3. Le chiffrage du coût de l'inaction (*Cost of Inaction — CoI*)
4. Diagnostic stratégique de l'existant — matrice SWOT consolidée
   * 4.1 Les enseignements des stratégies croisées
5. Analyse comparative des 3 scénarios d'évolution
   * 5.1 Définition technique des trois architectures candidates (A, B, C)
   * 5.2 Tableau d'évaluation multicritère des options
   * 5.3 Pourquoi l'option B est la décision rationnelle
   * 5.4 Registre des risques des options B et C
6. Évaluation économique, budgétaire & rentabilité (business case & ROI)
   * 6.1 Investissement requis, modèle TCO sur 3 ans & stratégie d'approvisionnement
   * 6.2 Gains financiers directs & indirects (bénéfices attendus)
   * 6.3 Rentabilité, point mort & analyse de sensibilité
   * 6.4 Processus d'exploitation, continuité d'activité & gouvernance IT
7. Trajectoire de mise en œuvre, risques projet & facteurs clés de succès
   * 7.1 Découpage en phases, planning sur 14 semaines et jalons
   * 7.2 Facteurs clés de succès, consolidation du modèle et gestion des risques projet
   * 7.3 Stratégie de bascule & synchronisation au fil de l'eau (delta load)
   * 7.4 Cadrage de périmètre : anticipation de l'« armoire de dossiers » (GED numérique)
   * 7.5 Conduite du changement et adoption par les chasseurs
8. Conclusion & recommandation formelle au comité de direction
9. Annexe pédagogique — grille d'évaluation & soutenance RNCP7
10. Historique des versions

---

## 1. Synthèse exécutive & Décision d'investissement (GO / NO-GO)

La société **« Chasse Immo »**, spécialisée dans l'intermédiation et la recherche immobilière sur-mesure pour acquéreurs particuliers, connaît une hyper-croissance soutenue. Cependant, son Système d'Information hérité constitue aujourd'hui un **goulet d'étranglement critique** qui menace directement la rentabilité et la survie juridique de l'entreprise :

* **Un constat de rupture avéré :** 6 des 11 mandats actifs (55 %, sur 18 mandats repris) ont dépassé l'échéance contractuelle de 6 mois fixée par l'énoncé et sont contestables, les données de recherche sont enfermées dans du texte libre inexploitable, et le backend existant est une « boîte noire » sans code source ni mainteneur (Anomalie A11).
* **Un pilotage à l'aveugle :** La direction générale et le Product Owner ne disposent d'aucun indicateur fiable sur leur funnel d'acquisition (`Demande` → `Mandat` → `Visite` → `Offre` → `Vente` → `Honoraires`), ni sur la performance réelle de leurs 6 chasseurs.
* **L'arbitrage stratégique :** L'analyse croisée démontre qu'un rafistolage du modèle hérité coûterait aussi cher qu'une refonte tout en pérennisant la dette technique. La faible volumétrie initiale — **52 lignes** (10 secteurs, 24 utilisateurs, 18 mandats), sur lesquelles la reprise journalise **73 anomalies** — offre une opportunité historique rare : **reconstruire intégralement le socle de données en une seule transaction de migration**, en traçant chaque anomalie.
* **Le Business Case :** Un coût total de possession la première année de **65,5 k€** (investissement de 53,2 k€, dont 4,6 k€ de provision pour risques, + exploitation de 12,3 k€ aux prix publics d'un hébergeur français) génère des gains estimés à **117 k€ par an** et dégage un **retour sur investissement (ROI) de 78,7 % la première année, avec un temps de retour estimé à 6,7 mois d'exploitation, soit environ 12 mois après le GO avec une montée progressive des gains**, puis de **274,2 % sur 3 ans**. **Même avec des gains divisés par deux, ou réalisé par une ESN, le projet reste rentable sur 3 ans** (analyse de sensibilité, §6.3).

> **Décision soumise au Comité de Direction : AVIS « GO » AVEC RÉSERVES**  
> Approbation du lancement de la **Phase 2 (socle relationnel cible et pipeline de migration)** selon l'**Architecture B (séparation OLTP transactionnel + OLAP décisionnel)**, retenue avec **85 points sur 115** (§5.2) — sous réserve de lever les **trois points bloquants** du cahier des charges technique v3.0 avant la remise : référence du modèle (PO-1), registre RGPD (PO-4) et règles de rémunération (PO-11). Voir §2.4 et §8.

---

## 2. Contexte métier & Définition de la problématique client

### 2.1 Le modèle économique de « Chasse Immo »
L'activité repose sur un mandat de recherche confié par un particulier acquéreur à un chasseur immobilier dédié. Le modèle de revenu est fondé sur des honoraires au succès (forfait fixe + pourcentage du montant de l'acquisition), perçus lors de la signature de l'acte authentique chez le notaire instrumentaire.

La rémunération des chasseurs (statut d'agents commerciaux indépendants RSAC) est modulée selon un barème de performance multi-critères :
1. Le délai de transformation entre la signature du mandat et l'acte notarié (arrondi à la semaine inférieure).
2. Le caractère exclusif ou non du mandat.
3. Le volume de ventes réussies.
4. Le ratio de mandats signés.
5. Le nombre de visites préalables nécessaires à la conclusion de la vente (plus le nombre de visites est faible, plus la prime de pertinence augmente).

### 2.2 La rupture opérationnelle du Système d'Information hérité
Comme l'a formulé avec lucidité le commanditaire :  
> *« Il semblerait que, malgré le grand soin apporté lors de sa création, l'organisation actuelle de la base de données ne permette pas de gérer totalement nos besoins métiers. »*

L'audit détaillé de l'existant (Livrable 1 — Cartographie SI hérité) et la confrontation aux exigences du **Cahier des charges technique v3.0 (standard ISO/IEC/IEEE 29148)** mettent en évidence **cinq ruptures fonctionnelles et réglementaires majeures** :
1. **La disparition de la chaîne de valeur (Anomalie A08 / EF-29 à EF-42) :** La base de données ne modélise ni les biens immobiliers, ni les visites, ni les propositions, ni les compromis de vente, ni les actes notariés, ni les décomptes de commissions. Le SI est incapable de tracer ce qui génère le chiffre d'affaires.
2. **L'aveuglement décisionnel & absence de pilotage (EF-43 à EF-45, EF-47) :** Aucun calcul de KPI n'est automatisé. La direction est incapable de mesurer le taux de transformation de son funnel commercial (`Demandes` → `Mandats` → `Visites` → `Offres` → `Ventes` → `Honoraires`) ni de justifier le calcul de la part variable reversée aux chasseurs selon le barème de performance.
3. **Le verrouillage de l'Intelligence Artificielle (Anomalies A03 & A10c / EF-18) :** Les critères de recherche des acquéreurs sont stockés dans un champ texte libre non structuré (`description_recherche`), systématiquement écrasé sans aucun historique d'affinage. Aucun algorithme de matching automatique d'annonces ne peut être branché sur une telle structure.
4. **L'insécurité réglementaire et légale (Loi Hoguet, LCB-FT, RGPD / EF-06 à EF-09) :** Absence de mentions obligatoires d'exercice (carte T, RCP, numéro RSAC, garantie financière), aucun registre séquentiel infalsifiable, absence de traçabilité LCB-FT sur l'origine des fonds, et données patrimoniales intimes en clair sans consentement horodaté ni purge (A10a, A10b).
5. **Le risque de défaillance fatale (Anomalie A11 / SPOF) :** L'API en production est une boîte noire non documentée, dont le développeur est en arrêt longue durée. Toute montée en charge brutale ou incident de sécurité conduirait à l'arrêt total de l'activité.

---

### 2.3 Les 5 Besoins Décisionnels Clés exprimés par la Direction & le Product Owner

L'entretien de cadrage avec le Product Owner (Jeff) a été déterminant : au-delà de l'expression des besoins de pilotage, il a permis de recentrer le périmètre métier de la plateforme. Alors que les ébauches initiales souffraient d'un modèle sur-étendu et dispersé, les arbitrages du Product Owner ont recentré le MCD/MLD sur le cœur de valeur de Chasse Immo, donnant naissance à l'architecture cible affinée (v7, consolidée depuis jusqu'au socle v8.43). Cet échange a également formalisé l'entonnoir décisionnel et les 5 indicateurs fondamentaux qui devront être restitués sous **Power BI** grâce au datamart OLAP en Phase 3 :

```
BESOINS MÉTIER (Pilotage & Croissance)
       ▼
Questions clés de la Direction Générale
       ▼
5 Indicateurs Clés (KPI)
       ▼
Dimensions d'analyse (Temps, Secteur, Chasseur)
       ▼
Modèle OLAP en étoile (Phase 3)
       ▼
Tableaux de Bord Power BI (Direction & Équipe)
```

| Réf. KPI | Libellé de l'Indicateur | Question métier à laquelle il répond | Impact décisionnel direct |
|---|---|---|---|
| **KPI-1** | **Taux de conversion du funnel commercial** | *« Combien de demandes se transforment en mandats, en visites, en offres et en actes notariés ? »* | Identification immédiate des déperditions entre étapes et ajustement du ciblage commercial. |
| **KPI-2** | **Délai moyen de conversion & Trésorerie prévisionnelle** | *« Quand allons-nous encaisser les honoraires en attente chez les notaires ? »* | Anticipation des flux financiers à M+3 en tenant compte du décalage incompressible de 10 à 14 semaines entre compromis et acte authentique. |
| **KPI-3** | **Indice d'efficacité des visites (Pertinence)** | *« Combien de visites nos chasseurs organisent-ils avant de conclure une vente ? »* | Mesure de la justesse de qualification du besoin (moins il y a de visites inutiles, plus la marge opérationnelle est élevée). |
| **KPI-4** | **Rentabilité nette & Rémunération variable chasseur** | *« Quelle marge nette dégage chaque chasseur et quel montant variable lui est dû ? »* | Calcul automatisé et transparent de la commission via la table `remuneration_chasseur`, dont toutes les composantes sont figées au jour de l'acte (ADR-049). |
| **KPI-5** | **Performance sectorielle & Internationale** | *« Quels sont les secteurs les plus dynamiques et où ouvrir de nouveaux bureaux ? »* | Pilotage de l'activité sur les 10 secteurs géographiques actuels et arbitrage sur les 9 pays cibles de l'extension Phase 3. |

---

### 2.4 État des points ouverts du cahier des charges technique (v3.0, §15)

Le **cahier des charges technique v3.0** du 08/10/2026 (R : Angeline Gomez · A : Thérèse Nguyen) recense **17 points ouverts, dont 3 bloquants**. L'Option B n'a pas vocation à tous les « résoudre » : elle en clôt certains par construction, en rend d'autres traitables, et en laisse quelques-uns à l'arbitrage de l'équipe et du Product Owner. Le tableau ci-dessous en donne l'état au 09/10/2026, en indiquant pour chacun l'apport de l'option retenue.

| Réf. | Point ouvert (CDC v3.0) | Statut CDC | Apport de l'Option B / état constaté |
|---|---|---|---|
| **PO-1** | Référence du modèle : la v8.4 est à acter par un ADR ; incohérences documentaires (36, 37 ou 38 tables selon les documents) | 🟡 En cours | Le socle existe et fonctionne : la recette du 09/10/2026 confirmait **38 tables et 8 vues** (v8.41) ; le socle fusionné le 15/10/2026 est la **v8.43** (38 tables, 9 vues, 7 index), documentée par la page « Modèle de données » et le registre ADR (v1.3). Reste l'acte formel de la version de référence en atelier. |
| **PO-2** | Chaîne de vente et barèmes | ✅ Clos (sous réserve de PO-1) | Modélisés : `proposition` → `offre_acquisition` → `compromis` → `acte` → `remuneration_chasseur`, barèmes par tranches (`tranche_bareme`). |
| **PO-3** | Deux choix sans ADR versé : PostgreSQL et Python pour la reprise | Ouvert | Le §5.2 justifie chaque pondération de l'arbitrage d'architecture, définit une grille de notation et teste la sensibilité du classement. Le choix du SGBD et du langage reste à verser en ADR. |
| **PO-4** | Notes transverses et registre RGPD à compléter | 🔴 Bloquant | Hors périmètre de l'étude : livrable de gouvernance (registre RGPD — A : Angeline Gomez). |
| **PO-5** | Échéance du mandat divergente de l'énoncé | ✅ Clos (ADR-037) | État du mandat dérivé dans la vue `v_mandat` (ADR-030, ADR-048), sans statut stocké. |
| **PO-6** | International : pays et devise portés, conformité par pays différée, langue non modélisée | Partiel | Le socle porte pays et devise (§6.2-5). Langue et conformité par pays restent à modéliser en phase 3. |
| **PO-7** | Numérotation des phases : 5 dans la note de cadrage, 4 dans l'énoncé | Ouvert | L'étude suit la note de cadrage ; la correspondance avec l'énoncé est donnée au §7.1. |
| **PO-8** | « Zéro déperdition » intenable ; critère tenable : « zéro perte non tracée » | À acter | L'étude adopte « zéro perte non tracée » (§7.3). La reprise v8.41 journalise 73 anomalies. |
| **PO-9** | Preuve d'exécution non rejouable | ✅ Clos (sous réserve de PO-1) | Recette rejouée le 09/10/2026 sur la v8.41 : 48 tests de migration, harnais de 23 rejets + 4 cas valides, 12 sondes d'intégrité, 7 tests RGPD — tous verts. Rejouée le 15/10/2026 sur la v8.43 : 40 rejets + 8 cas valides, 12 sondes, 4 scénarios de concurrence à deux sessions, 8 tests RGPD. |
| **PO-10** | Authentification et sécurité au niveau ligne (RLS) | Ouvert | Aucune politique RLS dans la v8.41 : prévue avec l'API en phase 4. |
| **PO-11** | Règles de rémunération en écart avec l'énoncé | 🔴 Bloquant | **Apport de la recette (test T-DR-01, 09/10/2026)** : le schéma v8.41 accepte la rémunération sous mandat **exclusif** pour un bien trouvé par le client (conforme à l'énoncé), mais l'accepte **aussi** sous mandat **non exclusif** (non conforme au §4 des règles de calcul). Le défaut réel est l'absence de garde sur l'exclusivité. Arbitrage à porter au Product Owner. |
| **PO-12** | Anomalie A06 : mandat rattaché par reconstitution, « à valider avant production » | Ouvert | À trancher : quarantaine ou reconstitution validée. |
| **PO-13** | Motif « arrêt » des indisponibilités (donnée de santé possible) | Ouvert | À remplacer par une catégorie neutre. |
| **PO-14** | Base légale du traitement de la demande | Ouvert | À requalifier en preuve d'information (mesures précontractuelles), le consentement marketing restant séparé. Avis d'un délégué à la protection des données recommandé avant la mise en production. |
| **PO-15** | Partitionnement compatible avec les clés | Ouvert (phase 3) | Conditionne l'absorption de volumétrie notée 4/5 au §5.2. |
| **PO-16** | Estimation pré-acte des honoraires | Ouvert | Arbitrage du Product Owner. |
| **PO-17** | Blocage ou signalement d'un mandat hors validité d'habilitation | Ouvert | La v8.41 signale ; un blocage applicatif reste à décider. |

**Bilan :** 3 points clos, 3 bloquants, 11 ouverts, partiels ou à acter. **Aucun des points bloquants ne remet en cause le choix de l'Option B** : deux conditionnent la remise des livrables (PO-1, PO-4), le troisième la conformité de la rémunération (PO-11). D'où la recommandation d'un **GO avec réserves** (§8).

---

### 2.5 Responsabilité Sociétale & Environnementale (Inclusion PSH & Éco-conception)

La transformation digitale ne se limite pas à un chantier technique : elle intègre dès sa conception les exigences modernes de responsabilité sociétale et environnementale :
* **Accessibilité numérique PSH (ENF-21 à ENF-23) :** Conformité au **RGAA 4.1** (critères issus des WCAG 2.1, niveaux A et AA) pour l'espace acquéreur : contraste minimal de 4,5:1, parcours entièrement utilisable au clavier, alternatives textuelles pour les photos et transcriptions ou sous-titres pour les avis audio et vidéo des chasseurs.
* **Éco-conception & Sobriété numérique (ENF-24 à ENF-26) :** Fréquence de sauvegarde arbitrée par nature de donnée (ENF-24), médias stockés hors base, une seule fois, et référencés par URI (ENF-25), index justifiés chacun par une requête, avec préférence pour les index partiels (ENF-26). L'isolation des requêtes décisionnelles hors de l'OLTP complète ce dispositif.

---

## 3. Le Chiffrage du Coût de l'Inaction (*Cost of Inaction - CoI*)

Conserver le SI hérité ou se limiter à une maintenance palliative (« Faire avec l'existant ») ne représente pas une économie de moyens, mais une **perte financière et juridique continue** pour l'entreprise.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        CHIFFRAGE ANNUEL DU COÛT DE L'INACTION                          │
└───────────────────────────┬────────────────────────────────┬───────────────────────────┘
                            │                                │
             ┌──────────────┴──────────────┐  ┌──────────────┴──────────────┐
             ▼                             ▼  ▼                             ▼
      PERTE DE COMMISSIONS           VENTES NON RÉALISÉES       RISQUE JURIDIQUE & CNIL
      Mandats nuls (Loi Hoguet)      Temps terrain perdu        Absence de registre/purge
      3 ventes contestées = 45 000 € 5 ventes perdues = 45 000 € Amende potentielle = 20 000 €
                            │                                │
                            └──────────────┬─────────────────┘
                                           ▼
                      COÛT GLOBAL ESTIMÉ DE L'INACTION :
                               110 000 € / an
```

| Poste de perte / Risque financier | Description opérationnelle du préjudice | Perte annuelle estimée |
|---|---|:---:|
| **Perte de commissions (Loi Hoguet — SC04)** | 6 mandats actifs sur 11 dépassent la durée légale de 6 mois sans renouvellement. En cas de contestation notariée, la commission est légalement nulle. Sur l'hypothèse de 3 ventes contestées par an à 15 k€ d'honoraires moyens : | **45 000 €** |
| **Ventes non réalisées faute de temps terrain** | 6 chasseurs passent en moyenne 4 h/jour à chercher manuellement des annonces sur les portails et à relire des fiches Word, au lieu de visiter des biens et convertir des mandats. Ce temps est celui d'indépendants : il n'est pas une charge de l'entreprise. Son préjudice est le manque à gagner commercial : la moitié de ce temps rendue au terrain vaut environ 5 ventes par an (§6.2-2), à 15 000 € d'honoraires dont 60 % conservés par l'entreprise : 5 × 9 000 € = | **45 000 €** |
| **Exposition aux sanctions CNIL (RGPD — SC02)** | Absence de politique de rétention, données patrimoniales intimes en clair sans consentement tracé (A10a, A10b) : provision pour risque juridique : | **20 000 €** |
| **TOTAL DU COÛT DE L'INACTION (Année 1) :** | **Impact financier direct du maintien du statu quo (estimation sur hypothèses explicites)** | **110 000 €** |

*Pour mémoire, le temps de recherche manuelle valorisé à 20 €/h (6 chasseurs × 4 h × 180 jours = 86 400 €) mesurait une capacité perdue par les chasseurs, pas une perte de l'entreprise ; il n'est plus compté (revue d'Angeline Gomez, 14/10/2026).*

> **Conclusion du CoI :** Le maintien de l'existant détruit chaque mois plus de **9 000 € de valeur**, soit l'équivalent budgétaire d'une phase complète de refonte.

---

## 4. Diagnostic stratégique de l'existant — Matrice SWOT consolidée

Pour éclairer l'arbitrage d'investissement face à l'environnement de marché, l'équipe a formalisé la matrice SWOT suivante (travaux consolidés par Angeline Gomez) :

```
                                  DIAGNOSTIC STRATÉGIQUE (SWOT)
  ┌───────────────────────────────────────────────┬───────────────────────────────────────────────┐
  │              FORCES (Interne, +)              │             FAIBLESSES (Interne, -)           │
  │ • Existant de taille négligeable (52 lignes)  │ • Données fausses en base (A01 / A04)         │
  │ • Qualité sémantique des données saines       │ • Mélange des rôles clients/chasseurs (A02)   │
  │ • Unicité de l'email fiable comme pivot       │ • Chaîne de valeur non modélisée (A08)        │
  │ • Référentiel géographique (10 secteurs) prêt │ • Critères texte libre non versionnés (A03)   │
  │ • Métier et barèmes parfaitement documentés   │ • Données personnelles non protégées (A10a-b) │
  │ • Lucidité et soutien total du commanditaire  │ • Backend boîte noire sans mainteneur (A11)   │
  ├───────────────────────────────────────────────┼───────────────────────────────────────────────┤
  │            OPPORTUNITÉS (Externe, +)          │              MENACES (Externe, -)             │
  │ • Croissance nationale & internationale       │ • Sanction CNIL sur données patrimoniales     │
  │ • Re-développement backend prévu en Phase 4   │ • Nullité juridique des honoraires (Hoguet)   │
  │ • Maturité des briques d'IA (Matching auto)   │ • Rupture d'exploitation à la montée en charge│
  │ • Notaire tiers de confiance (Pas de relance) │ • Dépendance SPOF au backend hérité (A11)     │
  │ • Marché immobilier en quête de réactivité    │ • Concurrence outillée en matching prédictif  │
  └───────────────────────────────────────────────┴───────────────────────────────────────────────┘
```

### 4.1 Les Enseignements des Stratégies Croisées
1. **Forces × Opportunités (Offensif) :** La taille infime de l'existant (52 lignes) et la reconstruction programmée du backend éliminent le besoin d'une cohabitation complexe : **la migration peut se faire en une transaction unique**, ouvrant immédiatement la voie au Big Data.
2. **Forces × Menaces (Défensif) :** La documentation précise du métier permet de traduire immédiatement les règles juridiques en **contraintes déclaratives PostgreSQL strictes** (calcul dynamique de l'échéance à `date_debut + 6 mois`, filiation des renouvellements), faisant de la base la pièce probante opposable devant le notaire.
3. **Faiblesses × Opportunités (Ajustement) :** La structuration fine des critères de recherche (A03) et le versionnage de la demande (A10c) ne sont pas un luxe cosmétique : c'est le **pré-requis technique non négociable** pour alimenter le modèle d'IA de la Phase 4.
4. **Faiblesses × Menaces (Survie) :** L'asymétrie majeure constatée (*la structure est massivement défaillante, alors que la donnée est peu nombreuse et que ses anomalies sont identifiées et traçables*) impose de **reconstruire la structure plutôt que de rafistoler l'ancien schéma**.

---

## 5. Analyse comparative des 3 scénarios d'évolution

Pour arbitrer de manière rationnelle sur l'architecture cible du SI (contribution directe au bloc RNCP **BC01** et au cadrage d'investissement **BC02**), trois options architecturales ont été formellement modélisées et soumises à une analyse multicritère rigoureuse.

### 5.1 Définition technique des trois architectures candidates (A, B, C)

Avant de procéder à la cotation comparative, il est indispensable de définir précisément la nature technique, les principes de fonctionnement et les limites intrinsèques de chaque scénario :

> **Lecture des lettres.** Les options A, B et C de cette étude répondent à la question « faut-il investir, et selon quelle organisation générale ? ». La *Matrice de décision — architecture de croissance* (Angeline Gomez, v2 du 08/10/2026) répond à une autre question, « comment la cible absorbe-t-elle la croissance ? », avec ses propres lettres. Pour éviter toute confusion, les deux jeux sont notés EO (étude d'opportunité) et ARCH (matrice) quand ils sont cités ensemble :
>
> | Étude d'opportunité | Matrice de décision | Remarque |
> |---|---|---|
> | **EO-A** base unique, transactionnel et analytique confondus | hors matrice | référence du statu quo ; **non conforme** à la séparation analytique imposée par l'énoncé, elle sert de point de comparaison, pas de candidate |
> | **EO-B** séparation base de travail / entrepôt | ARCH-A (indexée, sauvegardes) ou **ARCH-B** (indexée, haute disponibilité) | la recommandation retient ARCH-B ; ARCH-C (partitionnée) a été testée et écartée en l'état par le dossier d'architecture cible (ENF-04 non tenable) |
> | **EO-C** sharding géographique | ARCH-D (distribuée par pays) | même option, deux noms |

#### 1. Option A : Base relationnelle unique, indexée (Statu quo modernisé / Patching)
* **Principe d'architecture :** Conserver un système mono-instance où une unique base relationnelle (PostgreSQL) supporte à la fois les écritures opérationnelles quotidiennes (saisies des mandats, comptes-rendus de visites, offres) ET les requêtes analytiques lourdes (tableaux de bord Power BI de la direction, calculs de rentabilité).
* **Mécanismes techniques :** Ajout d'index B-Tree et d'index partiels sur les colonnes clés pour tenter d'accélérer les lectures.
* **Avantages :** Coût d'hébergement minimal (une seule instance de base de données), exploitation simple (un seul jeu de sauvegardes `pg_dump`).
* **Limites & Risques :** Concurrence de ressources. Lors du rafraîchissement d'un rapport Power BI de 50 pages balayant des milliers de mandats et d'annonces, les lectures analytiques et les écritures des chasseurs se disputent le processeur, la mémoire et les entrées-sorties de la même instance, et les transactions longues du reporting retardent le nettoyage interne de la base. (PostgreSQL ne bloque pas les écritures par des verrous de lecture : le problème est la concurrence de ressources, pas le verrouillage.) De plus, aucun espace n'est prévu pour décharger les traitements d'Intelligence Artificielle en Phase 4.

#### 2. Option B : Architecture découplée OLTP + OLAP (Option Recommandée)
* **Principe d'architecture :** Séparation physique et logique étanche entre l'environnement transactionnel (**OLTP**) et l'environnement décisionnel (**OLAP**), conformément à la frontière actée par l'équipe (ADR-025, ADR-036) :
  1. **Socle OLTP (PostgreSQL, socle v8.43 : 38 tables, 9 vues) :** Schéma normalisé (3FN), dont les quelques dénormalisations sont ciblées et justifiées par ADR, optimisé pour des transactions unitaires rapides, l'intégrité référentielle stricte (contraintes ACID) et la concurrence d'écriture sans blocage.
  2. **Socle OLAP (Entrepôt de données / Datamart) :** Schéma dénormalisé en étoile — 4 tables de faits (`fait_vente`, `fait_remuneration_chasseur`, `fait_mandat_cycle`, `fait_activite_demande`) et 6 dimensions (`dim_temps`, `dim_chasseur`, `dim_gestionnaire`, `dim_zone`, `dim_bien`, `dim_client`) —, alimenté par un pipeline ELT/ETL asynchrone (chargement nocturne ou micro-batch horaire).
* **Avantages :** Aucune concurrence de ressources entre la production terrain et le reporting de direction. Les requêtes analytiques s'exécutent sur des tables pré-agrégées dédiées. En cas de panne de l'entrepôt décisionnel, l'activité de vente continue sans aucune interruption.
* **Limites & Risques :** Nécessite la maintenance d'un pipeline de synchronisation entre l'OLTP et l'OLAP et la gestion de deux bases, ce qui reste parfaitement accessible aux compétences de l'équipe sans surcoût d'infogérance 24/7.

#### 3. Option C : Architecture distribuée — Base découplée avec Sharding géographique & Partitionnement
* **Principe d'architecture :** Reprendre le socle découplé de l'Option B, mais en partitionnant horizontalement les tables transactionnelles sur plusieurs serveurs physiques distincts (*shards* multi-nœuds distribués par pays ou région géographique : un nœud pour la France, un nœud pour chaque filiale internationale).
* **Mécanismes techniques :** Routeur de requêtes distribuées (ex: Citus Data, CockroachDB ou partitionnement FDW), transactions distribuées *two-phase commit* (2PC) pour garantir la cohérence inter-nœuds.
* **Avantages :** Montée en charge horizontale par ajout de nœuds, utile si les écritures saturent un serveur.
* **Limites & Risques :** Complexité d'exploitation démesurée pour une PME. Exige une équipe d'infogérance 24/7 et un DBA dédié. Surtout, **le sharding géographique complique le matching d'annonces par IA** : les annonces étant dispersées sur plusieurs fragments, une recherche globale doit interroger tous les nœuds et agréger leurs réponses (*scatter-gather*), sauf à maintenir un index de recherche centralisé, séparé du transactionnel. Ce surcoût n'est pas mesuré : la conclusion est « complexité et bénéfice non justifiés pour le scénario étudié », à réexaminer sur des seuils mesurés.

```
                            ARBITRAGE STRATÉGIQUE
            ┌──────────────────────────┼──────────────────────────┐
            ▼                          ▼                          ▼
   Option A : base unique     Option B : OLTP + OLAP     Option C : sharding
   indexée — 66 points        séparés — 85 points        multi-nœuds — 80 points
            │                          │                          │
            ▼                          ▼                          ▼
        ÉCARTÉE                  RETENUE (GO)             AJOURNÉE (phase 3+)
   concurrence de ressources, couvre la croissance,     complexité d'exploitation,
   pas d'espace pour l'IA    exploitation simple       dégradation du matching IA
```

### 5.2 Tableau d'évaluation multicritère des options

Chaque critère est pondéré de 1 à 5 selon sa criticité opérationnelle pour Chasse Immo. Chaque option est notée de 1 à 5, avec justification détaillée de la note attribuée :

| Critère d'évaluation | Poids | Justification du poids | Option A : Statu Quo / Patching | Option B (Retenue) : OLTP + OLAP Cible | Option C : Sharding & Multi-nœuds |
|---|:---:|---|---|---|---|
| **Absorption de la volumétrie** | **5** | Milliers de mandats/semaine, millions d'annonces scrapées. | **2/5 (10 pts)**<br>*Faible :* Goulot d'étranglement inévitable dès que les écritures concurrentes et lectures massives s'accumulent sur la même instance. | **4/5 (20 pts)**<br>*Très bonne :* L'isolation stricte des écritures OLTP permet d'absorber la croissance transactionnelle sans saturation. | **5/5 (25 pts)**<br>*Maximale :* La distribution horizontale permet d'ajouter des nœuds ; le bénéfice n'est pas démontré pour le scénario étudié. |
| **Complexité d'exploitation (PCA/PRA)** | **5** | PME sans équipe d'infogérance 24/7 dédiée (SPOF A11). | **5/5 (25 pts)**<br>*Minimale :* Une seule instance à sauvegarder et superviser avec des outils standards (`pg_dump`). | **3/5 (15 pts)**<br>*Modérée & Maîtrisée :* Deux instances à synchroniser, mais sur une stack PostgreSQL standard gérable par l'équipe interne. | **1/5 (5 pts)**<br>*Inacceptable :* Requiert un DBA dédié, un PCA géoréparti complexe et la gestion d'incidents distribués hors de portée. |
| **Performance analytique (Power BI / KPI)** | **4** | 5 indicateurs de performance à recalculer en continu. | **1/5 (4 pts)**<br>*Critique :* Les requêtes de reporting scannent la base de production, en concurrence de ressources avec les écritures des chasseurs, avec des délais d'attente. | **5/5 (20 pts)**<br>*Optimale :* Modélisation en étoile dédiée, pré-agrégats optimisés, requêtes analytiques exécutées en sous-seconde sans toucher à l'OLTP. | **5/5 (20 pts)**<br>*Optimale :* Même performance analytique grâce à la décharge sur les répliques décisionnelles. |
| **Distribution internationale** | **3** | Extension progressive dans 9 pays (Phase 3). | **1/5 (3 pts)**<br>*Faible :* Serveur unique en France, latence réseau pénalisante pour les utilisateurs en Espagne, Italie ou Allemagne. | **3/5 (9 pts)**<br>*Satisfaisante :* Base centralisée performante en Europe, avec schéma préparé à l'international (`code_iso_pays`, `devise`). | **5/5 (15 pts)**<br>*Maximale :* Nœuds locaux déployés dans chaque pays pour une latence minimale. |
| **Aptitude au Matching Big Data & IA** | **3** | Structuration des features et recherche vectorielle. | **3/5 (9 pts)**<br>*Moyenne :* L'entraînement et le calcul d'embeddings concurrents dégradent directement les temps de réponse de l'API. | **4/5 (12 pts)**<br>*Forte :* Les modèles d'IA exploitent le datamart ou une réplique de lecture sans impacter l'application des chasseurs. | **3/5 (9 pts)**<br>*Dégradée :* **Le sharding pénalise l'IA** : obligation d'interroger tous les shards distants (*scatter-gather*) pour le matching global d'annonces. |
| **Coût & Éco-conception** | **3** | Maîtrise des ressources serveurs et sobriété SQL. | **5/5 (15 pts)**<br>*Faible coût facial :* Une seule machine, mais processeur et entrées-sorties partagés entre saisie et reporting. | **3/5 (9 pts)**<br>*Équilibré & Sobre :* Hébergement, licences et IA pour environ 6 000 €/an hors maintenance, aux prix publics Scaleway (§6.1-B), instances au juste dimensionnement, requêtes ciblées. | **2/5 (6 pts)**<br>*Surdimensionné :* Coût cloud x3, consommation énergétique permanente de multiples serveurs sous-utilisés. |
| **SCORE GLOBAL PONDÉRÉ (sur 115) :** | | | **66 points** | **85 points** 🏆 | **80 points** |

**Méthode de calcul :** somme pondérée. Pour chaque critère, points = poids × note ; le score est la somme des points ; le maximum vaut (5 + 5 + 4 + 3 + 3 + 3) × 5 = 115. Pour tous les critères, **une note plus élevée est plus favorable** (pour l'exploitation et le coût, 5 signifie donc la solution la plus simple et la moins chère). Les notes sont des jugements d'expert, rendus explicites par la grille ci-dessous ; la notation est proposée par le rédacteur et doit être validée par l'équipe, conformément à la règle de vote du RACI v1.1.

#### Grille de notation

Les notes 2 et 4 correspondent à des situations intermédiaires entre les niveaux décrits.

| Critère | Note 1 | Note 3 | Note 5 |
|---|---|---|---|
| **Absorption de la volumétrie** | Instance unique saturée dès que lectures massives et écritures coexistent | Charges séparées, montée en charge verticale | Montée en charge horizontale par ajout de nœuds |
| **Complexité d'exploitation** | Cluster distribué : DBA dédié et astreinte 24/7 indispensables | Deux instances standard, outillage maîtrisé par l'équipe | Une instance, une sauvegarde, outillage standard |
| **Performance analytique** | Rapports exécutés sur la base de production, concurrence de ressources et délais d'attente | Réplique en lecture, sans modèle dédié | Modèle en étoile dédié, pré-agrégats, aucune charge sur l'OLTP |
| **Distribution internationale** | Serveur unique, aucune donnée de pays ni de devise | Base centralisée en Europe, schéma porteur des pays et devises | Nœuds locaux par pays, latence minimale |
| **Aptitude au matching & IA** | Aucune donnée structurée exploitable | Exploitable sous contrainte majeure : concurrence avec la production ou catalogue fragmenté | Environnement dédié, catalogue unifié, sans impact sur la production |
| **Coût & éco-conception** | Plus de 3 fois le coût de la solution la plus sobre | Environ 1,5 à 2 fois ce coût | Coût minimal, une seule infrastructure |

#### Sensibilité du classement aux pondérations

L'écart entre B et C n'étant que de 5 points, le classement a été recalculé sous des pondérations alternatives plausibles :

| Variation des poids | Option A | Option B | Option C | Option en tête |
|---|:---:|:---:|:---:|---|
| Pondérations retenues | 66 | **85** | 80 | B |
| Distribution internationale : 3 → 5 | 68 | **91** | 90 | B, d'un point |
| Complexité d'exploitation : 5 → 3 | 56 | **79** | 78 | B, d'un point |
| Complexité d'exploitation : 5 → 2 | 51 | 76 | **77** | C |
| International 5 **et** exploitation 3 | 58 | 85 | **88** | C |

**Lecture :** B reste en tête dans le scénario de référence et sous la plupart des variations. Le classement bascule vers C dans deux cas : si le poids de la complexité d'exploitation descend à 2, ou si l'international monte à 5 avec une exploitation ramenée à 3. Autrement dit, C ne l'emporte que si l'entreprise se dote d'une capacité d'exploitation distribuée, avec ou sans priorité internationale. C'est précisément la situation visée en phase 3 avancée : ce test justifie donc le report de l'option C plutôt que son abandon (§5.4, risque RB6).

### 5.3 Pourquoi l'Option B est la décision rationnelle d'ingénierie

L'analyse des scores et des contraintes opérationnelles conduit à la recommandation suivante :

1. **Pourquoi l'Option A est disqualifiée (Le piège de la fausse économie) :**  
   Bien que tentante par son faible coût initial, l'Option A enfermerait Chasse Immo dans une dette technique paralysante. Faire tourner des dashboards Power BI scannant des millions d'annonces sur la même base que la saisie mobile des chasseurs mettrait lectures lourdes et écritures en concurrence sur le même processeur, la même mémoire et les mêmes disques. Sur le terrain, un chasseur devant faire signer un mandat exclusif ou saisir une offre d'achat urgente subirait des ralentissements de son application. L'économie faciale d'un serveur unique détruirait le chiffre d'affaires opérationnel.

2. **Pourquoi l'Option C est rejetée (Le piège de la sur-ingénierie / *Over-engineering*) :**  
   Bien qu'attrayante sur le papier pour une multinationale, l'Option C est totalement inadaptée à la réalité de Chasse Immo :
   * **Inadéquation aux ressources humaines :** Suite à l'arrêt du développeur unique (anomalie A11), l'entreprise ne dispose pas d'une équipe d'astreinte 24/7 ni d'un ingénieur DBA spécialisé en consensus distribué. Imposer du sharding multi-nœuds exposerait l'entreprise à une rupture d'exploitation au premier incident réseau entre nœuds, avec des objectifs de reprise difficiles à tenir sans astreinte.
   * **Risque de contre-performance sur l'IA (non mesuré) :** Le moteur de matching d'annonces (Phase 4) doit trouver le meilleur bien immobilier pour un acquéreur parmi l'ensemble du catalogue. Dans une base shardée géographiquement, la recherche vectorielle est éclatée : le système doit envoyer la requête à chaque shard, attendre la réponse de tous les nœuds, agréger les classements partiels et trier les résultats. Ce surcoût réseau (*network scatter-gather*) peut annuler l'intérêt du sharding ; une recherche limitée au pays de la demande ou un index de recherche centralisé le réduiraient, au prix d'un composant de plus. Aucune de ces configurations n'a été construite ni mesurée : l'option est écartée sur l'analyse des besoins et des moyens, pas sur une mesure.

3. **Pourquoi l'Option B est le choix rationnel optimal (*Fitness for Purpose*) :**  
   L'Option B apporte exactement ce dont l'entreprise a besoin pour les 3 à 5 ans à venir :
   * **Résilience et isolation des pannes :** Si le pipeline décisionnel ou Power BI tombe en panne sous une requête mal formée, la base transactionnelle OLTP (socle v8.43, 38 tables) continue de fonctionner à 100 % sans aucun ralentissement pour les clients et les chasseurs.
   * **Accessibilité d'exploitation :** Deux instances managées PostgreSQL avec réplication asynchrone sont simples à exploiter, automatisables via Docker et scripts standards, et ne requièrent aucune compétence rare d'infogérance distribuée.
   * **Socle idéal pour l'IA :** L'extraction des caractéristiques (*features*) pour le matching se fait en tâche de fond sur la réplique analytique, garantissant une réactivité maximale de l'application mobile.

### 5.4 Registre des risques des options B et C

Choisir une option, c'est aussi choisir ses risques. Ce registre reprend l'échelle de l'analyse EBIOS RM de l'équipe : gravité G et vraisemblance V notées de 1 à 4, criticité R = G × V (🟢 1 à 4 tolérable, 🟡 5 à 9 modéré, 🟠 10 à 12 élevé, 🔴 13 à 16 critique). Les mesures de **prévention** réduisent la vraisemblance, les mesures de **protection** réduisent la gravité. Les risques de l'option B, retenue, sont traités ; ceux de l'option C, ajournée, sont évalués bruts, avec la condition qui permettrait de la relancer.

#### Option B (retenue) — risques et traitement

| Réf. | Risque | G | V | R brut | Traitement | G résid. | V résid. | R résiduel | Porteur (RACI v1.1) |
|---|---|:---:|:---:|:---:|---|:---:|:---:|:---:|---|
| **RB1** | Dérive de schéma entre le socle OLTP et l'entrepôt OLAP : chaque évolution du socle casse l'alimentation décisionnelle. **Constaté le 09/10/2026** : l'entrepôt avait été construit sur un schéma antérieur à la v8.4. | 2 | 4 | 🟡 8 | Prévention : exposition de l'OLTP par des vues d'interface stables et versionnées ; test de compatibilité de l'ETL intégré à la recette de chaque version du socle. | 2 | 2 | 🟢 4 | Matthieu Barre (R schéma OLAP) · A : Angeline Gomez |
| **RB2** | Indicateurs faux ou périmés (chargement partiel, désynchronisation), menant à des décisions erronées sur le barème ou le pilotage. | 3 | 3 | 🟡 9 | Prévention : réconciliation automatique OLTP ↔ OLAP sur les comptages **et** les montants à chaque chargement ; date du dernier chargement affichée dans les tableaux de bord. Protection : rechargement complet rejouable (ETL idempotent). | 2 | 1 | 🟢 2 | Alexandre Kechaf (A descriptif d'alimentation) |
| **RB3** | Charge d'exploitation (deux bases, un orchestrateur) supérieure à la capacité de l'équipe : incident non traité, RTO dépassé. | 3 | 2 | 🟡 6 | Prévention : bases managées en haute disponibilité avec bascule automatique, orchestrateur réduit au strict nécessaire, procédure de reprise testée chaque semestre. | 3 | 1 | 🟢 3 | Thérèse Nguyen (A PCA/PRA) |
| **RB4** | Ré-identification de clients dans l'entrepôt : données personnelles dupliquées sur de petits effectifs (18 clients migrés). | 3 | 2 | 🟡 6 | Prévention : aucune donnée directement identifiante dans l'OLAP, attributs en tranches (âge, budget), effectif minimal par cellule d'analyse (k-anonymat), anonymisation alignée sur l'ADR-043. | 3 | 1 | 🟢 3 | Angeline Gomez (A RGPD, A schéma OLAP) |
| **RB5** | Règle métier non garantie par le schéma : rémunération acceptée sans droit sous mandat non exclusif (CDC v3.0, PO-11). **Démontré par le test T-DR-01.** | 3 | 3 | 🟡 9 | Prévention : garde déclarative sur l'exclusivité du mandat, ou convention actée dans l'ADR-049 avec contrôle systématique en recette. | 3 | 1 | 🟢 3 | Alexandre Kechaf (A MLD) · Product Owner |
| **RB6** | Dette d'architecture : l'international décolle plus vite que prévu et impose une migration de B vers C. | 3 | 2 | 🟡 6 | Protection : réplique en lecture seule (option B du dossier d'architecture cible), pays et devise déjà portés par le schéma, seuils de déclenchement de la migration actés par ADR (nombre de pays, volumétrie, latence). *Mise à jour du 13/10 :* le partitionnement a été testé sur le socle v8.42 ; découpé par période, il impose une reprise des clés ; découpé par identifiant, il fait sortir de la base deux unicités métier (dossier d'architecture cible, § 4), à intégrer au chiffrage d'une migration B → C. | 2 | 2 | 🟢 4 | Matthieu Barre (R dossier d'architecture cible) · A : Thérèse Nguyen |
| **RB7** | Dépendance à l'hébergeur : verrouillage, hausse tarifaire. | 2 | 2 | 🟢 4 | Protection : PostgreSQL standard sans extension propriétaire, stockage compatible S3, sauvegardes logiques portables (`pg_dump`). | 1 | 2 | 🟢 2 | Thérèse Nguyen (A PCA/PRA) |
| **RB8** | Perte des compétences à la fin du projet (facteur bus = 1) : **reproduction du scénario A11**. Risque transverse, présent quelle que soit l'option. | 4 | 3 | 🟠 12 | Prévention : au moins un ingénieur data recruté en interne pour l'exploitation (§6.1-3), documentation vivante (ADR, modèles, procédures), clause de transfert de compétences en cas de recours à un prestataire. | 4 | 1 | 🟢 4 | Direction / Product Owner (décision d'approvisionnement) |
| **RB9** | Non-adoption de l'outil par les chasseurs : indépendants (RSAC), ils ne sont pas tenus de l'utiliser ; une saisie partielle des visites et des propositions fausse les indicateurs et le calcul de la rémunération. *Ajouté le 13/10 (revue de l'A).* | 3 | 3 | 🟡 9 | Prévention : pilote avec deux chasseurs volontaires, référent désigné, formation courte, indicateurs d'adoption suivis chaque semaine (§7.5) ; passage à l'ensemble des chasseurs seulement si les seuils du pilote sont atteints. | 3 | 1 | 🟢 3 | Direction (sponsor) · équipe projet |

#### Option C (ajournée) — risques bruts et conditions de relance

| Réf. | Risque | G | V | R brut | Condition pour relancer l'option |
|---|---|:---:|:---:|:---:|---|
| **RC1** | Exploitation distribuée hors de portée : incidents inter-nœuds, RTO et RPO intenables sans DBA dédié. | 4 | 3 | 🟠 12 | Équipe d'exploitation constituée, astreinte 24/7. |
| **RC2** | Garanties d'intégrité du socle non distribuables : clés étrangères composées, contraintes d'exclusion et déclencheurs — fondement des 23 rejets et 12 sondes de la recette v8.41 — ne s'appliquent pas simplement entre fragments. | 3 | 4 | 🟠 12 | Ré-architecture des contraintes et nouvelle recette complète. |
| **RC3** | Compétences rares (bases distribuées) : recrutement difficile, dépendance à un prestataire — reproduction du risque A11. | 4 | 3 | 🟠 12 | Recrutement, ou contrat de support assorti d'un transfert de compétences. |
| **RC4** | Surcoût d'infrastructure (environ trois fois l'option B) et nœuds sous-utilisés au regard de la volumétrie actuelle. | 2 | 4 | 🟡 8 | Volumétrie atteignant les seuils de l'ADR de déclenchement (RB6). |
| **RC5** | Dégradation du matching IA : recherche répartie sur tous les fragments (*scatter-gather*). | 2 | 3 | 🟡 6 | Index vectoriel centralisé, indépendant des fragments. |
| **RC6** | Risque éditeur : CockroachDB a retiré son offre libre « Core » le 18/11/2024 ; l'édition Enterprise n'est gratuite que sous 10 M$ de chiffre d'affaires, puis facturée par cœur. | 3 | 2 | 🟡 6 | Analyse de licence de la solution retenue à la date du choix. |
| **RC7** | Localisation des données par pays : tout nœud situé hors de l'Union européenne impose de vérifier le cadre de transfert RGPD applicable. | 3 | 2 | 🟡 6 | Analyse juridique pays par pays, reportée au registre RGPD. |

**Synthèse :** l'option B présente 9 risques, dont un seul élevé (RB8), qui est transverse à toutes les options. Les niveaux indiqués pour B sont les **niveaux résiduels visés après traitement** : le recrutement, les procédures, le pilote et les protections d'accès ne sont pas encore en place, et chaque traitement devra apporter sa preuve de réalisation. L'option C présente 7 risques, dont 3 élevés (RC1, RC2, RC3), **évalués bruts** faute de traitement possible avec les moyens actuels : la comparaison avec B est donc asymétrique, et c'est voulu, puisque c'est l'absence de traitement accessible qui motive le report. Le registre confirme la notation du §5.2 et le report de l'option C.

**Ordre de grandeur des coûts des options écartées.** Ni ARCH-C (partitionnée) ni EO-C / ARCH-D (distribuée) n'ont été prototypées ni chiffrées poste par poste. Pour anticiper, voici un ordre de grandeur dérivé des prix unitaires du §6.1 (base de production avec haute disponibilité : 228,71 € par mois) et de l'effort constaté sur le socle (51,4 j.h) ; il ne vaut pas devis.

| Option | Ce qu'il faudrait construire | Investissement (ordre de grandeur) | Exploitation annuelle en plus de B | Ce qui n'est pas chiffré |
|---|---|---|---|---|
| **ARCH-C** partitionnement par période | clé primaire composée et date dans les clés étrangères de 4 tables, 2 unicités métier réécrites en déclencheurs, création automatique des partitions, migration, recette (dossier d'architecture cible § 4) | **15 à 25 j.h, soit 5 à 9 k€** | création et purge des partitions : ≈ 0,5 j.h par mois, **≈ 2 k€** ; hébergement identique à B | le bénéfice : aucune requête mesurée n'est accélérée en l'état |
| **EO-C / ARCH-D** distribution par pays | un fragment par pays (base avec haute disponibilité chacune), un routeur de requêtes, les 7 contraintes d'intégrité fonctionnelle et les clés étrangères composées réécrites hors base (elles ne traversent pas les serveurs), transactions distribuées, index de recherche centralisé pour le matching | **60 à 90 j.h, soit 21 à 32 k€** | hébergement : 3 fragments au démarrage de la phase 3 ≈ **8 k€**, 10 fragments ≈ **27 k€** ; exploitation 24/7 (astreinte ou infogérance, DBA à temps partiel) : **25 à 50 k€** | licence du routeur (CockroachDB : édition Enterprise au-delà d'un seuil de chiffre d'affaires, RC6) ; analyse juridique de localisation par pays (RC7) |

Lecture : la première année, EO-C / ARCH-D coûterait de l'ordre de **55 à 110 k€ de plus que B** pour un besoin d'écriture projeté qui tient sur un serveur (≈ 8 associations par seconde en hypothèse haute, dossier d'architecture cible). Ce chiffrage sera repris si l'une des conditions de relance se réalise.

**Lien avec le budget :** la provision pour aléas de 10 % du CAPEX (4 550 €, soit 13 jours-homme, §6.1-2) est affectée au traitement de RB1, RB2 et RB5 (8 jours-homme) et de RB9, la conduite du changement (5 jours-homme, §7.5). Le traitement de RB8 relève de la stratégie d'approvisionnement (§6.1-3).

---

## 6. Évaluation économique, budgétaire & Rentabilité (Business Case & ROI)

### 6.1 Investissement requis, modèle TCO sur 3 ans & stratégie d'approvisionnement

L'estimation financière repose sur une méthodologie d'ingénierie d'affaires standard, valorisant l'effort de l'équipe projet interne (4 consultants / ingénieurs apprenants : Matthieu Barre, Angeline Gomez, Alexandre Kechaf, Thérèse Nguyen) complété par les charges d'infrastructures cloud et licences logicielles :

#### 1. Méthode de valorisation de l'effort d'ingénierie (TJM)
* **Taux Journalier Moyen (TJM) retenu :** **350 € / jour.homme**, soit le **coût complet d'un ingénieur data junior recruté en interne** : un salaire d'environ 45 000 € brut par an (fourchette Hays : 42 000 à 47 000 €) et des charges patronales d'environ 39 % donnent environ 62 600 € par an, soit 287 € par jour sur 218 jours travaillés, et 344 € par jour avec 20 % de frais de structure (poste de travail, encadrement). Ce taux exclut la marge commerciale d'un prestataire, dont les tarifs sont comparés au §6.1-3.
* **Volume d'effort global :** **130 jours.hommes (j.h)** répartis sur les 4 phases techniques du projet — la phase 5 (clôture et soutenance) n'est pas valorisée — soit environ 32,5 jours par personne étalés sur 14 semaines calendaires, respectant le rythme partagé formation / projet.
* **Coût total ingénierie interne :** 130 j.h × 350 €/j = **45 500 €**, auxquels s'ajoute une **provision pour aléas de 10 %** (4 550 €, soit 13 j.h) adossée au registre des risques (§5.4), soit **50 050 €**.
* **Dépenses ponctuelles :** environnements de construction, audit de sécurité et conduite du changement ajoutent 3 151 €, ce qui porte l'investissement initial à **53 201 €**.
* **Pas d'investissement matériel :** le modèle retenu repose sur des services en nuage facturés à l'usage. Aucun serveur n'est acheté : l'investissement matériel devient une dépense d'exploitation (§6.1-B). Les logiciels utilisés (PostgreSQL, Airflow, FastAPI, Power BI Desktop) sont libres ou gratuits, et les postes de travail de l'équipe sont couverts par les 20 % de frais de structure inclus dans le TJM.
* **Limite de l'estimation :** les montants par phase reprennent l'estimation initiale de l'étude (v1.0) ; leur ventilation en jours-homme en découle (montant ÷ 350 €). Une estimation ascendante, tâche par tâche, reste à produire pour la remise.
* **Périmètre chiffré : la plateforme de données.** Les 130 j.h couvrent l'audit, le socle relationnel, la migration, l'entrepôt, le contrat d'interface (OpenAPI) et le pré-matching. **Le backend applicatif complet n'est pas chiffré** : réécriture de l'API (ADR-054), authentification et fournisseur d'identité, droits par rôle, interfaces des chasseurs, des gestionnaires et des clients, pare-feu applicatif, notifications, décommissionnement de l'ancien backend (§7.1-4). Par comparaison avec l'effort constaté sur le socle (51,4 j.h), une fourchette indicative est de **60 à 90 j.h, soit 21 000 à 31 500 € au TJM interne**, à confirmer par une estimation par tâches avant le GO ; cette charge est **hors des 65 469 € de l'année 1** et déplacerait le temps de retour d'autant (§6.3). Restent également à préciser : le coût du fournisseur d'identité, l'exploitation du pare-feu applicatif et des notifications, une éventuelle réplique de lecture distincte de l'instance de secours (dossier d'architecture cible), la disponibilité de l'ingénieur recruté au-delà des 1,5 j.h mensuels de maintien en conditions opérationnelles, et le périmètre des 3 jours d'audit de sécurité.

#### 2. Décomposition budgétaire : Investissement Initial (CAPEX) vs Exploitation Récurrente (OPEX)

Pour garantir une gouvernance financière rigoureuse conforme aux standards d'ingénierie (RNCP40573), le budget dissocie strictement les dépenses d'investissement de conception/migration (**CAPEX - *Build***) des coûts récurrents d'hébergement, de stockage et de maintenance opérationnelle (**OPEX - *Run***).

##### A. Dépenses d'Investissement Initial (CAPEX — Build) : 53 201 €

| Poste de dépenses CAPEX | Détail opérationnel des livrables | Effort mobilisé | Coût calculé |
|---|---|:---:|:---:|
| **Phase 1 & 2 : Audit, Modélisation relationnelle & DDL** | Cartographie de l'existant, analyse EBIOS RM, socle relationnel v8.41 (38 tables, 8 vues), scripts DDL/DML, triggers et vue `v_mandat`. | **51,4 j.h**<br>*(~13 j/personne)* | **18 000 €** |
| **Phase 2b : Recette, Migration ETL & Sécurisation** | Pipeline de reprise des données historiques multi-source ; batteries de tests rejouables (harnais de 23 rejets + 4 cas valides, 12 sondes d'intégrité, 48 tests de migration, 7 tests RGPD) ; traitement des anomalies A03b et A06 (A06 à valider : CDC PO-12). La sécurité au niveau ligne (RLS) n'est pas incluse : elle est reportée en phase 4 (CDC PO-10). | **22,8 j.h**<br>*(~6 j/personne)* | **8 000 €** |
| **Phase 3 : Entrepôt Décisionnel OLAP & Power BI** | Modélisation en étoile (4 tables de faits : `fait_vente`, `fait_remuneration_chasseur`, `fait_mandat_cycle`, `fait_activite_demande` ; 6 dimensions), pipeline d'alimentation ELT nocturne, tableaux de bord Power BI. | **34,3 j.h**<br>*(~8,5 j/personne)* | **12 000 €** |
| **Phase 4 : Conception API cible & Matching IA** | Spécifications d'interface OpenAPI 3.0, module de pré-matching d'annonces par similarité multi-critères, note de sécurité et souveraineté IA. | **21,4 j.h**<br>*(~5,5 j/personne)* | **7 500 €** |
| **Provision pour aléas (10 %)** | Risques du registre (§5.4) : RB1, RB2 et RB5 pour 8 j.h (vues d'interface versionnées, réconciliation des montants, garde sur l'exclusivité du mandat) ; RB9 pour 5 j.h (pilote d'adoption, §7.5). | **13 j.h** | **4 550 €** |
| **Environnements de développement et de recette** | Base DB-PLAY2-NANO (31,54 €/mois) et instance PLAY2-NANO (20,10 €/mois) pendant les 14 semaines de construction, soit 3,5 mois, aux prix Scaleway. | — | **181 €** |
| **Audit de sécurité externe** | Test d'intrusion de l'API et de la base avant mise en production : 3 jours d'un prestataire au tarif médian de 640 €/j (§6.1-3). | **3 j** (prestataire) | **1 920 €** |
| **Conduite du changement** | Formation de la direction et de la gestion aux tableaux de bord, accompagnement des chasseurs à la nouvelle application. Complétée par 5 j.h de la provision pour le pilote d'adoption (§7.5) : 8 j.h au total. | **3 j.h** | **1 050 €** |
| **Sous-total Investissement Initial (CAPEX) :** | **146 jours.hommes internes au TJM de 350 €/j (dont 13 de provision) et 2 101 € de dépenses externes** | **146 j.h + 3 j** | **53 201 €** |

##### B. Dépenses Récurrentes Annuelles d'Infrastructure & Exploitation (OPEX — Run An 1) : 12 268 € / an

Chaque ligne est chiffrée aux **prix publics d'un hébergeur français**, Scaleway, en région Paris, hors taxes, tels que consultés le 09/10/2026 (sources au §6.1-4). Le mois de facturation compte 730 heures.

| Poste de dépenses OPEX | Offre retenue et calcul | Coût mensuel | Coût Année 1 | Estimation v2.0 |
|---|---|:---:|:---:|:---:|
| **Bases de données managées (OLTP HA & OLAP)** | • Production (OLTP) : DB-PRO2-XS (4 vCPU, 16 Go) à 0,22 €/h + option haute disponibilité multi-zones à 0,0933 €/h, soit 228,71 €/mois.<br>• Décisionnel (OLAP) : DB-PRO2-XXS (2 vCPU, 8 Go) à 0,11 €/h, soit 80,30 €/mois.<br>• Stockage bloc : 150 Go × 0,0993 € = 14,89 €/mois. Sauvegardes et restauration à la seconde : 200 Go × 0,03 € = 6,00 €/mois. | 329,90 € | **3 959 €** | 2 520 € |
| **Stockage Objet & Rétention Légale** | • Chaud, classe Standard multi-zones : 150 Go × 0,01606 € = 2,41 €/mois.<br>• Froid, classe Glacier : 500 Go × 0,00254 € = 1,27 €/mois.<br>• Réplique hors site de la règle 3-2-1, en région Amsterdam ou Varsovie, classe Standard une zone : 300 Go × 0,00803 € = 2,41 €/mois. Les 75 premiers Go sortants de chaque mois sont gratuits. | 6,09 € | **73 €** | 600 € |
| **Serveurs Applicatifs & Orchestration** | • API FastAPI et ingestion d'annonces : instance PLAY2-NANO (2 vCPU, 4 Go), 20,10 €/mois.<br>• Airflow (ordonnanceur, interface, exécuteur ETL et RGPD) : instance PLAY2-MICRO (4 vCPU, 8 Go), 40,20 €/mois. | 60,30 € | **724 €** | 1 320 € |
| **Licences, Outillage & Supervision** | • Power BI Pro : 4 licences pour les seuls utilisateurs internes (voir le tableau des profils ci-dessous) à environ 14 € par utilisateur et par mois — tarif porté de 10 à 14 $ le 01/04/2025 —, soit 56 €/mois.<br>• Supervision des erreurs applicatives, Sentry Team : environ 25 €/mois (26 $ en facturation annuelle).<br>• Métriques et tableaux de bord techniques, Grafana Cloud : offre gratuite (3 utilisateurs, 10 000 séries actives).<br>• Certificats TLS : Let's Encrypt, gratuit. | 81,00 € | **972 €** | 1 060 € |
| **Intelligence artificielle du produit** | API d'IA générative hébergée à Paris (Scaleway), conforme à l'exigence de souveraineté (CDC v3.0, ENF-20) : Mistral Small 3.2 à 0,15 € par million de jetons en entrée et 0,35 € en sortie, modèle d'embeddings à 0,10 € par million ; premier million de jetons gratuit. Hypothèse d'activité actuelle : 2 000 annonces vectorisées par jour pour le matching, 20 requêtes par jour ouvré et par chasseur (pré-rédaction, dédoublonnage), soit environ 4 € par mois. Budget retenu : 20 €/mois, cinq fois l'estimation. | 20,00 € | **240 €** | — |
| **Maintien en Conditions Opérationnelles (MCO)** | Correctifs de sécurité mensuels (Linux et conteneurs), maintenance préventive des index, supervision des sauvegardes, incidents de niveaux 2 et 3 : 1,5 j.h/mois au coût interne de 350 €/j. | 525,00 € | **6 300 €** | 6 300 € |
| **Sous-total Exploitation & Hébergement (OPEX An 1) :** | **Coûts récurrents de l'année 1, aux prix publics** | **1 022 €** | **12 268 €** | 11 800 € |

**Profils d'utilisateurs retenus pour le chiffrage**

| Profil | Nombre (hypothèse) | Accès | Licence payante |
|---|:---:|---|---|
| Direction (direction générale, direction administrative et financière) | 2 | Tableaux de bord Power BI | 2 licences Power BI Pro |
| Pilotage commercial et gestion des demandes | 2 | Tableaux de bord Power BI, application | 2 licences Power BI Pro |
| Chasseurs, agents commerciaux indépendants (§2.1) | 6 | Application : leurs **propres** indicateurs uniquement | Aucune : les chasseurs sont extérieurs à la société et ne reçoivent pas de licence de l'outil de pilotage interne |
| Clients acquéreurs | 18 à ce jour | Espace acquéreur web | Aucune |
| Administration technique | 1 à 2 | Consoles d'hébergement et de supervision | Aucune : offres incluses ou gratuites |

La définition des rôles, des droits et des comptes d'administration ne relève pas de l'étude d'opportunité. Elle appartient au cahier des charges technique (§5.1, EF-01 : rôles client, chasseur et gestionnaire) et à la future matrice d'habilitations, liée à l'authentification et à la sécurité au niveau ligne (CDC v3.0, PO-10). L'étude n'en retient que le nombre d'utilisateurs payants.

* **Ce que change le sourçage :** l'estimation v2.0 sous-évaluait la base de production (+1 439 €) et omettait l'IA du produit (+240 €), mais surévaluait le stockage objet (−527 €), les serveurs (−596 €) et l'outillage (−88 €). Écart net : **+468 € par an**.
* **Point de comparaison :** sur AWS, une instance équivalente (db.m6g.xlarge, 4 vCPU, 16 Go) coûte 0,318 $/h en zone unique dans la région de référence us-east-1, soit environ 464 $ par mois en haute disponibilité multi-zones, avant stockage : deux fois le prix retenu. Le choix d'un hébergeur français se justifie donc à la fois par le coût et par l'exigence de souveraineté de l'énoncé.
* **Hypothèse de continuité :** le budget de maintenance ne finance pas d'astreinte. Le RTO de 2 heures repose sur la bascule automatique de l'option haute disponibilité (§6.4-2) ; les incidents applicatifs sont traités aux heures ouvrées.

##### C. Matrice TCO Pluriannuelle Consolidée sur 3 Ans (Total Cost of Ownership)

La projection sur 3 ans retient trois hypothèses explicites : prix publics constants, stockage en hausse de 50 % par an, et passage de la base de production en DB-PRO2-S (8 vCPU, 32 Go, haute disponibilité : 455,30 €/mois) en année 3, avec l'expansion européenne.

| Catégorie budgétaire | Année 1 (Build + Run) | Année 2 (Run) | Année 3 (Run + Croissance UE) | Total TCO sur 3 ans |
|---|:---:|:---:|:---:|:---:|
| **Investissement Initial (CAPEX, provision incluse)** | 53 201 € | 0 € | 0 € | **53 201 €** |
| **Bases de données managées (OLTP + OLAP)** | 3 959 € | 4 084 € | 6 991 € | **15 034 €** |
| **Stockage Objet (chaud, froid, réplique hors site)** | 73 € | 110 € | 164 € | **347 €** |
| **Serveurs Applicatifs & Airflow** | 724 € | 724 € | 724 € | **2 172 €** |
| **Licences & Outils (Power BI, Supervision)** | 972 € | 972 € | 972 € | **2 916 €** |
| **Intelligence artificielle du produit** | 240 € | 240 € | 240 € | **720 €** |
| **Entretien & MCO** | 6 300 € | 6 300 € | 6 800 € | **19 400 €** |
| **COÛT TOTAL ANNUEL DU SI :** | **65 469 €** | **12 430 €** | **15 891 €** | **93 790 €** |

> **Constat financier clé :** Grâce au choix de briques open source souveraines (PostgreSQL, Airflow, FastAPI) chez un hébergeur français, le coût de fonctionnement se situe **entre 12 000 et 16 000 € par an** (12 430 € en année 2, 15 891 € en année 3 après la montée en gamme de la base de production), sans aucune rente de licence propriétaire captive. La maintenance (MCO) en représente à elle seule la moitié.

**Volumétrie retenue — limite à connaître :** ce chiffrage dimensionne l'infrastructure pour l'**activité actuelle** (6 chasseurs, 18 mandats repris) et sa croissance organique. Il ne couvre pas la cible de l'énoncé — des milliers de mandats par semaine, que le CDC v3.0 fixe à 5 000 (ENF-03) —, qui sera atteinte par croissance externe en phase 3. À ce volume, l'infrastructure change d'échelle : base de production plus puissante, réplique en lecture, stockage des médias. *Mise à jour du 13/10 :* le dossier d'architecture cible apporte de premières mesures (requêtes représentatives sous 65 ms sur 20 000 mandats, après indexation) et montre que le partitionnement des annonces et des propositions (ENF-04, PO-15) n'est pas applicable au socle actuel sans reprise de données. Ce coût doit être établi à partir de la note de dimensionnement 3V (RACI v1.1 — R : Alexandre Kechaf · A : Angeline Gomez), qui reste à produire. Les gains croissant avec le nombre de mandats, ce changement d'échelle ne remet pas a priori en cause la rentabilité, mais il doit être chiffré avant la phase 3.

#### 3. Stratégie d'approvisionnement : équipe interne, apprentis ou prestataire

Le coût de construction dépend directement de **qui** réalise le projet. Trois modes ont été comparés à périmètre identique (130 jours-homme, 10 % de provision et les mêmes dépenses ponctuelles), avec l'OPEX sourcé ci-dessus :

| Mode de réalisation | Coût journalier | CAPEX | TCO an 1 | ROI an 1 | ROI sur 3 ans | Démarrage | Risque de dépendance (A11) |
|---|---|:---:|:---:|:---:|:---:|---|---|
| **Équipe en apprentissage** (4 apprentis Bac+5) | ≈ 125 €/j brut, hors charges : 61 % du SMIC (21–25 ans, 2e année), soit 1 139 €/mois, sur 50 % du temps en entreprise ; aide de 2 000 € par contrat | 21 081 € | 33 349 € | +251 % | +469 % | À la rentrée de formation | **Très élevé** : départs en fin de contrat ; maître d'apprentissage obligatoire, alors qu'aucun informaticien n'est en poste |
| **Recrutement interne** (scénario central) | ≈ 350 €/j : coût complet d'un junior (§6.1-1) | 53 201 € | 65 469 € | +78,7 % | +274,2 % | Après le délai de recrutement | **Faible** : compétences conservées dans l'entreprise |
| **ESN ou indépendants** (data engineers) | 530 à 730 €/j, médiane 640 € ; une ESN facture en général au-dessus, marge comprise | 78 941 à 107 541 € | 91 209 à 119 809 € | de +28 % à -2 % | de +194 % à +137 % | Immédiat | **Élevé** sans clause de transfert : reproduit le schéma A11 |

**Recommandation : une approche mixte.** Le scénario central valorise une **équipe interne**, condition du traitement du risque RB8 (§5.4) : au moins un ingénieur data recruté reste pour l'exploitation et peut devenir le maître d'apprentissage d'éventuels apprentis. Le recours à un prestataire est réservé à des expertises ponctuelles, comme l'audit de sécurité budgété au §6.1-2, avec une clause contractuelle de transfert de compétences. L'option « tout apprentis » est la moins chère, mais elle n'est pas recommandée : elle ne peut pas fonctionner sans encadrement interne et maximise le risque A11.

#### 4. Sources des prix et des coûts (consultées le 09/10/2026)

* **Hébergement (Scaleway, région Paris, HT) :** [bases de données managées](https://www.scaleway.com/en/pricing/managed-databases/) · [stockage objet](https://www.scaleway.com/en/pricing/storage/) · [instances](https://www.scaleway.com/en/pricing/virtual-instances/).
* **IA générative (Scaleway, région Paris) :** [Generative APIs](https://www.scaleway.com/en/pricing/model-as-a-service/).
* **Comparaison AWS :** [db.m6g.xlarge, prix RDS](https://instances.vantage.sh/aws/rds/db.m6g.xlarge).
* **Licences et outillage :** [hausse du prix de Power BI Pro au 01/04/2025](https://www.theregister.com/2025/04/02/microsoft_power_bi_hikes/) · [Sentry, offre Team](https://capterra.com/p/165426/sentry/pricing) · [Grafana Cloud, offre gratuite](https://last9.io/blog/grafana-cloud-pricing/).
* **Coût d'un recrutement :** [salaires data engineer, Hays](https://www.hays.fr/conseils-carriere/article/data-engineer-missions-formation-competences-salaire) · [synthèse des salaires 2026](https://www.jedha.co/formation-data/salaire-data-engineer) · [charges patronales](https://finom.co/fr-fr/blog/charges-patronales/).
* **Apprentissage :** [SMIC au 01/01/2026](https://www.info.gouv.fr/actualite/le-smic-revalorise-au-1er-janvier-2026) · [rémunération des apprentis](https://www.digischool.fr/articles/orientation/alternance/salaire-apprenti-2026/) · [aides à l'embauche d'apprentis](https://travail-emploi.gouv.fr/laide-aux-employeurs-qui-recrutent-en-apprentissage).
* **Tarifs des prestataires :** [baromètre TJM 2026](https://tjmetre.fr/barometre-annuel) · [baromètre Silkhom](https://www.silkhom.com/barometre-des-tjm-informatique-electronique-digital/) · [TJM data engineer, Free-Work](https://www.free-work.com/fr/tech-it/data-engineer/rate-tjm-freelance).
* **Licence CockroachDB (risque RC6) :** [annonce de Cockroach Labs](https://www.cockroachlabs.com/enterprise-license-update).

Ces prix évoluent : ils sont à réactualiser à la date de la remise. Les conversions du dollar en euro sont indicatives.

---

### 6.2 Gains Financiers Directs & Indirects (Bénéfices Attendus)

La mise en production du nouveau SI dégage des retombées économiques directes dès le premier trimestre d'exploitation, estimées à **117 000 € dès la première année** :

#### 1. Sécurisation du Chiffre d'Affaires (+ 45 000 € / an) — *risque évité*
* Grâce à l'état dérivé du mandat dans la vue `v_mandat` (ADR-030, ADR-048) et à la filiation des renouvellements, l'échéance de chaque mandat est calculée et signalée : un mandat expiré ne passe plus inaperçu, et sa prolongation passe par un renouvellement tracé.
* **Impact financier :** Les honoraires des ventes conclues sous mandat valide deviennent opposables devant le notaire instrumentaire. Sur l'hypothèse de 3 ventes par an contestables à 15 000 € de commission moyenne, l'entreprise sanctuarise un revenu de **+45 000 € / an**.
* **Nature de ce gain : un risque évité, pas un revenu acquis.** Le nombre de 3 ventes contestées par an n'est pas mesuré : l'existant ne garde aucun historique de contestation. Ce levier est donc séparé des gains d'exploitation dans le récapitulatif (§6.2-4), et le projet reste rentable sans lui (§6.3, scénario « sans le levier 1 »). **À mesurer la première année :** mandats échus détectés par le suivi d'échéance, ventes évitées sous mandat expiré, contestations reçues.

#### 2. Ventes supplémentaires par la productivité des Chasseurs (+ 45 000 € / an) — *de 2 heures libérées à 5 ventes de plus*
* **Constat initial :** Dans le SI hérité, les 6 chasseurs passent en moyenne **4 heures par jour (50 % de leur journée de travail)** à éplucher manuellement les portails d'annonces (SeLoger, Leboncoin, PAP) et à relire des notes éparses. Il ne leur reste que 4 heures pour le contact direct, les visites et la négociation.
* **Gain de temps opérationnel :** La structuration typée des critères de recherche (`demande_version`) et l'ingestion automatisée des annonces libèrent **2 heures par jour et par chasseur** — soit la moitié du temps perdu chiffré au §3 —, réallouées à 100 % au terrain.
* **Du temps libéré aux ventes supplémentaires :** les chasseurs sont des indépendants ; leurs heures ne sont pas une charge de Chasse Immo, et les heures libérées ne sont donc pas un gain pour elle. Le gain n'existe que si ce temps se transforme en ventes, donc en honoraires. Le calcul suit la chaîne heures libérées → visites → taux de transformation (démonstration ci-dessous) → ventes × honoraires × part de l'entreprise :

```
Mandats signés par an    = 6 chasseurs × 12 mandats (hypothèse : un par mois)       = 72 mandats
Ventes supplémentaires   = 72 × (27 % − 20 %)                                        = 5,04 ≈ 5 ventes
Part de l'entreprise     = 15 000 € d'honoraires × 60 %                               = 9 000 € par vente
                           (barème : 40 % au chasseur dans la tranche 350 à 500 k€)
Gain pour l'entreprise   = 5 ventes × 9 000 €                                         = 45 000 € / an
```

* **Hypothèses à confirmer :** le nombre de mandats signés par an (à demander au Product Owner, puis lu dans la base pendant le pilote) et les honoraires moyens de 15 000 € (même base que le levier 1). Pour mémoire, le temps libéré valorisé à 20 €/h (6 × 2 h × 180 jours = 43 200 €) mesure une capacité, pas un gain : il n'est plus compté (revue d'Angeline Gomez, 14/10/2026).

* **Démonstration de la hausse de +35 % du taux de transformation commercial :**
  * *Avant refonte :* Avec 4h/jour sur le terrain, chaque chasseur ne peut réaliser en moyenne que **2 visites qualifiées par semaine**. Le taux de transformation historique d'un mandat en vente signée est de **20 %** (1 mandat sur 5 conclut une vente).
  * *Après refonte :* En disposant de 6h/jour sur le terrain (+50 % de temps client), le volume de visites utiles passe à **2,7 visites par semaine**. Ce surcroît d'accompagnement direct et de qualification augmente le taux de transformation à **27 %**.
  * *Calcul de la progression relative :*

```
Progression = (27 % − 20 %) / 20 % = +35 % d'augmentation relative du taux de conversion
```

* **Nature de ce gain : une hypothèse à valider par la mesure.** Ni les 4 heures de recherche manuelle ni les 2 heures libérées ne sont mesurées, et aucun retour d'expérience publié et vérifiable n'a été retenu pour les étayer. Le passage de 20 % à 27 % suppose aussi que le temps passé sur le terrain est le facteur limitant ; si le frein est ailleurs (ciblage, état du marché), ce levier est surestimé — c'est pourquoi l'analyse de sensibilité teste des gains divisés par deux (§6.3).
* **Plan de mesure :** pendant le pilote (§7.5), relevé du temps de recherche déclaré par les deux chasseurs pilotes, deux semaines avant et deux semaines après la mise en service, et suivi du nombre de visites réalisées par semaine, lu dans la base. Le gain est révisé à la fin du pilote, avant le passage à l'ensemble des chasseurs.

#### 3. Optimisation du pilotage managérial (+ 27 000 € / an) — *Explications des leviers métier*
Les tableaux de bord Power BI alimentés par le datamart OLAP apportent deux leviers majeurs de rentabilité :
1. **Sauvetage des « mandats dormants » par réaffectation avant échéance :**
   * *Qu'est-ce qu'un « mandat dormant » ?* C'est un mandat signé avec un client, mais sur lequel **aucune visite n'a été organisée depuis plus de 30 jours**, soit parce que le chasseur assigné est débordé, soit parce qu'il ne trouve pas de biens adaptés. Dans le système hérité, ce mandat s'endort silencieusement jusqu'à atteindre l'échéance contractuelle de 6 mois fixée par l'énoncé : le client déçu résilie, et l'agence perd définitivement la commission.
   * *Mécanisme de réaffectation :* Grâce aux alertes visuelles sous Power BI et au suivi de la vue `v_mandat` (alerte automatique à J-30), la direction détecte immédiatement les mandats sans activité. Le manager peut alors **retirer le mandat au chasseur inactif pour le réaffecter à un autre collaborateur disponible**, qui réactive les visites avant expiration. Récupérer ne serait-ce que 2 ventes par an ainsi sauvées représente **+30 000 € de CA**.
   * **Par prudence, ces +30 000 € ne sont pas comptés dans le total** : ils recoupent en partie le levier 1. Seul le levier suivant est retenu dans le chiffrage.
2. **Optimisation dynamique du barème d'honoraires :**
   * Chasse Immo rémunère ses chasseurs (indépendants RSAC) via un barème variable multi-critères (taux de transformation, exclusivité, délai de conversion, nombre de visites).
   * Sans système décisionnel, la direction navigue à l'aveugle : elle ne sait pas quels leviers de rémunération motivent réellement les chasseurs.
   * Grâce aux dimensions d'analyse du datamart, la direction affine les paliers de commissions (par exemple en valorisant davantage les mandats exclusifs qui se vendent 2 fois plus vite). Cet ajustement motive les chasseurs tout en optimisant la marge brute conservée par l'entreprise (**+27 000 € nets estimés**, seul montant retenu pour ce levier).
   * **Nature de ce montant : une hypothèse non démontrée par un calcul.** Il manque l'assiette (honoraires annuels), le volume de ventes concerné, la marge actuelle et l'effet attendu du changement de barème. Ces éléments sont à construire avec la direction pendant le pilote (§7.5), à partir des indicateurs de l'entrepôt. Le montant se lit comme un ordre de grandeur, testé par le scénario « gains divisés par deux » du §6.3.

#### 4. BÉNÉFICE FINANCIER GLOBAL IMMÉDIAT (Année 1) : **117 000 €**

Trois natures de gains, à ne pas additionner sans le dire :

| Nature | Levier | Montant | Comment il devient un bénéfice pour l'entreprise | Preuve attendue |
|---|---|:---:|---|---|
| **Gain commercial estimé** | 2 — ventes supplémentaires par la productivité des chasseurs | 45 000 € | 5 ventes de plus par an grâce au temps rendu au terrain (72 mandats par an, taux de transformation 20 % → 27 % : hypothèses), dont l'entreprise conserve 60 % des honoraires | pilote §7.5 : temps de recherche, visites et mandats par semaine, avant et après |
| **Gain monétaire estimé** | 3 — pilotage du barème | 27 000 € | marge conservée sur les honoraires grâce à un barème mieux réglé ; calcul à construire (assiette, volume, effet) | indicateurs de l'entrepôt la première année |
| **Risque évité** | 1 — sécurisation du chiffre d'affaires | 45 000 € | honoraires qui ne sont plus contestables parce que l'échéance des mandats est suivie | contestations reçues et ventes sous mandat échu, mesurées la première année |
| **Total des gains estimés de l'année 1** | | **117 000 €** | dont gains d'exploitation (leviers 2 et 3) : **72 000 €** | |

Les gains d'exploitation couvrent à eux seuls le coût total de la première année (72 000 € contre 65 469 €) : c'est le scénario « sans le levier 1 » du §6.3 (ROI an 1 de +10,0 %). Ce scénario n'est pas encore une preuve de rentabilité : il repose sur des ventes supplémentaires sous hypothèse et sur un montant non calculé. C'est pourquoi la décision de généralisation après le pilote (§7.5) conditionne la suite, et pourquoi le §6.3 teste des gains divisés par deux.

#### 5. Valeur Stratégique d'Optionnalité & Économies d'Échelle M&A (Croissance Externe Internationale)

Une question stratégique majeure pour la Direction Générale concerne la capacité du nouveau SI à **absorber rapidement les données d'entreprises cibles étrangères** dans le cadre de futures opérations de fusions-acquisitions (*M&A / External Growth* vers les 9 pays européens ciblés en Phase 3) :

* **Principe de prudence financière (Doctrine RNCP7 & DAF) :**  
  Ces gains de facilitation ne sont **délibérément pas comptabilisés dans le calcul du ROI de l'année 1 (78,7 %)** ni dans le point mort (6,7 mois). En finance d'entreprise, intégrer des flux d'acquisitions futures non encore signées affaiblirait la crédibilité de l'audit. Le business case d'ingénierie doit prouver sa rentabilité sur le périmètre certain à T0.
* **Chiffrage de l'Évitement de Coût d'Intégration (*Post-Merger Integration - PMI Cost Avoidance*) :**  
  * *Avec le SI hérité :* L'ingestion des bases de données hétérogènes d'une société cible étrangère (formats propriétaires, absence de normalisation géographique, pas de multi-devises) aurait imposé 6 à 9 mois de développements spécifiques d'urgence et une refonte complète du backend, pour un surcoût externe estimé entre **50 000 € et 80 000 € par opération de rachat**.
  * *Avec l'Architecture Cible Option B (socle v8.41) :* La base intègre nativement les standards internationaux :
    * Codes pays normalisés **ISO 3166-1 alpha-2** (`code_iso_pays`) et devises **ISO 4217** (`devise` : EUR, CHF, GBP...). La langue et la conformité par pays restent à modéliser (CDC v3.0, PO-6).
    * Architecture découplée avec **sas d'ingestion staging** (ETL/ELT) permettant de mapper n'importe quelle source externe (fichiers plats, bases SQL tierces, API de portails européens) vers le modèle 3FN sans altérer le transactionnel français.
  * **Économie nette d'intégration par rachat :** Le délai d'intégration technique est divisé par 4 (réduit à 2 à 3 semaines de paramétrage ETL par l'équipe interne), générant une **économie d'intégration directe de 35 000 € à 50 000 € par société étrangère rachetée**.
* **Accélération du *Time-to-Value* :** Les données des filiales internationales sont consolidées dans le datamart OLAP et restituées dans le rapport Power BI Direction (KPI-5) dès le premier mois post-acquisition, permettant un pilotage unifié de la rentabilité du groupe.

---

### 6.3 Rentabilité, point mort & analyse de sensibilité

#### 1. Ratios du scénario central

En intégrant l'intégralité du TCO de l'année 1 (CAPEX de 53 201 €, provision et dépenses ponctuelles incluses, + OPEX sourcé de 12 268 € = **65 469 €**), puis le TCO sur 3 ans (**93 790 €**) :

```
ROI (année 1)          = (Gains année 1 − TCO année 1) / TCO année 1 × 100
                       = (117 000 − 65 469) / 65 469 × 100            = 78,7 %

Point mort (payback)   = TCO année 1 / gains mensuels moyens
                       = 65 469 € / 9 750 €/mois                      = 6,71 mois ≈ 6,7 mois

ROI sur 3 ans          = (3 × gains annuels − TCO 3 ans) / TCO 3 ans × 100
                       = (351 000 − 93 790) / 93 790 × 100            = 274,2 %
```

**Pourquoi deux horizons :** le ROI de la première année supporte tout l'investissement initial ; il est donc très sensible aux hypothèses de coût. Le ROI sur 3 ans, calculé sur la même durée que le TCO, mesure la rentabilité une fois l'investissement amorti : c'est l'indicateur le plus robuste du dossier.

#### 2. Trajectoire de trésorerie après mise en production

Hypothèse prudente : l'intégralité du TCO de l'année 1 est considérée comme engagée dès le démarrage ; les gains (9 750 €/mois) courent à partir du premier mois d'exploitation.

| Mois d'exploitation | Gains cumulés | Position nette (gains − TCO an 1) |
|---|:---:|:---:|
| M+1 | 9 750 € | − 55 719 € |
| M+2 | 19 500 € | − 45 969 € |
| M+3 | 29 250 € | − 36 219 € |
| M+4 | 39 000 € | − 26 469 € |
| M+5 | 48 750 € | − 16 719 € |
| M+6 | 58 500 € | − 6 969 € |
| **M+7 — point mort franchi** | **68 250 €** | **+ 2 781 €** |
| M+12 | 117 000 € | **+ 51 531 €** |

> **Indicateur Décisionnel :** Le projet s'auto-finance en **6,7 mois d'exploitation**, même en intégrant l'ensemble des charges récurrentes, la maintenance, les dépenses ponctuelles et la provision pour aléas. La mise en production intervenant à la fin de la semaine 14 du planning (§7.1), le point mort tombe **environ 10 mois après le GO** : 3,2 mois de construction, puis 6,7 mois d'exploitation. **Ce point mort est une estimation conventionnelle** : il suppose tout le coût de l'année engagé au GO et des gains constants dès le premier mois. Avec une montée progressive des gains, plus réaliste après un pilote (aucun gain pendant les 14 semaines du projet, la moitié des gains pendant les 3 mois suivants, puis la totalité), le **temps de retour estimé est d'environ 12 mois après le GO**, et d'environ 16 mois en ne comptant que les gains d'exploitation. Pour parler d'excédent de trésorerie, il faudrait en outre que ces gains soient des encaissements ou des dépenses évitées, ce qui suppose que les ventes supplémentaires du levier 2 se réalisent (§6.2-2). À douze mois d'exploitation, l'entreprise dégage un excédent net de trésorerie de **+51 531 €** (117 000 − 65 469).

#### 3. Sensibilité aux hypothèses de gains

Le business case repose sur des hypothèses explicites mais non mesurées — 3 ventes contestées par an, 5 ventes supplémentaires par an (2 h libérées par jour et par chasseur, 72 mandats par an), +27 000 € liés au pilotage. Pour éprouver leur solidité, les gains sont soumis à trois scénarios, à coût constant :

| Scénario | Hypothèse sur les gains | Gains année 1 | ROI année 1 | Point mort | ROI sur 3 ans |
|---|---|:---:|:---:|:---:|:---:|
| Pessimiste | Gains divisés par deux (−50 %) | 58 500 € | − 10,6 % | 13,4 mois | + 87,1 % |
| Sans le levier 1 | Aucune vente contestée évitée (−45 000 €) | 72 000 € | + 10,0 % | 10,9 mois | + 130,3 % |
| **Central** | **Hypothèses du §6.2** | **117 000 €** | **+ 78,7 %** | **6,7 mois** | **+ 274,2 %** |
| Optimiste | Gains majorés de 25 % | 146 250 € | + 123,4 % | 5,4 mois | + 367,8 % |

**Lecture :** le projet est remboursé dans l'année **dès que 56,0 % des gains estimés se réalisent** (65 469 ÷ 117 000). Avec des gains divisés par deux, la première année est déficitaire (−10,6 %), mais le projet reste **rentable sur 3 ans (+87,1 %)**. L'hypothèse la plus fragile est le levier 1 (45 000 €, 38 % des gains), fondé sur un nombre de ventes contestées non mesuré : même sans lui, le ROI reste positif dès la première année (+10,0 %). Le levier 2, de même poids, repose sur un nombre de mandats par an à confirmer : c'est l'objet du pilote (§7.5).

#### 4. Sensibilité aux hypothèses de coût

| Hypothèse de coût | TCO année 1 | ROI année 1 | Point mort | ROI sur 3 ans |
|---|:---:|:---:|:---:|:---:|
| **Scénario central** (équipe interne à 350 €/j, OPEX sourcé, dépenses ponctuelles, provision de 10 %) | **65 469 €** | **+ 78,7 %** | **6,7 mois** | **+ 274,2 %** |
| Sans provision pour aléas | 60 919 € | + 92,1 % | 6,2 mois | + 293,3 % |
| OPEX doublé | 77 737 € | + 50,5 % | 8,0 mois | + 161,2 % |
| Réalisation par des prestataires, médiane 640 €/j | 106 939 € | + 9,4 % | 11,0 mois | + 159,5 % |
| Réalisation par des prestataires, haut de fourchette 730 €/j | 119 809 € | − 2,3 % | 12,3 mois | + 137,0 % |
| **Pire cas cumulé** : prestataires à 730 €/j, OPEX doublé **et** gains divisés par deux | 132 077 € | − 55,7 % | 27,1 mois | **− 7,0 %** |

**Lecture :** pris isolément, aucun aléa de coût ne rend le projet déficitaire sur 3 ans. Seul le cumul des trois hypothèses les plus défavorables y parvient (−7,0 %). C'est la limite de validité du business case, et la raison pour laquelle le mode de réalisation (§6.1-3) et la tenue des gains (KPI-1 à KPI-5) doivent être pilotés dès le lancement.

---

### 6.4 Processus d'Exploitation, Continuité d'Activité & Gouvernance IT

Pour pérenniser ces gains et garantir la conformité aux exigences RNCP40573 (Blocs de compétences BC01, BC02 et BC05), la direction technique formalise quatre processus d'exploitation industrielle. Les objectifs de continuité ci-dessous sont à aligner sur le PCA/PRA de l'équipe (R : Alexandre Kechaf · A : Thérèse Nguyen) :

#### 1. Gouvernance FinOps & Éco-conception (Green IT)
* **Budgétisation dynamique et alertes de surcoût :** Configuration de seuils d'alertes automatisés sur la console cloud (notification Slack/e-mail dès 80 % du budget mensuel consommé, et blocage d'auto-scaling d'urgence à 100 %).
* **Taggage systématique des ressources :** Toutes les ressources d'infrastructure (instances, volumes disques, buckets S3) sont étiquetées selon les axes analytiques : `env:prod|staging`, `owner:data-ia`, `service:oltp|olap|storage`.
* **Économies hors-production (*Scheduling*) :** Extinction automatique programmée des conteneurs et bases de staging/recette hors heures ouvrées (du lundi au vendredi entre 20h00 et 08h00, et week-ends complets), générant une réduction immédiate de **65 % des coûts d'infrastructure hors-production**.
* **Éco-conception logicielle (Green IT) :** Minimisation de l'empreinte carbone serveur grâce à la proscription des scans séquentiels (indexation B-Tree et GIN ciblée), au partitionnement temporel des logs d'audit et à la compression native ZSTD des flux d'ingestion.

#### 2. Stratégie de Continuité & Reprise d'Activité (PCA / PRA — Règle 3-2-1)
* **Objectifs de résilience opérationnelle :**
  * **RPO (*Recovery Point Objective*) < 1 heure :** En cas de sinistre majeur, la perte maximale de données tolérée ne peut excéder 60 minutes de transactions.
  * **RTO (*Recovery Time Objective*) < 2 heures :** Délai maximal de remise à disposition complète du service aux utilisateurs métier après déclaration d'incident.
  * **À harmoniser :** ces deux valeurs sont celles retenues par l'étude pour le chiffrage de l'option haute disponibilité. Le cahier des charges technique v1.2 fixe des objectifs différents (RPO d'une minute pour les engagements métier, RTO de 4 heures, exercice de restauration trimestriel). Les deux jeux ne décrivent pas le même scénario de panne ; le PCA/PRA (R : Thérèse Nguyen) doit fixer les objectifs donnée par donnée et scénario par scénario, et l'étude s'y alignera.
* **Mise en œuvre rigoureuse de la règle de sauvegarde 3-2-1 :**
  * **3 copies des données :** 1 base primaire de production live + 1 sauvegarde quotidienne locale + 1 copie hors site des sauvegardes. L'instance de secours de la haute disponibilité n'est **pas** une copie de sauvegarde : une suppression erronée y est répliquée à l'instant.
  * **2 supports/médias technologiques distincts :** Disques SSD NVMe blocs managés (pour la production active) et stockage objet immuable S3 (pour les archives de sauvegarde).
  * **1 copie hors site géographiquement distante :** Réplication chiffrée (AES-256 avec clé KMS dédiée) vers un second datacenter européen distant de plus de 400 km, protégeant l'entreprise contre tout sinistre régional majeur (incendie, coupure réseau opérateur).
* **Bascule automatique :** l'option haute disponibilité multi-zones de la base de production (§6.1-B) assure le basculement sans intervention humaine. C'est elle qui rend le RTO tenable avec un budget de maintenance de 1,5 j.h par mois, qui ne finance pas d'astreinte : les incidents applicatifs sont traités aux heures ouvrées.
* **Sauvegarde continue WAL (*Write-Ahead Logging*) :** Archivage temps réel des journaux de transactions PostgreSQL permettant une restauration à la seconde près (*Point-In-Time-Recovery - PITR*).
* **Exercice de restauration (*PRA Drill*) :** Test à blanc planifié tous les 6 mois dans l'étude, tous les 3 mois dans le cahier des charges technique v1.2 (fréquence à arbitrer dans le PCA/PRA) simulant un crash complet, avec validation de l'intégrité des 38 tables en moins de 90 minutes — en rejouant les batteries de tests versionnées du socle (§7.2).

#### 3. Cycle de Vie des Données (ILM) & Archivage Légal WORM
La politique de rétention et de stockage différentié (*Information Lifecycle Management*) articule trois paliers :

```
Création mandat / dossier client
        │
        │  J0 à J+90
        ▼
TIER CHAUD — SSD / S3 Standard (accès temps réel)
        │
        │  J+90 à 3 ans
        ▼
TIER TIÈDE — S3 Infrequent Access (coût réduit de 50 %)
        │
        ├── clôture transactionnelle ──▶ TIER FROID — S3 Glacier Vault Lock
        │                                (archivage légal WORM)
        │
        └── prospect inactif sans vente ──▶ ANONYMISATION RGPD (ADR-043)
                                            (anonymisation, et non suppression)
```

* **Tier Chaud (*Hot Storage*) :** Données transactionnelles courantes, annonces actives, photos HD en cours de consultation par les chasseurs. Hébergé sur volumes SSD managés et S3 Standard.
* **Tier Tiède (*Warm Storage*) :** Données des mandats clôturés ou suspendus depuis plus de 90 jours mais restant dans la fenêtre commerciale active (3 ans). Bascule automatique vers S3 Infrequent Access.
* **Tier Froid Immuable WORM (*Cold Storage*) :** Conservation des pièces soumises à des obligations légales de durée — registres et pièces comptables (10 ans), justificatifs LCB-FT (5 ans après la fin de la relation d'affaires) — dans un bucket S3 Glacier en mode **Vault Lock WORM (*Write Once Read Many*)**, interdisant toute altération ou suppression avant l'échéance, y compris par le compte administrateur racine (*root*). Les durées exactes par catégorie restent à confirmer par un avis juridique (CDC v3.0, hypothèses de travail).
* **Conformité RGPD automatisée :** Un job d'anonymisation, orchestré par un DAG Airflow fourni avec le socle v8.41, **anonymise — et ne supprime pas —** les comptes arrivés à échéance de conservation (ADR-043) ; le compte technique `SYS-MIGRATION` n'est jamais candidat. Le job est couvert par 7 tests automatisés, verts à la recette du 09/10/2026.

#### 4. SecOps, Maintien en Conditions Opérationnelles (MCO) & SLA
* **Engagements de Niveau de Service (SLA) :** Disponibilité garantie de **99,5 %** sur la plage d'ouverture commerciale (du lundi au samedi, 08h00 - 20h00, heures d'activité intense des chasseurs sur le terrain).
* **Fenêtre de maintenance préventive :** Plage d'intervention réservée le dimanche entre 02h00 et 04h00 pour l'application des correctifs de vulnérabilités (CVE Linux/Docker), le re-calcul des statistiques de requêtes (`ANALYZE`) et la défragmentation des index (`REINDEX`).
* **Supervision proactive & Métrologie :** Surveillance continue de l'espace disque avec seuil d'alerte à 80 % de remplissage, détection des requêtes lentes (*pg_stat_statements* > 250 ms) et monitoring des tentatives d'authentification suspectes.

---

## 7. Trajectoire de mise en œuvre, risques projets & Facteurs clés de succès

### 7.1 Découpage en phases, planning sur 14 semaines et jalons

**Pourquoi 14 semaines.** Le chiffrage du §6.1 retient 130 jours-homme, soit 32,5 jours par personne étalés sur **14 semaines calendaires** au rythme partagé formation / projet. Les jalons de la note de cadrage v1.1 (T0 + 0,5 à T0 + 4,5 semaines) exprimaient l'enchaînement initial des phases, avant chiffrage ; c'est le calendrier ci-dessous, cohérent avec le budget, qui fait foi pour le business case. La durée de chaque phase est proportionnelle à son effort au §6.1.

| Phase (effort) | S1 | S2 | S3 | S4 | S5 | S6 | S7 | S8 | S9 | S10 | S11 | S12 | S13 | S14 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1-2 · Audit, modélisation, DDL (51,4 j.h) | ■ | ■ | ■ | ■ | ■ | | | | | | | | | |
| 2b · Recette, migration, sécurisation (22,8 j.h) | | | | | | ■ | ■ | ■ | | | | | | |
| 3 · Entrepôt décisionnel, tableaux de bord (34,3 j.h) | | | | | | | | | ■ | ■ | ■ | ■ | | |
| 4 · Contrat d'API, pré-matching (21,4 j.h) | | | | | | | | | | | | | ■ | ■ |
| Conduite du changement (8 j.h, §7.5) | | | | | | | | | | | | ■ | ■ | ■ |
| Jalons | | | | | J1 | | | J2 | | | | J3 | | J4 |

| Jalon | Fin de | Livré | Critère d'acceptation | Dépendance à lever avant |
|---|---|---|---|---|
| **J1** | S5 | Socle relationnel, scripts de création | Création sans erreur ; chaque rejet de la recette refusé par la contrainte attendue | **PO-1** : socle acté par ADR |
| **J2** | S8 | Migration recettée | Zéro ligne perdue ; chaque anomalie journalisée ; tests RGPD verts | **PO-4** : registre RGPD avant toute reprise de données réelles |
| **J3** | S12 | Entrepôt et cinq indicateurs | Totaux rapprochés à l'euro près entre base de travail et entrepôt ; chargement nocturne rejouable | PO-11 (règles de rémunération, levé en v8.42) |
| **J4** | S14 | Contrat d'API, pré-matching, pilote lancé | Contrat d'API validé ; audit de sécurité passé ; seuils d'adoption du pilote fixés | Audit de sécurité externe (§6.1) |

*La phase 5 (clôture et soutenance) est propre à l'organisation de l'équipe et n'est pas valorisée. Le décommissionnement de la boîte noire A11 suit le remplacement de l'API (J4).*


> **Correspondance avec l'énoncé (CDC v3.0, PO-7) :** la note de cadrage découpe le projet en 5 phases, l'énoncé en 4. Les phases 1 à 4 se correspondent une à une (auditer l'existant, répondre au besoin actuel, absorber la croissance, réaliser le parcours futur avec l'IA) ; la phase 5 (clôture et soutenance) est propre à l'organisation de l'équipe et n'est pas valorisée au §6.1.

* **Phases 1 et 2 — Audit de l'Existant (S1 à S5, avec la modélisation) :** Cartographie du SI hérité, AMDEC, Matrice EBIOS RM, Diagnostic SWOT et Étude d'opportunité.
* **Phase 2 — Conception & Migration Relationnelle (S1 à S8, jalons J1 et J2) :** Déploiement du socle relationnel v8.43 (38 tables, 9 vues, 7 index ; PostgreSQL 18 visé, testé sous 16.15), exécution de l'ETL transactionnel en transaction unique, recette et contrôles de cohérence (`05_validation`), CDC et Registre RGPD initialisé.
* **Phase 3 — Absorber la Croissance & Décisionnel (S9 à S12, jalon J3) :** Modélisation de l'entrepôt de données en étoile (4 tables de faits, 6 dimensions), déploiement des tableaux de bord Power BI réservés aux utilisateurs internes (Direction, performance des chasseurs, Commercial) — chaque chasseur consultant ses propres indicateurs dans l'application —, dimensionnement 3V et PCA/PRA.
* **Phase 4 — Réaliser le Parcours Futur avec l'IA (S13 et S14, jalon J4) :** Réécriture de l'API RESTful (élimination définitive de la boîte noire A11), modèle de matching d'annonces et note de souveraineté/sécurité IA.
* **Phase 5 — Clôture & Préparation Soutenance (hors chiffrage) :** Préparation des dossiers individuels de soutenance du titre RNCP40573.

#### Focus Risque Critique : Qu'est-ce que l'anomalie A11 (« La boîte noire backend ») ?

L'anomalie **A11** identifiée lors de l'audit initial (Livrable 1 et Matrice EBIOS RM) représente le risque technique et opérationnel le plus dangereux pour l'entreprise :

* **Définition & Origine de la « boîte noire » :**  
  Le backend applicatif actuellement en production (API web servant l'application mobile des chasseurs et le site web client) a été développé historiquement par un prestataire unique, qui est aujourd'hui en **arrêt maladie de longue durée**. Aucun code source n'a été versé dans un dépôt Git d'entreprise, il n'existe **aucune documentation technique d'architecture**, aucune spécification d'interface (OpenAPI / Swagger), ni aucun jeu de tests automatisés.
* **Pourquoi parle-t-on de « boîte noire » (*Black Box*) ?**  
  Pour l'équipe actuelle et la direction, ce composant fonctionne de manière totalement opaque : des requêtes HTTP entrent, des enregistrements sont modifiés en base, mais **personne ne sait comment le code interne est structuré**, quelles bibliothèques obsolètes ou vulnérables sont utilisées, ni quelles règles métiers implicites y sont codées en dur.
* **La menace d'un SPOF (*Single Point of Failure*) à facteur bus = 1 :**  
  Si ce serveur tombe en panne, s'il subit une attaque informatique ou si une montée en charge corrompt les sessions, l'entreprise est incapable de corriger le bogue ou de redéployer le service. L'activité commerciale de Chasse Immo s'arrête instantanément.
* **La stratégie de remédiation en 3 temps (Éviter l'effet « big-bang ») :**  
  1. *Phase 2 (Isolement défensif) :* **Interdiction formelle de modifier le code de l'API existante.** L'ancienne API est sanctuarisée derrière un pare-feu applicatif (WAF). Elle reste **en écriture pour l'activité courante** (demandes, mandats, visites continuent d'y être saisis jusqu'à la bascule) ; seuls le compte d'extraction vers le socle cible et une copie figée pour les tests sont en lecture seule. La lecture seule complète n'intervient qu'au moment de la bascule finale (§7.3).
  2. *Phase 2b / 3 (Rétro-ingénierie & Spécification) :* Observation des flux réseau réels échangés avec les clients et chasseurs pour formaliser le contrat d'interface cible (OpenAPI 3.0 normalisé, sans dépendance à l'ancienne implémentation).
  3. *Phase 4 (Remplacement & Décommissionnement définitif) :* Réécriture complète et moderne du backend RESTful par l'équipe, raccordé nativement au socle relationnel (v8.43 à ce jour), avec tests unitaires, CI/CD et documentation vivante. L'extinction définitive de la boîte noire A11 intervient au Jalon 4.

### 7.2 Facteurs clés de succès, consolidation du modèle et gestion des risques projet
1. **Consolidation du schéma relationnel (v7 → v8.43) :** Suite aux revues d'intégrité de l'équipe (arbitrages A1 à A12 et B1 à B6, puis ADR-037 à ADR-053), la modélisation cible intègre le rattachement strict `proposition` → `mandat`, l'unicité du chasseur rémunéré par acte notarié, le gel de l'habilitation (carte T ou attestation) à la date de signature du mandat (ADR-039, ADR-046), les barèmes par tranches (`tranche_bareme`) et une rémunération figée au jour de l'acte (`remuneration_chasseur`, ADR-049).
2. **Neutralisation du risque de transition (A11) :** Le backend hérité est maintenu sous surveillance WAF défensive durant la Phase 2 : il reste en écriture pour l'activité, le compte d'extraction est en lecture seule, et il ne passe en lecture seule complète qu'à la bascule finale (§7.3). Aucune modification de code n'y est tentée jusqu'à son remplacement en Phase 4.
3. **Garantie de non-régression des données :** La reprise des 52 lignes existantes (73 anomalies journalisées) est couverte par des batteries rejouables — 48 tests de migration, un harnais de 27 cas (23 rejets de contraintes + 4 cas valides), 12 sondes d'intégrité et 7 tests RGPD —, toutes vertes à la recette du 09/10/2026.
4. **Adhésion des Chasseurs :** La transparence totale sur le calcul de la rémunération, dont toutes les composantes sont figées au jour de l'acte dans la table `remuneration_chasseur` (ADR-049), renforce la confiance des agents commerciaux. Elle ne suffit pas à garantir l'adoption : des indépendants ne s'imposent pas un outil, d'où le pilote du §7.5 (risque RB9).
5. **Risque identifié par la recette — droit à rémunération (CDC v3.0, PO-11) :** le test T-DR-01 montre que la base accepte une rémunération sous mandat non exclusif pour un bien trouvé par le client seul, ce que les règles de calcul excluent. **Avant la mise en production**, l'équipe doit soit ajouter une garde sur l'exclusivité du mandat, soit acter cette règle comme une convention de saisie dans l'ADR-049, avec l'accord du Product Owner (registre des risques, §5.4 : RB5).
6. **Suivi des risques de l'option retenue :** les neuf risques de l'option B sont suivis dans le registre du §5.4. Le plus élevé, la perte de compétences à la fin du projet (RB8), conditionne la stratégie d'approvisionnement (§6.1-3).

---

### 7.3 Stratégie de bascule & Synchronisation au fil de l'eau (Delta Load jour/semaine)

La reprise des données ne se réduit pas à une migration « one-shot » figée à la date d'audit du 25/07/2026. Pendant les phases de développement, de recette et de double-run (Phase 2 et 2b), l'activité commerciale continue de produire des flux dans le système hérité (nouvelles demandes acquéreurs, nouveaux mandats de recherche).

Pour éviter tout « effet tunnel » et garantir une bascule opérationnelle sans rupture, l'équipe adopte une **stratégie de migration à double vitesse** :

```
SI HÉRITÉ (activité courante continue)
   │
   ├── 1. Reprise initiale à froid ─────────────▶ SOCLE CIBLE v8.41
   │      52 lignes au 25/07/2026                 (schéma assaini)
   │      transcodage, nettoyage, journal              │
   │                                                   │
   └╌╌ 2. Delta load récurrent ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌▶      │
          synchronisation jour / semaine               ▼
          (rattrapage incrémental)           3. BASCULE FINALE (cut-over)
                                                dernier delta + source en
                                                lecture seule
```

1. **Reprise initiale à froid (*Initial Bulk Load*) :** Extraction, transcodage et chargement des 52 lignes historiques (10 secteurs, 24 utilisateurs, 18 mandats) vers le socle relationnel cible, en une transaction unique. Les 73 anomalies rencontrées sont journalisées avec leur motif, dont le doublon Nina Girard (ID 19) et le mandat de l'anomalie A06, rattaché par reconstitution et à valider (CDC v3.0, PO-12). **État : livré dans la v8.41.**
2. **Synchronisation incrémentale au fil de l'eau (*Delta Load* journalier / hebdomadaire) :** Script d'ingestion différentiel exécuté périodiquement (chaque nuit ou chaque fin de semaine) pour capturer les nouveaux enregistrements créés dans le SI hérité, appliquer les règles de transcodage du pipeline et alimenter la base cible. **État : à réaliser** — la mise à jour incrémentale (*upsert*) nécessaire à la reprise récurrente figure parmi les points ouverts du socle v8.41.
3. **Bascule finale à chaud (*Cut-over Day*) :** Le jour du Go-Live officiel, une ultime passe de synchronisation différentielle est exécutée (temps d'indisponibilité < 15 minutes), suivie du basculement en lecture seule de l'ancien système, avec pour critère **« zéro perte non tracée »** : toute ligne non reprise est journalisée avec son motif (CDC v3.0, PO-8).

---

### 7.4 Cadrage de périmètre : Anticipation de l'« Armoire de Dossiers » (GED numérique)

Une préoccupation légitime de la direction concerne la conservation probante des pièces justificatives (mandats signés, compromis, actes authentiques, diagnostics DPE, attestations d'identité LCB-FT). L'analyse d'opportunité pose un arbitrage de périmètre rigoureux (*Scoping MoSCoW*) pour éviter toute dérive budgétaire (*Scope Creep*) :

```
PHASE 2 — DANS LE PÉRIMÈTRE (socle v8.41)        PHASES 3 ET 4 — HORS PÉRIMÈTRE (feuille de route)
┌──────────────────────────────────────┐         ┌──────────────────────────────────────┐
│ Table document                        │ ──────▶ │ Armoire numérique (GED)               │
│ métadonnées, clé objet, URI,          │ prépare │ coffre-fort probatoire (NF Z42-013),  │
│ type MIME, taille, empreinte SHA-256  │         │ déploiement du stockage MinIO / S3    │
├──────────────────────────────────────┤         ├──────────────────────────────────────┤
│ Rattachements existants               │ ──────▶ │ Rattachement des mandats, compromis   │
│ note_avis_document (avis de visite)   │ prépare │ et actes ; signature électronique     │
│ facture_document (factures chasseur)  │         │ (API Yousign / DocuSign)              │
└──────────────────────────────────────┘         └──────────────────────────────────────┘
```

* **Dans le périmètre de la Phase 2 (socle v8.41) :** La table `document` stocke les métadonnées juridiques indispensables (type de pièce, clé objet, URI, type MIME, taille, horodatage, empreinte de contrôle SHA-256) ; les fichiers eux-mêmes sont stockés hors base, sur stockage objet (ADR-042). Elle est rattachée aux avis de visite (`note_avis_document`) et aux factures des chasseurs (`facture_document`).
* **Hors périmètre de la Phase 2 / Envisagé en Phase 3-4 (Armoire numérique complète) :** Le déploiement de l'infrastructure d'hébergement objet sécurisé (compatible S3 ; la maquette MinIO du 12/10 a montré que l'image officielle n'est plus librement distribuée et que sa console a été retirée des versions gratuites : un stockage objet managé européen est recommandé), le coffre-fort électronique à valeur probante (norme NF Z42-013), le rattachement des pièces aux mandats, compromis et actes, et l'intégration des API de signature électronique dématérialisée sont formellement séquencés en **Phase 3**.
* **Bénéfice de cet arbitrage :** Cette séparation nette garantit que le projet respecte strictement son enveloppe TCO initiale de **65 469 €** et son délai d'amortissement de **6,7 mois**, tout en prévenant toute refonte de structure lorsque l'armoire de dossiers sera raccordée.

### 7.5 Conduite du changement et adoption par les chasseurs

*Ajoutée le 13/10/2026 à la suite de la revue de l'A.* Les chasseurs sont des indépendants : leur adhésion ne se décrète pas, et un outil partiellement utilisé fausse à la fois les indicateurs et le calcul de leur rémunération (risque RB9, §5.4).

* **Pilote avant généralisation (S12 à S14).** Deux chasseurs volontaires utilisent l'outil pendant deux semaines sur leurs mandats réels, avec un **référent** joignable (un membre de l'équipe projet) et une formation courte d'une demi-journée. **Prérequis à inscrire au jalon 3 :** les fonctions nécessaires au pilote (lecture des mandats, saisie des visites et des propositions) doivent être livrées et protégées (droits par rôle, journalisation) avant S12, sur l'interface de transition ; l'API complète de la phase 4 n'est pas un prérequis, et le planning du §7.1 doit le dire fonction par fonction.
* **Indicateurs d'adoption**, suivis chaque semaine — les trois premiers sans enquête, à partir du journal de l'application et de la base :

| Indicateur | Mesure | Seuil pour généraliser |
|---|---|---|
| Usage | connexions par chasseur et par semaine | au moins 3 |
| Complétude | part des visites saisies dans l'outil le jour même | au moins 80 % |
| Activité | propositions soumises aux clients par les chasseurs pilotes | stable ou en hausse sur les 2 semaines |
| Satisfaction | questionnaire en fin de pilote : note de 1 à 5, avec motif | au moins 3,5 |

* **Décision de généralisation :** si les seuils sont atteints, déploiement aux six chasseurs ; sinon, correction des irritants relevés et second pilote.
* **Budget :** 3 j.h au CAPEX et 5 j.h prélevés sur la provision pour aléas (§5.4, §6.1), soit 8 j.h. Les montants du business case sont inchangés.
* **Lien avec les gains :** le pilote sert aussi de mesure du levier 2 (§6.2) — temps de recherche avant et après, visites par semaine.

---

## 8. Conclusion & Recommandation formelle au comité de direction

L'analyse d'opportunité est sans équivoque :
* Le SI hérité ne peut pas être conservé : il génère **110 000 € de pertes et de risques juridiques annuels** et bloque tout déploiement d'Intelligence Artificielle.
* Le rafistolage est une fausse économie qui laisserait en place un backend non documenté et une structure inapte au décisionnel.
* La refonte cible selon l'**Architecture B (socle OLTP PostgreSQL + entrepôt OLAP)** est techniquement mature — le socle v8.43 passe l'intégralité de sa recette —, avec un temps de retour estimé à 6,7 mois d'exploitation, **rentable sur 3 ans même avec des gains divisés par deux ou une réalisation par des prestataires**, et répond trait pour trait aux exigences de pilotage exprimées par le Product Owner et la direction générale.
* Ses risques sont identifiés, chacun avec un traitement et un niveau résiduel visé (§5.4), contrairement à ceux de l'option C, qui exigent une capacité d'exploitation distribuée dont l'entreprise ne dispose pas.

> **RECOMMANDATION FORMELLE : AVIS FAVORABLE (« GO ») AVEC TROIS RÉSERVES**  
> Il est recommandé au Comité de Direction de valider l'ouverture des crédits de la **Phase 2** pour lancer le déploiement du socle cible et la migration définitive des données, sous réserve de lever avant la remise les trois points bloquants du cahier des charges technique v3.0 :  
> 1. **PO-1 — Référence du modèle :** acter formellement le socle de référence en atelier ; la v8.43 (38 tables, 9 vues) est fusionnée et sa documentation alignée depuis le 15/10/2026.  
> 2. **PO-4 — Conformité RGPD :** compléter le registre RGPD et les notes transverses.  
> 3. **PO-11 — Règles de rémunération :** ajouter une garde sur l'exclusivité du mandat, ou acter la convention correspondante avec le Product Owner (§7.2-5).

---

## 9. Annexe pédagogique — Grille d'évaluation & Soutenance RNCP7

*Cette section prépare le candidat aux questions du jury pour la validation du bloc de compétences **BC02**.*

### Compétence RNCP40573 visée :
> **BC02 :** *« Analyser la problématique du client dans le cadre d'une transformation digitale et formaliser une étude d'opportunité. »*

### Questions clés et réponses types pour la soutenance :

#### Q1 : « Pourquoi avoir réalisé une Étude d'opportunité alors que le commanditaire avait déjà conscience des faiblesses de son SI ? »
> **Réponse attendue :**  
> *« Un constat de panne ne constitue pas un projet d'ingénierie. Savoir que le système actuel fonctionne mal ne dit ni combien cela coûte à l'entreprise, ni quelle est la meilleure trajectoire de sortie. L'Étude d'opportunité transforme un sentiment d'irritation métier en un dossier d'ingénieur d'affaires rigoureux : elle chiffre le coût de l'inaction (110 k€/an), compare trois options réelles au moyen d'une grille multicritère, prouve que l'Option B est rentabilisée en moins de 7 mois et fournit à la direction les éléments rationnels pour engager les investissements de la Phase 2. »*

#### Q2 : « Pourquoi avoir exclu l'Option C (Sharding / Base distribuée) alors qu'elle offre un score de 80 points et prépare l'international ? »
> **Réponse attendue :**  
> *« L'ingénieur doit concevoir une architecture que l'entreprise est réellement en mesure d'exploiter (Fitness for Purpose). Chasse Immo est une PME dont l'équipe d'exploitation est actuellement réduite à zéro suite à l'arrêt de son développeur unique. Imposer une architecture shardée distribuée nécessiterait une équipe d'infogérance 24/7 et dégraderait le matching d'IA (recherche vectorielle éclatée sur plusieurs nœuds physiques). L'Option B traite l'intégralité du besoin pour les trois ans à venir avec un PCA/PRA simple et fiable. L'Option C n'est pas abandonnée, elle est sagement séquencée pour la Phase 3 avancée. »*

#### Q3 : « En quoi un ROI de 78,7 % la première année est-il crédible dans un projet de migration de seulement 52 lignes ? »
> **Réponse attendue :**  
> *« Le ROI ne se mesure pas au nombre d'octets migrés, mais à la valeur des flux financiers protégés et des ventes supplémentaires que le temps libéré permet. Les 52 lignes initiales représentent 18 mandats dont 6 étaient juridiquement caducs, exposant l'agence à 45 k€ de contestations d'honoraires par an. Sécuriser ces honoraires par le calcul de l'échéance et rendre au terrain la moitié du temps de sourcing manuel des 6 chasseurs, soit environ 5 ventes de plus par an, génère 117 k€ de gains annuels estimés, face à un coût total de 65,5 k€ la première année, chiffré aux prix publics d'un hébergeur français, dépenses ponctuelles et provision pour aléas comprises. Et surtout, ce chiffre résiste à la critique : le projet est remboursé dans l'année dès que 56 % des gains se réalisent, et il reste rentable sur 3 ans même avec des gains divisés par deux ou une réalisation par une ESN. Seul le cumul des trois hypothèses les plus défavorables le rend déficitaire : nous l'avons calculé et nous l'affichons. Le ROI est un indicateur prospectif par nature : il porte sur des flux futurs estimés, pas sur un historique. La solidité du dossier ne tient donc pas à la valeur de 78,7 %, mais à l'analyse de sensibilité, et au fait que les gains d'exploitation couvrent seuls, sous hypothèse, le coût de l'année 1, sans compter le risque évité. »*

#### Q4 : « Quel est le lien entre le recueil des besoins du Product Owner et votre architecture décisionnelle ? »
> **Réponse attendue :**  
> *« L'atelier de cadrage avec le Product Owner (Jeff) a apporté deux arbitrages clés : d'une part, il a permis de recentrer notre modèle de données (MCD/MLD) sur le cœur de métier pour aboutir à la version cible v7, consolidée depuis jusqu'au socle v8.43, évitant une sur-spécification prématurée ; d'autre part, il a révélé le besoin vital de mesurer le funnel d'acquisition en temps réel et de suivre le décalage de trésorerie notarié (10 à 14 semaines). Si nous étions restés sur une base transactionnelle unique (Option A), chaque actualisation de dashboard Power BI viendrait consommer les ressources de la base pendant les saisies terrain des chasseurs, et ses transactions longues retarderaient le nettoyage interne de la base. C'est le besoin de reporting exprimé par le commanditaire qui a dicté la séparation physique entre l'OLTP (saisie rapide) et l'OLAP (analyse multi-dimensionnelle). »*

#### Q5 : « Comment votre étude d'opportunité intègre-t-elle les exigences sociétales et environnementales ? »
> **Réponse attendue :**  
> *« Une transformation digitale moderne ne peut pas ignorer la RSE. Dès la phase d'opportunité, nous avons intégré l'accessibilité PSH selon le RGAA 4.1, niveaux A et AA (ENF-21 à ENF-23), pour ouvrir la plateforme à tous sans refonte d'interface ultérieure. Sur le plan environnemental (ENF-24 à ENF-26), la séparation OLTP/OLAP réduit les cycles CPU inutiles en évitant les requêtes analytiques lourdes sur la base opérationnelle, complétée par des sauvegardes arbitrées par nature de donnée, des médias stockés une seule fois hors base et une indexation justifiée requête par requête. »*

#### Q6 : « Pourquoi prévoir une synchronisation au fil de l'eau pour 52 lignes, et comment gérez-vous l'armoire de dossiers légaux ? »
> **Réponse attendue :**  
> *« Les 52 lignes constituent la photographie de départ au 25/07/2026. Mais l'activité commerciale continue pendant les phases de conception et de recette ! Prévoir un pipeline de synchronisation incrémentale (delta load jour/semaine) garantit que les nouveaux mandats et demandes créés sur l'ancien système sont injectés au fil de l'eau, avec pour critère de bascule « zéro perte non tracée ». Concernant l'armoire de dossiers (GED), nous appliquons un cadrage de périmètre rigoureux : la table `document` stocke les métadonnées et l'empreinte SHA-256 en base dès la Phase 2 pour l'opposabilité juridique, tandis que le déploiement du stockage objet et du coffre-fort numérique est séquencé en Phase 3 pour ne pas alourdir le coût total de 65,5 k€ de la première année. »*

#### Q7 : « Qu'est-ce que l'anomalie A11 et pourquoi ne pas avoir réécrit l'API dès la Phase 2 ? »
> **Réponse attendue :**  
> *« L'anomalie A11 désigne l'API backend actuellement en production : c'est une "boîte noire" non documentée, sans code source versionné dans l'entreprise, dont le développeur unique est en arrêt maladie longue durée (SPOF critique). Ne pas la réécrire immédiatement en Phase 2 est un arbitrage délibéré de gestion des risques. Tenter de refondre simultanément la base de données et l'API applicative multiplierait les variables d'échec (effet "big-bang"). Notre démarche d'ingénierie sécurise d'abord les fondations — le socle (v8.43) et des données reprises avec traçabilité de chaque anomalie — tout en isolant l'ancienne API sous surveillance WAF. La réécriture propre de l'API est planifiée en Phase 4 avec une spécification OpenAPI standardisée et des tests automatisés, ce qui permet de décommissionner sereinement la boîte noire sans risquer d'interrompre l'exploitation. »*

#### Q8 : « Pourquoi ne pas inclure les gains d'ingestion des sociétés cibles rachetées à l'international dans votre calcul de ROI initial ? »
> **Réponse attendue :**  
> *« C'est un principe fondamental de rigueur financière et de prudence d'ingénieur d'affaires. À T0, les futures opérations de fusions-acquisitions (M&A) ne sont pas encore actées. Intégrer des gains hypothétiques de rachat dans le calcul du ROI de l'année 1 (78,7 %) et du point mort (6,7 mois) fausserait l'analyse en gonflant artificiellement les chiffres. Nous avons choisi de prouver la rentabilité immédiate du projet uniquement sur l'activité existante pérenne (117 k€ de gains récurrents pour 65,5 k€ de coût total la première année). En revanche, nous valorisons la facilitation d'ingestion de données étrangères comme un gain stratégique d'optionnalité (M&A Onboarding Agility) : grâce aux normes ISO 3166 pour les pays et ISO 4217 pour les devises, déjà présentes dans le socle, et aux tables de staging du pipeline ETL, chaque futur rachat fera économiser entre 35 000 et 50 000 € de coûts d'intégration tout en réduisant le délai de raccordement de 6 à 9 mois à 2 à 3 semaines. »*

#### Q9 : « Votre business case mise sur davantage de visites, alors que le barème récompense le chasseur qui en fait moins. N'est-ce pas contradictoire ? »
> **Réponse attendue :**  
> *« Non, car les deux indicateurs ne mesurent pas la même chose. Le business case raisonne sur le volume total de visites d'un chasseur sur l'ensemble de ses mandats : libéré de 2 heures de sourcing par jour, il accompagne davantage de clients. Le critère S5 du barème mesure le nombre de visites par vente, avant l'achat : il récompense la justesse du ciblage. L'objectif de la refonte est précisément d'obtenir les deux à la fois — plus de clients accompagnés, et moins de visites inutiles par vente grâce au matching. »*

#### Q10 : « Votre étude recommande un GO, alors que le cahier des charges de votre équipe liste trois points bloquants. Comment l'expliquez-vous ? »
> **Réponse attendue :**  
> *« Les deux documents ne répondent pas à la même question. L'étude d'opportunité décide s'il faut investir et dans quelle architecture : sur ce plan, aucun des trois points bloquants ne remet en cause l'Option B. Le cahier des charges, lui, vérifie la conformité de la solution avant la remise. C'est pourquoi la recommandation est un GO avec trois réserves nommées, chacune rattachée à un point ouvert et à une action précise. Un GO sans réserve aurait masqué ces risques ; un NO-GO aurait sanctionné l'architecture pour des défauts qui relèvent de la mise en conformité. »*

#### Q11 : « Pourquoi ne pas avoir confié le projet à une ESN, plus rapide et plus expérimentée ? »
> **Réponse attendue :**  
> *« Parce que le coût et le risque vont dans le même sens. Au prix du marché — 530 à 730 € par jour pour un data engineer —, le coût de la première année passerait de 65 k€ à 91, voire 120 k€, et le ROI de la première année tomberait entre +28 % et -2 %, même si le projet resterait rentable sur 3 ans. Surtout, l'anomalie A11 montre ce que coûte un SI confié à un prestataire unique sans transfert de compétences : un système que plus personne ne sait faire évoluer. Nous recommandons donc une équipe interne, avec au moins un ingénieur data qui reste pour l'exploitation, et un recours ponctuel à une ESN pour des expertises précises, assorti d'une clause de transfert de compétences. »*

#### Q12 : « Quels sont les risques de l'option que vous recommandez ? »
> **Réponse attendue :**  
> *« Nous en avons identifié neuf, évalués avec l'échelle de notre analyse EBIOS RM. Le plus élevé est transverse : la perte des compétences à la fin du projet, qui reproduirait le scénario A11 ; il se traite par le recrutement interne, complété par un relais et des procédures qu'un tiers peut suivre, car une seule personne ne supprime pas une dépendance à une personne. Un autre s'est déjà produit pendant le projet : la dérive de schéma entre la base transactionnelle et l'entrepôt, lorsque notre entrepôt a été construit sur une version périmée du socle. Nous l'avons détecté par la recette, et la parade — des vues d'interface versionnées et un test de compatibilité à chaque version — est financée par la provision pour aléas. Le neuvième, ajouté après revue, est humain : des chasseurs indépendants qui n'adopteraient pas l'outil ; il se traite par un pilote avec des seuils de généralisation. Les niveaux résiduels visés après traitement sont tous faibles ; ils restent à atteindre, puisque le recrutement, les procédures et le pilote ne sont pas encore effectifs. L'option C cumule au contraire trois risques élevés, qui ne se traitent qu'avec une équipe d'exploitation distribuée que l'entreprise n'a pas : c'est ce qui justifie son report. »*


#### Q13 : « La note de dimensionnement 3V n'est pas livrée alors qu'elle conditionne la cible. Comment défendez-vous votre recommandation ? »
> **Réponse attendue :**
> *« L'étude chiffre la phase 2 sur l'activité actuelle, et elle le dit (§6.1). La cible de l'énoncé, 5 000 mandats par semaine, relève de la phase 3 : la note 3V conditionne le dimensionnement de cette phase, pas le GO de la phase 2. Nous n'avançons pas à l'aveugle pour autant : le dossier d'architecture cible mesure déjà les requêtes représentatives sous 65 ms sur 20 000 mandats, et il a testé le partitionnement sur notre socle réel. Ce qui reste à prouver au volume de l'énoncé est écrit noir sur blanc : c'est l'objet de la note 3V. »*
---

## 10. Historique des versions

| Version | Date | Auteur | Principales modifications |
|---|---|---|---|
| 1.0 | 22/09/2026 | Matthieu Barre | Version publiée sur Confluence. |
| 1.1 | 08/10/2026 | Matthieu Barre | Complément : définition technique des options A, B et C ; notation justifiée case par case ; méthode TJM, séparation CAPEX/OPEX et TCO sur 3 ans ; démonstration des gains ; processus d'exploitation (§6.4) ; focus sur l'anomalie A11 ; annexe pédagogique. |
| 2.0 | 09/10/2026 | Matthieu Barre | Mise en cohérence avec le cahier des charges technique v3.0 (§2.4 réécrit sur ses 17 points ouverts) et avec le socle v8.41 recetté le 09/10/2026 (38 tables, 8 vues, batteries de tests) ; base de jours unifiée entre coût de l'inaction et gains (coût de l'inaction : 151,4 k€) ; annexe alignée sur le business case (57,3 k€, 101 %, 6 mois) et complétée (Q9, Q10) ; analyse de sensibilité (§6.3) ; tableau RACI aligné sur le RACI v1.1 ; statut « proposé » ; recommandation « GO avec réserves » ; mise en forme compatible Confluence. |
| 2.1 | 09/10/2026 | Matthieu Barre | Prix d'exploitation sourcés auprès d'un hébergeur réel (Scaleway, région Paris) ; licences Power BI limitées aux utilisateurs internes, les chasseurs étant extérieurs à la société ; budget d'IA du produit ; dépenses ponctuelles (environnements de construction, audit de sécurité, conduite du changement) ; provision pour aléas de 10 % ; stratégie d'approvisionnement comparant équipe interne, apprentis et prestataires (§6.1-3) ; limite de volumétrie explicitée ; grille de notation et sensibilité des pondérations (§5.2) ; registre des risques des options B et C (§5.4) ; ROI sur 3 ans et sensibilité aux coûts (§6.3) ; questions Q11 et Q12. Nouveaux indicateurs : coût total de 65,5 k€ la première année, ROI de 76 % la première année et de 268,5 % sur 3 ans, point mort à 6,8 mois. |
| 3.0 | 12/10/2026 | Matthieu Barre | Synthèse de deux pages en tête de page (format cible de la grille d'évaluation : 1 à 2 pages), l'étude complète v2.1 devenant l'annexe. Journal des décisions métier D10 à D17 sur une page dédiée. Socle v8.42 en relecture (PR #14 et #15). |
| 3.1 | 13/10/2026 | Matthieu Barre | Revue de l'A (Alexandre Kechaf, 13/10) intégrée : levier 1 requalifié en risque évité et séparé des gains d'exploitation ; levier 2 assumé comme hypothèse, avec plan de mesure ; conduite du changement (§7.5, pilote et indicateurs d'adoption, risque RB9, financée par la provision : montants inchangés) ; planning sur 14 semaines avec jalons et critères d'acceptation, réconcilié avec le chiffrage (§7.1) ; point mort exprimé par rapport au GO ; question Q13 sur la note 3V ; mise à jour du partitionnement et du stockage objet d'après le dossier d'architecture cible et la maquette MinIO ; avis d'un DPO recommandé (PO-14). |
| 3.2 | 14/10/2026 | Matthieu Barre | Revue de Thérèse Nguyen (14/10) intégrée. Corrections factuelles : argument des verrous remplacé par la concurrence de ressources ; durée de 6 mois rattachée à l'énoncé et non à la loi Hoguet ; unité des 55 % (6 des 11 mandats actifs). Options de l'étude mises en correspondance avec celles de la matrice de décision (EO / ARCH). Formulations sur le sharding ramenées à « non mesuré » ; lecture corrigée du test de sensibilité. Risques : niveaux « résiduels visés », asymétrie B / C assumée. Ordre de grandeur des coûts de ARCH-C et ARCH-D. Gains présentés en trois natures (capacité, monétaire estimé, risque évité) ; 27 000 € qualifiés d'hypothèse non calculée ; point mort présenté comme estimation conventionnelle, avec temps de retour à montée progressive (≈ 12 mois). Périmètre chiffré explicité : le backend applicatif complet est hors des 65 469 € (fourchette indicative 60 à 90 j.h). Backend hérité : lecture seule limitée au compte d'extraction. RPO/RTO et exercice de restauration à harmoniser avec le cahier des charges technique dans le PCA/PRA. Prérequis fonctionnels du pilote. Montants du business case inchangés. |
| 3.3 | 15/10/2026 | Matthieu Barre | Revue d'Angeline Gomez (PR #17, 14/10) intégrée, points B, D, E et F : références alignées sur le socle v8.43 fusionné le 15/10 (38 tables, 9 vues, 7 index ; recette rejouée ; PO-1 passe « en cours ») ; partitionnement : la réserve repose sur la sortie des unicités métier et non sur la seule reprise de données (RB6, dossier d'architecture cible v1.2) ; questions au Product Owner reformulées d'après le journal (D13 et D19 posées, D20 actée avec une question non bloquante, D18 posée à l'équipe). Point A : le gain de productivité est réexprimé en ventes supplémentaires (72 mandats par an × 7 points de transformation ≈ 5 ventes × 9 000 € de part entreprise = 45 000 €), le temps des chasseurs n'étant pas une charge de l'entreprise ; le coût de l'inaction retient le manque à gagner correspondant (45 000 €) à la place des 86 400 € de temps perdu, soit 110 000 € par an. Gains de l'année 1 : 117 000 € (dont 72 000 € d'exploitation) ; ROI an 1 78,7 %, 3 ans 274,2 % ; point mort 6,7 mois ; trajectoire de trésorerie et tableaux de sensibilité recalculés. |
