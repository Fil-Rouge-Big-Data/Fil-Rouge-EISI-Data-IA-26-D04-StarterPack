# language: fr
# Source : Readme.md — « Le parcours utilisateur actuel » > « Le chasseur », étapes 5 à 6

@chasseur @actuel
Fonctionnalité: Sélection quotidienne de biens et retour du client
  En tant que chasseur immobilier
  Je veux recevoir une sélection de biens correspondant aux critères de mes clients et suivre leurs retours
  Afin de proposer des visites ou d'ajuster la recherche jusqu'à trouver un bien pertinent

  Contexte:
    Étant donné qu'un mandat de recherche est signé avec mon client

  @selection-quotidienne
  Scénario: Le chasseur reçoit une sélection quotidienne de biens
    Quand le système traite les critères de recherche de mon client
    Alors je reçois une sélection de biens correspondant à cette recherche
    Et cette sélection peut m'être envoyée plusieurs fois par jour dans les zones tendues

  @transmission-client
  Scénario: Le chasseur transmet une sélection de biens à son client
    Étant donné que j'ai reçu une sélection de biens du système
    Quand j'effectue ma propre sélection à partir de celle du système
    Alors je transmets cette sélection à proposer à mon client

  @retour-client @alerte
  Scénario: Le chasseur reçoit une alerte lorsque le client a commenté et priorisé la sélection
    Étant donné que j'ai transmis une sélection de biens à mon client
    Quand mon client commente et priorise cette sélection
    Alors je reçois une alerte m'indiquant que le client a traité la sélection

  @engagement
  Scénario: Le chasseur engage les discussions ou organise une visite suite au retour du client
    Étant donné que mon client a commenté et priorisé la sélection et qu'un bien l'intéresse
    Quand je consulte le retour du client
    Alors je peux engager les discussions sur ce bien ou organiser sa visite

  @requalification
  Scénario: Le chasseur requalifie la recherche si aucun bien ne convient au client
    Étant donné que mon client a commenté et priorisé la sélection
    Quand aucun bien de la sélection ne convient à mon client
    Alors je requalifie la recherche
    Et une nouvelle sélection quotidienne de biens est établie sur la base des critères ajustés
