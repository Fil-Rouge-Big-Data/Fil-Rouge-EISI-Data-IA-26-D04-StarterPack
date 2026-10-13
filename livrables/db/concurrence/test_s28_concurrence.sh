#!/usr/bin/env bash
# ============================================================
# Test de concurrence de la garde S28 (D20) — revue de la PR #16, point A (Angeline Gomez).
# Deux sessions simultanées : l'une rémunère le chasseur, l'autre décoche l'encaissement.
# Sans verrou, les deux passaient : rémunération sur un acte non encaissé.
# Attendu, dans les deux ordres : jamais de rémunération sur un acte non encaissé.
# Usage : bash livrables/db/concurrence/test_s28_concurrence.sh   (conteneur chasse_oltp démarré)
# ============================================================
set -uo pipefail
CONTAINER="${CONTAINER:-chasse_oltp}"; DB="${DB:-chasse_v8}"; DBUSER="${DBUSER:-chasse_migration}"
PSQL="docker exec -i $CONTAINER psql -U $DBUSER -d $DB -q -t -A"
ACTE="ac700000-0000-0000-0000-0000000000c1"

prepare() {
$PSQL >/dev/null 2>&1 <<SQL
DELETE FROM remuneration_chasseur WHERE id_acte = '$ACTE';
DELETE FROM acte WHERE id_acte = '$ACTE';
INSERT INTO mandat (id_mandat,id_demande,id_version_contractuelle,id_chasseur,id_signataire,id_mandat_precedent,numero_registre,date_signature,mode_signature,date_debut,numero_habilitation_signature,validite_habilitation_signature,exclusif,taux_honoraires,base_honoraires,taux_tva,qualite_signataire)
VALUES ('88888888-0000-0000-0000-0000000000c1','33333333-0000-0000-0000-000000000001','44444444-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000003','88888888-0000-0000-0000-000000000001','REG-c1','2025-12-05','presentiel','2025-12-05','ATT-3401','2027-01-01',true,3.0,'TTC',20.0,'nom_propre')
ON CONFLICT DO NOTHING;
INSERT INTO acte (id_acte,id_mandat,date_signature,montant_vente,honoraires_fixe,source_information,date_connaissance,honoraires_encaisses,date_encaissement)
VALUES ('$ACTE','88888888-0000-0000-0000-0000000000c1','2026-02-01',300000,9000,'notaire','2026-03-10',true,'2026-03-20');
SQL
}
REMUNERE="INSERT INTO remuneration_chasseur (id_acte,id_chasseur,id_mandat,honoraires,score_delai,score_exclusivite,score_ventes,score_mandats,score_visites,score_performance,taux_base,majoration_anciennete,modulation_performance,taux_final,montant,id_bareme_applique) VALUES ('$ACTE','11111111-0000-0000-0000-000000000001','88888888-0000-0000-0000-0000000000c1',9000,80,100,85,70,50,76,45,5,1.0,47.0,4230.00,'b0000000-0000-0000-0000-000000000001');"
DECOCHE="UPDATE acte SET honoraires_encaisses = false, date_encaissement = NULL WHERE id_acte = '$ACTE';"
INCOHERENT="SELECT count(*) FROM remuneration_chasseur r JOIN acte a USING (id_acte) WHERE a.id_acte = '$ACTE' AND NOT a.honoraires_encaisses;"

echec=0
scenario() {  # $1 = libellé, $2 = SQL de la première session (garde la main 2 s), $3 = SQL de la seconde (démarre à 0,5 s)
  prepare
  printf 'BEGIN;\n%s\nSELECT pg_sleep(2);\nCOMMIT;\n' "$2" | $PSQL >/dev/null 2>&1 &
  printf 'SELECT pg_sleep(0.5);\nBEGIN;\n%s\nCOMMIT;\n' "$3" | $PSQL >/dev/null 2>&1 &
  wait
  n=$(echo "$INCOHERENT" | $PSQL)
  if [ "$n" = "0" ]; then echo "  [OK  ] $1"; else echo "  [ECHEC] $1 : $n rémunération(s) sur un acte non encaissé"; echec=1; fi
}
echo "Concurrence S28 (D20) :"
scenario "rémunération d'abord, encaissement décoché pendant" "$REMUNERE" "$DECOCHE"
scenario "encaissement décoché d'abord, rémunération pendant" "$DECOCHE" "$REMUNERE"
echo "DELETE FROM remuneration_chasseur WHERE id_acte = '$ACTE'; DELETE FROM acte WHERE id_acte = '$ACTE'; DELETE FROM mandat WHERE id_mandat = '88888888-0000-0000-0000-0000000000c1';" | $PSQL >/dev/null 2>&1
exit $echec
