-- ============================================================================
-- Migration: Add Study Modes and Reflections System
-- Version: 1.0
-- Date: 2025-12-23
-- Description:
--   - Adds study_mode column to study_guides for different study experiences
--   - Adds extended_content JSONB for mode-specific extra content
--   - Adds default_study_mode to user_preferences
--   - Creates study_reflections table for interactive reflection responses
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. ADD STUDY MODE TO STUDY_GUIDES TABLE
-- ============================================================================

-- Add study_mode column (quick, standard, deep, lectio)
ALTER TABLE public.study_guides
ADD COLUMN IF NOT EXISTS study_mode TEXT DEFAULT 'standard'
CHECK (study_mode IN ('quick', 'standard', 'deep', 'lectio'));

-- Add extended_content for mode-specific sections (deep dive: word study, etc.)
ALTER TABLE public.study_guides
ADD COLUMN IF NOT EXISTS extended_content JSONB DEFAULT '{}'::JSONB;

-- Add comment for documentation
COMMENT ON COLUMN public.study_guides.study_mode IS
'Study mode used to generate this guide: quick (3 min), standard (10 min), deep (25 min), lectio (15 min)';

COMMENT ON COLUMN public.study_guides.extended_content IS
'Mode-specific extended content as JSONB. For deep dive: word_study, historical_context, cross_references, journal_prompt. For lectio: meditation_prompts, prayer_template, contemplation_thought';

-- Index for filtering by study mode
CREATE INDEX IF NOT EXISTS idx_study_guides_study_mode
ON public.study_guides(study_mode);

-- ============================================================================
-- 2. ADD DEFAULT STUDY MODE TO USER_PREFERENCES
-- ============================================================================

-- Add default_study_mode column
ALTER TABLE public.user_preferences
ADD COLUMN IF NOT EXISTS default_study_mode TEXT DEFAULT 'standard'
CHECK (default_study_mode IN ('quick', 'standard', 'deep', 'lectio'));

COMMENT ON COLUMN public.user_preferences.default_study_mode IS
'User preferred default study mode for new study guides';

-- ============================================================================
-- 3. CREATE STUDY_REFLECTIONS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.study_reflections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  study_guide_id UUID NOT NULL REFERENCES public.study_guides(id) ON DELETE CASCADE,
  study_mode TEXT NOT NULL CHECK (study_mode IN ('quick', 'standard', 'deep', 'lectio')),

  -- Structured responses as JSONB for flexibility
  -- Example structure:
  -- {
  --   "summary_theme": "strength",
  --   "interpretation_relevance": 0.75,
  --   "context_related": true,
  --   "context_note": "When I lost my job...",
  --   "saved_verses": ["2 Cor 12:9", "Isaiah 40:31"],
  --   "life_areas": ["work", "anxiety"],
  --   "prayer_mode": "silent",
  --   "prayer_duration_seconds": 90
  -- }
  responses JSONB NOT NULL DEFAULT '{}'::JSONB,

  -- Tracking
  time_spent_seconds INTEGER DEFAULT 0,
  completed_at TIMESTAMPTZ,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.study_reflections ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only manage their own reflections
CREATE POLICY "study_reflections_select_own" ON public.study_reflections
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "study_reflections_insert_own" ON public.study_reflections
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "study_reflections_update_own" ON public.study_reflections
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "study_reflections_delete_own" ON public.study_reflections
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_reflections_user
ON public.study_reflections(user_id);

CREATE INDEX IF NOT EXISTS idx_reflections_guide
ON public.study_reflections(study_guide_id);

CREATE INDEX IF NOT EXISTS idx_reflections_date
ON public.study_reflections(completed_at DESC);

CREATE INDEX IF NOT EXISTS idx_reflections_user_date
ON public.study_reflections(user_id, completed_at DESC);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_study_reflections_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER study_reflections_updated_at_trigger
  BEFORE UPDATE ON public.study_reflections
  FOR EACH ROW
  EXECUTE FUNCTION update_study_reflections_updated_at();

-- Comments
COMMENT ON TABLE public.study_reflections IS
'Stores user reflection responses from interactive Reflect Mode in study guides';

COMMENT ON COLUMN public.study_reflections.responses IS
'JSONB containing structured reflection responses. Keys depend on study mode and interaction type.';

COMMENT ON COLUMN public.study_reflections.time_spent_seconds IS
'Total time user spent in Reflect Mode for this study guide';

COMMENT ON COLUMN public.study_reflections.completed_at IS
'Timestamp when user completed the reflection (all cards answered)';

-- ============================================================================
-- 4. VALIDATION
-- ============================================================================

DO $$
DECLARE
  study_guides_mode_exists BOOLEAN;
  user_pref_mode_exists BOOLEAN;
  reflections_exists BOOLEAN;
BEGIN
  -- Check study_guides.study_mode
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'study_guides' AND column_name = 'study_mode'
  ) INTO study_guides_mode_exists;

  -- Check user_preferences.default_study_mode
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_preferences' AND column_name = 'default_study_mode'
  ) INTO user_pref_mode_exists;

  -- Check study_reflections table
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'study_reflections'
  ) INTO reflections_exists;

  IF NOT study_guides_mode_exists THEN
    RAISE EXCEPTION 'study_guides.study_mode column was not created';
  END IF;

  IF NOT user_pref_mode_exists THEN
    RAISE EXCEPTION 'user_preferences.default_study_mode column was not created';
  END IF;

  IF NOT reflections_exists THEN
    RAISE EXCEPTION 'study_reflections table was not created';
  END IF;

  RAISE NOTICE 'Migration completed successfully:';
  RAISE NOTICE '  - Added study_mode column to study_guides';
  RAISE NOTICE '  - Added extended_content JSONB to study_guides';
  RAISE NOTICE '  - Added default_study_mode to user_preferences';
  RAISE NOTICE '  - Created study_reflections table with RLS';
END $$;

COMMIT;
