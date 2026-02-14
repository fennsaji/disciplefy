-- Migration: Feature Flags Setup
-- Created: 2026-02-14
-- Description: Set up and configure all feature flags with correct descriptions and plan assignments

-- 1. Update ai_discipler: Voice conversation feature (Talk to AI Discipler button)
-- Make it more restrictive (plus, premium only) as voice conversation is expensive
UPDATE feature_flags
SET
  feature_name = 'AI Discipler',
  description = 'AI-powered voice conversation feature for Bible study discussions',
  enabled_for_plans = ARRAY['plus', 'premium'],
  updated_at = NOW()
WHERE feature_key = 'ai_discipler';

-- 2. Update voice_buddy: Listen/TTS feature (Listen button in study guides)
-- Make it less restrictive (standard, plus, premium) as TTS is cheaper than voice conversation
UPDATE feature_flags
SET
  feature_name = 'Voice Buddy',
  description = 'Listen to study guides with AI-powered text-to-speech',
  enabled_for_plans = ARRAY['standard', 'plus', 'premium'],
  updated_at = NOW()
WHERE feature_key = 'voice_buddy';

-- 3. Add study_chat feature flag: Text-based follow-up conversations
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

-- 4. Add memory_verses feature flag
INSERT INTO feature_flags (
  feature_key,
  feature_name,
  description,
  is_enabled,
  enabled_for_plans,
  category,
  rollout_percentage,
  created_at,
  updated_at
) VALUES (
  'memory_verses',
  'Memory Verses',
  'Memorize and practice Bible verses with spaced repetition and gamification',
  true,
  ARRAY['free', 'standard', 'plus', 'premium'],
  'core_features',
  100,
  NOW(),
  NOW()
)
ON CONFLICT (feature_key) DO UPDATE SET
  feature_name = EXCLUDED.feature_name,
  description = EXCLUDED.description,
  enabled_for_plans = EXCLUDED.enabled_for_plans,
  updated_at = NOW();

-- 5. Add daily_verse feature flag
INSERT INTO feature_flags (
  feature_key,
  feature_name,
  description,
  is_enabled,
  enabled_for_plans,
  category,
  rollout_percentage,
  created_at,
  updated_at
) VALUES (
  'daily_verse',
  'Daily Verse',
  'Daily inspirational Bible verse with multiple translations',
  true,
  ARRAY['free', 'standard', 'plus', 'premium'],
  'core_features',
  100,
  NOW(),
  NOW()
)
ON CONFLICT (feature_key) DO UPDATE SET
  feature_name = EXCLUDED.feature_name,
  description = EXCLUDED.description,
  enabled_for_plans = EXCLUDED.enabled_for_plans,
  updated_at = NOW();

-- 6. Add reflections feature flag
INSERT INTO feature_flags (
  feature_key,
  feature_name,
  description,
  is_enabled,
  enabled_for_plans,
  category,
  rollout_percentage,
  created_at,
  updated_at
) VALUES (
  'reflections',
  'Reflections',
  'Personal reflection questions and insights after study sessions',
  true,
  ARRAY['standard', 'plus', 'premium'],
  'study_features',
  100,
  NOW(),
  NOW()
)
ON CONFLICT (feature_key) DO UPDATE SET
  feature_name = EXCLUDED.feature_name,
  description = EXCLUDED.description,
  enabled_for_plans = EXCLUDED.enabled_for_plans,
  updated_at = NOW();

-- 7. Add leaderboard feature flag
INSERT INTO feature_flags (
  feature_key,
  feature_name,
  description,
  is_enabled,
  enabled_for_plans,
  category,
  rollout_percentage,
  created_at,
  updated_at
) VALUES (
  'leaderboard',
  'Leaderboard',
  'Gamification leaderboard with XP tracking and achievements',
  true,
  ARRAY['free', 'standard', 'plus', 'premium'],
  'gamification',
  100,
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
