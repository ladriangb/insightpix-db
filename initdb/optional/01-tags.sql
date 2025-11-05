-- ==============================================================
--  InsightPix DB - Optional Tagging Module (Schema Only)
--  Version: 1.0
--  Author: Luis Adrian Gonzalez Benavides
--  Description:
--    Adds tagging capability to images and defines a
--    materialized view for aggregated tag analytics.
-- ==============================================================

SET search_path TO insightpix;

-- ==============================================================
-- TAGS
-- ==============================================================
CREATE TABLE IF NOT EXISTS tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

COMMENT ON TABLE tags IS 'Free-form keyword labels assignable to images.';
COMMENT ON COLUMN tags.name IS 'Unique tag identifier (e.g., "portrait", "nature", "bw").';

-- ==============================================================
-- IMAGE_TAGS (Many-to-Many)
-- ==============================================================
CREATE TABLE IF NOT EXISTS image_tags (
    image_id INT NOT NULL REFERENCES images(id) ON DELETE CASCADE,
    tag_id INT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (image_id, tag_id)
);

COMMENT ON TABLE image_tags IS 'Associates tags with images (many-to-many relationship).';

-- ==============================================================
-- MATERIALIZED VIEW: TAG_STATS_MV
-- ==============================================================
-- Aggregated metrics per tag, derived from image-level data.
-- Stored physically for fast analytical queries.
CREATE MATERIALIZED VIEW IF NOT EXISTS tag_stats_mv AS
SELECT
    t.id                    AS tag_id,
    t.name                  AS tag_name,
    COUNT(i.id)             AS image_count,
    COALESCE(SUM(m.total_votes), 0)    AS total_votes,
    COALESCE(SUM(m.positive_votes), 0) AS positive_votes,
    COALESCE(SUM(m.negative_votes), 0) AS negative_votes,
    ROUND(COALESCE(AVG(m.score), 0), 2) AS avg_score,
    NOW() AS last_refreshed
FROM tags t
JOIN image_tags it ON it.tag_id = t.id
JOIN images i ON i.id = it.image_id
LEFT JOIN metrics m ON m.image_id = i.id
GROUP BY t.id, t.name
WITH DATA;

COMMENT ON MATERIALIZED VIEW tag_stats_mv IS
'Materialized tag performance metrics, refreshed periodically for analytical queries.';

-- ==============================================================
-- INDEXES
-- ==============================================================
CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name);
CREATE INDEX IF NOT EXISTS idx_image_tags_tag_id ON image_tags(tag_id);
CREATE INDEX IF NOT EXISTS idx_image_tags_image_id ON image_tags(image_id);
CREATE INDEX IF NOT EXISTS idx_tag_stats_mv_tag_name ON tag_stats_mv(tag_name);
CREATE INDEX IF NOT EXISTS idx_tag_stats_mv_avg_score ON tag_stats_mv(avg_score);
