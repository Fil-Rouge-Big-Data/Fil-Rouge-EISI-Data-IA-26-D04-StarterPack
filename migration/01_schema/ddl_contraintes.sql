-- ============================================================
-- SCRIPT DDL — Ajout des Clés Étrangères (FK)
-- Permet de séparer la création des tables et l'ajout des contraintes
-- ============================================================

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
