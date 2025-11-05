-- ==============================================================
-- InsightPix DB - Core Schema Definition
-- Version: 1.0
-- Author: Luis Adrian Gonzalez Benavides
-- Description:
--   Maintains real-time aggregated voting metrics for images.
--   Applies incremental updates on INSERT/DELETE to avoid full table scans.
--   Updates positive/negative/total counts, recalculates score, and refreshes updated_at.
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
    IF TG_OP = 'INSERT' THEN
        delta_pos := CASE WHEN NEW.value = 1 THEN 1 ELSE 0 END;
        delta_neg := CASE WHEN NEW.value = -1 THEN 1 ELSE 0 END;
        delta_total := 1;
    ELSIF TG_OP = 'DELETE' THEN
        delta_pos := CASE WHEN OLD.value = 1 THEN -1 ELSE 0 END;
        delta_neg := CASE WHEN OLD.value = -1 THEN -1 ELSE 0 END;
        delta_total := -1;
    ELSE
        RETURN NULL;
    END IF;

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

    RETURN CASE WHEN TG_OP = 'INSERT' THEN NEW ELSE OLD END;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_image_metrics ON votes;

CREATE TRIGGER trg_update_image_metrics
    AFTER INSERT OR DELETE
    ON votes
    FOR EACH ROW
EXECUTE FUNCTION update_image_metrics();
