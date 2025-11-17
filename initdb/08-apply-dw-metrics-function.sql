-- ==============================================================
-- InsightPix DB - DW Metrics Upsert Function
-- Version    : 1.0
-- Author     : Luis Adrian Gonzalez Benavides
-- Description:
--   Applies incremental vote deltas into the data-warehouse-level
--   category_metrics_periodic table. Supports all dimensional cuts:
--   year, semester, quarter, trimester, month, week_of_year,
--   week_of_month, day, day_of_week, day_period, and hour.
--
--   The function implements an UPSERT strategy:
--     1. Attempt UPDATE on an existing grain.
--     2. If no row matches exactly (IS NOT DISTINCT FROM semantics),
--        INSERT a new dimensional row.
--
-- Notes:
--   - Called exclusively by the periodic fan-out trigger.
--   - Uses NULL-matching operators (IS NOT DISTINCT FROM) to guarantee
--     that NULL dimensional levels behave as equal during UPDATE checks.
--   - Score formula matches image-level semantics: (pos - neg)/total * 100.
-- ==============================================================

SET search_path TO insightpix;

CREATE OR REPLACE FUNCTION apply_dw_metrics(
    p_cat_id INT,
    p_vote_count SMALLINT,
    p_pos INT,
    p_neg INT,
    p_ts TIMESTAMP,
    p_year INT,
    p_semester SMALLINT DEFAULT NULL,
    p_quarter SMALLINT DEFAULT NULL,
    p_trimester SMALLINT DEFAULT NULL,
    p_month SMALLINT DEFAULT NULL,
    p_week_year SMALLINT DEFAULT NULL,
    p_week_month SMALLINT DEFAULT NULL,
    p_day SMALLINT DEFAULT NULL,
    p_dow SMALLINT DEFAULT NULL,
    p_day_period VARCHAR(10) DEFAULT NULL,
    p_hour SMALLINT DEFAULT NULL
) RETURNS VOID
    LANGUAGE plpgsql
AS
$$
BEGIN
    -- 1) UPDATE if exists
    UPDATE category_metrics_periodic cm
    SET total_votes    = cm.total_votes + p_vote_count,
        positive_votes = cm.positive_votes + p_pos,
        negative_votes = cm.negative_votes + p_neg,
        score          = CASE
                             WHEN (cm.total_votes + p_vote_count) = 0 THEN NULL
                             ELSE ROUND(((cm.positive_votes + p_pos
                                 - (cm.negative_votes + p_neg))::numeric
                                 / (cm.total_votes + p_vote_count)) * 100, 2)
            END,
        updated_at     = p_ts
    WHERE cm.category_id = p_cat_id
      AND cm.year = p_year
      AND cm.semester IS NOT DISTINCT FROM p_semester
      AND cm.quarter IS NOT DISTINCT FROM p_quarter
      AND cm.trimester IS NOT DISTINCT FROM p_trimester
      AND cm.month IS NOT DISTINCT FROM p_month
      AND cm.week_of_year IS NOT DISTINCT FROM p_week_year
      AND cm.week_of_month IS NOT DISTINCT FROM p_week_month
      AND cm.day IS NOT DISTINCT FROM p_day
      AND cm.day_of_week IS NOT DISTINCT FROM p_dow
      AND cm.day_period IS NOT DISTINCT FROM p_day_period
      AND cm.hour IS NOT DISTINCT FROM p_hour;

    IF FOUND THEN
        RETURN;
    END IF;

    -- 2) INSERT if not exists
    INSERT INTO category_metrics_periodic(category_id, year, semester, quarter, trimester, month,
                                                     week_of_year, week_of_month, day, day_of_week, day_period, hour,
                                                     total_votes, positive_votes, negative_votes, score, updated_at)
    VALUES (p_cat_id, p_year, p_semester, p_quarter, p_trimester, p_month,
            p_week_year, p_week_month, p_day, p_dow, p_day_period, p_hour,
            p_vote_count, p_pos, p_neg,
            CASE
                WHEN p_vote_count = 0 THEN NULL
                ELSE ROUND(((p_pos - p_neg)::numeric / p_vote_count) * 100, 2)
                END,
            p_ts);
END;
$$;
