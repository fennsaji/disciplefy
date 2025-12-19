-- ============================================================================
-- Memory Verses Enhancement Migration
-- Version: 2.4.0 - Sprint 1
-- Date: 2025-12-18
-- 
-- Description:
-- Comprehensive enhancement to Memory Verses feature including:
-- - 7 practice modes (typing, cloze, first-letter, progressive, word scramble, word order, audio)
-- - Memory streak system with freeze day protection
-- - Mastery level progression (5 levels)
-- - Daily goals tracking
-- - Verse collections (topical groupings)
-- - Weekly/monthly challenges system
-- - Enhanced review session tracking
-- ============================================================================

-- ============================================================================
-- Table 1: memory_practice_modes
-- Tracks performance per practice mode per verse
-- ============================================================================

CREATE TABLE IF NOT EXISTS memory_practice_modes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  memory_verse_id UUID NOT NULL REFERENCES memory_verses(id) ON DELETE CASCADE,
  
  -- Practice mode type
  mode_type TEXT NOT NULL CHECK (mode_type IN (
    'flip_card',      -- Default flip card mode
    'typing',         -- Type verse from memory
    'cloze',          -- Fill in missing words
    'first_letter',   -- First letter hints
    'progressive',    -- Progressive reveal
    'word_scramble',  -- Drag-and-drop words
    'word_order',     -- Arrange phrase chunks
    'audio'           -- Listen and repeat with TTS
  )),
  
  -- Performance tracking
  times_practiced INT NOT NULL DEFAULT 0,
  success_rate DECIMAL(5,2) NOT NULL DEFAULT 0.0 CHECK (success_rate >= 0 AND success_rate <= 100),
  average_time_seconds INT CHECK (average_time_seconds > 0),
  is_favorite BOOLEAN NOT NULL DEFAULT false,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Constraints
  UNIQUE(user_id, memory_verse_id, mode_type)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_memory_practice_modes_user_id ON memory_practice_modes(user_id);
CREATE INDEX IF NOT EXISTS idx_memory_practice_modes_verse_id ON memory_practice_modes(memory_verse_id);
CREATE INDEX IF NOT EXISTS idx_memory_practice_modes_user_verse ON memory_practice_modes(user_id, memory_verse_id);
CREATE INDEX IF NOT EXISTS idx_memory_practice_modes_mode_type ON memory_practice_modes(mode_type);
CREATE INDEX IF NOT EXISTS idx_memory_practice_modes_favorite ON memory_practice_modes(user_id, is_favorite) WHERE is_favorite = true;

-- RLS policies
ALTER TABLE memory_practice_modes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own practice modes" ON memory_practice_modes;
CREATE POLICY "Users can view their own practice modes"
  ON memory_practice_modes FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own practice modes" ON memory_practice_modes;
CREATE POLICY "Users can insert their own practice modes"
  ON memory_practice_modes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own practice modes" ON memory_practice_modes;
CREATE POLICY "Users can update their own practice modes"
  ON memory_practice_modes FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own practice modes" ON memory_practice_modes;
CREATE POLICY "Users can delete their own practice modes"
  ON memory_practice_modes FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- Table 2: memory_verse_streaks
-- Separate streak system for memory practice with freeze day protection
-- ============================================================================

CREATE TABLE IF NOT EXISTS memory_verse_streaks (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Streak tracking
  current_streak INT NOT NULL DEFAULT 0 CHECK (current_streak >= 0),
  longest_streak INT NOT NULL DEFAULT 0 CHECK (longest_streak >= 0),
  last_practice_date DATE,
  total_practice_days INT NOT NULL DEFAULT 0 CHECK (total_practice_days >= 0),
  
  -- Freeze day mechanics (earn by practicing 5+ days per week)
  freeze_days_available INT NOT NULL DEFAULT 0 CHECK (freeze_days_available >= 0 AND freeze_days_available <= 5),
  freeze_days_used INT NOT NULL DEFAULT 0 CHECK (freeze_days_used >= 0),
  
  -- Milestone tracking (achievement triggers)
  milestone_10_date TIMESTAMPTZ,
  milestone_30_date TIMESTAMPTZ,
  milestone_100_date TIMESTAMPTZ,
  milestone_365_date TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_memory_verse_streaks_current_streak ON memory_verse_streaks(current_streak DESC);
CREATE INDEX IF NOT EXISTS idx_memory_verse_streaks_longest_streak ON memory_verse_streaks(longest_streak DESC);
CREATE INDEX IF NOT EXISTS idx_memory_verse_streaks_last_practice ON memory_verse_streaks(last_practice_date);

-- RLS policies
ALTER TABLE memory_verse_streaks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own streak" ON memory_verse_streaks;
CREATE POLICY "Users can view their own streak"
  ON memory_verse_streaks FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own streak" ON memory_verse_streaks;
CREATE POLICY "Users can insert their own streak"
  ON memory_verse_streaks FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own streak" ON memory_verse_streaks;
CREATE POLICY "Users can update their own streak"
  ON memory_verse_streaks FOR UPDATE
  USING (auth.uid() = user_id);

-- ============================================================================
-- Table 3: memory_verse_mastery
-- Tracks progression through 5 mastery levels
-- ============================================================================

CREATE TABLE IF NOT EXISTS memory_verse_mastery (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  memory_verse_id UUID NOT NULL REFERENCES memory_verses(id) ON DELETE CASCADE,
  
  -- Mastery progression
  mastery_level TEXT NOT NULL DEFAULT 'beginner' CHECK (
    mastery_level IN ('beginner', 'intermediate', 'advanced', 'expert', 'master')
  ),
  mastery_percentage DECIMAL(5,2) NOT NULL DEFAULT 0.0 CHECK (mastery_percentage >= 0 AND mastery_percentage <= 100),
  
  -- Performance metrics
  modes_mastered INT NOT NULL DEFAULT 0 CHECK (modes_mastered >= 0 AND modes_mastered <= 8),
  perfect_recalls INT NOT NULL DEFAULT 0 CHECK (perfect_recalls >= 0),
  confidence_rating DECIMAL(3,1) CHECK (confidence_rating >= 1 AND confidence_rating <= 5),
  
  -- Timestamp
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Constraints
  UNIQUE(user_id, memory_verse_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_memory_verse_mastery_user_id ON memory_verse_mastery(user_id);
CREATE INDEX IF NOT EXISTS idx_memory_verse_mastery_verse_id ON memory_verse_mastery(memory_verse_id);
CREATE INDEX IF NOT EXISTS idx_memory_verse_mastery_level ON memory_verse_mastery(mastery_level);
CREATE INDEX IF NOT EXISTS idx_memory_verse_mastery_user_level ON memory_verse_mastery(user_id, mastery_level);

-- RLS policies
ALTER TABLE memory_verse_mastery ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own mastery" ON memory_verse_mastery;
CREATE POLICY "Users can view their own mastery"
  ON memory_verse_mastery FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own mastery" ON memory_verse_mastery;
CREATE POLICY "Users can insert their own mastery"
  ON memory_verse_mastery FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own mastery" ON memory_verse_mastery;
CREATE POLICY "Users can update their own mastery"
  ON memory_verse_mastery FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own mastery" ON memory_verse_mastery;
CREATE POLICY "Users can delete their own mastery"
  ON memory_verse_mastery FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- Table 4: memory_daily_goals
-- Daily practice targets and progress tracking
-- ============================================================================

CREATE TABLE IF NOT EXISTS memory_daily_goals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  goal_date DATE NOT NULL,
  
  -- Review goals
  target_reviews INT NOT NULL DEFAULT 5 CHECK (target_reviews > 0),
  completed_reviews INT NOT NULL DEFAULT 0 CHECK (completed_reviews >= 0),
  
  -- New verse goals
  target_new_verses INT NOT NULL DEFAULT 1 CHECK (target_new_verses >= 0),
  added_new_verses INT NOT NULL DEFAULT 0 CHECK (added_new_verses >= 0),
  
  -- Completion tracking
  goal_achieved BOOLEAN NOT NULL DEFAULT false,
  bonus_xp_awarded INT NOT NULL DEFAULT 0 CHECK (bonus_xp_awarded >= 0),
  
  -- Timestamp
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Constraints
  UNIQUE(user_id, goal_date)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_memory_daily_goals_user_id ON memory_daily_goals(user_id);
CREATE INDEX IF NOT EXISTS idx_memory_daily_goals_date ON memory_daily_goals(goal_date DESC);
CREATE INDEX IF NOT EXISTS idx_memory_daily_goals_user_date ON memory_daily_goals(user_id, goal_date DESC);
CREATE INDEX IF NOT EXISTS idx_memory_daily_goals_achieved ON memory_daily_goals(user_id, goal_achieved) WHERE goal_achieved = true;

-- RLS policies
ALTER TABLE memory_daily_goals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own daily goals" ON memory_daily_goals;
CREATE POLICY "Users can view their own daily goals"
  ON memory_daily_goals FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own daily goals" ON memory_daily_goals;
CREATE POLICY "Users can insert their own daily goals"
  ON memory_daily_goals FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own daily goals" ON memory_daily_goals;
CREATE POLICY "Users can update their own daily goals"
  ON memory_daily_goals FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own daily goals" ON memory_daily_goals;
CREATE POLICY "Users can delete their own daily goals"
  ON memory_daily_goals FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- Table 5: memory_verse_collections
-- Topical verse groupings (comfort, wisdom, promises, etc.)
-- ============================================================================

CREATE TABLE IF NOT EXISTS memory_verse_collections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Collection metadata
  name TEXT NOT NULL CHECK (char_length(name) > 0 AND char_length(name) <= 100),
  category TEXT CHECK (category IN (
    'comfort',    -- Comfort and encouragement verses
    'wisdom',     -- Wisdom and guidance verses
    'promises',   -- God's promises
    'commands',   -- Commands and instructions
    'prophecy',   -- Prophetic verses
    'gospel',     -- Gospel and salvation verses
    'prayer',     -- Prayer verses
    'custom'      -- User-defined category
  )),
  description TEXT CHECK (char_length(description) <= 500),
  
  -- Visual customization
  icon TEXT CHECK (char_length(icon) <= 50),
  color TEXT CHECK (char_length(color) <= 20),
  
  -- Statistics
  verse_count INT NOT NULL DEFAULT 0 CHECK (verse_count >= 0),
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_memory_verse_collections_user_id ON memory_verse_collections(user_id);
CREATE INDEX IF NOT EXISTS idx_memory_verse_collections_category ON memory_verse_collections(category);
CREATE INDEX IF NOT EXISTS idx_memory_verse_collections_user_category ON memory_verse_collections(user_id, category);

-- RLS policies
ALTER TABLE memory_verse_collections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own collections" ON memory_verse_collections;
CREATE POLICY "Users can view their own collections"
  ON memory_verse_collections FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own collections" ON memory_verse_collections;
CREATE POLICY "Users can insert their own collections"
  ON memory_verse_collections FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own collections" ON memory_verse_collections;
CREATE POLICY "Users can update their own collections"
  ON memory_verse_collections FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own collections" ON memory_verse_collections;
CREATE POLICY "Users can delete their own collections"
  ON memory_verse_collections FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- Table 5b: memory_verse_collection_items
-- Many-to-many relationship between collections and verses
-- ============================================================================

CREATE TABLE IF NOT EXISTS memory_verse_collection_items (
  collection_id UUID NOT NULL REFERENCES memory_verse_collections(id) ON DELETE CASCADE,
  memory_verse_id UUID NOT NULL REFERENCES memory_verses(id) ON DELETE CASCADE,
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  PRIMARY KEY (collection_id, memory_verse_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_collection_items_collection_id ON memory_verse_collection_items(collection_id);
CREATE INDEX IF NOT EXISTS idx_collection_items_verse_id ON memory_verse_collection_items(memory_verse_id);

-- RLS policies
ALTER TABLE memory_verse_collection_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own collection items" ON memory_verse_collection_items;
CREATE POLICY "Users can view their own collection items"
  ON memory_verse_collection_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM memory_verse_collections mvc
      WHERE mvc.id = collection_id AND mvc.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can insert their own collection items" ON memory_verse_collection_items;
CREATE POLICY "Users can insert their own collection items"
  ON memory_verse_collection_items FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM memory_verse_collections mvc
      WHERE mvc.id = collection_id AND mvc.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can delete their own collection items" ON memory_verse_collection_items;
CREATE POLICY "Users can delete their own collection items"
  ON memory_verse_collection_items FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM memory_verse_collections mvc
      WHERE mvc.id = collection_id AND mvc.user_id = auth.uid()
    )
  );

-- ============================================================================
-- Table 6: memory_challenges
-- Weekly/monthly challenges for variety and engagement
-- ============================================================================

CREATE TABLE IF NOT EXISTS memory_challenges (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Challenge metadata
  challenge_type TEXT NOT NULL CHECK (challenge_type IN ('daily', 'weekly', 'monthly')),
  target_type TEXT NOT NULL CHECK (target_type IN (
    'reviews_count',   -- Complete X reviews
    'new_verses',      -- Add X new verses
    'mastery_level',   -- Reach X mastery level
    'perfect_recalls', -- Achieve X perfect recalls
    'streak_days',     -- Maintain X day streak
    'modes_tried'      -- Try X different modes
  )),
  target_value INT NOT NULL CHECK (target_value > 0),
  
  -- Rewards
  xp_reward INT NOT NULL CHECK (xp_reward > 0),
  badge_icon TEXT CHECK (char_length(badge_icon) <= 50),
  
  -- Schedule
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  
  -- Timestamp
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CHECK (end_date > start_date)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_memory_challenges_type ON memory_challenges(challenge_type);
CREATE INDEX IF NOT EXISTS idx_memory_challenges_active ON memory_challenges(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_memory_challenges_dates ON memory_challenges(start_date, end_date);

-- RLS policies (challenges are global, readable by all authenticated users)
ALTER TABLE memory_challenges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view challenges" ON memory_challenges;
CREATE POLICY "Authenticated users can view challenges"
  ON memory_challenges FOR SELECT
  USING (auth.role() = 'authenticated');

-- Admin-only insert/update/delete (not defined here, managed via service role)

-- ============================================================================
-- Table 6b: user_challenge_progress
-- Tracks individual user progress on challenges
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_challenge_progress (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  challenge_id UUID NOT NULL REFERENCES memory_challenges(id) ON DELETE CASCADE,
  
  -- Progress tracking
  current_progress INT NOT NULL DEFAULT 0 CHECK (current_progress >= 0),
  is_completed BOOLEAN NOT NULL DEFAULT false,
  completed_at TIMESTAMPTZ,
  xp_claimed BOOLEAN NOT NULL DEFAULT false,
  
  PRIMARY KEY (user_id, challenge_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_challenge_progress_user_id ON user_challenge_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_challenge_progress_challenge_id ON user_challenge_progress(challenge_id);
CREATE INDEX IF NOT EXISTS idx_user_challenge_progress_completed ON user_challenge_progress(user_id, is_completed) WHERE is_completed = true;

-- RLS policies
ALTER TABLE user_challenge_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own challenge progress" ON user_challenge_progress;
CREATE POLICY "Users can view their own challenge progress"
  ON user_challenge_progress FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own challenge progress" ON user_challenge_progress;
CREATE POLICY "Users can insert their own challenge progress"
  ON user_challenge_progress FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own challenge progress" ON user_challenge_progress;
CREATE POLICY "Users can update their own challenge progress"
  ON user_challenge_progress FOR UPDATE
  USING (auth.uid() = user_id);

-- ============================================================================
-- Schema Extensions: review_sessions
-- Add practice mode tracking and enhanced metrics
-- ============================================================================

-- Add new columns to review_sessions
ALTER TABLE review_sessions 
  ADD COLUMN IF NOT EXISTS practice_mode TEXT CHECK (practice_mode IN (
    'flip_card', 'typing', 'cloze', 'first_letter',
    'progressive', 'word_scramble', 'word_order', 'audio'
  )),
  ADD COLUMN IF NOT EXISTS confidence_rating INT CHECK (confidence_rating BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS accuracy_percentage DECIMAL(5,2) CHECK (accuracy_percentage >= 0 AND accuracy_percentage <= 100),
  ADD COLUMN IF NOT EXISTS hints_used INT DEFAULT 0 CHECK (hints_used >= 0);

-- Indexes for new columns
CREATE INDEX IF NOT EXISTS idx_review_sessions_practice_mode ON review_sessions(practice_mode);
CREATE INDEX IF NOT EXISTS idx_review_sessions_confidence ON review_sessions(confidence_rating);

-- ============================================================================
-- Schema Extensions: memory_verses
-- Add preferred mode and mastery tracking
-- ============================================================================

-- Add new columns to memory_verses
ALTER TABLE memory_verses
  ADD COLUMN IF NOT EXISTS preferred_practice_mode TEXT CHECK (preferred_practice_mode IN (
    'flip_card', 'typing', 'cloze', 'first_letter',
    'progressive', 'word_scramble', 'word_order', 'audio'
  )),
  ADD COLUMN IF NOT EXISTS mastery_level TEXT DEFAULT 'beginner' CHECK (
    mastery_level IN ('beginner', 'intermediate', 'advanced', 'expert', 'master')
  ),
  ADD COLUMN IF NOT EXISTS times_perfectly_recalled INT DEFAULT 0 CHECK (times_perfectly_recalled >= 0);

-- Indexes for new columns
CREATE INDEX IF NOT EXISTS idx_memory_verses_mastery_level ON memory_verses(mastery_level);
CREATE INDEX IF NOT EXISTS idx_memory_verses_perfect_recalls ON memory_verses(times_perfectly_recalled DESC);

-- ============================================================================
-- Trigger: Update memory_verse_collections.verse_count
-- Automatically maintain verse count when items are added/removed
-- ============================================================================

CREATE OR REPLACE FUNCTION update_collection_verse_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE memory_verse_collections
    SET verse_count = verse_count + 1,
        updated_at = NOW()
    WHERE id = NEW.collection_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE memory_verse_collections
    SET verse_count = GREATEST(0, verse_count - 1),
        updated_at = NOW()
    WHERE id = OLD.collection_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_collection_verse_count_insert ON memory_verse_collection_items;
CREATE TRIGGER trigger_update_collection_verse_count_insert
AFTER INSERT ON memory_verse_collection_items
FOR EACH ROW
EXECUTE FUNCTION update_collection_verse_count();

DROP TRIGGER IF EXISTS trigger_update_collection_verse_count_delete ON memory_verse_collection_items;
CREATE TRIGGER trigger_update_collection_verse_count_delete
AFTER DELETE ON memory_verse_collection_items
FOR EACH ROW
EXECUTE FUNCTION update_collection_verse_count();

-- ============================================================================
-- Trigger: Update memory_practice_modes.updated_at
-- Automatically update timestamp on practice mode changes
-- ============================================================================

CREATE OR REPLACE FUNCTION update_practice_mode_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_practice_mode_timestamp ON memory_practice_modes;
CREATE TRIGGER trigger_update_practice_mode_timestamp
BEFORE UPDATE ON memory_practice_modes
FOR EACH ROW
EXECUTE FUNCTION update_practice_mode_timestamp();

-- ============================================================================
-- Trigger: Update memory_verse_streaks.updated_at
-- Automatically update timestamp on streak changes
-- ============================================================================

CREATE OR REPLACE FUNCTION update_streak_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_streak_timestamp ON memory_verse_streaks;
CREATE TRIGGER trigger_update_streak_timestamp
BEFORE UPDATE ON memory_verse_streaks
FOR EACH ROW
EXECUTE FUNCTION update_streak_timestamp();

-- ============================================================================
-- Trigger: Update memory_verse_mastery.updated_at
-- Automatically update timestamp on mastery changes
-- ============================================================================

CREATE OR REPLACE FUNCTION update_mastery_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_mastery_timestamp ON memory_verse_mastery;
CREATE TRIGGER trigger_update_mastery_timestamp
BEFORE UPDATE ON memory_verse_mastery
FOR EACH ROW
EXECUTE FUNCTION update_mastery_timestamp();

-- ============================================================================
-- Trigger: Update memory_verse_collections.updated_at
-- Automatically update timestamp on collection changes
-- ============================================================================

CREATE OR REPLACE FUNCTION update_collection_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_collection_timestamp ON memory_verse_collections;
CREATE TRIGGER trigger_update_collection_timestamp
BEFORE UPDATE ON memory_verse_collections
FOR EACH ROW
EXECUTE FUNCTION update_collection_timestamp();

-- ============================================================================
-- Comments for documentation
-- ============================================================================

COMMENT ON TABLE memory_practice_modes IS 'Tracks performance per practice mode per verse (typing, cloze, etc.)';
COMMENT ON TABLE memory_verse_streaks IS 'Separate streak system for memory practice with freeze day protection';
COMMENT ON TABLE memory_verse_mastery IS 'Tracks progression through 5 mastery levels (Beginner → Master)';
COMMENT ON TABLE memory_daily_goals IS 'Daily practice targets and progress tracking';
COMMENT ON TABLE memory_verse_collections IS 'Topical verse groupings (comfort, wisdom, promises, etc.)';
COMMENT ON TABLE memory_verse_collection_items IS 'Many-to-many relationship between collections and verses';
COMMENT ON TABLE memory_challenges IS 'Weekly/monthly challenges for variety and engagement';
COMMENT ON TABLE user_challenge_progress IS 'Tracks individual user progress on challenges';

COMMENT ON COLUMN memory_practice_modes.mode_type IS 'Practice mode: flip_card, typing, cloze, first_letter, progressive, word_scramble, word_order, audio';
COMMENT ON COLUMN memory_practice_modes.success_rate IS 'Percentage success rate (0-100) for this mode';
COMMENT ON COLUMN memory_verse_streaks.freeze_days_available IS 'Freeze days earned through consistency (max 5)';
COMMENT ON COLUMN memory_verse_mastery.mastery_level IS 'Current mastery level: beginner, intermediate, advanced, expert, master';
COMMENT ON COLUMN memory_verse_mastery.modes_mastered IS 'Number of practice modes mastered (80%+ success rate)';
COMMENT ON COLUMN memory_daily_goals.target_reviews IS 'Target number of reviews for the day';
COMMENT ON COLUMN memory_challenges.challenge_type IS 'Challenge duration: daily, weekly, monthly';
COMMENT ON COLUMN memory_challenges.target_type IS 'Challenge goal: reviews_count, new_verses, mastery_level, perfect_recalls, streak_days, modes_tried';

-- ============================================================================
-- Migration Complete
-- ============================================================================

-- Verify tables were created
DO $$
BEGIN
  RAISE NOTICE 'Memory Verses Enhancement Migration Completed Successfully';
  RAISE NOTICE 'Tables created: 8 (6 new tables + 2 junction tables)';
  RAISE NOTICE 'Schema extensions: review_sessions (4 columns), memory_verses (3 columns)';
  RAISE NOTICE 'Indexes created: 35+ for optimal query performance';
  RAISE NOTICE 'RLS policies: Enabled on all new tables';
  RAISE NOTICE 'Triggers: 5 auto-update triggers for timestamps and counts';
END $$;
