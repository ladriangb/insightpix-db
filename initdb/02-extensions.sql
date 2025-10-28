-- ==============================================================
-- InsightPix DB - Optional Extensions Setup
-- Version: 1.0
-- Author: Luis Adrian Gonzalez Benavides
-- Description:
--   Enables PostgreSQL extensions required for development,
--   testing, and analytics. These are non-essential for
--   production but critical for CI / test environments.
-- ==============================================================

SET search_path TO public;

-- ==============================================================
-- pgTAP - Unit Testing Framework
-- ==============================================================
DO $$
BEGIN
    IF current_setting('server_version_num')::int >= 90600 THEN
        RAISE NOTICE 'Installing pgTAP extension...';
        CREATE EXTENSION IF NOT EXISTS pgtap;
    ELSE
        RAISE NOTICE 'PostgreSQL < 9.6 detected; pgTAP may not be available.';
    END IF;
END $$;

COMMENT ON EXTENSION pgtap IS
'pgTAP: PostgreSQL unit testing framework used by InsightPix DB test suite.';

-- ==============================================================
-- UUID-OSSP (optional)
-- ==============================================================
DO $$
BEGIN
    RAISE NOTICE 'Installing uuid-ossp extension (optional)...';
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
END $$;

COMMENT ON EXTENSION "uuid-ossp" IS
'Provides functions to generate UUIDs (useful for external references).';
