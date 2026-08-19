-- =========================================================================
-- 05_validation/controles.sql
-- Contrôles de reprise, exécutés dans le schéma cible fil_rouge_cible.
-- Date de référence du projet : 25/07/2026 — jamais CURRENT_DATE.
-- Lecture seule : le script ne modifie rien et se rejoue à volonté.
-- =========================================================================

SET search_path TO fil_rouge_cible;
BEGIN READ ONLY;

WITH controles (libelle, obtenu, attendu) AS (VALUES
  ('personnes reprises',
     (SELECT COUNT(*) FROM personne),
     (SELECT COUNT(*) FROM "Fil_Rouge_Depart".utilisateurs)),
  ('scission client + chasseur sans perte (A02)',
     (SELECT COUNT(*) FROM client) + (SELECT COUNT(*) FROM chasseur),
     (SELECT COUNT(*) FROM "Fil_Rouge_Depart".utilisateurs)),
  ('mandats repris',
     (SELECT COUNT(*) FROM mandat),
     (SELECT COUNT(*) FROM "Fil_Rouge_Depart".mandats)),
  ('une version courante par demande (A10c)',
     (SELECT COUNT(*) FROM demande_version WHERE est_courante),
     (SELECT COUNT(*) FROM demande)),
  ('date_fin = signature + 6 mois (A04)',
     (SELECT COUNT(*) FROM mandat WHERE date_fin = (date_signature + INTERVAL '6 months')::date),
     (SELECT COUNT(*) FROM mandat)),
  ('statut « expire » non repris (A01)',
     (SELECT COUNT(*) FROM mandat WHERE statut = 'actif'), 13),
  ('mandats périmés au 25/07/2026, expiration calculée (A01)',
     (SELECT COUNT(*) FROM mandat
       WHERE date_fin < DATE '2026-07-25' AND statut IN ('actif', 'suspendu')), 9),
  ('aucun chasseur en position de client (A06)',
     (SELECT COUNT(*) FROM demande d JOIN chasseur c ON d.id_client = c.id_personne), 0),
  ('texte source conservé intégralement (A03)',
     (SELECT COUNT(*) FROM demande_version WHERE criteres_bruts IS NOT NULL),
     (SELECT COUNT(*) FROM "Fil_Rouge_Depart".mandats WHERE description_recherche IS NOT NULL)),
  ('aucune version sans critère structuré (A03)',
     (SELECT COUNT(*) FROM demande_version
       WHERE type_bien IS NULL AND budget_max IS NULL AND surface_min IS NULL
         AND nb_pieces_min IS NULL AND nb_chambres_min IS NULL), 0),
  ('taux de commission repris en barèmes (A08)',
     (SELECT COUNT(*) FROM tranche_bareme),
     (SELECT COUNT(*) FROM "Fil_Rouge_Depart".utilisateurs WHERE taux_commission IS NOT NULL)),
  ('secteurs multiples repris du texte libre (A03)',
     (SELECT COUNT(*) FROM demande_secteur WHERE id_version = 8), 2))
SELECT libelle, obtenu, attendu,
       CASE WHEN obtenu = attendu THEN 'OK' ELSE 'KO' END AS verdict
FROM controles;

ROLLBACK;