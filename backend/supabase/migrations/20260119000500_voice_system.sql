-- =====================================================
-- Consolidated Migration: Voice System
-- =====================================================
-- Source: Merged 10 voice-related migrations
-- Tables: 4 (voice_conversations, voice_conversation_messages,
--            voice_usage_tracking, voice_preferences)
-- Description: Complete AI Study Buddy Voice system with monthly limits,
--              usage tracking, user preferences, and quota management
-- =====================================================

-- Dependencies: 0001_core_schema.sql (auth.users, user_profiles, study_guides)

BEGIN;

-- =====================================================
-- SUMMARY: Migration creates complete voice conversation system
-- Completed: 0001 (11 tables), 0002 (6 tables), 0003 (2 tables),
--            0004 (5 tables), 0005 (6 tables)
-- Now creating 0006 with voice infrastructure
-- =====================================================

-- =====================================================
-- PART 1: TABLES
-- =====================================================

-- -----------------------------------------------------
-- 1.1 Voice Conversations Table
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS voice_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Session Info
  session_id TEXT NOT NULL, -- Client-generated UUID for WebSocket management
  language_code TEXT NOT NULL DEFAULT 'en-US'
    CHECK (language_code IN ('en-US', 'hi-IN', 'ml-IN')),

  -- Conversation Context
  conversation_type TEXT NOT NULL DEFAULT 'general'
    CHECK (conversation_type IN (
      'general',           -- Open-ended questions
      'study_enhancement', -- Questions during study guide
      'scripture_inquiry', -- Specific verse questions
      'prayer_guidance',   -- Prayer-related
      'theological_debate' -- Deep theological discussion
    )),

  related_study_guide_id UUID REFERENCES study_guides(id) ON DELETE SET NULL,
  related_scripture TEXT, -- e.g., "John 3:16"

  -- Conversation Metadata
  total_messages INTEGER DEFAULT 0,
  total_duration_seconds INTEGER DEFAULT 0,

  -- Status
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'completed', 'abandoned')),

  -- User Feedback (Fix: already included in base schema, no need for separate migration)
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  feedback_text TEXT,
  was_helpful BOOLEAN,

  -- Fix: Renamed columns for consistency with mobile app expectations
  user_rating INTEGER CHECK (user_rating BETWEEN 1 AND 5),

  -- Timestamps
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_voice_conversations_user_id
  ON voice_conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_voice_conversations_session_id
  ON voice_conversations(session_id);
CREATE INDEX IF NOT EXISTS idx_voice_conversations_status
  ON voice_conversations(status);
CREATE INDEX IF NOT EXISTS idx_voice_conversations_language
  ON voice_conversations(language_code);
CREATE INDEX IF NOT EXISTS idx_voice_conversations_started_at
  ON voice_conversations(user_id, started_at DESC);

-- Comments
COMMENT ON TABLE voice_conversations IS
  'Stores voice conversation sessions for AI Study Buddy Voice feature';
COMMENT ON COLUMN voice_conversations.session_id IS
  'Client-generated UUID for WebSocket session management';
COMMENT ON COLUMN voice_conversations.conversation_type IS
  'Type of conversation context for tailored AI responses';
COMMENT ON COLUMN voice_conversations.rating IS
  'User rating from 1-5 stars (legacy column)';
COMMENT ON COLUMN voice_conversations.user_rating IS
  'User rating from 1-5 stars (mobile app compatible)';
COMMENT ON COLUMN voice_conversations.feedback_text IS
  'Optional user feedback text';
COMMENT ON COLUMN voice_conversations.was_helpful IS
  'Whether the conversation was helpful';

-- -----------------------------------------------------
-- 1.2 Voice Conversation Messages Table
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS voice_conversation_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES voice_conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Message Info
  message_order INTEGER NOT NULL, -- Sequence in conversation (1, 2, 3...)
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),

  -- Content
  content_text TEXT NOT NULL, -- Transcribed/generated text
  content_language TEXT NOT NULL DEFAULT 'en-US',

  -- Audio Metadata
  audio_duration_seconds DECIMAL(6,2),
  audio_url TEXT, -- Supabase Storage URL (if cached)

  -- Processing Metadata
  transcription_confidence DECIMAL(4,3), -- 0.000 to 1.000 (from STT)
  llm_model_used TEXT, -- e.g., 'gpt-4-turbo-preview'
  llm_tokens_used INTEGER,

  -- Scripture References (for assistant messages)
  scripture_references TEXT[], -- Array like ['John 3:16', 'Romans 8:28']

  -- Fix: Bible Book Name Correction Fields (20251220000002)
  book_names_corrected BOOLEAN DEFAULT FALSE,
  corrections_made JSONB DEFAULT NULL, -- Array: [{"original": "Jn", "corrected": "John"}]

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(conversation_id, message_order)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_voice_conversation_messages_conversation_id
  ON voice_conversation_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_voice_conversation_messages_user_id
  ON voice_conversation_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_voice_conversation_messages_order
  ON voice_conversation_messages(conversation_id, message_order);

-- Comments
COMMENT ON TABLE voice_conversation_messages IS
  'Individual messages within voice conversations';
COMMENT ON COLUMN voice_conversation_messages.message_order IS
  'Sequential order of message in conversation for proper replay';
COMMENT ON COLUMN voice_conversation_messages.transcription_confidence IS
  'STT confidence score from 0.000 to 1.000';
COMMENT ON COLUMN voice_conversation_messages.book_names_corrected IS
  'Whether Bible book names were auto-corrected in this message';
COMMENT ON COLUMN voice_conversation_messages.corrections_made IS
  'Array of corrections made: [{"original", "corrected"}]';

-- -----------------------------------------------------
-- 1.3 Voice Usage Tracking Table
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS voice_usage_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Usage Period
  usage_date DATE NOT NULL DEFAULT CURRENT_DATE,

  -- Fix: Monthly tracking columns (20260116000002)
  month_year TEXT NOT NULL DEFAULT to_char(CURRENT_DATE, 'YYYY-MM'),
  monthly_conversations_started INTEGER NOT NULL DEFAULT 0,
  monthly_conversations_completed INTEGER NOT NULL DEFAULT 0,

  -- Usage Counts (daily)
  conversations_started INTEGER DEFAULT 0,
  conversations_completed INTEGER DEFAULT 0,
  total_messages_sent INTEGER DEFAULT 0,
  total_messages_received INTEGER DEFAULT 0,

  -- Duration Tracking
  total_conversation_seconds INTEGER DEFAULT 0,
  total_audio_seconds INTEGER DEFAULT 0,

  -- Language Usage
  language_usage JSONB DEFAULT '{}', -- Example: {"en-US": 5, "hi-IN": 2, "ml-IN": 1}

  -- Subscription Tier (at time of use)
  tier_at_time TEXT NOT NULL CHECK (tier_at_time IN ('free', 'standard', 'plus', 'premium')),

  -- Quota Management
  daily_quota_limit INTEGER, -- Conversations allowed per day
  daily_quota_used INTEGER DEFAULT 0,
  quota_exceeded BOOLEAN DEFAULT FALSE,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, usage_date)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_voice_usage_user_id
  ON voice_usage_tracking(user_id);
CREATE INDEX IF NOT EXISTS idx_voice_usage_date
  ON voice_usage_tracking(usage_date);
CREATE INDEX IF NOT EXISTS idx_voice_usage_tier
  ON voice_usage_tracking(tier_at_time);

-- Fix: Monthly tracking index (20260116000002)
CREATE INDEX IF NOT EXISTS idx_voice_usage_tracking_user_month
  ON voice_usage_tracking(user_id, month_year);

-- Comments
COMMENT ON TABLE voice_usage_tracking IS
  'Daily usage tracking for voice conversation quota management';
COMMENT ON COLUMN voice_usage_tracking.language_usage IS
  'JSONB object tracking conversation count per language';
COMMENT ON COLUMN voice_usage_tracking.tier_at_time IS
  'User subscription tier when usage occurred';
COMMENT ON COLUMN voice_usage_tracking.month_year IS
  'Calendar month in YYYY-MM format for monthly limit tracking';
COMMENT ON COLUMN voice_usage_tracking.monthly_conversations_started IS
  'Number of voice conversations started in the current month';
COMMENT ON COLUMN voice_usage_tracking.monthly_conversations_completed IS
  'Number of voice conversations completed in the current month';

-- -----------------------------------------------------
-- 1.4 Voice Preferences Table
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS voice_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Language Preferences
  preferred_language TEXT NOT NULL DEFAULT 'en-US'
    CHECK (preferred_language IN ('en-US', 'hi-IN', 'ml-IN', 'default')),
  auto_detect_language BOOLEAN DEFAULT TRUE,

  -- Voice Settings
  tts_voice_gender TEXT DEFAULT 'female'
    CHECK (tts_voice_gender IN ('male', 'female')),
  speaking_rate DECIMAL(3,2) DEFAULT 0.95
    CHECK (speaking_rate BETWEEN 0.5 AND 2.0),
  pitch DECIMAL(4,2) DEFAULT 0.0
    CHECK (pitch BETWEEN -20.0 AND 20.0),

  -- Interaction Preferences
  auto_play_response BOOLEAN DEFAULT TRUE,
  show_transcription BOOLEAN DEFAULT TRUE,
  continuous_mode BOOLEAN DEFAULT FALSE, -- Keep mic open after response

  -- Context Preferences
  use_study_context BOOLEAN DEFAULT TRUE, -- Include current study in conversation
  cite_scripture_references BOOLEAN DEFAULT TRUE,

  -- Notification Preferences
  notify_daily_quota_reached BOOLEAN DEFAULT TRUE,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id)
);

-- Comments
COMMENT ON TABLE voice_preferences IS
  'User preferences for voice conversation settings';
COMMENT ON COLUMN voice_preferences.speaking_rate IS
  'TTS speaking rate from 0.5 (slow) to 2.0 (fast)';
COMMENT ON COLUMN voice_preferences.pitch IS
  'TTS pitch adjustment from -20.0 to 20.0';
COMMENT ON COLUMN voice_preferences.continuous_mode IS
  'Keep microphone open for continuous conversation';
COMMENT ON COLUMN voice_preferences.preferred_language IS
  'Preferred voice language; "default" uses user profile language';

-- =====================================================
-- PART 2: FUNCTIONS
-- =====================================================

-- -----------------------------------------------------
-- 2.1 Helper Function: Get User Subscription Tier
-- -----------------------------------------------------
-- Fix: 20251124000001 - Created helper to fetch tier from subscriptions

CREATE OR REPLACE FUNCTION get_user_subscription_tier(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_tier TEXT;
BEGIN
  -- Check user's active subscription (using plan_id JOIN)
  SELECT
    CASE
      WHEN sp.plan_code = 'premium' AND s.status IN ('active', 'trial', 'authenticated', 'pending_cancellation') AND
           (s.current_period_end IS NULL OR s.current_period_end > NOW()) THEN 'premium'
      WHEN sp.plan_code = 'plus' AND s.status IN ('active', 'trial', 'authenticated', 'pending_cancellation') AND
           (s.current_period_end IS NULL OR s.current_period_end > NOW()) THEN 'plus'
      WHEN sp.plan_code = 'standard' AND s.status IN ('active', 'trial', 'authenticated', 'pending_cancellation') AND
           (s.current_period_end IS NULL OR s.current_period_end > NOW()) THEN 'standard'
      ELSE 'free'
    END INTO v_tier
  FROM subscriptions s
  LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
  WHERE s.user_id = p_user_id
  ORDER BY
    CASE
      WHEN sp.plan_code = 'premium' THEN 1
      WHEN sp.plan_code = 'plus' THEN 2
      WHEN sp.plan_code = 'standard' THEN 3
      ELSE 4
    END,
    s.created_at DESC
  LIMIT 1;

  -- Default to free if no subscription found
  IF v_tier IS NULL THEN
    v_tier := 'free';
  END IF;

  RETURN v_tier;
END;
$$;

COMMENT ON FUNCTION get_user_subscription_tier IS
  'Gets the current subscription tier for a user (free, standard, plus, premium)';

-- -----------------------------------------------------
-- 2.2 Check Voice Quota (Monthly Calculation)
-- -----------------------------------------------------
-- Fix: 20251124000001 - Made parameterless (uses auth.uid())
-- Fix: 20251128000001 - Changed to MONTHLY quota calculation

CREATE OR REPLACE FUNCTION check_voice_quota()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_user_id UUID;
  v_tier TEXT;
  v_quota_limit INTEGER;
  v_monthly_usage INTEGER;
  v_can_start BOOLEAN;
  v_month_start DATE;
  v_month_end DATE;
BEGIN
  -- Get current user ID from auth context
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'User not authenticated',
      'can_start', false,
      'quota_limit', 0,
      'quota_used', 0,
      'quota_remaining', 0,
      'tier', 'free'
    );
  END IF;

  -- Get user's subscription tier
  v_tier := get_user_subscription_tier(v_user_id);

  -- 🆕 Get MONTHLY quota from database (subscription_plans.features.voice_conversations_monthly)
  -- Database-driven configuration allows admin to change limits without code deployment
  SELECT (features->>'voice_conversations_monthly')::INTEGER
  INTO v_quota_limit
  FROM subscription_plans
  WHERE plan_code = v_tier AND is_active = true;

  -- Fallback to 0 if not found
  v_quota_limit := COALESCE(v_quota_limit, 0);

  -- Calculate current month boundaries
  v_month_start := DATE_TRUNC('month', CURRENT_DATE)::DATE;
  v_month_end := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

  -- Sum up all usage for the current month
  SELECT COALESCE(SUM(daily_quota_used), 0) INTO v_monthly_usage
  FROM voice_usage_tracking
  WHERE user_id = v_user_id
    AND usage_date >= v_month_start
    AND usage_date <= v_month_end;

  -- Check if can start new conversation
  -- Premium users (limit = -1) can always start
  -- Free users (limit = 0) can never start
  -- Standard/Plus users check against monthly limit
  v_can_start := CASE
    WHEN v_quota_limit = -1 THEN TRUE  -- Premium: unlimited
    WHEN v_quota_limit = 0 THEN FALSE  -- Free: not available
    ELSE v_monthly_usage < v_quota_limit
  END;

  -- Ensure today's tracking record exists
  INSERT INTO voice_usage_tracking (
    user_id, tier_at_time, daily_quota_limit, daily_quota_used
  )
  VALUES (v_user_id, v_tier, v_quota_limit, 0)
  ON CONFLICT (user_id, usage_date) DO NOTHING;

  RETURN jsonb_build_object(
    'can_start', v_can_start,
    'quota_limit', CASE WHEN v_quota_limit = -1 THEN 999999 ELSE v_quota_limit END,
    'quota_used', v_monthly_usage,
    'quota_remaining', CASE
      WHEN v_quota_limit = -1 THEN 999999  -- Premium: show as unlimited
      ELSE GREATEST(0, v_quota_limit - v_monthly_usage)
    END,
    'tier', v_tier
  );
END;
$$;

COMMENT ON FUNCTION check_voice_quota() IS
  'Checks if authenticated user can start a new voice conversation based on MONTHLY tier quota from database (subscription_plans.features.voice_conversations_monthly)';

-- -----------------------------------------------------
-- 2.3 Increment Voice Usage
-- -----------------------------------------------------
-- Fix: 20251124000001 - Made parameterless (uses auth.uid())

CREATE OR REPLACE FUNCTION increment_voice_usage()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_user_id UUID;
  v_tier TEXT;
  v_language TEXT;
  v_current_month TEXT;
BEGIN
  -- Get current user ID from auth context
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  -- Get user's subscription tier
  v_tier := get_user_subscription_tier(v_user_id);

  -- Default language (will be updated when conversation is created)
  v_language := 'en-US';

  -- Get current month for monthly tracking
  v_current_month := to_char(CURRENT_DATE, 'YYYY-MM');

  INSERT INTO voice_usage_tracking (
    user_id,
    usage_date,
    month_year,
    tier_at_time,
    daily_quota_limit,
    daily_quota_used,
    conversations_started,
    monthly_conversations_started,
    language_usage
  )
  VALUES (
    v_user_id,
    CURRENT_DATE,
    v_current_month,
    v_tier,
    CASE
      WHEN v_tier = 'free' THEN 0
      WHEN v_tier = 'standard' THEN 10
      WHEN v_tier = 'plus' THEN 10
      WHEN v_tier = 'premium' THEN -1
    END,
    1,
    1,
    1,
    jsonb_build_object(v_language, 1)
  )
  ON CONFLICT (user_id, usage_date)
  DO UPDATE SET
    daily_quota_used = voice_usage_tracking.daily_quota_used + 1,
    conversations_started = voice_usage_tracking.conversations_started + 1,
    monthly_conversations_started = voice_usage_tracking.monthly_conversations_started + 1,
    updated_at = NOW();
END;
$$;

COMMENT ON FUNCTION increment_voice_usage() IS
  'Increments daily and monthly voice usage count when authenticated user starts a conversation';

-- -----------------------------------------------------
-- 2.4 Complete Voice Conversation
-- -----------------------------------------------------
-- Fix: 20251128000008 - Added feedback params, auto-calculate duration, auth checks

CREATE OR REPLACE FUNCTION complete_voice_conversation(
  p_conversation_id UUID,
  p_rating INTEGER DEFAULT NULL,
  p_feedback_text TEXT DEFAULT NULL,
  p_was_helpful BOOLEAN DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_user_id UUID;
  v_caller_id UUID;
  v_started_at TIMESTAMPTZ;
  v_duration_seconds INTEGER;
BEGIN
  -- Get caller's user ID from auth context
  v_caller_id := auth.uid();

  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get user_id and started_at from conversation
  SELECT user_id, started_at INTO v_user_id, v_started_at
  FROM voice_conversations
  WHERE id = p_conversation_id;

  -- Verify conversation exists
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Conversation not found: %', p_conversation_id;
  END IF;

  IF v_started_at IS NULL THEN
    RAISE EXCEPTION 'Conversation % has no started_at timestamp', p_conversation_id;
  END IF;

  -- Verify caller owns this conversation
  IF v_user_id != v_caller_id THEN
    RAISE EXCEPTION 'Not authorized to complete this conversation';
  END IF;

  -- Calculate duration from started_at to now
  v_duration_seconds := EXTRACT(EPOCH FROM (NOW() - v_started_at))::INTEGER;

  -- Update conversation status with feedback
  UPDATE voice_conversations
  SET
    status = 'completed',
    ended_at = NOW(),
    total_duration_seconds = v_duration_seconds,
    user_rating = p_rating,
    rating = p_rating, -- Also set legacy column
    feedback_text = p_feedback_text,
    was_helpful = p_was_helpful,
    updated_at = NOW()
  WHERE id = p_conversation_id;

  -- Upsert daily usage tracking
  INSERT INTO voice_usage_tracking (
    user_id,
    usage_date,
    conversations_completed,
    monthly_conversations_completed,
    total_conversation_seconds,
    updated_at
  ) VALUES (
    v_user_id,
    CURRENT_DATE,
    1,
    1,
    v_duration_seconds,
    NOW()
  )
  ON CONFLICT (user_id, usage_date) DO UPDATE SET
    conversations_completed = voice_usage_tracking.conversations_completed + 1,
    monthly_conversations_completed = voice_usage_tracking.monthly_conversations_completed + 1,
    total_conversation_seconds = voice_usage_tracking.total_conversation_seconds + EXCLUDED.total_conversation_seconds,
    updated_at = NOW();
END;
$$;

COMMENT ON FUNCTION complete_voice_conversation IS
  'Completes a voice conversation with optional user feedback (rating, feedback text, was_helpful). Duration is calculated automatically from started_at timestamp.';

-- -----------------------------------------------------
-- 2.5 Get Voice Preferences
-- -----------------------------------------------------
-- Fix: 20251124000001 - Made parameterless (uses auth.uid())
-- Fix: 20251124000002 - Fallback to user_profiles.language_preference
-- Fix: 20260107000001 - Include user_id in defaults, add security

CREATE OR REPLACE FUNCTION get_voice_preferences()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
DECLARE
  v_user_id UUID;
  v_prefs RECORD;
  v_user_lang TEXT;
  v_full_lang_code TEXT;
BEGIN
  -- Get current user ID from auth context
  v_user_id := auth.uid();

  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required: Cannot retrieve voice preferences for unauthenticated users'
      USING ERRCODE = 'PGRST301',
            HINT = 'User must be logged in to access voice preferences';
  END IF;

  -- Try to get existing voice preferences
  SELECT * INTO v_prefs
  FROM voice_preferences
  WHERE user_id = v_user_id;

  -- If voice preferences exist, return them
  IF v_prefs IS NOT NULL THEN
    RETURN jsonb_build_object(
      'id', v_prefs.id,
      'user_id', v_prefs.user_id,
      'preferred_language', v_prefs.preferred_language,
      'auto_detect_language', v_prefs.auto_detect_language,
      'tts_voice_gender', v_prefs.tts_voice_gender,
      'speaking_rate', v_prefs.speaking_rate,
      'pitch', v_prefs.pitch,
      'auto_play_response', v_prefs.auto_play_response,
      'show_transcription', v_prefs.show_transcription,
      'continuous_mode', v_prefs.continuous_mode,
      'use_study_context', v_prefs.use_study_context,
      'cite_scripture_references', v_prefs.cite_scripture_references,
      'notify_daily_quota_reached', v_prefs.notify_daily_quota_reached,
      'created_at', v_prefs.created_at,
      'updated_at', v_prefs.updated_at
    );
  END IF;

  -- Voice preferences don't exist, get language from user profile
  SELECT language_preference INTO v_user_lang
  FROM user_profiles
  WHERE id = v_user_id;

  -- Convert short language codes to full voice codes
  v_full_lang_code := CASE
    WHEN v_user_lang = 'en' THEN 'en-US'
    WHEN v_user_lang = 'hi' THEN 'hi-IN'
    WHEN v_user_lang = 'ml' THEN 'ml-IN'
    ELSE 'default'  -- Use 'default' to indicate system should use profile language
  END;

  -- Return defaults with user's profile language
  RETURN jsonb_build_object(
    'id', NULL,
    'user_id', v_user_id,
    'preferred_language', v_full_lang_code,
    'auto_detect_language', true,
    'tts_voice_gender', 'female',
    'speaking_rate', 0.95,
    'pitch', 0,
    'auto_play_response', true,
    'show_transcription', true,
    'continuous_mode', true,
    'use_study_context', true,
    'cite_scripture_references', true,
    'notify_daily_quota_reached', true,
    'created_at', NULL,
    'updated_at', NULL
  );
END;
$$;

COMMENT ON FUNCTION get_voice_preferences() IS
  'Returns voice preferences for authenticated user with fallback to user profile language and user_id field in defaults';

-- -----------------------------------------------------
-- 2.6 Get Voice Conversation History
-- -----------------------------------------------------
-- Fix: 20251124000001 - Made parameterless (uses auth.uid())

CREATE OR REPLACE FUNCTION get_voice_conversation_history(
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_user_id UUID;
  v_conversations JSONB;
  v_total_count INTEGER;
BEGIN
  -- Get current user ID from auth context
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'User not authenticated',
      'conversations', '[]'::jsonb,
      'total_count', 0
    );
  END IF;

  -- Get total count
  SELECT COUNT(*) INTO v_total_count
  FROM voice_conversations
  WHERE user_id = v_user_id;

  -- Get conversations with messages
  SELECT jsonb_agg(conv_data ORDER BY started_at DESC)
  INTO v_conversations
  FROM (
    SELECT
      jsonb_build_object(
        'id', vc.id,
        'session_id', vc.session_id,
        'language_code', vc.language_code,
        'conversation_type', vc.conversation_type,
        'total_messages', vc.total_messages,
        'total_duration_seconds', vc.total_duration_seconds,
        'status', vc.status,
        'rating', vc.rating,
        'user_rating', vc.user_rating,
        'started_at', vc.started_at,
        'ended_at', vc.ended_at,
        'messages', COALESCE(
          (SELECT jsonb_agg(
            jsonb_build_object(
              'id', cm.id,
              'role', cm.role,
              'content_text', cm.content_text,
              'scripture_references', cm.scripture_references,
              'book_names_corrected', cm.book_names_corrected,
              'corrections_made', cm.corrections_made,
              'created_at', cm.created_at
            ) ORDER BY cm.message_order
          )
          FROM voice_conversation_messages cm
          WHERE cm.conversation_id = vc.id
          ), '[]'::jsonb
        )
      ) as conv_data,
      vc.started_at
    FROM voice_conversations vc
    WHERE vc.user_id = v_user_id
    ORDER BY vc.started_at DESC
    LIMIT p_limit
    OFFSET p_offset
  ) sub;

  RETURN jsonb_build_object(
    'conversations', COALESCE(v_conversations, '[]'::jsonb),
    'total_count', v_total_count
  );
END;
$$;

COMMENT ON FUNCTION get_voice_conversation_history IS
  'Returns paginated conversation history with messages for authenticated user';

-- -----------------------------------------------------
-- 2.7 Get or Create Monthly Voice Usage
-- -----------------------------------------------------
-- Fix: 20260116000002 - NEW function for monthly tracking

CREATE OR REPLACE FUNCTION get_or_create_monthly_voice_usage(
  p_user_id UUID,
  p_tier TEXT
)
RETURNS voice_usage_tracking
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_current_month TEXT;
  v_usage_record voice_usage_tracking;
  v_daily_quota_limit INTEGER;
BEGIN
  v_current_month := to_char(CURRENT_DATE, 'YYYY-MM');

  -- Try to get existing record for current month
  SELECT * INTO v_usage_record
  FROM voice_usage_tracking
  WHERE user_id = p_user_id
    AND month_year = v_current_month;

  -- If no record exists, create one
  IF NOT FOUND THEN
    -- Determine daily quota limit based on tier
    v_daily_quota_limit := CASE
      WHEN p_tier = 'premium' THEN -1  -- Unlimited
      WHEN p_tier = 'plus' THEN 10
      WHEN p_tier = 'standard' THEN 10
      ELSE 0  -- free
    END;

    INSERT INTO voice_usage_tracking (
      user_id,
      usage_date,
      month_year,
      tier_at_time,
      conversations_started,
      conversations_completed,
      monthly_conversations_started,
      monthly_conversations_completed,
      total_messages_sent,
      total_messages_received,
      total_conversation_seconds,
      total_audio_seconds,
      language_usage,
      daily_quota_limit,
      daily_quota_used,
      quota_exceeded
    ) VALUES (
      p_user_id,
      CURRENT_DATE,
      v_current_month,
      p_tier,
      0, 0,  -- daily conversations
      0, 0,  -- monthly conversations
      0, 0, 0, 0,  -- message and time tracking
      '{}'::jsonb,  -- language_usage
      v_daily_quota_limit,
      0,
      FALSE
    )
    RETURNING * INTO v_usage_record;
  END IF;

  RETURN v_usage_record;
END;
$$;

COMMENT ON FUNCTION get_or_create_monthly_voice_usage IS
  'Atomically gets or creates a monthly voice usage tracking record for a user';

-- -----------------------------------------------------
-- 2.8 Check Monthly Voice Conversation Limit
-- -----------------------------------------------------
-- Fix: 20260116000002 - NEW function for explicit monthly limit checking

CREATE OR REPLACE FUNCTION check_monthly_voice_conversation_limit(
  p_user_id UUID,
  p_tier TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_current_month TEXT;
  v_conversations_used INTEGER;
  v_limit INTEGER;
  v_remaining INTEGER;
  v_can_start BOOLEAN;
BEGIN
  v_current_month := to_char(CURRENT_DATE, 'YYYY-MM');

  -- Set limit based on tier (matches new monthly limits)
  v_limit := CASE
    WHEN p_tier = 'premium' THEN -1  -- Unlimited
    WHEN p_tier = 'plus' THEN 10
    WHEN p_tier = 'standard' THEN 3
    ELSE 1  -- free
  END;

  -- Premium users bypass limit
  IF v_limit = -1 THEN
    RETURN jsonb_build_object(
      'can_start', TRUE,
      'conversations_used', 0,
      'limit', -1,
      'remaining', -1,
      'tier', p_tier,
      'month', v_current_month
    );
  END IF;

  -- Get current month's usage
  SELECT COALESCE(monthly_conversations_started, 0)
  INTO v_conversations_used
  FROM voice_usage_tracking
  WHERE user_id = p_user_id
    AND month_year = v_current_month;

  -- If no record, user hasn't started any conversations this month
  IF NOT FOUND THEN
    v_conversations_used := 0;
  END IF;

  -- Calculate remaining and determine if user can start new conversation
  v_remaining := GREATEST(0, v_limit - v_conversations_used);
  v_can_start := v_conversations_used < v_limit;

  RETURN jsonb_build_object(
    'can_start', v_can_start,
    'conversations_used', v_conversations_used,
    'limit', v_limit,
    'remaining', v_remaining,
    'tier', p_tier,
    'month', v_current_month
  );
END;
$$;

COMMENT ON FUNCTION check_monthly_voice_conversation_limit IS
  'Checks if a user can start a new voice conversation based on their tier and monthly usage. Returns JSON with can_start flag, usage stats, and remaining conversations. Tier limits: Free=1, Standard=3, Plus=10, Premium=unlimited per month.';

-- -----------------------------------------------------
-- 2.9 Reset Monthly Voice Limits (Cron Job Function)
-- -----------------------------------------------------
-- NEW: Function for automated monthly reset via pg_cron

CREATE OR REPLACE FUNCTION reset_monthly_voice_limits()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_users_reset INTEGER := 0;
  v_new_month TEXT;
  v_user_record RECORD;
BEGIN
  v_new_month := to_char(CURRENT_DATE, 'YYYY-MM');

  -- For each user who has voice usage tracking records
  FOR v_user_record IN
    SELECT DISTINCT user_id, tier_at_time
    FROM voice_usage_tracking
    WHERE month_year != v_new_month
  LOOP
    -- Create new monthly record with reset counters
    INSERT INTO voice_usage_tracking (
      user_id,
      usage_date,
      month_year,
      tier_at_time,
      conversations_started,
      conversations_completed,
      monthly_conversations_started,
      monthly_conversations_completed,
      total_messages_sent,
      total_messages_received,
      total_conversation_seconds,
      total_audio_seconds,
      language_usage,
      daily_quota_limit,
      daily_quota_used,
      quota_exceeded
    ) VALUES (
      v_user_record.user_id,
      CURRENT_DATE,
      v_new_month,
      v_user_record.tier_at_time,
      0, 0,  -- daily conversations reset
      0, 0,  -- monthly conversations reset
      0, 0, 0, 0,  -- message and time tracking reset
      '{}'::jsonb,
      CASE
        WHEN v_user_record.tier_at_time = 'premium' THEN -1
        WHEN v_user_record.tier_at_time = 'plus' THEN 10
        WHEN v_user_record.tier_at_time = 'standard' THEN 10
        ELSE 0
      END,
      0,
      FALSE
    )
    ON CONFLICT (user_id, usage_date) DO NOTHING;

    v_users_reset := v_users_reset + 1;
  END LOOP;

  RAISE NOTICE 'Reset monthly voice limits for % users for month %', v_users_reset, v_new_month;
  RETURN v_users_reset;
END;
$$;

COMMENT ON FUNCTION reset_monthly_voice_limits IS
  'Resets monthly voice conversation limits for all users. Should be called on 1st of every month via pg_cron.

  CRON SETUP REQUIRED:
  Run: backend/supabase/scripts/backup/setup_monthly_voice_reset_cron.sh

  Or manually:
  SELECT cron.schedule(
    ''reset-monthly-voice-limits'',
    ''0 0 1 * *'',  -- 1st of month at midnight UTC
    $$SELECT reset_monthly_voice_limits();$$
  );

  Manual execution: SELECT reset_monthly_voice_limits();';

-- =====================================================
-- PART 3: TRIGGERS
-- =====================================================

-- -----------------------------------------------------
-- 3.1 Trigger: Update Conversation Message Count
-- -----------------------------------------------------

CREATE OR REPLACE FUNCTION update_conversation_message_count()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE voice_conversations
  SET
    total_messages = total_messages + 1,
    updated_at = NOW()
  WHERE id = NEW.conversation_id;

  -- Also update daily usage tracking for messages
  UPDATE voice_usage_tracking
  SET
    total_messages_sent = CASE WHEN NEW.role = 'user'
      THEN total_messages_sent + 1 ELSE total_messages_sent END,
    total_messages_received = CASE WHEN NEW.role = 'assistant'
      THEN total_messages_received + 1 ELSE total_messages_received END,
    total_audio_seconds = total_audio_seconds + COALESCE(NEW.audio_duration_seconds, 0),
    updated_at = NOW()
  WHERE user_id = NEW.user_id
    AND usage_date = CURRENT_DATE;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_update_voice_conversation_message_count
  AFTER INSERT ON voice_conversation_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_message_count();

-- -----------------------------------------------------
-- 3.2 Trigger: Update updated_at Timestamp
-- -----------------------------------------------------

CREATE OR REPLACE FUNCTION update_voice_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_voice_conversations_updated_at
  BEFORE UPDATE ON voice_conversations
  FOR EACH ROW
  EXECUTE FUNCTION update_voice_updated_at();

CREATE TRIGGER trg_voice_usage_updated_at
  BEFORE UPDATE ON voice_usage_tracking
  FOR EACH ROW
  EXECUTE FUNCTION update_voice_updated_at();

CREATE TRIGGER trg_voice_preferences_updated_at
  BEFORE UPDATE ON voice_preferences
  FOR EACH ROW
  EXECUTE FUNCTION update_voice_updated_at();

-- =====================================================
-- PART 4: ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE voice_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_conversation_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_usage_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_preferences ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------
-- 4.1 voice_conversations Policies
-- -----------------------------------------------------

CREATE POLICY "Users can view own conversations"
  ON voice_conversations FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own conversations"
  ON voice_conversations FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own conversations"
  ON voice_conversations FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own conversations"
  ON voice_conversations FOR DELETE
  USING (auth.uid() = user_id);

-- -----------------------------------------------------
-- 4.2 voice_conversation_messages Policies
-- -----------------------------------------------------

CREATE POLICY "Users can view own voice messages"
  ON voice_conversation_messages FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own voice messages"
  ON voice_conversation_messages FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- -----------------------------------------------------
-- 4.3 voice_usage_tracking Policies
-- -----------------------------------------------------

CREATE POLICY "Users can view own usage"
  ON voice_usage_tracking FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own usage"
  ON voice_usage_tracking FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own usage"
  ON voice_usage_tracking FOR UPDATE
  USING (auth.uid() = user_id);

-- -----------------------------------------------------
-- 4.4 voice_preferences Policies
-- -----------------------------------------------------

CREATE POLICY "Users can view own preferences"
  ON voice_preferences FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own preferences"
  ON voice_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences"
  ON voice_preferences FOR UPDATE
  USING (auth.uid() = user_id);

-- =====================================================
-- PART 5: GRANTS
-- =====================================================

GRANT EXECUTE ON FUNCTION get_user_subscription_tier TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION check_voice_quota TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION increment_voice_usage TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION complete_voice_conversation TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_voice_preferences TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_voice_conversation_history TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_or_create_monthly_voice_usage TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION check_monthly_voice_conversation_limit TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION reset_monthly_voice_limits TO service_role; -- Only service_role for cron

-- =====================================================
-- PART 6: DATA FIXES
-- =====================================================

-- Fix: 20251204000003 - Correct inflated daily_quota_used values
DO $$
DECLARE
  affected_rows INTEGER;
BEGIN
  UPDATE voice_usage_tracking
  SET daily_quota_used = conversations_started,
      updated_at = NOW()
  WHERE daily_quota_used > conversations_started;

  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  RAISE NOTICE 'Fixed % voice_usage_tracking records with inflated quota counts', affected_rows;
END $$;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
BEGIN
  -- Verify tables
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'voice_conversations') THEN
    RAISE EXCEPTION 'Migration failed: voice_conversations table not created';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'voice_conversation_messages') THEN
    RAISE EXCEPTION 'Migration failed: voice_conversation_messages table not created';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'voice_usage_tracking') THEN
    RAISE EXCEPTION 'Migration failed: voice_usage_tracking table not created';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'voice_preferences') THEN
    RAISE EXCEPTION 'Migration failed: voice_preferences table not created';
  END IF;

  -- Verify key columns
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'voice_usage_tracking' AND column_name = 'month_year'
  ) THEN
    RAISE EXCEPTION 'Migration failed: month_year column not created';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'voice_conversation_messages' AND column_name = 'book_names_corrected'
  ) THEN
    RAISE EXCEPTION 'Migration failed: book_names_corrected column not created';
  END IF;

  -- Verify functions
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'reset_monthly_voice_limits') THEN
    RAISE EXCEPTION 'Migration failed: reset_monthly_voice_limits function not created';
  END IF;

  RAISE NOTICE 'Migration 0006_voice_system.sql completed successfully - 4 tables, 9 functions';
END $$;

-- =====================================================
-- PART 8: POPULATE VOICE CONVERSATION LIMITS IN FEATURES
-- =====================================================

-- Add voice_conversations_monthly to subscription_plans.features
-- Makes voice limits database-driven instead of hardcoded

-- Free Plan: 0 conversations/month
UPDATE public.subscription_plans
SET
  features = features || '{"voice_conversations_monthly": 0}'::jsonb,
  updated_at = NOW()
WHERE plan_code = 'free';

-- Standard Plan: 10 conversations/month
UPDATE public.subscription_plans
SET
  features = features || '{"voice_conversations_monthly": 10}'::jsonb,
  updated_at = NOW()
WHERE plan_code = 'standard';

-- Plus Plan: 15 conversations/month
UPDATE public.subscription_plans
SET
  features = features || '{"voice_conversations_monthly": 15}'::jsonb,
  updated_at = NOW()
WHERE plan_code = 'plus';

-- Premium Plan: -1 (unlimited)
UPDATE public.subscription_plans
SET
  features = features || '{"voice_conversations_monthly": -1}'::jsonb,
  updated_at = NOW()
WHERE plan_code = 'premium';

COMMIT;

-- =====================================================
-- POST-MIGRATION SETUP REQUIRED
-- =====================================================
--
-- IMPORTANT: After this migration, you MUST setup the monthly
-- voice limit reset cron job by running:
--
--   backend/supabase/scripts/backup/setup_monthly_voice_reset_cron.sh
--
-- This schedules reset_monthly_voice_limits() to run automatically
-- on the 1st of every month at 00:00 UTC.
-- =====================================================
