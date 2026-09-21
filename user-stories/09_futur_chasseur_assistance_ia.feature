# language: fr
# Source : Readme.md — « Le futur du parcours utilisateur » > « Le chasseur »
# Ces scénarios complètent ceux de 04_chasseur_prise_en_charge_demande.feature,
# 05_chasseur_selection_quotidienne_biens.feature, 06_chasseur_avis_et_offre_achat.feature
# et 07_chasseur_remuneration_et_performance.feature.
# Rappel (Readme.md, Phase 4) : les chasseurs-IA doivent aussi pouvoir épauler les chasseurs humains
# et opérer seuls dans les zones non couvertes physiquement.

@chasseur @futur-ia
Fonctionnalité: Assistance par IA du parcours chasseur
  En tant que chasseur immobilier (humain ou chasseur-IA)
  Je veux être assisté par le système à chaque étape de la prise en charge d'un client
  Afin de gagner en efficacité et en pertinence sur des volumes de recherche croissants

  @rapport-faisabilite
  Scénario: Le système produit un rapport de faisabilité complet à l'acceptation de la demande
    Étant donné que j'accepte une demande de recherche
    Quand le système analyse la demande
    Alors il produit un rapport de faisabilité complet de la demande
    Et il m'indique comment reformuler la demande afin de maximiser la réussite de la recherche

  @automatisation-prise-de-contact
  Scénario: La prise de contact et de rendez-vous est automatisable
    Étant donné qu'une demande de recherche a été acceptée
    Quand je choisis d'automatiser la prise de contact
    Alors le système prend contact avec le prospect et propose un rendez-vous en présentiel ou en ligne

  @affinage-assiste
  Scénario: L'affinage des critères de recherche est assisté par le système
    Étant donné que je suis en rendez-vous avec le prospect pour affiner les critères
    Quand je saisis les critères évoqués avec le prospect
    Alors le système m'assiste dans l'affinage de ces critères

  @selection-enrichie
  Scénario: La sélection quotidienne de biens est dédoublonnée, comparée et ordonnée par pertinence
    Étant donné qu'une sélection quotidienne de biens est établie pour un client
    Quand le système traite cette sélection
    Alors les doublons sont supprimés
    Et les annonces sont comparées, pré-filtrées et ordonnées suivant leur pertinence
    Et les possibilités de faire une offre en dessous du prix affiché sont pré-calculées

  @requalification-automatique
  Scénario: La requalification écarte automatiquement les biens ressemblant à ceux déjà rejetés
    Étant donné qu'un client a écarté un ou plusieurs biens de sa sélection
    Quand le système requalifie la recherche
    Alors les biens ressemblant aux biens écartés par le client sont automatiquement exclus des prochaines sélections

  @avis-pre-rediges
  Scénario: Les notes d'avis sont pré-rédigées et assistées par le système
    Étant donné que j'ai investigué sur un bien intéressant mon client
    Quand je rédige ma note d'avis
    Alors le système me propose une pré-rédaction assistée de cette note

  @offres-multiples
  Scénario: Le système propose plusieurs offres d'achat possibles selon la marge de négociation
    Étant donné que mon client souhaite se porter acquéreur d'un bien
    Quand le système évalue les possibilités de négociation sur le prix
    Alors il propose plusieurs offres d'achat (offre plus basse, offre au prix...)

  @verification-autonome-facture
  Scénario: Le système vérifie la facture du chasseur de façon autonome
    Étant donné que j'ai envoyé ma facture dans le système
    Quand le système traite ma facture
    Alors il la vérifie de façon autonome sans intervention manuelle
    Et il l'affiche comme vérifiée et conforme si aucune anomalie n'est détectée

  @conseils-renouvellement
  Scénario: Le système conseille le chasseur pour améliorer la recherche lors d'un renouvellement de mandat
    Étant donné qu'un mandat de recherche arrive à échéance sans vente aboutie
    Quand je suis invité à renouveler le mandat avec le client
    Alors le système me fournit des conseils pour améliorer la recherche
