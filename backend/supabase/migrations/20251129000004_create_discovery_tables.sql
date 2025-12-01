-- =====================================================
-- Phase 4: Enhanced Discovery Tables
-- =====================================================
-- This migration creates tables for:
-- 1. Trending topics (most popular this week)
-- 2. Seasonal topics (Christmas, Easter, Lent, etc.)
-- 3. Life situations (contextual discovery)
-- =====================================================

-- =====================================================
-- 1. TRENDING TOPICS
-- Tracks topic popularity based on study guide generation
-- =====================================================

-- Table to track topic engagement/popularity metrics
CREATE TABLE IF NOT EXISTS topic_engagement_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic_id UUID NOT NULL REFERENCES recommended_topics(id) ON DELETE CASCADE,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    study_count INTEGER DEFAULT 0,
    completion_count INTEGER DEFAULT 0,
    save_count INTEGER DEFAULT 0,
    share_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(topic_id, date)
);

-- Index for efficient trending queries
CREATE INDEX IF NOT EXISTS idx_topic_engagement_date ON topic_engagement_metrics(date DESC);
CREATE INDEX IF NOT EXISTS idx_topic_engagement_topic ON topic_engagement_metrics(topic_id);

-- Function to increment engagement metrics
CREATE OR REPLACE FUNCTION increment_topic_engagement(
    p_topic_id UUID,
    p_metric_type TEXT DEFAULT 'study'
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO topic_engagement_metrics (topic_id, date, study_count, completion_count, save_count, share_count)
    VALUES (
        p_topic_id,
        CURRENT_DATE,
        CASE WHEN p_metric_type = 'study' THEN 1 ELSE 0 END,
        CASE WHEN p_metric_type = 'completion' THEN 1 ELSE 0 END,
        CASE WHEN p_metric_type = 'save' THEN 1 ELSE 0 END,
        CASE WHEN p_metric_type = 'share' THEN 1 ELSE 0 END
    )
    ON CONFLICT (topic_id, date)
    DO UPDATE SET
        study_count = topic_engagement_metrics.study_count + CASE WHEN p_metric_type = 'study' THEN 1 ELSE 0 END,
        completion_count = topic_engagement_metrics.completion_count + CASE WHEN p_metric_type = 'completion' THEN 1 ELSE 0 END,
        save_count = topic_engagement_metrics.save_count + CASE WHEN p_metric_type = 'save' THEN 1 ELSE 0 END,
        share_count = topic_engagement_metrics.share_count + CASE WHEN p_metric_type = 'share' THEN 1 ELSE 0 END,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. SEASONAL TOPICS
-- Maps topics to seasons/holidays for timely discovery
-- =====================================================

-- Seasons enum type
DO $$ BEGIN
    CREATE TYPE season_type AS ENUM (
        'advent',
        'christmas',
        'lent',
        'easter',
        'pentecost',
        'ordinary_time',
        'new_year',
        'thanksgiving',
        'back_to_school',
        'summer',
        'fall',
        'winter',
        'spring'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS seasonal_topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic_id UUID NOT NULL REFERENCES recommended_topics(id) ON DELETE CASCADE,
    season season_type NOT NULL,
    priority INTEGER DEFAULT 0, -- Higher = more prominent
    start_month INTEGER CHECK (start_month >= 1 AND start_month <= 12),
    end_month INTEGER CHECK (end_month >= 1 AND end_month <= 12),
    -- Some seasons have specific date ranges (e.g., Easter moves)
    start_day INTEGER CHECK (start_day >= 1 AND start_day <= 31),
    end_day INTEGER CHECK (end_day >= 1 AND end_day <= 31),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(topic_id, season)
);

-- Translations for seasonal labels
CREATE TABLE IF NOT EXISTS seasonal_translations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    season season_type NOT NULL,
    language_code VARCHAR(5) NOT NULL DEFAULT 'en',
    title VARCHAR(100) NOT NULL,
    subtitle VARCHAR(200),
    description TEXT,
    icon_name VARCHAR(50), -- Flutter icon name
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(season, language_code)
);

CREATE INDEX IF NOT EXISTS idx_seasonal_topics_season ON seasonal_topics(season);
CREATE INDEX IF NOT EXISTS idx_seasonal_topics_active ON seasonal_topics(is_active) WHERE is_active = TRUE;

-- =====================================================
-- 3. LIFE SITUATIONS
-- Contextual discovery based on life circumstances
-- =====================================================

CREATE TABLE IF NOT EXISTS life_situations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(100) NOT NULL UNIQUE,
    icon_name VARCHAR(50) NOT NULL DEFAULT 'help_outline',
    color_hex VARCHAR(7) DEFAULT '#6A4FB6', -- Primary purple
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS life_situation_translations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    life_situation_id UUID NOT NULL REFERENCES life_situations(id) ON DELETE CASCADE,
    language_code VARCHAR(5) NOT NULL DEFAULT 'en',
    title VARCHAR(100) NOT NULL,
    subtitle VARCHAR(200),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(life_situation_id, language_code)
);

-- Maps topics to life situations
CREATE TABLE IF NOT EXISTS life_situation_topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    life_situation_id UUID NOT NULL REFERENCES life_situations(id) ON DELETE CASCADE,
    topic_id UUID NOT NULL REFERENCES recommended_topics(id) ON DELETE CASCADE,
    relevance_score INTEGER DEFAULT 100, -- 1-100, higher = more relevant
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(life_situation_id, topic_id)
);

CREATE INDEX IF NOT EXISTS idx_life_situation_topics_situation ON life_situation_topics(life_situation_id);
CREATE INDEX IF NOT EXISTS idx_life_situations_active ON life_situations(is_active) WHERE is_active = TRUE;

-- =====================================================
-- 4. ROW LEVEL SECURITY
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE topic_engagement_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE seasonal_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE seasonal_translations ENABLE ROW LEVEL SECURITY;
ALTER TABLE life_situations ENABLE ROW LEVEL SECURITY;
ALTER TABLE life_situation_translations ENABLE ROW LEVEL SECURITY;
ALTER TABLE life_situation_topics ENABLE ROW LEVEL SECURITY;

-- Public read access for discovery tables (no auth required for browsing)
CREATE POLICY "Anyone can read engagement metrics" ON topic_engagement_metrics
    FOR SELECT USING (true);

CREATE POLICY "Anyone can read seasonal topics" ON seasonal_topics
    FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Anyone can read seasonal translations" ON seasonal_translations
    FOR SELECT USING (true);

CREATE POLICY "Anyone can read life situations" ON life_situations
    FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Anyone can read life situation translations" ON life_situation_translations
    FOR SELECT USING (true);

CREATE POLICY "Anyone can read life situation topics" ON life_situation_topics
    FOR SELECT USING (true);

-- Service role can manage all tables
CREATE POLICY "Service role can manage engagement metrics" ON topic_engagement_metrics
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can manage seasonal topics" ON seasonal_topics
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can manage seasonal translations" ON seasonal_translations
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can manage life situations" ON life_situations
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can manage life situation translations" ON life_situation_translations
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can manage life situation topics" ON life_situation_topics
    FOR ALL USING (auth.role() = 'service_role');

-- =====================================================
-- 5. HELPER VIEW FOR TRENDING TOPICS
-- =====================================================

CREATE OR REPLACE VIEW trending_topics_view AS
SELECT
    t.id,
    t.title,
    t.description,
    t.category,
    t.tags,
    COALESCE(SUM(e.study_count), 0) AS total_studies,
    COALESCE(SUM(e.completion_count), 0) AS total_completions,
    COALESCE(SUM(e.save_count), 0) AS total_saves,
    -- Weighted popularity score
    COALESCE(
        SUM(e.study_count) * 1 +
        SUM(e.completion_count) * 2 +
        SUM(e.save_count) * 1.5 +
        SUM(e.share_count) * 3,
        0
    ) AS popularity_score
FROM recommended_topics t
LEFT JOIN topic_engagement_metrics e ON t.id = e.topic_id
    AND e.date >= CURRENT_DATE - INTERVAL '7 days'
WHERE t.is_active = TRUE
GROUP BY t.id, t.title, t.description, t.category, t.tags
ORDER BY popularity_score DESC;

-- =====================================================
-- 6. UPDATED_AT TRIGGERS
-- =====================================================

CREATE OR REPLACE FUNCTION update_discovery_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_topic_engagement_updated_at
    BEFORE UPDATE ON topic_engagement_metrics
    FOR EACH ROW EXECUTE FUNCTION update_discovery_updated_at();

CREATE TRIGGER trigger_seasonal_topics_updated_at
    BEFORE UPDATE ON seasonal_topics
    FOR EACH ROW EXECUTE FUNCTION update_discovery_updated_at();

CREATE TRIGGER trigger_life_situations_updated_at
    BEFORE UPDATE ON life_situations
    FOR EACH ROW EXECUTE FUNCTION update_discovery_updated_at();
