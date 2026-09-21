# Gherkin — Cours

> Cible : développeurs & AMOA. Axe : **description du fonctionnel** et **bornage des fonctionnalités**.

---

## Sommaire

1. [À quoi sert Gherkin](#1-à-quoi-sert-gherkin)
2. [Position dans la chaîne de spécification](#2-position-dans-la-chaîne-de-spécification)
3. [Syntaxe complète](#3-syntaxe-complète)
4. [Écrire un comportement : les règles de rédaction](#4-écrire-un-comportement--les-règles-de-rédaction)
5. [Structurer une fonctionnalité](#5-structurer-une-fonctionnalité)
6. [**Borner une fonctionnalité : dire ce qui ne doit pas être**](#6-borner-une-fonctionnalité--dire-ce-qui-ne-doit-pas-être)
7. [Anti-patterns et grille de relecture](#7-anti-patterns-et-grille-de-relecture)
8. [Cycle de vie, gouvernance, outillage](#8-cycle-de-vie-gouvernance-outillage)
9. [Fiche mémo](#9-fiche-mémo)

---

## 1. À quoi sert Gherkin

### 1.1 Le problème

Une spécification classique en prose souffre de trois défauts systématiques :

| Défaut | Manifestation typique |
|---|---|
| **Ambiguïté** | « Le manager valide rapidement la demande. » Rapidement = 24 h ? 5 jours ? Le manager = le N+1 hiérarchique ou le responsable budgétaire ? |
| **Incomplétude silencieuse** | Le cas nominal est décrit ; les cas de refus, les limites et les effets de bord ne le sont pas. Ils seront tranchés par le développeur, seul, en fin de sprint. |
| **Dérive** | Le document est écrit avant le développement puis n'est plus jamais mis à jour. Six mois après, personne ne sait quelle version dit vrai : le doc ou le code. |

### 1.2 La réponse : l'exemple concret

Gherkin est un **langage de description de comportement par l'exemple**. Le principe fondateur, issu du BDD (*Behaviour-Driven Development*, Dan North, 2006) et de la *Specification by Example* (Gojko Adzic, 2011) :

> Une règle métier est ambiguë tant qu'elle n'est pas illustrée par des exemples concrets, chiffrés, et vérifiables.

Concrètement, on n'écrit pas seulement « les notes de frais au-delà d'un certain montant nécessitent une double validation ». On écrit la règle **et** ses exemples :

```gherkin
# language: fr
Règle: Une note de frais dont le montant total dépasse 500 € nécessite une validation
       par le manager puis par le contrôle de gestion

  Exemple: 499,99 € ne déclenche pas la double validation
    ...

  Exemple: 500,00 € déclenche la double validation
    ...
```

La deuxième formulation force la question « et à exactement 500 € ? » à être posée **avant** le développement. C'est là que se trouve l'essentiel de la valeur.

### 1.3 Le triple usage d'un fichier `.feature`

Un même fichier sert trois publics simultanément. C'est sa raison d'être :

| Public | Usage |
|---|---|
| AMOA / métier | Spécification lisible, discutable, validable sans compétence technique |
| Développeur | Critères d'acceptation non ambigus, et point d'ancrage des tests automatisés |
| Tout le monde | **Documentation vivante** : le fichier est exécuté à chaque build. S'il est faux, le build casse. Il ne peut donc pas dériver silencieusement. |

C'est le seul format de spécification qui a cette propriété. Si vous n'exécutez pas vos `.feature`, vous perdez 60 % de l'intérêt de Gherkin — mais pas 100 % : la discipline de rédaction reste précieuse.

### 1.4 L'atelier des Trois Amigos

Gherkin n'est pas un livrable qu'une personne rédige seule dans son coin. Le format de travail associé est l'atelier **Three Amigos** (aussi appelé *Example Mapping*, Matt Wynne, 2015), qui réunit trois points de vue :

- **Métier / AMOA** : quelle est la règle, quelle est l'intention ?
- **Développement** : est-ce réalisable, quels cas techniques n'ont pas été envisagés ?
- **Test / QA** : quels cas cassent la règle, quelles sont les limites ?

Format court (25 min max) sur cartes de 4 couleurs :

| Couleur | Contenu |
|---|---|
| Jaune | Le récit / la user story |
| Bleu | Les **règles** métier |
| Vert | Les **exemples** qui illustrent chaque règle |
| Rouge | Les **questions ouvertes** que personne ne sait trancher séance tenante |

Signal de sortie : beaucoup de cartes rouges ⇒ la story n'est pas prête, ne pas l'embarquer dans le sprint. Beaucoup de cartes bleues ⇒ la story est trop grosse, la découper.

Les cartes bleues deviennent des `Règle:`, les cartes vertes deviennent des `Exemple:`. Gherkin n'est que la **mise au propre** du résultat de l'atelier.

---

## 2. Position dans la chaîne de spécification

```
Besoin métier (vision, valeur)
        │
        ▼
User story  ─────────► "En tant que… je veux… afin de…"
        │                (le POURQUOI et pour QUI)
        ▼
Atelier 3 amigos ────► règles + exemples + questions
        │
        ▼
Fichier .feature ────► Fonctionnalité / Règle / Exemples
        │                (le QUOI, observable, borné)
        ▼
Step definitions ────► code de liaison (le COMMENT du test)
        │
        ▼
Code applicatif  ────► le COMMENT de la solution
```

**Erreur fréquente n°1** : mettre le *pourquoi* dans les scénarios. Le *pourquoi* va dans la description de la `Fonctionnalité`, en prose libre.

**Erreur fréquente n°2** : mettre le *comment* dans les scénarios (clics, écrans, appels API, tables SQL). Le *comment* va dans les step definitions, en code.

Le scénario ne contient que le **quoi observable par le métier**.

---

## 3. Syntaxe complète

### 3.1 Le fichier

- Extension `.feature`, encodage **UTF-8**.
- Une seule `Fonctionnalité:` par fichier. C'est une contrainte du parser, pas une convention.
- L'indentation n'a **aucune valeur syntaxique** : elle sert uniquement la lisibilité humaine. Convention : 2 espaces par niveau.
- La langue est déclarée en **première ligne** du fichier :

```gherkin
# language: fr
```

Sans cette ligne, le parser attend l'anglais. 80 langues sont disponibles dans Gherkin 42.

### 3.2 Mots-clés français ↔ anglais

Table extraite du fichier `gherkin-languages.json` du parser officiel (`gherkin-official` v42.0.1) — c'est la source de vérité, pas la documentation.

| Rôle | Français | Anglais |
|---|---|---|
| Fonctionnalité | `Fonctionnalité` | `Feature`, `Business Need`, `Ability` |
| Règle métier | `Règle` | `Rule` |
| Scénario | `Exemple`, `Scénario` | `Example`, `Scenario` |
| Scénario paramétré | `Plan du scénario`, `Plan du Scénario` | `Scenario Outline`, `Scenario Template` |
| Table de données du plan | `Exemples` | `Examples`, `Scenarios` |
| Contexte partagé | `Contexte` | `Background` |
| Étape — état initial | `Soit`, `Sachant`, `Sachant que`, `Sachant qu'`, `Etant donné`, `Etant donné que`, `Etant donné qu'`, `Étant donné`, `Étant donné que`, `Étant donné qu'`, + accords `Etant donnée / donnés / données` | `Given` |
| Étape — action | `Quand`, `Lorsque`, `Lorsqu'` | `When` |
| Étape — résultat | `Alors`, `Donc` | `Then` |
| Enchaînement | `Et`, `Et que`, `Et qu'` | `And` |
| Contraste | `Mais`, `Mais que`, `Mais qu'` | `But` |
| Étape neutre | `*` | `*` |

Points de vigilance :

- Les mots-clés d'étape sont suivis d'un **espace** (`Quand `). `Quandje...` n'est pas reconnu.
- `Fonctionnalité` n'a **aucun synonyme** en français, contrairement à l'anglais.
- `Donc` est un synonyme valide de `Alors`. À éviter en pratique : deux mots-clés pour la même chose dans un même dépôt nuisent à la relecture. **Choisir une forme et s'y tenir** (recommandation : `Étant donné que` / `Quand` / `Alors` / `Et`).
- `*` remplace n'importe quel mot-clé. Utile quand une liste d'étapes de même nature devient illisible ; dangereux car il efface la sémantique Given/When/Then. À réserver aux listes de données.

### 3.3 Anatomie complète

```gherkin
# language: fr
@notes-de-frais @lot-2
Fonctionnalité: Soumission d'une note de frais

  Texte libre de description, non exécuté par le parser.
  Sert à porter le pourquoi, le périmètre, le hors-périmètre,
  les liens vers les autres documents et le glossaire.

  Contexte:
    Étant donné que le salarié "Dupont" est rattaché au service "Commercial"

  Règle: Une dépense de restauration est plafonnée à 25 € par repas

    Exemple: Une dépense de restauration sous le plafond est acceptée
      Étant donné que Dupont saisit une dépense de restauration de 18,50 €
      Quand il soumet sa note de frais
      Alors la note de frais est "En attente de validation"

    @refus
    Exemple: Une dépense de restauration au-dessus du plafond est refusée
      Étant donné que Dupont saisit une dépense de restauration de 31,00 €
      Quand il soumet sa note de frais
      Alors la soumission est refusée
      Et le motif affiché est "Plafond restauration dépassé : 31,00 € pour un maximum de 25,00 €"

  Règle: Le plafond s'applique par repas, pas par journée

    Plan du scénario: Deux repas dans la même journée sont évalués séparément
      Étant donné que Dupont saisit une dépense de restauration de <midi> € le 12/03/2026
      Et qu'il saisit une dépense de restauration de <soir> € le 12/03/2026
      Quand il soumet sa note de frais
      Alors la note de frais est "<statut>"

      Exemples: Les deux repas sont sous le plafond
        | midi  | soir  | statut                  |
        | 24,00 | 24,00 | En attente de validation |
        | 25,00 | 25,00 | En attente de validation |

      Exemples: Un des deux repas dépasse le plafond
        | midi  | soir  | statut  |
        | 25,01 | 10,00 | Refusée |
        | 10,00 | 25,01 | Refusée |
```

### 3.4 Les blocs de données

**Table de données** (attachée à une étape) — pour décrire un ensemble structuré :

```gherkin
    Étant donné que la note de frais de Dupont contient les dépenses suivantes:
      | date       | catégorie    | montant |
      | 12/03/2026 | Restauration | 18,50   |
      | 12/03/2026 | Taxi         | 32,00   |
      | 13/03/2026 | Hôtel        | 145,00  |
```

**Docstring** (texte long, délimité par `"""` ou `` ``` ``) — pour un contenu textuel exact :

```gherkin
    Alors le courriel envoyé au manager contient:
      """
      Bonjour,
      Dupont a soumis une note de frais de 195,50 € le 14/03/2026.
      Cette note nécessite votre validation avant le 21/03/2026.
      """
```

Ne pas confondre :

| | Table de données | `Exemples` d'un plan de scénario |
|---|---|---|
| Attachée à | une étape | un `Plan du scénario` |
| Effet | fournit une donnée structurée à **un seul** scénario | génère **N scénarios**, un par ligne |
| Indice visuel | pas de `<placeholder>` dans l'étape | des `<placeholder>` dans les étapes |

### 3.5 Tags

Les tags sont des étiquettes posées sur une `Fonctionnalité`, une `Règle`, un `Exemple` ou un bloc `Exemples`. Ils sont **hérités** vers le bas.

```gherkin
@lot-2
Fonctionnalité: …

  @critique
  Exemple: …     # porte @lot-2 et @critique
```

Usages sains :

| Tag | Sens |
|---|---|
| `@lot-2`, `@sprint-14` | rattachement à un incrément de livraison |
| `@JIRA-1234` | traçabilité vers le référentiel d'exigences |
| `@critique`, `@smoke` | sélection d'un sous-ensemble à l'exécution |
| `@wip` | en cours de rédaction, exclu du build |
| `@manuel` | scénario non automatisable, exécuté à la main |

Usage à éviter : encoder de la logique métier dans un tag (`@montant-eleve`). Le métier doit se lire dans le texte des étapes, pas dans les étiquettes.

### 3.6 Commentaires

```gherkin
  # Ligne de commentaire. Doit occuper toute la ligne.
  Étant donné que … # ceci N'EST PAS un commentaire, c'est du texte d'étape
```

Un commentaire est une ligne entière commençant par `#`. Il n'y a pas de commentaire de fin de ligne en Gherkin.

Règle de bon sens : un commentaire dans un `.feature` est presque toujours le signe que le texte des étapes n'est pas assez explicite. Corriger le texte plutôt que d'ajouter un commentaire.

### 3.7 Les erreurs silencieuses

Certaines fautes ne produisent **aucune erreur de parsing** : le fichier est accepté, mais il n'exécute pas ce qu'on croit. Ce sont les plus dangereuses.

| Faute | Conséquence silencieuse |
|---|---|
| `Plan du scénario` sans bloc `Exemples:` | Le plan génère **0 scénario**. La table est réinterprétée comme table de données de la dernière étape. |
| Mot-clé d'un autre dialecte (`Scenario:` dans un fichier `# language: fr`) | La ligne et tout ce qui suit sont absorbés dans la **description** en texte libre. Les scénarios disparaissent. |
| Ligne de texte libre sous une `Fonctionnalité:` ressemblant à un scénario | Idem : avalée par la description. |
| Bloc `Exemples:` vide | 0 scénario généré. |
| Fichier `.feature` non pris par le glob de configuration | Jamais exécuté. |

**Contre-mesure, à mettre en place dès le premier jour** : afficher et surveiller le **nombre de scénarios exécutés** à chaque build. Une chute de ce nombre est un incident, au même titre qu'un test rouge. Un `.feature` qui n'exécute rien laisse la CI verte — c'est le pire des cas.

Note : une étape occupe **une seule ligne**. Un retour à la ligne pour « aérer » une étape longue produit soit une erreur de parsing, soit une absorption silencieuse selon l'endroit. Pour un contenu long, utiliser une docstring.

---

## 4. Écrire un comportement : les règles de rédaction

### 4.1 La sémantique Given / When / Then

C'est la partie que tout le monde croit connaître et que presque personne n'applique correctement.

| Mot-clé | Sémantique stricte | Temps |
|---|---|---|
| `Étant donné que` | **État du monde avant l'action.** Un contexte, pas une action. Décrit ce qui *est déjà vrai*. | Présent / passé composé |
| `Quand` | **L'action déclenchante, et elle seule.** Un événement, un seul, causé par un acteur. | Présent |
| `Alors` | **Le résultat observable.** Une assertion vérifiable par le métier. | Présent |

Trois tests de validation à appliquer systématiquement :

1. **Test du `Quand` unique.** Un scénario = un événement déclencheur = un seul `Quand`. Deux `Quand` ⇒ deux scénarios, ou bien le premier `Quand` était en réalité un `Étant donné`.
2. **Test de l'observabilité.** Un `Alors` doit être vérifiable par une personne du métier qui regarde le système. « Alors la ligne est insérée en base » échoue au test. « Alors la note de frais apparaît dans la liste des demandes à valider du manager » le passe.
3. **Test de l'acteur.** Un `Quand` a toujours un sujet identifiable. « Quand le traitement est lancé » ⇒ lancé par qui, par quoi ? Souvent la réponse révèle une règle métier oubliée.

Piège classique — le `Étant donné` qui est une action déguisée :

```gherkin
  # ✗ Mauvais : deux actions, dont une masquée en Given
  Étant donné que Dupont soumet sa note de frais
  Quand le manager la valide
  Alors …
```

Ici, la soumission est-elle *le sujet du test* ou *un prérequis* ? Si c'est un prérequis, il faut le formuler comme un état :

```gherkin
  # ✓ Bon : un état, puis une action
  Étant donné qu'une note de frais de Dupont est en attente de validation
  Quand le manager la valide
  Alors …
```

Ce n'est pas de la coquetterie : la première version couple le scénario de validation au processus de soumission. Si la soumission change, le scénario de validation casse sans raison métier.

### 4.2 Déclaratif vs impératif

C'est **le** critère de qualité d'un fichier `.feature`.

| | Impératif (à proscrire) | Déclaratif (à viser) |
|---|---|---|
| Décrit | la manipulation de l'interface | l'intention métier |
| Durée de vie | casse à chaque refonte d'écran | survit aux refontes |
| Lisible par | personne, en fait | le métier |

```gherkin
  # ✗ Impératif
  Étant donné que je suis sur la page "/expenses/new"
  Quand je saisis "18,50" dans le champ "montant"
  Et que je sélectionne "Restauration" dans la liste "categorie"
  Et que je clique sur le bouton "Enregistrer"
  Et que je clique sur le bouton "Soumettre"
  Et que je clique sur "Confirmer" dans la boîte de dialogue
  Alors je vois le texte "OK" dans le div "#flash-message"
```

Sept étapes, zéro information métier. On ne sait pas ce qui est testé. Un changement de libellé de bouton casse le test.

```gherkin
  # ✓ Déclaratif
  Étant donné que Dupont a saisi une dépense de restauration de 18,50 €
  Quand il soumet sa note de frais
  Alors sa note de frais est en attente de validation par son manager
```

Trois étapes, la règle métier est lisible. Le *comment* (le clic, le champ, l'URL) est descendu dans les step definitions, où il a sa place et où il est modifiable sans toucher à la spécification.

**Heuristique de détection de l'impératif** : chercher dans le fichier les mots *clique, saisis, page, bouton, champ, écran, onglet, coche, sélectionne dans la liste, URL, formulaire*. Chaque occurrence est un candidat au refactoring.

### 4.3 Le bon niveau d'abstraction

Trop impératif est le défaut le plus courant, mais trop abstrait existe aussi :

```gherkin
  # ✗ Trop abstrait : ne dit rien de vérifiable
  Étant donné qu'un utilisateur a des données
  Quand il fait une action
  Alors le résultat est correct
```

Le curseur correct : **le niveau auquel une personne du métier décrirait la situation à un collègue**.

> « Dupont a mangé au restaurant pour 18,50 € pendant son déplacement, il soumet sa note, elle part chez son manager. »

Ni les clics, ni « des données ».

### 4.4 Les valeurs concrètes

Une spécification par l'exemple sans valeurs concrètes n'est pas une spécification par l'exemple.

```gherkin
  # ✗
  Étant donné qu'une dépense dépasse le plafond
  Alors elle est refusée

  # ✓
  Étant donné une dépense de restauration de 31,00 €
  Alors elle est refusée avec le motif "Plafond restauration dépassé : maximum 25,00 €"
```

La version ✗ n'apporte rien de plus que la règle métier elle-même : elle ne lève aucune ambiguïté. La version ✓ oblige à trancher le plafond, sa devise, et le libellé du refus.

### 4.5 Langage ubiquitaire

Un même concept métier = **un seul terme**, dans les `.feature`, dans le code, dans les conversations, dans l'interface.

Si le métier dit « note de frais », le fichier ne dit ni « expense report », ni « déclaration », ni « ticket », ni « demande de remboursement ». Une table de glossaire en tête de dossier `features/` évite bien des débats :

```markdown
| Terme            | Définition                                                          |
|------------------|---------------------------------------------------------------------|
| Note de frais    | Regroupement de dépenses soumis en une fois pour remboursement       |
| Dépense          | Une ligne de la note de frais : date, catégorie, montant, justificatif |
| Soumission       | Action du salarié qui envoie sa note de frais dans le circuit        |
| Validation       | Décision favorable du manager                                        |
| Rejet            | Décision défavorable du manager, avec motif obligatoire               |
| Refus            | Blocage automatique par une règle, sans intervention humaine          |
```

Noter la distinction **Rejet** (humain) / **Refus** (automatique) : ce genre de précision de vocabulaire, décidée une fois, économise des dizaines d'allers-retours.

---

## 5. Structurer une fonctionnalité

### 5.1 `Fonctionnalité` : le conteneur et son texte libre

La description libre sous `Fonctionnalité:` n'est pas exécutée. C'est pourtant l'un des emplacements les plus utiles du fichier, parce que c'est le seul endroit où l'on peut écrire de la prose. On y place :

```gherkin
# language: fr
Fonctionnalité: Soumission d'une note de frais

  En tant que salarié
  Je veux soumettre mes dépenses professionnelles
  Afin d'en obtenir le remboursement sous 30 jours

  Contexte réglementaire : politique voyage v4.2 (intranet/RH/politique-voyage).
  Référence : JIRA EPIC-412.

  Périmètre couvert par cette fonctionnalité :
    - saisie et soumission des dépenses par le salarié
    - contrôles automatiques de plafonds et de justificatifs

  Hors périmètre (voir §6 pour la méthode) :
    - le circuit de validation manager → fichier validation-note-de-frais.feature
    - le versement bancaire effectif → hors SI, géré par la paie
```

### 5.2 `Règle` : le pivot du document

`Règle` (Gherkin 6+, 2018) est le mot-clé le plus important pour l'AMOA, et le plus sous-utilisé. Il permet de faire porter le sens par **la règle métier** et non par la liste plate de scénarios.

Sans `Règle` — la logique métier est invisible, il faut lire les 12 scénarios pour la reconstituer :

```gherkin
Fonctionnalité: Note de frais
  Exemple: Restauration à 18 €
  Exemple: Restauration à 31 €
  Exemple: Taxi sans justificatif
  Exemple: Taxi avec justificatif
  Exemple: Note de plus de 500 €
  …
```

Avec `Règle` — la spécification s'auto-documente :

```gherkin
Fonctionnalité: Note de frais

  Règle: Une dépense de restauration est plafonnée à 25 € par repas
    Exemple: 18,50 € est accepté
    Exemple: 31,00 € est refusé
    Exemple: 25,00 € pile est accepté

  Règle: Toute dépense de plus de 20 € exige un justificatif numérisé
    Exemple: Taxi à 32 € sans justificatif → refusé
    Exemple: Taxi à 32 € avec justificatif → accepté
    Exemple: Métro à 2,10 € sans justificatif → accepté

  Règle: Une note de frais de plus de 500 € passe en double validation
    …
```

Bénéfices concrets :

1. La liste des `Règle:` est **le résumé exécutif** de la fonctionnalité. Un directeur peut la lire en 30 secondes.
2. Une règle sans exemple signale un trou de spécification.
3. Un exemple qui n'appartient à aucune règle signale soit une règle implicite non écrite, soit un scénario superflu.
4. `Règle` accepte son propre `Contexte:` local, ce qui évite de polluer le contexte global.

### 5.3 `Contexte` : à manier avec parcimonie

`Contexte` factorise les étapes `Étant donné` communes à tous les scénarios de son bloc.

Trois règles d'usage :

- **Uniquement des `Étant donné`.** Un `Quand` dans un `Contexte` est une faute de conception.
- **Court** : 4 étapes maximum. Au-delà, le lecteur doit faire des allers-retours pour comprendre un scénario, ce qui annule le bénéfice.
- **Pas de contexte technique.** « Étant donné que la base est vide », « Étant donné que je suis connecté » : ces étapes relèvent du harnais de test, pas de la spécification. À descendre dans les hooks (`Before`) du framework.

### 5.4 `Plan du scénario` : quand et quand pas

À utiliser quand **la même règle** est illustrée par plusieurs jeux de valeurs, typiquement autour d'une frontière :

```gherkin
  Plan du scénario: Application du plafond de restauration
    Étant donné une dépense de restauration de <montant> €
    Quand la note de frais est soumise
    Alors la dépense est "<décision>"

    Exemples: Sous et à la limite du plafond
      | montant | décision |
      | 0,01    | Acceptée |
      | 24,99   | Acceptée |
      | 25,00   | Acceptée |

    Exemples: Au-delà du plafond
      | montant | décision |
      | 25,01   | Refusée  |
      | 999,00  | Refusée  |
```

À **ne pas** utiliser :

- Quand les lignes n'illustrent pas la même règle. Deux règles ⇒ deux plans, ou deux `Règle:`.
- Pour faire de la combinatoire exhaustive. Une table de 40 lignes n'est plus une spécification, c'est un jeu de données : elle doit descendre dans le code de test (test paramétré unitaire).
- Quand un seul exemple suffit à lever l'ambiguïté.

Deux techniques de lisibilité, visibles ci-dessus :

- **Plusieurs blocs `Exemples` nommés** dans un même plan : chaque bloc porte une intention (« sous la limite », « au-delà »). C'est bien plus parlant qu'une table unique de 5 lignes.
- **Colonne de décision explicite** plutôt qu'une colonne booléenne `| ok |` avec `true/false`.

### 5.5 Organisation des fichiers

```
features/
├── GLOSSAIRE.md
├── note-de-frais/
│   ├── soumission.feature
│   ├── validation-manager.feature
│   ├── controle-de-gestion.feature
│   └── HORS-PERIMETRE.md
└── remboursement/
    └── ...
```

Critères de découpage :

- Un fichier = **une fonctionnalité du point de vue métier**, pas un écran, pas une classe, pas une US.
- Un fichier de plus de ~250 lignes ou de plus de ~15 scénarios est presque toujours à découper.
- Le nom du fichier suit le nom de la fonctionnalité, en kebab-case.

---

## 6. Borner une fonctionnalité : dire ce qui ne doit pas être

C'est le cœur de ce cours. Un développeur, confronté à une spécification muette sur un cas, ne s'arrête pas : il tranche. Il tranche vite, seul, et souvent contre l'intention métier. **Le bornage est le mécanisme qui évite cette décision par défaut.**

### 6.1 Les cinq formes du « non »

Le mot « ça ne doit pas se produire » recouvre cinq réalités radicalement différentes. Les confondre est l'erreur la plus coûteuse en spécification.

| # | Forme | Définition | Où l'écrire | Exécutable ? |
|---|---|---|---|---|
| 1 | **Comportement de refus** | Le système *doit* réagir, et sa réaction est un refus explicite | `Exemple:` avec un `Alors` de refus | ✅ Oui |
| 2 | **Invariant / non-effet** | Le système ne doit produire *aucun* effet dans un cas donné | `Alors` négatif (« aucun courriel n'est envoyé ») | ✅ Oui |
| 3 | **Borne de valeur** | La frontière exacte entre l'accepté et le refusé | `Plan du scénario` sur les valeurs limites | ✅ Oui |
| 4 | **Hors périmètre** | Le sujet n'est pas traité par cette fonctionnalité, ni maintenant ni plus tard | Prose, description de `Fonctionnalité` | ❌ Non, volontairement |
| 5 | **Différé** | Le besoin est reconnu, la décision est prise, la réalisation est reportée | Prose + tag `@differe-lot-3` ou ticket | ❌ Non, pour l'instant |

Les formes 1–3 **appartiennent au périmètre** : ce sont des comportements, on les teste. Les formes 4–5 **définissent le périmètre par sa frontière extérieure** : elles ne sont pas testables et ne doivent pas l'être.

Écrire un scénario pour du hors-périmètre est une faute : cela crée un test qui vérifie qu'une fonctionnalité n'existe pas, test qui cassera le jour où on l'implémentera légitimement.

---

### 6.2 Forme 1 — Le comportement de refus

Le refus est un **comportement de premier rang**, pas un cas d'erreur secondaire. Il mérite le même niveau de détail que le cas nominal.

```gherkin
  Règle: Une note de frais ne peut pas être soumise plus de 90 jours après la date
         de la dépense la plus ancienne

    Exemple: Soumission dans les délais
      Étant donné que nous sommes le 10/06/2026
      Et qu'une note de frais contient une dépense datée du 15/03/2026
      Quand le salarié soumet sa note de frais
      Alors la note de frais est en attente de validation

    Exemple: Soumission hors délai
      Étant donné que nous sommes le 20/06/2026
      Et qu'une note de frais contient une dépense datée du 15/03/2026
      Quand le salarié soumet sa note de frais
      Alors la soumission est refusée
      Et le motif est "Dépense du 15/03/2026 antérieure de plus de 90 jours"
      Et la note de frais reste au statut "Brouillon"
```

Points de qualité, tous obligatoires :

1. **Le motif exact est spécifié**, entre guillemets, tel qu'il sera lu par l'utilisateur. Sans cela, le développeur inventera « Erreur 422 » ou « Opération impossible ».
2. **L'état résultant est spécifié** (`reste au statut "Brouillon"`). Un refus laisse le système dans un état : lequel ? Perd-on la saisie ?
3. **La date de référence est explicite** (`nous sommes le 20/06/2026`). Un scénario qui dépend de la date du jour est un scénario qui cassera.

Question de relecture à poser systématiquement pour chaque refus : *« Que voit l'utilisateur, et que devient sa saisie ? »*

---

### 6.3 Forme 2 — L'invariant / non-effet

Le cas le plus souvent oublié, et celui qui produit les incidents les plus gênants en production (courriels indus, doublons, notifications parasites).

```gherkin
  Règle: Une note de frais refusée automatiquement ne déclenche aucune notification
         au manager

    Exemple: Aucune notification en cas de refus automatique
      Étant donné qu'une note de frais contient une dépense de restauration de 31,00 €
      Quand le salarié soumet sa note de frais
      Alors la soumission est refusée
      Et aucun courriel n'est envoyé au manager
      Et la note de frais n'apparaît pas dans la liste des demandes à valider du manager
```

Comment formuler un non-effet correctement :

| Formulation | Verdict |
|---|---|
| `Alors rien ne se passe` | ✗ Intestable. « Rien » n'est pas observable. |
| `Alors le système ne plante pas` | ✗ Ce n'est pas une exigence fonctionnelle. |
| `Alors aucun courriel n'est envoyé au manager` | ✓ Un observable précis, une négation précise. |
| `Alors le solde de congés de Dupont reste à 12 jours` | ✓ Non-effet exprimé comme une constance de valeur. |

**Règle de rédaction** : un non-effet doit citer **l'observable précis qui ne change pas** ou **l'action précise qui n'a pas lieu**. Jamais une négation globale.

Grille des non-effets à passer en revue pour toute fonctionnalité — c'est un excellent réflexe d'atelier :

- courriels / notifications / SMS / webhooks
- écritures comptables, mouvements de stock, débits
- changements de statut
- appels aux systèmes tiers
- entrées de journal d'audit
- compteurs et quotas

---

### 6.4 Forme 3 — La borne de valeur

Toute règle qui contient un seuil, une durée, un nombre ou une plage doit être bornée par des exemples **des deux côtés de la frontière, et sur la frontière**.

La formulation « au-delà de 25 € » est ambiguë : 25,00 € est-il au-delà ? La table de valeurs limites tranche mécaniquement la question.

```gherkin
  Règle: Le plafond restauration est de 25,00 € par repas, plafond inclus

    Plan du scénario: Frontière du plafond restauration
      Étant donné une dépense de restauration de <montant> €
      Quand la note de frais est soumise
      Alors la dépense est "<décision>"

      Exemples: Limite basse et bornes acceptées
        | montant | décision |
        | 0,01    | Acceptée |
        | 24,99   | Acceptée |
        | 25,00   | Acceptée |

      Exemples: Premier montant refusé
        | montant | décision |
        | 25,01   | Refusée  |
```

Modèle de valeurs à couvrir pour toute borne — 5 lignes suffisent, inutile d'en écrire 30 :

| Valeur | Rôle |
|---|---|
| minimum acceptable | vérifie qu'il n'y a pas de plancher caché |
| borne − 1 unité | dernier accepté |
| **borne exacte** | **tranche l'inclusion / exclusion — la ligne la plus importante** |
| borne + 1 unité | premier refusé |
| valeur aberrante (0, négatif, très grand) | vérifie qu'il n'y a pas de comportement inattendu |

Attention à l'unité : « + 1 unité » vaut 0,01 pour un montant en euros, 1 pour un nombre de jours, 1 seconde pour une durée. La préciser dans le texte de la `Règle` (« plafond inclus », « strictement supérieur à »).

---

### 6.5 Forme 4 — Le hors périmètre

C'est ici que les projets se perdent. Une fonctionnalité qui ne dit pas ce qu'elle ne fait pas se fait grignoter par les hypothèses de chacun.

Le hors-périmètre s'écrit **en prose**, dans la description de la `Fonctionnalité`. Il ne s'écrit pas en scénario.

```gherkin
# language: fr
Fonctionnalité: Soumission d'une note de frais

  En tant que salarié
  Je veux soumettre mes dépenses professionnelles
  Afin d'en obtenir le remboursement

  ## Hors périmètre

  1. Conversion de devises. Seules les dépenses en euros sont acceptées ;
     une dépense saisie dans une autre devise est refusée (voir la règle
     « Devise unique » ci-dessous).
     Raison : moins de 2 % des notes, traitement manuel par la comptabilité.
     Décision : atelier cadrage du 04/02/2026.

  2. Import de justificatifs depuis un scanner ou une application mobile.
     Seul le téléversement de fichier depuis le poste est prévu.
     Raison : le parc mobile n'est pas déployé.
     Réévaluation : lot 4, T4 2026 (JIRA EPIC-518).

  3. Circuit de validation manager. Traité intégralement dans
     validation-manager.feature. Cette fonctionnalité s'arrête au passage
     de la note au statut "En attente de validation".

  4. Versement bancaire. Hors SI : réalisé par le service Paie via l'outil
     ADP, à partir d'un export mensuel. Aucun développement de notre côté.
```

**Anatomie d'une exclusion correcte** — quatre éléments, tous nécessaires :

| Élément | Question à laquelle il répond | Sans lui |
|---|---|---|
| **L'objet exclu, décidable** | Qu'est-ce qui est exclu, exactement ? | « Les cas complexes sont exclus » : inutilisable |
| **Le comportement de substitution** | Que fait le système si ça arrive quand même ? | Le développeur invente, souvent un crash |
| **La raison** | Pourquoi ? | L'exclusion sera rediscutée à chaque sprint |
| **Le renvoi ou l'échéance** | Où est-ce traité, ou quand sera-ce réévalué ? | Le besoin disparaît de tous les radars |

**Le point n°2 du tableau est le plus important et le plus oublié.** Dire « la conversion de devises est hors périmètre » ne dit pas ce qui se passe si un utilisateur saisit 40 USD. Il faut donc *systématiquement* faire redescendre l'exclusion dans une règle exécutable de garde :

```gherkin
  Règle: Devise unique — seules les dépenses en euros sont traitées

    Exemple: Une dépense dans une devise étrangère est refusée à la saisie
      Quand le salarié saisit une dépense de 40,00 USD
      Alors la saisie est refusée
      Et le motif est "Seules les dépenses en euros sont acceptées. Contactez la comptabilité pour une dépense en devise."
```

**C'est le mécanisme central du bornage :** une exclusion de périmètre bien écrite produit presque toujours un comportement de refus testable à la frontière. Le hors-périmètre pur (non testable) se réduit alors aux cas où le système ne peut même pas être sollicité (le versement bancaire, ci-dessus).

**Formulations à bannir dans une section hors périmètre :**

| ✗ À bannir | Pourquoi |
|---|---|
| « etc. », « notamment », « entre autres » | Rend l'exclusion non décidable : personne ne sait ce qu'il y a dans le « etc. » |
| « les cas particuliers » | Qui décide de ce qui est particulier ? |
| « pour l'instant » sans date ni ticket | Reporte sans trace : le besoin disparaît |
| « on verra plus tard » | Non-décision déguisée en décision |
| Une exclusion sans raison | Sera rediscutée indéfiniment |

---

### 6.6 Forme 5 — Le différé

Distinct du hors-périmètre : le besoin est **reconnu et accepté**, mais pas maintenant. Il doit rester visible.

```gherkin
  ## Différé

  - Validation par délégation en cas d'absence du manager.
    Besoin confirmé par la DRH le 12/02/2026. Prévu lot 3 (JIRA STORY-731).
    Contournement d'ici là : le manager N+2 dispose du droit de validation
    globale, procédure manuelle décrite dans intranet/RH/absences.
```

Optionnellement, on peut écrire le scénario à l'avance et le neutraliser :

```gherkin
  @differe @lot-3
  Exemple: Un manager absent délègue sa validation à un pair
    Étant donné que le manager "Martin" est déclaré absent du 01/07 au 15/07/2026
    Et qu'il a délégué ses validations à "Bernard"
    Quand une note de frais est soumise le 05/07/2026 à Martin
    Alors la note de frais apparaît dans la liste des demandes à valider de Bernard
```

Le tag `@differe` est exclu de l'exécution (`--tags "not @differe"`). Avantages : la spécification est prête, elle a été discutée. Inconvénient réel : un scénario non exécuté vieillit mal et devient faux sans qu'on le sache. **À n'utiliser que si l'échéance est proche et le ticket existe.** Sinon, prose uniquement.

---

### 6.7 Fiche récapitulative : où écrire quoi

```
┌──────────────────────────────────────────────────────────────────┐
│  "Le système ne doit pas X"                                      │
└──────────────────────────────────────────────────────────────────┘
                │
                ▼
    Le système peut-il être sollicité sur X ?
        │                              │
       NON                            OUI
        │                              │
        ▼                              ▼
  Hors périmètre (4)        Que doit-il faire alors ?
  ou Différé (5)                       │
        │                    ┌─────────┼──────────────┐
        ▼                    ▼         ▼              ▼
  Prose dans la      Refuser avec   Ne rien      Accepter jusqu'à
  description        un motif       changer      un seuil
  + raison               │             │              │
  + renvoi/échéance      ▼             ▼              ▼
  + comportement    Exemple de    Exemple avec   Plan du scénario
    de garde        refus (1)     non-effet (2)  aux bornes (3)
                     testable      testable       testable
```

### 6.8 Questions de bornage à poser en atelier

Liste à dérouler mécaniquement sur chaque règle métier. Elle produit en général 40 % des scénarios d'un fichier.

**Sur les valeurs**
- Quelle est la valeur exacte de la borne, et est-elle incluse ?
- Que se passe-t-il à zéro ? Avec une valeur négative ? Avec une valeur absurdement grande ?
- Combien de décimales ? Quel arrondi ? Quelle devise / quelle unité ?

**Sur le temps**
- À quelle date/heure de référence la règle s'évalue-t-elle ?
- Que se passe-t-il si le délai est atteint exactement ?
- Le week-end et les jours fériés comptent-ils ?
- Quel fuseau horaire ?

**Sur les acteurs**
- Qui n'a **pas** le droit de faire cette action ? Que voit-il alors ?
- Que se passe-t-il si l'acteur perd son droit entre la soumission et la validation ?
- Un acteur peut-il agir sur sa propre demande ?

**Sur les états**
- Depuis quels états cette action est-elle interdite ? Que voit l'utilisateur ?
- L'action est-elle rejouable ? Que se passe-t-il si elle est faite deux fois ?
- Est-elle réversible ?

**Sur les effets de bord**
- Quels courriels, notifications, écritures, appels tiers ne doivent **pas** avoir lieu ?
- Quelles données ne doivent **pas** être modifiées ?

**Sur le périmètre**
- Qu'est-ce que quelqu'un pourrait raisonnablement croire inclus, et qui ne l'est pas ?
- Si ce cas non couvert survient, que fait le système ?
- Cette exclusion est-elle définitive ou différée ? Sur quelle décision, quelle date ?

---

## 7. Anti-patterns et grille de relecture

### 7.1 Les anti-patterns

| # | Anti-pattern | Symptôme | Correction |
|---|---|---|---|
| 1 | **Scénario impératif** | « je clique », « le champ », « la page » | Remonter au niveau de l'intention métier |
| 2 | **Scénario conjonctif** | 12 étapes, 4 `Quand`, enchaînement de `Et` | Découper : un scénario = un comportement |
| 3 | **`Étant donné` actif** | « Étant donné que je soumets… » | Reformuler en état : « qu'une note est soumise » |
| 4 | **`Alors` non observable** | « la ligne est insérée en base », « le flag est à true » | Exprimer l'effet visible par le métier |
| 5 | **Vocabulaire technique** | « API », « HTTP 422 », « table », « cache » | Remplacer par le vocabulaire du glossaire |
| 6 | **Scénario sans valeur** | « une dépense élevée », « un délai long » | Mettre des chiffres |
| 7 | **`Contexte` obèse** | 10 étapes de contexte | Descendre le technique dans les hooks, garder ≤ 4 étapes métier |
| 8 | **Table combinatoire** | `Exemples` de 40 lignes | Garder 5 lignes aux bornes, descendre le reste en test unitaire paramétré |
| 9 | **Scénarios couplés** | Le scénario 2 dépend de l'état laissé par le scénario 1 | Chaque scénario est indépendant et rejouable dans n'importe quel ordre |
| 10 | **`Fonctionnalité` fourre-tout** | 400 lignes, 30 scénarios, aucune `Règle` | Découper en fichiers, introduire des `Règle:` |
| 11 | **Gherkin décoratif** | Fichiers jamais exécutés, jamais relus | Soit on les branche au build, soit on assume qu'ils sont de la doc morte |
| 12 | **Spécification en négatif seul** | Que des scénarios d'erreur | Le nominal doit exister et être en premier |
| 13 | **Date du jour implicite** | « Étant donné une dépense d'il y a 3 mois » | Fixer une date de référence explicite |
| 14 | **Hors-périmètre testé** | Un scénario qui vérifie l'absence d'une fonctionnalité entière | Prose dans la description, + éventuel comportement de garde |

### 7.2 Grille de relecture

À dérouler avant de considérer un `.feature` comme prêt. Un « non » = un point à corriger ou à assumer explicitement.

**Lisibilité**
- [ ] Une personne du métier comprend chaque scénario sans explication orale.
- [ ] Aucun terme technique (base, API, endpoint, cache, flag, code HTTP).
- [ ] Aucun terme d'interface (clic, bouton, champ, page, onglet).
- [ ] Le vocabulaire est celui du glossaire, de manière homogène.

**Structure**
- [ ] Une seule `Fonctionnalité` dans le fichier ; fichier < 250 lignes.
- [ ] Les scénarios sont regroupés sous des `Règle:` explicites.
- [ ] Chaque `Règle:` a au moins un exemple positif et un exemple négatif.
- [ ] Un seul `Quand` par scénario.
- [ ] Chaque scénario est indépendant des autres.
- [ ] Le titre du scénario décrit le comportement, pas les données (« Refus au-delà du plafond » et non « Test 3 »).

**Précision**
- [ ] Toutes les valeurs sont concrètes (montants, dates, délais, libellés).
- [ ] Aucune date relative implicite ; la date de référence est fixée.
- [ ] Les libellés d'erreur destinés à l'utilisateur sont écrits mot pour mot.
- [ ] Les unités, devises et arrondis sont explicites.

**Bornage** — le cœur
- [ ] Chaque seuil est couvert par borne − 1, borne exacte, borne + 1.
- [ ] L'inclusion ou l'exclusion de la borne est écrite dans le texte de la `Règle`.
- [ ] Pour chaque cas de refus : le motif exact **et** l'état résultant sont spécifiés.
- [ ] Les non-effets attendus sont écrits (courriels, statuts, écritures, compteurs).
- [ ] Les acteurs non autorisés sont couverts.
- [ ] Les états depuis lesquels l'action est interdite sont couverts.
- [ ] Une section « Hors périmètre » existe et chaque exclusion porte : objet décidable, comportement de garde, raison, renvoi ou échéance.
- [ ] Aucun « etc. », « notamment », « cas particuliers » dans les exclusions.
- [ ] Les éléments différés portent un ticket et une échéance.

---

## 8. Cycle de vie, gouvernance, outillage

### 8.1 Qui écrit quoi

| Artefact | Rédaction | Validation |
|---|---|---|
| Règles métier (`Règle:`) | AMOA / PO | Métier |
| Exemples (`Exemple:`) | Atelier 3 amigos, en commun | Métier + Dev |
| Section hors périmètre | AMOA, tranchée en atelier | Métier (décision engageante) |
| Step definitions (code) | Développeur | Développeur |
| Glossaire | AMOA | Tout le monde |

Le point de friction habituel : les `.feature` vivent dans le dépôt Git, aux côtés du code, dans la même branche que la fonctionnalité. C'est indispensable (le fichier doit évoluer avec le code) mais cela suppose que l'AMOA ait accès au dépôt et sache faire une pull request, ou qu'un rituel de relecture soit organisé. **Traiter ce point d'organisation avant de démarrer**, sinon la boucle de relecture métier ne se ferme jamais.

### 8.2 Chaîne d'exécution

```
fichier .feature
      │  parsé par Gherkin
      ▼
  étape textuelle : "Quand il soumet sa note de frais"
      │  appariée par expression Cucumber
      ▼
  step definition (code)
      │  appelle
      ▼
  code applicatif
```

### 8.3 Outils par écosystème

Versions vérifiées le 25/08/2026 :

| Écosystème | Outil | Version | Note |
|---|---|---|---|
| JavaScript / TypeScript | `@cucumber/cucumber` | 13.2.1 | ESM natif |
| Parser de référence | `@cucumber/gherkin` / `gherkin-official` | 42.0.1 | Source de vérité des mots-clés |
| Python | `pytest-bdd` | 8.1.0 | S'intègre à pytest, recommandé |
| Python | `behave` | 1.3.3 | Autonome, plus ancien |
| .NET | **Reqnroll** | 3.3.4 | **Successeur de SpecFlow**, qui n'est plus maintenu |
| Java / Kotlin | `cucumber-jvm` | 7.x | JUnit 5 via `cucumber-junit-platform-engine` |
| PHP | `Behat` | 3.x | |

⚠️ **SpecFlow** : le projet n'est plus maintenu. Tout nouveau projet .NET doit démarrer sur **Reqnroll**, fork officiel maintenu par l'auteur historique de SpecFlow. La migration depuis SpecFlow est largement automatisée.

### 8.4 Step definitions : bonnes pratiques

Deux illustrations minimales, à destination des développeurs. L'AMOA peut sauter cette section.

**Cucumber Expressions plutôt que regex** — plus lisibles, typées, et le paramètre est nommé :

```javascript
// features/step_definitions/note_de_frais.steps.mjs
import { Given, When, Then } from '@cucumber/cucumber'
import { strict as assert } from 'node:assert'

// {string} {int} {float} {word} sont les types intégrés
Given('une dépense de restauration de {float} €', function (montant) {
  this.noteDeFrais.ajouterDepense({ categorie: 'Restauration', montant })
})

When('la note de frais est soumise', function () {
  this.resultat = this.service.soumettre(this.noteDeFrais)
})

Then('la dépense est {string}', function (decisionAttendue) {
  assert.equal(this.resultat.decision, decisionAttendue)
})

Then('aucun courriel n\'est envoyé au manager', function () {
  assert.equal(this.courriels.filter(c => c.destinataire === 'manager').length, 0)
})
```

```python
# tests/step_defs/test_note_de_frais.py  (pytest-bdd 8.x)
from pytest_bdd import scenarios, given, when, then, parsers

scenarios("../features/note-de-frais/soumission.feature")

@given(parsers.parse("une dépense de restauration de {montant:g} €"), target_fixture="note")
def _(montant):
    return NoteDeFrais(depenses=[Depense("Restauration", montant)])

@when("la note de frais est soumise", target_fixture="resultat")
def _(note, service):
    return service.soumettre(note)

@then(parsers.parse('la dépense est "{decision}"'))
def _(resultat, decision):
    assert resultat.decision == decision
```

Règles de qualité côté code :

1. **Aucune règle métier dans une step definition.** La step traduit du texte en appel ; elle ne contient ni `if` métier, ni calcul de plafond. Si le plafond de 25 € apparaît en dur dans le code de test, la spécification est en deux endroits.
2. **Pas de `Then` qui agit.** Un `Then` observe et assertit, il ne modifie rien.
3. **Isolation.** Chaque scénario démarre d'un état propre (hooks `Before` / fixtures). Aucune dépendance à l'ordre d'exécution.
4. **Réutilisation par le texte, pas par le copier-coller.** Si deux étapes disent la même chose autrement, unifier le texte dans les `.feature`.
5. **Pas d'attente fixe** (`sleep`) : attente conditionnelle sur un observable.

### 8.5 Sélection à l'exécution

```bash
# JS — tout sauf le différé et le travail en cours
npx cucumber-js --tags "not @differe and not @wip"

# Python
pytest -m "not differe"

# .NET
dotnet test --filter "Category!=differe"
```

---

## 9. Fiche mémo

**Structure**

```gherkin
# language: fr
@tag
Fonctionnalité: <nom métier>
  <prose : pourquoi, périmètre, HORS PÉRIMÈTRE, renvois>

  Contexte:
    Étant donné que <état commun, ≤ 4 étapes>

  Règle: <la règle métier, énoncée complètement>

    Exemple: <comportement décrit, pas les données>
      Étant donné que <état>
      Quand <une seule action>
      Alors <résultat observable>
      Et <non-effet éventuel>

    Plan du scénario: <règle à bornes>
      … <placeholder> …
      Exemples: <intention du bloc>
        | col | col |
```

**Les 5 formes du « non »**

| Forme | Support | Testable |
|---|---|---|
| Refus | `Exemple` + motif + état résultant | ✅ |
| Non-effet | `Alors` négatif sur un observable précis | ✅ |
| Borne | `Plan du scénario`, borne −1 / borne / borne +1 | ✅ |
| Hors périmètre | Prose + comportement de garde + raison + renvoi | ❌ |
| Différé | Prose + ticket + échéance (+ `@differe` optionnel) | ❌ |

**Les 3 tests d'un scénario**

1. Un seul `Quand` ?
2. Chaque `Alors` est-il observable par le métier ?
3. Chaque `Quand` a-t-il un acteur identifiable ?

**Le réflexe de bornage**

> Pour chaque règle : *quelle est la valeur exacte de la frontière, qui n'a pas le droit, depuis quels états est-ce interdit, qu'est-ce qui ne doit surtout pas se produire, et qu'est-ce que quelqu'un pourrait croire inclus à tort ?*
