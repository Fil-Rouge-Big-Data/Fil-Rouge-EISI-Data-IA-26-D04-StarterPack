# ADR-031 — Critères d'équipement en booléens, pas en table générique

> ⚠️ **REMPLACÉ par ADR-052 côté demande.** Les six booléens `exige_*` de `demande_version` sont devenus des préférences à 4 états `pref_*`. Les booléens côté bien (`a_*`) restent. **Collision de numéro :** `ADR-remuneration-chasseur.md` a aussi reçu le numéro *proposé* ADR-031 ; le DDL cite « ADR-031 » pour les éléments de gel de la rémunération (ce second ADR). À renuméroter : voir PASSATION, §9. Texte repris du dossier v7 (§8.8, archivé).

**Statut :** Accepté. **Blocs :** BC05 · BC01.

**Contexte.** Les critères d'équipement (ascenseur, balcon, terrasse, jardin, parking, cave) peuvent se modéliser en six booléens symétriques (côté bien et côté version de demande) ou via une table `CARACTERISTIQUE` générique + jonctions. Il n'y a **aucune donnée à migrer** : ces critères servent à reproduire les filtres des portails concurrents (type BienIci). Le PO penche booléens, au nom du « nécessaire et suffisant ».

**Décision.** **Six booléens.** Côté bien, `nullable` (`NULL` = non renseigné par la source, distinct de `false`) ; côté version, `NOT NULL DEFAULT false` (non coché = non exigé).

**Justification.** Une table générique se justifie pour des critères **nombreux, ouverts, imprévisibles**. Ici le domaine est **fermé et stable** : les portails exposent une liste arrêtée de filtres, qui bouge de une ou deux entrées par an. Dans ce cas, la table générique coûte plus qu'elle ne rapporte (matching par agrégation de jointures au lieu d'une comparaison directe, perte de la contrainte de type, ambiguïté du « absent = pas exigé ou oublié ? ») pour un seul bénéfice — ajouter un critère sans DDL — dont on n'a pas l'usage, un `ALTER TABLE ADD COLUMN … DEFAULT false` étant trivial et non bloquant.

**Alternative écartée.** Table `CARACTERISTIQUE` + jonctions bien/version : reportée comme **évolution possible si l'IA de matching est intégrée** (Phase 4) — un modèle fin pourrait exploiter des critères plus riches et ouverts. Hors périmètre actuel, tracé comme point d'évolution assumé, non comme dette.

**Conséquences.** Modèle plus simple et lisible, matching direct ; l'asymétrie nullable/NOT NULL est préservée et testée implicitement par le seed. Le choix « simple » est un choix **conscient et réversible**, défendable au jury.
