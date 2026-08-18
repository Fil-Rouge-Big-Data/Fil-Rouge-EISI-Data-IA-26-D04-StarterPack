"""Référentiels de reprise : correspondances entre l'existant et le modèle cible.

Déclaratif uniquement, aucune logique. Chaque correspondance porte la source qui
la justifie — travaux d'audit et de modélisation de l'équipe (Confluence : registre
d'anomalies et ses codes Axx, dictionnaire de données de l'existant, MCD cible et
MLD), DDL de `01_schema/`, ou référentiel externe.

Les clés sont normalisées (minuscules, sans accent) : ce sont des clés de
recherche dans `mandats.description_recherche`, pas des libellés d'affichage.
"""

# Les 6 communes de l'existant sont toutes françaises : un seul pays à créer.
PAYS = {"code_iso": "FRA", "nom": "France", "devise": "EUR", "langue_defaut": "fr"}

# VILLE.code_insee est NOT NULL (01_schema/ddl_tables.sql) et l'existant ne porte
# aucun code commune : « le seul identifiant fiable d'une commune — un code
# officiel type INSEE — n'existe nulle part dans l'existant » (dictionnaire de
# données de l'existant, § secteurs). Codes officiels géographiques INSEE saisis
# commune par commune : c'est un apport externe, pas une donnée reprise. Toute
# commune absente d'ici fait échouer la transformation (KeyError explicite).
CODES_INSEE = {
    "Castelnau-le-Lez": "34057",
    "Lattes": "34129",
    "Lyon": "69123",
    "Montpellier": "34172",
    "Nantes": "44109",
    "Sète": "34301",
}

# A01 — `expire` est une donnée *calculable* que la cible ne stocke plus :
# l'expiration se lit sur MANDAT.date_fin (vue v_mandat_etat de 01_schema/).
# Le dictionnaire de données le classe « calculable stockée : à ne pas reprendre,
# se déduit des dates ». Seul le dernier statut *décidé* est donc repris ; un
# mandat expiré non clos reste « actif », et la vue le signale expiré.
STATUTS_MANDAT = {"actif": "actif", "suspendu": "suspendu", "termine": "termine", "expire": "actif"}

# A06 — mandat 13 : `client_id` = 3, or l'utilisateur 3 est la chasseuse Inès
# Delacroix. Trois indices convergents désignent le client 19, Nina Girard :
# budget 220000 (le sien, et celui d'aucun autre client), seul client sans
# mandat, même ville que le secteur visé — faisceau établi par le dictionnaire de
# données de l'existant (§ le vrai client du mandat 13), vérifiable par requête
# sur `fixtures/`. Reconstitution : à faire valider par le métier avant exécution
# en production, sans quoi le mandat part en quarantaine plutôt qu'en base.
CORRECTIONS_CLIENT = {13: 19}

# La notation « Tn » vaut appartement + n pièces, traitée à part dans le parseur.
TYPES_BIEN = {"maison": "maison", "villa": "villa", "loft": "loft", "appartement": "appartement"}

# « neuf ou recent » : le modèle ne porte pas la disjonction (un seul état
# attendu), elle est ramenée à sa borne la moins restrictive — un bien neuf est
# récent, l'inverse est faux.
ETATS_ATTENDUS = {"neuf ou recent": "recent", "ancien renove": "ancien_renove", "travaux ok": "a_renover"}

# « vue mer si possible » est un souhait, pas un critère éliminatoire :
# est_imperatif = FALSE. Le dictionnaire de données relève 3 occurrences de ce
# « caractère du critère » et avertit que l'ignorer transformerait un souhait en
# critère bloquant. La colonne DEMANDE_CARACTERISTIQUE.est_imperatif du DDL est
# exactement ce qui permet de le reprendre.
MODULATEURS = ("si possible", "appreciee", "apprecie")

# Référentiel des caractéristiques, établi sur le vocabulaire des 18
# `description_recherche` — le dictionnaire de données le réclamait (« vocabulaire
# libre, non normalisé, sans référentiel », 17/18 occurrences). Tout critère
# qualitatif devient une CARACTERISTIQUE(libelle, categorie) du MCD cible : le DDL
# ne prévoit aucun champ texte résiduel sur DEMANDE_VERSION, `criteres_bruts`
# étant réservé à la reprise (COMMENT de 01_schema/ddl_tables.sql).
# L'ORDRE de ce dictionnaire fixe les id_caracteristique attribués à la reprise
# (1 → 19) : ne pas le réordonner, ni y insérer une entrée ailleurs qu'à la fin,
# une fois la cible chargée — les liaisons DEMANDE_CARACTERISTIQUE s'y réfèrent.
CARACTERISTIQUES = {
    "balcon": ("Balcon", "exterieur"),
    "terrasse": ("Terrasse", "exterieur"),
    "jardin": ("Jardin", "exterieur"),
    "jardin sud": ("Jardin exposé sud", "exterieur"),
    "petit exterieur": ("Petit extérieur", "exterieur"),
    "piscine": ("Piscine", "exterieur"),
    "parking": ("Parking", "stationnement"),
    "garage": ("Garage", "stationnement"),
    "cave": ("Cave", "confort"),
    "ascenseur": ("Ascenseur", "accessibilite"),
    "lumineux": ("Lumineux", "confort"),
    "calme": ("Calme", "environnement"),
    "vue": ("Vue dégagée", "confort"),
    "vue mer": ("Vue mer", "environnement"),
    "proche tram": ("Proche tram", "environnement"),
    "standing": ("Standing", "confort"),
    "prestations haut de gamme": ("Prestations haut de gamme", "confort"),
    # Le dictionnaire de données signale « charme ancien » comme ambigu (état ou
    # caractéristique ?). Arbitré ici en caractéristique : à la différence de
    # « ancien renove », valeur de l'enum etat_attendu qui décrit un état de
    # rénovation, il qualifie un cachet perçu, souvent sur un bien non rénové.
    "charme ancien": ("Charme ancien", "confort"),
    "poutres": ("Poutres apparentes", "confort"),
}

# Donnée du client égarée dans une colonne de critères de bien : le dictionnaire
# de données la classe hors sujet. Écartée avec motif, jamais silencieusement —
# la note de cadrage vise « zéro déperdition », toute exception se justifie.
HORS_SUJET = {"premier achat": "attribut du client (primo-accession), pas un critère de bien"}
