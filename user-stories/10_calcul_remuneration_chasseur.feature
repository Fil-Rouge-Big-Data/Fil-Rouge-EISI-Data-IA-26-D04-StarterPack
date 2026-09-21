# language: fr
# Source : Readme.md — section « Le contexte » (assiette, barème, critères de performance)
# Les valeurs numériques (montant fixe, pourcentage, tranches, poids, bornes) sont des
# paramètres proposés, non imposés par le métier : ils sont justifiés et discutés dans
# « documents utiles/REGLES-CALCUL-REMUNERATION.md ». Les règles, elles, sont métier.

@regles-metier @remuneration @calcul
Fonctionnalité: Calcul de la rémunération du chasseur
  En tant qu'entreprise de chasse immobilière
  Je veux calculer la part reversée au chasseur de façon déterministe et auditable
  Afin que chaque chasseur puisse vérifier son montant et que l'entreprise maîtrise sa marge

  Le calcul se déroule toujours dans le même ordre :
  droit à rémunération → assiette (honoraires) → score de performance → taux de tranche
  → modulation ancienneté et performance → montant, figé au jour de l'acte authentique.

  Contexte:
    Étant donné les paramètres d'honoraires en vigueur au "2026-07-30"
      | montant fixe | pourcentage du prix |
      | 3000,00      | 2,5                 |
    Et le barème de commission par défaut en vigueur au "2026-07-30"
      | montant min | montant max | taux de base |
      | 0           | 199999      | 30           |
      | 200000      | 349999      | 35           |
      | 350000      | 499999      | 40           |
      | 500000      | 749999      | 45           |
      | 750000      |             | 50           |

  @droit-a-remuneration @exclusivite
  Règle: Le droit à rémunération dépend de l'exclusivité du mandat et de l'origine de la vente

    Plan du Scénario: Le droit à rémunération est établi avant tout calcul de montant
      Étant donné un mandat "<exclusivite>" en cours de validité à la date de l'acte
      Quand la vente aboutit et que son origine est "<origine>"
      Alors le droit à rémunération du chasseur est "<droit>"

      Exemples:
        | exclusivite  | origine                            | droit  |
        | exclusif     | le chasseur                        | ouvert |
        | exclusif     | le client, en dehors du dispositif | ouvert |
        | non-exclusif | le chasseur                        | ouvert |
        | non-exclusif | le client, en dehors du dispositif | fermé  |
        | non-exclusif | un chasseur d'une autre agence     | fermé  |

    Scénario: Un acte signé après l'échéance du mandat n'ouvre aucun droit
      Étant donné un mandat non renouvelé signé le "2025-11-14"
      Et que sa date de fin de validité est le "2026-05-14"
      Quand l'acte authentique est signé le "2026-07-30"
      Alors le droit à rémunération du chasseur est "fermé"
      Et la rémunération calculée est de 0,00 €

    Scénario: Un seul chasseur est rémunéré pour une vente donnée
      Étant donné qu'un client a signé deux mandats non-exclusifs avec "Bruno" et "Chloé"
      Quand la vente aboutit à l'initiative de "Chloé"
      Alors "Chloé" perçoit la totalité de la part chasseur
      Et "Bruno" ne perçoit aucune rémunération pour cette vente

  @assiette @honoraires @notaire
  Règle: L'assiette du calcul est constituée des honoraires encaissés par l'entreprise, soit un montant fixe augmenté d'un pourcentage du prix d'achat

    Scénario: Les honoraires sont collectés par le notaire en sus du prix d'achat
      Étant donné un bien acquis 420000,00 € devant notaire
      Quand l'acte authentique est signé
      Alors le notaire collecte 420000,00 € pour le vendeur
      Et il collecte en sus 13500,00 € d'honoraires pour le compte de l'entreprise
      Et l'assiette de la rémunération du chasseur est de 13500,00 €

    Plan du Scénario: Les honoraires se calculent sur le prix d'achat acté
      Étant donné un prix d'achat acté de <prix> €
      Quand les honoraires de l'entreprise sont calculés
      Alors les honoraires s'élèvent à <honoraires> €

      Exemples:
        | prix   | honoraires |
        | 180000 | 7500,00    |
        | 250000 | 9250,00    |
        | 420000 | 13500,00   |
        | 620000 | 18500,00   |
        | 800000 | 23000,00   |

    Scénario: L'assiette n'est jamais le prix du bien
      Étant donné un prix d'achat acté de 420000,00 €
      Et des honoraires de 13500,00 €
      Quand la rémunération du chasseur est calculée
      Alors le taux de commission s'applique aux 13500,00 € d'honoraires
      Mais il ne s'applique pas aux 420000,00 € du prix d'achat

  @performance @score
  Règle: Le score de performance est la moyenne pondérée de cinq critères notés de 0 à 100

    Contexte:
      Étant donné la pondération des critères de performance
        | critere                       | poids |
        | delai entre mandat et acte    | 25    |
        | exclusivite du mandat         | 10    |
        | nombre de ventes reussies     | 25    |
        | nombre de mandats signes      | 15    |
        | nombre de visites avant achat | 25    |

    Plan du Scénario: Le délai entre la signature du mandat et l'acte est arrondi à la semaine inférieure
      Étant donné un mandat signé le "2025-11-14"
      Et un acte authentique signé <jours> jours plus tard
      Quand le critère de délai est noté
      Alors le délai retenu est de <semaines> semaines
      Et la note du critère de délai est de <note> sur 100

      Exemples:
        | jours | semaines | note |
        | 84    | 12       | 100  |
        | 90    | 12       | 100  |
        | 139   | 19       | 80   |
        | 258   | 36       | 40   |
        | 300   | 42       | 20   |
        | 400   | 57       | 0    |

    Plan du Scénario: Moins il y a eu de visites avant l'achat, meilleure est la note
      Étant donné <visites> visites effectuées avant l'achat
      Quand le critère de visites est noté
      Alors la note du critère de visites est de <note> sur 100

      Exemples:
        | visites | note |
        | 2       | 100  |
        | 5       | 80   |
        | 8       | 60   |
        | 11      | 40   |
        | 14      | 20   |
        | 18      | 0    |

    Plan du Scénario: L'exclusivité du mandat est notée forfaitairement
      Étant donné un mandat "<exclusivite>"
      Quand le critère d'exclusivité est noté
      Alors la note du critère d'exclusivité est de <note> sur 100

      Exemples:
        | exclusivite  | note |
        | exclusif     | 100  |
        | non-exclusif | 60   |

    Plan du Scénario: Les volumes de ventes et de mandats sont comptés sur douze mois glissants
      Étant donné <ventes> ventes réussies et <mandats> mandats signés dans les douze mois précédant l'acte
      Quand les critères de volume sont notés
      Alors la note du critère de ventes est de <note ventes> sur 100
      Et la note du critère de mandats est de <note mandats> sur 100

      Exemples:
        | ventes | mandats | note ventes | note mandats |
        | 0      | 3       | 0           | 30           |
        | 2      | 6       | 40          | 60           |
        | 4      | 9       | 80          | 90           |
        | 5      | 10      | 100         | 100          |
        | 7      | 14      | 100         | 100          |

    Scénario: Le score global agrège les cinq critères
      Étant donné un chasseur dont les critères sont notés
        | critere                       | note |
        | delai entre mandat et acte    | 40   |
        | exclusivite du mandat         | 100  |
        | nombre de ventes reussies     | 80   |
        | nombre de mandats signes      | 90   |
        | nombre de visites avant achat | 80   |
      Quand le score de performance est calculé
      Alors le score de performance est de 73,5 sur 100

  @bareme @tranches
  Règle: Le taux de base est celui de la tranche de montant du barème en vigueur, sans progressivité entre tranches

    Plan du Scénario: Un prix d'achat donné désigne une seule tranche et un seul taux
      Étant donné un prix d'achat acté de <prix> €
      Quand le taux de base est déterminé à partir du barème
      Alors le taux de base est de <taux> %

      Exemples:
        | prix   | taux |
        | 150000 | 30   |
        | 199999 | 30   |
        | 200000 | 35   |
        | 420000 | 40   |
        | 620000 | 45   |
        | 800000 | 50   |

    Scénario: Le taux s'applique à la totalité du montant, sans découpage par tranche
      Étant donné un prix d'achat acté de 420000,00 €
      Quand le taux de base est déterminé à partir du barème
      Alors le taux de base retenu est de 40 % pour la totalité des honoraires
      Mais aucune part des honoraires n'est rémunérée aux taux des tranches inférieures

    Scénario: Le barème retenu est celui en vigueur à la date de l'acte authentique
      Étant donné un barème par défaut fixant la tranche 350000 à 499999 € à 40 % jusqu'au "2026-06-30"
      Et un barème par défaut fixant cette même tranche à 38 % à partir du "2026-07-01"
      Quand la rémunération est calculée pour un acte signé le "2026-07-30"
      Alors le taux de base retenu est de 38 %

    Scénario: Un barème propre au chasseur prévaut sur le barème par défaut
      Étant donné un barème propre au chasseur "Bruno" fixant la tranche 350000 à 499999 € à 43 %
      Quand la rémunération de "Bruno" est calculée pour un prix d'achat de 420000,00 €
      Alors le taux de base retenu est de 43 %
      Et le barème par défaut n'est pas appliqué

  @modulation @anciennete
  Règle: Le taux de base est majoré par l'ancienneté et modulé par la performance, puis borné entre 20 % et 60 %

    Plan du Scénario: L'ancienneté majore le taux de 2 % relatifs par année révolue, plafonnés à 10 %
      Étant donné un chasseur ayant <annees> années d'ancienneté révolues à la date de l'acte
      Quand la majoration d'ancienneté est calculée
      Alors la majoration d'ancienneté est de <majoration> %

      Exemples:
        | annees | majoration |
        | 0      | 0          |
        | 1      | 2          |
        | 3      | 6          |
        | 5      | 10         |
        | 8      | 10         |

    Plan du Scénario: La performance module le taux de plus ou moins 20 % autour d'un score pivot de 50
      Étant donné un score de performance de <score> sur 100
      Quand la modulation de performance est calculée
      Alors la modulation de performance est de <modulation> %

      Exemples:
        | score | modulation |
        | 0     | -20        |
        | 25    | -10        |
        | 50    | 0          |
        | 73,5  | 9,4        |
        | 100   | 20         |

    Scénario: Le taux final combine le taux de tranche, l'ancienneté et la performance
      Étant donné un taux de base de 40 %
      Et une majoration d'ancienneté de 6 %
      Et une modulation de performance de 9,4 %
      Quand le taux final est calculé
      Alors le taux final est de 46,16 %

    Scénario: Le taux final est plafonné à 60 %
      Étant donné un taux de base de 50 %
      Et une majoration d'ancienneté de 10 %
      Et une modulation de performance de 20 %
      Quand le taux final est calculé
      Alors le taux final avant bornage serait de 65,00 %
      Mais le taux final retenu est de 60 %

    Scénario: Le taux final ne peut pas descendre sous 20 %
      Étant donné un taux de base de 22 %
      Et une majoration d'ancienneté de 0 %
      Et une modulation de performance de -20 %
      Quand le taux final est calculé
      Alors le taux final avant bornage serait de 17,60 %
      Mais le taux final retenu est de 20 %

  @montant @arrondi
  Règle: La rémunération est le produit du taux final par les honoraires, arrondi au centime au demi supérieur

    Scénario: Calcul de bout en bout d'une rémunération
      Étant donné un mandat exclusif signé le "2025-11-14" par le chasseur "Bruno"
      Et que "Bruno" a 3 années d'ancienneté révolues
      Et qu'il a réalisé 4 ventes et signé 9 mandats dans les douze derniers mois
      Et que le client a effectué 5 visites avant l'achat
      Quand l'acte authentique est signé le "2026-07-30" pour un prix de 420000,00 €
      Alors les honoraires de l'entreprise sont de 13500,00 €
      Et le score de performance de "Bruno" est de 73,5 sur 100
      Et le taux final de "Bruno" est de 46,16 %
      Et la rémunération de "Bruno" est de 6231,60 €
      Et la marge conservée par l'entreprise est de 7268,40 €

    Scénario: Le montant est arrondi au centime, au demi supérieur
      Étant donné des honoraires de 9250,00 €
      Et un taux final de 38,99 %
      Quand la rémunération est calculée
      Alors la rémunération avant arrondi est de 3606,575 €
      Et la rémunération retenue est de 3606,58 €

  @tracabilite @paiement
  Règle: Les éléments du calcul sont figés à la date de l'acte authentique et ne sont jamais recalculés a posteriori

    Scénario: Le montant notifié au chasseur est celui figé au calcul
      Étant donné une rémunération calculée à 6231,60 € pour un acte signé le "2026-07-30"
      Quand le chasseur est prévenu du paiement proche de sa rémunération
      Alors le montant annoncé est de 6231,60 €
      Et il correspond au montant payé après vérification de sa facture

    Scénario: Un changement de barème postérieur ne modifie pas une rémunération déjà calculée
      Étant donné une rémunération de 6231,60 € figée pour un acte signé le "2026-07-30"
      Quand un nouveau barème entre en vigueur le "2026-09-01"
      Alors la rémunération attachée à l'acte du "2026-07-30" reste de 6231,60 €
      Et les éléments de calcul conservés restent les honoraires, le score, le taux de base, les modulations et le taux final

    Scénario: Les indicateurs de performance sont recalculés après le paiement
      Étant donné une rémunération marquée comme payée
      Quand les indicateurs de performance du chasseur sont recalculés
      Alors les compteurs de ventes réussies et de mandats signés sur douze mois sont mis à jour
      Et le nouveau score sert de base au calcul de la prochaine rémunération

    Scénario: Un mandat arrivé à échéance sans vente dégrade le score du chasseur
      Étant donné un mandat signé le "2025-11-14" et arrivé à échéance le "2026-05-14" sans vente
      Quand les indicateurs de performance du chasseur sont recalculés
      Alors le mandat reste compté dans le nombre de mandats signés
      Mais aucune vente n'est comptée pour ce mandat
      Et le score de performance du chasseur est recalculé à la baisse
