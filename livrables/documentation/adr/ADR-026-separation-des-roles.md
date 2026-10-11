# ADR-026 — Séparation des rôles confirmée après remise en cause

> ℹ️ **Texte repris du dossier de modélisation v7 (§8.3, archivé).** Toujours valable : `utilisateur` + `client` / `chasseur` / `gestionnaire`, clé primaire = clé étrangère.

**Statut :** Accepté (confirme ADR-018 et la règle R7 après un arbitrage inverse envisagé puis écarté). **Blocs :** BC01 · BC02 · Transverse RGPD. **Dates :** échange PO initial `[DATE À CONFIRMER — cf. Confluence]` ; révision après confrontation au dictionnaire complet.

**Contexte.** En cours de projet, un arbitrage rapporté de réunion PO a envisagé une **table unique** `utilisateurs` à colonnes nullable (coût de jointure jugé non justifié), en s'appuyant sur deux colonnes rôle-spécifiques identifiées à ce moment-là. La confrontation au dictionnaire complet a montré que CLIENT et CHASSEUR portent chacun **plus de dix attributs propres** (Hoguet, LCB-FT…) : l'arbitrage avait été pris sur une information incomplète.

**Décision.** La séparation stricte (`utilisateur` + `client`/`chasseur`/`gestionnaire`, PK = FK) est **confirmée**, motivée par : **RGPD** (minimisation par construction, rétention différenciée par rôle — le volet LCB-FT du client n'a pas la durée de conservation des obligations Hoguet du chasseur) et **international** (Phase 3 : obligations réglementaires divergentes par pays, ingérables en colonnes nullable).

**Conséquences.** Cohérence avec le MPD exécuté ; jointure supplémentaire sur les parcours génériques, absorbée sans problème signalé. **Méthode** : un arbitrage pris sur information incomplète doit être révisé ouvertement et la révision tracée — c'est une preuve de démarche, pas un embarras. *Action de suivi : faire valider cette confirmation en réunion PO formelle.*
