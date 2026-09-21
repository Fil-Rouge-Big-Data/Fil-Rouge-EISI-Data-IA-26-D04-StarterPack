# language: fr
# Source : Readme.md — « Le parcours utilisateur actuel » > « Le chasseur », étapes 7 à 9

@chasseur @actuel
Fonctionnalité: Rédaction de la note d'avis et gestion de l'offre d'achat
  En tant que chasseur immobilier
  Je veux investiguer sur les biens intéressant mon client puis gérer l'offre d'achat
  Afin d'accompagner mon client jusqu'à l'acceptation de son offre par le vendeur

  @note-avis
  Scénario: Le chasseur rédige une note d'avis après investigation sur un bien
    Étant donné que j'ai investigué sur un bien qui intéresse mon client
    Quand je rédige ma note d'avis
    Alors je peux y joindre des commentaires audio et des vidéos
    Et la note d'avis est mise à disposition de mon client

  @offre-prete
  Scénario: Le système présente une offre d'achat pré-remplie si le client souhaite acquérir
    Étant donné que j'ai rédigé une note d'avis sur un bien avec mes conclusions
    Quand mon client souhaite se porter acquéreur de ce bien
    Alors le système lui présente une offre d'achat pré-remplie suivant mes conclusions, notamment le montant de l'offre
    Et mon client peut compléter et signer cette offre

  @client-non-interesse
  Scénario: Le client ne souhaite pas se porter acquéreur
    Étant donné que j'ai rédigé une note d'avis sur un bien
    Quand mon client ne souhaite pas se porter acquéreur de ce bien
    Alors une nouvelle sélection quotidienne de biens est établie

  @transmission-vendeur
  Scénario: Le chasseur transmet l'offre d'achat au vendeur
    Étant donné que mon client a complété et signé une offre d'achat
    Quand je transmets cette offre au vendeur
    Alors le statut de l'offre passe en attente de réponse du vendeur

  @offre-refusee
  Scénario: L'offre d'achat est refusée par le vendeur
    Étant donné que j'ai transmis une offre d'achat au vendeur
    Quand le vendeur refuse l'offre
    Alors je peux proposer une nouvelle offre d'achat à mon client
    Et si aucune nouvelle offre n'est faite, une nouvelle sélection quotidienne de biens est établie

  @offre-acceptee @rendez-vous-notaire
  Scénario: L'offre d'achat est acceptée par le vendeur
    Étant donné que j'ai transmis une offre d'achat au vendeur
    Quand le vendeur accepte l'offre
    Alors je prends rendez-vous pour organiser la signature de l'acte authentique chez le notaire
