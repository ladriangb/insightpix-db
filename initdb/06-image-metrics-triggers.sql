-- ==============================================================
-- InsightPix DB - Image Metrics Update Trigger
-- Version    : 1.0
-- Author     : Luis Adrian Gonzalez Benavides
-- Description:
--   Maintains real-time aggregated voting metrics for images.
--   Applies incremental updates on INSERT/DELETE to avoid full rescans.
--   Updates positive, negative, and total vote counts; recalculates score;
--   and refreshes updated_at timestamp.
--
-- Notes:
--   - Trigger-level logic: runs AFTER INSERT or DELETE on votes.
--   - Delegates delta calculation to compute_vote_delta() for consistency.
-- ==============================================================

SET search_path TO insightpix;

CREATE OR REPLACE FUNCTION update_image_metrics()
    RETURNS TRIGGER AS
$$
DECLARE
    delta_pos   INT := 0;
    delta_neg   INT := 0;
    delta_total INT := 0;
    img_id      INT := COALESCE(NEW.image_id, OLD.image_id);
BEGIN
    -- Determine deltas
    SELECT d_pos, d_neg, d_tot
    INTO delta_pos, delta_neg, delta_total
    FROM compute_vote_delta(TG_OP, COALESCE(NEW.value, OLD.value));


    -- Ensure metrics row exists
    INSERT INTO metrics (image_id)
    VALUES (img_id)
    ON CONFLICT (image_id) DO NOTHING;

    -- Update with shared formula
    UPDATE metrics
    SET positive_votes = positive_votes + delta_pos,
        negative_votes = negative_votes + delta_neg,
        total_votes    = total_votes + delta_total,
        score          = CASE
                             WHEN (total_votes + delta_total) <= 0 THEN 0
                             ELSE ROUND(
                                         (
                                                 ((positive_votes + delta_pos) - (negative_votes + delta_neg))::decimal
                                                 /
                                                 NULLIF((total_votes + delta_total), 0)
                                             ) * 100,
                                         2
                                 )
            END,
        updated_at     = CURRENT_TIMESTAMP
    WHERE image_id = img_id;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_image_metrics ON votes;

CREATE TRIGGER trg_update_image_metrics
    AFTER INSERT OR DELETE
    ON votes
    FOR EACH ROW
EXECUTE FUNCTION update_image_metrics();
