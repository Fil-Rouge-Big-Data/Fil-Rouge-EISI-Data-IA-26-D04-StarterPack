# ADR-027 — RG-01 : un client ne peut pas poser de commentaire privé

> ℹ️ **Texte repris du dossier de modélisation v7 (§8.4, archivé).** La contrainte (trigger `tg_commentaire_prive`) est en place. En revanche la **sécurité de lecture (RLS) n'est pas implémentée** : elle est renvoyée au chantier API REST (voir PASSATION, §9 et §10).

**Statut :** Accepté. **Blocs :** BC03 · BC05 · Transverse RGPD/sécurité.

**Contexte.** La logique métier des commentaires : le client commente **publiquement** ; le chasseur commente publiquement **ou en privé** (notes internes — condition de la franchise des débriefs, invisibles du client). L'attribut `est_prive` existait sans restriction de rôle sur l'auteur : rien n'empêchait un client de poser une note privée, cas sans objet métier et source de confusion sur la confidentialité.

**Décision.** Contrainte **C18** : un commentaire dont l'auteur est client — sans être aussi chasseur ni gestionnaire (héritage non exclusif, C1) — ne peut pas être privé. Traduction : déclencheur `tg_commentaire_prive` (écriture) + RLS en lecture. Le contrôle applicatif de l'identité passe par `SET app.user_id` en début de transaction, lu par les politiques via `current_setting('app.user_id')` — mécanisme retenu plutôt qu'un rôle PostgreSQL par utilisateur (ingérable à l'échelle) ou un contrôle purement applicatif (contournable). Le CHECK simple est impossible (la règle traverse l'héritage).

**Alternative écartée.** Deux associations distinctes par rôle (contrainte portée par le modèle) : rejetée — complexifie le schéma pour un cas que le déclencheur couvre, et casserait l'unicité de l'entité COMMENTAIRE.

**Conséquences.** Testé et validé (T20 rejeté, P4/P5 acceptés) ; le cumul de rôles (P5 : un chasseur ayant un compte client) reste couvert — c'est le rôle *effectif* qui compte, d'où le libellé précis de C18. La RLS de lecture reste à écrire une fois le mode d'authentification backend figé.
