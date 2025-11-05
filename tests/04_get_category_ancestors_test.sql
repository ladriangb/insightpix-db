-- ===============================================================
-- pgTAP Tests - InsightPix Core Schema
-- Version : 1.0
-- Author  : Luis Adrian Gonzalez Benavides
--
-- Module      : get_category_ancestors()
--
-- Description :
--   Tests the function that returns the full ancestor chain for a category,
--   including the category itself. Ensures correct traversal of the hierarchy
--   with no duplicates.
--
-- Notes:
--   - Uses pgTAP
--   - Runs inside a transaction and rolls back
-- ===============================================================

SET search_path TO insightpix, public;

BEGIN;

SELECT plan(7);

---------------------------------------------------------------
-- SETUP: Create category hierarchy
--
--   Root (ID 1)
--     └── Child (ID 2)
--           └── Grandchild (ID 3)
---------------------------------------------------------------
INSERT INTO categories (id, name, parent_id) VALUES
    (-1, 'Root', NULL),
    (-2, 'Child', -1),
    (-3, 'Grandchild', -2);


---------------------------------------------------------------
-- TEST: Root should return only itself
---------------------------------------------------------------
SELECT is(
    (SELECT count(*) FROM get_category_ancestors(-1))::int,
    1,
    'Root returns only itself'
);

SELECT is(
    (SELECT id FROM get_category_ancestors(-1) LIMIT 1),
    -1,
    'Root ancestor is itself'
);

---------------------------------------------------------------
-- TEST: Child should return itself + root
---------------------------------------------------------------
SELECT is(
    (SELECT count(*) FROM get_category_ancestors(-2))::int,
    2,
    'Child returns 2 ancestors (self + parent)'
);

SELECT ok(
    (SELECT array_agg(id ORDER BY id) FROM get_category_ancestors(-2)) @> ARRAY[-1,-2],
    'Child ancestors include 1 and 2'
);

---------------------------------------------------------------
-- TEST: Grandchild should return 3 levels
---------------------------------------------------------------
SELECT is(
    (SELECT count(*) FROM get_category_ancestors(-3))::int,
    3,
    'Grandchild returns 3 ancestors (self + 2 parents)'
);

SELECT ok(
    (SELECT array_agg(id ORDER BY id) FROM get_category_ancestors(-3)) @> ARRAY[-1,-2,-3],
    'Grandchild ancestors include 1, 2, and 3'
);

---------------------------------------------------------------
-- TEST: No duplicates
---------------------------------------------------------------
SELECT is(
    (SELECT count(*) FROM (SELECT DISTINCT id FROM get_category_ancestors(-3)) AS uniq),
    (SELECT count(*) FROM get_category_ancestors(-3)),
    'No duplicates returned'
);

---------------------------------------------------------------
-- FINISH
---------------------------------------------------------------
SELECT * FROM finish();
ROLLBACK;
