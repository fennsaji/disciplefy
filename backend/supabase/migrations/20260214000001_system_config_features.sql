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
-- 1. Create system_config Table
-- ============================================================================

-- Create system_config table with all columns
CREATE TABLE IF NOT EXISTS public.system_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on system_config
ALTER TABLE public.system_config ENABLE ROW LEVEL SECURITY;

-- Policy: Public read access for active configs
CREATE POLICY "Allow public read access to system config"
  ON public.system_config
  FOR SELECT
  TO public
  USING (is_active = true);

-- Policy: Only service role can write
CREATE POLICY "Only service role can modify system config"
  ON public.system_config
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Create index for active configs
CREATE INDEX IF NOT EXISTS idx_system_config_active ON public.system_config(key) WHERE is_active = true;

-- Add table comment
COMMENT ON TABLE public.system_config IS
  'System-wide configuration and feature flags.
   Used for maintenance mode, versioning, and feature toggles.';

-- ============================================================================
-- 2. Insert Legacy System Configuration Entries
-- ============================================================================

-- Insert legacy configuration entries (from admin_config migration)
INSERT INTO public.system_config (key, value, description, is_active) VALUES
  ('app_version', '1.0.0', 'Current application version', true),
  ('maintenance_mode', 'false', '[DEPRECATED] Use maintenance_mode_enabled instead', false),
  ('trial_period_days', '7', '[DEPRECATED] Use premium_trial_days instead', false),
  ('max_free_guides_per_day', '3', '[DEPRECATED] Daily limits moved to subscription_plans', false),
  ('feature_voice_buddy', 'true', '[DEPRECATED] Use feature_flags table instead', false),
  ('feature_learning_paths', 'true', '[DEPRECATED] Use feature_flags table instead', false),
  ('feature_memory_verses', 'true', '[DEPRECATED] Use feature_flags table instead', false),
  ('admin_emails', 'fennsaji@gmail.com', 'Comma-separated list of admin emails (server-side only)', true)
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- 3. Insert New System Configuration Entries
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

-- Memory Verse System Configuration
INSERT INTO public.system_config (key, value, description, is_active, metadata)
VALUES
  -- Practice Mode Unlock Limits (per verse per day by tier)
  ('free_practice_unlock_limit', '1', 'Number of practice modes Free users can unlock per verse per day', true, '{"category": "memory_verses", "tier": "free"}'::jsonb),
  ('standard_practice_unlock_limit', '2', 'Number of practice modes Standard users can unlock per verse per day', true, '{"category": "memory_verses", "tier": "standard"}'::jsonb),
  ('plus_practice_unlock_limit', '3', 'Number of practice modes Plus users can unlock per verse per day', true, '{"category": "memory_verses", "tier": "plus"}'::jsonb),
  ('premium_practice_unlock_limit', '-1', 'Number of practice modes Premium users can unlock per verse per day (-1 = unlimited)', true, '{"category": "memory_verses", "tier": "premium"}'::jsonb),

  -- Memory Verse Limits (total active verses by tier)
  ('free_memory_verses_limit', '3', 'Maximum number of memory verses Free users can have active at once', true, '{"category": "memory_verses", "tier": "free"}'::jsonb),
  ('standard_memory_verses_limit', '5', 'Maximum number of memory verses Standard users can have active at once', true, '{"category": "memory_verses", "tier": "standard"}'::jsonb),
  ('plus_memory_verses_limit', '10', 'Maximum number of memory verses Plus users can have active at once', true, '{"category": "memory_verses", "tier": "plus"}'::jsonb),
  ('premium_memory_verses_limit', '-1', 'Maximum number of memory verses Premium users can have active at once (-1 = unlimited)', true, '{"category": "memory_verses", "tier": "premium"}'::jsonb),

  -- Practice Mode Availability (JSON arrays of available mode names)
  ('free_available_practice_modes', '["flip_card", "type_it_out"]', 'Practice modes available to Free tier users', true, '{"category": "memory_verses", "tier": "free", "type": "array"}'::jsonb),
  ('paid_available_practice_modes', '["flip_card", "type_it_out", "cloze", "first_letter", "progressive", "word_scramble", "word_bank", "audio"]', 'Practice modes available to Standard/Plus/Premium users', true, '{"category": "memory_verses", "tier": "paid", "type": "array"}'::jsonb),

  -- Spaced Repetition Configuration
  ('memory_verse_initial_ease_factor', '2.5', 'Initial ease factor for new memory verses (spaced repetition algorithm)', true, '{"category": "memory_verses", "algorithm": "sm2"}'::jsonb),
  ('memory_verse_initial_interval_days', '1', 'Initial review interval in days for new memory verses', true, '{"category": "memory_verses", "algorithm": "sm2"}'::jsonb),
  ('memory_verse_min_ease_factor', '1.3', 'Minimum ease factor allowed (prevents interval from becoming too short)', true, '{"category": "memory_verses", "algorithm": "sm2"}'::jsonb),
  ('memory_verse_max_interval_days', '365', 'Maximum review interval in days (1 year)', true, '{"category": "memory_verses", "algorithm": "sm2"}'::jsonb),

  -- Gamification & Engagement
  ('memory_verse_mastery_threshold', '5', 'Number of consecutive correct reviews to mark verse as mastered', true, '{"category": "memory_verses", "gamification": true}'::jsonb),
  ('memory_verse_xp_per_review', '10', 'XP points awarded per successful verse review', true, '{"category": "memory_verses", "gamification": true}'::jsonb),
  ('memory_verse_xp_mastery_bonus', '50', 'Bonus XP points awarded when verse reaches mastered status', true, '{"category": "memory_verses", "gamification": true}'::jsonb)
ON CONFLICT (key) DO UPDATE SET
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
  metadata = EXCLUDED.metadata;

-- ============================================================================
-- 4. Database Functions for System Config Access
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
-- 5. Grant Permissions
-- ============================================================================

-- Grant execute permissions on functions to authenticated and anonymous users
GRANT EXECUTE ON FUNCTION public.is_maintenance_mode_enabled() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_system_configs() TO authenticated, anon;

-- ============================================================================
-- 6. Add Comments for Documentation
-- ============================================================================

COMMENT ON FUNCTION public.is_maintenance_mode_enabled() IS 'Check if app is currently in maintenance mode. Returns true if maintenance_mode_enabled config is true.';
COMMENT ON FUNCTION public.get_system_configs() IS 'Retrieve all active system configuration entries. Used for backend caching to avoid repeated database queries.';

COMMENT ON COLUMN public.system_config.is_active IS 'Whether this config entry is currently active. Inactive entries are ignored by get_system_configs().';
COMMENT ON COLUMN public.system_config.metadata IS 'Additional metadata for the config entry (JSON). Can store update timestamps, original values, etc.';

-- ============================================================================
-- 7. Remove Premium Trial Start Date Restriction (2026-02-15)
-- ============================================================================
-- CHANGE: Premium trials are now available on-demand (user-initiated)
-- instead of being date-gated. The trial is offered when user clicks
-- "Subscribe to Premium" - no date restrictions.

-- Deactivate premium_trial_start_date (no longer used)
UPDATE public.system_config
SET
  is_active = false,
  description = '[DEPRECATED] Premium trial start date - Premium trials are now available on-demand, not date-gated',
  metadata = jsonb_set(
    COALESCE(metadata, '{}'::jsonb),
    '{deprecated}',
    'true'::jsonb
  )
WHERE key = 'premium_trial_start_date';

-- Update premium_trial_days description for clarity
UPDATE public.system_config
SET description = 'Premium trial duration in days (offered when user clicks "Subscribe to Premium")'
WHERE key = 'premium_trial_days';

-- Log the change
DO $$
BEGIN
  RAISE NOTICE 'Premium trial model updated: Date restrictions removed, trials now on-demand';
END $$;

COMMIT;
