# language: fr
# Source : Readme.md — « Le parcours utilisateur actuel » > « Le particulier », étapes 6 à 9

@particulier @actuel
Fonctionnalité: Offre d'achat, signature de l'acte authentique et suivi post-achat
  En tant que particulier ayant trouvé un bien qui me convient
  Je veux faire une offre d'achat et finaliser la transaction
  Afin d'acquérir mon bien immobilier et clôturer ma relation avec l'entreprise

  Contexte:
    Étant donné qu'un bien me convient dans le cadre de ma recherche

  @offre-achat
  Scénario: Le particulier fait une offre d'achat
    Quand je fais une offre d'achat sur le bien retenu
    Alors mon offre est transmise au vendeur par l'intermédiaire de mon chasseur

  @offre-refusee
  Scénario: L'offre d'achat n'est pas acceptée
    Étant donné que j'ai fait une offre d'achat sur un bien
    Quand le vendeur n'accepte pas mon offre
    Alors je reçois de nouvelles propositions de biens de la part de mon chasseur

  @offre-acceptee @signature-acte
  Scénario: L'offre d'achat est acceptée et la signature de l'acte authentique est organisée
    Étant donné que j'ai fait une offre d'achat sur un bien
    Quand le vendeur accepte mon offre
    Alors mon chasseur organise la signature de l'acte authentique chez le notaire

  @paiement-honoraires
  Scénario: Signature de l'acte authentique et paiement des honoraires
    Étant donné que la signature de l'acte authentique a été organisée
    Quand je signe l'acte authentique d'achat devant le notaire
    Alors je règle, en plus du montant de l'achat, les honoraires de l'entreprise (montant fixe + pourcentage du montant de l'achat)
    Et le notaire collecte ce montant pour le compte de l'entreprise

  @facture @fin-parcours
  Scénario: Le particulier reçoit sa facture et est invité à partager son expérience
    Étant donné que j'ai signé l'acte authentique et réglé les honoraires
    Quand la transaction est finalisée
    Alors je reçois ma facture
    Et je suis invité à parler de mon expérience
    Et je pourrai recevoir des offres régulières de services de la part de l'entreprise
