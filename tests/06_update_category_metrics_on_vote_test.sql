-- ===============================================================
-- pgTAP Tests - InsightPix Core Schema
-- Version : 1.0
-- Author  : Luis Adrian Gonzalez Benavides
--
-- Module      : update_category_metrics_on_vote trigger
--
-- Description :
--   Tests the trigger that updates category_metrics after INSERT
--   or DELETE operations on votes. Ensures that metrics propagate
--   to the category of the image and all ancestor categories.
--
-- Notes:
--   - Uses pgTAP
--   - Runs inside a transaction and rolls back
-- ===============================================================

SET search_path TO insightpix, public;

BEGIN;

SELECT plan(18);

---------------------------------------------------------------
-- SETUP with NEGATIVE IDs
---------------------------------------------------------------
INSERT INTO categories (id, name, parent_id)
VALUES (-1, 'Root', NULL),
       (-2, 'Child', -1),
       (-3, 'Leaf', -2);

INSERT INTO users (id, username, email)
VALUES (-201, 'cat_user', 'cu@test.com');

INSERT INTO images (id, user_id, category_id, url)
VALUES (-2001, -201, -3, 'img_leaf.jpg');

---------------------------------------------------------------
-- INSERT +1
---------------------------------------------------------------
INSERT INTO votes (image_id, user_id, value)
VALUES (-2001, -201, 1);

-- Leaf
SELECT is(
    (SELECT positive_votes FROM category_metrics WHERE category_id = -3),
    1,
    'Leaf +1 vote registered'
);

-- Child
SELECT is(
    (SELECT positive_votes FROM category_metrics WHERE category_id = -2),
    1,
    'Child inherited +1 vote'
);

-- Root
SELECT is(
    (SELECT positive_votes FROM category_metrics WHERE category_id = -1),
    1,
    'Root inherited +1 vote'
);

---------------------------------------------------------------
-- INSERT -1
---------------------------------------------------------------
INSERT INTO users (id, username, email)
VALUES (-202, 'cat_user2', 'cu2@test.com');

INSERT INTO votes (image_id, user_id, value)
VALUES (-2001, -202, -1);

-- Now: total=2, pos=1, neg=1, score=0
SELECT is((SELECT total_votes FROM category_metrics WHERE category_id = -3), 2, 'Leaf total=2');
SELECT is((SELECT score       FROM category_metrics WHERE category_id = -3), 0.00, 'Leaf score=0');

SELECT is((SELECT total_votes FROM category_metrics WHERE category_id = -2), 2, 'Child total=2');
SELECT is((SELECT score       FROM category_metrics WHERE category_id = -2), 0.00, 'Child score=0');

SELECT is((SELECT total_votes FROM category_metrics WHERE category_id = -1), 2, 'Root total=2');
SELECT is((SELECT score       FROM category_metrics WHERE category_id = -1), 0.00, 'Root score=0');

---------------------------------------------------------------
-- DELETE -1
---------------------------------------------------------------
DELETE FROM votes WHERE image_id = -2001 AND user_id = -202;

SELECT is((SELECT positive_votes FROM category_metrics WHERE category_id = -3), 1, 'Leaf pos back to 1');
SELECT is((SELECT negative_votes FROM category_metrics WHERE category_id = -3), 0, 'Leaf neg back to 0');
SELECT is((SELECT score          FROM category_metrics WHERE category_id = -3), 100.00, 'Leaf score back to 100');

SELECT is((SELECT positive_votes FROM category_metrics WHERE category_id = -2), 1, 'Child pos back to 1');
SELECT is((SELECT negative_votes FROM category_metrics WHERE category_id = -2), 0, 'Child neg back to 0');
SELECT is((SELECT score          FROM category_metrics WHERE category_id = -2), 100.00, 'Child score back to 100');

SELECT is((SELECT positive_votes FROM category_metrics WHERE category_id = -1), 1, 'Root pos back to 1');
SELECT is((SELECT negative_votes FROM category_metrics WHERE category_id = -1), 0, 'Root neg back to 0');
SELECT is((SELECT score          FROM category_metrics WHERE category_id = -1), 100.00, 'Root score back to 100');

---------------------------------------------------------------
-- FINISH
---------------------------------------------------------------
SELECT * FROM finish();
ROLLBACK;
