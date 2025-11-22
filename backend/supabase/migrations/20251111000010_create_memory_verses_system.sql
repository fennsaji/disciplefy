-- =====================================================
-- Memory Verses Spaced Repetition System (SRS)
-- Migration: Create tables, indexes, and RLS policies
-- =====================================================

-- =====================================================
-- TABLE: memory_verses
-- Stores verses that users want to memorize with SRS metadata
-- =====================================================
CREATE TABLE IF NOT EXISTS memory_verses (
  -- Primary key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- User reference
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Verse content
  verse_reference TEXT NOT NULL,
  verse_text TEXT NOT NULL,
  language TEXT NOT NULL DEFAULT 'en',
  
  -- Source tracking
  source_type TEXT NOT NULL CHECK (source_type IN ('daily_verse', 'manual', 'ai_generated')),
  source_id UUID REFERENCES daily_verses_cache(uuid) ON DELETE SET NULL,
  
  -- SM-2 Spaced Repetition Algorithm fields
  ease_factor NUMERIC(4,2) NOT NULL DEFAULT 2.5 CHECK (ease_factor >= 1.3),
  interval_days INTEGER NOT NULL DEFAULT 1 CHECK (interval_days >= 0),
  repetitions INTEGER NOT NULL DEFAULT 0 CHECK (repetitions >= 0),
  next_review_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Review metadata
  added_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_reviewed TIMESTAMPTZ,
  total_reviews INTEGER NOT NULL DEFAULT 0 CHECK (total_reviews >= 0),
  
  -- Audit fields
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT unique_user_verse_language UNIQUE(user_id, verse_reference, language),
  CONSTRAINT valid_ease_factor CHECK (ease_factor BETWEEN 1.3 AND 3.0),
  CONSTRAINT valid_next_review CHECK (next_review_date >= added_date)
);

-- Add table comment
COMMENT ON TABLE memory_verses IS 'Stores Bible verses for spaced repetition memorization with SM-2 algorithm metadata';

-- Add column comments
COMMENT ON COLUMN memory_verses.source_type IS 'Origin of the verse: daily_verse (from Daily Verse feature), manual (user-added), ai_generated (AI-generated)';
COMMENT ON COLUMN memory_verses.source_id IS 'Foreign key to daily_verses table if source_type is daily_verse';
COMMENT ON COLUMN memory_verses.ease_factor IS 'SM-2 algorithm: ease factor for calculating next interval (1.3-3.0)';
COMMENT ON COLUMN memory_verses.interval_days IS 'SM-2 algorithm: days until next review';
COMMENT ON COLUMN memory_verses.repetitions IS 'SM-2 algorithm: number of consecutive successful reviews';
COMMENT ON COLUMN memory_verses.next_review_date IS 'Scheduled date/time for next review';

-- =====================================================
-- TABLE: review_sessions
-- Stores individual review attempts with quality ratings
-- =====================================================
CREATE TABLE IF NOT EXISTS review_sessions (
  -- Primary key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Foreign keys
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  memory_verse_id UUID NOT NULL REFERENCES memory_verses(id) ON DELETE CASCADE,
  
  -- Review data
  review_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  quality_rating INTEGER NOT NULL CHECK (quality_rating BETWEEN 0 AND 5),
  
  -- SM-2 algorithm state after this review
  new_ease_factor NUMERIC(4,2) NOT NULL CHECK (new_ease_factor >= 1.3),
  new_interval_days INTEGER NOT NULL CHECK (new_interval_days >= 0),
  new_repetitions INTEGER NOT NULL CHECK (new_repetitions >= 0),
  
  -- Performance tracking
  time_spent_seconds INTEGER CHECK (time_spent_seconds > 0),
  
  -- Audit fields
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add table comment
COMMENT ON TABLE review_sessions IS 'Records each individual review session with quality rating and resulting SM-2 state';

-- Add column comments
COMMENT ON COLUMN review_sessions.quality_rating IS 'SM-2 quality rating: 0=complete blackout, 1=incorrect with correct answer seeming familiar, 2=incorrect but remembered, 3=correct with serious difficulty, 4=correct after hesitation, 5=perfect recall';
COMMENT ON COLUMN review_sessions.new_ease_factor IS 'Ease factor calculated after this review';
COMMENT ON COLUMN review_sessions.new_interval_days IS 'Interval calculated after this review';
COMMENT ON COLUMN review_sessions.new_repetitions IS 'Repetition count after this review';

-- =====================================================
-- TABLE: review_history
-- Aggregates daily review statistics per verse
-- =====================================================
CREATE TABLE IF NOT EXISTS review_history (
  -- Primary key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Foreign keys
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  memory_verse_id UUID NOT NULL REFERENCES memory_verses(id) ON DELETE CASCADE,
  
  -- Daily aggregation
  review_date DATE NOT NULL,
  reviews_count INTEGER NOT NULL DEFAULT 0 CHECK (reviews_count >= 0),
  average_quality NUMERIC(3,2) CHECK (average_quality BETWEEN 0 AND 5),
  
  -- Audit fields
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT unique_user_verse_date UNIQUE(user_id, memory_verse_id, review_date)
);

-- Add table comment
COMMENT ON TABLE review_history IS 'Daily aggregated review statistics for analytics and progress tracking';

-- =====================================================
-- INDEXES
-- Optimized for common query patterns
-- =====================================================

-- Index for fetching due verses (most common query)
CREATE INDEX IF NOT EXISTS idx_memory_verses_user_next_review 
  ON memory_verses(user_id, next_review_date) 
  WHERE next_review_date IS NOT NULL;

-- Index for source tracking queries
CREATE INDEX IF NOT EXISTS idx_memory_verses_source 
  ON memory_verses(user_id, source_type, source_id);

-- Index for verse lookup by reference
CREATE INDEX IF NOT EXISTS idx_memory_verses_reference 
  ON memory_verses(user_id, verse_reference);

-- Index for language filtering
CREATE INDEX IF NOT EXISTS idx_memory_verses_language 
  ON memory_verses(user_id, language);

-- Index for review session queries (user's review history)
CREATE INDEX IF NOT EXISTS idx_review_sessions_user_date 
  ON review_sessions(user_id, review_date DESC);

-- Index for verse-specific review history
CREATE INDEX IF NOT EXISTS idx_review_sessions_verse 
  ON review_sessions(memory_verse_id, review_date DESC);

-- Index for daily history aggregation queries
CREATE INDEX IF NOT EXISTS idx_review_history_user_verse 
  ON review_history(user_id, memory_verse_id, review_date DESC);

-- Index for date-based analytics
CREATE INDEX IF NOT EXISTS idx_review_history_user_date 
  ON review_history(user_id, review_date DESC);

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- Users can only access their own memory verses and reviews
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE memory_verses ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_history ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- RLS POLICIES: memory_verses
-- =====================================================

-- Policy: Users can view their own memory verses
CREATE POLICY "Users can view their own memory verses"
  ON memory_verses
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own memory verses
CREATE POLICY "Users can insert their own memory verses"
  ON memory_verses
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own memory verses
CREATE POLICY "Users can update their own memory verses"
  ON memory_verses
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own memory verses
CREATE POLICY "Users can delete their own memory verses"
  ON memory_verses
  FOR DELETE
  USING (auth.uid() = user_id);

-- =====================================================
-- RLS POLICIES: review_sessions
-- =====================================================

-- Policy: Users can view their own review sessions
CREATE POLICY "Users can view their own review sessions"
  ON review_sessions
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own review sessions
CREATE POLICY "Users can insert their own review sessions"
  ON review_sessions
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users cannot update review sessions (immutable audit log)
-- No UPDATE policy - review sessions are immutable once created

-- Policy: Users can delete their own review sessions (for data cleanup)
CREATE POLICY "Users can delete their own review sessions"
  ON review_sessions
  FOR DELETE
  USING (auth.uid() = user_id);

-- =====================================================
-- RLS POLICIES: review_history
-- =====================================================

-- Policy: Users can view their own review history
CREATE POLICY "Users can view their own review history"
  ON review_history
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own review history
CREATE POLICY "Users can insert their own review history"
  ON review_history
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own review history (for aggregation updates)
CREATE POLICY "Users can update their own review history"
  ON review_history
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own review history
CREATE POLICY "Users can delete their own review history"
  ON review_history
  FOR DELETE
  USING (auth.uid() = user_id);

-- =====================================================
-- TRIGGERS
-- Auto-update updated_at timestamp
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_memory_verses_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for memory_verses table
CREATE TRIGGER trigger_memory_verses_updated_at
  BEFORE UPDATE ON memory_verses
  FOR EACH ROW
  EXECUTE FUNCTION update_memory_verses_updated_at();

-- =====================================================
-- GRANTS
-- Ensure authenticated users have necessary permissions
-- =====================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON memory_verses TO authenticated;
GRANT SELECT, INSERT, DELETE ON review_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON review_history TO authenticated;

-- Grant sequence permissions for serial IDs (if any)
-- Note: Using UUID, so no sequences needed

-- =====================================================
-- VALIDATION FUNCTIONS
-- Helper functions for data integrity
-- =====================================================

-- Function to validate SM-2 quality rating
CREATE OR REPLACE FUNCTION validate_sm2_quality_rating(rating INTEGER)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN rating >= 0 AND rating <= 5;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION validate_sm2_quality_rating IS 'Validates SM-2 quality rating is between 0 and 5';

-- =====================================================
-- ANALYTICS FUNCTIONS
-- Helper functions for statistics and reporting
-- =====================================================

-- Function to get total memory verses count for user
CREATE OR REPLACE FUNCTION get_user_memory_verses_count(p_user_id UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM memory_verses
    WHERE user_id = p_user_id
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION get_user_memory_verses_count IS 'Returns total number of memory verses for a user';

-- Function to get due verses count for user
CREATE OR REPLACE FUNCTION get_user_due_verses_count(p_user_id UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM memory_verses
    WHERE user_id = p_user_id
      AND next_review_date <= NOW()
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION get_user_due_verses_count IS 'Returns number of verses due for review';

-- Function to get reviews completed today
CREATE OR REPLACE FUNCTION get_user_reviews_today_count(p_user_id UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM review_sessions
    WHERE user_id = p_user_id
      AND review_date::DATE = CURRENT_DATE
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION get_user_reviews_today_count IS 'Returns number of reviews completed today';

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

-- Log successful migration
DO $$
BEGIN
  RAISE NOTICE 'Memory Verses SRS system created successfully';
  RAISE NOTICE 'Tables: memory_verses, review_sessions, review_history';
  RAISE NOTICE 'RLS policies: Enabled and configured';
  RAISE NOTICE 'Indexes: Optimized for common query patterns';
END $$;
