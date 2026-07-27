# 👥 RACI — qui fait quoi sur chaque tâche

> **Fiche de cours + modèle.** Une matrice RACI clarifie, pour chaque tâche d'un projet, **le rôle exact de chaque personne**. Elle évite les deux plaies classiques : « je croyais que c'était toi qui le faisais » et « pourquoi personne ne m'a demandé mon avis ? ». Dans ce projet, elle relève du pilotage — bloc **BC02** (voir [`TRACABILITE-COMPETENCES.md`](./TRACABILITE-COMPETENCES.md)).

## À quoi ça sert

Sur un projet à plusieurs, la même tâche peut impliquer plusieurs personnes à des titres différents : l'une la fait, une autre en répond devant le client, d'autres doivent être consultées ou simplement tenues au courant. La RACI met tout ça noir sur blanc, **une ligne par tâche, une colonne par personne**.

## Les 4 lettres

| Lettre | Signifie | Rôle |
| --- | --- | --- |
| **R** | *Responsible* — **Réalise** | Fait le travail concrètement. Peut être plusieurs personnes. |
| **A** | *Accountable* — **Autorité / rend des comptes** | Valide et assume le résultat. **Une seule** par tâche. |
| **C** | *Consulted* — **Consulté** | Donne un avis avant/pendant (échange à double sens). |
| **I** | *Informed* — **Informé** | Est tenu au courant du résultat (sens unique). |

## Les règles d'or

* **Exactement un A par ligne.** Deux « A », c'est deux capitaines : personne ne tranche. Zéro « A », personne n'assume.
* **Au moins un R par ligne.** Sinon la tâche n'est faite par personne.
* **R et A peuvent être la même personne** (elle fait ET assume) — courant sur un petit binôme.
* **Ne pas sur-consulter.** Trop de « C » paralyse. Consulté = son avis change la décision ; sinon, c'est juste « I ».
* **C = dialogue, I = notification.** Ne pas confondre : on *consulte* avant de décider, on *informe* une fois décidé.

## Comment on la remplit, pas à pas

1. **Lister les tâches** en lignes (les grandes étapes ou livrables du projet).
2. **Lister les personnes / rôles** en colonnes.
3. Pour chaque tâche, se demander dans l'ordre :
   * *Qui la fait ?* → **R**
   * *Qui en répond / valide ?* → **A** (un seul !)
   * *Qui doit être consulté avant ?* → **C**
   * *Qui doit être informé après ?* → **I**
4. **Vérifier chaque ligne** : un seul A ? au moins un R ?
5. **Vérifier chaque colonne** : une personne avec « A » partout est un goulot ; une personne avec « I » partout ne sert peut-être à rien sur ce projet.

---

## Exemple de matrice RACI *(binôme + parties prenantes du projet)*

> Adaptez les rôles : ici **Éq. A** et **Éq. B** = les deux membres du binôme ; **Formateur** joue le commanditaire/expert ; **Jury** = destinataire final.

| Tâche / Livrable | Éq. A | Éq. B | Formateur | Jury |
| --- | --- | --- | --- | --- |
| Audit de l'existant | **R/A** | C | C | I |
| Modélisation MCD cible | R | **A** | C | I |
| Script de migration SQL | **R/A** | C | I | — |
| Note de cadrage | C | **R/A** | C | I |
| Conception OLAP | R | **A** | C | I |
| Registre RGPD | **R/A** | C | C | I |
| Préparation de la soutenance | R | **R** puis **A** | C | I |

> Lecture d'une ligne : pour « Modélisation MCD cible », Éq. B **assume** (A) et valide, Éq. A **réalise** (R), le formateur est **consulté** (C), le jury sera **informé** (I) via le livrable final.

---

## Pièges fréquents à éviter

* **Plusieurs A sur une tâche** → ambiguïté de responsabilité. Tranchez.
* **Confondre C et I** → on « informe » quelqu'un qu'on aurait dû « consulter », il découvre trop tard un choix qu'il aurait orienté.
* **Une RACI figée** → elle vit avec le projet ; mettez-la à jour quand les tâches ou l'équipe changent.
* **Trop de détail** → une RACI à 40 lignes est illisible. Restez au niveau des étapes/livrables.

---

## Conclusion *(à remplir)*

_(Quelques lignes : votre répartition des rôles vous a-t-elle évité des frictions ? Qu'ajusteriez-vous ? À pouvoir expliquer à l'oral, où le jury peut demander « qui a fait quoi ».)_