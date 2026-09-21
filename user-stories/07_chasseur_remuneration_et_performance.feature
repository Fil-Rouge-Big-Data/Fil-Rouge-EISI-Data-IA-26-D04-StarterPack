# language: fr
# Source : Readme.md — « Le parcours utilisateur actuel » > « Le chasseur », étapes 10 à 13

@chasseur @actuel @remuneration @performance
Fonctionnalité: Rémunération du chasseur et recalcul de la performance
  En tant que chasseur immobilier
  Je veux être informé du paiement de mes honoraires et connaître mes indicateurs de performance
  Afin de facturer l'entreprise et suivre l'évolution de ma rémunération

  @notification-paiement-proche
  Scénario: Le chasseur est prévenu du paiement proche de sa rémunération
    Étant donné que l'entreprise a reçu les honoraires réglés par le client devant notaire
    Quand ce paiement est enregistré
    Alors je suis prévenu du paiement proche de ma rémunération et de son montant
    Et je peux préparer ma facture

  @envoi-facture
  Scénario: Le chasseur envoie sa facture dans le système
    Étant donné que j'ai été prévenu du paiement proche de ma rémunération
    Quand j'envoie ma facture dans le système
    Alors ma facture est soumise à vérification

  @facture-verifiee @paiement-programme
  Scénario: Le paiement est programmé une fois la facture vérifiée et conforme
    Étant donné que j'ai envoyé ma facture dans le système
    Quand le système affiche ma facture comme vérifiée et conforme
    Alors le paiement de ma rémunération est affiché comme programmé

  @paiement-effectue @recalcul-performance
  Scénario: La rémunération est marquée payée et les indicateurs de performance sont recalculés
    Étant donné que le paiement de ma rémunération est programmé
    Quand le paiement est effectué
    Alors la somme est marquée comme payée
    Et mes indicateurs de performance sont recalculés et affichés

  @renouvellement-mandat
  Scénario: Le mandat arrive à échéance avant l'achat, le chasseur est invité à le renouveler
    Étant donné qu'un mandat de recherche arrive à échéance sans qu'une vente ait abouti
    Quand la date de fin de validité du mandat (signature + 6 mois) est atteinte
    Alors je suis invité à prendre rendez-vous avec l'acquéreur afin de renouveler le mandat
    Et mes indicateurs de performance sont recalculés à la baisse et affichés
