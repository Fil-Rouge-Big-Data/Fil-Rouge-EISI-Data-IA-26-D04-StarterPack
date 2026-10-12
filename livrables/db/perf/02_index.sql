-- ============================================================
-- 02_index.sql — Index proposés après mesure (note d'indexation). Chacun est justifié par UNE requête
-- de 03_requetes.sql ; principe d'éco-conception ENF-26 : pas d'index sans requête qui le demande.
-- PostgreSQL n'indexe PAS automatiquement les clés étrangères : seules les clés primaires et les
-- unicités le sont. Les jointures « parent -> enfants » (mandat -> propositions, proposition -> visites,
-- chasseur -> mandats / rémunérations) partent donc d'un parcours séquentiel sans ces index.
-- ============================================================

-- Q1 (mandats d'un chasseur) et Q2 (mandats signés sur 12 mois) : accès par chasseur puis par date
CREATE INDEX IF NOT EXISTS ix_mandat_chasseur_signature ON mandat (id_chasseur, date_signature);

-- Q2 (ventes rémunérées sur 12 mois, critère S3) : accès par chasseur puis par date de calcul
CREATE INDEX IF NOT EXISTS ix_remuneration_chasseur_date ON remuneration_chasseur (id_chasseur, date_calcul);

-- Q3 (matching : annonces actives d'une zone, d'un type, dans un budget)
CREATE INDEX IF NOT EXISTS ix_bien_zone_type ON bien (id_zone, type_bien);
-- index PARTIEL : seules les annonces actives sont candidates au matching (ENF-26, préférence aux index partiels)
CREATE INDEX IF NOT EXISTS ix_annonce_active_bien_prix ON annonce (id_bien, prix) WHERE statut = 'active';

-- Q4 (D10 : rendez-vous d'un mandat) et Q1 (état du mandat via la chaîne proposition -> offre -> compromis)
CREATE INDEX IF NOT EXISTS ix_proposition_mandat ON proposition (id_mandat);
CREATE INDEX IF NOT EXISTS ix_visite_proposition_date ON visite (id_proposition, date_visite) WHERE realisee;
CREATE INDEX IF NOT EXISTS ix_offre_proposition ON offre_acquisition (id_proposition);
CREATE INDEX IF NOT EXISTS ix_compromis_offre ON compromis (id_offre);

ANALYZE;
