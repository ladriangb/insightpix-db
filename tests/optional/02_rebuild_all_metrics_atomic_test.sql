-- ===============================================================
-- pgTAP Tests - InsightPix Core Schema
-- Version : 1.0
-- Author  : Luis Adrian Gonzalez Benavides
--
-- Module      : rebuild_all_metrics_atomic()
--
-- Description :
--   Validates that rebuild_all_metrics_atomic() produces the exact same
--   results as incremental trigger-based metric calculations.
--
-- Flow:
--   1. Insert data and let triggers compute metrics
--   2. Snapshot metrics into temp tables
--   3. Corrupt metrics
--   4. Run rebuild_all_metrics_atomic()
--   5. Compare post-rebuild metrics with original snapshot
--
-- Notes:
--   - Uses pgTAP
--   - Runs inside a transaction and rolls back
--   - Uses negative IDs to avoid collisions
-- ===============================================================

SET search_path TO insightpix, public;

BEGIN;

SELECT plan(8);

---------------------------------------------------------------
-- SETUP
---------------------------------------------------------------
INSERT INTO categories (id, name, parent_id)
VALUES (-10, 'Root', NULL),
       (-20, 'A', -10),
       (-30, 'A1', -20),
       (-40, 'A2', -20);

INSERT INTO users (id, username, email)
VALUES
(-301, 'u1', 'u1@test.com'),
(-302, 'u2', 'u2@test.com'),
(-303, 'u3', 'u3@test.com');

INSERT INTO images (id, user_id, category_id, url)
VALUES
(-3001, -301, -30, 'img_a1.jpg'),
(-3002, -302, -40, 'img_a2.jpg');

-- Votes
INSERT INTO votes (image_id, user_id, value) VALUES
(-3001, -301, 1),
(-3001, -302, 1),
(-3001, -303, -1),
(-3002, -301, -1),
(-3002, -302, -1);

---------------------------------------------------------------
-- SNAPSHOT PRE-REBUILD METRICS
---------------------------------------------------------------
CREATE TEMP TABLE tmp_pre_img_metrics AS
SELECT * FROM metrics ORDER BY image_id;

CREATE TEMP TABLE tmp_pre_cat_metrics AS
SELECT * FROM category_metrics ORDER BY category_id;

SELECT is(
    (SELECT COUNT(*) FROM tmp_pre_img_metrics) > 0,
    true,
    'Snapshot captured for image metrics'
);

SELECT is(
    (SELECT COUNT(*) FROM tmp_pre_cat_metrics) > 0,
    true,
    'Snapshot captured for category metrics'
);

---------------------------------------------------------------
-- CORRUPT METRICS
---------------------------------------------------------------
UPDATE metrics SET total_votes = 999, positive_votes = 999, negative_votes = 999;
UPDATE category_metrics SET total_votes = 999, positive_votes = 999, negative_votes = 999;

---------------------------------------------------------------
-- RUN REBUILD
---------------------------------------------------------------
SELECT rebuild_all_metrics_atomic();

---------------------------------------------------------------
-- COMPARE IMAGE METRICS POST-REBUILD vs SNAPSHOT
---------------------------------------------------------------
-- two-way EXCEPT must return zero rows for a perfect match
SELECT is(
    (SELECT COUNT(*) FROM (
        SELECT * FROM metrics
        EXCEPT
        SELECT * FROM tmp_pre_img_metrics
    ) AS diff)::int,
    0,
    'Image metrics: no differences after rebuild'
);

SELECT is(
    (SELECT COUNT(*) FROM (
        SELECT * FROM tmp_pre_img_metrics
        EXCEPT
        SELECT * FROM metrics
    ) AS diff)::int,
    0,
    'Image metrics: full match trigger vs rebuild'
);

---------------------------------------------------------------
-- COMPARE CATEGORY METRICS POST-REBUILD vs SNAPSHOT
---------------------------------------------------------------
SELECT is(
    (SELECT COUNT(*) FROM (
        SELECT * FROM category_metrics
        EXCEPT
        SELECT * FROM tmp_pre_cat_metrics
    ) AS diff)::int,
    0,
    'Category metrics: no differences after rebuild'
);

SELECT is(
    (SELECT COUNT(*) FROM (
        SELECT * FROM tmp_pre_cat_metrics
        EXCEPT
        SELECT * FROM category_metrics
    ) AS diff)::int,
    0,
    'Category metrics: full match trigger vs rebuild'
);

---------------------------------------------------------------
-- SANITY CHECK: ensure corrupted values are gone
---------------------------------------------------------------
SELECT is(
    (SELECT COUNT(*) FROM metrics WHERE total_votes = 999)::int,
    0,
    'No corrupted image metrics remain'
);

SELECT is(
    (SELECT COUNT(*) FROM category_metrics WHERE total_votes = 999)::int,
    0,
    'No corrupted category metrics remain'
);

---------------------------------------------------------------
-- FINISH
---------------------------------------------------------------
SELECT * FROM finish();
ROLLBACK;
