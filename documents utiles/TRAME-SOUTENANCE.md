# 🎤 Trame de soutenance — modèle

> **Fiche + modèle.** Chaque bloc du RNCP40573 se conclut par une **restitution orale** devant un jury (2 professionnels externes + 1 représentant du certificateur). Cette trame aide à structurer la présentation et à anticiper les questions. À préparer en fin de projet. Voir [`TRACABILITE-COMPETENCES.md`](./TRACABILITE-COMPETENCES.md).

## Ce que le jury évalue

Pas seulement « avez-vous produit les livrables », mais **« comprenez-vous ce que vous avez fait et pourquoi »**. La soutenance teste votre capacité à expliquer, justifier et défendre vos choix. Un livrable brillant mal défendu vaut moins qu'un livrable correct bien expliqué.

> 🧠 Règle du binôme : le jury peut désigner **qui** répond. Chaque membre doit pouvoir parler de **chaque** partie, même celle produite par l'autre.

---

## Structure de présentation suggérée

> Adaptez la durée à celle qui vous est allouée. Gardez du temps pour les questions.

1. **Le problème** _(1-2 min)_ — le contexte, l'entreprise, pourquoi le SI actuel ne suffit plus. Montrez que vous avez compris le besoin.
2. **La démarche** _(2 min)_ — comment vous avez procédé (audit → modélisation → architecture → IA), votre méthode.
3. **Les choix clés et leur justification** _(le cœur, 4-6 min)_ — vos décisions structurantes, appuyées sur vos matrices et ADR. Pour chacune : le problème, les options, le choix, la raison.
4. **La démonstration** _(2-3 min)_ — montrez du concret : le modèle, une requête, la détection d'une anomalie, la démo IA…
5. **Les arbitrages transverses** _(2 min)_ — RGPD, éco-conception, accessibilité, souveraineté IA. Le jury y est attentif.
6. **Bilan & limites** _(1 min)_ — ce qui marche, ce que vous feriez différemment, les pistes d'amélioration. Reconnaître une limite est une force, pas un aveu.

---

## Questions probables du jury (préparez vos réponses)

* Pourquoi avoir séparé OLTP et OLAP ?
* Comment garantissez-vous l'intégrité (ex. qu'un client ne soit pas un chasseur) ?
* Quelles données personnelles gérez-vous, et comment les protégez-vous ?
* Pourquoi cette fréquence de sauvegarde ?
* Comment migrez-vous sans perdre de données ?
* Que se passe-t-il si le serveur tombe ?
* Comment évitez-vous qu'une IA branchée sur la base cause des dégâts ?
* Qui a fait quoi dans le binôme ?
* Si c'était à refaire, que changeriez-vous ?

> 💡 Pour chaque choix figurant dans vos livrables, préparez la phrase « on a choisi X **parce que** Y, plutôt que Z ». C'est exactement ce que le jury veut entendre.

---

## Modèle à remplir

* **Durée allouée :** _(à confirmer)_
* **Répartition binôme à l'oral :** _(qui présente quoi)_
* **3 choix clés à défendre absolument :** _(les plus structurants)_
* **Démo prévue :** _(quoi montrer en direct, et le plan B si ça plante)_
* **Limites assumées :** _(ce que vous reconnaissez)_

---

## Conseils

* **Répétez à voix haute**, chronométrez.
* **Prévoyez un plan B** pour la démo (captures d'écran si le live échoue).
* **Ne lisez pas vos slides** : regardez le jury, racontez.
* **Assumez les limites** : « nous n'avons pas eu le temps de X, mais voici comment nous l'aurions abordé ».
* **Appuyez-vous sur vos traces** : ADR, matrices, registre RGPD sont vos preuves.

> ⚠️ Le fil-rouge insiste depuis le début sur les « traces ». La soutenance est le moment où elles paient : chaque décision documentée devient un argument.