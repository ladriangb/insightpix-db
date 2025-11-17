-- ==============================================================
-- InsightPix DB  - Vote Integrity Enforcement
-- Version    : 1.0
-- Author     : Luis Adrian Gonzalez Benavides
-- Description:
--   Enforces the business rule that votes cannot be updated once
--   created. Any modification must be performed as a DELETE followed
--   by a new INSERT. This prevents metric inconsistencies and ensures
--   data integrity at the database level (not relying on application logic).
-- ==============================================================

SET search_path TO insightpix;

CREATE OR REPLACE FUNCTION block_vote_updates()
    RETURNS TRIGGER AS
$$
BEGIN
    RAISE EXCEPTION 'UPDATE on votes is not allowed. Delete and insert instead.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_block_vote_updates
    BEFORE UPDATE
    ON votes
    FOR EACH ROW
EXECUTE FUNCTION block_vote_updates();
