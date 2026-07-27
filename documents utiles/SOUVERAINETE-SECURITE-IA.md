# 🛡️ Souveraineté & sécurité des données face à l'IA — modèle

> **Fiche + modèle.** Dès qu'on ouvre une base à une IA (par exemple via un serveur MCP branché sur un assistant), on prend un risque : **qui accède à quelles données, et pour en faire quoi ?** Exigé au bloc **BC05**. À produire en Phase 4, en lien direct avec la démo Tabularis + Claude du cours. Voir [`TRACABILITE-COMPETENCES.md`](./TRACABILITE-COMPETENCES.md).

## Pourquoi c'est un sujet à part entière

Brancher un modèle d'IA sur une vraie base client est puissant… et dangereux. L'IA peut lire des données personnelles, les recopier ailleurs, ou exécuter des requêtes destructrices. Le référentiel attend que vous **anticipiez** ces risques — c'est précisément l'erreur qu'un jury guette.

> 🧠 Le principe : l'IA ne devrait voir que **le strict nécessaire**, en **lecture seule**, et jamais des données personnelles **en clair** si elles ne sont pas indispensables.

## Les trois questions à traiter

### 1. Périmètre d'accès — qui voit quoi ?
* L'IA accède-t-elle à toute la base ou à une vue restreinte ?
* Privilégier un **compte en lecture seule** (l'IA lit, elle n'écrit jamais).
* Idéalement, l'IA lit l'**OLAP anonymisé**, pas la base de production (lien avec [`OLAP.md`](./OLAP.md)).

### 2. Anonymisation / pseudonymisation
* **Anonymisation** : on supprime tout moyen de ré-identifier la personne (irréversible).
* **Pseudonymisation** : on remplace les identifiants par des codes, réversibles avec une clé gardée à part.
* Avant d'exposer des données à l'IA, retirer ou masquer nom, email, téléphone quand ils ne sont pas nécessaires à la tâche.

### 3. Souveraineté / localisation
* Où les données sont-elles traitées ? Sur quel serveur, dans quel pays ?
* Un traitement hors UE peut poser problème au regard du RGPD.
* Documenter le trajet de la donnée quand elle sort du système.

---

## Modèle à remplir

### Périmètre d'accès accordé à l'IA
| Ressource | Accès accordé | Justification |
| --- | --- | --- |
| _(ex. table biens)_ | _(lecture seule)_ | _(nécessaire au matching)_ |
| _(ex. table clients)_ | _(pseudonymisée / interdite)_ | _(données personnelles)_ |
| _…_ | _…_ | _…_ |

### Mesures de protection retenues
* Compte d'accès : _(lecture seule ? droits limités ?)_
* Données masquées avant exposition : _(lesquelles ?)_
* Garde-fous techniques : _(validation des requêtes, journalisation des accès…)_

### Risques identifiés et parades
| Risque | Parade |
| --- | --- |
| L'IA exécute une requête destructrice | compte en lecture seule |
| Fuite de données personnelles | anonymisation avant exposition |
| _…_ | _…_ |

---

## Méthode pas à pas

1. **Cartographier** ce à quoi l'IA aurait besoin d'accéder (le minimum).
2. **Restreindre** : compte en lecture seule, périmètre limité.
3. **Masquer** les données personnelles non nécessaires (anonymisation/pseudonymisation).
4. **Documenter** le trajet et la localisation des données.
5. **Prévoir la journalisation** des accès pour pouvoir auditer.

> ⚠️ À l'oral : « vous branchez une IA sur vos données — comment évitez-vous la fuite ou la casse ? ». Cette note est votre réponse, et elle vous distingue nettement.