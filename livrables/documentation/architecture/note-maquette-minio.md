# Maquette MinIO — stockage des documents (photos, vidéos, PDF)

> **Date :** 12/10/2026 · **Auteur :** Matthieu Barre · **Statut :** maquette validée en local — pas une implémentation
> **Met en œuvre :** ADR-042 « Stockage des médias hors base (MinIO / S3), URI seule en base » (acceptée le 05/10)

## Le principe en une phrase

La base de données ne stocke **jamais** les fichiers : elle stocke leur **fiche** (clé, adresse, taille, empreinte). Les fichiers vivent dans un serveur de stockage objet compatible S3.

```
  [chat.png]  ──dépôt──▶  MinIO, seau "documents-immo"      (le fichier)
                              │
                              ▼  clé : documents-immo/chat.png
  PostgreSQL, table document : type, clé, URI, taille, SHA-256   (la fiche)
```

## Ce que la maquette a prouvé (fait le 12/10)

| Étape | Commande | Résultat |
| --- | --- | --- |
| 1. Serveur MinIO local | `docker run -d --name minio_fil_rouge -p 9000:9000 -e MINIO_ROOT_USER=… -e MINIO_ROOT_PASSWORD=… bitnamilegacy/minio:latest` | serveur S3 sur `localhost:9000` |
| 2. Création du seau | `docker exec minio_fil_rouge mc mb local/documents-immo` | seau créé |
| 3. Dépôt d'un fichier | `docker cp …` puis `mc cp /tmp/chat.png local/documents-immo/chat.png` | objet de 2,5 Kio déposé |
| 4. Fiche en base | `INSERT INTO document (type_document, cle_objet, uri, mime_type, taille_octets, hash_sha256, libelle) VALUES ('image', 'documents-immo/chat.png', …)` | ligne créée, vérifiée par SELECT |

Le schéma v8.42 était **déjà prêt** : la table `document` (ADR-042) porte `cle_objet`, `uri`, `mime_type`, `taille_octets`, `hash_sha256`. Aucune modification de la base n'a été nécessaire.

## Pourquoi ce choix (à redire en soutenance)

- **Base légère** : elle ne transporte que du texte, pas des gigaoctets d'images ; sauvegardes rapides.
- **Intégrité** : l'empreinte SHA-256 permet de détecter un fichier altéré et de dédoublonner.
- **Compatibilité S3** : les mêmes commandes et le même code marchent avec MinIO local, un MinIO hébergé, ou un stockage objet managé (Scaleway, déjà chiffré dans l'étude d'opportunité).

## ⚠️ Constat fait pendant la maquette : risque fournisseur

- L'image Docker officielle `minio/minio` n'est **plus téléchargeable** publiquement (Docker Hub et Quay refusent l'accès).
- La **console web d'administration a été retirée** des versions gratuites de MinIO en 2025 ; tout passe par la ligne de commande `mc`.
- La maquette tourne sur `bitnamilegacy/minio`, une **archive tierce figée, sans mises à jour de sécurité** : acceptable pour une démo, pas pour la production.

**Conséquence :** le choix « MinIO auto-hébergé » de l'ADR-042 doit être réévalué pour la production. Deux options à arbitrer en atelier : stockage objet **managé** (Scaleway, cohérent avec l'OPEX de l'étude) ou MinIO **sous licence commerciale**. La règle du registre s'applique : décision à tracer par un nouvel ADR (prochain numéro libre du registre, 055 étant réservé) ou par une révision de l'ADR-042.

## Ce qui resterait pour une vraie implémentation (phase 4)

1. Dépôt des fichiers par **l'application**, pas à la main (bibliothèque S3, clés d'accès dédiées, pas le compte admin).
2. **Liens temporaires signés** pour la consultation, au lieu d'une URI publique.
3. **Sauvegarde et rétention** des seaux dans le PCA/PRA (avec Thérèse) ; purge alignée sur l'anonymisation RGPD (ADR-043).
4. Choix de production arbitré et tracé (voir ci-dessus).
