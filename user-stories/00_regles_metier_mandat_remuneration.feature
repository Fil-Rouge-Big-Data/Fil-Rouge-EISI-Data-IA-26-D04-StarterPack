# language: fr
# Source : Readme.md — section « Le contexte »

@regles-metier @mandat @remuneration
Fonctionnalité: Règles métier du mandat de recherche et de la rémunération
  En tant qu'entreprise de chasse immobilière
  Je veux appliquer des règles claires sur les mandats et la rémunération des chasseurs
  Afin de sécuriser la relation contractuelle avec les clients et la rétribution des chasseurs

  Contexte:
    Étant donné un particulier "Alice" ayant déposé une demande de recherche
    Et un chasseur "Bruno" affecté à cette demande

  @exclusif
  Scénario: Un mandat exclusif garantit la rémunération même en cas de découverte autonome
    Étant donné qu'Alice signe avec Bruno un mandat de recherche exclusif
    Quand Alice trouve elle-même un bien correspondant à sa recherche en dehors du dispositif du chasseur
    Et qu'elle achète ce bien
    Alors Bruno est rémunéré pour cette vente
    Et aucun autre chasseur ne peut agir pour le compte d'Alice pendant la durée du mandat

  @non-exclusif
  Scénario: Un mandat non-exclusif n'implique pas de rémunération automatique en cas de découverte autonome
    Étant donné qu'Alice signe avec Bruno un mandat de recherche non-exclusif
    Quand Alice trouve elle-même un bien correspondant à sa recherche sans l'intervention de Bruno
    Et qu'elle achète ce bien
    Alors Bruno peut ne pas être rémunéré pour cette vente

  @non-exclusif
  Scénario: Un mandat non-exclusif permet à un autre chasseur d'agir pour le même client
    Étant donné qu'Alice a signé avec Bruno un mandat de recherche non-exclusif
    Quand Alice signe un second mandat non-exclusif avec un chasseur "Chloé" d'une autre agence
    Alors Bruno et Chloé peuvent tous deux agir pour le compte d'Alice
    Et la vente finale rémunère le chasseur à l'origine de la transaction aboutie

  @duree-mandat
  Scénario: La durée de validité du mandat est de 6 mois, renouvelable
    Étant donné qu'Alice signe un mandat de recherche le "2026-02-25"
    Alors la date de fin de validité du mandat est le "2026-08-25"
    Et le mandat peut être renouvelé à l'échéance si aucune vente n'a abouti

  @remuneration @notaire
  Scénario: La rémunération de l'entreprise est collectée par le notaire lors de la signature de l'acte authentique
    Étant donné qu'Alice se porte acquéreuse d'un bien pour un montant donné
    Et que le notaire a connaissance du mandat de recherche signé avec Bruno
    Quand l'acte authentique d'achat est signé devant notaire
    Alors le notaire collecte, en plus du montant de l'achat, un montant fixe et un pourcentage du montant de l'achat pour le compte de l'entreprise
    Et ce montant sert de base de calcul à la rémunération de l'entreprise et du chasseur

  @bareme
  Scénario: Le barème de commission d'un chasseur dépend du montant du projet, de son ancienneté et de sa performance
    Étant donné un barème de commission défini par tranches de montant
    Et que ce barème varie dans le temps et selon le chasseur
    Quand la rémunération de Bruno est calculée pour une vente d'un montant donné
    Alors la part reversée à Bruno correspond à la tranche du barème en vigueur applicable à ce montant, à cette date, pour ce chasseur

  @performance
  Plan du Scénario: La performance d'un chasseur est recalculée à partir de critères définis
    Étant donné les indicateurs suivants pour Bruno : "<critere>"
    Quand les indicateurs de performance de Bruno sont recalculés
    Alors le critère "<critere>" est pris en compte dans le calcul de la performance

    Exemples:
      | critere                                                              |
      | délai entre la signature du mandat et l'achat effectif (arrondi à la semaine inférieure) |
      | caractère exclusif ou non du mandat                                  |
      | nombre de ventes réussies                                            |
      | nombre de mandats signés                                             |
      | nombre de visites effectuées avant achat (moins il y en a, plus la rémunération monte) |
