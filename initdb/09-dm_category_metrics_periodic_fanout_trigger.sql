-- ==============================================================
-- InsightPix DB - Category Metrics Periodic Fan-Out Trigger
-- Version    : 1.0
-- Author     : Luis Adrian Gonzalez Benavides
-- Description:
--   Propagates each vote event (INSERT/DELETE on votes) to all
--   hierarchical category ancestors, computing deltas and applying
--   them across all dimensional combinations via apply_dw_metrics().
--
--   Dimensions generated per vote:
--     - Year, Semester, Quarter, Trimester
--     - Month, Week of Year, Week of Month
--     - Day, Day of Week, Day Period (morning/afternoon/night)
--     - Hour
--
--   The trigger performs:
--     1. Delta calculation based on TG_OP (INSERT or DELETE).
--     2. Category lookup through images table.
--     3. Dimensional extraction (time grain derivation).
--     4. Fan-out to all ancestors returned by get_category_ancestors().
--     5. Execution of 19 apply_dw_metrics() calls per ancestor,
--        covering all supported dimensional grains.
--
-- Notes:
--   - Ensures DW aggregation stays fully incremental.
--   - Maintains strict consistency with compute_vote_delta logic
--     by manually deriving ±1 deltas per operation.
-- ==============================================================

SET search_path TO insightpix;

CREATE OR REPLACE FUNCTION update_category_metrics_periodic_fanout()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_ts   TIMESTAMP;
    v_cat  INT;
    d_tot  SMALLINT;
    d_pos  INT;
    d_neg  INT;
    anc_id INT;

    -- Dimensions
    y      INT; sem SMALLINT; qtr SMALLINT; tri SMALLINT; mon SMALLINT;
    wy     SMALLINT; wm SMALLINT; dd SMALLINT; dow SMALLINT; hr SMALLINT; dp VARCHAR(10);
BEGIN
    -- Determine deltas
    IF TG_OP = 'INSERT' THEN
        v_ts := NEW.voted_at;
        v_cat := (SELECT category_id FROM images WHERE id = NEW.image_id);
        d_tot := 1;
        d_pos := (NEW.value = 1)::INT;
        d_neg := (NEW.value = -1)::INT;

    ELSIF TG_OP = 'DELETE' THEN
        v_ts := OLD.voted_at;
        v_cat := (SELECT category_id FROM images WHERE id = OLD.image_id);
        d_tot := -1;
        d_pos := - (OLD.value = 1)::INT;
        d_neg := - (OLD.value = -1)::INT;

    ELSE
        RAISE EXCEPTION 'Unsupported TG_OP: %', TG_OP;
    END IF;

    IF v_cat IS NULL THEN
        RETURN NULL;
    END IF;

    -- Extract time dimensions
    y := EXTRACT(YEAR FROM v_ts);
    mon := EXTRACT(MONTH FROM v_ts);
    dd := EXTRACT(DAY FROM v_ts);
    dow := EXTRACT(ISODOW FROM v_ts);
    hr := EXTRACT(HOUR FROM v_ts);
    qtr := CEIL(mon / 3.0);
    tri := CEIL(mon / 4.0);
    sem := CEIL(mon / 6.0);
    wy := EXTRACT(WEEK FROM v_ts);
    wm := wy - EXTRACT(WEEK FROM date_trunc('month', v_ts)) + 1;

    IF hr BETWEEN 6 AND 11 THEN
        dp := 'morning';
    ELSIF hr BETWEEN 12 AND 19 THEN
        dp := 'afternoon';
    ELSE
        dp := 'night';
    END IF;

    -- Fan-out to ancestors
    FOR anc_id IN SELECT id FROM get_category_ancestors(v_cat)
        LOOP
            -- 01: YEAR
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL,
                                     NULL,
                                     NULL
                );
            -- 02: YEAR + SEMESTER
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     sem, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL,
                                     NULL,
                                     NULL
                );

            -- 03: YEAR + QUARTER
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, qtr, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL,
                                     NULL,
                                     NULL
                );
            -- 04: YEAR + TRIMESTER
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, tri,
                                     NULL, NULL, NULL,
                                     NULL, NULL,
                                     NULL,
                                     NULL
                );
            -- 05: YEAR + MONTH
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     mon, NULL, NULL,
                                     NULL, NULL,
                                     NULL,
                                     NULL
                );
            -- 06: YEAR + WEEK_OF_YEAR
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     NULL, wy, NULL,
                                     NULL, NULL,
                                     NULL,
                                     NULL
                );
            -- 07: YEAR + MONTH + WEEK_OF_MONTH
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     mon, NULL, wm,
                                     NULL, NULL,
                                     NULL,
                                     NULL
                );
            -- 08: YEAR + MONTH + DAY
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     mon, NULL, NULL,
                                     dd, NULL,
                                     NULL,
                                     NULL
                );
            -- 09: YEAR + DAY  (sin month)
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     dd, NULL,
                                     NULL,
                                     NULL
                );
            -- 10: YEAR + DAY_OF_WEEK
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, dow,
                                     NULL,
                                     NULL
                );
            -- 11: YEAR + MONTH + DAY_OF_WEEK
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     mon, NULL, NULL,
                                     NULL, dow,
                                     NULL,
                                     NULL
                );
            -- 12: YEAR + MONTH + DAY_PERIOD
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     mon, NULL, NULL,
                                     NULL, NULL,
                                     dp,
                                     NULL
                );
            -- 13: YEAR + MONTH + DAY + DAY_PERIOD
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     mon, NULL, NULL,
                                     dd, NULL,
                                     dp,
                                     NULL
                );
            -- 14: YEAR + DAY_OF_WEEK + DAY_PERIOD
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, dow,
                                     dp,
                                     NULL
                );
            -- 15: YEAR + MONTH + DAY_OF_WEEK + DAY_PERIOD
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     mon, NULL, NULL,
                                     NULL, dow,
                                     dp,
                                     NULL
                );
            -- 16: YEAR + MONTH + HOUR
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     mon, NULL, NULL,
                                     NULL, NULL,
                                     NULL,
                                     hr
                );
            -- 17: YEAR + WEEK_OF_YEAR + HOUR
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     NULL, wy, NULL,
                                     NULL, NULL,
                                     NULL,
                                     hr
                );
            -- 18: YEAR + MONTH + DAY + HOUR
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     mon, NULL, NULL,
                                     dd, NULL,
                                     NULL,
                                     hr
                );
            -- 19: YEAR + HOUR
            PERFORM apply_dw_metrics(anc_id, d_tot, d_pos, d_neg, v_ts, y,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL,
                                     NULL,
                                     hr
                );

        END LOOP;

    RETURN NULL;
END;
$$;
-- =====================================================================

DROP TRIGGER IF EXISTS trg_category_metrics_periodic_fanout ON votes;

CREATE TRIGGER trg_category_metrics_periodic_fanout
    AFTER INSERT OR DELETE
    ON votes
    FOR EACH ROW
EXECUTE FUNCTION update_category_metrics_periodic_fanout();
