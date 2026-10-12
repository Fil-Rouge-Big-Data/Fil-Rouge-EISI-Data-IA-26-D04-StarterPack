# Journal des décisions métier — D10 à D17

> **Statut du document :** proposé · **Date :** 11/10/2026 · **Rédaction :** Matthieu Barre · **Prolonge :** les décisions D1 à D9 du document de l'école (`documents utiles/REGLES-CALCUL-REMUNERATION.md`, §13).
>
> ⚠️ **Les réponses du Product Owner ci-dessous sont une SIMULATION**, rédigée le 11/10 pour préparer le point du lundi 12/10. Elles représentent la réponse la plus probable au vu de l'énoncé. Elles seront remplacées par les réponses réelles de Jeff après le point, et le statut de chaque décision passera de « simulée » à « confirmée » ou « modifiée ».

## Pourquoi ce journal

Le cahier des charges v3.0 (§10) prévoit un journal de décisions parmi les livrables. Les décisions D1 à D9 de l'école couvrent le calcul de la rémunération ; les questions ouvertes par la recette v8.41 et la revue de la PR #13 (achat hors dispositif, comptage des visites, mandat renouvelé) n'y figurent pas. Ce journal les numérote à la suite. Chaque décision est prise par l'équipe sur la base de l'énoncé, puis **présentée** au Product Owner : seules celles qui tranchent une contradiction de l'énoncé lui sont **posées** comme question (D13).

Légende des statuts : **actée** (décision de l'équipe, présentée pour information) · **posée au PO** (question, décision suspendue) · **simulée** (réponse du PO imaginée le 11/10) · **confirmée** / **modifiée** (après le point réel).

---

## Tableau de synthèse

| N° | Décision | Statut | Effet sur le modèle |
| --- | --- | --- | --- |
| D10 | Une visite = un rendez-vous ; seuls les rendez-vous avec un acquéreur comptent dans S₅ | actée, simulée : confirmée | ADR-049 §5 (requête), OLAP (phase 4) |
| D11 | Mandat exclusif + achat hors dispositif : droit ouvert, acte sans compromis, mandat clos en succès | actée, simulée : confirmée | v8.42 (ADR-053) |
| D12 | Note de visites de cet acte : visites réelles, 50 si aucune | actée, simulée : confirmée | ADR-049 §2.3, moteur de calcul |
| D13 | Mandat renouvelé : droit jugé sur la chaîne de renouvellement en vigueur, délai S₁ depuis le mandat initial | **posée au PO**, simulée : confirmée | v8.42 (garde S24 étendue, garde S26) |
| D14 | Mandat non exclusif : achat ailleurs = 0 € motivé ; via le chasseur = parcours normal | actée, simulée : confirmée | aucun (déjà le modèle) |
| D15 | Pas d'offre sans note d'avis ; la note suit une visite de reconnaissance | actée, simulée : modifiée (dérogation possible) | API (phase 4) |
| D16 | Achat hors dispositif saisi par le gestionnaire, avec source, date et justificatif ; alerte à 30 jours | actée, simulée : confirmée | v8.42 (colonnes de traçabilité), OLAP (alerte) |
| D17 | Hors périmètre : partage d'honoraires, visite accompagnée obligatoire, rendez-vous à trois | actée, simulée : confirmée | aucun (phase 4 si besoin) |
| D18 | Une chaîne de mandats aboutit à **au plus un acte** (un seul achat par recherche) | **posée à l'équipe** (revue PR #14, point B) | v8.42 : garde S24 et trigger de l'acte classique, PR suivante |
| D19 | Honoraires et marge de l'entrepôt en **HT** ; l'assiette OLTP reste celle de l'énoncé (fixe + %), dans la base du mandat | **posée au PO** (revue PR #15, point 2) | ETL : conversion selon `base_honoraires` et `taux_tva` |
| D20 | Rémunération du chasseur **seulement après encaissement** des honoraires par l'entreprise (litige = pas de paiement) | actée (règle B2/US07, jusqu'ici non contrainte) | v8.43 : garde S28, tests T36-T37 |

---

## D10 — Unité de comptage des visites (critère S₅)

- **Décision.** Une visite est **un rendez-vous** sur un bien, quel que soit le nombre de personnes présentes. Pour la note S₅ (« nombre de visites avant achat »), on compte les rendez-vous **réalisés** où au moins un **acquéreur de la demande** est présent, sur les propositions du mandat, dans les 12 mois précédant l'acte. La visite de reconnaissance du chasseur seul est enregistrée (elle porte la note d'avis) mais **ne compte pas**.
- **Source.** `.feature 10`, scénario de bout en bout : « le client a effectué 5 visites avant l'achat ». Readme, parcours du particulier, étape 5 : l'avis du chasseur vient « après que ce dernier ait effectué des visites ».
- **Alternatives écartées.** (a) Compter les lignes de `visite` : une visite en couple compte double (5 visites → 10 → note ≈ 47 au lieu de 80, soit environ 180 € de moins sur l'exemple de Bruno). (b) Compter les visites du chasseur : pénalise son travail de filtrage. (c) Ajouter une colonne `type_visite` : inutile, la nature se déduit des participants.
- **Effet.** ADR-049 §5 réécrit (v8.42) : `count(DISTINCT (id_proposition, date_visite))` avec jointure sur `demande_acquereur`. Pas de changement de schéma.
- **Réponse simulée du PO.** « D'accord. Un rendez-vous, c'est une visite. Et je ne veux pas que le chasseur soit pénalisé parce qu'il a visité avant son client. »

## D11 — Achat hors dispositif sous mandat exclusif

- **Décision.** Sous mandat exclusif, si le client achète un bien trouvé seul (en direct ou par l'agence du vendeur), le chasseur est rémunéré. L'acte est enregistré **sans compromis**, rattaché au mandat ; le mandat est **clos en succès**, pas résilié.
- **Source.** Readme l. 75 ; `.feature 00` l. 15-19 et 42-48 ; `.feature 10` l. 40.
- **Alternatives écartées.** Fabriquer une proposition fictive (fausse les scores) ; fait « vente constatée » distinct (39ᵉ table, double rattachement) ; traiter le cas hors base comme clause pénale (contraire à l'énoncé). Voir ADR-053 §2.
- **Effet.** Schéma v8.42 : `acte.id_mandat`, `ck_acte_origine`, trigger S24, `ck_mandat_vente_externe`, vues à deux chemins.
- **Réponse simulée du PO.** « C'est le contrat : exclusif veut dire payé quoi qu'il arrive. Un mandat qui finit par une vente est un succès. »

## D12 — Note de visites d'un acte hors dispositif

- **Décision.** `score_visites` se calcule avec la requête de D10 sur les visites réelles du client pendant le mandat ; si elle renvoie 0, on gèle une **note neutre de 50**.
- **Source.** Barème du `.feature 10` (2 visites → 100, 18 → 0) ; logique du critère (justesse du ciblage).
- **Alternatives écartées.** Note 0 : sanction maximale (comme 18 visites) ; « 0 visite » convertie = 100 : bonus pour un ciblage non fait. Écart entre les deux : 540 € sur l'exemple de Bruno (5 799,60 € contre 6 339,60 €).
- **Effet.** ADR-049 §2.3 et ADR-053 §5 ; règle du moteur de calcul (OLAP / applicatif), hors schéma. Ces actes sont exclus du KPI-3.
- **Réponse simulée du PO.** « Ni bonus ni malus pour un bien que le chasseur n'a pas trouvé : 50, ça me va. Mais si le client a visité dix biens avec lui avant, on les compte. »

## D13 — Mandat renouvelé : droit et délai (question posée au PO)

- **Problème.** L'exemple de bout en bout du `.feature 10` (Bruno) date l'acte du 30/07/2026 pour un mandat signé le 14/11/2025, donc échu le 14/05/2026 ; la ligne 46 du même fichier ferme le droit dans ce cas (0,00 €). L'exemple calcule pourtant 6 231,60 €. Le document de l'école (§4, l. 98) dit : « sauf renouvellement du mandat ».
- **Décision proposée.** (1) Le droit se juge sur **la chaîne de renouvellement** : il est ouvert si un mandat de la chaîne (initial ou renouvelé, filiation `id_mandat_precedent`) est en vigueur à la date de l'acte. (2) Le délai S₁ se mesure depuis la signature du **mandat initial** : c'est le délai vécu par le client, et c'est ce qui justifie une grille S₁ jusqu'à 48 semaines alors qu'un mandat simple dure 26 semaines.
- **Alternatives écartées.** Juger le droit sur le seul mandat référencé par la proposition : Bruno ne serait pas payé, contrairement à l'exemple. Mesurer S₁ depuis le mandat renouvelé : la grille au-delà de 26 semaines n'aurait plus de sens.
- **Effet.** v8.42 (mis en œuvre le 11/10, sous réserve de la confirmation du PO) : fonctions `f_chaine_mandats`, `f_mandat_en_vigueur_chaine`, `f_mandat_initial_chaine` ; garde S24 étendue à la chaîne (acte hors dispositif) ; garde S25 sur le mandat en vigueur ; nouvelle garde S26 : pas de rémunération si aucun mandat de la chaîne n'est en vigueur à la date de l'acte (`.feature 10` l. 45-50) ; re-vérification différée après modification d'un mandat ou d'un acte ; vue `v_acte_mandat` (mandat d'origine, en vigueur, initial) ; cas de Bruno ajouté en scénario valide (P9).
- **Réponse simulée du PO.** « L'exemple suppose un renouvellement, c'est un oubli dans le texte. Un chasseur qui a renouvelé son mandat et vend après est payé. Le délai, c'est celui du client : depuis le premier mandat. Je corrige l'exemple. »

## D14 — Mandat non exclusif et client qui trouve seul

- **Décision.** Si le client achète ailleurs : pas d'acte, 0 € avec le motif tracé (`type_resiliation = 'vente_externe'`). S'il trouve seul mais confie la suite au chasseur (offre, compromis) : parcours normal, rémunération.
- **Source.** Readme l. 76 (« pourra ne pas être rémunéré ») ; décision D2 de l'école (« Rien (R = 0), mais motif tracé »).
- **Alternatives écartées.** Indemnité forfaitaire (écartée par D2).
- **Effet.** Aucun : c'est le fonctionnement de la v8.41 (ADR-049).
- **Réponse simulée du PO.** « Non exclusif, pas de garantie. Mais s'il fait le boulot jusqu'au notaire, il est payé. »

## D15 — Note d'avis et visite de reconnaissance

- **Décision.** Pas d'offre sans note d'avis du chasseur sur la proposition. La note d'avis suit une visite de reconnaissance du chasseur.
- **Source.** Readme, parcours du chasseur, étapes 7 et 8 (offre « pré-remplie suivant les conclusions du chasseur ») ; parcours du particulier, étape 5.
- **Alternatives écartées.** Contrainte en base (trigger sur `offre_acquisition`) : trop rigide pour la reprise de données et les offres saisies par le client.
- **Effet.** Règle de parcours portée par l'API (phase 4). Pas de changement de schéma.
- **Réponse simulée du PO.** « L'avis avant l'offre, oui, toujours. La visite avant l'avis, c'est la règle, mais je veux pouvoir déroger : parfois le chasseur connaît déjà le bien. » → statut **modifiée** : dérogation possible, tracée par le gestionnaire.

## D16 — Détection et saisie d'un achat hors dispositif

- **Décision.** L'achat est saisi par le gestionnaire quand l'agence l'apprend, avec la **source** de l'information (client, notaire, autre), la **date** à laquelle elle l'a apprise et le justificatif joint en `document`. Le mandat exclusif contient une clause d'information du client. Une alerte signale les mandats exclusifs sans visite depuis 30 jours (signal, pas preuve).
- **Source.** Readme l. 78 (le notaire connaît le mandat et collecte) ; constat : le notaire du client n'est pas tenu de connaître le mandat.
- **Alternatives écartées.** Données publiques des ventes (DVF) : anonymisées, publiées avec des mois de retard ; à garder pour les indicateurs de faisabilité (phase 4).
- **Effet.** v8.42 : `acte.source_information`, `acte.date_connaissance` (`ck_acte_trace_hors_dispositif`). Alerte : OLAP / tableau de bord (phase 3). Notaire de l'acte hors dispositif non enregistré : le justificatif suffit.
- **Réponse simulée du PO.** « Le gestionnaire saisit, avec la preuve. L'alerte à 30 jours, je la veux sur mon tableau de bord. Pas besoin du nom du notaire si on a le courrier. »

## D17 — Hors périmètre

- **Décision.** Hors périmètre du projet : partage d'honoraires avec l'agence du vendeur ; obligation d'accompagner la visite du client ; prise de rendez-vous à trois (chasseur, client, vendeur). Ce dernier point est noté « Should » pour la phase 4 (agenda, API), avec un modèle visite + participants.
- **Source.** L'énoncé n'en parle pas ; les honoraires sont payés par l'acheteur (Readme l. 78).
- **Alternatives écartées.** Modéliser le vendeur dès maintenant : données personnelles d'un tiers, registre RGPD à compléter (PO-4), hors énoncé.
- **Effet.** Aucun. Hypothèse notée dans l'étude : « honoraires à la charge de l'acheteur, sans partage ».
- **Réponse simulée du PO.** « On ne partage pas, l'acheteur nous paie. L'accompagnement, c'est au chasseur de voir. L'agenda, plus tard. »

---

## D18 — Un seul acte par chaîne de mandats (question posée à l'équipe)

- **Problème (revue de la PR #14, Angeline Gomez).** `UNIQUE (acte.id_mandat)` n'empêche que deux actes hors dispositif : un mandat qui a déjà un acte classique (via proposition) accepte encore un acte hors dispositif, donc deux rémunérations.
- **Décision proposée.** Un mandat de recherche porte sur **un** achat : une chaîne de mandats aboutit à au plus un acte, quelle que soit son origine. Garde à ajouter dans S24 (acte hors dispositif) et dans le trigger de l'acte sur compromis.
- **Alternative écartée.** Autoriser plusieurs actes (achat de deux biens sous un même mandat) : pas dans l'énoncé, et les cinq critères du barème sont définis pour une vente par mandat.
- **Effet.** v8.42, PR suivante (avec les points A, C et D de la même revue).

## D19 — Honoraires HT ou TTC dans l'entrepôt (question posée au PO)

- **Problème (revue de la PR #15, Angeline Gomez).** L'entrepôt étiquetait « HT » des honoraires calculés dans la base du mandat (TTC à 20 % sur le jeu de test) : 9 300 € affichés pour 7 750 € HT réels, marge et taux de marge faux.
- **Décision proposée.** L'OLTP garde l'assiette de l'énoncé (fixe + % du prix) dans la base du mandat ; l'entrepôt conserve ce brut et le **convertit en HT** selon `base_honoraires` et `taux_tva` ; chiffre d'affaires, marge et taux de marge sont en HT. La rémunération gelée est réputée HT (le chasseur indépendant facture l'agence).
- **Question au PO.** L'assiette de la rémunération du chasseur est-elle le brut de l'énoncé ou les honoraires HT ? L'énoncé ne parle pas de TVA. Tant que ce n'est pas tranché, l'OLTP ne change pas.
- **Effet.** ETL et vues de l'entrepôt (PR #15), dossier OLAP §2.

## D20 — Rémunération du chasseur seulement après encaissement (12/10)

- **Problème (question de Matthieu).** Si le client conteste les honoraires d'un achat hors dispositif (enquête, décision judiciaire), la direction ne veut pas qu'une facturation du chasseur soit possible avant l'issue. La règle écrite (B2/US07 : l'encaissement des honoraires par l'entreprise est le fait générateur de la rémunération) n'était portée par **aucune contrainte** : la base acceptait une rémunération sur un acte non encaissé.
- **Décision.** Garde S28 : une rémunération n'est acceptée que si les honoraires de l'acte sont encaissés ; annuler l'encaissement d'un acte déjà rémunéré est refusé. Tant que le litige dure, l'entreprise n'encaisse pas, donc ne rémunère pas. Enregistrer la vente et tracer sa source restent possibles dès la connaissance du fait : c'est la mémoire du dossier, pas un paiement.
- **Question au PO (non bloquante).** Faut-il un état « contesté / en litige » visible sur l'acte, pour que la direction voie ces dossiers dans l'entrepôt ?
- **Effet.** v8.43 (PR #16) : triggers S28 (`tg_remuneration_encaissement`, `tg_acte_encaissement_remunere`), tests T36 et T37, ADR-053 item 4 quater.

## Décision de GO sur l'étude d'opportunité (pour information)

- **Présenté.** Recommandation « GO avec trois réserves » (PO-1, PO-4, PO-11) ; ROI 76 % la première année, 268,5 % sur 3 ans ; mode de réalisation : équipe interne.
- **Réponse simulée du PO.** « GO. Les réserves, je les connais. Mais 40 pages, personne ne les lira en comité : je veux les deux pages qui comptent, le reste en annexe. » → action : synthèse de 2 pages (grille d'évaluation : format cible 1-2 pages).

## Suites

| Action | Porteur | Échéance |
| --- | --- | --- |
| Remplacer les réponses simulées par les réponses réelles | Matthieu | après le point du 12/10 |
| Mettre en œuvre D13 (gardes S24 et S26) et la traçabilité D16 dans la v8.42 | Matthieu (PR #14) | avant le merge |
| Implémenter D10 et D12 dans l'alimentation OLAP, avec tests | Matthieu | phase 3 |
| Reporter D15 (dérogation tracée) dans le contrat d'API | équipe | phase 4 |
| Synthèse de l'étude d'opportunité en 2 pages | Matthieu | semaine du 12/10 |
