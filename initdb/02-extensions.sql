-- ==============================================================
-- InsightPix DB - Extensions Setup
-- Version    : 1.0
-- Author     : Luis Adrian Gonzalez Benavides
-- Description:
--   Installs PostgreSQL extensions used by InsightPix during
--   development, testing, and analytics. These extensions are:
--     • pgTAP       → Required for unit testing in CI environments
--     • uuid-ossp   → Optional; provides UUID generation functions
--
--   Notes    :
--     - pgTAP is intended for DEV and CI/test usage only.
--     - uuid-ossp may be enabled in PROD if UUIDs are required.
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
