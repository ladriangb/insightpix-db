-- ===============================================================
-- pgTAP Test - Data Mart: Category Metrics Periodic (Fan-out)
-- Smoke Test (Basic) - v1.2 (Aligned with trigger behavior)
-- Author : Luis Adrian Gonzalez Benavides
-- ===============================================================

SET search_path TO insightpix, public;

BEGIN;
-- We have 11 assertions below
SELECT plan(11);

SET client_min_messages TO WARNING;

---------------------------------------------------------------
-- SETUP CATEGORY TREE
---------------------------------------------------------------
INSERT INTO categories (id, name, parent_id)
VALUES (-1, 'Root', NULL),
       (-2, 'Child', -1),
       (-3, 'Leaf',  -2);

INSERT INTO users (id, username, email)
VALUES (-901, 'u1', 'u1@test.com');

INSERT INTO images (id, user_id, category_id, url)
VALUES (-9001, -901, -3, 'img_leaf.jpg');

DELETE FROM category_metrics WHERE category_id IN (-1,-2,-3);
DELETE FROM category_metrics_periodic WHERE category_id IN (-1,-2,-3);

---------------------------------------------------------------
-- INSERT +1 VOTE
---------------------------------------------------------------
INSERT INTO votes (image_id, user_id, value, voted_at)
VALUES (-9001, -901, 1, '2025-03-10 21:15:00');

SELECT ok(
    (SELECT COUNT(*) FROM category_metrics_periodic WHERE category_id IN (-1,-2,-3)) > 0,
    'Fan-out created rows for all 3 categories'
);

---------------------------------------------------------------
-- YEAR BUCKET (Leaf)  -> bucket #1: year only
---------------------------------------------------------------
SELECT results_eq(
    $$
    SELECT total_votes, positive_votes, negative_votes
      FROM category_metrics_periodic
     WHERE category_id   = -3
       AND year          = 2025
       AND semester      IS NULL
       AND quarter       IS NULL
       AND trimester     IS NULL
       AND month         IS NULL
       AND week_of_year  IS NULL
       AND week_of_month IS NULL
       AND day           IS NULL
       AND day_of_week   IS NULL
       AND day_period    IS NULL
       AND hour          IS NULL
    $$,
    $$VALUES (1,1,0)$$,
    'Year bucket: Leaf has +1 vote'
);

---------------------------------------------------------------
-- DAY PERIOD BUCKET (Leaf, granular version)
-- Trigger bucket #13: year + month + day + day_period
---------------------------------------------------------------
SELECT is(
    (SELECT day_period
       FROM category_metrics_periodic
      WHERE category_id   = -3
        AND year          = 2025
        AND month         = 3
        AND day           = 10
        AND semester      IS NULL
        AND quarter       IS NULL
        AND trimester     IS NULL
        AND week_of_year  IS NULL
        AND week_of_month IS NULL
        AND day_of_week   IS NULL
        AND hour          IS NULL
      LIMIT 1),
    'night',
    'Leaf: Day period correctly classified as night (year+month+day+day_period)'
);

-- Propagated Day Period to Child
SELECT ok(
    EXISTS(
        SELECT 1
          FROM category_metrics_periodic
         WHERE category_id   = -2
           AND year          = 2025
           AND month         = 3
           AND day           = 10
           AND day_period    = 'night'
           AND semester      IS NULL
           AND quarter       IS NULL
           AND trimester     IS NULL
           AND week_of_year  IS NULL
           AND week_of_month IS NULL
           AND day_of_week   IS NULL
           AND hour          IS NULL
    ),
    'Child: Received day_period bucket (year+month+day+day_period)'
);

-- Propagated Day Period to Root
SELECT ok(
    EXISTS(
        SELECT 1
          FROM category_metrics_periodic
         WHERE category_id   = -1
           AND year          = 2025
           AND month         = 3
           AND day           = 10
           AND day_period    = 'night'
           AND semester      IS NULL
           AND quarter       IS NULL
           AND trimester     IS NULL
           AND week_of_year  IS NULL
           AND week_of_month IS NULL
           AND day_of_week   IS NULL
           AND hour          IS NULL
    ),
    'Root: Received day_period bucket (year+month+day+day_period)'
);

---------------------------------------------------------------
-- HOUR BUCKET (Leaf, granular version)
-- Trigger bucket #18: year + month + day + hour
---------------------------------------------------------------
SELECT is(
    (SELECT hour
       FROM category_metrics_periodic
      WHERE category_id   = -3
        AND year          = 2025
        AND month         = 3
        AND day           = 10
        AND hour          = 21
        AND semester      IS NULL
        AND quarter       IS NULL
        AND trimester     IS NULL
        AND week_of_year  IS NULL
        AND week_of_month IS NULL
        AND day_of_week   IS NULL
        AND day_period    IS NULL
      LIMIT 1),
    21::smallint,
    'Leaf: Hour bucket stored correct hour (21) (year+month+day+hour)'
);

-- Propagated Hour to Child
SELECT ok(
    EXISTS(
        SELECT 1
          FROM category_metrics_periodic
         WHERE category_id   = -2
           AND year          = 2025
           AND month         = 3
           AND day           = 10
           AND hour          = 21
           AND semester      IS NULL
           AND quarter       IS NULL
           AND trimester     IS NULL
           AND week_of_year  IS NULL
           AND week_of_month IS NULL
           AND day_of_week   IS NULL
           AND day_period    IS NULL
    ),
    'Child: Received hour bucket (year+month+day+hour)'
);

-- Propagated Hour to Root
SELECT ok(
    EXISTS(
        SELECT 1
          FROM category_metrics_periodic
         WHERE category_id   = -1
           AND year          = 2025
           AND month         = 3
           AND day           = 10
           AND hour          = 21
           AND semester      IS NULL
           AND quarter       IS NULL
           AND trimester     IS NULL
           AND week_of_year  IS NULL
           AND week_of_month IS NULL
           AND day_of_week   IS NULL
           AND day_period    IS NULL
    ),
    'Root: Received hour bucket (year+month+day+hour)'
);

---------------------------------------------------------------
-- DELETE THE VOTE -> Should revert YEAR bucket values
---------------------------------------------------------------
DELETE FROM votes WHERE image_id = -9001 AND user_id = -901;

-- Year Bucket Reverted (Leaf)
SELECT is(
    COALESCE((
        SELECT total_votes
          FROM category_metrics_periodic
         WHERE category_id   = -3
           AND year          = 2025
           AND semester      IS NULL
           AND quarter       IS NULL
           AND trimester     IS NULL
           AND month         IS NULL
           AND week_of_year  IS NULL
           AND week_of_month IS NULL
           AND day           IS NULL
           AND day_of_week   IS NULL
           AND day_period    IS NULL
           AND hour          IS NULL
    ), 0),
    0,
    'Leaf Year bucket reverted total_votes to 0 after deletion'
);

-- Ancestors Year Reverted
SELECT is(
    COALESCE((
        SELECT total_votes
          FROM category_metrics_periodic
         WHERE category_id   = -2
           AND year          = 2025
           AND semester      IS NULL
           AND quarter       IS NULL
           AND trimester     IS NULL
           AND month         IS NULL
           AND week_of_year  IS NULL
           AND week_of_month IS NULL
           AND day           IS NULL
           AND day_of_week   IS NULL
           AND day_period    IS NULL
           AND hour          IS NULL
    ), 0),
    0,
    'Child Year bucket reverted'
);

SELECT is(
    COALESCE((
        SELECT total_votes
          FROM category_metrics_periodic
         WHERE category_id   = -1
           AND year          = 2025
           AND semester      IS NULL
           AND quarter       IS NULL
           AND trimester     IS NULL
           AND month         IS NULL
           AND week_of_year  IS NULL
           AND week_of_month IS NULL
           AND day           IS NULL
           AND day_of_week   IS NULL
           AND day_period    IS NULL
           AND hour          IS NULL
    ), 0),
    0,
    'Root Year bucket reverted'
);

---------------------------------------------------------------
SELECT finish();
ROLLBACK;
