# ADR-042 — Stockage des fichiers média & note d'avis

> **Statut :** Accepté · **Date :** 2026-10-05 · **Renvoi grille :** B4 · **Sources :** US 06 (note d'avis audio/vidéo), ADR-031 (facture → document).

## 1. Contexte

L'US 06 établit que le chasseur, après investigation sur un bien, rédige une **note d'avis** à laquelle il peut joindre des **commentaires audio et des vidéos**, mise à disposition du client. L'ADR-031 (facturation) prévoit aussi un **document** rattaché à la facture. Deux questions se posaient :

1. **Où vivent les octets** des fichiers audio/vidéo ? (un fichier vidéo pèse des méga-octets)
2. **Où vit la note d'avis** dans le modèle ? (elle n'existait pas en v7)

## 2. Décision

### 2.1 Les octets ne vont jamais dans l'OLTP

On distingue le **fichier binaire** (les octets) de sa **métadonnée** (type, date, rattachement). Règle de l'art : les fichiers vont dans un **object storage**, la base ne garde qu'une **référence** (URI/clé). La table `document` ne contient donc que des métadonnées de quelques centaines d'octets, quel que soit le volume de médias.

### 2.2 Object storage : MinIO (compatible S3)

**Décision : MinIO** pour le stockage des médias.

- Compatible avec le protocole S3 → transférable sans réécriture vers Amazon S3 / GCS / Azure Blob en production cloud.
- Open-source, tourne dans un simple conteneur Docker à côté de PostgreSQL → cohérent avec l'environnement du projet.
- Dimensionné pour le besoin réel : ranger des fichiers et les retrouver par clé.

Le *où* et le *comment* précis (bucket, politique d'accès, upload signé) relèvent de la couche backend (phase applicative) ; le modèle OLTP n'en dépend pas — il ne connaît que l'`uri`.

### 2.3 Hadoop / data lake : NON maintenant, ouverture à l'international

**Hadoop et un data lake ne sont PAS retenus** pour ce besoin. Ce sont des technologies de **traitement distribué de très gros volumes analytiques** (péta-octets, calcul batch massif) — sans rapport avec le stockage opérationnel de notes vocales et de vidéos de biens d'un service de chasse immobilière. Les introduire ici serait une sur-architecture (Règle 6 : pas de techno par mode).

**Ouverture tracée :** la question d'un data lake / Hadoop pourra se reposer **à la phase internationale**, si l'accumulation de données hétérogènes multi-pays et les besoins analytiques/IA (US 08/09) le justifient alors par un besoin réel. Décision différée, non fermée.

### 2.4 Modèle de données (OLTP)

- `note_avis` : **rattachée au mandat** (`id_mandat`), pas à la demande. L'engagement contractuel naît du mandat ; une note d'avis n'est produite qu'après signature, dans le cadre contractuel. Porte le bien investigué (`id_bien`), les conclusions (`contenu`), le montant d'offre suggéré (US 06 : pré-remplit l'offre) et la date de mise à disposition du client. Unicité `(id_mandat, id_bien)` : une note par bien dans un mandat.
- `document` : métadonnée média (`type_document` ∈ audio/video/pdf/image/autre, `uri`, `libelle`, `date_ajout`).
- `document_rattachement` : liaison **polymorphe** (`id_document`, `type_cible`, `id_cible`), cibles limitées à ce que les US justifient (`note_avis`, `facture_chasseur`). Un document → N cibles, une cible → N documents (une note peut porter plusieurs vidéos).

## 3. Alternatives écartées

| Option | Rejet |
|---|---|
| Stocker les octets en `bytea` dans PostgreSQL | Fait exploser la taille de la base, ruine sauvegardes et performances OLTP. |
| Data lake / Hadoop dès maintenant | Sur-architecture pour le volume réel ; techno de l'analytique massif, pas du stockage opérationnel de fichiers. |
| `note_avis` rattachée à la demande | L'engagement est contractuel : la note naît dans le cadre du mandat, pas de la demande nue. |
| FK simple document sur chaque table porteuse | Ne gère pas « plusieurs vidéos sur une note » ; le polymorphe couvre note + facture d'un seul mécanisme. |

## 4. Conséquences

- **Positives :** OLTP léger et stable quel que soit le volume média ; portabilité S3 ; note d'avis correctement ancrée au contrat ; chaîne média minimale et extensible.
- **Coûts :** une dépendance d'infrastructure (MinIO) à opérer en phase backend ; le rattachement polymorphe n'a pas de FK stricte sur `id_cible` (compromis classique du pattern).
- **Limite tracée :** la note d'avis est rattachée au mandat, donc suppose qu'elle arrive après signature (conforme au parcours actuel). Des notes pré-mandat exigeraient une révision — non requis par les US actuelles.

## 5. Rattachement RNCP40573

| Bloc | Contribution |
|---|---|
| BC01 | Séparation octets / métadonnée tracée ; techno choisie selon le besoin réel |
| BC03 | Modèle média minimal, intègre, ancré au bon niveau (contrat) |
| BC05 | OLTP qui reste performant ; ouverture analytique différée et documentée |
