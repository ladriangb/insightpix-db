-- ==============================================================
-- InsightPix DB - Hierarchical Category Metrics Propagation
-- Version    : 1.0
-- Author     : Luis Adrian Gonzalez Benavides
--
-- Description:
--   Updates category-level voting metrics using hierarchical
--   propagation. When a vote is added or removed from an image,
--   metrics are incrementally applied to the image's category
--   AND to all of its ancestor categories.
--
--   Designed to run after vote events (INSERT/DELETE) to maintain
--   real-time aggregate metrics across the category tree.
--
-- Notes:
--   - Uses get_category_ancestors() to resolve the full path.
--   - Performs incremental updates to avoid full recalculation.
--
-- Usage:
--   Trigger-based, not called manually.
-- ==============================================================



SET search_path TO insightpix;

-- Idempotent safety
DROP FUNCTION IF EXISTS apply_category_metrics_delta(INT, INT, INT, INT) CASCADE;
DROP FUNCTION IF EXISTS update_category_metrics_on_vote() CASCADE;
DROP TRIGGER IF EXISTS trg_update_category_metrics ON votes;

-- Core delta applier: updates the image category and all ancestors
CREATE OR REPLACE FUNCTION apply_category_metrics_delta(
    _image_id INT,
    _delta_pos INT,
    _delta_neg INT,
    _delta_total INT
) RETURNS VOID AS
$$
DECLARE
    _cat_id INT;
    _cur_id INT;
BEGIN
    SELECT category_id
    INTO _cat_id
    FROM images
    WHERE id = _image_id;

    -- If the image has no category, nothing to propagate.
    IF _cat_id IS NULL THEN
        RETURN;
    END IF;

    -- Traverse upwards: current category + all ancestors
    FOR _cur_id IN
        SELECT id FROM get_category_ancestors(_cat_id)
        LOOP
            -- Ensure the category_metrics row exists
            INSERT INTO category_metrics (category_id)
            VALUES (_cur_id)
            ON CONFLICT (category_id) DO NOTHING;

            -- Apply delta and recompute score from the new state
            UPDATE category_metrics cm
            SET positive_votes = cm.positive_votes + _delta_pos,
                negative_votes = cm.negative_votes + _delta_neg,
                total_votes    = cm.total_votes + _delta_total,
                score          = CASE
                                     WHEN (cm.total_votes + _delta_total) <= 0 THEN 0
                                     ELSE ROUND(
                                                 (
                                                         ((cm.positive_votes + _delta_pos) - (cm.negative_votes + _delta_neg))::DECIMAL
                                                         / NULLIF(cm.total_votes + _delta_total, 0)
                                                     ) * 100, 2
                                         )
                    END,
                updated_at     = CURRENT_TIMESTAMP
            WHERE cm.category_id = _cur_id;
        END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Trigger function that derives deltas from vote events and calls the applier
CREATE OR REPLACE FUNCTION update_category_metrics_on_vote()
    RETURNS TRIGGER AS
$$
DECLARE
    delta_pos   INT := 0;
    delta_neg   INT := 0;
    delta_total INT := 0;
BEGIN

    SELECT d_pos, d_neg, d_tot
        INTO delta_pos, delta_neg, delta_total
        FROM compute_vote_delta(TG_OP, COALESCE(NEW.value, OLD.value));

    PERFORM apply_category_metrics_delta(
            COALESCE(NEW.image_id, OLD.image_id),
            delta_pos,
            delta_neg,
            delta_total
        );

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Single trigger for both events (AFTER INSERT OR DELETE on votes)
CREATE TRIGGER trg_update_category_metrics
    AFTER INSERT OR DELETE
    ON votes
    FOR EACH ROW
EXECUTE FUNCTION update_category_metrics_on_vote();
