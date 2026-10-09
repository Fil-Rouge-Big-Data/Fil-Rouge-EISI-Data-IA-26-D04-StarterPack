-- ============================================================
-- 40_validate.sql — Contrôles post-migration BLOQUANTS (M3/ADR-050).
-- Chaque contrôle lève une EXCEPTION si une anomalie est trouvée. Lancé avec
-- psql -v ON_ERROR_STOP=1, le pipeline s'arrête net au premier contrôle rouge.
-- Garantie côté EXÉCUTION (même sans Python). Doublon volontaire avec la
-- validation Python du pipeline (garantie côté pipeline) — mêmes requêtes.
-- ============================================================
DO $$
DECLARE n integer;
BEGIN
    -- C1 : acquéreur orphelin
    SELECT count(*) INTO n FROM demande_acquereur da
      LEFT JOIN client c ON c.id_utilisateur=da.id_client WHERE c.id_utilisateur IS NULL;
    IF n>0 THEN RAISE EXCEPTION 'C1 : % acquereur(s) sans client', n; END IF;

    -- C2 : mandat sans chasseur
    SELECT count(*) INTO n FROM mandat m
      LEFT JOIN chasseur ch ON ch.id_utilisateur=m.id_chasseur WHERE ch.id_utilisateur IS NULL;
    IF n>0 THEN RAISE EXCEPTION 'C2 : % mandat(s) sans chasseur', n; END IF;

    -- C3 : résiliation = date + type ensemble
    SELECT count(*) INTO n FROM mandat
      WHERE (date_resiliation IS NULL) <> (type_resiliation IS NULL);
    IF n>0 THEN RAISE EXCEPTION 'C3 : % resiliation(s) incoherente(s)', n; END IF;

    -- C4 : signataire = acquéreur de la demande
    SELECT count(*) INTO n FROM mandat m
      LEFT JOIN demande_acquereur da ON da.id_demande=m.id_demande AND da.id_client=m.id_signataire
      WHERE da.id_demande IS NULL;
    IF n>0 THEN RAISE EXCEPTION 'C4 : % signataire(s) non acquereur', n; END IF;

    -- C8 : zéro déperdition (texte source conservé)
    SELECT count(*) INTO n FROM demande_version
      WHERE commentaire_criteres IS NULL OR commentaire_criteres='';
    IF n>0 THEN RAISE EXCEPTION 'C8 : % version(s) sans texte source', n; END IF;

    RAISE NOTICE 'Validation OK : tous les controles bloquants passent.';
END $$;
