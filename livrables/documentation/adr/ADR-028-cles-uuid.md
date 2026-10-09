# ADR-028 — Clés primaires en UUID

> ⚠️ **REMPLACÉ par ADR-044 (UUIDv7).** Le principe (clés UUID, fusion de bases sans collision) reste vrai ; le choix d'un UUID aléatoire généré par `gen_random_uuid()` est remplacé par des UUIDv7 ordonnés dans le temps. Conservé pour l'historique. Texte repris du dossier v7 (§8.5, archivé).

**Statut :** Accepté. **Blocs :** BC01 · BC02 · Transverse souveraineté.

**Contexte.** Le socle a d'abord été prototypé en `bigint IDENTITY` (compact, performant, testé). Mais la Phase 3 prévoit la croissance par **rachat d'entreprises** et la **fusion de leurs bases** dans le socle unique. Avec des clés séquentielles, deux bases rachetées exposent les mêmes identifiants (`1, 2, 3…`) : toute fusion impose de réattribuer les clés de l'une et de propager ces nouveaux identifiants dans toutes les FK — opération lourde, risquée, à répéter à chaque acquisition.

**Décision.** Toutes les clés primaires passent en **`uuid`**, générées par défaut via `gen_random_uuid()` (pgcrypto). Deux bases fusionnent alors sans collision par construction.

**Alternatives écartées.**

| Option | Raison du rejet |
|---|---|
| `bigint IDENTITY` seul | Collision garantie à la fusion ; réattribution de clés à chaque rachat, contraire à l'objectif de socle unifié (ADR-001) ; expose le volume d'activité en API |
| Hybride `bigint` interne + `uuid_public` exposé | Deux clés à maintenir par table, deux points de vérité, complexité dans chaque requête et chaque FK — pour un gain de performance dont on n'a pas besoin à l'échelle visée (milliers de mandats/semaine, pas milliards de lignes). N'achète pas assez pour ce qu'il complique |

**Conséquences.**
- **+8 octets par clé** et index un peu plus lourds vs bigint : marginal à cette échelle, largement compensé par l'absence de réconciliation de clés.
- **UUIDv4 (aléatoire)** en PostgreSQL 16.15 : `uuidv7()` natif (ordonné dans le temps, index moins fragmentés) n'apparaît qu'en **PostgreSQL 18**. Le jour du passage en PG 18+, on pourra basculer le `DEFAULT` vers `uuidv7()` **sans changer le type** des colonnes — la migration est non structurante. En attendant, prévoir un `VACUUM`/`REINDEX` un peu plus attentif sur les tables à forte insertion (`annonce`, `proposition`).
- Bénéfice RGPD accessoire : un UUID exposé ne fuite pas le volume (un `id=51823` révèle un compteur, un UUID non).
- **Validé à l'exécution** : les 28 tables et la batterie 20+5 tournent en UUID.
