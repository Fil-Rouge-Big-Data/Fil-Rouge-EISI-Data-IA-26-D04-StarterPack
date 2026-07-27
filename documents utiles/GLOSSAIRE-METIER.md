# 📖 Glossaire métier — chasse immobilière

> **Fiche de référence.** Le domaine de la chasse immobilière a son vocabulaire. Ce lexique évite les malentendus dans le binôme et avec le jury, et garantit que tout le monde parle de la même chose. À enrichir au fil du projet.

## Acteurs

* **Chasseur (immobilier)** : professionnel mandaté par un particulier pour lui **trouver** un bien à acheter (à ne pas confondre avec l'agent immobilier classique, qui représente le vendeur). Rémunéré par des honoraires.
* **Client / acquéreur / prospect** : le particulier qui cherche à acheter et fait appel à un chasseur. « Prospect » tant qu'il n'a pas signé de mandat, « client » ensuite.
* **Vendeur** : le propriétaire du bien recherché (hors périmètre direct du projet, mais présent dans le parcours).
* **Notaire** : officier public qui authentifie la vente et **sécurise le paiement des honoraires** pour le compte de l'entreprise.

## Le mandat

* **Mandat de recherche** : contrat par lequel un client charge un chasseur de trouver un bien. **Validité 6 mois**, renouvelable.
* **Mandat exclusif** : le client ne peut passer que par ce chasseur ; même s'il trouve seul, le chasseur est rémunéré.
* **Mandat non-exclusif** : le client peut solliciter plusieurs chasseurs ; s'il trouve seul, le chasseur peut ne pas être payé.
* **Demande / critères de recherche** : ce que le client cherche (type de bien, budget, surface, secteur, options…). Dans le modèle cible, c'est une entité structurée, distincte du mandat. La demande **évolue dans le temps** (le chasseur la remanie, le client change d'avis) : on en conserve l'**historique versionné** par mandat (date, auteur, motif de chaque changement) plutôt que de l'écraser.
* **Version de demande** : un état daté de la demande à un instant donné. Chaque modification crée une nouvelle version ; la plus récente est la version « courante ». On ne supprime jamais les précédentes.

## Le bien et sa recherche

* **Bien (immobilier)** : le logement recherché ou proposé (appartement, maison, loft…).
* **Secteur** : zone géographique de chasse (ville, quartier, code postal).
* **DPE** : Diagnostic de Performance Énergétique, note de A à G sur la consommation d'un logement. Souvent un critère de recherche.
* **T2, T3, T4…** : typologie d'un logement selon le nombre de pièces principales (T3 = 3 pièces, généralement séjour + 2 chambres).
* **Présentation / proposition** : quand un chasseur soumet un bien à un client pour une demande donnée.

## Argent

* **Honoraires** : somme perçue par l'entreprise à la signature de l'acte, = **montant fixe + pourcentage** du prix d'achat. Payée par l'acquéreur, séparément du prix du bien.
* **Commission (du chasseur)** : part des honoraires reversée au chasseur. **Variable** selon le montant, l'ancienneté et la performance du chasseur.
* **Barème de commission** : grille (par **tranches de montant**) qui détermine la commission. Variable dans le temps.
* **Acte authentique** : l'acte de vente définitif signé chez le notaire. Déclenche le paiement des honoraires.

## Performance du chasseur

Calculée notamment sur : le **délai** entre signature du mandat et achat (arrondi à la semaine inférieure), le caractère **exclusif** ou non du mandat, le **nombre de ventes réussies**, le **nombre de mandats signés**, et le **nombre de visites** avant achat.

---

> 💡 Ajoutez ici tout terme rencontré et clarifié en cours de projet. Un glossaire vivant est un signe de rigueur apprécié en jury.