# ADR-025 — Scission de responsabilité d'OBSERVATION : preuve OLTP, comparatif OLAP dérivé

> ℹ️ **Texte repris du dossier de modélisation v7 (§8.2, archivé).** Cet ADR fonde ADR-036 (critère de frontière OLTP/OLAP) et ADR-051 (scission de l'état du mandat). Toujours valable ; `FAIT_PERFORMANCE_CHASSEUR` est une piste de travail du chantier OLAP, pas une table existante.

**Statut :** Accepté. **Blocs :** BC01 · BC05.

**Contexte.** Un besoin d'affichage chasseur authentiquement analytique a émergé : comparatifs vs pairs et zones, tendances multi-périodes. Une première tentation était de migrer `observation`/`objectif` intégralement vers un OLAP. Or le dictionnaire précise que `observation.valeur` **sert de base à la rémunération variable** : c'est une preuve transactionnelle, potentiellement contentieuse.

**Décision.** `observation` et `objectif` **restent en OLTP**, inchangées (mécanisme exécuté et testé — T9, `tg_observation_periode`, C9). Un fait OLAP **dérivé**, `FAIT_PERFORMANCE_CHASSEUR`, est introduit pour le comparatif, alimenté par extraction depuis `observation` (§7).

**Alternatives écartées.**

| Option | Rejet |
|---|---|
| Migration intégrale vers l'OLAP | Ferait porter à l'OLAP une responsabilité de preuve qu'il n'est pas conçu pour garantir (un entrepôt est rejouable) ; démonte un mécanisme testé sans bénéfice pour l'usage individuel |
| Tout en OLTP, comparatifs calculés à la volée par l'API | Agrégations transversales coûteuses et répétées sur un modèle non prévu pour ça |

**Conséquences.** Duplication contrôlée (source OLTP / dérivé OLAP, jamais l'inverse) ; le mapping d'extraction est à documenter comme tout flux OLTP→OLAP ; l'API sert les deux lectures sans les mélanger. **À défendre** : la distinction entre *fait métier figé* (OLTP même s'il ressemble à un agrégat) et *besoin analytique* qui s'en nourrit sans le remplacer.
