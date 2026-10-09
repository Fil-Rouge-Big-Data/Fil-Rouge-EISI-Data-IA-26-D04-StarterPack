#!/usr/bin/env python3
"""Batterie de tests MPD v8.41 (harnais probant : chaque rejet doit venir de la contrainte ATTENDUE). Chaque test REJET attend une exception ; chaque test VALIDE attend un succès.

Portable : la connexion se configure par les variables d'environnement PostgreSQL
standard (PGHOST, PGPORT, PGUSER, PGDATABASE, PGPASSWORD). Valeurs par défaut
adaptées à un `docker compose up` local (127.0.0.1:5433).

Exemples :
  # Docker local (port 5433 exposé par docker-compose)
  PGHOST=127.0.0.1 PGPORT=5433 PGUSER=chasse_migration PGDATABASE=chasse_v8 \
    PGPASSWORD=<mot_de_passe_du_.env> python3 run_tests.py
"""
import os, subprocess, sys

PGHOST     = os.environ.get("PGHOST", "127.0.0.1")
PGPORT     = os.environ.get("PGPORT", "5433")
PGUSER     = os.environ.get("PGUSER", "chasse_migration")
PGDATABASE = os.environ.get("PGDATABASE", "chasse_v8")
PSQL_BIN   = os.environ.get("PSQL_BIN", "psql")  # 'psql' si dans le PATH

# Si PSQL_DOCKER_CONTAINER est défini (ex. chasse_oltp), psql est exécuté DANS ce conteneur via
# `docker exec -i` : aucun client psql n'est nécessaire sur la machine hôte (pratique sous Windows).
PSQL_CONTAINER = os.environ.get("PSQL_DOCKER_CONTAINER")
if PSQL_CONTAINER:
    PSQL = ["docker", "exec", "-i", PSQL_CONTAINER, "psql", "-U", PGUSER, "-d", PGDATABASE,
            "-v", "ON_ERROR_STOP=1", "-v", "VERBOSITY=verbose", "-t", "-A"]
else:
    PSQL = [PSQL_BIN, "-h", PGHOST, "-p", PGPORT, "-U", PGUSER, "-d", PGDATABASE,
            "-v", "ON_ERROR_STOP=1", "-v", "VERBOSITY=verbose", "-t", "-A"]

def run(sql):
    """Exécute un bloc SQL via psql. Retourne (ok, message).
    ok=True si psql sort en code 0 (aucune erreur SQL)."""
    p = subprocess.run(PSQL, input=sql, capture_output=True, text=True,
                       env={**os.environ})
    ok = (p.returncode == 0)
    msg = (p.stdout + p.stderr).strip().replace('\n', ' ')[:300]
    return ok, msg

# B5 : un vrai rejet d'intégrité porte un code SQLSTATE de contrainte
# (23xxx : FK, unique, check, exclusion, not-null) ou un message de trigger
# métier (RAISE EXCEPTION). Une erreur de SYNTAXE ou de COLONNE (42xxx) est un
# rejet « parasite » : le test ne prouve rien. On distingue les deux.
import re
_SQLSTATE_INTEGRITE = ("23502","23503","23505","23514","23P01")  # not-null, fk, unique, check, exclusion

def rejet_probant(msg):
    """True si le rejet vient d'une contrainte/trigger métier, pas d'une erreur parasite."""
    # psql affiche 'ERROR:  ... violates ... constraint "nom"' ou un RAISE métier.
    if "violates" in msg and "constraint" in msg:
        return True, _nom_contrainte(msg)
    if re.search(r"\b(S\d+|C\d+|T\d+)\b", msg):   # message d'un trigger métier (RAISE)
        return True, "trigger"
    if "does not exist" in msg or "syntax error" in msg or "column" in msg:
        return False, "ERREUR PARASITE (colonne/syntaxe)"
    return True, "?"   # autre rejet métier plausible

def _nom_contrainte(msg):
    m = re.search(r'constraint "([^"]+)"', msg)
    return m.group(1) if m else "?"

# Contrainte que CHAQUE test de rejet est censé déclencher. Règle de l'art : un test négatif doit échouer
# pour la BONNE raison. Un rejet par une autre contrainte (jeu de données qui bute plus tôt, FK
# antérieure...) est un FAUX POSITIF : le test ne prouve alors rien sur la règle visée.
# "trigger" = règle portée par un trigger (RAISE EXCEPTION, SQLSTATE P0001), sans nom de contrainte.
ATTENDU = {
    "T1": "ck_commentaire_cible",   "T2": "trigger",                  "T3": "uk_proposition_active",
    "T4": "fk_mandat_signataire",   "T5": "ux_affectation_ouverte",   "T6": "ck_mandat_remun",
    "T7": "ck_mandat_effet",        "T8": "ck_mandat_procur",         "T9": "trigger",
    "T10": "fk_proposition_annonce","T11": "d_dpe_check",             "T12": "d_email_check",
    "T13": "ck_proposition_rejet",  "T14": "ck_demande_consent_web",  "T15": "ck_version_rendement",
    "T16": "ux_offre_acceptee",     "T17": "ck_compromis_caducite",   "T18": "ck_acte_honoraires",
    "T19": "ck_visite_annulation",  "T20": "trigger",                 "T21": "fk_proposition_mandat",
    "T22": "ck_chasseur_habilitation", "T23": "trigger",
}

def verdict_rejet(identifiant, msg):
    """(ok, détail). OK seulement si la contrainte (ou le trigger) ATTENDU est celui qui a rejeté."""
    m = re.search(r"ERROR:\s+([0-9A-Z]{5}):", msg)
    sqlstate = m.group(1) if m else None
    nom = _nom_contrainte(msg)
    attendue = ATTENDU.get(identifiant)
    if attendue is None:
        return False, f"aucune contrainte attendue déclarée pour {identifiant}"
    if attendue == "trigger":
        return (sqlstate == "P0001"), ("trigger" if sqlstate == "P0001" else f"{sqlstate}/{nom} au lieu d'un trigger")
    return (nom == attendue), (nom if nom == attendue else f"{nom} AU LIEU DE {attendue}")

REJETS = [
 ("T1  C2  commentaire double cible",
  "INSERT INTO commentaire (id_auteur,id_demande,id_proposition,type_contexte,contenu) VALUES ('11111111-0000-0000-0000-000000000001','33333333-0000-0000-0000-000000000001','77777777-0000-0000-0000-000000000001','note_recherche','x');"),
 ("T2  ADR-048 renouvellement qui commence avant 6 mois",
  "INSERT INTO mandat (id_mandat,id_demande,id_version_contractuelle,id_chasseur,id_signataire,id_mandat_precedent,numero_registre,date_signature,mode_signature,date_debut,numero_habilitation_signature,validite_habilitation_signature,exclusif,taux_honoraires,base_honoraires,taux_tva,qualite_signataire) VALUES ('88888888-0000-0000-0000-0000000000f2','33333333-0000-0000-0000-000000000001','44444444-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000003','88888888-0000-0000-0000-000000000001','REG-X2','2025-08-01','presentiel','2025-08-01','ATT','2027-06-05',true,3.0,'TTC',20.0,'nom_propre');"),
 ("T3  C8  bien proposé 2x même demande",
  "INSERT INTO proposition (id_demande,id_version,id_bien,id_mandat,date_matching,statut) VALUES ('33333333-0000-0000-0000-000000000001','44444444-0000-0000-0000-000000000001','55555555-0000-0000-0000-000000000001','88888888-0000-0000-0000-000000000001','2025-06-10','soumis');"),
 ("T4  C5  signataire non acquéreur",
  "INSERT INTO mandat (id_demande,id_version_contractuelle,id_chasseur,id_signataire,numero_registre,date_signature,mode_signature,date_debut,numero_habilitation_signature,validite_habilitation_signature,exclusif,taux_honoraires,base_honoraires,taux_tva,qualite_signataire) VALUES ('33333333-0000-0000-0000-000000000001','44444444-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000004','REG-Y','2025-07-02','presentiel','2025-07-02','CPI3401 2025 000 001','2027-06-05',true,3.0,'TTC',20.0,'nom_propre');"),
 ("T5  C6  seconde affectation ouverte",
  "INSERT INTO affectation (id_demande,id_gestionnaire,date_debut,motif) VALUES ('33333333-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000002','2025-06-01','initiale'); INSERT INTO affectation (id_demande,id_gestionnaire,date_debut,motif) VALUES ('33333333-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000002','2025-06-05','surcharge');"),
 ("T6  ck  mandat sans rémunération",
  "INSERT INTO mandat (id_demande,id_version_contractuelle,id_chasseur,id_signataire,numero_registre,date_signature,mode_signature,date_debut,numero_habilitation_signature,validite_habilitation_signature,exclusif,base_honoraires,taux_tva,qualite_signataire) VALUES ('33333333-0000-0000-0000-000000000001','44444444-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000003','REG-Z','2025-07-03','presentiel','2025-07-03','CPI3401 2025 000 001','2027-06-05',true,'TTC',20.0,'nom_propre');"),
 ("T7  ck  effet avant signature",
  "INSERT INTO mandat (id_demande,id_version_contractuelle,id_chasseur,id_signataire,numero_registre,date_signature,mode_signature,date_debut,numero_habilitation_signature,validite_habilitation_signature,exclusif,taux_honoraires,base_honoraires,taux_tva,qualite_signataire) VALUES ('33333333-0000-0000-0000-000000000001','44444444-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000003','REG-W','2025-07-05','presentiel','2025-07-01','CPI3401 2025 000 001','2027-06-05',true,3.0,'TTC',20.0,'nom_propre');"),
 ("T8  ck  procuration sans référence",
  "INSERT INTO mandat (id_demande,id_version_contractuelle,id_chasseur,id_signataire,numero_registre,date_signature,mode_signature,date_debut,numero_habilitation_signature,validite_habilitation_signature,exclusif,taux_honoraires,base_honoraires,taux_tva,qualite_signataire) VALUES ('33333333-0000-0000-0000-000000000001','44444444-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000003','REG-V','2025-07-06','presentiel','2025-07-06','CPI3401 2025 000 001','2027-06-05',true,3.0,'TTC',20.0,'procuration');"),
 ("T9  C9  observation période ouverte",
  "INSERT INTO observation (id_utilisateur,code_indicateur,id_periode,valeur,date_calcul) VALUES ('11111111-0000-0000-0000-000000000002','delai_affectation','99999999-0000-0000-0000-000000000001',4.2,'2025-06-15');"),
 ("T10 fk  annonce d'un autre bien",
  "INSERT INTO bien (id_bien,id_zone,type_bien) VALUES ('55555555-0000-0000-0000-000000000002','22222222-0000-0000-0000-000000000002','maison'); INSERT INTO proposition (id_demande,id_version,id_bien,id_annonce_reference,id_mandat,date_matching,statut) VALUES ('33333333-0000-0000-0000-000000000001','44444444-0000-0000-0000-000000000001','55555555-0000-0000-0000-000000000002','66666666-0000-0000-0000-000000000001','88888888-0000-0000-0000-000000000001','2025-06-11','soumis');"),
 ("T11 dom DPE hors A-G",
  "INSERT INTO bien (id_zone,type_bien,dpe) VALUES ('22222222-0000-0000-0000-000000000001','appartement','Z');"),
 ("T12 dom email malformé",
  "INSERT INTO utilisateur (nom,prenom,email,password_hash) VALUES ('X','Y','pasunemail','x');"),
 ("T13 ck  refus sans motif",
  "INSERT INTO proposition (id_demande,id_version,id_bien,id_mandat,date_matching,statut) VALUES ('33333333-0000-0000-0000-000000000001','44444444-0000-0000-0000-000000000001','55555555-0000-0000-0000-000000000002','88888888-0000-0000-0000-000000000001','2025-06-12','refuse_client');"),
 ("T14 ck  lead web sans consentement",
  "INSERT INTO demande (id_gestionnaire,date_depot,canal) VALUES ('11111111-0000-0000-0000-000000000002','2025-06-01','site_web');"),
 ("T15 ck  rendement sur résidence principale",
  "INSERT INTO demande_version (id_demande,id_modifie_par,no_version,date_creation,motif_evolution,type_bien,destination,budget_max,rendement_brut_min) VALUES ('33333333-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000003',9,'2025-06-20','x','appartement','principale',300000,5.0);"),
 # --- Nouveaux tests chaîne de valeur + C18 ---
 ("T16 C13 offre acceptée en double",
  "INSERT INTO offre_acquisition (id_proposition,camp,saisi_par,montant,date_signature,date_validite,statut,date_reponse) VALUES ('77777777-0000-0000-0000-000000000001','acquereur','chasseur',300000,'2025-06-15','2025-06-20','acceptee','2025-06-16'); INSERT INTO offre_acquisition (id_proposition,camp,saisi_par,montant,date_signature,date_validite,statut,date_reponse) VALUES ('77777777-0000-0000-0000-000000000001','acquereur','chasseur',310000,'2025-06-17','2025-06-22','acceptee','2025-06-18');"),
 ("T17 C15 compromis caduc sans motif (date_caducite sans motif)",
  # On modifie le compromis du jeu de test (le trigger d'offre ne se déclenche que sur UPDATE OF id_offre) :
  # le test atteint directement ck_compromis_caducite, sans reconstruire une chaîne offre->compromis.
  "UPDATE compromis SET date_caducite='2025-07-20' WHERE id_compromis='c0a00000-0000-0000-0000-000000000001';"),
 ("T18 C16 acte sans honoraires",
  # Idem : UPDATE de l'acte du jeu de test (le trigger ne se déclenche que sur UPDATE OF id_compromis).
  "UPDATE acte SET honoraires_fixe=NULL, honoraires_taux=NULL WHERE id_acte='ac700000-0000-0000-0000-000000000001';"),
 ("T19 C17 visite annulée sans motif",
  "INSERT INTO visite (id_proposition,id_visiteur,date_visite,realisee) VALUES ('77777777-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000003','2025-06-20',false);"),
 ("T21 v82 proposition mandat d'une autre demande",
  # La demande « autre » a sa propre version : le couple (demande, version) est valide, SEUL le couple
  # (mandat, demande) est faux -> c'est bien fk_proposition_mandat qui doit rejeter (et non la FK de version).
  "INSERT INTO demande (id_demande,id_gestionnaire,date_depot,canal) VALUES ('33333333-0000-0000-0000-0000000000ff','11111111-0000-0000-0000-000000000002','2025-06-01','autre'); "
  "INSERT INTO demande_version (id_version,id_demande,id_modifie_par,no_version,date_creation,motif_evolution,type_bien,destination,budget_max) VALUES ('44444444-0000-0000-0000-0000000000ff','33333333-0000-0000-0000-0000000000ff','11111111-0000-0000-0000-000000000003',1,'2025-06-02','initiale','appartement','principale',300000); "
  "INSERT INTO proposition (id_demande,id_version,id_bien,id_mandat,date_matching,statut) VALUES ('33333333-0000-0000-0000-0000000000ff','44444444-0000-0000-0000-0000000000ff','55555555-0000-0000-0000-000000000001','88888888-0000-0000-0000-000000000001','2025-06-10','soumis');"),
 ("T22 v82 chasseur salarié avec carte_t (doit être attestation)",
  "INSERT INTO utilisateur (id_utilisateur,nom,prenom,email,password_hash) VALUES ('11111111-0000-0000-0000-0000000000f2','X','Y','xyf2@m.fr','x'); INSERT INTO chasseur (id_utilisateur,type_habilitation,numero_habilitation,date_validite_habilitation,organisme_delivrance,organisme_garant,montant_garantie_financiere,numero_rcp,date_echeance_rcp,statut_juridique,date_entree_reseau,capacite_max_mandats) VALUES ('11111111-0000-0000-0000-0000000000f2','carte_t','CT','2027-01-01','CCI','G',120000,'R','2027-01-01','salarie','2024-01-01',15);"),
 ("T23 v82 mandat son propre précédent",
  "UPDATE mandat SET id_mandat_precedent = id_mandat WHERE id_mandat='88888888-0000-0000-0000-000000000001';"),
 ("T20 C18 client poste commentaire privé",
  "INSERT INTO commentaire (id_auteur,id_demande,type_contexte,est_prive,contenu) VALUES ('11111111-0000-0000-0000-000000000003','33333333-0000-0000-0000-000000000001','note_recherche',true,'note privee interdite');"),
]

VALIDES = [
 ("P3  1 bien / 2 annonces / 1 proposition",
  "INSERT INTO annonce (id_bien,source,reference_source,prix,date_ingestion,date_derniere_vue,statut) VALUES ('55555555-0000-0000-0000-000000000001','seloger','REF999',318000,'2025-06-03','2025-06-03','active');"),
 ("P4  chasseur pose commentaire privé",
  "INSERT INTO commentaire (id_auteur,id_demande,type_contexte,est_prive,contenu) VALUES ('11111111-0000-0000-0000-000000000001','33333333-0000-0000-0000-000000000001','note_recherche',true,'note interne chasseur');"),
 ("P5  cumul chasseur+client pose privé",
  "INSERT INTO commentaire (id_auteur,id_demande,type_contexte,est_prive,contenu) VALUES ('11111111-0000-0000-0000-000000000005','33333333-0000-0000-0000-000000000001','note_recherche',true,'note interne cumul');"),
 ("P7  renouvellement = nouveau mandat avec filiation",
  "INSERT INTO mandat (id_demande,id_version_contractuelle,id_chasseur,id_signataire,id_mandat_precedent,numero_registre,date_signature,mode_signature,date_debut,numero_habilitation_signature,validite_habilitation_signature,exclusif,taux_honoraires,base_honoraires,taux_tva,qualite_signataire) VALUES ('33333333-0000-0000-0000-000000000001','44444444-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000003','88888888-0000-0000-0000-000000000001','REG-2025-002','2025-12-05','presentiel','2025-12-05','CPI3401 2025 000 001','2027-06-05',true,3.0,'TTC',20.0,'nom_propre');"),
]

def savepoint_wrap(sql):
    # chaque test dans sa propre transaction annulée pour ne pas polluer
    return "BEGIN;\n"+sql+"\nROLLBACK;"

print("="*70)
print("BATTERIE DE TESTS MPD v8.41 — PostgreSQL 16+/18")
print("="*70)
nrej_ok=0
print("\n--- TESTS DE REJET (une écriture invalide DOIT échouer PAR UNE CONTRAINTE) ---")
for name, sql in REJETS:
    ok,msg = run(savepoint_wrap(sql))
    if ok:
        # l'écriture est passée : le schéma accepte quelque chose d'interdit
        print(f"  [!! ECHEC (accepté à tort) ] {name}")
        continue
    # Rejet oui, mais par la BONNE contrainte ? (parasite -> échec ; mauvaise contrainte -> échec)
    probant, origine = rejet_probant(msg)
    if not probant:
        print(f"  [!! ECHEC ({origine}) ] {name}")
        print(f"        -> rejet non probant : {msg[:90]}")
        continue
    bon, detail = verdict_rejet(name.split()[0], msg)
    if bon:
        nrej_ok+=1
        print(f"  [OK  ({detail:22})] {name}")
    else:
        print(f"  [!! ECHEC : mauvaise contrainte] {name}")
        print(f"        -> rejeté par {detail}")

nval_ok=0
print("\n--- SCÉNARIOS VALIDES (une écriture correcte DOIT réussir) ---")
for name, sql in VALIDES:
    ok,msg = run(savepoint_wrap(sql))
    verdict = "OK " if ok else "!! ECHEC (rejeté à tort)"
    if ok: nval_ok+=1
    print(f"  [{verdict:24}] {name}")
    if not ok: print(f"        -> {msg}")

print("\n"+"="*70)
print(f"REJETS   : {nrej_ok}/{len(REJETS)} correctement rejetés")
print(f"VALIDES  : {nval_ok}/{len(VALIDES)} correctement acceptés")
print("="*70)
sys.exit(0 if (nrej_ok==len(REJETS) and nval_ok==len(VALIDES)) else 1)
