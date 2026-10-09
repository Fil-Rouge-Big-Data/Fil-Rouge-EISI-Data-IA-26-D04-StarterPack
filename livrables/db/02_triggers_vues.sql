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

-- Mandat : date_fin et expiration calculées (ADR-030), jamais stockées
-- ADR-048 : état du mandat ENTIÈREMENT DÉRIVÉ des faits. Aucun statut stocké.
CREATE VIEW v_mandat AS
SELECT m.*,
       (m.date_debut + INTERVAL '6 months')::date AS date_fin,
       ((m.date_debut + INTERVAL '6 months')::date < date_reference()) AS est_expire,
       -- faits dérivés
       EXISTS (SELECT 1 FROM acte a JOIN compromis co ON co.id_compromis=a.id_compromis
               JOIN offre_acquisition o ON o.id_offre=co.id_offre
               JOIN proposition p ON p.id_proposition=o.id_proposition
               WHERE p.id_mandat = m.id_mandat) AS a_acte,
       EXISTS (SELECT 1 FROM mandat s WHERE s.id_mandat_precedent = m.id_mandat) AS a_successeur,
       -- statut officiel : ADR-048 « repris fait foi ». Si un état repris existe
       -- (fait historique non recalculable, flux de rachats), il prime ; sinon on
       -- dérive des faits (résilié > succès > renouvelé > actif > échu).
       COALESCE(
         (SELECT mr.statut_repris FROM mandat_reprise mr
          WHERE mr.id_mandat = m.id_mandat),
         CASE
           WHEN m.date_resiliation IS NOT NULL THEN 'resilie'
           WHEN EXISTS (SELECT 1 FROM acte a JOIN compromis co ON co.id_compromis=a.id_compromis
                        JOIN offre_acquisition o ON o.id_offre=co.id_offre
                        JOIN proposition p ON p.id_proposition=o.id_proposition
                        WHERE p.id_mandat = m.id_mandat) THEN 'clos_succes'
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
         WHEN EXISTS (SELECT 1 FROM acte a JOIN compromis co ON co.id_compromis=a.id_compromis
                      JOIN offre_acquisition o ON o.id_offre=co.id_offre
                      JOIN proposition p ON p.id_proposition=o.id_proposition
                      WHERE p.id_mandat = d.id_mandat_courant) THEN 'close'
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
