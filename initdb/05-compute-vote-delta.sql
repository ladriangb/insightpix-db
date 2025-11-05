-- =====================================================================
-- InsightPix DB  - Vote Delta Computation
-- Version   : 1.0
-- Function  : compute_vote_delta(op TEXT, val SMALLINT)
--
-- Parameter :
--   op  TEXT - The trigger operation ('INSERT' or 'DELETE')
--   val SMALLINT  - The vote value being applied or removed (1 or -1)
--
-- Purpose   :
--   Computes the delta values for positive, negative, and total votes
--   based on the vote operation and value. This function is intended
--   to be used by vote-related triggers to ensure consistent delta
--   calculations and avoid duplicated logic across triggers.
--
-- Returns   : TABLE(d_pos INT, d_neg INT, d_tot INT)
--   d_pos  - Change to positive vote count
--   d_neg  - Change to negative vote count
--   d_tot  - Change to total vote count (+1 or -1)
--
-- Author    : Luis Adrian Gonzalez Benavides
--
-- Notes     :
--   - For INSERT:
--       * value 1   → d_pos = +1, d_neg =  0, d_tot = +1
--       * value -1  → d_pos =  0, d_neg = +1, d_tot = +1
--   - For DELETE:
--       * value 1   → d_pos = -1, d_neg =  0, d_tot = -1
--       * value -1  → d_pos =  0, d_neg = -1, d_tot = -1
--
-- Usage     :
--   SELECT * FROM compute_vote_delta('INSERT', 1);
--   SELECT * FROM compute_vote_delta('DELETE', -1);
-- =====================================================================


CREATE FUNCTION compute_vote_delta(op TEXT, val SMALLINT)
    RETURNS TABLE
            (
                d_pos INT,
                d_neg INT,
                d_tot INT
            )
AS
$$
BEGIN
    IF val NOT IN (1, -1) THEN
        RAISE EXCEPTION 'Invalid vote value: %, expected 1 or -1', val;
    END IF;

    IF op = 'INSERT' THEN
        RETURN QUERY
            SELECT (val = 1)::INT, (val = -1)::INT, 1;
    ELSIF op = 'DELETE' THEN
        RETURN QUERY
            SELECT -(val = 1)::INT, -(val = -1)::INT, -1;
    ELSE
        RAISE EXCEPTION 'Unsupported operation: %, expected INSERT or DELETE', op;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
