-- ============================================================
-- SCRIPT DDL — Ajout des Clés Étrangères (FK), Index et Contraintes (CHECK)
-- V5 : Version exhaustive avec btree_gist, exclusion et transactions
-- ============================================================

SET search_path TO fil_rouge_cible;

BEGIN;

-- ==========================================
-- 0. EXTENSIONS POUR RÈGLES AVANCÉES
-- ==========================================
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ==========================================
-- 1. CLÉS ÉTRANGÈRES (FOREIGN KEYS)
-- ==========================================
ALTER TABLE VILLE ADD CONSTRAINT fk_ville_pays FOREIGN KEY (code_iso_pays) REFERENCES PAYS(code_iso);
ALTER TABLE SECTEUR ADD CONSTRAINT fk_secteur_ville FOREIGN KEY (id_ville) REFERENCES VILLE(id_ville);

ALTER TABLE PERSONNE ADD CONSTRAINT fk_personne_ville FOREIGN KEY (id_ville) REFERENCES VILLE(id_ville);
ALTER TABLE CLIENT ADD CONSTRAINT fk_client_personne FOREIGN KEY (id_personne) REFERENCES PERSONNE(id_personne);
ALTER TABLE CHASSEUR ADD CONSTRAINT fk_chasseur_personne FOREIGN KEY (id_personne) REFERENCES PERSONNE(id_personne);

ALTER TABLE DEMANDE ADD CONSTRAINT fk_demande_client FOREIGN KEY (id_client) REFERENCES CLIENT(id_personne);

ALTER TABLE AFFECTATION ADD CONSTRAINT fk_affectation_demande FOREIGN KEY (id_demande) REFERENCES DEMANDE(id_demande);
ALTER TABLE AFFECTATION ADD CONSTRAINT fk_affectation_chasseur FOREIGN KEY (id_chasseur) REFERENCES CHASSEUR(id_personne);

ALTER TABLE MANDAT ADD CONSTRAINT fk_mandat_demande FOREIGN KEY (id_demande) REFERENCES DEMANDE(id_demande);
ALTER TABLE MANDAT ADD CONSTRAINT fk_mandat_chasseur FOREIGN KEY (id_chasseur) REFERENCES CHASSEUR(id_personne);

ALTER TABLE RENOUVELLEMENT_MANDAT ADD CONSTRAINT fk_renouvellement_mandat FOREIGN KEY (id_mandat) REFERENCES MANDAT(id_mandat);

ALTER TABLE DEMANDE_VERSION ADD CONSTRAINT fk_version_demande FOREIGN KEY (id_demande) REFERENCES DEMANDE(id_demande);
ALTER TABLE DEMANDE_VERSION ADD CONSTRAINT fk_version_redacteur FOREIGN KEY (id_redacteur) REFERENCES PERSONNE(id_personne);

ALTER TABLE DEMANDE_SECTEUR ADD CONSTRAINT fk_dsect_version FOREIGN KEY (id_version) REFERENCES DEMANDE_VERSION(id_version);
ALTER TABLE DEMANDE_SECTEUR ADD CONSTRAINT fk_dsect_secteur FOREIGN KEY (id_secteur) REFERENCES SECTEUR(id_secteur);

ALTER TABLE DEMANDE_CARACTERISTIQUE ADD CONSTRAINT fk_dcaract_version FOREIGN KEY (id_version) REFERENCES DEMANDE_VERSION(id_version);
ALTER TABLE DEMANDE_CARACTERISTIQUE ADD CONSTRAINT fk_dcaract_caract FOREIGN KEY (id_caracteristique) REFERENCES CARACTERISTIQUE(id_caracteristique);

ALTER TABLE BIEN ADD CONSTRAINT fk_bien_secteur FOREIGN KEY (id_secteur) REFERENCES SECTEUR(id_secteur);

ALTER TABLE BIEN_CARACTERISTIQUE ADD CONSTRAINT fk_bcaract_bien FOREIGN KEY (id_bien) REFERENCES BIEN(id_bien);
ALTER TABLE BIEN_CARACTERISTIQUE ADD CONSTRAINT fk_bcaract_caract FOREIGN KEY (id_caracteristique) REFERENCES CARACTERISTIQUE(id_caracteristique);

ALTER TABLE ANNONCE ADD CONSTRAINT fk_annonce_bien FOREIGN KEY (id_bien) REFERENCES BIEN(id_bien);

ALTER TABLE PROPOSITION ADD CONSTRAINT fk_proposition_version FOREIGN KEY (id_version) REFERENCES DEMANDE_VERSION(id_version);
ALTER TABLE PROPOSITION ADD CONSTRAINT fk_proposition_annonce FOREIGN KEY (id_annonce) REFERENCES ANNONCE(id_annonce);

ALTER TABLE COMMENTAIRE ADD CONSTRAINT fk_commentaire_proposition FOREIGN KEY (id_proposition) REFERENCES PROPOSITION(id_proposition);
ALTER TABLE COMMENTAIRE ADD CONSTRAINT fk_commentaire_auteur FOREIGN KEY (id_auteur) REFERENCES PERSONNE(id_personne);

ALTER TABLE PIECE_JOINTE ADD CONSTRAINT fk_piece_commentaire FOREIGN KEY (id_commentaire) REFERENCES COMMENTAIRE(id_commentaire);

ALTER TABLE VISITE ADD CONSTRAINT fk_visite_proposition FOREIGN KEY (id_proposition) REFERENCES PROPOSITION(id_proposition);
ALTER TABLE VISITE ADD CONSTRAINT fk_visite_visiteur FOREIGN KEY (id_visiteur) REFERENCES PERSONNE(id_personne);

ALTER TABLE OFFRE_ACQUISITION ADD CONSTRAINT fk_offre_proposition FOREIGN KEY (id_proposition) REFERENCES PROPOSITION(id_proposition);
ALTER TABLE OFFRE_ACQUISITION ADD CONSTRAINT fk_offre_precedente FOREIGN KEY (id_offre_precedente) REFERENCES OFFRE_ACQUISITION(id_offre);

ALTER TABLE COMPROMIS ADD CONSTRAINT fk_compromis_offre FOREIGN KEY (id_offre) REFERENCES OFFRE_ACQUISITION(id_offre);
ALTER TABLE COMPROMIS ADD CONSTRAINT fk_compromis_notaire FOREIGN KEY (id_notaire) REFERENCES NOTAIRE(id_notaire);

ALTER TABLE CLAUSE_SUSPENSIVE ADD CONSTRAINT fk_clause_compromis FOREIGN KEY (id_compromis) REFERENCES COMPROMIS(id_compromis);

ALTER TABLE ACTE ADD CONSTRAINT fk_acte_compromis FOREIGN KEY (id_compromis) REFERENCES COMPROMIS(id_compromis);

ALTER TABLE BAREME ADD CONSTRAINT fk_bareme_chasseur FOREIGN KEY (id_chasseur) REFERENCES CHASSEUR(id_personne);
ALTER TABLE TRANCHE_BAREME ADD CONSTRAINT fk_tranche_bareme FOREIGN KEY (id_bareme) REFERENCES BAREME(id_bareme);

ALTER TABLE REMUNERATION ADD CONSTRAINT fk_remuneration_acte FOREIGN KEY (id_acte) REFERENCES ACTE(id_acte);
ALTER TABLE FACTURE ADD CONSTRAINT fk_facture_remuneration FOREIGN KEY (id_remuneration) REFERENCES REMUNERATION(id_remuneration);
ALTER TABLE PAIEMENT ADD CONSTRAINT fk_paiement_facture FOREIGN KEY (id_facture) REFERENCES FACTURE(id_facture);

ALTER TABLE INDICATEUR_PERFORMANCE ADD CONSTRAINT fk_indicateur_chasseur FOREIGN KEY (id_chasseur) REFERENCES CHASSEUR(id_personne);

-- ==========================================
-- 2. INDEX SUR LES CLÉS ÉTRANGÈRES (Performance)
-- ==========================================
CREATE INDEX idx_ville_pays ON VILLE(code_iso_pays);
CREATE INDEX idx_secteur_ville ON SECTEUR(id_ville);
CREATE INDEX idx_personne_ville ON PERSONNE(id_ville);
CREATE INDEX idx_demande_client ON DEMANDE(id_client);
CREATE INDEX idx_affectation_demande ON AFFECTATION(id_demande);
CREATE INDEX idx_affectation_chasseur ON AFFECTATION(id_chasseur);
CREATE INDEX idx_mandat_demande ON MANDAT(id_demande);
CREATE INDEX idx_mandat_chasseur ON MANDAT(id_chasseur);
CREATE INDEX idx_renouvellement_mandat ON RENOUVELLEMENT_MANDAT(id_mandat);
CREATE INDEX idx_version_demande ON DEMANDE_VERSION(id_demande);
CREATE INDEX idx_version_redacteur ON DEMANDE_VERSION(id_redacteur);
CREATE INDEX idx_dsect_secteur ON DEMANDE_SECTEUR(id_secteur);
CREATE INDEX idx_dcaract_caract ON DEMANDE_CARACTERISTIQUE(id_caracteristique);
CREATE INDEX idx_bien_secteur ON BIEN(id_secteur);
CREATE INDEX idx_bcaract_caract ON BIEN_CARACTERISTIQUE(id_caracteristique);
CREATE INDEX idx_annonce_bien ON ANNONCE(id_bien);
CREATE INDEX idx_proposition_version ON PROPOSITION(id_version);
CREATE INDEX idx_proposition_annonce ON PROPOSITION(id_annonce);
CREATE INDEX idx_commentaire_proposition ON COMMENTAIRE(id_proposition);
CREATE INDEX idx_commentaire_auteur ON COMMENTAIRE(id_auteur);
CREATE INDEX idx_piece_commentaire ON PIECE_JOINTE(id_commentaire);
CREATE INDEX idx_visite_proposition ON VISITE(id_proposition);
CREATE INDEX idx_visite_visiteur ON VISITE(id_visiteur);
CREATE INDEX idx_offre_proposition ON OFFRE_ACQUISITION(id_proposition);
CREATE INDEX idx_offre_precedente ON OFFRE_ACQUISITION(id_offre_precedente);
CREATE INDEX idx_compromis_offre ON COMPROMIS(id_offre);
CREATE INDEX idx_compromis_notaire ON COMPROMIS(id_notaire);
CREATE INDEX idx_clause_compromis ON CLAUSE_SUSPENSIVE(id_compromis);
CREATE INDEX idx_acte_compromis ON ACTE(id_compromis);
CREATE INDEX idx_bareme_chasseur ON BAREME(id_chasseur);
CREATE INDEX idx_tranche_bareme ON TRANCHE_BAREME(id_bareme);
CREATE INDEX idx_remuneration_acte ON REMUNERATION(id_acte);
CREATE INDEX idx_facture_remuneration ON FACTURE(id_remuneration);
CREATE INDEX idx_paiement_facture ON PAIEMENT(id_facture);
CREATE INDEX idx_indicateur_chasseur ON INDICATEUR_PERFORMANCE(id_chasseur);

-- ==========================================
-- 3. CONTRAINTES DE VALIDATION (Data Quality & Règles Métier)
-- ==========================================

-- Unicité métier et structurelle intelligente
CREATE UNIQUE INDEX ux_secteur_ville_quartier ON SECTEUR (id_ville, COALESCE(quartier, ''));
ALTER TABLE VILLE ADD CONSTRAINT uq_ville_insee UNIQUE (code_iso_pays, code_insee);
ALTER TABLE MANDAT ADD CONSTRAINT uq_mandat_registre UNIQUE (numero_registre);
ALTER TABLE DEMANDE_VERSION ADD CONSTRAINT uq_version UNIQUE (id_demande, no_version);
CREATE UNIQUE INDEX ux_version_courante ON DEMANDE_VERSION (id_demande) WHERE est_courante;
CREATE UNIQUE INDEX ux_caracteristique_libelle ON CARACTERISTIQUE (lower(libelle));
ALTER TABLE INDICATEUR_PERFORMANCE ADD CONSTRAINT uq_indicateur_date UNIQUE (id_chasseur, date_calcul);

-- Validation des formats de contact (Email & Téléphone international)
ALTER TABLE PERSONNE ADD CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
ALTER TABLE PERSONNE ADD CONSTRAINT chk_telephone_format CHECK (telephone ~ '^\+?[0-9\s\-\.()]{6,20}$');

-- Validation du code postal (Format international permissif)
ALTER TABLE SECTEUR ADD CONSTRAINT chk_code_postal CHECK (code_postal ~ '^[A-Za-z0-9\s-]{3,10}$');

-- Cohérence temporelle et règles légales (Loi Hoguet = max 6 mois)
ALTER TABLE MANDAT ADD CONSTRAINT chk_mandat_dates CHECK (date_fin > date_signature);
ALTER TABLE MANDAT ADD CONSTRAINT chk_mandat_duree_max CHECK (date_fin <= date_debut_periode + INTERVAL '6 months');
ALTER TABLE RENOUVELLEMENT_MANDAT ADD CONSTRAINT chk_renouvellement_date CHECK (nouvelle_date_fin > date_renouvellement);
ALTER TABLE ANNONCE ADD CONSTRAINT chk_annonce_dates CHECK (date_retrait IS NULL OR date_retrait >= date_publication);

-- Cohérence des barèmes de commission et non-chevauchement
ALTER TABLE BAREME ADD CONSTRAINT chk_bareme_dates CHECK (date_fin IS NULL OR date_fin > date_debut);
ALTER TABLE TRANCHE_BAREME ADD CONSTRAINT chk_tranche_coherente CHECK (montant_max IS NULL OR montant_max > montant_min);
ALTER TABLE TRANCHE_BAREME ADD CONSTRAINT chk_taux_valide CHECK (taux >= 0 AND taux <= 100);
ALTER TABLE DEMANDE_VERSION ADD CONSTRAINT chk_pieces_coherentes CHECK (nb_chambres_min IS NULL OR nb_pieces_min IS NULL OR nb_chambres_min <= nb_pieces_min);

-- Exclusion des chevauchements de tranches et de barèmes (GIST)
ALTER TABLE TRANCHE_BAREME ADD CONSTRAINT excl_tranche_bareme EXCLUDE USING gist (id_bareme WITH =, numrange(montant_min, montant_max) WITH &&);
ALTER TABLE BAREME ADD CONSTRAINT excl_bareme_periode EXCLUDE USING gist (id_chasseur WITH =, daterange(date_debut, COALESCE(date_fin, 'infinity'::date)) WITH &&);

-- ==========================================
-- TRIGGERS (Automatisation Métier)
-- ==========================================
CREATE OR REPLACE FUNCTION trg_update_mandat_fin() RETURNS TRIGGER 
  LANGUAGE plpgsql
  SET search_path = fil_rouge_cible
AS $$
BEGIN
    UPDATE MANDAT 
    SET date_debut_periode = NEW.date_renouvellement,
        date_fin = NEW.nouvelle_date_fin 
    WHERE id_mandat = NEW.id_mandat;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_renouvellement_mandat ON RENOUVELLEMENT_MANDAT;
CREATE TRIGGER trg_renouvellement_mandat
AFTER INSERT OR UPDATE ON RENOUVELLEMENT_MANDAT
FOR EACH ROW EXECUTE FUNCTION trg_update_mandat_fin();

-- Montants et surfaces logiques
ALTER TABLE DEMANDE_VERSION ADD CONSTRAINT chk_budget_max CHECK (budget_max > 0);
ALTER TABLE DEMANDE_VERSION ADD CONSTRAINT chk_surface_min CHECK (surface_min > 0);
ALTER TABLE OFFRE_ACQUISITION ADD CONSTRAINT chk_montant_offre CHECK (montant > 0);

COMMIT;
