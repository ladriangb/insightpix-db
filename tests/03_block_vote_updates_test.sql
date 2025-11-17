-- ===============================================================
-- pgTAP Tests - InsightPix Core Schema
-- Version : 1.0
-- Author  : Luis Adrian Gonzalez Benavides
--
-- Module      : block_vote_updates() trigger
--
-- Description :
--   Tests the trigger that blocks UPDATE operations on the votes table.
--   Ensures votes cannot be modified after creation, enforcing immutable
--   vote behavior. INSERT and DELETE must still be permitted.
--
-- Notes:
--   - Uses pgTAP
--   - Runs inside a transaction and rolls back
-- ===============================================================

SET search_path TO insightpix, public;

BEGIN;

SELECT plan(3);

---------------------------------------------------------------
-- SETUP: Insert sample data
---------------------------------------------------------------
INSERT INTO users (id, username, email) VALUES (1, 'user1', 'u1@test.com');
INSERT INTO images (id, user_id, url) VALUES (10, 1, 'img.jpg');
INSERT INTO votes (image_id, user_id, value) VALUES (10, 1, 1);

---------------------------------------------------------------
-- UPDATE SHOULD BE BLOCKED
---------------------------------------------------------------
SELECT throws_ok(
    $$UPDATE votes SET value = -1 WHERE image_id = 10 AND user_id = 1$$,
    'UPDATE on votes is not allowed. Delete and insert instead.',
    'UPDATE on votes is rejected as expected'
);

---------------------------------------------------------------
-- INSERT SHOULD STILL WORK
---------------------------------------------------------------
SELECT lives_ok(
    $$INSERT INTO votes (image_id, user_id, value) VALUES (10, 1, 1) ON CONFLICT DO NOTHING$$,
    'INSERT on votes still works'
);

---------------------------------------------------------------
-- DELETE SHOULD STILL WORK
---------------------------------------------------------------
SELECT lives_ok(
    $$DELETE FROM votes WHERE image_id = 10 AND user_id = 1$$,
    'DELETE on votes still works'
);

---------------------------------------------------------------
-- FINISH
---------------------------------------------------------------
SELECT * FROM finish();
ROLLBACK;
