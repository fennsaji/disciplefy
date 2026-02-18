-- =====================================================
-- Consolidated Migration: Memory Verses System
-- =====================================================
-- Source: Merged 9 memory verse related migrations
-- Tables: 8 (memory_verses, review_sessions, review_history, daily_unlocked_modes,
--           memory_practice_modes, memory_verse_mastery,
--            memory_verse_collections, memory_verse_collection_items)
-- Description: Complete spaced repetition system (SM-2 algorithm) with daily unlocked
--              practice modes, tier-based limits, and topical verse collections
-- =====================================================

-- Dependencies: 0001_core_schema.sql (auth.users, user_notification_preferences),
--               0004_subscription_system.sql (subscriptions)

BEGIN;

-- =====================================================
-- SUMMARY: Migration creates complete memory verse system
-- Completed: 0001 (11 tables), 0002 (6 tables), 0003 (2 tables),
--            0004 (5 tables), 0005 (6 tables), 0006 (4 tables)
-- Now creating 0007 with memory verse infrastructure
-- =====================================================

-- =====================================================
-- PART 1: TABLES
-- =====================================================

-- -----------------------------------------------------
-- 1.1 Memory Verses Table
-- -----------------------------------------------------
-- Stores verses for spaced repetition with SM-2 algorithm

CREATE TABLE IF NOT EXISTS memory_verses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- User reference
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Verse content
  verse_reference TEXT NOT NULL,
  verse_text TEXT NOT NULL,
  language TEXT NOT NULL DEFAULT 'en',

  -- Source tracking
  source_type TEXT NOT NULL
    CHECK (source_type IN ('daily_verse', 'manual', 'ai_generated')),
  source_id UUID, -- Optional: references daily_verses_cache if from daily verse

  -- SM-2 Spaced Repetition Algorithm fields
  ease_factor NUMERIC(4,2) NOT NULL DEFAULT 2.5
    CHECK (ease_factor >= 1.3 AND ease_factor <= 3.0),
  interval_days INTEGER NOT NULL DEFAULT 1 CHECK (interval_days >= 0),
  repetitions INTEGER NOT NULL DEFAULT 0 CHECK (repetitions >= 0),
  next_review_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Review metadata
  added_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_reviewed TIMESTAMPTZ,
  total_reviews INTEGER NOT NULL DEFAULT 0 CHECK (total_reviews >= 0),

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_user_verse_language UNIQUE(user_id, verse_reference, language),
  CONSTRAINT valid_next_review CHECK (next_review_date >= added_date)
);

-- Indexes for memory_verses
CREATE INDEX IF NOT EXISTS idx_memory_verses_user_next_review
  ON memory_verses(user_id, next_review_date)
  WHERE next_review_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_memory_verses_source
  ON memory_verses(user_id, source_type, source_id);

CREATE INDEX IF NOT EXISTS idx_memory_verses_reference
  ON memory_verses(user_id, verse_reference);

CREATE INDEX IF NOT EXISTS idx_memory_verses_language
  ON memory_verses(user_id, language);

-- Comments
COMMENT ON TABLE memory_verses IS
  'Stores Bible verses for spaced repetition memorization with SM-2 algorithm metadata';
COMMENT ON COLUMN memory_verses.source_type IS
  'Origin of the verse: daily_verse (from Daily Verse feature), manual (user-added), ai_generated (AI-generated)';
COMMENT ON COLUMN memory_verses.ease_factor IS
  'SM-2 algorithm: ease factor for calculating next interval (1.3-3.0)';
COMMENT ON COLUMN memory_verses.interval_days IS
  'SM-2 algorithm: days until next review';
COMMENT ON COLUMN memory_verses.repetitions IS
  'SM-2 algorithm: number of consecutive successful reviews';
COMMENT ON COLUMN memory_verses.next_review_date IS
  'Scheduled date/time for next review';

-- -----------------------------------------------------
-- 1.2 Review Sessions Table (practice attempts)
-- -----------------------------------------------------
-- Stores individual practice attempts with quality ratings and performance metrics

CREATE TABLE IF NOT EXISTS review_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Foreign keys
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  memory_verse_id UUID NOT NULL REFERENCES memory_verses(id) ON DELETE CASCADE,

  -- Practice data
  practice_mode TEXT NOT NULL
    CHECK (practice_mode IN (
      'flip_card', 'type_it_out', 'cloze', 'first_letter',
      'progressive', 'word_scramble', 'word_bank', 'audio'
    )),
  review_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  quality_rating INTEGER NOT NULL CHECK (quality_rating BETWEEN 0 AND 5),

  -- Enhanced performance tracking
  confidence_rating INTEGER CHECK (confidence_rating BETWEEN 1 AND 5),
  accuracy_percentage NUMERIC(5,2) CHECK (accuracy_percentage BETWEEN 0 AND 100),
  hints_used INTEGER DEFAULT 0 CHECK (hints_used >= 0),

  -- SM-2 algorithm state after this practice
  new_ease_factor NUMERIC(4,2) NOT NULL CHECK (new_ease_factor >= 1.3),
  new_interval_days INTEGER NOT NULL CHECK (new_interval_days >= 0),
  new_repetitions INTEGER NOT NULL CHECK (new_repetitions >= 0),

  -- Performance tracking
  time_spent_seconds INTEGER CHECK (time_spent_seconds > 0),

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for review_sessions
CREATE INDEX IF NOT EXISTS idx_review_sessions_user_date
  ON review_sessions(user_id, review_date DESC);

CREATE INDEX IF NOT EXISTS idx_review_sessions_verse
  ON review_sessions(memory_verse_id, review_date DESC);

CREATE INDEX IF NOT EXISTS idx_review_sessions_mode
  ON review_sessions(user_id, practice_mode, review_date DESC);

-- Comments
COMMENT ON TABLE review_sessions IS
  'Records each individual practice session with quality rating, performance metrics, and resulting SM-2 state';
COMMENT ON COLUMN review_sessions.quality_rating IS
  'SM-2 quality rating: 0=complete blackout, 1=incorrect with correct answer seeming familiar, 2=incorrect but remembered, 3=correct with serious difficulty, 4=correct after hesitation, 5=perfect recall';
COMMENT ON COLUMN review_sessions.practice_mode IS
  'Practice mode used: flip_card, type_it_out, cloze, first_letter, progressive, word_scramble, word_bank, or audio';
COMMENT ON COLUMN review_sessions.confidence_rating IS
  'User self-assessment confidence (1-5), separate from SM-2 quality rating';
COMMENT ON COLUMN review_sessions.accuracy_percentage IS
  'Objective accuracy for typing/cloze modes (0-100)';
COMMENT ON COLUMN review_sessions.hints_used IS
  'Number of hints used during this practice session';
COMMENT ON COLUMN review_sessions.new_ease_factor IS
  'Ease factor calculated after this practice session';
COMMENT ON COLUMN review_sessions.new_interval_days IS
  'Interval calculated after this practice session';
COMMENT ON COLUMN review_sessions.new_repetitions IS
  'Repetition count after this practice session';

-- -----------------------------------------------------
-- 1.3 Review History Table
-- -----------------------------------------------------
-- Aggregates daily practice statistics per verse

CREATE TABLE IF NOT EXISTS review_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Foreign keys
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  memory_verse_id UUID NOT NULL REFERENCES memory_verses(id) ON DELETE CASCADE,

  -- Daily aggregation
  review_date DATE NOT NULL,
  reviews_count INTEGER NOT NULL DEFAULT 0 CHECK (reviews_count >= 0),
  average_quality NUMERIC(3,2) CHECK (average_quality BETWEEN 0 AND 5),

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_user_verse_date UNIQUE(user_id, memory_verse_id, review_date)
);

-- Indexes for review_history
CREATE INDEX IF NOT EXISTS idx_review_history_user_verse
  ON review_history(user_id, memory_verse_id, review_date DESC);

CREATE INDEX IF NOT EXISTS idx_review_history_user_date
  ON review_history(user_id, review_date DESC);

-- Comments
COMMENT ON TABLE review_history IS
  'Daily aggregated practice statistics for analytics and progress tracking';

-- -----------------------------------------------------
-- 1.4 Daily Unlocked Modes Table
-- -----------------------------------------------------
-- Fix: 20260117000001 - Implements tier-based daily unlocked mode limits per verse
-- Free: 1 unlocked mode per verse per day
-- Standard: 2 unlocked modes per verse per day
-- Plus: 3 unlocked modes per verse per day
-- Premium: All modes unlocked automatically

CREATE TABLE IF NOT EXISTS daily_unlocked_modes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  memory_verse_id UUID NOT NULL REFERENCES memory_verses(id) ON DELETE CASCADE,
  practice_date DATE NOT NULL DEFAULT CURRENT_DATE,
  unlocked_modes TEXT[] NOT NULL DEFAULT '{}', -- Array of unlocked mode names
  tier_at_time TEXT NOT NULL, -- Snapshot of user's tier when modes were unlocked
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Ensure one record per user per verse per day
  CONSTRAINT daily_unlocked_modes_unique
    UNIQUE(user_id, memory_verse_id, practice_date)
);

-- Indexes for daily_unlocked_modes
CREATE INDEX IF NOT EXISTS idx_daily_unlocked_modes_user_verse_date
  ON daily_unlocked_modes(user_id, memory_verse_id, practice_date);

CREATE INDEX IF NOT EXISTS idx_daily_unlocked_modes_date
  ON daily_unlocked_modes(practice_date);

-- Comments
COMMENT ON TABLE daily_unlocked_modes IS
  'Tracks which practice modes are unlocked per verse per user per day for tier-based daily limits';

-- -----------------------------------------------------
-- 1.5 Memory Verse Collections Table
-- -----------------------------------------------------
-- User-created topical collections of memory verses

CREATE TABLE IF NOT EXISTS memory_verse_collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT CHECK (category IN (
    'comfort', 'wisdom', 'promises', 'commands',
    'prophecy', 'gospel', 'prayer', 'custom'
  )),
  description TEXT,
  icon TEXT,
  color TEXT,
  verse_count INTEGER DEFAULT 0 CHECK (verse_count >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for memory_verse_collections
CREATE INDEX IF NOT EXISTS idx_memory_verse_collections_user_id
  ON memory_verse_collections(user_id);

CREATE INDEX IF NOT EXISTS idx_memory_verse_collections_category
  ON memory_verse_collections(category);

-- Comments
COMMENT ON TABLE memory_verse_collections IS
  'User-created topical collections of memory verses (comfort, wisdom, promises, etc.)';
COMMENT ON COLUMN memory_verse_collections.category IS
  'Collection category: comfort, wisdom, promises, commands, prophecy, gospel, prayer, or custom';
COMMENT ON COLUMN memory_verse_collections.verse_count IS
  'Automatically updated count of verses in this collection';

-- -----------------------------------------------------
-- 1.6 Memory Verse Collection Items Table
-- -----------------------------------------------------
-- Many-to-many relationship between collections and verses

CREATE TABLE IF NOT EXISTS memory_verse_collection_items (
  collection_id UUID NOT NULL REFERENCES memory_verse_collections(id) ON DELETE CASCADE,
  memory_verse_id UUID NOT NULL REFERENCES memory_verses(id) ON DELETE CASCADE,
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (collection_id, memory_verse_id)
);

-- Indexes for memory_verse_collection_items
CREATE INDEX IF NOT EXISTS idx_collection_items_collection_id
  ON memory_verse_collection_items(collection_id);

CREATE INDEX IF NOT EXISTS idx_collection_items_verse_id
  ON memory_verse_collection_items(memory_verse_id);

-- Comments
COMMENT ON TABLE memory_verse_collection_items IS
  'Many-to-many relationship between collections and verses with join date tracking';

-- -----------------------------------------------------
-- 1.5 Memory Verse Streaks Table
-- -----------------------------------------------------
-- Separate streak system for memory practice with freeze days and milestones
-- Source: 20251217000003_memory_verses_gamification_schema.sql

CREATE TABLE IF NOT EXISTS memory_verse_streaks (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  current_streak INTEGER DEFAULT 0 CHECK (current_streak >= 0),
  longest_streak INTEGER DEFAULT 0 CHECK (longest_streak >= 0),
  last_practice_date DATE,
  total_practice_days INTEGER DEFAULT 0 CHECK (total_practice_days >= 0),
  freeze_days_available INTEGER DEFAULT 0 CHECK (freeze_days_available >= 0),
  freeze_days_used INTEGER DEFAULT 0 CHECK (freeze_days_used >= 0),
  milestone_10_date TIMESTAMPTZ,
  milestone_30_date TIMESTAMPTZ,
  milestone_100_date TIMESTAMPTZ,
  milestone_365_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Indexes for memory_verse_streaks
CREATE INDEX IF NOT EXISTS idx_memory_verse_streaks_current_streak
  ON memory_verse_streaks(current_streak DESC);

CREATE INDEX IF NOT EXISTS idx_memory_verse_streaks_last_practice
  ON memory_verse_streaks(last_practice_date DESC);

-- Comments
COMMENT ON TABLE memory_verse_streaks IS
  'Separate streak system for memory verse practice with freeze days and milestones (10, 30, 100, 365 day achievements)';

-- -----------------------------------------------------
-- 1.6 Memory Daily Goals Table
-- -----------------------------------------------------
-- Daily practice targets with review and new verse goals
-- Source: 20251217000003_memory_verses_gamification_schema.sql

CREATE TABLE IF NOT EXISTS memory_daily_goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  goal_date DATE NOT NULL,
  target_reviews INTEGER DEFAULT 5 CHECK (target_reviews >= 0),
  completed_reviews INTEGER DEFAULT 0 CHECK (completed_reviews >= 0),
  target_new_verses INTEGER DEFAULT 1 CHECK (target_new_verses >= 0),
  added_new_verses INTEGER DEFAULT 0 CHECK (added_new_verses >= 0),
  goal_achieved BOOLEAN DEFAULT FALSE,
  bonus_xp_awarded INTEGER DEFAULT 0 CHECK (bonus_xp_awarded >= 0),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  CONSTRAINT unique_user_goal_date UNIQUE(user_id, goal_date)
);

-- Indexes for memory_daily_goals
CREATE INDEX IF NOT EXISTS idx_memory_daily_goals_user_id
  ON memory_daily_goals(user_id);

CREATE INDEX IF NOT EXISTS idx_memory_daily_goals_date
  ON memory_daily_goals(goal_date DESC);

CREATE INDEX IF NOT EXISTS idx_memory_daily_goals_achieved
  ON memory_daily_goals(goal_achieved) WHERE goal_achieved = TRUE;

-- Comments
COMMENT ON TABLE memory_daily_goals IS
  'Daily practice targets with review counts (default: 5) and new verse goals (default: 1) with XP bonus rewards';

-- =====================================================
-- PART 2: NOTIFICATION PREFERENCES
-- =====================================================
-- Fix: 20251122000001 - Add memory verse notification columns to user_notification_preferences

ALTER TABLE user_notification_preferences
  ADD COLUMN IF NOT EXISTS memory_verse_reminder_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS memory_verse_reminder_time TIME NOT NULL DEFAULT '09:00:00',
  ADD COLUMN IF NOT EXISTS memory_verse_overdue_enabled BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN user_notification_preferences.memory_verse_reminder_enabled IS
  'Enable daily reminder when user has memory verses due for review (sent at memory_verse_reminder_time)';
COMMENT ON COLUMN user_notification_preferences.memory_verse_reminder_time IS
  'Time of day (in users timezone) to send memory verse review reminder';
COMMENT ON COLUMN user_notification_preferences.memory_verse_overdue_enabled IS
  'Enable notification when memory verses become overdue for review';

-- =====================================================
-- PART 3: FUNCTIONS
-- =====================================================

-- -----------------------------------------------------
-- 3.1 Validation Functions
-- -----------------------------------------------------

CREATE OR REPLACE FUNCTION validate_sm2_quality_rating(rating INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN rating >= 0 AND rating <= 5;
END;
$$;

COMMENT ON FUNCTION validate_sm2_quality_rating IS
  'Validates SM-2 quality rating is between 0 and 5';

-- -----------------------------------------------------
-- 3.2 Analytics Functions
-- -----------------------------------------------------

CREATE OR REPLACE FUNCTION get_user_memory_verses_count(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM memory_verses
    WHERE user_id = p_user_id
  );
END;
$$;

COMMENT ON FUNCTION get_user_memory_verses_count IS
  'Returns total number of memory verses for a user';

CREATE OR REPLACE FUNCTION get_user_due_verses_count(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM memory_verses
    WHERE user_id = p_user_id
      AND next_review_date <= NOW()
  );
END;
$$;

COMMENT ON FUNCTION get_user_due_verses_count IS
  'Returns number of verses due for review';

CREATE OR REPLACE FUNCTION get_user_reviews_today_count(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM review_sessions
    WHERE user_id = p_user_id
      AND review_date::DATE = CURRENT_DATE
  );
END;
$$;

COMMENT ON FUNCTION get_user_reviews_today_count IS
  'Returns number of practice sessions completed today';

-- -----------------------------------------------------
-- 3.3 Calculate Comprehensive Mastery
-- -----------------------------------------------------
-- Calculates overall mastery score for a memory verse

CREATE OR REPLACE FUNCTION calculate_comprehensive_mastery(
  p_memory_verse_id UUID
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_ease_factor NUMERIC;
  v_repetitions INTEGER;
  v_interval_days INTEGER;
  v_total_reviews INTEGER;
  v_recent_quality NUMERIC;
  v_mastery_score NUMERIC;
BEGIN
  -- Get verse metadata
  SELECT ease_factor, repetitions, interval_days, total_reviews
  INTO v_ease_factor, v_repetitions, v_interval_days, v_total_reviews
  FROM memory_verses
  WHERE id = p_memory_verse_id;

  -- Get average quality from recent 5 sessions
  SELECT COALESCE(AVG(quality_rating), 0)
  INTO v_recent_quality
  FROM (
    SELECT quality_rating
    FROM review_sessions
    WHERE memory_verse_id = p_memory_verse_id
    ORDER BY review_date DESC
    LIMIT 5
  ) recent;

  -- Calculate comprehensive mastery score (0-100)
  -- Factors: ease factor (30%), repetitions (20%), interval (20%),
  --          total reviews (10%), recent quality (20%)
  v_mastery_score := (
    (LEAST(v_ease_factor - 1.3, 1.7) / 1.7 * 30) +  -- Ease factor contribution
    (LEAST(v_repetitions, 10) / 10.0 * 20) +         -- Repetitions contribution
    (LEAST(v_interval_days, 365) / 365.0 * 20) +     -- Interval contribution
    (LEAST(v_total_reviews, 50) / 50.0 * 10) +       -- Total reviews contribution
    (v_recent_quality / 5.0 * 20)                     -- Recent quality contribution
  );

  RETURN ROUND(v_mastery_score, 2);
END;
$$;

COMMENT ON FUNCTION calculate_comprehensive_mastery IS
  'Calculates comprehensive mastery score (0-100) for a memory verse based on SM-2 metrics and practice history';

-- -----------------------------------------------------
-- 3.4 Check Mode Unlock Status
-- -----------------------------------------------------
-- Fix: 20260117000001 - Checks if a practice mode can be unlocked

CREATE OR REPLACE FUNCTION check_mode_unlock_status(
  p_user_id UUID,
  p_memory_verse_id UUID,
  p_mode TEXT,
  p_tier TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_current_date DATE;
  v_unlocked_modes TEXT[];
  v_unlock_limit INTEGER;
  v_unlock_slots_used INTEGER;
  v_unlock_slots_remaining INTEGER;
  v_is_mode_unlocked BOOLEAN;
  v_can_unlock BOOLEAN;
  v_available_modes TEXT[];
BEGIN
  v_current_date := CURRENT_DATE;

  -- Define tier-based unlock limits
  v_unlock_limit := CASE
    WHEN p_tier = 'premium' THEN -1  -- Unlimited (all modes auto-unlocked)
    WHEN p_tier = 'plus' THEN 3
    WHEN p_tier = 'standard' THEN 2
    ELSE 1  -- free
  END;

  -- Define available mode pool based on tier
  v_available_modes := CASE
    WHEN p_tier = 'free' THEN ARRAY['flip_card', 'type_it_out']
    ELSE ARRAY['flip_card', 'type_it_out', 'cloze', 'first_letter',
                'progressive', 'word_scramble', 'word_bank', 'audio']
  END;

  -- Check if mode is in user's tier pool
  IF NOT (p_mode = ANY(v_available_modes)) THEN
    RETURN jsonb_build_object(
      'status', 'tier_locked',
      'mode', p_mode,
      'tier', p_tier,
      'available_modes', v_available_modes,
      'unlocked_modes', ARRAY[]::TEXT[],
      'unlock_slots_remaining', 0,
      'message', format('Mode %s is not available on %s plan. Upgrade to access advanced practice modes.',
                        p_mode, p_tier)
    );
  END IF;

  -- Premium users: all modes automatically unlocked
  IF v_unlock_limit = -1 THEN
    RETURN jsonb_build_object(
      'status', 'unlocked',
      'mode', p_mode,
      'tier', p_tier,
      'available_modes', v_available_modes,
      'unlocked_modes', v_available_modes,
      'unlock_slots_remaining', -1,
      'message', 'Premium: All modes unlocked'
    );
  END IF;

  -- Get current day's unlocked modes
  SELECT COALESCE(unlocked_modes, '{}')
  INTO v_unlocked_modes
  FROM daily_unlocked_modes
  WHERE user_id = p_user_id
    AND memory_verse_id = p_memory_verse_id
    AND practice_date = v_current_date;

  -- If no record exists, no modes unlocked yet
  IF NOT FOUND THEN
    v_unlocked_modes := '{}';
  END IF;

  -- Check if mode is already unlocked
  v_is_mode_unlocked := p_mode = ANY(v_unlocked_modes);

  IF v_is_mode_unlocked THEN
    RETURN jsonb_build_object(
      'status', 'unlocked',
      'mode', p_mode,
      'tier', p_tier,
      'available_modes', v_available_modes,
      'unlocked_modes', v_unlocked_modes,
      'unlock_slots_remaining', v_unlock_limit - array_length(v_unlocked_modes, 1),
      'message', format('Mode %s is already unlocked for today. Practice unlimited times!', p_mode)
    );
  END IF;

  -- Check if user has remaining unlock slots
  v_unlock_slots_used := array_length(v_unlocked_modes, 1);
  v_unlock_slots_remaining := v_unlock_limit - COALESCE(v_unlock_slots_used, 0);
  v_can_unlock := v_unlock_slots_remaining > 0;

  IF v_can_unlock THEN
    RETURN jsonb_build_object(
      'status', 'can_unlock',
      'mode', p_mode,
      'tier', p_tier,
      'available_modes', v_available_modes,
      'unlocked_modes', v_unlocked_modes,
      'unlock_slots_remaining', v_unlock_slots_remaining,
      'message', format('You can unlock %s mode (%s slot%s remaining today)',
                        p_mode, v_unlock_slots_remaining::TEXT,
                        CASE WHEN v_unlock_slots_remaining > 1 THEN 's' ELSE '' END)
    );
  ELSE
    RETURN jsonb_build_object(
      'status', 'unlock_limit_reached',
      'mode', p_mode,
      'tier', p_tier,
      'available_modes', v_available_modes,
      'unlocked_modes', v_unlocked_modes,
      'unlock_slots_remaining', 0,
      'unlock_limit', v_unlock_limit,
      'message', format('Daily unlock limit reached (%s/%s modes unlocked for this verse today). Upgrade for more modes!',
                        v_unlock_slots_used::TEXT, v_unlock_limit::TEXT)
    );
  END IF;
END;
$$;

COMMENT ON FUNCTION check_mode_unlock_status IS
  'Checks if a practice mode can be unlocked for a verse today. Returns status: tier_locked, unlocked, can_unlock, or unlock_limit_reached';

-- -----------------------------------------------------
-- 3.5 Unlock Practice Mode
-- -----------------------------------------------------
-- Fix: 20260117000001 - Unlocks a practice mode for a verse

CREATE OR REPLACE FUNCTION unlock_practice_mode(
  p_user_id UUID,
  p_memory_verse_id UUID,
  p_mode TEXT,
  p_tier TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_current_date DATE;
  v_unlock_status JSONB;
  v_unlocked_modes TEXT[];
  v_updated_modes TEXT[];
  v_unlock_limit INTEGER;
BEGIN
  v_current_date := CURRENT_DATE;

  -- First check if mode can be unlocked
  v_unlock_status := check_mode_unlock_status(p_user_id, p_memory_verse_id, p_mode, p_tier);

  -- If tier_locked, cannot unlock
  IF v_unlock_status->>'status' = 'tier_locked' THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'TIER_LOCKED',
      'message', v_unlock_status->>'message',
      'unlock_status', v_unlock_status
    );
  END IF;

  -- If already unlocked, return success (idempotent)
  IF v_unlock_status->>'status' = 'unlocked' THEN
    RETURN jsonb_build_object(
      'success', TRUE,
      'message', format('Mode %s is already unlocked', p_mode),
      'unlock_status', v_unlock_status
    );
  END IF;

  -- If unlock limit reached, cannot unlock
  IF v_unlock_status->>'status' = 'unlock_limit_reached' THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'UNLOCK_LIMIT_REACHED',
      'message', v_unlock_status->>'message',
      'unlock_status', v_unlock_status
    );
  END IF;

  -- Status is 'can_unlock', proceed to unlock
  -- Get current unlocked modes from database
  SELECT COALESCE(unlocked_modes, '{}')
  INTO v_unlocked_modes
  FROM daily_unlocked_modes
  WHERE user_id = p_user_id
    AND memory_verse_id = p_memory_verse_id
    AND practice_date = v_current_date;

  IF NOT FOUND THEN
    v_unlocked_modes := '{}';
  END IF;

  -- Add new mode to array
  v_updated_modes := array_append(v_unlocked_modes, p_mode);

  -- Get unlock limit for calculating remaining slots
  v_unlock_limit := CASE
    WHEN p_tier = 'premium' THEN -1
    WHEN p_tier = 'plus' THEN 3
    WHEN p_tier = 'standard' THEN 2
    ELSE 1
  END;

  -- Upsert: update if record exists for today, insert if not
  INSERT INTO daily_unlocked_modes (
    user_id,
    memory_verse_id,
    practice_date,
    unlocked_modes,
    tier_at_time,
    updated_at
  ) VALUES (
    p_user_id,
    p_memory_verse_id,
    v_current_date,
    v_updated_modes,
    p_tier,
    NOW()
  )
  ON CONFLICT (user_id, memory_verse_id, practice_date)
  DO UPDATE SET
    unlocked_modes = v_updated_modes,
    updated_at = NOW();

  -- Return success with updated status
  RETURN jsonb_build_object(
    'success', TRUE,
    'message', format('Mode %s unlocked successfully!', p_mode),
    'unlocked_modes', v_updated_modes,
    'unlock_slots_remaining', CASE
      WHEN v_unlock_limit = -1 THEN -1
      ELSE v_unlock_limit - array_length(v_updated_modes, 1)
    END
  );
END;
$$;

COMMENT ON FUNCTION unlock_practice_mode IS
  'Unlocks a practice mode for a verse today if user has remaining unlock slots. Returns success status and updated unlock information';

-- -----------------------------------------------------
-- 3.6 Cleanup Old Unlocked Modes
-- -----------------------------------------------------
-- Fix: 20260117000001 - Deletes old records for maintenance

CREATE OR REPLACE FUNCTION cleanup_old_unlocked_modes()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_deleted_count INTEGER;
BEGIN
  DELETE FROM daily_unlocked_modes
  WHERE practice_date < CURRENT_DATE - INTERVAL '30 days';

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  RETURN v_deleted_count;
END;
$$;

COMMENT ON FUNCTION cleanup_old_unlocked_modes IS
  'Deletes unlocked mode records older than 30 days. Should be run periodically for database maintenance';

-- -----------------------------------------------------
-- 3.7 Memory Verse Reminder Notifications
-- -----------------------------------------------------
-- Fix: 20251122000001 + 20251123000001 + 20260105000002 - Get users for reminder notifications

CREATE OR REPLACE FUNCTION get_memory_verse_reminder_notification_users(
  target_hour INTEGER,
  target_minute INTEGER
)
RETURNS TABLE (
  user_id UUID,
  fcm_token TEXT,
  timezone_offset_minutes INTEGER,
  platform VARCHAR(20),
  due_verse_count INTEGER,
  overdue_verse_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
BEGIN
  RETURN QUERY
  SELECT
    unp.user_id,
    unt.fcm_token,
    EXTRACT(TIMEZONE FROM NOW())::INTEGER / 60 AS timezone_offset_minutes,
    unt.platform,
    (
      SELECT COUNT(*)::INTEGER
      FROM memory_verses mv
      WHERE mv.user_id = unp.user_id  -- Fix: 20260105000002 - Explicit user_id reference
        AND mv.next_review_date <= NOW()
    ) AS due_verse_count,
    (
      SELECT COUNT(*)::INTEGER
      FROM memory_verses mv
      WHERE mv.user_id = unp.user_id  -- Fix: 20260105000002 - Explicit user_id reference
        AND mv.next_review_date < NOW() - INTERVAL '1 day'
    ) AS overdue_verse_count
  FROM user_notification_preferences unp
  INNER JOIN user_notification_tokens unt ON unt.user_id = unp.user_id
  WHERE unp.memory_verse_reminder_enabled = TRUE
    AND EXTRACT(HOUR FROM unp.memory_verse_reminder_time) = target_hour
    AND EXTRACT(MINUTE FROM unp.memory_verse_reminder_time) = target_minute
    AND EXISTS (
      SELECT 1
      FROM memory_verses mv
      WHERE mv.user_id = unp.user_id  -- Fix: 20260105000002 - Explicit user_id reference
        AND mv.next_review_date <= NOW()
    );
END;
$$;

COMMENT ON FUNCTION get_memory_verse_reminder_notification_users IS
  'Returns users who should receive memory verse reminder notifications at a specific time';

-- -----------------------------------------------------
-- 3.8 Get or Create Memory Streak
-- -----------------------------------------------------
-- Source: 20251217000004_memory_streak_functions.sql

CREATE OR REPLACE FUNCTION get_or_create_memory_streak(p_user_id UUID)
RETURNS TABLE (
  out_user_id UUID,
  out_current_streak INTEGER,
  out_longest_streak INTEGER,
  out_last_practice_date DATE,
  out_total_practice_days INTEGER,
  out_freeze_days_available INTEGER,
  out_freeze_days_used INTEGER,
  out_milestone_10_date TIMESTAMPTZ,
  out_milestone_30_date TIMESTAMPTZ,
  out_milestone_100_date TIMESTAMPTZ,
  out_milestone_365_date TIMESTAMPTZ,
  out_created_at TIMESTAMPTZ,
  out_updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Try to insert first with ON CONFLICT DO NOTHING (atomic, prevents race conditions)
  RETURN QUERY
  INSERT INTO memory_verse_streaks (user_id)
  VALUES (p_user_id)
  ON CONFLICT (user_id) DO NOTHING
  RETURNING
    user_id,
    current_streak,
    longest_streak,
    last_practice_date,
    total_practice_days,
    freeze_days_available,
    freeze_days_used,
    milestone_10_date,
    milestone_30_date,
    milestone_100_date,
    milestone_365_date,
    created_at,
    updated_at;

  -- If INSERT was skipped due to conflict, fetch existing row
  IF NOT FOUND THEN
    RETURN QUERY
    SELECT
      user_id,
      current_streak,
      longest_streak,
      last_practice_date,
      total_practice_days,
      freeze_days_available,
      freeze_days_used,
      milestone_10_date,
      milestone_30_date,
      milestone_100_date,
      milestone_365_date,
      created_at,
      updated_at
    FROM memory_verse_streaks
    WHERE user_id = p_user_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION get_or_create_memory_streak(UUID) TO authenticated;

COMMENT ON FUNCTION get_or_create_memory_streak IS
  'Gets or atomically creates a memory verse streak record for a user (prevents race conditions)';

-- =====================================================
-- PART 4: TRIGGERS
-- =====================================================

CREATE OR REPLACE FUNCTION update_memory_verses_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_memory_verses_updated_at
  BEFORE UPDATE ON memory_verses
  FOR EACH ROW
  EXECUTE FUNCTION update_memory_verses_updated_at();

CREATE TRIGGER trigger_daily_unlocked_modes_updated_at
  BEFORE UPDATE ON daily_unlocked_modes
  FOR EACH ROW
  EXECUTE FUNCTION update_memory_verses_updated_at();

-- =====================================================
-- PART 4.3: Additional Columns for memory_verses
-- =====================================================
-- Columns needed by submit-memory-practice Edge Function

ALTER TABLE memory_verses
  ADD COLUMN IF NOT EXISTS mastery_level TEXT DEFAULT 'beginner'
    CHECK (mastery_level IN ('beginner', 'intermediate', 'advanced', 'expert', 'master')),
  ADD COLUMN IF NOT EXISTS times_perfectly_recalled INTEGER NOT NULL DEFAULT 0
    CHECK (times_perfectly_recalled >= 0),
  ADD COLUMN IF NOT EXISTS preferred_practice_mode TEXT
    CHECK (preferred_practice_mode IN (
      'flip_card', 'type_it_out', 'cloze', 'first_letter',
      'progressive', 'word_scramble', 'word_bank', 'audio'
    ));

COMMENT ON COLUMN memory_verses.mastery_level IS
  'Overall mastery level: beginner, intermediate, advanced, expert, master';
COMMENT ON COLUMN memory_verses.times_perfectly_recalled IS
  'Number of times the verse was recalled perfectly (quality_rating = 5)';
COMMENT ON COLUMN memory_verses.preferred_practice_mode IS
  'Most recently used practice mode for this verse';

-- =====================================================
-- PART 4.4: Practice Mode Statistics Table
-- =====================================================
-- Aggregated per-user, per-verse, per-mode statistics
-- Used by submit-memory-practice and get-memory-statistics Edge Functions

CREATE TABLE IF NOT EXISTS memory_practice_modes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  memory_verse_id UUID NOT NULL REFERENCES memory_verses(id) ON DELETE CASCADE,
  mode_type TEXT NOT NULL CHECK (mode_type IN (
    'flip_card', 'type_it_out', 'cloze', 'first_letter',
    'progressive', 'word_scramble', 'word_bank', 'audio'
  )),
  times_practiced INTEGER NOT NULL DEFAULT 0 CHECK (times_practiced >= 0),
  success_rate NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (success_rate BETWEEN 0 AND 100),
  average_time_seconds INTEGER,
  is_favorite BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_user_verse_mode UNIQUE(user_id, memory_verse_id, mode_type)
);

CREATE INDEX IF NOT EXISTS idx_memory_practice_modes_user_verse
  ON memory_practice_modes(user_id, memory_verse_id);

CREATE INDEX IF NOT EXISTS idx_memory_practice_modes_user_mode
  ON memory_practice_modes(user_id, mode_type);

COMMENT ON TABLE memory_practice_modes IS
  'Aggregated statistics per user per verse per practice mode (success rate, count, avg time)';
COMMENT ON COLUMN memory_practice_modes.success_rate IS
  'Weighted average success rate (0-100): uses accuracy_percentage when available, else quality >= 3';
COMMENT ON COLUMN memory_practice_modes.times_practiced IS
  'Total number of practice sessions for this mode on this verse';

-- =====================================================
-- PART 4.5.a: Memory Verse Mastery Table
-- =====================================================
-- Overall mastery progress per user per verse across all modes

CREATE TABLE IF NOT EXISTS memory_verse_mastery (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  memory_verse_id UUID NOT NULL REFERENCES memory_verses(id) ON DELETE CASCADE,
  mastery_level TEXT NOT NULL DEFAULT 'beginner' CHECK (mastery_level IN (
    'beginner', 'intermediate', 'advanced', 'expert', 'master'
  )),
  mastery_percentage INTEGER NOT NULL DEFAULT 0 CHECK (mastery_percentage BETWEEN 0 AND 100),
  modes_mastered INTEGER NOT NULL DEFAULT 0 CHECK (modes_mastered >= 0),
  perfect_recalls INTEGER NOT NULL DEFAULT 0 CHECK (perfect_recalls >= 0),
  confidence_rating NUMERIC(3,2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_user_verse_mastery UNIQUE(user_id, memory_verse_id)
);

CREATE INDEX IF NOT EXISTS idx_memory_verse_mastery_user
  ON memory_verse_mastery(user_id);

CREATE INDEX IF NOT EXISTS idx_memory_verse_mastery_level
  ON memory_verse_mastery(user_id, mastery_level);

COMMENT ON TABLE memory_verse_mastery IS
  'Overall mastery progress per user per verse: aggregates across all practice modes';
COMMENT ON COLUMN memory_verse_mastery.modes_mastered IS
  'Number of practice modes mastered (80%+ success rate with 5+ practices)';
COMMENT ON COLUMN memory_verse_mastery.perfect_recalls IS
  'Cumulative count of perfect recalls (quality_rating = 5) across all modes';

-- =====================================================
-- PART 4.5: Suggested Verses (Curated Popular Verses)
-- =====================================================

-- Stores curated/popular Bible verses that users can easily add to their memory deck
CREATE TABLE IF NOT EXISTS suggested_verses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference TEXT NOT NULL,              -- "John 3:16" (English canonical reference)
  book TEXT NOT NULL,                   -- "John"
  chapter INTEGER NOT NULL,             -- 3
  verse_start INTEGER NOT NULL,         -- 16
  verse_end INTEGER,                    -- NULL for single verse, or end verse for ranges
  category TEXT NOT NULL CHECK (category IN (
    'salvation', 'comfort', 'strength', 'wisdom',
    'promise', 'guidance', 'faith', 'love'
  )),
  tags TEXT[] DEFAULT '{}',             -- Additional tags for filtering
  display_order INTEGER DEFAULT 0,      -- Order within category
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Multi-language support for suggested verses (EN, HI, ML)
CREATE TABLE IF NOT EXISTS suggested_verse_translations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  suggested_verse_id UUID NOT NULL REFERENCES suggested_verses(id) ON DELETE CASCADE,
  language_code TEXT NOT NULL CHECK (language_code IN ('en', 'hi', 'ml')),
  verse_text TEXT NOT NULL,             -- Full verse text in this language
  localized_reference TEXT NOT NULL,    -- Localized reference (e.g., "यूहन्ना 3:16")
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  CONSTRAINT unique_verse_language UNIQUE(suggested_verse_id, language_code)
);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_suggested_verses_category ON suggested_verses(category);
CREATE INDEX IF NOT EXISTS idx_suggested_verses_active ON suggested_verses(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_suggested_verses_display_order ON suggested_verses(category, display_order);
CREATE INDEX IF NOT EXISTS idx_suggested_verse_translations_verse_id ON suggested_verse_translations(suggested_verse_id);
CREATE INDEX IF NOT EXISTS idx_suggested_verse_translations_language ON suggested_verse_translations(language_code);

-- Table comments
COMMENT ON TABLE suggested_verses IS 'Curated popular Bible verses that users can easily add to their memory deck';
COMMENT ON TABLE suggested_verse_translations IS 'Multi-language translations for suggested verses (English, Hindi, Malayalam)';
COMMENT ON COLUMN suggested_verses.category IS 'Category for filtering: salvation, comfort, strength, wisdom, promise, guidance, faith, love';
COMMENT ON COLUMN suggested_verses.tags IS 'Additional tags for flexible filtering beyond category';
COMMENT ON COLUMN suggested_verses.display_order IS 'Order within category for consistent display';

-- =====================================================
-- PART 5: ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE memory_verses ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_unlocked_modes ENABLE ROW LEVEL SECURITY;
ALTER TABLE memory_verse_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE memory_verse_collection_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE memory_verse_streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE memory_daily_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE suggested_verses ENABLE ROW LEVEL SECURITY;
ALTER TABLE suggested_verse_translations ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------
-- 5.1 memory_verses Policies
-- -----------------------------------------------------

CREATE POLICY "Users can view their own memory verses"
  ON memory_verses FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own memory verses"
  ON memory_verses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own memory verses"
  ON memory_verses FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own memory verses"
  ON memory_verses FOR DELETE
  USING (auth.uid() = user_id);

-- -----------------------------------------------------
-- 5.2 review_sessions Policies
-- -----------------------------------------------------

CREATE POLICY "Users can view their own review sessions"
  ON review_sessions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own review sessions"
  ON review_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own review sessions"
  ON review_sessions FOR DELETE
  USING (auth.uid() = user_id);

-- No UPDATE policy - review sessions are immutable once created

-- -----------------------------------------------------
-- 5.3 review_history Policies
-- -----------------------------------------------------

CREATE POLICY "Users can view their own review history"
  ON review_history FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own review history"
  ON review_history FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own review history"
  ON review_history FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own review history"
  ON review_history FOR DELETE
  USING (auth.uid() = user_id);

-- -----------------------------------------------------
-- 5.4 daily_unlocked_modes Policies
-- -----------------------------------------------------

CREATE POLICY "Users can read/modify their own unlocked modes"
  ON daily_unlocked_modes FOR ALL
  USING (auth.uid() = user_id);

-- -----------------------------------------------------
-- 5.5 memory_verse_collections Policies
-- -----------------------------------------------------

CREATE POLICY "Users can view their own collections"
  ON memory_verse_collections FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own collections"
  ON memory_verse_collections FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own collections"
  ON memory_verse_collections FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own collections"
  ON memory_verse_collections FOR DELETE
  USING (auth.uid() = user_id);

-- -----------------------------------------------------
-- 5.6 memory_verse_collection_items Policies
-- -----------------------------------------------------

-- Access controlled through collection ownership
CREATE POLICY "Users can view items in their own collections"
  ON memory_verse_collection_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM memory_verse_collections
      WHERE id = collection_id AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can add items to their own collections"
  ON memory_verse_collection_items FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM memory_verse_collections
      WHERE id = collection_id AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can remove items from their own collections"
  ON memory_verse_collection_items FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM memory_verse_collections
      WHERE id = collection_id AND user_id = auth.uid()
    )
  );

-- -----------------------------------------------------
-- 5.7 memory_verse_streaks Policies
-- -----------------------------------------------------

DROP POLICY IF EXISTS "Users can read own memory streak" ON memory_verse_streaks;
CREATE POLICY "Users can read own memory streak"
  ON memory_verse_streaks FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own memory streak" ON memory_verse_streaks;
CREATE POLICY "Users can insert own memory streak"
  ON memory_verse_streaks FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own memory streak" ON memory_verse_streaks;
CREATE POLICY "Users can update own memory streak"
  ON memory_verse_streaks FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- -----------------------------------------------------
-- 5.8 memory_daily_goals Policies
-- -----------------------------------------------------

DROP POLICY IF EXISTS "Users can read own daily goals" ON memory_daily_goals;
CREATE POLICY "Users can read own daily goals"
  ON memory_daily_goals FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own daily goals" ON memory_daily_goals;
CREATE POLICY "Users can insert own daily goals"
  ON memory_daily_goals FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own daily goals" ON memory_daily_goals;
CREATE POLICY "Users can update own daily goals"
  ON memory_daily_goals FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- -----------------------------------------------------
-- 5.9 suggested_verses Policies (Public Read-Only)
-- -----------------------------------------------------

-- Everyone can read active suggested verses
CREATE POLICY "everyone_read_active_suggested_verses"
  ON suggested_verses FOR SELECT
  USING (is_active = TRUE);

-- Service role has full access
CREATE POLICY "service_role_suggested_verses_all"
  ON suggested_verses FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- -----------------------------------------------------
-- 5.10 suggested_verse_translations Policies (Public Read-Only)
-- -----------------------------------------------------

-- Everyone can read translations
CREATE POLICY "everyone_read_suggested_verse_translations"
  ON suggested_verse_translations FOR SELECT
  USING (TRUE);

-- Service role has full access
CREATE POLICY "service_role_suggested_verse_translations_all"
  ON suggested_verse_translations FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- -----------------------------------------------------
-- 5.11 memory_practice_modes Policies
-- -----------------------------------------------------

ALTER TABLE memory_practice_modes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own practice mode stats"
  ON memory_practice_modes FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own practice mode stats"
  ON memory_practice_modes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own practice mode stats"
  ON memory_practice_modes FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role can manage practice mode stats"
  ON memory_practice_modes FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- -----------------------------------------------------
-- 5.12 memory_verse_mastery Policies
-- -----------------------------------------------------

ALTER TABLE memory_verse_mastery ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own verse mastery"
  ON memory_verse_mastery FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own verse mastery"
  ON memory_verse_mastery FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own verse mastery"
  ON memory_verse_mastery FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role can manage verse mastery"
  ON memory_verse_mastery FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- PART 6: TRIGGERS
-- =====================================================

-- -----------------------------------------------------
-- 6.1 Trigger: Update Collection Verse Count
-- -----------------------------------------------------

CREATE OR REPLACE FUNCTION update_collection_verse_count()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE memory_verse_collections
    SET verse_count = verse_count + 1,
        updated_at = NOW()
    WHERE id = NEW.collection_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE memory_verse_collections
    SET verse_count = verse_count - 1,
        updated_at = NOW()
    WHERE id = OLD.collection_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_update_collection_verse_count
  AFTER INSERT OR DELETE ON memory_verse_collection_items
  FOR EACH ROW
  EXECUTE FUNCTION update_collection_verse_count();

COMMENT ON FUNCTION update_collection_verse_count IS
  'Automatically updates verse_count when items are added/removed from collections';

-- -----------------------------------------------------
-- 6.2 Trigger: Update Collections updated_at
-- -----------------------------------------------------

CREATE OR REPLACE FUNCTION update_collections_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_memory_verse_collections_updated_at
  BEFORE UPDATE ON memory_verse_collections
  FOR EACH ROW
  EXECUTE FUNCTION update_collections_updated_at();

-- =====================================================
-- PART 7: GRANTS
-- =====================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON memory_verses TO authenticated;
GRANT SELECT, INSERT, DELETE ON review_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON review_history TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON daily_unlocked_modes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON memory_verse_collections TO authenticated;
GRANT SELECT, INSERT, DELETE ON memory_verse_collection_items TO authenticated;

GRANT SELECT, INSERT, UPDATE ON memory_practice_modes TO authenticated;
GRANT SELECT, INSERT, UPDATE ON memory_verse_mastery TO authenticated;

GRANT EXECUTE ON FUNCTION validate_sm2_quality_rating TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_user_memory_verses_count TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_user_due_verses_count TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_user_reviews_today_count TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION calculate_comprehensive_mastery TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION check_mode_unlock_status TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION unlock_practice_mode TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION cleanup_old_unlocked_modes TO service_role;
GRANT EXECUTE ON FUNCTION get_memory_verse_reminder_notification_users TO service_role;

-- =====================================================
-- PART 7.1: user_subscriptions VIEW
-- =====================================================
-- Provides a simplified view of subscriptions with tier name
-- Used by Edge Functions that query user_subscriptions.tier

CREATE OR REPLACE VIEW user_subscriptions AS
SELECT
  s.id,
  s.user_id,
  s.provider,
  s.provider_subscription_id,
  s.plan_id,
  sp.plan_code AS tier,
  s.status,
  s.plan_type,
  s.current_period_start,
  s.current_period_end,
  s.cancel_at_cycle_end,
  s.metadata,
  s.created_at,
  s.updated_at
FROM subscriptions s
LEFT JOIN subscription_plans sp ON s.plan_id = sp.id;

COMMENT ON VIEW user_subscriptions IS
  'Convenience view of subscriptions with tier (plan_code) exposed for Edge Function queries';

GRANT SELECT ON user_subscriptions TO authenticated, service_role;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
BEGIN
  -- Verify tables
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'memory_verses') THEN
    RAISE EXCEPTION 'Migration failed: memory_verses table not created';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'review_sessions') THEN
    RAISE EXCEPTION 'Migration failed: review_sessions table not created';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'review_history') THEN
    RAISE EXCEPTION 'Migration failed: review_history table not created';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'daily_unlocked_modes') THEN
    RAISE EXCEPTION 'Migration failed: daily_unlocked_modes table not created';
  END IF;

  -- Verify key columns added to user_notification_preferences
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_notification_preferences'
      AND column_name = 'memory_verse_reminder_enabled'
  ) THEN
    RAISE EXCEPTION 'Migration failed: memory_verse_reminder_enabled column not added';
  END IF;

  -- Verify functions
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_mode_unlock_status') THEN
    RAISE EXCEPTION 'Migration failed: check_mode_unlock_status function not created';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'unlock_practice_mode') THEN
    RAISE EXCEPTION 'Migration failed: unlock_practice_mode function not created';
  END IF;

  RAISE NOTICE 'Migration 0007_memory_system.sql completed successfully - review_sessions, memory_practice_modes, memory_verse_mastery, user_subscriptions view, 9 functions';
END $$;

COMMIT;

-- =====================================================
-- POST-MIGRATION NOTES
-- =====================================================
--
-- This migration creates the complete memory verses spaced repetition
-- system with tier-based daily unlocked practice modes.
--
-- Key Features:
-- - SM-2 Spaced Repetition Algorithm for optimal memory retention
-- - 8 practice modes: flip_card, type_it_out, cloze, first_letter,
--   progressive, word_scramble, word_bank, audio
-- - Tier-based daily unlock limits (Free=1, Standard=2, Plus=3, Premium=all)
-- - Comprehensive mastery calculation
-- - Daily reminder notifications for due verses
--
-- Recommended Cron Jobs:
-- 1. Cleanup old unlocked modes (monthly):
--    SELECT cleanup_old_unlocked_modes();
--
-- 2. Send daily reminder notifications (hourly):
--    SELECT * FROM get_memory_verse_reminder_notification_users(9, 0);
-- =====================================================
