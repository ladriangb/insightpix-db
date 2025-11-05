-- =====================================================================
-- InsightPix DB  - Full Metrics Rebuild (Atomic)
-- Version   : 1.0
-- Function  : rebuild_all_metrics_atomic()
--
-- Purpose   :
--   Rebuilds all aggregated metrics (image-level and category-level)
--   from scratch in a single atomic transaction. If any failure occurs,
--   the entire rebuild is rolled back, ensuring no partial state.
--
-- Behavior  :
--   - Clears metrics and category_metrics tables
--   - Recalculates image metrics from votes
--   - Recalculates hierarchical category metrics using ancestors
--   - Does NOT use triggers (set-based rebuild)
--   - Fully atomic: one transaction, no intermediate commits
--
-- Notes     :
--   - May take time on large datasets but guarantees consistency
--   - Safe to run while reads occur; writes to votes should be paused
--   - Score formula matches trigger logic for consistency
--
-- Usage     :
--   BEGIN;
--   SELECT rebuild_all_metrics_atomic();
--   COMMIT;
-- =====================================================================

SET search_path TO insightpix;

CREATE OR REPLACE FUNCTION rebuild_all_metrics_atomic()
    RETURNS VOID AS
$$
BEGIN
    --------------------------------------------------------------------
    -- Clear current aggregates
    --------------------------------------------------------------------
    TRUNCATE TABLE metrics;
    TRUNCATE TABLE category_metrics;

    --------------------------------------------------------------------
    -- Rebuild image-level metrics from votes
    --------------------------------------------------------------------
    INSERT INTO metrics (image_id, total_votes, positive_votes, negative_votes, score, updated_at)
    SELECT v.image_id,
           COUNT(*)::INT            AS total_votes,
           SUM((v.value = 1)::INT)  AS positive_votes,
           SUM((v.value = -1)::INT) AS negative_votes,
           CASE
               WHEN COUNT(*) = 0 THEN 0
               ELSE ROUND(
                           (
                                   (SUM((v.value = 1)::INT) - SUM((v.value = -1)::INT))::NUMERIC
                                   / NULLIF(COUNT(*), 0)
                               ) * 100, 2
                   )
               END                  AS score,
           CURRENT_TIMESTAMP        AS updated_at
    FROM votes v
    GROUP BY v.image_id;

    --------------------------------------------------------------------
    -- Rebuild hierarchical category metrics
    --------------------------------------------------------------------
    WITH img_totals AS (SELECT i.id                     AS image_id,
                               i.category_id            AS category_id,
                               COUNT(v.*)::INT          AS total_votes,
                               SUM((v.value = 1)::INT)  AS positive_votes,
                               SUM((v.value = -1)::INT) AS negative_votes
                        FROM images i
                                 JOIN votes v ON v.image_id = i.id
                        WHERE i.category_id IS NOT NULL
                        GROUP BY i.id, i.category_id),
         cat_paths AS (SELECT a.id AS category_id,
                              t.total_votes,
                              t.positive_votes,
                              t.negative_votes
                       FROM img_totals t
                                JOIN LATERAL get_category_ancestors(t.category_id) a ON TRUE)
    INSERT
    INTO category_metrics (category_id, total_votes, positive_votes, negative_votes, score, updated_at)
    SELECT category_id,
           SUM(total_votes)    AS total_votes,
           SUM(positive_votes) AS positive_votes,
           SUM(negative_votes) AS negative_votes,
           CASE
               WHEN SUM(total_votes) <= 0 THEN 0
               ELSE ROUND(
                           (
                                   (SUM(positive_votes) - SUM(negative_votes))::NUMERIC
                                   / NULLIF(SUM(total_votes), 0)
                               ) * 100, 2
                   )
               END             AS score,
           CURRENT_TIMESTAMP   AS updated_at
    FROM cat_paths
    GROUP BY category_id;

END;
$$ LANGUAGE plpgsql;
