-- ==============================================================
--  InsightPix DB - Core Schema Definition
--  Version: 1.0
--  Author: Luis Adrian Gonzalez Benavides
--  Description:
--    Defines the relational schema for the InsightPix ecosystem,
--    including users, categories (hierarchical), images, 
--    votes, and multiple levels of aggregated metrics.
-- ==============================================================

-- === SCHEMA ===================================================
CREATE SCHEMA IF NOT EXISTS insightpix;
SET search_path TO insightpix;

-- ==============================================================
-- USERS
-- ==============================================================
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE users IS 'Registered users who upload images or provide feedback.';
COMMENT ON COLUMN users.username IS 'Unique username for identification.';
COMMENT ON COLUMN users.email IS 'User email address.';

-- ==============================================================
-- CATEGORIES (Hierarchical)
-- ==============================================================
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    parent_id INT REFERENCES categories(id) ON DELETE SET NULL
);

COMMENT ON TABLE categories IS 'Hierarchical classification of images.';
COMMENT ON COLUMN categories.parent_id IS 'Self-referencing parent category for hierarchical structures.';

-- ==============================================================
-- IMAGES
-- ==============================================================
CREATE TABLE IF NOT EXISTS images (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id INT REFERENCES categories(id) ON DELETE SET NULL,
    url TEXT NOT NULL,
    title VARCHAR(255),
    description TEXT,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE images IS 'Images uploaded by users for tagging, categorization, and feedback.';
COMMENT ON COLUMN images.category_id IS 'Linked category for hierarchical classification.';

-- ==============================================================
-- VOTES
-- ==============================================================
CREATE TABLE IF NOT EXISTS votes (
    id SERIAL PRIMARY KEY,
    image_id INT NOT NULL REFERENCES images(id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    value SMALLINT NOT NULL CHECK (value IN (1, -1)),
    voted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_vote_per_user_per_image UNIQUE (image_id, user_id)
);

COMMENT ON TABLE votes IS 'User votes (1 or -1) associated to specific images.';
COMMENT ON COLUMN votes.value IS '1 = positive vote, -1 = negative vote.';

-- ==============================================================
-- IMAGE METRICS (Aggregated by Image)
-- ==============================================================
CREATE TABLE IF NOT EXISTS metrics (
    image_id INT PRIMARY KEY REFERENCES images(id) ON DELETE CASCADE,
    total_votes INT DEFAULT 0,
    positive_votes INT DEFAULT 0,
    negative_votes INT DEFAULT 0,
    score NUMERIC(5,2) DEFAULT 0.0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE metrics IS 'Aggregated statistics per image.';
COMMENT ON COLUMN metrics.score IS 'Weighted score, may be computed by triggers.';

-- ==============================================================
-- CATEGORY METRICS (Aggregated by Category)
-- ==============================================================
CREATE TABLE IF NOT EXISTS category_metrics (
    category_id INT PRIMARY KEY REFERENCES categories(id) ON DELETE CASCADE,
    total_votes INT DEFAULT 0,
    positive_votes INT DEFAULT 0,
    negative_votes INT DEFAULT 0,
    score NUMERIC(5,2) DEFAULT 0.0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE category_metrics IS 'Aggregated vote statistics per category, including hierarchical propagation.';

-- ==============================================================
-- CATEGORY METRICS (Periodic / Time-bucketed, Extended)
-- ==============================================================
CREATE TABLE IF NOT EXISTS category_metrics_periodic (
    id BIGSERIAL PRIMARY KEY,
    category_id INT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,

    -- === Date-based dimensions ===
    year INT NOT NULL,
    quarter SMALLINT CHECK (quarter BETWEEN 1 AND 4),
    trimester SMALLINT CHECK (trimester BETWEEN 1 AND 3),
    semester SMALLINT CHECK (semester BETWEEN 1 AND 2),
    month SMALLINT CHECK (month BETWEEN 1 AND 12),
    week_of_year SMALLINT CHECK (week_of_year BETWEEN 1 AND 53),
    week_of_month SMALLINT CHECK (week_of_month BETWEEN 1 AND 5),
    day SMALLINT CHECK (day BETWEEN 1 AND 31),
    day_of_week SMALLINT CHECK (day_of_week BETWEEN 1 AND 7),

    -- === Time-based dimensions ===
    hour SMALLINT CHECK (hour BETWEEN 0 AND 23),
    day_period VARCHAR(10) CHECK (day_period IN ('morning','afternoon','night')),

    -- === Metrics ===
    total_votes INT DEFAULT 0,
    positive_votes INT DEFAULT 0,
    negative_votes INT DEFAULT 0,
    score NUMERIC(5,2) DEFAULT 0.0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (
        category_id, year, quarter, trimester, semester, month, week_of_year,
        week_of_month, day, day_of_week, hour, day_period
    )
);

COMMENT ON TABLE category_metrics_periodic IS
'Aggregated category-level metrics with full temporal dimensions (year, month, week, day, hour, etc.).';
COMMENT ON COLUMN category_metrics_periodic.quarter IS
'Quarter-year segment (1–4). Used for four-part division of the year.';
COMMENT ON COLUMN category_metrics_periodic.trimester IS
'Trimester (1–3). Used for three-part division of the year.';
COMMENT ON COLUMN category_metrics_periodic.semester IS
'Semester (1–2). Used for two-part division of the year.';
COMMENT ON COLUMN category_metrics_periodic.week_of_year IS
'ISO week number (1–53).';
COMMENT ON COLUMN category_metrics_periodic.week_of_month IS
'Week number within the month (1–5). Calculated from the vote date.';
COMMENT ON COLUMN category_metrics_periodic.day_of_week IS
'ISO day of week (1=Monday, 7=Sunday).';
COMMENT ON COLUMN category_metrics_periodic.hour IS
'Hour of the day (0–23).';
COMMENT ON COLUMN category_metrics_periodic.day_period IS
'Categorical representation of time of day: morning (06–11), afternoon (12–19), night (20–05).';

-- ==============================================================
-- INDEXES
-- ==============================================================
CREATE INDEX IF NOT EXISTS idx_votes_image_id ON votes(image_id);
CREATE INDEX IF NOT EXISTS idx_metrics_score ON metrics(score);
CREATE INDEX IF NOT EXISTS idx_category_metrics_periodic_cat ON category_metrics_periodic(category_id);
CREATE INDEX IF NOT EXISTS idx_category_metrics_periodic_year ON category_metrics_periodic(year);
CREATE INDEX IF NOT EXISTS idx_category_metrics_periodic_dayperiod ON category_metrics_periodic(day_period);

-- ==============================================================
-- SCHEMA COMMENT
-- ==============================================================
COMMENT ON SCHEMA insightpix IS
'Main schema for the InsightPix database system. Includes user content, hierarchical categories, votes, and analytical metric layers (instant and periodic).';
