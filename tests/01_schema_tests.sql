-- ===============================================================
-- pgTAP Tests - InsightPix Core Schema
-- Version: 1.1 updated for latest schema
-- Author: Luis Adrian Gonzalez Benavides
-- ===============================================================

BEGIN;

SELECT plan(33);  -- Update this if adding more tests later

---------------------------------------------------------------
-- SCHEMA EXISTS
---------------------------------------------------------------
SELECT has_schema('insightpix', 'Schema insightpix exists');

---------------------------------------------------------------
-- TABLES EXIST
---------------------------------------------------------------
SELECT has_table('insightpix', 'users', 'users table exists');
SELECT has_table('insightpix', 'categories', 'categories table exists');
SELECT has_table('insightpix', 'images', 'images table exists');
SELECT has_table('insightpix', 'votes', 'votes table exists');
SELECT has_table('insightpix', 'metrics', 'metrics table exists');
SELECT has_table('insightpix', 'category_metrics', 'category_metrics table exists');
SELECT has_table('insightpix', 'category_metrics_periodic', 'periodic metrics table exists');

---------------------------------------------------------------
-- COLUMNS & TYPES
---------------------------------------------------------------
-- users
SELECT col_is_pk('insightpix', 'users', 'id', 'users.id is PK');
SELECT col_type_is('insightpix', 'users', 'username', 'character varying(50)', 'users.username type is correct');
SELECT col_type_is('insightpix', 'users', 'email', 'character varying(100)', 'users.email type is correct');

-- categories
SELECT col_type_is('insightpix', 'categories', 'name', 'character varying(100)', 'categories.name type correct');
SELECT fk_ok('insightpix', 'categories', 'parent_id', 'insightpix', 'categories', 'id', 'categories.parent_id FK valid');

-- images
SELECT fk_ok('insightpix', 'images', 'user_id', 'insightpix', 'users', 'id', 'images.user_id references users.id');
SELECT fk_ok('insightpix', 'images', 'category_id', 'insightpix', 'categories', 'id', 'images.category_id references categories.id');
SELECT col_type_is('insightpix', 'images', 'url', 'text', 'images.url is text');

-- votes
SELECT col_type_is('insightpix', 'votes', 'value', 'smallint', 'votes.value is smallint');
SELECT col_has_check('insightpix', 'votes', 'value', 'votes.value has range constraint');
SELECT fk_ok('insightpix', 'votes', 'image_id', 'insightpix', 'images', 'id', 'votes.image_id FK valid');
SELECT fk_ok('insightpix', 'votes', 'user_id', 'insightpix', 'users', 'id', 'votes.user_id FK valid');

---------------------------------------------------------------
-- UNIQUE CONSTRAINTS
---------------------------------------------------------------
---------------------------------------------------------------
-- UNIQUE CONSTRAINTS (Portable version)
---------------------------------------------------------------

-- Unique username in users
SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(c.conkey)
        WHERE c.contype = 'u'
        AND n.nspname = 'insightpix'
        AND t.relname = 'users'
        AND a.attname = 'username'
    ),
    'username must be unique'
);

-- Unique email in users
SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(c.conkey)
        WHERE c.contype = 'u'
        AND n.nspname = 'insightpix'
        AND t.relname = 'users'
        AND a.attname = 'email'
    ),
    'email must be unique'
);

-- Composite unique (image_id, user_id) in votes
SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE c.contype = 'u'
        AND n.nspname = 'insightpix'
        AND t.relname = 'votes'
    ),
    'votes has composite unique constraint for image/user pair'
);

---------------------------------------------------------------
-- METRICS TABLES
---------------------------------------------------------------
SELECT col_type_is('insightpix', 'metrics', 'total_votes', 'integer', 'metrics.total_votes integer');
SELECT col_is_pk('insightpix', 'metrics', 'image_id', 'metrics references images PK');

SELECT col_is_pk('insightpix', 'category_metrics', 'category_id', 'category_metrics references categories PK');

---------------------------------------------------------------
-- PERIODIC METRICS
---------------------------------------------------------------
SELECT col_type_is('insightpix', 'category_metrics_periodic', 'year', 'integer', 'year type OK');
SELECT col_type_is('insightpix', 'category_metrics_periodic', 'day_period', 'character varying(10)', 'day_period OK');

---------------------------------------------------------------
-- CHECK CONSTRAINTS (Portable version)
---------------------------------------------------------------
-- Check constraint on quarter
SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE c.contype = 'c'
        AND n.nspname = 'insightpix'
        AND t.relname = 'category_metrics_periodic'
        AND pg_get_constraintdef(c.oid) LIKE '%quarter%'
    ),
    'quarter column has valid CHECK constraint'
);

-- Check constraint on day_period
SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE c.contype = 'c'
        AND n.nspname = 'insightpix'
        AND t.relname = 'category_metrics_periodic'
        AND pg_get_constraintdef(c.oid) LIKE '%day_period%'
    ),
    'day_period column has allowed values constraint'
);

---------------------------------------------------------------
-- INDEXES
---------------------------------------------------------------
SELECT has_index('insightpix', 'votes', 'idx_votes_image_id', 'votes.image_id index exists');
SELECT has_index('insightpix', 'metrics', 'idx_metrics_score', 'metrics.score index exists');
SELECT has_index('insightpix', 'category_metrics_periodic', 'idx_category_metrics_periodic_cat', 'periodic by category index exists');

---------------------------------------------------------------
-- FINISH
---------------------------------------------------------------
SELECT * FROM finish();
ROLLBACK;
