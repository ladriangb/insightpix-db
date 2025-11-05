-- ==============================================================
-- InsightPix DB  - Core Schema Definition
-- Version: 1.0
-- Author: Luis Adrian Gonzalez Benavides
-- Description:
--   Blocks UPDATE operations on the votes table.
--   Enforces the rule: votes cannot be modified once created; they must be deleted and re-inserted.
--   Prevents inconsistent metric updates and preserves data integrity.
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
