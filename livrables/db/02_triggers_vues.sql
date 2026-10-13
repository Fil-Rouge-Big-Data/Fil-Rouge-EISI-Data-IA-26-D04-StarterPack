-- ============================================================
-- Déclencheurs & vues v7
-- ============================================================
SET search_path TO public;

-- ------------------------------------------------------------
-- C9 : observation sur période close
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION f_observation_periode() RETURNS trigger AS $$
DECLARE v_fin date;
BEGIN
    SELECT date_fin INTO v_fin FROM periode WHERE id_periode = NEW.id_periode;
    IF NEW.date_calcul::date <= v_fin THEN
        RAISE EXCEPTION 'C9 : periode non close au calcul (fin=%, calcul=%)', v_fin, NEW.date_calcul::date;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER tg_observation_periode BEFORE INSERT OR UPDATE ON observation
    FOR EACH ROW EXECUTE FUNCTION f_observation_periode();

-- ------------------------------------------------------------
-- est_courante : bascule automatique (BEFORE, cf. contrainte index partiel)
-- ------------------------------------------------------------
-- ADR-048 : tg_version_courante SUPPRIMÉ (est_courante n'existe plus ; la version
-- courante = max no_version, dérivée dans v_version_courante).

-- ADR-048 : règle de succession. Un renouvellement (n+1) ne peut commencer AVANT
-- le terme du précédent : date_debut(n+1) >= date_debut(n) + 6 mois. Pas de borne
-- supérieure (reprendre après une pause est normal). Règle inter-lignes -> trigger.
CREATE OR REPLACE FUNCTION f_mandat_succession() RETURNS trigger AS $$
DECLARE deb_prec date;
BEGIN
    IF NEW.id_mandat_precedent IS NOT NULL THEN
        SELECT date_debut INTO deb_prec FROM mandat WHERE id_mandat = NEW.id_mandat_precedent;
        IF NEW.date_debut < deb_prec + INTERVAL '6 months' THEN
            RAISE EXCEPTION 'ADR-048 : un renouvellement doit debuter >= 6 mois apres le mandat precedent (debut precedent %, debut nouveau %)', deb_prec, NEW.date_debut;
        END IF;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER tg_mandat_succession BEFORE INSERT OR UPDATE OF id_mandat_precedent, date_debut ON mandat
    FOR EACH ROW EXECUTE FUNCTION f_mandat_succession();

-- ------------------------------------------------------------
-- C18 / RG-01 : un client (sans rôle chasseur/gestionnaire) ne peut pas poster privé
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION f_commentaire_prive() RETURNS trigger AS $$
DECLARE v_client boolean; v_pro boolean;
BEGIN
    IF NEW.est_prive THEN
        SELECT EXISTS(SELECT 1 FROM client WHERE id_utilisateur = NEW.id_auteur) INTO v_client;
        SELECT EXISTS(SELECT 1 FROM chasseur WHERE id_utilisateur = NEW.id_auteur)
             OR EXISTS(SELECT 1 FROM gestionnaire WHERE id_utilisateur = NEW.id_auteur) INTO v_pro;
        IF v_client AND NOT v_pro THEN
            RAISE EXCEPTION 'C18/RG-01 : un client ne peut pas poster un commentaire prive';
        END IF;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER tg_commentaire_prive BEFORE INSERT OR UPDATE ON commentaire
    FOR EACH ROW EXECUTE FUNCTION f_commentaire_prive();

-- ------------------------------------------------------------
-- C4 (au moins un acquéreur principal) : contrainte différée
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION f_demande_acquereur() RETURNS trigger AS $$
DECLARE v_demande uuid; v_nb int;
BEGIN
    v_demande := COALESCE(NEW.id_demande, OLD.id_demande);
    IF NOT EXISTS(SELECT 1 FROM demande WHERE id_demande = v_demande) THEN
        RETURN NULL;  -- demande supprimée : rien à vérifier
    END IF;
    SELECT count(*) INTO v_nb FROM demande_acquereur
        WHERE id_demande = v_demande AND qualite = 'principal';
    IF v_nb <> 1 THEN
        RAISE EXCEPTION 'C4 : demande % doit avoir exactement un acquereur principal (trouve %)', v_demande, v_nb;
    END IF;
    RETURN NULL;
END; $$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER tg_demande_acquereur
    AFTER INSERT OR UPDATE OR DELETE ON demande_acquereur
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION f_demande_acquereur();

-- A3/ADR-032 : une demande SANS acquéreur passait (le trigger ci-dessus ne se
-- déclenche que si on touche demande_acquereur). Second trigger différé côté
-- demande : vérifie en fin de transaction qu'au moins un acquéreur existe (défaut S1).
CREATE OR REPLACE FUNCTION f_demande_a_un_acquereur() RETURNS trigger AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM demande_acquereur WHERE id_demande = NEW.id_demande) THEN
        RAISE EXCEPTION 'C4 : demande % doit avoir au moins un acquereur', NEW.id_demande;
    END IF;
    RETURN NULL;
END; $$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER tg_demande_a_un_acquereur
    AFTER INSERT ON demande
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION f_demande_a_un_acquereur();

-- ------------------------------------------------------------
-- Synchronisation dénormalisations demande <- affectation
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION f_affectation_sync() RETURNS trigger AS $$
BEGIN
    IF NEW.date_fin IS NULL THEN  -- affectation ouverte = affectation courante
        UPDATE demande
           SET id_gestionnaire = NEW.id_gestionnaire,
               id_chasseur     = NEW.id_chasseur,
               date_affectation = COALESCE(date_affectation, NEW.date_debut)
         WHERE id_demande = NEW.id_demande;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER tg_affectation_sync AFTER INSERT OR UPDATE ON affectation
    FOR EACH ROW EXECUTE FUNCTION f_affectation_sync();

-- ============================================================
-- VUES
-- ============================================================

-- B2/S4/ADR-045 : une vente ne naît que d'une offre ACCEPTÉE et d'un compromis
-- RÉALISÉ. Règles inter-lignes -> déclencheurs (un CHECK ne lit pas une autre ligne).

-- Un compromis ne peut porter que sur une offre acceptée.
CREATE OR REPLACE FUNCTION f_compromis_offre_acceptee() RETURNS trigger AS $$
BEGIN
    IF (SELECT statut FROM offre_acquisition WHERE id_offre = NEW.id_offre) <> 'acceptee' THEN
        RAISE EXCEPTION 'S4 : compromis possible seulement sur une offre acceptee (offre %)', NEW.id_offre;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER tg_compromis_offre_acceptee
    BEFORE INSERT OR UPDATE OF id_offre ON compromis
    FOR EACH ROW EXECUTE FUNCTION f_compromis_offre_acceptee();

-- ADR-048 : un acte ne peut porter que sur un compromis NON CADUC (un compromis
-- caduc ne peut aboutir à une vente). « Réalisé » n'est plus un statut : il SE
-- DÉFINIT par l'existence de cet acte. La garde porte donc sur la caducité.
CREATE OR REPLACE FUNCTION f_acte_compromis_valide() RETURNS trigger AS $$
BEGIN
    IF (SELECT date_caducite FROM compromis WHERE id_compromis = NEW.id_compromis) IS NOT NULL THEN
        RAISE EXCEPTION 'S4 : acte impossible sur un compromis caduc (compromis %)', NEW.id_compromis;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER tg_acte_compromis_realise
    BEFORE INSERT OR UPDATE OF id_compromis ON acte
    FOR EACH ROW EXECUTE FUNCTION f_acte_compromis_valide();

-- ------------------------------------------------------------
-- ADR-053 / D13 : chaîne de renouvellement et droit à rémunération
-- ------------------------------------------------------------
-- Un mandat est « en vigueur » à une date s'il a commencé, n'est pas échu (6 mois, ADR-030)
-- et n'est pas résilié avant cette date. Le droit à rémunération se juge sur la CHAÎNE
-- (mandat initial + renouvellements, filiation id_mandat_precedent, ADR-048) : .feature 10
-- l. 45-50 (acte après l'échéance d'un mandat NON renouvelé -> droit fermé) et §4 des règles
-- de calcul (« sauf renouvellement du mandat »).

-- COST 10000 sur les trois fonctions : chaque appel exécute une CTE récursive ; sans ce coût déclaré, le
-- planificateur les évaluait AVANT les filtres d'égalité des vues (6 000 actes x 100 mandats, > 3 min).
-- Tous les mandats de la chaîne à laquelle appartient p_mandat (initial et renouvellements).
CREATE OR REPLACE FUNCTION f_chaine_mandats(p_mandat uuid) RETURNS SETOF uuid AS $$
    WITH RECURSIVE amont AS (            -- remonte jusqu'au mandat initial
        SELECT id_mandat, id_mandat_precedent FROM mandat WHERE id_mandat = p_mandat
        UNION ALL
        SELECT m.id_mandat, m.id_mandat_precedent FROM mandat m JOIN amont a ON m.id_mandat = a.id_mandat_precedent
    ), aval AS (                         -- redescend vers tous les renouvellements
        SELECT id_mandat FROM amont WHERE id_mandat_precedent IS NULL
        UNION ALL
        SELECT m.id_mandat FROM mandat m JOIN aval v ON m.id_mandat_precedent = v.id_mandat
    )
    SELECT id_mandat FROM aval;
$$ LANGUAGE sql STABLE COST 10000 ROWS 2;   -- ROWS 2 : sans cette estimation (1 000 par défaut), parcours complets au lieu des index

-- Le mandat INITIAL de la chaîne : point de départ du délai de performance S1 (D13).
CREATE OR REPLACE FUNCTION f_mandat_initial_chaine(p_mandat uuid) RETURNS uuid AS $$
    WITH RECURSIVE amont AS (
        SELECT id_mandat, id_mandat_precedent FROM mandat WHERE id_mandat = p_mandat
        UNION ALL
        SELECT m.id_mandat, m.id_mandat_precedent FROM mandat m JOIN amont a ON m.id_mandat = a.id_mandat_precedent
    )
    SELECT id_mandat FROM amont WHERE id_mandat_precedent IS NULL;
$$ LANGUAGE sql STABLE COST 10000;

-- Le mandat de la chaîne EN VIGUEUR à la date p_date, ou NULL (droit fermé).
-- Le jour où un renouvellement prend effet, c'est lui qui est retenu (date_debut la plus récente).
CREATE OR REPLACE FUNCTION f_mandat_en_vigueur_chaine(p_mandat uuid, p_date date) RETURNS uuid AS $$
    SELECT m.id_mandat
    FROM f_chaine_mandats(p_mandat) ch
    JOIN mandat m ON m.id_mandat = ch
    WHERE p_date >= m.date_debut
      AND p_date <= (m.date_debut + INTERVAL '6 months')::date
      AND (m.date_resiliation IS NULL OR p_date <= m.date_resiliation)
    ORDER BY m.date_debut DESC
    LIMIT 1;
$$ LANGUAGE sql STABLE COST 10000;

-- Les actes rattachés à une chaîne de mandats, par leurs deux origines, EN PARTANT DES INDEX (acte.id_mandat,
-- proposition.id_mandat) : c'est l'inverse de v_acte_mandat, qui part de l'acte. Sert aux vues d'état.
CREATE OR REPLACE FUNCTION f_actes_chaine(p_mandat uuid)
RETURNS TABLE (id_acte uuid, id_mandat_origine uuid, date_signature date) AS $$
    SELECT a.id_acte, a.id_mandat, a.date_signature
    FROM f_chaine_mandats(p_mandat) ch
    JOIN acte a ON a.id_mandat = ch
    UNION ALL
    SELECT a.id_acte, p.id_mandat, a.date_signature
    FROM f_chaine_mandats(p_mandat) ch
    JOIN proposition p       ON p.id_mandat = ch
    JOIN offre_acquisition o ON o.id_proposition = p.id_proposition
    JOIN compromis co        ON co.id_offre = o.id_offre
    JOIN acte a              ON a.id_compromis = co.id_compromis;
$$ LANGUAGE sql STABLE COST 10000;

-- Vrai si un acte de la chaîne rémunère CE mandat (= mandat en vigueur à la date de l'acte). Corps de
-- fonction = barrière d'optimisation : les actes candidats sont trouvés par index AVANT l'appel coûteux
-- à f_mandat_en_vigueur_chaine (sans cela, une sous-requête corrélée dans v_mandat l'évaluait pour chaque
-- acte et chaque mandat : > 3 min sur 20 000 mandats, mesure de la note d'indexation).
CREATE OR REPLACE FUNCTION f_mandat_clos_par_acte(p_mandat uuid) RETURNS boolean AS $$
    SELECT EXISTS (SELECT 1 FROM f_actes_chaine(p_mandat) x
                   WHERE f_mandat_en_vigueur_chaine(x.id_mandat_origine, x.date_signature) = p_mandat);
$$ LANGUAGE sql STABLE COST 10000;

-- S24 : un acte hors dispositif (sans compromis) référence le mandat EN VIGUEUR de sa chaîne à la
-- date de l'acte, et ce mandat est EXCLUSIF (Readme l. 75, US 00 et 10). Sous mandat non exclusif,
-- l'achat ailleurs clôt le mandat ('vente_externe', ADR-049). Fonction de contrôle réutilisée
-- par le trigger d'écriture et par la re-vérification après coup.
CREATE OR REPLACE FUNCTION f_verifier_acte_hors_dispositif(p_acte uuid, p_mandat uuid, p_date date) RETURNS void AS $$
DECLARE v uuid; v_exclusif boolean;
BEGIN
    IF p_mandat IS NULL THEN RETURN; END IF;               -- vente menée par le chasseur (compromis)
    v := f_mandat_en_vigueur_chaine(p_mandat, p_date);
    IF v IS NULL THEN
        RAISE EXCEPTION 'S24 : acte hors dispositif % refusé, aucun mandat de la chaîne de % n''est en vigueur le %', p_acte, p_mandat, p_date;
    END IF;
    IF v <> p_mandat THEN
        RAISE EXCEPTION 'S24 : acte hors dispositif % refusé, le mandat en vigueur le % est le renouvellement %, pas %', p_acte, p_date, v, p_mandat;
    END IF;
    SELECT exclusif INTO v_exclusif FROM mandat WHERE id_mandat = v;
    IF NOT v_exclusif THEN
        RAISE EXCEPTION 'S24 : acte hors dispositif % refusé, le mandat % n''est pas exclusif', p_acte, v;
    END IF;
END; $$ LANGUAGE plpgsql;

-- S25 / S26 : la rémunération porte sur le mandat de la chaîne EN VIGUEUR à la date de l'acte,
-- quelle que soit l'origine de l'acte (chaîne compromis -> offre -> proposition, ou mandat direct).
-- S26 : si aucun mandat de la chaîne n'est en vigueur, le droit est fermé (.feature 10 l. 45-50).
-- La FK composée fk_remuneration_mandat garantit déjà chasseur = chasseur du mandat.
CREATE OR REPLACE FUNCTION f_verifier_remuneration(p_acte uuid, p_mandat uuid) RETURNS void AS $$
DECLARE v_racine uuid; v_date date; v uuid;
BEGIN
    SELECT COALESCE(a.id_mandat, p.id_mandat), a.date_signature INTO v_racine, v_date
    FROM acte a
    LEFT JOIN compromis co        ON co.id_compromis = a.id_compromis
    LEFT JOIN offre_acquisition o ON o.id_offre = co.id_offre
    LEFT JOIN proposition p       ON p.id_proposition = o.id_proposition
    WHERE a.id_acte = p_acte;
    v := f_mandat_en_vigueur_chaine(v_racine, v_date);
    IF v IS NULL THEN
        RAISE EXCEPTION 'S26 : droit fermé, aucun mandat de la chaîne de % n''est en vigueur à la date de l''acte % (%)', v_racine, p_acte, v_date;
    END IF;
    IF v <> p_mandat THEN
        RAISE EXCEPTION 'S25 : la rémunération doit porter sur le mandat en vigueur à l''acte (acte %, mandat en vigueur %, mandat saisi %)', p_acte, v, p_mandat;
    END IF;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION f_acte_hors_dispositif() RETURNS trigger AS $$
BEGIN
    PERFORM f_verifier_acte_hors_dispositif(NEW.id_acte, NEW.id_mandat, NEW.date_signature);
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER tg_acte_hors_dispositif
    BEFORE INSERT OR UPDATE OF id_mandat, date_signature ON acte
    FOR EACH ROW EXECUTE FUNCTION f_acte_hors_dispositif();

CREATE OR REPLACE FUNCTION f_remuneration_mandat_acte() RETURNS trigger AS $$
BEGIN
    PERFORM f_verifier_remuneration(NEW.id_acte, NEW.id_mandat);
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER tg_remuneration_mandat_acte
    BEFORE INSERT OR UPDATE OF id_acte, id_mandat ON remuneration_chasseur
    FOR EACH ROW EXECUTE FUNCTION f_remuneration_mandat_acte();

-- Re-vérification APRÈS COUP (contournement) : modifier un mandat (exclusivité, dates, résiliation,
-- filiation) ou un acte (mandat, compromis, date) après l'écriture de l'acte ou de la rémunération
-- ne doit pas les rendre incohérents. Déclencheurs de contrainte DIFFÉRÉS : contrôlés au commit,
-- pour laisser une transaction applicative enchaîner plusieurs mises à jour
-- (ex. renouvellement : mettre à jour l'acte puis la rémunération). SET CONSTRAINTS ALL IMMEDIATE
-- force le contrôle sans attendre le commit (utilisé par le harnais de tests).
CREATE OR REPLACE FUNCTION f_reverifier_apres_mandat() RETURNS trigger AS $$
DECLARE r record;
BEGIN
    FOR r IN SELECT a.id_acte, a.id_mandat, a.date_signature FROM acte a
             WHERE a.id_mandat IN (SELECT f_chaine_mandats(NEW.id_mandat)
                                   UNION SELECT f_chaine_mandats(OLD.id_mandat_precedent))
    LOOP
        PERFORM f_verifier_acte_hors_dispositif(r.id_acte, r.id_mandat, r.date_signature);
    END LOOP;
    FOR r IN SELECT rc.id_acte, rc.id_mandat FROM remuneration_chasseur rc
             WHERE rc.id_mandat IN (SELECT f_chaine_mandats(NEW.id_mandat)
                                    UNION SELECT f_chaine_mandats(OLD.id_mandat_precedent))
    LOOP
        PERFORM f_verifier_remuneration(r.id_acte, r.id_mandat);
    END LOOP;
    RETURN NULL;
END; $$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER tg_mandat_reverification
    AFTER UPDATE OF exclusif, date_debut, date_signature, date_resiliation, type_resiliation, id_mandat_precedent ON mandat
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION f_reverifier_apres_mandat();

CREATE OR REPLACE FUNCTION f_reverifier_apres_acte() RETURNS trigger AS $$
DECLARE r record;
BEGIN
    FOR r IN SELECT rc.id_acte, rc.id_mandat FROM remuneration_chasseur rc WHERE rc.id_acte = NEW.id_acte
    LOOP
        PERFORM f_verifier_remuneration(r.id_acte, r.id_mandat);
    END LOOP;
    RETURN NULL;
END; $$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER tg_acte_reverification
    AFTER UPDATE OF id_mandat, id_compromis, date_signature ON acte
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION f_reverifier_apres_acte();

-- S27 (revue de la PR #14, point A) : on ne résilie pas un mandat qui a abouti. Sans cette garde, une
-- résiliation posée APRÈS l'acte faisait passer le mandat en « résilié » dans v_mandat (la résiliation y
-- est testée avant le succès) alors que le chasseur a été payé. Cause traitée, pas le symptôme.
CREATE OR REPLACE FUNCTION f_mandat_resiliation_apres_acte() RETURNS trigger AS $$
BEGIN
    IF NEW.date_resiliation IS NOT NULL AND f_mandat_clos_par_acte(NEW.id_mandat) THEN
        RAISE EXCEPTION 'S27 : résiliation refusée, le mandat % a déjà abouti à un acte', NEW.id_mandat;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER tg_mandat_resiliation_apres_acte
    BEFORE INSERT OR UPDATE OF date_resiliation, type_resiliation ON mandat
    FOR EACH ROW EXECUTE FUNCTION f_mandat_resiliation_apres_acte();

-- S28 / D20 : la rémunération du chasseur n'existe qu'après l'encaissement des honoraires par
-- l'entreprise. Source : Readme, parcours du chasseur, étape 10 (« une fois que l'entreprise reçoit
-- les honoraires, le chasseur est prévenu du paiement proche de sa rémunération »). Tant qu'un
-- litige client bloque l'encaissement (contestation, décision judiciaire attendue), rien ne doit
-- permettre de payer le chasseur. La règle était écrite (01_ddl.sql, ADR-049) mais portée par
-- aucune contrainte : la base acceptait une rémunération sur un acte non encaissé.
-- Concurrence (revue de la PR #16, Angeline Gomez, point A) : la ligne de l'acte est VERROUILLÉE
-- (FOR SHARE) pendant la vérification. Sans ce verrou, une transaction qui décoche l'encaissement
-- en même temps ne voit pas la rémunération pas encore validée, et les deux passent (course
-- reproduite le 13/10). Avec le verrou, la transaction concurrente attend la fin de celle-ci,
-- puis voit la rémunération et est refusée par le volet symétrique ci-dessous. Le verrou posé par
-- la clé étrangère (FOR KEY SHARE) ne suffit pas : il ne bloque pas la mise à jour d'une colonne
-- non clé comme honoraires_encaisses.
CREATE OR REPLACE FUNCTION f_remuneration_encaissement() RETURNS trigger AS $$
BEGIN
    PERFORM 1 FROM acte a WHERE a.id_acte = NEW.id_acte AND a.honoraires_encaisses FOR SHARE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'S28 : rémunération refusée, les honoraires de l''acte % ne sont pas encaissés', NEW.id_acte;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER tg_remuneration_encaissement
    BEFORE INSERT OR UPDATE OF id_acte ON remuneration_chasseur
    FOR EACH ROW EXECUTE FUNCTION f_remuneration_encaissement();

-- S28 (volet symétrique) : on n'annule pas l'encaissement d'un acte déjà rémunéré.
CREATE OR REPLACE FUNCTION f_acte_encaissement_remunere() RETURNS trigger AS $$
BEGIN
    IF NOT NEW.honoraires_encaisses
       AND EXISTS (SELECT 1 FROM remuneration_chasseur rc WHERE rc.id_acte = NEW.id_acte) THEN
        RAISE EXCEPTION 'S28 : annulation d''encaissement refusée, l''acte % porte déjà une rémunération', NEW.id_acte;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER tg_acte_encaissement_remunere
    BEFORE UPDATE OF honoraires_encaisses ON acte
    FOR EACH ROW EXECUTE FUNCTION f_acte_encaissement_remunere();

-- ADR-053 / D13 : pour chaque acte, le mandat d'ORIGINE (chaîne de vente ou hors dispositif),
-- le mandat EN VIGUEUR de sa chaîne à la date de l'acte (celui que rémunère remuneration_chasseur)
-- et le mandat INITIAL (point de départ du délai S1). Sert aux vues d'état et à l'entrepôt.
CREATE VIEW v_acte_mandat AS
SELECT a.id_acte,
       a.date_signature,
       (a.id_mandat IS NOT NULL)                                                            AS hors_dispositif,
       COALESCE(a.id_mandat, p.id_mandat)                                                   AS id_mandat_origine,
       f_mandat_en_vigueur_chaine(COALESCE(a.id_mandat, p.id_mandat), a.date_signature)    AS id_mandat_en_vigueur,
       f_mandat_initial_chaine(COALESCE(a.id_mandat, p.id_mandat))                         AS id_mandat_initial
FROM acte a
LEFT JOIN compromis co        ON co.id_compromis = a.id_compromis
LEFT JOIN offre_acquisition o ON o.id_offre = co.id_offre
LEFT JOIN proposition p       ON p.id_proposition = o.id_proposition;

-- Mandat : date_fin et expiration calculées (ADR-030), jamais stockées
-- ADR-048 : état du mandat ENTIÈREMENT DÉRIVÉ des faits. Aucun statut stocké.
CREATE VIEW v_mandat AS
SELECT m.*,
       (m.date_debut + INTERVAL '6 months')::date AS date_fin,
       ((m.date_debut + INTERVAL '6 months')::date < date_reference()) AS est_expire,
       -- faits dérivés
       -- ADR-053 / D13 : l'acte (chaîne de vente ou hors dispositif) est rattaché au mandat de la
       -- chaîne EN VIGUEUR à sa date (v_acte_mandat) : le mandat initial d'une chaîne renouvelée
       -- est « renouvelé », le renouvellement qui aboutit est « clos en succès ».
       -- f_mandat_clos_par_acte : actes de la chaîne trouvés par index, puis mandat en vigueur (ADR-053 / D13)
       f_mandat_clos_par_acte(m.id_mandat) AS a_acte,
       EXISTS (SELECT 1 FROM mandat s WHERE s.id_mandat_precedent = m.id_mandat) AS a_successeur,
       -- statut officiel : ADR-048 « repris fait foi ». Si un état repris existe
       -- (fait historique non recalculable, flux de rachats), il prime ; sinon on
       -- dérive des faits (résilié > succès > renouvelé > actif > échu).
       COALESCE(
         (SELECT mr.statut_repris FROM mandat_reprise mr
          WHERE mr.id_mandat = m.id_mandat),
         CASE
           WHEN m.date_resiliation IS NOT NULL THEN 'resilie'
           WHEN f_mandat_clos_par_acte(m.id_mandat) THEN 'clos_succes'  -- ADR-053 / D13
           WHEN EXISTS (SELECT 1 FROM mandat s WHERE s.id_mandat_precedent = m.id_mandat) THEN 'renouvele'
           WHEN (m.date_debut + INTERVAL '6 months')::date >= date_reference() THEN 'actif'
           ELSE 'echu'
         END
       ) AS statut_calcule
FROM mandat m;

-- Seul point de lecture des mandats réellement en cours
CREATE VIEW v_mandat_actif AS
SELECT * FROM v_mandat WHERE statut_calcule = 'actif';

-- Honoraires entreprise (total calculé, jamais stocké)
CREATE VIEW v_honoraires AS
SELECT a.id_acte, a.montant_vente, a.honoraires_fixe, a.honoraires_taux,
       -- E5-m13/ADR-040 : arrondi au centime — ces honoraires sont l'assiette de la rémunération.
       round(COALESCE(a.honoraires_fixe,0) + COALESCE(a.honoraires_taux,0)/100 * a.montant_vente, 2) AS honoraires_total
FROM acte a;

-- Version courante servant au matching
-- ADR-048 : version courante = celle au no_version MAX par demande (dérivée).
CREATE VIEW v_version_courante AS
SELECT dv.* FROM demande_version dv
WHERE dv.no_version = (SELECT max(no_version) FROM demande_version d2 WHERE d2.id_demande = dv.id_demande);

-- ADR-048 : cycle de la demande entièrement dérivé des faits.
CREATE VIEW v_demande AS
SELECT d.*,
       CASE
         WHEN d.date_sans_suite IS NOT NULL THEN 'sans_suite'
         -- ADR-053 / D13 : la demande est close dès qu'un acte rémunère un mandat de la demande
         WHEN EXISTS (SELECT 1 FROM mandat mo WHERE mo.id_demande = d.id_demande AND f_mandat_clos_par_acte(mo.id_mandat)) THEN 'close'
         WHEN d.id_mandat_courant IS NOT NULL THEN 'en_recherche'
         WHEN d.date_qualification IS NOT NULL THEN 'qualifie'
         WHEN d.date_affectation IS NOT NULL THEN 'affecte'
         ELSE 'nouveau'
       END AS statut_calcule
FROM demande d;

-- ADR-048 : état du compromis dérivé (signé/réalisé) sauf caducité (fait stocké).
CREATE VIEW v_compromis AS
SELECT c.*,
       CASE
         WHEN c.date_caducite IS NOT NULL THEN 'caduc'
         WHEN EXISTS (SELECT 1 FROM acte a WHERE a.id_compromis = c.id_compromis) THEN 'realise'
         ELSE 'signe'
       END AS statut_calcule
FROM compromis c;

-- Conformité chasseur : cartes/RCP expirées + mandats signés hors validité de carte
-- A8/ADR-039 : conformité GELÉE à la signature. mandat_hors_carte lit la
-- validité de carte T figée sur le mandat (validite_carte_t_signature), et non
-- la carte courante — la non-conformité d'époque reste visible après renouvellement.
-- D-FLAG (migration) : est_a_regulariser (calculé, non stocké) — lu par la couche
-- applicative pour blocage éventuel. Les deux modifications d'un seul tenant (ADR-039).
CREATE VIEW v_conformite_chasseur AS
SELECT c.id_utilisateur,
       (c.date_validite_habilitation < date_reference()) AS habilitation_expiree,
       (c.date_echeance_rcp          < date_reference()) AS rcp_expiree,
       -- mandat signé alors que l'habilitation gelée était déjà expirée.
       -- NULL de gel (M1) = « inconnu à la reprise » -> pas compté comme non conforme.
       EXISTS (SELECT 1 FROM mandat m
               WHERE m.id_chasseur = c.id_utilisateur
                 AND m.validite_habilitation_signature IS NOT NULL
                 AND m.date_signature > m.validite_habilitation_signature) AS mandat_hors_habilitation,
       (
            c.date_validite_habilitation < date_reference()
         OR c.date_echeance_rcp          < date_reference()
         OR c.numero_habilitation LIKE 'A_REGULARISER%'
         OR c.numero_rcp          LIKE 'A_REGULARISER%'
         OR c.organisme_delivrance = 'A_REGULARISER'
         OR c.organisme_garant     = 'A_REGULARISER'
       ) AS est_a_regulariser
FROM chasseur c;

-- Charge gestionnaire : leads en cours, capacité, taux de charge (source KPI)
CREATE VIEW v_charge_gestionnaire AS
SELECT g.id_utilisateur,
       g.capacite_max_leads,
       count(d.id_demande) FILTER (WHERE d.statut_calcule NOT IN ('sans_suite','close')) AS leads_en_cours,
       round(
         count(d.id_demande) FILTER (WHERE d.statut_calcule NOT IN ('sans_suite','close'))::numeric
         / NULLIF(g.capacite_max_leads,0), 2) AS taux_charge
FROM gestionnaire g
LEFT JOIN v_demande d ON d.id_gestionnaire = g.id_utilisateur
GROUP BY g.id_utilisateur, g.capacite_max_leads;
-- A9/ADR-036 : v_delai_affectation RETIRÉE de l'OLTP. C'est une mesure
-- comparative (moyenne de délai par gestionnaire) qui ne pilote aucune
-- transaction -> elle relève de l'OLAP, calculée sur affectation historisée
-- (en excluant SYS-MIGRATION). Ne pas dupliquer en OLTP ce qui se calcule en OLAP.
