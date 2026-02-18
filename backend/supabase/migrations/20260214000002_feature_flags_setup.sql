-- Migration: Feature Flags Setup
-- Created: 2026-02-14
-- Description: Set up and configure all feature flags with correct descriptions and plan assignments

BEGIN;

-- ============================================================================
-- 1. Create Feature Flags Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.feature_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_key TEXT UNIQUE NOT NULL,
  feature_name TEXT NOT NULL,
  description TEXT,
  is_enabled BOOLEAN DEFAULT false,
  display_mode TEXT NOT NULL DEFAULT 'lock' CHECK (display_mode IN ('hide', 'lock')),
  rollout_percentage INTEGER DEFAULT 100 CHECK (rollout_percentage >= 0 AND rollout_percentage <= 100),
  enabled_for_plans TEXT[] DEFAULT ARRAY[]::TEXT[], -- Plans that have access: ['free', 'standard', 'plus', 'premium']
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by TEXT -- Admin email who made the last change
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_feature_flags_enabled ON public.feature_flags(is_enabled) WHERE is_enabled = true;
CREATE INDEX IF NOT EXISTS idx_feature_flags_key ON public.feature_flags(feature_key);

-- Add table and column comments
COMMENT ON TABLE public.feature_flags IS 'Dynamic feature toggles for gradual rollout and plan-based access control. Enables/disables features without deployment.';
COMMENT ON COLUMN public.feature_flags.display_mode IS 'Controls how features appear to users without plan access: hide (hidden from UI) or lock (shown with lock icon and upgrade prompt)';
COMMENT ON COLUMN public.feature_flags.rollout_percentage IS 'Percentage of users who can see this feature (0-100). Used for gradual rollout. Currently unused but available for future A/B testing.';
COMMENT ON COLUMN public.feature_flags.enabled_for_plans IS 'Array of plan types that have access to this feature (free, standard, plus, premium)';

-- ============================================================================
-- 2. Insert Initial Feature Flags
-- ============================================================================

INSERT INTO public.feature_flags (feature_key, feature_name, description, is_enabled, enabled_for_plans, rollout_percentage, metadata)
VALUES
  -- Core Features
  ('voice_buddy', 'Voice Buddy', 'AI-powered voice conversation feature for Bible study', true, ARRAY['premium', 'plus'], 100, '{"min_app_version": "1.0.0", "requires_subscription": true, "category": "premium_features"}'::jsonb),
  ('learning_paths', 'Learning Paths', 'Curated learning journey feature with progressive study paths', true, ARRAY['free', 'standard', 'plus', 'premium'], 100, '{"min_app_version": "1.0.0", "category": "core_features"}'::jsonb),
  ('memory_verses', 'Memory Verses', 'Spaced repetition memorization system for scripture verses', true, ARRAY['free', 'standard', 'plus', 'premium'], 100, '{"min_app_version": "1.0.0", "category": "core_features"}'::jsonb),
  ('ai_discipler', 'AI Discipler', 'Follow-up conversation feature for deeper discipleship', true, ARRAY['standard', 'plus', 'premium'], 100, '{"min_app_version": "1.0.0", "requires_subscription": true, "category": "premium_features"}'::jsonb),
  ('reflections', 'Reflections', 'Personal reflection journaling and insight tracking', true, ARRAY['standard', 'plus', 'premium'], 100, '{"min_app_version": "1.0.0", "requires_subscription": true, "category": "premium_features"}'::jsonb),

  -- Study Modes
  ('quick_read_mode', 'Quick Read Mode', '3-minute condensed study with key insight and reflection (⚡ Quick Read)', true, ARRAY['free', 'standard', 'plus', 'premium'], 100, '{"min_app_version": "1.0.0", "duration_minutes": 3, "category": "study_modes"}'::jsonb),
  ('standard_study_mode', 'Standard Study Mode', '10-minute full study with all 6 sections (📖 Standard Study)', true, ARRAY['free', 'standard', 'plus', 'premium'], 100, '{"min_app_version": "1.0.0", "duration_minutes": 10, "category": "study_modes"}'::jsonb),
  ('deep_dive_mode', 'Deep Dive Mode', '15-minute extended study with word studies and cross-references (🔍 Deep Dive)', true, ARRAY['standard', 'plus', 'premium'], 100, '{"min_app_version": "1.0.0", "duration_minutes": 15, "requires_subscription": true, "category": "study_modes"}'::jsonb),
  ('lectio_divina_mode', 'Lectio Divina Mode', '10-minute meditative Lectio Divina format with silence timers (🕯️ Lectio Divina)', true, ARRAY['standard', 'plus', 'premium'], 100, '{"min_app_version": "1.0.0", "duration_minutes": 10, "requires_subscription": true, "category": "study_modes"}'::jsonb),
  ('sermon_outline_mode', 'Sermon Outline Mode', '50-60 minute full sermon with timing and illustrations (⛪ Sermon Outline)', true, ARRAY['plus', 'premium'], 100, '{"min_app_version": "1.0.0", "duration_minutes": 55, "requires_subscription": true, "category": "study_modes"}'::jsonb),

  -- Additional Features
  ('daily_verse', 'Daily Verse', 'Daily verse delivery with multilingual support and caching', true, ARRAY['free', 'standard', 'plus', 'premium'], 100, '{"min_app_version": "1.0.0", "category": "engagement_features"}'::jsonb),
  ('leaderboard', 'Leaderboard & Gamification', 'Study streaks, achievements, XP system, and global leaderboards', true, ARRAY['free', 'standard', 'plus', 'premium'], 100, '{"min_app_version": "1.0.0", "category": "engagement_features"}'::jsonb)
ON CONFLICT (feature_key) DO NOTHING;

-- ============================================================================
-- 3. Enable RLS on feature_flags
-- ============================================================================

ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

-- Public read access for enabled features (anyone can see what features are enabled)
CREATE POLICY "Feature flags are viewable by everyone"
  ON public.feature_flags FOR SELECT
  USING (is_enabled = true);

-- Admin write access (only admins can modify feature flags)
CREATE POLICY "Feature flags are editable by admins"
  ON public.feature_flags FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- ============================================================================
-- 4. Database Functions for Feature Flag Access
-- ============================================================================

-- Function: Check if a feature is enabled for a specific user based on their plan
CREATE OR REPLACE FUNCTION public.is_feature_enabled_for_user(
  p_feature_key TEXT,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_enabled BOOLEAN;
  v_user_plan TEXT;
BEGIN
  -- Get user's current active subscription plan
  SELECT COALESCE(s.plan_type, 'free')
  INTO v_user_plan
  FROM public.subscriptions s
  WHERE s.user_id = p_user_id
  AND s.status IN ('active', 'trial', 'pending_cancellation')
  ORDER BY s.created_at DESC
  LIMIT 1;

  -- If no subscription found, default to free plan
  v_user_plan := COALESCE(v_user_plan, 'free');

  -- Check if feature is enabled globally AND user's plan has access
  SELECT f.is_enabled AND (v_user_plan = ANY(f.enabled_for_plans))
  INTO v_is_enabled
  FROM public.feature_flags f
  WHERE f.feature_key = p_feature_key;

  RETURN COALESCE(v_is_enabled, false);
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.is_feature_enabled_for_user(TEXT, UUID) TO authenticated;

-- Add function comment
COMMENT ON FUNCTION public.is_feature_enabled_for_user(TEXT, UUID) IS 'Check if a specific feature is enabled for a user based on their subscription plan and the feature global enable status.';

-- ============================================================================
-- ============================================================================
-- 6. Update Specific Feature Flags
-- ============================================================================

-- Update ai_discipler: Voice conversation feature (Talk to AI Discipler button)
-- Make it more restrictive (plus, premium only) as voice conversation is expensive
UPDATE feature_flags
SET
  feature_name = 'AI Discipler',
  description = 'AI-powered voice conversation feature for Bible study discussions',
  enabled_for_plans = ARRAY['standard', 'plus', 'premium'],
  updated_at = NOW()
WHERE feature_key = 'ai_discipler';

-- Update voice_buddy: Listen/TTS feature (Listen button in study guides)
-- Make it less restrictive (standard, plus, premium) as TTS is cheaper than voice conversation
UPDATE feature_flags
SET
  feature_name = 'Voice Buddy',
  description = 'Listen to study guides with AI-powered text-to-speech',
  enabled_for_plans = ARRAY['standard', 'plus', 'premium'],
  updated_at = NOW()
WHERE feature_key = 'voice_buddy';

-- Add study_chat feature flag: Text-based follow-up conversations
INSERT INTO feature_flags (
  feature_key,
  feature_name,
  description,
  is_enabled,
  enabled_for_plans,
  created_at,
  updated_at
) VALUES (
  'study_chat',
  'Follow Up Chat',
  'Text-based follow-up conversations in study guides for deeper understanding',
  true,
  ARRAY['standard', 'plus', 'premium'],
  NOW(),
  NOW()
)
ON CONFLICT (feature_key) DO UPDATE SET
  feature_name = EXCLUDED.feature_name,
  description = EXCLUDED.description,
  enabled_for_plans = EXCLUDED.enabled_for_plans,
  updated_at = NOW();

-- Add/update memory_verses feature flag
INSERT INTO feature_flags (
  feature_key,
  feature_name,
  description,
  is_enabled,
  enabled_for_plans,
  rollout_percentage,
  metadata,
  created_at,
  updated_at
) VALUES (
  'memory_verses',
  'Memory Verses',
  'Memorize and practice Bible verses with spaced repetition and gamification',
  true,
  ARRAY['free', 'standard', 'plus', 'premium'],
  100,
  '{"category": "core_features"}'::jsonb,
  NOW(),
  NOW()
)
ON CONFLICT (feature_key) DO UPDATE SET
  feature_name = EXCLUDED.feature_name,
  description = EXCLUDED.description,
  enabled_for_plans = EXCLUDED.enabled_for_plans,
  updated_at = NOW();

-- Add/update daily_verse feature flag
INSERT INTO feature_flags (
  feature_key,
  feature_name,
  description,
  is_enabled,
  enabled_for_plans,
  rollout_percentage,
  metadata,
  created_at,
  updated_at
) VALUES (
  'daily_verse',
  'Daily Verse',
  'Daily inspirational Bible verse with multiple translations',
  true,
  ARRAY['free', 'standard', 'plus', 'premium'],
  100,
  '{"category": "core_features"}'::jsonb,
  NOW(),
  NOW()
)
ON CONFLICT (feature_key) DO UPDATE SET
  feature_name = EXCLUDED.feature_name,
  description = EXCLUDED.description,
  enabled_for_plans = EXCLUDED.enabled_for_plans,
  updated_at = NOW();

-- Add/update reflections feature flag
INSERT INTO feature_flags (
  feature_key,
  feature_name,
  description,
  is_enabled,
  enabled_for_plans,
  rollout_percentage,
  metadata,
  created_at,
  updated_at
) VALUES (
  'reflections',
  'Reflections',
  'Personal reflection questions and insights after study sessions',
  true,
  ARRAY['standard', 'plus', 'premium'],
  100,
  '{"category": "study_features"}'::jsonb,
  NOW(),
  NOW()
)
ON CONFLICT (feature_key) DO UPDATE SET
  feature_name = EXCLUDED.feature_name,
  description = EXCLUDED.description,
  enabled_for_plans = EXCLUDED.enabled_for_plans,
  updated_at = NOW();

-- Add/update leaderboard feature flag
INSERT INTO feature_flags (
  feature_key,
  feature_name,
  description,
  is_enabled,
  enabled_for_plans,
  rollout_percentage,
  metadata,
  created_at,
  updated_at
) VALUES (
  'leaderboard',
  'Leaderboard',
  'Gamification leaderboard with XP tracking and achievements',
  true,
  ARRAY['free', 'standard', 'plus', 'premium'],
  100,
  '{"category": "gamification"}'::jsonb,
  NOW(),
  NOW()
)
ON CONFLICT (feature_key) DO UPDATE SET
  feature_name = EXCLUDED.feature_name,
  description = EXCLUDED.description,
  enabled_for_plans = EXCLUDED.enabled_for_plans,
  updated_at = NOW();

-- Summary of all feature flags:
-- ai_discipler: Voice conversation from Generate page - Plus/Premium only
-- voice_buddy: Listen/TTS button in study guides - Standard/Plus/Premium
-- study_chat: Text follow-up chat in study guides - Standard/Plus/Premium
-- memory_verses: Memory verse feature - All plans
-- daily_verse: Daily verse feature - All plans
-- reflections: Reflection questions - Standard/Plus/Premium
-- leaderboard: Gamification leaderboard - All plans


-- ============================================================================
-- 7. VERIFICATION
-- ============================================================================

-- Verify table and columns created successfully
DO $$
BEGIN
  -- Verify feature_flags table exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name = 'feature_flags'
  ) THEN
    RAISE EXCEPTION 'Migration failed: feature_flags table not created';
  END IF;

  -- Verify display_mode column exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'feature_flags'
    AND column_name = 'display_mode'
  ) THEN
    RAISE EXCEPTION 'Migration failed: display_mode column not created';
  END IF;

  RAISE NOTICE '✅ Migration 20260214000002_feature_flags_setup completed successfully';
  RAISE NOTICE '✅ feature_flags table created with display_mode column';
  RAISE NOTICE '✅ Default display modes configured for all features';
END $$;

COMMIT;
