# User stories (Gherkin)

Ce dossier contient des **user stories au format Gherkin**, déduites du [`Readme.md`](../Readme.md) racine du projet (sections « Le contexte », « Le parcours utilisateur actuel » et « Le futur du parcours utilisateur »).

⚠️ Ces fichiers sont une **synthèse fonctionnelle de travail**, pas un livrable officiel du projet (voir la liste des livrables attendus dans le Readme principal et `documents utiles/`). Ils servent de point de départ pour :

* clarifier les règles métier avant modélisation (MCD/MLD) ;
* alimenter le cahier des charges technique (Phase 2) ;
* servir de base à des tests fonctionnels (Phase 4, backend/API).

## Organisation des fichiers

| Fichier | Contenu | Source (Readme.md) |
|---|---|---|
| [`00_regles_metier_mandat_remuneration.feature`](./00_regles_metier_mandat_remuneration.feature) | Règles transverses : mandat exclusif/non-exclusif, rémunération via le notaire, barème, performance | « Le contexte » |
| [`01_particulier_demande_et_compte.feature`](./01_particulier_demande_et_compte.feature) | Dépôt de la demande, affectation du chasseur, création de compte, signature du mandat | Parcours particulier, étapes 1-3 |
| [`02_particulier_recherche_et_visites.feature`](./02_particulier_recherche_et_visites.feature) | Réception des propositions, avis du chasseur, boucle de sélection | Parcours particulier, étapes 4-6 |
| [`03_particulier_offre_et_signature.feature`](./03_particulier_offre_et_signature.feature) | Offre d'achat, signature de l'acte, facturation | Parcours particulier, étapes 6-9 |
| [`04_chasseur_prise_en_charge_demande.feature`](./04_chasseur_prise_en_charge_demande.feature) | Réception/acceptation d'une demande, prise de contact, signature du mandat | Parcours chasseur, étapes 1-4 |
| [`05_chasseur_selection_quotidienne_biens.feature`](./05_chasseur_selection_quotidienne_biens.feature) | Sélection quotidienne de biens, retour client, requalification | Parcours chasseur, étapes 5-6 |
| [`06_chasseur_avis_et_offre_achat.feature`](./06_chasseur_avis_et_offre_achat.feature) | Note d'avis, offre d'achat pré-remplie, transmission au vendeur | Parcours chasseur, étapes 7-9 |
| [`07_chasseur_remuneration_et_performance.feature`](./07_chasseur_remuneration_et_performance.feature) | Facturation du chasseur, paiement, recalcul de performance, renouvellement de mandat | Parcours chasseur, étapes 10-13 |
| [`08_futur_particulier_assistance_ia.feature`](./08_futur_particulier_assistance_ia.feature) | Ajouts IA côté particulier (faisabilité, personnalisation, recommandations) | « Le futur du parcours utilisateur » — particulier |
| [`09_futur_chasseur_assistance_ia.feature`](./09_futur_chasseur_assistance_ia.feature) | Ajouts IA côté chasseur (faisabilité, dédoublonnage, pré-rédaction, vérification autonome) | « Le futur du parcours utilisateur » — chasseur |
| [`10_calcul_remuneration_chasseur.feature`](./10_calcul_remuneration_chasseur.feature) | **Algorithme de rémunération** chiffré : droit à rémunération, honoraires, score de performance, barème par tranches, modulations, arrondis, gel des valeurs | « Le contexte » + [`REGLES-CALCUL-REMUNERATION.md`](../documents%20utiles/REGLES-CALCUL-REMUNERATION.md) |

## Conventions

* Gherkin en français (`# language: fr`), avec les mots-clés `Fonctionnalité`, `Règle`, `Contexte`, `Scénario`, `Plan du Scénario`, `Exemples`, `Étant donné`, `Quand`, `Alors`, `Et`, `Mais`.
* Le mot-clé `Règle:` regroupe les scénarios sous la règle métier qu'ils illustrent (voir [`Gherkin.md`](../documents%20utiles/Gherkin.md) § 5.2). Il est utilisé dans le fichier `10`, dont la lecture des seules `Règle:` donne le résumé exécutif de l'algorithme.
* Tags `@actuel` / `@futur-ia` pour distinguer le parcours existant du parcours cible avec IA, et `@particulier` / `@chasseur` pour l'acteur concerné.
* Date de référence utilisée dans les exemples : **25 juillet 2026**, conformément à la date de référence indiquée dans le Readme principal.
* Chaque scénario reste au niveau **métier** (pas d'implémentation technique) : à affiner/compléter lors de la conception du modèle de données et de l'API.
