# language: fr
# Source : Readme.md — « Le parcours utilisateur actuel » > « Le particulier », étapes 4 à 6

@particulier @actuel
Fonctionnalité: Réception des propositions de biens et retour d'expérience du chasseur
  En tant que particulier ayant signé un mandat de recherche
  Je veux recevoir des propositions de biens et l'avis de mon chasseur après visite
  Afin d'affiner mon choix jusqu'à trouver un bien qui me convient

  Contexte:
    Étant donné que j'ai signé un mandat de recherche avec mon chasseur

  @propositions
  Scénario: Le particulier reçoit des propositions de biens et choisit ceux à visiter
    Quand mon chasseur me transmet une sélection de biens correspondant à ma recherche
    Alors je peux consulter la liste des biens proposés
    Et je peux choisir un ou plusieurs biens à faire visiter par mon chasseur

  @avis-chasseur
  Scénario: Le particulier reçoit les recommandations et avis du chasseur après visite
    Étant donné que j'ai choisi un ou plusieurs biens à visiter
    Quand mon chasseur a effectué la visite du ou des biens choisis
    Alors je reçois les recommandations et l'avis du chasseur sur chaque bien visité

  @boucle-selection
  Scénario: Aucun bien ne convient, la recherche de propositions reprend
    Étant donné que j'ai reçu les avis du chasseur sur les biens visités
    Quand aucun bien ne me convient
    Alors je reçois de nouvelles propositions de biens de la part de mon chasseur

  @bien-retenu
  Scénario: Un bien convient et le particulier est invité à le visiter ou à faire une offre
    Étant donné que j'ai reçu les avis du chasseur sur les biens visités
    Quand un bien me convient
    Alors je suis invité à visiter ce bien ou à faire directement une offre d'achat
