# 🛟 PCA, PRA & plan de migration — modèle

> **Fiche + modèle.** Trois documents qui répondent à « et si ça tourne mal ? » et « comment passe-t-on de l'ancien au nouveau système ? ». Exigés au bloc **BC02** (mitigation des risques, continuité, migration). À produire en Phase 3. Voir [`TRACABILITE-COMPETENCES.md`](./TRACABILITE-COMPETENCES.md).

## Trois notions à ne pas confondre

| Sigle | Nom complet | Répond à | Moment |
| --- | --- | --- | --- |
| **PCA** | Plan de Continuité d'Activité | « comment continuer à fonctionner PENDANT un incident ? » | avant / pendant l'incident |
| **PRA** | Plan de Reprise d'Activité | « comment redémarrer APRÈS un sinistre ? » | après l'incident |
| **Plan de migration** | — | « comment passer de l'ancien SI au nouveau sans perte ? » | lors du changement de système |

> 🧠 Le PCA vise à **ne pas s'arrêter** ; le PRA vise à **repartir vite** ; le plan de migration vise à **basculer proprement**.

---

## PCA — continuité d'activité

Objectif : que le service tienne même en cas de panne. On identifie ce qui est **critique** et on prévoit des solutions de secours.

**À remplir :**
| Activité critique | Que se passe-t-il si elle s'arrête ? | Solution de continuité |
| --- | --- | --- |
| _(ex. accès aux mandats)_ | _(les chasseurs sont bloqués)_ | _(réplication, bascule serveur…)_ |
| _…_ | _…_ | _…_ |

Deux indicateurs clés à définir :
* **RTO** (Recovery Time Objective) : en combien de temps doit-on être reparti ? _(ex. 4 h)_
* **RPO** (Recovery Point Objective) : combien de données peut-on se permettre de perdre ? _(ex. 1 h — lié à la fréquence de sauvegarde)_

---

## PRA — reprise après sinistre

Objectif : redémarrer après un incident majeur (serveur détruit, corruption, cyberattaque). Repose largement sur les **sauvegardes** (lien avec la note d'éco-conception et la stratégie de sauvegarde).

**À remplir — procédure de reprise :**
1. _(ex. détecter et qualifier l'incident)_
2. _(restaurer la dernière sauvegarde saine)_
3. _(vérifier l'intégrité des données)_
4. _(remettre le service en ligne)_
5. _(communiquer aux parties prenantes)_

> Testez votre PRA : une sauvegarde jamais restaurée n'est pas une sauvegarde, c'est un espoir.

---

## Plan de migration — de l'ancien au nouveau SI

Objectif : basculer de la base héritée (`Fil_Rouge_Depart`) vers le modèle cible **sans perdre ni corrompre** de données.

**À remplir :**
| Étape | Action | Point de vigilance |
| --- | --- | --- |
| 1. Préparation | figer l'ancien schéma, sauvegarder | avoir un point de retour |
| 2. Extraction | lire les données de l'existant | gérer les anomalies (ex. le client qui est chasseur) |
| 3. Transformation | adapter au nouveau modèle | scinder utilisateurs, structurer les critères |
| 4. Chargement | insérer dans le nouveau SI | respecter l'ordre des clés étrangères |
| 5. Vérification | comparer les comptages avant/après | aucune donnée perdue |
| 6. Bascule | passer en production | prévoir un rollback |

> 💡 Stratégie de bascule à choisir : **big bang** (tout d'un coup, risqué) ou **progressive** (par lots, plus sûr). Justifiez.

---

## Méthode pas à pas

1. **PCA** : lister les activités critiques et leurs solutions de secours ; fixer RTO/RPO.
2. **PRA** : écrire la procédure de restauration à partir des sauvegardes ; la tester.
3. **Migration** : planifier extraction → transformation → chargement → vérification → bascule.
4. **Prévoir le rollback** partout : toujours pouvoir revenir en arrière.

> ⚠️ À l'oral : « que faites-vous si le serveur brûle la veille de la démo ? » — le PRA est la réponse. « Comment migrez-vous sans perdre de données ? » — le plan de migration.