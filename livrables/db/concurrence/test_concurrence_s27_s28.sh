#!/usr/bin/env bash
# ============================================================
# Tests de concurrence des gardes S27 (résiliation / acte) et S28 (rémunération / encaissement, D20).
# Deux sessions simultanées, dans les deux ordres. Revue de la PR #16 : Angeline Gomez (course S28),
# Thérèse Nguyen (S27 dans l'autre sens, harnais probant).
#
# Pour chaque scénario, le test vérifie QUATRE choses (un « OK » n'est plus possible à vide) :
#   1. la première session, qui garde son verrou 2 s avant de valider, réussit (code de retour 0) ;
#   2. la seconde session, lancée 0,5 s plus tard, est REFUSÉE, et par la garde attendue (son code est
#      dans le message d'erreur) ;
#   3. la seconde session a réellement attendu le verrou : elle a duré au moins 1 s (chevauchement prouvé) ;
#   4. l'état final de la base est celui attendu (comptages).
# Toute erreur de préparation ou de nettoyage arrête le script (ON_ERROR_STOP, code 2).
# Contrat : niveau d'isolation READ COMMITTED (défaut PostgreSQL), voir ADR-053 item 4 quater.
# Usage : bash livrables/db/concurrence/test_concurrence_s27_s28.sh   (conteneur chasse_oltp démarré)
# ============================================================
set -uo pipefail
CONTAINER="${CONTAINER:-chasse_oltp}"; DB="${DB:-chasse_v8}"; DBUSER="${DBUSER:-chasse_migration}"
PSQL="docker exec -i $CONTAINER psql -U $DBUSER -d $DB -q -t -A -v ON_ERROR_STOP=1"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

MANDAT="88888888-0000-0000-0000-0000000000c1"      # renouvellement exclusif du mandat du seed, sans acte
ACTE="ac700000-0000-0000-0000-0000000000c1"

sql() { printf '%s\n' "$1" | $PSQL; }                 # une commande ; échoue si psql échoue

nettoyer() {
  sql "DELETE FROM remuneration_chasseur WHERE id_acte = '$ACTE';
       DELETE FROM acte WHERE id_acte = '$ACTE';
       DELETE FROM mandat WHERE id_mandat = '$MANDAT';" >/dev/null || { echo "  [ERREUR] nettoyage impossible"; exit 2; }
}
preparer_mandat() {
  sql "INSERT INTO mandat (id_mandat,id_demande,id_version_contractuelle,id_chasseur,id_signataire,id_mandat_precedent,numero_registre,date_signature,mode_signature,date_debut,numero_habilitation_signature,validite_habilitation_signature,exclusif,taux_honoraires,base_honoraires,taux_tva,qualite_signataire)
       VALUES ('$MANDAT','33333333-0000-0000-0000-000000000001','44444444-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000003','88888888-0000-0000-0000-000000000001','REG-c1','2025-12-05','presentiel','2025-12-05','ATT-3401','2027-01-01',true,3.0,'TTC',20.0,'nom_propre');" >/dev/null \
    || { echo "  [ERREUR] préparation du mandat"; exit 2; }
}
preparer_acte_encaisse() {
  sql "INSERT INTO acte (id_acte,id_mandat,date_signature,montant_vente,honoraires_fixe,source_information,date_connaissance,honoraires_encaisses,date_encaissement)
       VALUES ('$ACTE','$MANDAT','2026-02-01',300000,9000,'notaire','2026-03-10',true,'2026-03-20');" >/dev/null \
    || { echo "  [ERREUR] préparation de l'acte"; exit 2; }
  [ "$(sql "SELECT count(*) FROM acte WHERE id_acte = '$ACTE' AND honoraires_encaisses;")" = "1" ] || { echo "  [ERREUR] acte préparé introuvable"; exit 2; }
}

REMUNERE="INSERT INTO remuneration_chasseur (id_acte,id_chasseur,id_mandat,honoraires,score_delai,score_exclusivite,score_ventes,score_mandats,score_visites,score_performance,taux_base,majoration_anciennete,modulation_performance,taux_final,montant,id_bareme_applique) VALUES ('$ACTE','11111111-0000-0000-0000-000000000001','$MANDAT',9000,80,100,85,70,50,76,45,5,1.0,47.0,4230.00,'b0000000-0000-0000-0000-000000000001');"
DECOCHE="UPDATE acte SET honoraires_encaisses = false, date_encaissement = NULL WHERE id_acte = '$ACTE';"
ACTE_HD="INSERT INTO acte (id_acte,id_mandat,date_signature,montant_vente,honoraires_fixe,source_information,date_connaissance) VALUES ('$ACTE','$MANDAT','2026-02-01',300000,9000,'notaire','2026-03-10');"
RESILIE="UPDATE mandat SET date_resiliation = '2026-03-01', type_resiliation = 'abandon_client' WHERE id_mandat = '$MANDAT';"

echec=0
# $1 libellé · $2 SQL session 1 (réussit, garde son verrou 2 s) · $3 SQL session 2 (doit être refusée)
# $4 code de garde attendu dans l'erreur de la session 2 · $5 requête d'état final · $6 valeur attendue
scenario() {
  printf 'BEGIN;\n%s\nSELECT pg_sleep(2);\nCOMMIT;\n' "$2" | $PSQL >"$TMP/s1.out" 2>"$TMP/s1.err" &
  p1=$!
  sleep 0.5
  t0=$(date +%s%N)
  printf 'BEGIN;\n%s\nCOMMIT;\n' "$3" | $PSQL >"$TMP/s2.out" 2>"$TMP/s2.err"; rc2=$?
  t1=$(date +%s%N); attente_ms=$(( (t1 - t0) / 1000000 ))
  wait $p1; rc1=$?
  etat=$(sql "$5")
  motifs=""
  [ "$rc1" -eq 0 ] || motifs="$motifs session 1 refusée ($(tr -d '\n' <"$TMP/s1.err" | cut -c1-120)) ;"
  [ "$rc2" -ne 0 ] || motifs="$motifs session 2 acceptée à tort ;"
  grep -Eq "(^|[^A-Z0-9])$4([^A-Z0-9]|$)" "$TMP/s2.err" || motifs="$motifs session 2 refusée sans le code $4 ($(tr -d '\n' <"$TMP/s2.err" | cut -c1-120)) ;"
  [ "$attente_ms" -ge 1000 ] || motifs="$motifs chevauchement non prouvé (session 2 : ${attente_ms} ms, attendu >= 1000) ;"
  [ "$etat" = "$6" ] || motifs="$motifs état final '$etat' au lieu de '$6' ;"
  if [ -z "$motifs" ]; then echo "  [OK  ] $1 (session 2 refusée par $4 après ${attente_ms} ms d'attente)"
  else echo "  [ECHEC] $1 :$motifs"; echec=1; fi
}

echo "Concurrence S28 (D20) :"
nettoyer; preparer_mandat; preparer_acte_encaisse
scenario "rémunération d'abord, encaissement décoché pendant" "$REMUNERE" "$DECOCHE" "S28" \
  "SELECT (SELECT count(*) FROM remuneration_chasseur WHERE id_acte = '$ACTE') || '/' || (SELECT honoraires_encaisses::int FROM acte WHERE id_acte = '$ACTE');" "1/1"
nettoyer; preparer_mandat; preparer_acte_encaisse
scenario "encaissement décoché d'abord, rémunération pendant" "$DECOCHE" "$REMUNERE" "S28" \
  "SELECT (SELECT count(*) FROM remuneration_chasseur WHERE id_acte = '$ACTE') || '/' || (SELECT honoraires_encaisses::int FROM acte WHERE id_acte = '$ACTE');" "0/0"

echo "Concurrence S27 (résiliation / acte) :"
nettoyer; preparer_mandat
scenario "acte hors dispositif d'abord, résiliation pendant" "$ACTE_HD" "$RESILIE" "S27" \
  "SELECT (SELECT count(*) FROM acte WHERE id_acte = '$ACTE') || '/' || (SELECT (date_resiliation IS NOT NULL)::int FROM mandat WHERE id_mandat = '$MANDAT');" "1/0"
nettoyer; preparer_mandat
scenario "résiliation d'abord, acte hors dispositif pendant" "$RESILIE" "$ACTE_HD" "S27" \
  "SELECT (SELECT count(*) FROM acte WHERE id_acte = '$ACTE') || '/' || (SELECT (date_resiliation IS NOT NULL)::int FROM mandat WHERE id_mandat = '$MANDAT');" "0/1"

nettoyer
exit $echec
