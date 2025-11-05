-- =====================================================================
-- Data Mart: Category Metrics Periodic (Fan-out Incremental Loader)
-- Version     : 1.0
-- Author      : Luis Adrian Gonzalez Benavides
--
-- Purpose:
--   Incrementally populate category_metrics_periodic for all time
--   granularities whenever a vote is inserted or deleted.
--
-- Behavior:
--   - Uses voted_at to place metrics in the correct time bucket
--   - Propagates metrics to category and all ancestors (fan-out)
--   - INSERT adds +1/-1/+/- to metrics; DELETE reverts using old row
--   - Ensures one row per category per granular bucket
--
-- Granularities Generated:
--   year, semester, quarter, trimester, month,
--   week_of_year, week_of_month, day, day_of_week, day_period, hour
--
-- Dependencies:
--   - get_category_ancestors(category_id)  returns all ancestor category IDs (including self)
--
-- =====================================================================

SET search_path TO insightpix,public;


-- ---------------------------------------------------------------------
-- FUNCTION: update_category_metrics_periodic_fanout()
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_category_metrics_periodic_fanout()
    RETURNS TRIGGER AS
$$
DECLARE
    cat_id       INT;
    v_vote_value SMALLINT;
    v_vote_count SMALLINT;
    v_ts         TIMESTAMP;

    -- Breakdown of timestamp into dimensions
    year         INT;
    semester     SMALLINT;
    quarter      SMALLINT;
    trimester    SMALLINT;
    month        SMALLINT;
    week_year    SMALLINT;
    week_month   SMALLINT;
    day          SMALLINT;
    dow          SMALLINT;
    hour         SMALLINT;
    day_period   VARCHAR(10);
    pos          INT;
    neg          INT;
BEGIN
    --------------------------------------------------------------------
    -- Determine operation context
    --------------------------------------------------------------------
    IF TG_OP = 'INSERT' THEN
        v_vote_value := NEW.value;
        v_ts := NEW.voted_at;
        cat_id := (SELECT category_id FROM images WHERE id = NEW.image_id);
        v_vote_count := 1;
    ELSIF TG_OP = 'DELETE' THEN
        v_vote_count := -1;
        v_vote_value := -1 * OLD.value; -- invert contribution on delete
        v_ts := OLD.voted_at;
        cat_id := (SELECT category_id FROM images WHERE id = OLD.image_id);
    ELSE
        RAISE EXCEPTION 'Unsupported op % in update_category_metrics_periodic_fanout()', TG_OP;
    END IF;

    pos := (v_vote_value = 1)::INT;
    neg := (v_vote_value = -1)::INT;

    IF cat_id IS NULL THEN
        RETURN NULL; -- Images without category do not participate
    END IF;

    --------------------------------------------------------------------
    -- Extract date/time dimensions
    --------------------------------------------------------------------
    year := EXTRACT(YEAR FROM v_ts);
    month := EXTRACT(MONTH FROM v_ts);
    day := EXTRACT(DAY FROM v_ts);
    dow := EXTRACT(ISODOW FROM v_ts); -- 1=Mon .. 7=Sun
    hour := EXTRACT(HOUR FROM v_ts);
    quarter := CEIL(month / 3.0);
    trimester := CEIL(month / 4.0);
    semester := CEIL(month / 6.0);
    week_year := EXTRACT(WEEK FROM v_ts);

    -- week_of_month = week_of_year - week_of_year(first day of month) + 1
    week_month := week_year - EXTRACT(WEEK FROM date_trunc('month', v_ts)) + 1;

    IF hour BETWEEN 6 AND 11 THEN
        day_period := 'morning';
    ELSIF hour BETWEEN 12 AND 19 THEN
        day_period := 'afternoon';
    ELSE
        day_period := 'night';
    END IF;

    --------------------------------------------------------------------
    -- Fan-out: update for category and all ancestors
    --------------------------------------------------------------------
    FOR cat_id IN
        SELECT id FROM get_category_ancestors(cat_id)
        LOOP
        ----------------------------------------------------------------
        -- For each granularity generate an UPSERT
        ----------------------------------------------------------------
            INSERT INTO category_metrics_periodic(category_id, year, semester, quarter, trimester, month, week_of_year,
                                                  week_of_month, day, day_of_week, hour, day_period, total_votes,
                                                  positive_votes, negative_votes)
            VALUES (cat_id, year, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, pos, neg),
                   (cat_id, year, semester, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, pos, neg),
                   (cat_id, year, NULL, quarter, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, pos, neg),
                   (cat_id, year, NULL, NULL, trimester, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, pos, neg),
                   (cat_id, year, NULL, NULL, NULL, month, NULL, NULL, NULL, NULL, NULL, NULL, 1, pos, neg),
                   (cat_id, year, NULL, NULL, NULL, NULL, week_year, NULL, NULL, NULL, NULL, NULL, 1, pos, neg),
                   (cat_id, year, NULL, NULL, NULL, month, NULL, week_month, NULL, NULL, NULL, NULL, 1, pos, neg),
                   (cat_id, year, NULL, NULL, NULL, month, NULL, NULL, day, NULL, NULL, NULL, 1, pos, neg),
                   (cat_id, year, NULL, NULL, NULL, NULL, NULL, NULL, day, NULL, NULL, NULL, 1, pos, neg),
                   (cat_id, year, NULL, NULL, NULL, NULL, NULL, NULL, NULL, dow, NULL, NULL, 1, pos, neg),
                   (cat_id, year, NULL, NULL, NULL, month, NULL, NULL, NULL, dow, NULL, NULL, 1, pos, neg),
                   (cat_id, year, NULL, NULL, NULL, month, NULL, NULL, NULL, NULL, day_period, NULL, 1, pos, neg),
                   (cat_id, year, NULL, NULL, NULL, month, NULL, NULL, day, NULL, day_period, NULL, 1, pos, neg),
                   (cat_id, year, NULL, NULL, NULL, NULL, NULL, NULL, NULL, dow, day_period, NULL, 1, pos, neg),
                   (cat_id, year, NULL, NULL, NULL, month, NULL, NULL, NULL, dow, day_period, NULL, 1, pos, neg),
                   (cat_id, year, NULL, NULL, NULL, month, NULL, NULL, NULL, NULL, NULL, hour, 1, pos, neg),
                   (cat_id, year, NULL, NULL, NULL, NULL, week_year, NULL, NULL, NULL, NULL, hour, 1, pos, neg),
                   (cat_id, year, NULL, NULL, NULL, month, NULL, NULL, day, NULL, NULL, hour, 1, pos, neg),
                   (cat_id, year, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, hour, 1, pos, neg)
            ON CONFLICT
                DO UPDATE SET total_votes    = category_metrics_periodic.total_votes + v_vote_count,
                              positive_votes = category_metrics_periodic.positive_votes + EXCLUDED.positive_votes,
                              negative_votes = category_metrics_periodic.negative_votes + EXCLUDED.negative_votes,
                              score          = ROUND(
                                          ((category_metrics_periodic.positive_votes + EXCLUDED.positive_votes -
                                            category_metrics_periodic.negative_votes +
                                            EXCLUDED.negative_votes)::numeric /
                                           NULLIF(category_metrics_periodic.total_votes + EXCLUDED.total_votes, 0)) *
                                          100,
                                          2),
                              updated_at     = CURRENT_TIMESTAMP;


        END LOOP;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------
-- TRIGGER
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_category_metrics_periodic_fanout ON votes;

CREATE TRIGGER trg_category_metrics_periodic_fanout
    AFTER INSERT OR DELETE
    ON votes
    FOR EACH ROW
EXECUTE FUNCTION update_category_metrics_periodic_fanout();
