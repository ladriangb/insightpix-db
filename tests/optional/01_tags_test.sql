-- ===============================================================
-- pgTAP Tests - Optional Tagging Module (Portable Version)
-- ===============================================================

SET search_path TO insightpix,public;

BEGIN;
SELECT plan(11);

---------------------------------------------------------------
-- TABLES EXIST
---------------------------------------------------------------
SELECT has_table('insightpix', 'tags', 'tags table exists');
SELECT has_table('insightpix', 'image_tags', 'image_tags table exists');

---------------------------------------------------------------
-- PK AND COLUMNS
---------------------------------------------------------------
SELECT col_is_pk('insightpix', 'tags', 'id', 'tags.id is PK');
SELECT col_type_is('insightpix', 'tags', 'name', 'character varying(50)', 'tags.name type correct');

---------------------------------------------------------------
-- UNIQUE NAME CONSTRAINT ON TAGS
---------------------------------------------------------------
SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(c.conkey)
        WHERE c.contype = 'u'
        AND n.nspname = 'insightpix'
        AND t.relname = 'tags'
        AND a.attname = 'name'
    ),
    'tags.name must be unique'
);

---------------------------------------------------------------
-- FOREIGN KEYS FOR IMAGE_TAGS
---------------------------------------------------------------
SELECT fk_ok('insightpix', 'image_tags', 'image_id', 'insightpix', 'images', 'id',
           'image_tags.image_id -> images.id');

SELECT fk_ok('insightpix', 'image_tags', 'tag_id', 'insightpix', 'tags', 'id',
           'image_tags.tag_id -> tags.id');

---------------------------------------------------------------
-- MATERIALIZED VIEW EXISTS
---------------------------------------------------------------
SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind = 'm'
        AND c.relname = 'tag_stats_mv'
        AND n.nspname = 'insightpix'
    ),
    'materialized view tag_stats_mv exists'
);

---------------------------------------------------------------
-- MATERIALIZED VIEW REQUIRED COLUMNS
---------------------------------------------------------------
SELECT has_column( 'insightpix', 'tag_stats_mv', 'tag_id', 'mv has tag_id column' );
SELECT has_column( 'insightpix', 'tag_stats_mv', 'total_votes', 'mv has total_votes column' );

---------------------------------------------------------------
-- INDEXES
---------------------------------------------------------------
SELECT ok(
    EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname='insightpix'
        AND tablename='tags'
        AND indexname='idx_tags_name'
    ),
    'idx_tags_name exists'
);

---------------------------------------------------------------
-- FINISH
---------------------------------------------------------------
SELECT finish();
ROLLBACK;
