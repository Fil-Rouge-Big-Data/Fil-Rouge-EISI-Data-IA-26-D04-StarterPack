# 🔐 Registre des traitements RGPD — modèle

> **Fiche + modèle.** Le RGPD (Règlement Général sur la Protection des Données) impose de **documenter** tout traitement de données personnelles. Le registre des traitements est ce document. Exigé de façon transverse (**BC02, BC03, BC05**), il est incontournable dès qu'une base contient des données de personnes — ce qui est massivement le cas ici (identités, emails, téléphones, budgets). Voir [`TRACABILITE-COMPETENCES.md`](./TRACABILITE-COMPETENCES.md).

## Pourquoi c'est obligatoire (et attendu par le jury)

Dès qu'on stocke des informations sur des personnes physiques, la loi impose de savoir **quelles données, pourquoi, combien de temps, et qui y accède**. Ne pas le documenter est une faute — et le référentiel RNCP40573 cite explicitement le RGPD dans plusieurs blocs. Un projet qui ignore ce point se met en difficulté en jury.

> 🧠 Le principe clé : **minimisation**. On ne collecte que les données **nécessaires** à une finalité précise, on les garde le temps **nécessaire**, et pas plus.

## Le vocabulaire essentiel

* **Donnée personnelle** : toute information se rapportant à une personne identifiable (nom, email, téléphone, mais aussi un budget lié à un client identifié).
* **Donnée sensible** : catégorie particulière (santé, opinions, origine…) — normalement absente ici, mais à vérifier.
* **Finalité** : la raison précise pour laquelle on traite la donnée (ex. « gérer un mandat de recherche »).
* **Base légale** : le fondement juridique qui autorise le traitement (contrat, consentement, obligation légale, intérêt légitime).
* **Durée de conservation** : combien de temps on garde la donnée avant de l'effacer ou de l'anonymiser.

---

## Le registre (modèle à remplir)

> Une ligne par **traitement** (pas par table). Un traitement = une finalité.

| Traitement | Finalité | Données personnelles concernées | Base légale | Durée de conservation | Qui y accède |
| --- | --- | --- | --- | --- | --- |
| Gestion des mandats | Exécuter le mandat de recherche | nom, email, téléphone, budget du client | Exécution du contrat | Durée du mandat + X ans (obligations légales) | chasseur affecté, direction |
| Comptes acquéreurs | Permettre l'accès à l'espace client | nom, email, mot de passe (haché) | Contrat / consentement | Tant que le compte est actif | le client, support |
| Paiements / honoraires | Traçabilité comptable | identité, montants | Obligation légale (comptable) | 10 ans (obligation comptable) | comptabilité, direction |
| _…_ | _…_ | _…_ | _…_ | _…_ | _…_ |

---

## Points à traiter en plus du registre

* **Minimisation** : chaque donnée collectée est-elle vraiment nécessaire ? (ex. faut-il vraiment le téléphone ?)
* **Sécurité** : mots de passe hachés, accès restreints, chiffrement le cas échéant.
* **Droits des personnes** : comment un client peut-il consulter, corriger ou faire effacer ses données ?
* **Anonymisation / pseudonymisation** : indispensable avant d'exposer des données à une IA ou à un outil tiers (lien avec la note de souveraineté — voir [`SOUVERAINETE-SECURITE-IA.md`](./SOUVERAINETE-SECURITE-IA.md)).
* **Privacy by design** : penser la protection **dès la conception** du modèle, pas après coup.

---

## Méthode pas à pas

1. **Repérer toutes les données personnelles** de votre modèle cible (parcourez vos tables).
2. **Regrouper par finalité** : pourquoi chaque donnée est-elle là ?
3. **Une ligne de registre par finalité**, avec base légale et durée.
4. **Challenger chaque donnée** : nécessaire ? sinon, la retirer (minimisation).
5. **Documenter la sécurité et les droits** des personnes.

> ⚠️ À l'oral, attendez-vous à : « quelles données personnelles gérez-vous, et comment les protégez-vous ? ». Le registre est votre réponse prête.