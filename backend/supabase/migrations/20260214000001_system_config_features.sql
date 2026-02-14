-- ============================================================================
-- System Config Features Migration
-- Date: 2026-02-14
-- Purpose: Enable database-driven system configuration
-- ============================================================================
--
-- Adds support for:
-- 1. Maintenance Mode - Global app control without deployment
-- 2. Feature Flags - Dynamic feature toggles with plan-based access
-- 3. App Version Control - Force update notifications
-- 4. Dynamic Trial Periods - Database-driven trial configuration
--
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Extend system_config Table
-- ============================================================================

-- Add columns for enhanced config management (existing table uses 'key' and 'value')
ALTER TABLE public.system_config
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- Create index for active configs
CREATE INDEX IF NOT EXISTS idx_system_config_active ON public.system_config(key) WHERE is_active = true;

-- ============================================================================
-- 2. Insert System Configuration Entries
-- ============================================================================

-- Maintenance Mode Configuration
INSERT INTO public.system_config (key, value, description, is_active, metadata)
VALUES
  ('maintenance_mode_enabled', 'false', 'Global maintenance mode switch - blocks all non-admin access when true', true, '{"updated_at": null, "updated_by": null}'::jsonb),
  ('maintenance_mode_message', 'We are currently performing maintenance. Please check back shortly.', 'User-facing message displayed during maintenance mode', true, '{"default_message": true}'::jsonb)
ON CONFLICT (key) DO UPDATE SET
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
  metadata = EXCLUDED.metadata;

-- App Version Control Configuration
INSERT INTO public.system_config (key, value, description, is_active, metadata)
VALUES
  ('min_app_version_android', '1.0.0', 'Minimum required Android app version (users below this are forced to update)', true, '{"platform": "android", "updated_at": null}'::jsonb),
  ('min_app_version_ios', '1.0.0', 'Minimum required iOS app version (users below this are forced to update)', true, '{"platform": "ios", "updated_at": null}'::jsonb),
  ('min_app_version_web', '1.0.0', 'Minimum required web app version (users below this are forced to update)', true, '{"platform": "web", "updated_at": null}'::jsonb),
  ('latest_app_version', '1.0.0', 'Current latest version available in app stores', true, '{"release_date": null, "release_notes_url": null}'::jsonb),
  ('force_update_enabled', 'false', 'When true, users below minimum version cannot access app (force update)', true, '{"updated_at": null}'::jsonb)
ON CONFLICT (key) DO UPDATE SET
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
  metadata = EXCLUDED.metadata;

-- Dynamic Trial Configuration
INSERT INTO public.system_config (key, value, description, is_active, metadata)
VALUES
  ('standard_trial_end_date', '2026-03-31T23:59:59+05:30', 'Standard plan free trial end date (all users get free Standard access until this date)', true, '{"timezone": "Asia/Kolkata", "original_value": "2026-03-31T23:59:59+05:30"}'::jsonb),
  ('premium_trial_days', '7', 'Premium trial duration in days for new users', true, '{"original_value": 7}'::jsonb),
  ('premium_trial_start_date', '2026-04-01T00:00:00+05:30', 'Premium trial availability start date (users signing up after this can get Premium trial)', true, '{"timezone": "Asia/Kolkata", "original_value": "2026-04-01T00:00:00+05:30"}'::jsonb),
  ('grace_period_days', '7', 'Grace period in days after trial ends before downgrade to free plan', true, '{"original_value": 7}'::jsonb)
ON CONFLICT (key) DO UPDATE SET
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
  metadata = EXCLUDED.metadata;

-- ============================================================================
-- 3. Create Feature Flags Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.feature_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_key TEXT UNIQUE NOT NULL,
  feature_name TEXT NOT NULL,
  description TEXT,
  is_enabled BOOLEAN DEFAULT false,
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

-- ============================================================================
-- 4. Insert Feature Flags
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
-- 5. Enable RLS on feature_flags
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
-- 6. Database Functions for Config Access
-- ============================================================================

-- Function: Check if maintenance mode is enabled
CREATE OR REPLACE FUNCTION public.is_maintenance_mode_enabled()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  mode_enabled BOOLEAN;
BEGIN
  SELECT (value::boolean)
  INTO mode_enabled
  FROM public.system_config
  WHERE key = 'maintenance_mode_enabled'
  AND is_active = true;

  RETURN COALESCE(mode_enabled, false);
END;
$$;

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

-- Function: Get all active system configs (for caching at app level)
CREATE OR REPLACE FUNCTION public.get_system_configs()
RETURNS TABLE (
  key TEXT,
  value TEXT,
  metadata JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT sc.key, sc.value, sc.metadata
  FROM public.system_config sc
  WHERE sc.is_active = true
  ORDER BY sc.key;
END;
$$;

-- ============================================================================
-- 7. Grant Permissions
-- ============================================================================

-- Grant execute permissions on functions to authenticated and anonymous users
GRANT EXECUTE ON FUNCTION public.is_maintenance_mode_enabled() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_feature_enabled_for_user(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_system_configs() TO authenticated, anon;

-- ============================================================================
-- 8. Add Comments for Documentation
-- ============================================================================

COMMENT ON TABLE public.feature_flags IS 'Dynamic feature toggles for gradual rollout and plan-based access control. Enables/disables features without deployment.';
COMMENT ON COLUMN public.feature_flags.rollout_percentage IS 'Percentage of users who can see this feature (0-100). Used for gradual rollout. Currently unused but available for future A/B testing.';
COMMENT ON COLUMN public.feature_flags.enabled_for_plans IS 'Array of plan types that have access to this feature (free, standard, plus, premium)';

COMMENT ON FUNCTION public.is_maintenance_mode_enabled() IS 'Check if app is currently in maintenance mode. Returns true if maintenance_mode_enabled config is true.';
COMMENT ON FUNCTION public.is_feature_enabled_for_user(TEXT, UUID) IS 'Check if a specific feature is enabled for a user based on their subscription plan and the feature global enable status.';
COMMENT ON FUNCTION public.get_system_configs() IS 'Retrieve all active system configuration entries. Used for backend caching to avoid repeated database queries.';

COMMENT ON COLUMN public.system_config.is_active IS 'Whether this config entry is currently active. Inactive entries are ignored by get_system_configs().';
COMMENT ON COLUMN public.system_config.metadata IS 'Additional metadata for the config entry (JSON). Can store update timestamps, original values, etc.';

COMMIT;
