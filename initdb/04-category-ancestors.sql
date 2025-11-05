-- =====================================================================
-- InsightPix DB  - Category Ancestor Resolver
-- Version     : 1.0
-- Function    : get_category_ancestors(cat_id INT)
--
-- Parameter   :
--   cat_id INT  - The category ID from which the ancestor traversal begins
--
-- Purpose     :
--   Returns the full ancestor chain for the given category, including
--   the category itself. This is used for hierarchical metric propagation
--   and other category tree computations.
--
-- Author      : Luis Adrian Gonzalez Benavides
--
-- Details     :
--   - Traverses the category hierarchy upwards until reaching the root
--   - Optimized to avoid reprocessing already-visited categories
--
-- Notes       :
--   - The starting category ID is included in the result
--   - Returns only category IDs; join with categories for names or details
--
-- Usage       :
--   SELECT * FROM get_category_ancestors(10);
-- =====================================================================

SET search_path TO insightpix;

CREATE OR REPLACE FUNCTION get_category_ancestors(cat_id INT)
RETURNS TABLE(id INT) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE up(id, frontier) AS (
        -- anchor
        SELECT cat_id, TRUE
        UNION ALL
        -- expand only frontier rows
        SELECT c.parent_id, TRUE
        FROM categories c
        JOIN up u ON c.id = u.id
        WHERE u.frontier = TRUE
          AND c.parent_id IS NOT NULL
        UNION ALL
        -- mark processed
        SELECT id, FALSE
        FROM up
        WHERE frontier = TRUE
    )
    SELECT DISTINCT id FROM up;
END;
$$ LANGUAGE plpgsql STABLE;
