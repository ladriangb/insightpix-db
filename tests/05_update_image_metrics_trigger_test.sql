-- ===============================================================
-- pgTAP Tests - InsightPix Core Schema
-- Version : 1.0
-- Author  : Luis Adrian Gonzalez Benavides
--
-- Module      : update_image_metrics trigger
--
-- Description :
--   Tests the trigger that updates image-level metrics after
--   INSERT or DELETE operations in the votes table.
--
-- Notes:
--   - Uses pgTAP
--   - Runs inside a transaction and rolls back
-- ===============================================================

SET search_path TO insightpix, public;

BEGIN;

SELECT plan(12);

---------------------------------------------------------------
-- SETUP
---------------------------------------------------------------

INSERT INTO users (id, username, email) VALUES (-101, 'test_user', 'test@x.com');
INSERT INTO users (id, username, email) VALUES (-102, 'test_user2', 'test2@x.com');
INSERT INTO images (id, user_id, url) VALUES (-1001, -101, 'img1.jpg');
DELETE FROM metrics WHERE image_id = -1001;

SELECT is(
    (SELECT COUNT(*) FROM metrics WHERE image_id = -1001)::int,
    0,
    'No metrics row exists initially'
);

---------------------------------------------------------------
-- INSERT A POSITIVE VOTE
---------------------------------------------------------------
INSERT INTO votes (image_id, user_id, value) VALUES (-1001, -101, 1);

SELECT is(
    (SELECT total_votes FROM metrics WHERE image_id = -1001),
    1,
    'After +1 vote: total_votes = 1'
);

SELECT is(
    (SELECT positive_votes FROM metrics WHERE image_id = -1001),
    1,
    'After +1 vote: positive_votes = 1'
);

SELECT is(
    (SELECT negative_votes FROM metrics WHERE image_id = -1001),
    0,
    'After +1 vote: negative_votes = 0'
);

SELECT is(
    (SELECT score FROM metrics WHERE image_id = -1001),
    100.00,
    'After +1 vote: score = 100.00'
);

---------------------------------------------------------------
-- INSERT A NEGATIVE VOTE
---------------------------------------------------------------
INSERT INTO votes (image_id, user_id, value) VALUES (-1001, -102, -1);

SELECT is(
    (SELECT total_votes FROM metrics WHERE image_id = -1001),
    2,
    'After -1 vote: total_votes = 2'
);

SELECT is(
    (SELECT positive_votes FROM metrics WHERE image_id = -1001),
    1,
    'After -1 vote: positive_votes remains 1'
);

SELECT is(
    (SELECT negative_votes FROM metrics WHERE image_id = -1001),
    1,
    'After -1 vote: negative_votes = 1'
);

SELECT is(
    (SELECT score FROM metrics WHERE image_id = -1001),
    0.00,
    'After +1 and -1 votes: score = 0.00'
);

---------------------------------------------------------------
-- DELETE A NEGATIVE VOTE
---------------------------------------------------------------
DELETE FROM votes WHERE image_id = -1001 AND user_id = -102;

SELECT is(
    (SELECT total_votes FROM metrics WHERE image_id = -1001),
    1,
    'After deleting -1 vote: total_votes back to 1'
);

SELECT is(
    (SELECT negative_votes FROM metrics WHERE image_id = -1001),
    0,
    'After deleting -1 vote: negative_votes back to 0'
);

SELECT is(
    (SELECT score FROM metrics WHERE image_id = -1001),
    100.00,
    'After delete: score returns to 100.00'
);

---------------------------------------------------------------
-- FINISH
---------------------------------------------------------------
SELECT finish();
ROLLBACK;
