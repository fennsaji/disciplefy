-- ============================================================================
-- Migration: Update Display Order by Faith Level (Easy to Difficult)
-- ============================================================================
-- This migration reorganizes recommended topics with proper display_order
-- based on faith level progression from foundational to advanced topics.
-- Each topic gets a unique display_order across the entire table.

BEGIN;

-- ============================================================================
-- Update display_order for all topics based on faith level progression
-- ============================================================================

-- Clear existing display orders first
UPDATE recommended_topics SET display_order = 0;

-- ============================================================================
-- LEVEL 1: FOUNDATIONS OF FAITH (Display Order: 1-6)
-- Essential basics every new believer should know first
-- ============================================================================

UPDATE recommended_topics SET display_order = 1 
WHERE id = '111e8400-e29b-41d4-a716-446655440001'; -- Who is Jesus Christ?

UPDATE recommended_topics SET display_order = 2 
WHERE id = '111e8400-e29b-41d4-a716-446655440002'; -- What is the Gospel?

UPDATE recommended_topics SET display_order = 3 
WHERE id = '111e8400-e29b-41d4-a716-446655440003'; -- Assurance of Salvation

UPDATE recommended_topics SET display_order = 4 
WHERE id = '111e8400-e29b-41d4-a716-446655440004'; -- Why Read the Bible?

UPDATE recommended_topics SET display_order = 5 
WHERE id = '111e8400-e29b-41d4-a716-446655440005'; -- Importance of Prayer

UPDATE recommended_topics SET display_order = 6 
WHERE id = '111e8400-e29b-41d4-a716-446655440006'; -- The Role of the Holy Spirit

-- ============================================================================
-- LEVEL 2: SPIRITUAL DISCIPLINES (Display Order: 7-11)
-- Building spiritual habits after understanding the basics
-- ============================================================================

UPDATE recommended_topics SET display_order = 7 
WHERE id = '555e8400-e29b-41d4-a716-446655440001'; -- Daily Devotions

UPDATE recommended_topics SET display_order = 8 
WHERE id = '555e8400-e29b-41d4-a716-446655440004'; -- Meditation on God's Word

UPDATE recommended_topics SET display_order = 9 
WHERE id = '555e8400-e29b-41d4-a716-446655440003'; -- Worship as a Lifestyle

UPDATE recommended_topics SET display_order = 10 
WHERE id = '555e8400-e29b-41d4-a716-446655440005'; -- Journaling Your Walk with God

UPDATE recommended_topics SET display_order = 11 
WHERE id = '555e8400-e29b-41d4-a716-446655440002'; -- Fasting and Prayer

-- ============================================================================
-- LEVEL 3: CHRISTIAN LIFE (Display Order: 12-17)
-- Practical living as a Christian in daily life
-- ============================================================================

UPDATE recommended_topics SET display_order = 12 
WHERE id = '222e8400-e29b-41d4-a716-446655440001'; -- Walking with God Daily

UPDATE recommended_topics SET display_order = 13 
WHERE id = '222e8400-e29b-41d4-a716-446655440002'; -- Overcoming Temptation

UPDATE recommended_topics SET display_order = 14 
WHERE id = '222e8400-e29b-41d4-a716-446655440003'; -- Forgiveness and Reconciliation

UPDATE recommended_topics SET display_order = 15 
WHERE id = '222e8400-e29b-41d4-a716-446655440006'; -- Living a Holy Life

UPDATE recommended_topics SET display_order = 16 
WHERE id = '222e8400-e29b-41d4-a716-446655440005'; -- Giving and Generosity

UPDATE recommended_topics SET display_order = 17 
WHERE id = '222e8400-e29b-41d4-a716-446655440004'; -- The Importance of Fellowship

-- ============================================================================
-- LEVEL 4: CHURCH & COMMUNITY (Display Order: 18-22)
-- Understanding church life and community involvement
-- ============================================================================

UPDATE recommended_topics SET display_order = 18 
WHERE id = '333e8400-e29b-41d4-a716-446655440001'; -- What is the Church?

UPDATE recommended_topics SET display_order = 19 
WHERE id = '333e8400-e29b-41d4-a716-446655440002'; -- Why Fellowship Matters

UPDATE recommended_topics SET display_order = 20 
WHERE id = '333e8400-e29b-41d4-a716-446655440004'; -- Unity in Christ

UPDATE recommended_topics SET display_order = 21 
WHERE id = '333e8400-e29b-41d4-a716-446655440005'; -- Spiritual Gifts and Their Use

UPDATE recommended_topics SET display_order = 22 
WHERE id = '333e8400-e29b-41d4-a716-446655440003'; -- Serving in the Church

-- ============================================================================
-- LEVEL 5: FAMILY & RELATIONSHIPS (Display Order: 23-27)
-- Applying faith in personal relationships
-- ============================================================================

UPDATE recommended_topics SET display_order = 23 
WHERE id = '777e8400-e29b-41d4-a716-446655440004'; -- Healthy Friendships

UPDATE recommended_topics SET display_order = 24 
WHERE id = '777e8400-e29b-41d4-a716-446655440003'; -- Honoring Parents

UPDATE recommended_topics SET display_order = 25 
WHERE id = '777e8400-e29b-41d4-a716-446655440005'; -- Resolving Conflicts Biblically

UPDATE recommended_topics SET display_order = 26 
WHERE id = '777e8400-e29b-41d4-a716-446655440001'; -- Marriage and Faith

UPDATE recommended_topics SET display_order = 27 
WHERE id = '777e8400-e29b-41d4-a716-446655440002'; -- Raising Children in Christ

-- ============================================================================
-- LEVEL 6: DISCIPLESHIP & GROWTH (Display Order: 28-32)
-- Growing in maturity and helping others grow
-- ============================================================================

UPDATE recommended_topics SET display_order = 28 
WHERE id = '444e8400-e29b-41d4-a716-446655440001'; -- What is Discipleship?

UPDATE recommended_topics SET display_order = 29 
WHERE id = '444e8400-e29b-41d4-a716-446655440002'; -- The Cost of Following Jesus

UPDATE recommended_topics SET display_order = 30 
WHERE id = '444e8400-e29b-41d4-a716-446655440003'; -- Bearing Fruit

UPDATE recommended_topics SET display_order = 31 
WHERE id = '444e8400-e29b-41d4-a716-446655440005'; -- Mentoring Others

UPDATE recommended_topics SET display_order = 32 
WHERE id = '444e8400-e29b-41d4-a716-446655440004'; -- The Great Commission

-- ============================================================================
-- LEVEL 7: MISSION & SERVICE (Display Order: 33-37)
-- Outward focused ministry and evangelism
-- ============================================================================

UPDATE recommended_topics SET display_order = 33 
WHERE id = '888e8400-e29b-41d4-a716-446655440001'; -- Being the Light in Your Community

UPDATE recommended_topics SET display_order = 34 
WHERE id = '888e8400-e29b-41d4-a716-446655440002'; -- Sharing Your Testimony

UPDATE recommended_topics SET display_order = 35 
WHERE id = '888e8400-e29b-41d4-a716-446655440003'; -- Serving the Poor and Needy

UPDATE recommended_topics SET display_order = 36 
WHERE id = '888e8400-e29b-41d4-a716-446655440004'; -- Evangelism Made Simple

UPDATE recommended_topics SET display_order = 37 
WHERE id = '888e8400-e29b-41d4-a716-446655440005'; -- Praying for the Nations

-- ============================================================================
-- LEVEL 8: APOLOGETICS & DEFENSE OF FAITH (Display Order: 38-42)
-- Advanced topics for defending and explaining the faith
-- ============================================================================

UPDATE recommended_topics SET display_order = 38 
WHERE id = '666e8400-e29b-41d4-a716-446655440001'; -- Why We Believe in One God

UPDATE recommended_topics SET display_order = 39 
WHERE id = '666e8400-e29b-41d4-a716-446655440002'; -- The Uniqueness of Jesus

UPDATE recommended_topics SET display_order = 40 
WHERE id = '666e8400-e29b-41d4-a716-446655440003'; -- Is the Bible Reliable?

UPDATE recommended_topics SET display_order = 41 
WHERE id = '666e8400-e29b-41d4-a716-446655440004'; -- Responding to Common Questions from Other Faiths

UPDATE recommended_topics SET display_order = 42 
WHERE id = '666e8400-e29b-41d4-a716-446655440005'; -- Standing Firm in Persecution

-- ============================================================================
-- Verify no duplicate display_order values exist
-- ============================================================================

-- Check for duplicates (this should return 0 rows if successful)
DO $$
DECLARE
    duplicate_count INTEGER;
    total_topics INTEGER;
BEGIN
    SELECT COUNT(*) INTO duplicate_count
    FROM (
        SELECT display_order, COUNT(*) as cnt
        FROM recommended_topics
        WHERE display_order > 0
        GROUP BY display_order
        HAVING COUNT(*) > 1
    ) duplicates;
    
    SELECT COUNT(*) INTO total_topics
    FROM recommended_topics 
    WHERE display_order > 0;
    
    IF duplicate_count > 0 THEN
        RAISE EXCEPTION 'Found % duplicate display_order values after migration', duplicate_count;
    ELSE
        RAISE NOTICE 'Migration successful: All % topics have unique display_order values', total_topics;
    END IF;
END
$$;

-- ============================================================================
-- Update function to use proper ordering
-- ============================================================================

-- Update the get_recommended_topics function to use the new ordering
CREATE OR REPLACE FUNCTION get_recommended_topics(
  p_category TEXT DEFAULT NULL,
  p_difficulty TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
  id UUID,
  title TEXT,
  description TEXT,
  category VARCHAR(100),
  tags TEXT[],
  display_order INTEGER,
  created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    rt.id,
    rt.title,
    rt.description,
    rt.category,
    rt.tags,
    rt.display_order,
    rt.created_at
  FROM recommended_topics rt
  WHERE rt.is_active = true
    AND (p_category IS NULL OR rt.category = p_category)
  ORDER BY rt.display_order ASC, rt.created_at ASC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Add constraints to prevent future duplicate display_order values
-- ============================================================================

-- Add unique constraint on display_order where is_active = true
CREATE UNIQUE INDEX IF NOT EXISTS idx_recommended_topics_unique_display_order_active 
ON recommended_topics (display_order) 
WHERE is_active = true AND display_order > 0;

-- Add comment explaining the display order logic
COMMENT ON COLUMN recommended_topics.display_order IS 'Unique display order for active topics: 1-6 Foundations, 7-11 Spiritual Disciplines, 12-17 Christian Life, 18-22 Church & Community, 23-27 Family & Relationships, 28-32 Discipleship & Growth, 33-37 Mission & Service, 38-42 Apologetics & Defense';

COMMIT;