# Dictionnaire des données — v8.41 (complet)

**Cible :** MPD v8.41 — `sql/01_ddl.sql`. PostgreSQL 18 (compatible 16+).
**Portée :** 36 tables, rédigé à la main (sens métier + justification), pas un
export de catalogue. Les contraintes clés sont indiquées ; le détail exhaustif
est dans le DDL.

> ⚠️ Entreprise et données fictives. Livrable pédagogique (RNCP40573).

## Conventions
- **PK** = clé primaire · **FK** = clé étrangère · **UQ** = unique · **NN** = non nul.
- Domaines applicatifs : `d_email`, `d_tel`, `d_montant` (≥0), `d_taux` (0–100),
  `d_dpe` (A–G).
- Toutes les PK sont des **UUIDv7** (`DEFAULT uuidv7()`, ADR-044).

---

# Domaine 1 — Acteurs

## utilisateur
Tronc commun de toute personne du système (identité, contact, authentification,
RGPD). Spécialisé ensuite en client, chasseur ou gestionnaire.

| Colonne | Type | Clé/NN | Sens & justification |
|---|---|---|---|
| id_utilisateur | uuid | PK | Identifiant technique (UUIDv7). |
| nom, prenom | text | NN | Identité. |
| email | d_email | NN, UQ | Contact et identifiant de connexion ; unique. |
| telephone | d_tel | | Contact ; format validé par le domaine. |
| password_hash | text | NN | Empreinte du mot de passe (jamais en clair). Sentinelle à la reprise (ADR-043). |
| date_creation | timestamptz | NN | Horodatage de création. |
| actif | boolean | NN | Compte actif ; passe à false à l'anonymisation. |
| date_anonymisation | timestamptz | | Date d'anonymisation RGPD. Contrainte C12 : si renseignée, `actif=false`. |

## client
Spécialisation acquéreur de `utilisateur` (clé partagée). Profil et vigilance.

| Colonne | Type | Clé/NN | Sens & justification |
|---|---|---|---|
| id_utilisateur | uuid | PK, FK→utilisateur | Héritage par clé partagée. |
| frais_dossier_offerts | boolean | NN | Avantage filleul (parrainage) ; distinct de la rétribution parrain. |
| annee_naissance | smallint | | Profil ; bornée 1900–2100. |
| primo_accedant | boolean | NN | Premier achat ; influence l'accompagnement. |
| code_postal_residence | text | | Résidence ; format FR 5 chiffres. |
| canal_contact_prefere | text | | telephone / email / sms. |
| consentement_marketing | boolean | NN | RGPD ; si true, `date_consentement_marketing` requise (ck_client_consent_mkg). |
| date_consentement_marketing | timestamptz | | Preuve du consentement. |
| niveau_vigilance | text | NN | standard / renforcee (LCB-FT). |
| date_derniere_verification | date | | Dernière vérification de conformité. |
| origine_fonds_declaree | text | | Origine des fonds (LCB-FT) — donnée sensible d'accès. |

## chasseur
Spécialisation professionnelle. **Habilitation loi Hoguet** (ADR-046).

| Colonne | Type | Clé/NN | Sens & justification |
|---|---|---|---|
| id_utilisateur | uuid | PK, FK→utilisateur | Héritage. |
| type_habilitation | text | NN | `carte_t` (titulaire) ou `attestation` (négociateur). |
| numero_habilitation | text | NN | N° de carte T ou d'attestation ; **non unique** (plusieurs collaborateurs partagent la carte du titulaire). |
| date_validite_habilitation | date | NN | Doit être en cours de validité (exigence métier). |
| organisme_delivrance | text | NN | CCI (ex-préfecture). |
| organisme_garant | text | NN | Garantie financière. |
| montant_garantie_financiere | d_montant | NN | > 0. |
| numero_rcp | text | NN | Responsabilité civile professionnelle. |
| date_echeance_rcp | date | NN | Échéance RCP. |
| statut_juridique | text | NN | salarie / agent_commercial / independant. Salarié ⇒ attestation (ck_chasseur_habilitation). |
| numero_rsac | text | | Requis si agent_commercial (ck_chasseur_rsac). |
| date_entree_reseau | date | NN | Entrée dans le réseau. |
| date_sortie_reseau | date | | Sortie éventuelle (≥ entrée). |
| capacite_max_mandats | smallint | NN | Charge maximale ; > 0. |
| budget_min/max_intervention | d_montant | | Fourchette d'intervention. |
| taux_honoraires_defaut | d_taux | | Taux par défaut du chasseur. |

## gestionnaire
Spécialisation interne : affecte les demandes aux chasseurs.

| Colonne | Type | Clé/NN | Sens & justification |
|---|---|---|---|
| id_utilisateur | uuid | PK, FK→utilisateur | Héritage. |
| matricule | text | NN, UQ | Identifiant RH. |
| date_entree_fonction | date | NN | Prise de fonction. |
| date_sortie_fonction | date | | Sortie (≥ entrée). |
| equipe | text | | Rattachement. |
| capacite_max_leads | smallint | NN | Charge maximale ; > 0. |

## indisponibilite
Périodes d'absence d'un chasseur (congés, etc.).

| Colonne | Type | Clé/NN | Sens |
|---|---|---|---|
| id_indisponibilite | uuid | PK | — |
| id_chasseur | uuid | NN, FK→chasseur | — |
| date_debut, date_fin | date | NN | Période ; fin ≥ début. |
| motif | text | | Libre. |

## parrainage
Dispositif de parrainage complet (ADR-034, source : règlement Evoriel 06/2026).
Récompense le **parrain** après concrétisation.

| Colonne | Type | Clé/NN | Sens & justification |
|---|---|---|---|
| id_parrainage | uuid | PK | — |
| id_parrain | uuid | NN, FK→utilisateur | Client ou prospect (pas collaborateur). |
| id_filleul | uuid | FK→utilisateur | Renseigné quand le filleul a un compte. |
| filleul_nom/prenom/email/telephone | — | | Identité déclarée avant compte (déclaration préalable). |
| type_contrat | text | NN | vente / gerance / syndic. |
| date_declaration | date | NN | Préalable à tout contact. |
| date_fin_validite | date | NN | 12 mois (vente/gérance) ou 24 mois (syndic). |
| statut | text | NN | declare → mandat_signe → concretise → retribue ; + expire / rejete. |
| id_mandat_concretise | uuid | FK→mandat | Concrétisation. Requis si concretise/retribue. |
| date_concretisation | date | | — |
| rib_recu, date_reception_rib | | | RIB sous 15 j (condition de rétribution). |
| montant_retribution | d_montant | | 400 € par mandat. |
| date_versement | date | | Versement sous 3 mois. |

Contraintes : `ck_parrainage_pas_auto` (parrain ≠ filleul), `ck_parrainage_concret`,
`ck_parrainage_retribue` (RIB + versement + montant), unicité filleul/concrétisation.

---

# Domaine 2 — Demande (expression du besoin)

## demande
Racine du besoin d'un client. Canal, consentement RGPD, cycle de vie.

| Colonne | Type | Clé/NN | Sens & justification |
|---|---|---|---|
| id_demande | uuid | PK | — |
| id_gestionnaire | uuid | FK→gestionnaire | Gestionnaire en charge (nullable : demande non encore affectée). |
| date_depot | date | NN | Dépôt. |
| canal | text | NN | site_web / parrainage / telephone / autre. site_web ⇒ consentement requis. |
| ~~statut~~ | — | — | **ADR-048 : SUPPRIMÉ.** Cycle dérivé dans v_demande (nouveau/affecté/qualifié/en_recherche/close) depuis les faits ; `sans_suite` = flag `date_sans_suite`+motif. |
| id_mandat_courant | uuid | FK | ADR-048 : mandat en cours (fait de gestion). Porte l'unicité « un mandat courant par demande ». |
| date_sans_suite | timestamptz | | ADR-048 : flag d'abandon (le seul écart stocké du cycle). |
| date_consentement | timestamptz | | RGPD ; requis si canal=site_web (ck_demande_consent_web). |
| nb_relances | smallint | NN | Compteur de relances. |
| statut_financement | text | | non_evalue / a_evaluer / accord_principe / refuse. |

## demande_acquereur
Lie une demande à ses acquéreurs (co-acquéreurs possibles ; un principal requis).

| Colonne | Type | Clé/NN | Sens |
|---|---|---|---|
| id_demande | uuid | PK, FK→demande | — |
| id_client | uuid | PK, FK→client | — |
| qualite | text | NN | principal / co_acquereur. Un seul principal par demande (trigger C4). |

## demande_version
Historise les critères de recherche (chaque modification = nouvelle version).

| Colonne | Type | Clé/NN | Sens & justification |
|---|---|---|---|
| id_version | uuid | PK | — |
| id_demande | uuid | NN, FK→demande | — |
| id_modifie_par | uuid | FK→utilisateur | Auteur de la version. |
| no_version | smallint | NN | Numéro croissant ; > 0. |
| date_creation | timestamptz | NN | — |
| motif_evolution | text | NN | Pourquoi cette version. |
| type_bien | text | NN | appartement / maison / terrain / immeuble / autre. |
| destination | text | NN | principale / secondaire / investissement. |
| budget_max | d_montant | | Plafond ; > 0. |
| surface_min, nb_pieces_min, nb_chambres_min | smallint | | Exigences minimales. |
| dpe_max | d_dpe | | Performance énergétique maximale. |
| pref_ascenseur/balcon/terrasse/jardin/parking/cave | d_preference | NN | **v8.41 (ADR-052)** : intention du client sur le critère, 4 états : `exige` (doit l'avoir), `souhaite` (apprécié, non bloquant), `exclut` (refus : critère d'exclusion), `indifferent` (défaut). Remplace les booléens `exige_*`. |
| travaux_acceptes | boolean | NN | — |
| rendement_brut_min | d_taux | | Seulement si destination=investissement (ck_version_rendement). |
| ~~est_courante~~ | — | — | **ADR-048 : SUPPRIMÉ.** La version courante = celle au `no_version` MAX (dérivée, v_version_courante). |
| commentaire_criteres | text | | Texte brut source (migration, zéro déperdition). |

## affectation
Relie gestionnaire, demande et chasseur dans le temps (historisée).

| Colonne | Type | Clé/NN | Sens |
|---|---|---|---|
| id_affectation | uuid | PK | — |
| id_demande | uuid | NN, FK→demande | — |
| id_chasseur | uuid | NN, FK→chasseur | — |
| id_gestionnaire | uuid | NN, FK→gestionnaire | Qui a affecté. |
| date_debut, date_fin | timestamptz | NN/— | Période ; une seule ouverte par demande. |
| motif | text | NN | initiale / surcharge / absence / desaccord_client / refus_chasseur / autre. |

## zone, version_zone, chasseur_zone
`zone` : référentiel géographique unifié (ville ou secteur). `version_zone` : zones
visées par une version de critères (n-n). `chasseur_zone` : zones d'intervention
d'un chasseur (n-n).

| zone | Type | Clé/NN | Sens |
|---|---|---|---|
| id_zone | uuid | PK | — |
| type_zone | text | NN | ville / secteur. |
| pays, code_iso_pays, devise | — | NN | FR / EUR par défaut. |
| ville, secteur | citext | NN/— | Insensible à la casse (anti-doublon orthographique). |
| code_insee | char(5) | | Regex INSEE (Corse 2A/2B). Requis pour FR. |
| code_postal | text | | Format FR si pays=FR. |

---

# Domaine 3 — Biens et prospection

## bien
Un bien immobilier (caractéristiques physiques).

| Colonne | Type | Clé/NN | Sens |
|---|---|---|---|
| id_bien | uuid | PK | — |
| id_zone | uuid | NN, FK→zone | Localisation. |
| type_bien | text | NN | — |
| surface, nb_pieces, nb_chambres, etage | | | Caractéristiques. |
| dpe | d_dpe | | Performance énergétique. |
| adresse_indicative, code_postal | text | | — |
| a_ascenseur/balcon/terrasse/jardin/parking/cave | boolean | | Équipements (pour le matching). |

## annonce
Annonces collectées pour un bien (sources hétérogènes).

| Colonne | Type | Clé/NN | Sens |
|---|---|---|---|
| id_annonce | uuid | PK | — |
| id_bien | uuid | NN, FK→bien | — |
| source, reference_source | text | NN | Portail d'origine + réf. |
| prix | d_montant | NN | Prix affiché. |
| date_ingestion, date_derniere_vue | date | NN | Fraîcheur. |
| statut | text | NN | active / retiree / vendue. |
| UQ (id_bien, id_annonce) | | | Cible de FK composée depuis proposition. |

## proposition
Proposition d'un bien à une demande, **sous un mandat** (ADR-045).

| Colonne | Type | Clé/NN | Sens & justification |
|---|---|---|---|
| id_proposition | uuid | PK | — |
| id_demande, id_version | uuid | NN, FK comp.→demande_version | La proposition répond à une version de critères. |
| id_bien | uuid | NN, FK→bien | — |
| id_annonce_reference | uuid | FK comp.→annonce | — |
| id_mandat | uuid | NN, FK comp.→mandat | **Sous quel mandat** (même demande). Ferme S2/S3. |
| date_matching | timestamptz | NN | — |
| score_matching | numeric | | 0–100. |
| priorite_client | smallint | | Le client priorise (US05) ; > 0. |
| statut | text | NN | a_qualifier / soumis / retenu_visite / refuse_client / ecarte_chasseur. |
| motif_rejet | text | | Requis si refuse_client. |
| UQ partielle (id_demande,id_bien) WHERE statut vivant | | | Reproposer après baisse de prix (E4). |

## commentaire, visite, note_avis, document, document_rattachement
`commentaire` : échanges (sur demande ou proposition, une seule cible).
`visite` : visite d'un bien (statut, annulation motivée).
`note_avis` : conclusions du chasseur, **rattachée au mandat** (ADR-042), porte le
montant d'offre suggéré. `document` : métadonnée média (octets hors base, MinIO).
`document_rattachement` : liaison polymorphe document ↔ (note_avis | facture).

---

# Domaine 4 — Vente

Chaîne linéaire verrouillée par triggers (ADR-045).

## offre_acquisition
| Colonne | Type | Clé/NN | Sens |
|---|---|---|---|
| id_offre | uuid | PK | — |
| id_proposition | uuid | NN, FK→proposition | — |
| camp | text | NN | acquereur / vendeur. |
| saisi_par | text | NN | chasseur / gestionnaire / client. |
| montant | d_montant | NN | — |
| date_signature, date_validite, date_reponse | date | | Si statut≠en_cours, date_reponse requise. |
| origine_decouverte | text | | chasseur / client / tiers (droit à rémunération). |
| statut | text | NN | en_cours / acceptee / refusee / caduque / retiree. |

## compromis, acte
`compromis` : sur une offre **acceptée** (trigger), chez un `notaire`, avec
`clause_suspensive`. **ADR-048** : plus de statut stocké — signé/réalisé dérivés (v_compromis), `caduc` = flag `date_caducite`+motif. `acte` : sur un compromis
**réalisé** (trigger) ; porte `montant_vente`, honoraires, et l'**encaissement**
(`honoraires_encaisses`, `date_encaissement`) — fait générateur de la rémunération.

---

# Domaine 5 — Rémunération

## bareme, tranche_bareme, parametre_honoraires
`bareme` : défaut (id_chasseur NULL) ou propre à un chasseur, versionné, **sans
chevauchement de vigueur** (exclusion). `tranche_bareme` : intervalles
semi-ouverts `[min,max)`, **sans chevauchement** (exclusion). `parametre_honoraires` :
paramètres entreprise versionnés (optionnel).

## remuneration_chasseur
Part du chasseur, **figée** au jour de l'acte.

| Colonne | Type | Clé/NN | Sens |
|---|---|---|---|
| id_remuneration | uuid | PK | — |
| id_acte | uuid | NN, UQ, FK→acte | Un seul chasseur payé par acte (A2). |
| id_chasseur | uuid | NN | — |
| id_mandat | uuid | NN, FK comp.→mandat | **Le chasseur payé est celui du mandat** (S1). |
| honoraires, taux_base, majoration_anciennete, modulation_performance, taux_final | | | Éléments de gel. |
| montant | d_montant | NN | Rémunération finale. |
| id_bareme_applique | uuid | FK→bareme | Barème appliqué (traçabilité). |

## facture_chasseur
Cycle de facturation / paiement.

| Colonne | Type | Clé/NN | Sens |
|---|---|---|---|
| id_facture | uuid | PK | — |
| id_remuneration | uuid | NN, FK→remuneration_chasseur | — |
| numero | text | NN, UQ | — |
| montant | d_montant | NN | — |
| statut | text | NN | soumise / verifiee_conforme / rejetee. |
| statut_paiement | text | | programme / paye (si conforme). |
| date_emission, date_programmation, date_paiement | date | | — |

---

# Domaine 6 — Pilotage

## mandat
**Le pivot contractuel.** Engagement entre client et chasseur.

| Colonne | Type | Clé/NN | Sens & justification |
|---|---|---|---|
| id_mandat | uuid | PK | — |
| id_demande | uuid | NN, FK→demande | Demande d'origine. |
| id_version_contractuelle | uuid | NN, FK comp.→demande_version | Version de critères contractualisée. |
| id_chasseur | uuid | NN, FK→chasseur | — |
| id_signataire | uuid | NN, FK comp.→demande_acquereur | Acquéreur signataire (de la demande). |
| id_mandat_precedent | uuid | FK→mandat, UQ | Renouvellement ; pas d'auto-précédent (S9) ; même demande. |
| numero_registre | text | NN, UQ | Registre des mandats. |
| date_signature, date_debut | date | NN | date_debut = date_signature (A12). |
| mode_signature | text | NN | presentiel / en_ligne. |
| numero/validite_habilitation_signature | text/date | | Gel de l'habilitation à la signature (nullable à la reprise, M1). |
| exclusif | boolean | NN | Mandat exclusif ou non. |
| ~~statut~~ | — | — | **ADR-048 : SUPPRIMÉ.** État dérivé dans v_mandat (actif/échu/succès/renouvelé/résilié) ; `resilie` = flag `date_resiliation`. |
| taux_honoraires, forfait_honoraires | | | Taux OU forfait requis (ck_mandat_remun). |
| base_honoraires, taux_tva | | NN | HT/TTC, TVA. |
| qualite_signataire, reference_procuration | | | nom_propre / procuration (référence requise si procuration). |
| date_resiliation, motif_resiliation | | | Requis si statut=resilie. |
| UQ (id_mandat,id_demande) et (id_mandat,id_chasseur) | | | Cibles des FK composées (proposition, rémunération). |

## indicateur, periode, observation, objectif
Suivi de performance (alimente l'OLAP, ADR-036). `indicateur` : définition d'un
KPI. `periode` : fenêtre temporelle (unique par type+début). `observation` : valeur
d'un indicateur sur une période. `objectif` : cible d'un indicateur.

---

## Annexe — Vues (dérivées, non stockées)

Voir `dossier-modelisation-v82.md` §6. Les vues calculent l'expiration (mandat),
la conformité (chasseur), l'assiette d'honoraires, la version courante et la
charge gestionnaire, via `date_reference()` pour la reproductibilité (ADR-047).

## mandat_etat (ADR-048 §3)
Projection d'état du mandat. Active en v8.41, justifiée par le flux récurrent de rachats :
une partie de l'état (le « repris ») n'est pas calculable faute de faits, et un besoin
métier récurrent l'impose.

| Colonne | Type | Clé/NN | Sens |
|---|---|---|---|
| id_mandat | uuid | PK, FK→mandat | — |
| statut | text | NN | actif/echu/renouvele/resilie/clos_succes. |
| origine | text | NN | `repris` (fait historique non recalculable, fait foi, jamais écrasé) ou `calcule` (cache régénérable). |
| date_calcul | timestamptz | NN | — |

Règle : dans v_mandat, un état `origine='repris'` prime sur le calcul ; sinon l'état est dérivé des faits.

---

# Évolutions v8.41 (par rapport à v8.3)

| Table | Changement |
|---|---|
| `remuneration_chasseur` | Gel complet : toutes les colonnes de calcul NOT NULL ; **5 composantes** du score conservées (v8.41 : `score_delai`, `score_exclusivite`, `score_ventes`, `score_mandats`, `score_visites` — conformes à la spec) ; `CHECK taux_final BETWEEN 20 AND 60` ; flag `date_annulation`/`motif_annulation`. (ADR-049) |
| `offre_acquisition` | **`origine_decouverte` supprimé** : le droit à rémunération se dérive de l'existence de l'acte (ADR-049). |
| `mandat` | `type_resiliation` ajouté (dont `vente_externe`) ; `motif_resiliation` = détail libre. |
| `facture_chasseur` | `UNIQUE(id_remuneration)` ; colonnes de vérification (`date_verification`, `id_verificateur`, `motif_rejet`). |
| `document` | Métadonnées MinIO : `cle_objet`, `mime_type`, `taille_octets`, `hash_sha256`. |
| `note_avis` | Rattachée à **`id_proposition`** (au lieu de mandat+bien). |
| `document_rattachement` | **Supprimé** → remplacé par `note_avis_document` + `facture_document` (vraies FK). |
| `commentaire` | 3ᵉ cible `id_bien` (note métier chasseur) ; type `note_bien`. |

Migration (ADR-050) : UUID préfixés par source (anti-collision multisource), transaction unique + journal indépendant, validation bloquante, staging sans DROP (historique préservé), parsing allégé (critères ambigus non forcés).


---

# Évolutions v8.41 (par rapport à v8.4)

| Élément | Changement |
|---|---|
| `demande_version` | Booléens `exige_*` → **`pref_*`** (domaine `d_preference` : exige / souhaite / exclut / indifferent). « sans balcon » est désormais un **refus** exprimable. (ADR-052) |
| `remuneration_chasseur` | Composantes du score **corrigées pour coller à la spec** : `score_delai`, `score_exclusivite`, `score_ventes`, `score_mandats`, `score_visites` (+ global). Supprimés : `score_reussite`, `score_satisfaction`, `score_volume`, `score_anciennete` (inventés/doublon en v8.4). (ADR-052) |
| Base de données | Nommage `chasse_v7` → **`chasse_v8`** partout (scorie v7 purgée). |
| Tests | Skips d'intégration **bruyants** (`REQUIRE_DB=1` = échec), idempotence sur toutes les tables, test de **rollback**, sondes complètes (12), test aux limites du taux (19,99/20/60/60,01). |
| Migration | Anomalie **A10b** désormais tracée (canal réel inconnu). |
| Anonymisation | Traite aussi les comptes **`actif=false`** échus (trou RGPD), gardes conservées. |

Hors patch (renvoyés) : RLS / accès restreint rémunération & IBAN → fil API REST ; upsert / migration récurrente → chantier croissance ; test « client transactionnel » et contrôle croisé budget A03b → collègue (v8.42).
