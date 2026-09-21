# language: fr
# Source : Readme.md — « Le futur du parcours utilisateur » > « Le particulier »
# Ces scénarios complètent ceux de 01_particulier_demande_et_compte.feature,
# 02_particulier_recherche_et_visites.feature et 03_particulier_offre_et_signature.feature.

@particulier @futur-ia
Fonctionnalité: Assistance par IA du parcours particulier
  En tant que particulier souhaitant acquérir un bien immobilier
  Je veux être guidé par des indicateurs et recommandations générés par le système
  Afin de fiabiliser ma recherche et de me sentir accompagné dès le premier contact

  @faisabilite @formulaire
  Scénario: Le système indique la faisabilité du projet pendant le remplissage du formulaire
    Étant donné que je suis en train de remplir le formulaire de demande de recherche
    Quand je saisis mes critères (budget, zone, type de bien...)
    Alors le système m'affiche des indicateurs de faisabilité de mon projet d'achat
    Et il m'incite à affiner ou corriger ma recherche en fonction de la réalité du marché et des annonces disponibles

  @personnalisation @notification
  Scénario: Le particulier reçoit une description personnalisée renforçant la confiance envers le chasseur affecté
    Étant donné qu'un chasseur m'a été affecté suite à ma demande
    Quand je reçois la notification d'affectation
    Alors je reçois une description rédigée en fonction du profil du chasseur et du mien
    Et cette description renforce l'impression d'avoir tapé à la bonne porte

  @apprentissage-preferences
  Scénario: Chaque choix ou rejet de bien affine automatiquement la recherche
    Étant donné que je consulte des propositions de biens
    Quand je choisis un bien ou que j'en écarte un
    Alors le système me propose une modification de ma recherche prenant en compte mes goûts déduits de cette action

  @offres-personnalisees @fin-parcours
  Scénario: Le particulier reçoit des offres et articles sélectionnés et rédigés par le système après l'achat
    Étant donné que j'ai finalisé mon achat et reçu ma facture
    Quand l'entreprise me sollicite pour de futurs services
    Alors je reçois des offres et articles sélectionnés et rédigés par le système en fonction de mon profil
