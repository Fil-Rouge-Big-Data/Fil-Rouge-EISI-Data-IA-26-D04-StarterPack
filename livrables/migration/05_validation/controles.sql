-- =========================================================================
-- 05_validation/controles.sql
-- Validation d'intégrité exécutée dans le schéma fil_rouge_cible
-- =========================================================================

SET search_path TO fil_rouge_cible;

-- 1. Vérification de l'éclatement des utilisateurs (Héritage PERSONNE)
SELECT 
    (SELECT COUNT(*) FROM personne) AS total_personnes,
    (SELECT COUNT(*) FROM client) AS nb_clients,
    (SELECT COUNT(*) FROM chasseur) AS nb_chasseurs;

-- 2. Contrôle du parsing des critères (DEMANDE_VERSION)
SELECT id_version, type_bien, budget_max, surface_min 
FROM demande_version 
WHERE budget_max IS NOT NULL;

-- 3. Vérification du nettoyage des mandats expirés (A01)
SELECT statut, COUNT(*) AS total
FROM mandat 
GROUP BY statut;

-- 4. Contrôle d'absence d'orphelins sur la relation MANDAT -> CLIENT
SELECT m.id_mandat, d.id_client 
FROM mandat m
JOIN demande d ON m.id_demande = d.id_demande
LEFT JOIN client c ON d.id_client = c.id_personne
WHERE c.id_personne IS NULL;