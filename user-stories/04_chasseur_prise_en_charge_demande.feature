# language: fr
# Source : Readme.md — « Le parcours utilisateur actuel » > « Le chasseur », étapes 1 à 4

@chasseur @actuel
Fonctionnalité: Prise en charge d'une demande de recherche par le chasseur
  En tant que chasseur immobilier
  Je veux recevoir, qualifier et accepter des demandes de recherche
  Afin de démarrer un accompagnement avec un mandat de recherche signé

  @reception-demande
  Scénario: Le chasseur reçoit une demande de recherche
    Étant donné qu'un particulier a déposé une demande de recherche
    Quand le système m'affecte cette demande
    Alors je reçois une notification de demande de recherche

  @refus
  Scénario: Le chasseur n'accepte pas la demande
    Étant donné que j'ai reçu une demande de recherche
    Quand je décide de ne pas l'accepter
    Alors la demande n'est pas prise en charge par moi
    Et elle peut être réaffectée à un autre chasseur

  @acceptation @recherche-initiale
  Scénario: Le chasseur accepte la demande et consulte une recherche initiale
    Étant donné que j'ai reçu une demande de recherche
    Quand j'accepte la demande
    Alors le système m'affiche le résultat d'une recherche initiale de biens correspondant à la demande

  @prise-de-contact
  Scénario: Le chasseur prend contact avec le prospect pour fixer un rendez-vous
    Étant donné que j'ai accepté une demande de recherche
    Quand je prends contact avec le prospect
    Alors un rendez-vous est fixé, en présentiel ou en ligne

  @affinage-criteres @signature-mandat
  Scénario: Le chasseur affine les critères et fait signer le mandat de recherche
    Étant donné qu'un rendez-vous avec le prospect a eu lieu
    Quand j'affine les critères de recherche avec le prospect et lui présente des exemples de biens
    Et que je lui fais signer le mandat de recherche
    Alors les critères de recherche affinés sont enregistrés
    Et le mandat de recherche est signé et sa date de fin de validité est calculée
