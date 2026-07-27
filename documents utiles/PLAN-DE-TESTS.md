# ✅ Plan de tests — modèle

> **Fiche + modèle.** Tester, c'est **vérifier que le logiciel fait ce qu'il doit faire** et signaler ce qui cloche. Le bloc **BC03** l'exige explicitement (« Rédiger les scénarios de tests et les exécuter »). À produire en Phase 4. Voir [`TRACABILITE-COMPETENCES.md`](./TRACABILITE-COMPETENCES.md).

## À quoi ça sert

Sans tests, on livre à l'aveugle : on croit que ça marche. Les tests transforment cette croyance en **preuve**. Ils protègent aussi l'avenir : quand on modifiera le code, rejouer les tests garantit qu'on n'a rien cassé (non-régression).

> 🧠 Un bon test décrit : ce qu'on teste, ce qu'on fait, ce qu'on attend, et ce qu'on obtient. S'ils diffèrent, c'est un bug.

## Les deux niveaux demandés

| Type de test | Vérifie… | Exemple ici |
| --- | --- | --- |
| **Test unitaire** | une petite brique isolée (une fonction, une règle) | le calcul de commission par tranche renvoie le bon montant |
| **Test fonctionnel** | un scénario métier complet, de bout en bout | « passer une commande » crée bien mandat + décrémente + facture |

---

## Anatomie d'un cas de test

Chaque cas suit le schéma **Given / When / Then** (Étant donné / Quand / Alors) :

* **Given** (contexte) : l'état de départ. *« Étant donné un bien à 300 000 € et un barème 2,5 % »*
* **When** (action) : ce qu'on déclenche. *« Quand on calcule la commission »*
* **Then** (résultat attendu) : ce qu'on doit obtenir. *« Alors la commission = 7 500 € »*

---

## Modèle à remplir — tableau des cas de test

| ID | Type | Ce qu'on teste | Given (contexte) | When (action) | Then (attendu) | Résultat obtenu | Statut |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T01 | unitaire | calcul commission | bien 300k€, barème 2,5% | calcul commission | 7 500 € | _…_ | ⬜ |
| T02 | fonctionnel | passer une commande | stock=5, client valide | créer commande de 2 | commande créée, stock=3, facture émise | _…_ | ⬜ |
| T03 | unitaire | date_fin mandat | signature 2026-01-10 | calcul date_fin | 2026-07-10 (+6 mois) | _…_ | ⬜ |
| _…_ | | | | | | | ⬜ |

> Statut : ⬜ à faire · ✅ réussi · ❌ échoué (à corriger).

---

## Que faut-il penser à tester ?

* **Le cas nominal** : ça marche quand tout est normal.
* **Les cas limites** : valeurs extrêmes (stock = 0, budget = 0, date de fin = aujourd'hui).
* **Les cas d'erreur** : ce qui DOIT échouer (insérer un client_id qui est un chasseur → refus).
* **La non-régression** : rejouer les anciens tests après chaque modification.

---

## Méthode pas à pas

1. **Lister les règles métier** à garantir (celles du parcours utilisateur, des contraintes SQL…).
2. **Écrire un cas par règle** au format Given/When/Then.
3. **Ajouter les cas limites et d'erreur**.
4. **Exécuter** et noter le résultat obtenu.
5. **Corriger** les échecs, puis **rejouer** l'ensemble.

> ⚠️ À l'oral, montrer un plan de tests exécuté prouve la rigueur (BC03). Un logiciel « qui marche » sans tests reste une affirmation invérifiable.