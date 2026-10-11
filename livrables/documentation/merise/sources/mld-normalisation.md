## Normalisation

### Démarche

Le MLD est obtenu par les règles de passage ci-dessus, puis vérifié forme par forme. La cible est la **troisième forme normale (3FN)** pour toutes les relations transactionnelles ; les écarts sont des **dénormalisations décidées**, chacune tracée par un ADR, jamais des oublis.

### Première forme normale (1FN) — valeurs atomiques, pas de groupe répétitif

- Les critères de recherche de l'existant étaient un texte libre écrasé à chaque modification (`description_recherche`, anomalies A03 et A10c). Ils sont éclatés en attributs typés dans `demande_version` (`budget_max`, `surface_min`, `pref_balcon`…), une ligne par version : pas de liste dans une colonne, pas de perte d'historique.
- Les zones ciblées par une recherche et les zones d'intervention d'un chasseur sont des relations n,m (`version_zone`, `chasseur_zone`), pas des colonnes « zone_1, zone_2 ».
- Les documents joints sont des lignes de `document` reliées par `note_avis_document` et `facture_document`, pas des colonnes « pièce_jointe_n ».
- Seuls champs de texte libre conservés : `commentaire_criteres`, `description_initiale`, `contenu` (notes, commentaires), `motif_*`. Ils sont descriptifs ; aucune règle de gestion ne les lit.

### Deuxième forme normale (2FN) — tout attribut dépend de la clé entière

Concerne les relations à clé composée :

| Relation | Clé | Attributs portés | Dépendance |
|---|---|---|---|
| `demande_acquereur` | (id_demande, id_client) | `qualite` | la qualité (principal / co-acquéreur) n'a de sens que pour le couple |
| `chasseur_zone` | (id_chasseur, id_zone) | `role_intervention` | le rôle dépend du couple |
| `observation` | (id_utilisateur, code_indicateur, id_periode) | `valeur`, `date_calcul` | une mesure est propre au triplet |
| `objectif` | (id_utilisateur, code_indicateur, id_periode) | `valeur_cible`, `date_fixation` | idem |
| `version_zone`, `note_avis_document`, `facture_document` | couples de clés | — | aucun attribut : rien à vérifier |

Aucun attribut ne dépend d'une partie seulement de la clé.

### Troisième forme normale (3FN) — pas de dépendance transitive

Les dépendances transitives repérées, et ce qui en a été fait :

| Relation | Dépendance | Décision | Référence |
|---|---|---|---|
| `zone` | `code_iso_pays` → `pays`, `devise` | **Dénormalisation assumée** : le référentiel des pays n'est pas modélisé en phase 2 (un seul pays en production) ; la conformité par pays est différée (CDC v3.0, PO-6). À normaliser en phase 3 (relation `pays`) lors de l'ouverture européenne | ADR-ouverture-internationale |
| `demande` | `id_chasseur`, `date_affectation` dérivables de l'affectation ouverte | **Redondance maintenue par trigger** (`tg_affectation_sync`) : lecture directe du chasseur courant sans parcourir l'historique des affectations | ADR-048 |
| `demande` | `id_mandat_courant` dérivable des mandats | **Fait de gestion**, pas une dérivation : le gestionnaire désigne le mandat courant (renouvellements, reprise) | ADR-048 |
| `mandat` | `numero_habilitation_signature`, `validite_habilitation_signature` copiés du chasseur | **Gel juridique** : c'est l'habilitation *à la date de signature* qui compte (loi Hoguet) ; la valeur courante du chasseur change ensuite. Dépendance temporelle, pas transitive | ADR-039, ADR-046 |
| `remuneration_chasseur` | toutes les composantes du calcul (scores, taux, barème appliqué) | **Gel complet au jour de l'acte** : le calcul doit rester reconstituable si le barème ou les règles changent | ADR-049, ADR-052 |
| `acte` | `honoraires_fixe`, `honoraires_taux` face à `mandat.taux_honoraires` | Pas une dépendance : les honoraires constatés à l'acte peuvent différer du mandat (négociation, forfait) ; l'assiette est ce que le notaire collecte | ADR-049 |
| `parrainage` | `filleul_nom`, `filleul_prenom` face à `id_filleul` | Pas une dépendance : le filleul est déclaré avant d'exister comme utilisateur ; `id_filleul` est renseigné ensuite | ADR-034, ADR-parrainage |
| `mandat_reprise` | `statut_repris` face à l'état dérivé | **Fait historique non recalculable** (reprise de données) : il prime sur le calcul | ADR-051 |

### Forme normale de Boyce-Codd (FNBC) — clés candidates

Chaque relation a une clé primaire technique (UUIDv7) et, le cas échéant, une clé candidate métier déclarée `UNIQUE` : `utilisateur.email`, `gestionnaire.matricule`, `mandat.numero_registre`, `annonce(source, reference_source)`, `notaire(nom, etude)`, `facture_chasseur.numero`, `remuneration_chasseur.id_acte` (une rémunération par acte), `acte.id_compromis`, `acte.id_mandat`, `mandat.id_mandat_precedent` (successeur unique). Tout déterminant est une clé candidate : la FNBC est respectée.

### Ce que le modèle relationnel ne sait pas exprimer, et où c'est porté

| Règle | Pourquoi hors MLD | Portée par |
|---|---|---|
| Un acte a exactement une origine (compromis ou mandat) | contrainte sur deux colonnes facultatives | `CHECK ck_acte_origine` (MPD) |
| Deux barèmes ou deux tranches ne se chevauchent pas | contrainte d'intervalle | `EXCLUDE USING gist` (MPD, ADR-045) |
| Un renouvellement commence au moins 6 mois après le précédent | règle inter-lignes | trigger `tg_mandat_succession` (ADR-048) |
| Un acte hors dispositif exige un mandat exclusif en vigueur ; la rémunération porte sur le mandat en vigueur de la chaîne | règle inter-lignes et temporelle | triggers S24, S25, S26 et re-vérification différée (ADR-053, D13) |
| L'état d'un mandat, d'une demande, d'un compromis | dérivé, jamais stocké | vues `v_mandat`, `v_demande`, `v_compromis` (ADR-048) |

### Rattachement RNCP40573

BC05 — « Concevoir la base pour l'analytique et l'IA » : MLD normalisé, dénormalisations justifiées et tracées. BC03 — intégrité portée par le SGBD (clés, unicités, contraintes, déclencheurs). BC01 — chaque écart à la 3FN renvoie à une décision d'architecture.
