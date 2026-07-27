# 📓 Journal de décisions (ADR léger) — modèle

> **Fiche + modèle.** Un ADR (*Architecture Decision Record*, « fiche de décision d'architecture ») garde la **trace de chaque choix important** : quoi, pourquoi, quelles alternatives écartées. Le Readme du projet l'exige en filigrane : « les solutions doivent être choisies ET écartées en conscience », « quelqu'un doit pouvoir comprendre pourquoi tel choix a été fait ». Voir [`TRACABILITE-COMPETENCES.md`](./TRACABILITE-COMPETENCES.md).

## À quoi ça sert

Dans quelques semaines, vous aurez oublié **pourquoi** vous aviez choisi PostgreSQL plutôt que MySQL, ou l'étoile plutôt que le flocon. Un tiers qui rejoint l'équipe sera perdu. L'ADR résout ça : **une fiche courte par décision**, datée, qui fige le raisonnement. C'est aussi une mine d'or pour la soutenance et le Dossier Professionnel.

> 🧠 Une décision non tracée est une décision qu'on devra re-débattre. L'ADR évite de refaire dix fois le même arbitrage.

## Quand créer un ADR

Dès qu'un choix **structurant** est fait : choix de SGBD, de modélisation, d'architecture, de stratégie de sauvegarde, de gestion d'une règle métier ambiguë… Pas pour les micro-décisions : pour celles qu'on pourrait vous demander de justifier.

---

## Modèle d'une fiche de décision (à dupliquer par décision)

### ADR-XXX : _(titre court de la décision)_

* **Date :** _(JJ/MM/AAAA)_
* **Statut :** proposé / **accepté** / remplacé par ADR-YYY
* **Décideurs :** _(qui a tranché — voir RACI)_

**Contexte**
_(Quel problème ou question a mené à devoir décider ? 2-4 phrases.)_

**Options envisagées**
1. _(Option A — avantages / inconvénients)_
2. _(Option B — avantages / inconvénients)_
3. _(Option C…)_

**Décision**
_(Quelle option retenue ?)_

**Justification**
_(Pourquoi celle-ci ? Sur quels critères ? Renvoyez éventuellement à une [matrice de décision](./MATRICE-DECISION.md).)_

**Conséquences**
_(Ce que ce choix implique, y compris les inconvénients acceptés.)_

---

## Exemple rempli

### ADR-001 : Séparer OLTP et OLAP

* **Date :** 25/07/2026
* **Statut :** accepté
* **Décideurs :** binôme (voir RACI)

**Contexte** — Les projections annoncent des milliers de mandats/semaine et un besoin de pilotage. Faire l'analytique sur la base de production la ralentirait.

**Options envisagées**
1. Tout dans une seule base — simple mais non scalable.
2. OLTP + OLAP séparés — plus de travail, mais performances préservées.
3. Microservices — puissant mais prématuré.

**Décision** — Option 2 : deux bases distinctes.

**Justification** — Meilleur équilibre performance / scalabilité / sécurité sans la complexité prématurée des microservices (voir matrice de décision).

**Conséquences** — Il faut concevoir un processus d'alimentation OLTP→OLAP et gérer une fréquence de rafraîchissement (lien éco-conception).

---

## Méthode pas à pas

1. **Repérer** qu'une décision structurante se présente.
2. **Dupliquer** le modèle de fiche, lui donner un numéro (ADR-001, 002…).
3. **Remplir à chaud**, tant que le raisonnement est frais.
4. **Ne jamais effacer** un ADR : s'il est remplacé, marquer « remplacé par ADR-XXX ».

> ⚠️ À l'oral, sortir un journal de décisions impressionne : il prouve que vos choix sont réfléchis, tracés et défendables — exactement l'esprit du fil-rouge.