# Schéma analytique (OLAP) et alimentation — v8.42

> **Livrable BC05** (grille d'évaluation : « schéma analytique + alimentation des données : 1 schéma + description, script SQL ou code »).
> **Rédaction :** Matthieu Barre (R, schéma OLAP) · **Approbation :** Angeline Gomez (A) · **Alimentation :** Alexandre Kechaf (A du descriptif d'alimentation) — RACI v1.1.
> **Version :** 1.2 du 12/10/2026 — corrections de la revue de la PR #15 (Angeline Gomez) : vues sans multiplication des montants, honoraires convertis en HT (D19), deux notions de zone explicites, chargements déterministes. La v1.1 du 11/10 rebasait l'entrepôt sur le socle OLTP **v8.42** (ADR-053, décisions D10, D12, D13) ; la v1.0 était construite sur un schéma antérieur à la v8.4 (risque RB1 de l'étude d'opportunité).
> **Code :** `livrables/olap/01_schema_etoile.sql` · `02_etl_chargement.sql` · `03_vues_kpi.sql` · `tests/test_olap_pipeline.py`. Rejoué par `run_tests_docker.sh`.

## 1. Ce que l'entrepôt doit répondre

Les cinq indicateurs de l'étude d'opportunité (§2.3), tels que validés avec le Product Owner :

| KPI | Question | Vue de restitution |
|---|---|---|
| KPI-1 | Combien de demandes deviennent mandats, visites, offres, actes ? | `v_kpi_conversion_funnel` (jusqu'à l'acte depuis le 13/10) |
| KPI-2 | Quand encaisse-t-on ? Quels mandats dorment ? | `v_kpi_tresorerie` (encaissé, en attente chez le notaire, prévu par les compromis) ; `v_kpi_mandats_cycle_vie` (dont mandats sans visite depuis 30 jours, D16) |
| KPI-3 | Combien de visites avant une vente ? | `v_kpi_performance_chasseurs.visites_moyennes_par_vente` |
| KPI-4 | Quelle marge, quelle rémunération par chasseur ? | `v_kpi_chiffre_affaires_mensuel`, `v_kpi_performance_chasseurs` |
| KPI-5 | Quels secteurs performent ? | `v_kpi_analyse_geographique` |
| Complément | Pourquoi perd-on des mandats ? Les biens proposés plaisent-ils ? | `v_kpi_motifs_resiliation` ; `v_kpi_performance_chasseurs.taux_acceptation_propositions_pct` |

> **Relecture du 13/10/2026.** En comparant les vues aux questions de l'étude (§2.3), deux promesses n'étaient pas tenues : KPI-1 s'arrêtait au mandat, et KPI-2 ne disait rien de l'encaissement. Elles sont corrigées, avec deux compléments dont les données existaient déjà dans l'OLTP.

## 2. Principes (ADR)

- **ADR-025 / ADR-036 — frontière OLTP / OLAP.** L'OLTP (`public`, 38 tables, 9 vues) est la source de vérité ; l'entrepôt (`olap`) est reconstruit depuis lui, jamais l'inverse. Aucun agrégat comparatif ne vit dans l'OLTP.
- **ADR-048 / ADR-051 — états dérivés, jamais recalculés ici.** L'ETL lit les vues d'état de l'OLTP (`v_mandat`, `v_demande`, `v_acte_mandat`, `v_honoraires`) : si la règle change dans l'OLTP, l'entrepôt la suit sans modification. C'est la parade au risque **RB1** (dérive de schéma) de l'étude d'opportunité.
- **ADR-049 / ADR-052 — rémunération gelée.** `fait_remuneration_chasseur` copie les composantes figées à l'acte (cinq notes, taux, montant). L'entrepôt n'invente aucun calcul de rémunération.
- **ADR-053 / D13 — acte à double origine, chaîne de renouvellement.** Une vente est rattachée au mandat de la chaîne **en vigueur** à l'acte (celui que rémunère l'OLTP) et au mandat **initial** (point de départ du délai S₁). Une vente hors dispositif n'a ni bien ni zone : ces clés sont nulles et `est_hors_dispositif` la distingue.
- **D10 — une visite = un rendez-vous.** Fonction `olap.f_nb_visites` : rendez-vous distincts (bien, date) réalisés avec au moins un acquéreur de la demande. Une visite en couple compte une fois ; la reconnaissance du chasseur seul ne compte pas.
- **D12 — efficacité des visites.** Les ventes hors dispositif sont exclues de la moyenne de visites par vente (KPI-3).
- **D19 — honoraires HT.** L'OLTP calcule l'assiette comme l'énoncé la définit (fixe + % du prix), dans la base du mandat (`base_honoraires` HT ou TTC) ; il ne parle pas de TVA. L'entrepôt garde ce brut (`honoraires_agence_brut`) **et** le convertit en HT selon `taux_tva` ; chiffre d'affaires, marge et taux de marge sont calculés en HT. La rémunération gelée par l'OLTP est réputée HT (le chasseur indépendant facture l'agence). Hypothèse posée au Product Owner.
- **Une vue ne joint jamais deux tables de faits sur la même clé.** Chaque fait est agrégé dans sa propre CTE avant jointure (sinon chaque vente est répétée autant de fois que le chasseur a de mandats : défaut trouvé en revue). Un test rapproche les sommes des vues des sommes brutes des faits (RB2 : réconciliation des montants).
- **ADR-043 / RB4 — pas de donnée identifiante.** `dim_client` ne porte que des tranches (budget, âge) et le statut d'anonymisation ; `dim_chasseur` ne porte pas l'e-mail.
- **ADR-036 — compte technique.** `SYS-MIGRATION` est marqué `est_technique` et exclu des délais « humains ».

## 3. Modèle en étoile

Grain : un acte = un fait de vente ; une rémunération = un fait ; un mandat = un cycle ; une demande = une activité.

```mermaid
erDiagram
    DIM_TEMPS ||--o{ FAIT_VENTE : "date de l'acte"
    DIM_CHASSEUR ||--o{ FAIT_VENTE : "chasseur du mandat en vigueur"
    DIM_GESTIONNAIRE |o--o{ FAIT_VENTE : "gestionnaire de la demande"
    DIM_ZONE |o--o{ FAIT_VENTE : "zone du bien (NULL hors dispositif)"
    DIM_CLIENT ||--o{ FAIT_VENTE : "acquéreur principal"
    DIM_BIEN |o--o{ FAIT_VENTE : "bien (NULL hors dispositif)"
    DIM_TEMPS ||--o{ FAIT_REMUNERATION_CHASSEUR : "date de calcul, date de l'acte"
    DIM_CHASSEUR ||--o{ FAIT_REMUNERATION_CHASSEUR : "chasseur rémunéré"
    DIM_ZONE |o--o{ FAIT_REMUNERATION_CHASSEUR : "zone du bien"
    DIM_TEMPS ||--o{ FAIT_MANDAT_CYCLE : "signature, fin théorique"
    DIM_CHASSEUR ||--o{ FAIT_MANDAT_CYCLE : "chasseur"
    DIM_ZONE |o--o{ FAIT_MANDAT_CYCLE : "première zone ciblée"
    DIM_CLIENT ||--o{ FAIT_MANDAT_CYCLE : "acquéreur principal"
    DIM_TEMPS ||--o{ FAIT_ACTIVITE_DEMANDE : "dépôt, affectation"
    DIM_GESTIONNAIRE ||--o{ FAIT_ACTIVITE_DEMANDE : "gestionnaire"
    DIM_CHASSEUR |o--o{ FAIT_ACTIVITE_DEMANDE : "chasseur affecté"
    DIM_CLIENT ||--o{ FAIT_ACTIVITE_DEMANDE : "acquéreur principal"

    FAIT_VENTE {
        uuid id_acte UK
        int id_date_acte FK
        uuid id_chasseur FK
        uuid id_gestionnaire FK
        uuid id_zone FK
        uuid id_client FK
        uuid id_bien FK
        uuid id_mandat_en_vigueur
        uuid id_mandat_initial
        boolean est_hors_dispositif
        varchar source_information
        boolean est_mandat_exclusif
        numeric montant_acte_net_vendeur
        numeric honoraires_agence_ht
        numeric remuneration_chasseur_ht
        numeric marge_brute_ht
        numeric taux_marge_pct
        int delai_depot_a_acte_jours
        int delai_mandat_a_acte_jours
        int nb_visites_effectuees
        int nb_propositions_recues
    }
    FAIT_REMUNERATION_CHASSEUR {
        uuid id_remuneration UK
        int id_date_calcul FK
        int id_date_acte FK
        uuid id_chasseur FK
        uuid id_zone FK
        uuid id_acte
        boolean est_hors_dispositif
        numeric honoraires_assiette
        numeric score_s1_delai
        numeric score_s2_exclusivite
        numeric score_s3_ventes
        numeric score_s4_mandats
        numeric score_s5_visites
        numeric score_performance_global
        numeric taux_base_pct
        numeric majoration_anciennete_pct
        numeric modulation_performance_pct
        numeric taux_final_pct
        numeric montant_remuneration_ht
        boolean est_annulee
    }
    FAIT_MANDAT_CYCLE {
        uuid id_mandat UK
        int id_date_signature FK
        int id_date_fin_theorique FK
        uuid id_chasseur FK
        uuid id_zone FK
        uuid id_client FK
        uuid id_mandat_precedent
        boolean exclusif
        varchar statut_projete
        boolean est_succes
        boolean est_renouvele
        boolean est_resilie
        boolean est_echu
        int duree_effective_jours
        int nb_propositions
        int nb_visites
        int jours_sans_visite
    }
    FAIT_ACTIVITE_DEMANDE {
        uuid id_demande UK
        int id_date_depot FK
        int id_date_affectation FK
        uuid id_gestionnaire FK
        uuid id_chasseur FK
        uuid id_client FK
        varchar canal
        varchar statut_demande
        numeric delai_affectation_heures
        numeric delai_qualification_jours
        boolean a_abouti_mandat
        int nb_versions_criteres
    }
```

### Dimensions

| Dimension | Contenu | Source OLTP | Note |
|---|---|---|---|
| `dim_temps` | calendrier 2020-2030, jour par jour (année, trimestre, mois, semaine ISO, week-end, ouvré) | généré | clé `YYYYMMDD` |
| `dim_chasseur` | identité, statut juridique, **habilitation Hoguet** (type, numéro, organisme, validité), entrée et sortie du réseau, capacité | `chasseur`, `utilisateur` | pas d'e-mail (minimisation) |
| `dim_gestionnaire` | matricule, identité, équipe, capacité, `est_technique` | `gestionnaire`, `utilisateur` | `SYS-MIGRATION` → technique |
| `dim_zone` | type, libellé, ville, secteur, codes, département (France), **pays, code ISO, devise** | `zone` | prêt pour l'international |
| `dim_bien` | type, tranche de surface, pièces, DPE, prestations | `bien` | |
| `dim_client` | tranche de budget, destination, primo-accédant, financement, tranche d'âge, `est_anonymise_rgpd` | `client`, `demande`, `v_version_courante`, `utilisateur` | aucune donnée identifiante |

### Faits

| Fait | Grain | Mesures | Règles |
|---|---|---|---|
| `fait_vente` | un acte | montant, honoraires brut et **HT**, part chasseur, marge, taux de marge, délais, visites, propositions, **encaissement** (drapeau, date, délai acte → encaissement) | marge HT = honoraires HT − part chasseur (D19) ; délai mandat → acte depuis le mandat **initial** (D13) ; visites = rendez-vous d'acquéreurs sur la chaîne du mandat (D10) ; deux zones : `id_zone` (bien vendu), `id_zone_recherche` (mandat) |
| `fait_remuneration_chasseur` | une rémunération | assiette, cinq notes, score, taux, montant, `est_annulee` | copie du gel OLTP (ADR-049) ; `est_hors_dispositif` |
| `fait_mandat_cycle` | un mandat | durée effective, propositions (dont soumises au client et retenues), visites, `jours_sans_visite`, motif de résiliation | état lu dans `v_mandat` ; filiation `id_mandat_precedent` ; résilié sans motif (état repris) = `non_renseigne` (ADR-051) ; retenue = statut `retenu_visite`, visite réalisée ou offre |
| `fait_activite_demande` | une demande | délais d'affectation et de qualification, versions de critères, `a_abouti_mandat`, `a_eu_visite`, `a_eu_offre`, `a_abouti_acte` | état lu dans `v_demande` ; visite = rendez-vous avec un acquéreur (D10) ; acte = les deux origines (ADR-053) |
| `fait_compromis` | un compromis | montant de l'offre, honoraires **estimés** HT, date d'acte prévue | état lu dans `v_compromis` ; estimation = forfait + taux du mandat × offre, convertie en HT (D19) ; le montant réel est celui de l'acte |

## 4. Alimentation (`02_etl_chargement.sql`)

- **ELT en SQL ensembliste**, une transaction, `INSERT … ON CONFLICT DO UPDATE` sur la clé naturelle de chaque table : rejouable à l'identique (test d'idempotence), sans suppression.
- **Ordre** : dimensions (temps, chasseur, gestionnaire, zone, bien, client), puis faits (mandats, demandes, ventes, rémunérations, compromis).
- **Lignage** :

```
OLTP (public)                                   vue d'état lue            OLAP (olap)
mandat, mandat_reprise, proposition, visite ──▶ v_mandat ───────────────▶ fait_mandat_cycle
demande, affectation, demande_version ───────▶ v_demande ──────────────▶ fait_activite_demande
acte (2 origines), compromis…proposition ────▶ v_acte_mandat, v_honoraires ▶ fait_vente
remuneration_chasseur ───────────────────────▶ (copie du gel) ──────────▶ fait_remuneration_chasseur
compromis, offre, mandat ────────────────────▶ v_compromis ─────────────▶ fait_compromis
chasseur, gestionnaire, zone, bien, client ──▶ (tranches, drapeaux) ────▶ dimensions
```

- **Date de référence** : les âges, durées et mandats dormants utilisent `public.date_reference()` (ADR-047), donc le même « aujourd'hui » que l'OLTP : les tests sont reproductibles.
- **Déterminisme** : aucun `LIMIT 1` sans `ORDER BY` (zone recherchée = première zone par identifiant ; demande de référence du client = demande principale la plus récente) ; `dim_temps` couvre 2020-2030 et toutes les dates présentes dans l'OLTP, plus un an.
- **Reconstruction complète** : la recette supprime le schéma `olap` et le recharge entièrement ; en production, le même script tourne en chargement nocturne (orchestrateur Airflow, étude §6.1) et ne fait que des mises à jour.

## 5. Vues de restitution (`03_vues_kpi.sql`)

| Vue | Public | Ce qu'elle donne |
|---|---|---|
| `v_kpi_chiffre_affaires_mensuel` | direction, DAF | ventes (dont hors dispositif), volume, honoraires, part chasseurs, marge, taux de marge, panier moyen, délai moyen mandat → acte |
| `v_kpi_performance_chasseurs` | direction commerciale | mandats (actifs, clos en succès), ventes, honoraires HT, rémunération hors annulations, cinq notes moyennes, visites moyennes par vente (hors ventes hors dispositif, D12), taux de transformation, **taux d'acceptation des biens proposés** — trois faits agrégés séparément |
| `v_kpi_conversion_funnel` | pôle gestion | demandes reçues, en attente, prises en charge, transformées en mandat, avec visite, avec offre, abouties à un acte, sans suite ; taux mandat et taux acte ; délais humains (hors compte technique). Un achat hors dispositif atteint l'acte sans visite ni offre : l'entonnoir n'est pas strictement décroissant |
| `v_kpi_mandats_cycle_vie` | juridique, direction | répartition par état, exclusivité, **mandats dormants** (actifs, > 30 jours sans visite), durée, propositions et visites moyennes |
| `v_kpi_tresorerie` | DAF, direction | par mois : honoraires **encaissés** (délai moyen acte → encaissement), **en attente chez le notaire** (acte signé, argent pas reçu ; ancienneté), **prévus** par les compromis signés au mois de l'acte prévu (estimation). Trois branches agrégées séparément |
| `v_kpi_motifs_resiliation` | direction commerciale | mandats résiliés par motif : nombre, dont exclusifs, part, durée avant résiliation, visites |
| `v_kpi_analyse_geographique` | développement | par zone **recherchée** : mandats engagés, ventes de ces mandats, taux de succès ; par zone **du bien** : ventes, volume, honoraires HT, marge. Les deux notions sont séparées : le taux de succès compare mandats et ventes sur la même zone |

## 6. Tests (`tests/test_olap_pipeline.py`)

| Test | Vérifie | Jeu de test (seed) | Données reprises (migration) |
|---|---|---|---|
| structure | 6 dimensions, 5 faits, 7 vues | ✅ | ✅ |
| idempotence | rejouer l'ETL ne change aucun comptage | ✅ | ✅ |
| réconciliation mandats | volume et état identiques à `v_mandat` (RB2) | ✅ | ✅ 18 mandats : 11 échus, 3 clos en succès, 2 actifs, 2 résiliés |
| réconciliation ventes | comptage **et** montants identiques à l'OLTP (RB2) | ✅ | ✅ (0 vente reprise) |
| compte technique | `SYS-MIGRATION` technique, délais humains à NULL | — (absent) | ✅ |
| formules | marge = honoraires − part ; taux | ✅ | ✅ |
| RGPD | aucune colonne identifiante dans `dim_client` ; anonymisation reflétée | ✅ | ✅ |
| D10 | couple + chasseur + reconnaissance = **1** visite | ✅ | — (pas de proposition reprise) |
| D13 / ADR-053 | chaque vente rattachée au mandat en vigueur et au mandat initial ; une vente de la chaîne a toujours un bien | ✅ | ✅ |
| vues sans multiplication | sommes des vues (CA, rémunération, par chasseur et par zone) = sommes brutes des faits ; un mandat de plus sans vente ne change pas le CA du chasseur | ✅ | ✅ |
| honoraires HT (D19) | brut = assiette OLTP ; HT = brut / (1 + TVA) si le mandat est TTC | ✅ | — (0 vente reprise) |
| encaissement | drapeau et délai identiques à l'acte | ✅ | — (0 vente reprise) |
| compromis | volume et état identiques à `v_compromis` ; honoraires estimés recalculés depuis le mandat | ✅ | — |
| trésorerie sans double compte | encaissé + en attente = honoraires des ventes ; prévu = compromis signés | ✅ | ✅ |
| compromis en cours | un compromis signé apparaît au mois de l'acte prévu, un caduc n'apparaît pas | ✅ | ✅ |
| entonnoir jusqu'à l'acte | demandes abouties à un acte identiques à l'OLTP ; pas d'offre sans mandat | ✅ | ✅ |
| motifs et acceptation | tout mandat résilié a un motif ; retenues ≤ soumises, soumises identiques à l'OLTP | ✅ | ✅ |

Résultat au 13/10/2026 (PostgreSQL 16.15) : **18 tests, 17 réussis + 1 sauté** sur le jeu de test (pas de compte technique) ; sur les données reprises, le test D10 et le test HT sont sautés faute de proposition et de vente reprises. Commande : `./run_tests_docker.sh` (dernière étape), ou `pytest livrables/olap/tests` avec les variables `PG*`.

## 7. Limites et suites

- **Volumétrie** : construit et testé sur l'activité actuelle (52 lignes reprises) ; sur le jeu de volume de la note d'indexation (20 000 mandats, 6 000 ventes), la lecture complète de `v_mandat` prend 12,6 s. À la cible de l'énoncé (5 000 mandats par semaine, CDC ENF-03), les faits se partitionnent par date, l'ETL passe en chargement par delta et les sous-requêtes corrélées en jointures agrégées ; la note de dimensionnement 3V (R : Alexandre Kechaf) doit chiffrer ce passage.
- **Chargement incrémental** : l'ETL recharge tout ; un chargement par delta (actes et mandats modifiés depuis la dernière exécution) est à prévoir avec l'orchestrateur.
- **Historisation des dimensions** : type 1 (écrasement). Les changements de chasseur ou de zone ne sont pas historisés (pas de SCD 2) : décision à acter par ADR en phase 3.
- **Index de la note d'indexation** : mesurés et justifiés, ils ne sont pas encore dans `01_ddl.sql` (la note mesure, le DDL décide) ; leur ajout au socle est prévu dans la PR suivante.
- **D13** : la lecture « chaîne de renouvellement » est appliquée ; elle attend la confirmation du Product Owner (journal des décisions).
- **Trésorerie prévisionnelle** : les honoraires des compromis sont une estimation d'après le mandat ; un compromis sans date d'acte prévue apparaît « non daté ». Le seed ne contient aucun compromis en cours : la branche « prévu » est vérifiée par un test sur des faits temporaires.
- **Pistes non retenues en phase 2** : la négociation obtenue sur le prix affiché (seul le dernier prix d'annonce est conservé, souvent honoraires compris : la mesure serait biaisée) ; le lien entre le score de matching et la vente (le score sera produit par le matching de la phase 4).

## 8. Rattachement RNCP40573

BC05 — « Extraction, transformation, chargement, qualité, RGPD » (ETL idempotent, réconciliation, minimisation) et « concevoir la base pour l'analytique » (étoile, grain, dimensions). BC01 — frontière OLTP / OLAP tracée par ADR. BC03 — tests automatisés rejoués dans la recette.
