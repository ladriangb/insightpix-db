-- ===============================================================
-- pgTAP Tests - InsightPix Core Schema
-- Version : 1.0
-- Author  : Luis Adrian Gonzalez Benavides
--
-- Module      : compute_vote_delta()
--
-- Description :
--   Unit tests for the compute_vote_delta() function. Ensures that
--   the delta calculation logic for INSERT/DELETE vote operations
--   behaves as expected, including validation of invalid inputs.
--
-- Notes:
--   - Uses pgTAP
--   - Runs inside a transaction and rolls back
-- ===============================================================

SET search_path TO insightpix,public;

BEGIN;

SELECT plan(8);

-- INSERT +1
SELECT is(
    (SELECT d_pos FROM compute_vote_delta('INSERT'::text, 1::smallint)),
    1,
    'INSERT +1: d_pos = +1'
);

SELECT is(
    (SELECT d_neg FROM compute_vote_delta('INSERT'::text, 1::smallint)),
    0,
    'INSERT +1: d_neg = 0'
);

SELECT is(
    (SELECT d_tot FROM compute_vote_delta('INSERT'::text, 1::smallint)),
    1,
    'INSERT +1: d_tot = +1'
);

-- INSERT -1
SELECT is(
    (SELECT d_neg FROM compute_vote_delta('INSERT'::text, -1::smallint)),
    1,
    'INSERT -1: d_neg = +1'
);

-- DELETE +1
SELECT is(
    (SELECT d_pos FROM compute_vote_delta('DELETE'::text, 1::smallint)),
    -1,
    'DELETE +1: d_pos = -1'
);

-- DELETE -1
SELECT is(
    (SELECT d_neg FROM compute_vote_delta('DELETE'::text, -1::smallint)),
    -1,
    'DELETE -1: d_neg = -1'
);

-- Invalid value
SELECT throws_ok(
    $$SELECT compute_vote_delta('INSERT'::text, 0::smallint)$$,
    'Invalid vote value: 0, expected 1 or -1',
    'Rejects invalid vote value (0)'
);

-- Invalid op
SELECT throws_ok(
    $$SELECT compute_vote_delta('UPSERT'::text, 1::smallint)$$,
    'Unsupported operation: UPSERT, expected INSERT or DELETE',
    'Rejects invalid operation'
);

SELECT finish();

ROLLBACK;
