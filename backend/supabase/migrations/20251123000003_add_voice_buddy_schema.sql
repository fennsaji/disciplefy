-- ============================================================================
-- Migration: Add AI Study Buddy Voice Schema
-- Version: 1.0
-- Date: 2025-11-23
-- Description: Creates all voice-related tables for the AI Study Buddy Voice feature
--              including conversations, messages, usage tracking, and preferences
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. VOICE CONVERSATIONS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS voice_conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Session Info
  session_id TEXT NOT NULL, -- Client-generated UUID
  language_code TEXT NOT NULL DEFAULT 'en-US' CHECK (language_code IN ('en-US', 'hi-IN', 'ml-IN')),

  -- Conversation Context
  conversation_type TEXT NOT NULL DEFAULT 'general' CHECK (conversation_type IN (
    'general',           -- Open-ended questions
    'study_enhancement', -- Questions during study guide
    'scripture_inquiry', -- Specific verse questions
    'prayer_guidance',   -- Prayer-related
    'theological_debate' -- Deep theological discussion
  )),

  related_study_guide_id UUID REFERENCES study_guides(id) ON DELETE SET NULL, -- If asking about a specific study
  related_scripture TEXT, -- e.g., "John 3:16"

  -- Conversation Metadata
  total_messages INTEGER DEFAULT 0,
  total_duration_seconds INTEGER DEFAULT 0,

  -- Status
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
    'active',
    'completed',
    'abandoned'
  )),

  -- User Feedback
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  feedback_text TEXT,
  was_helpful BOOLEAN,

  -- Timestamps
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for voice_conversations
CREATE INDEX IF NOT EXISTS idx_voice_conversations_user_id ON voice_conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_voice_conversations_session_id ON voice_conversations(session_id);
CREATE INDEX IF NOT EXISTS idx_voice_conversations_status ON voice_conversations(status);
CREATE INDEX IF NOT EXISTS idx_voice_conversations_language ON voice_conversations(language_code);
CREATE INDEX IF NOT EXISTS idx_voice_conversations_started_at ON voice_conversations(user_id, started_at DESC);

-- Comments
COMMENT ON TABLE voice_conversations IS 'Stores voice conversation sessions for AI Study Buddy Voice feature';
COMMENT ON COLUMN voice_conversations.session_id IS 'Client-generated UUID for WebSocket session management';
COMMENT ON COLUMN voice_conversations.conversation_type IS 'Type of conversation context for tailored AI responses';
COMMENT ON COLUMN voice_conversations.related_study_guide_id IS 'Links conversation to active study guide for context';

-- ============================================================================
-- 2. VOICE CONVERSATION MESSAGES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS voice_conversation_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID NOT NULL REFERENCES voice_conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Message Info
  message_order INTEGER NOT NULL, -- Sequence in conversation (1, 2, 3...)
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),

  -- Content
  content_text TEXT NOT NULL, -- Transcribed/generated text
  content_language TEXT NOT NULL DEFAULT 'en-US',

  -- Audio Metadata (if available)
  audio_duration_seconds DECIMAL(6,2),
  audio_url TEXT, -- Supabase Storage URL (if we cache audio)

  -- Processing Metadata
  transcription_confidence DECIMAL(4,3), -- 0.000 to 1.000 (from STT)
  llm_model_used TEXT, -- e.g., 'gpt-4-turbo-preview'
  llm_tokens_used INTEGER,

  -- Scripture References (for assistant messages)
  scripture_references TEXT[], -- Array of references like ['John 3:16', 'Romans 8:28']

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(conversation_id, message_order)
);

-- Indexes for voice_conversation_messages
CREATE INDEX IF NOT EXISTS idx_voice_conversation_messages_conversation_id ON voice_conversation_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_voice_conversation_messages_user_id ON voice_conversation_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_voice_conversation_messages_order ON voice_conversation_messages(conversation_id, message_order);

-- Comments
COMMENT ON TABLE voice_conversation_messages IS 'Individual messages within voice conversations';
COMMENT ON COLUMN voice_conversation_messages.message_order IS 'Sequential order of message in conversation for proper replay';
COMMENT ON COLUMN voice_conversation_messages.transcription_confidence IS 'STT confidence score from 0.000 to 1.000';

-- ============================================================================
-- 3. VOICE USAGE TRACKING TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS voice_usage_tracking (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Usage Period
  usage_date DATE NOT NULL DEFAULT CURRENT_DATE,

  -- Usage Counts
  conversations_started INTEGER DEFAULT 0,
  conversations_completed INTEGER DEFAULT 0,
  total_messages_sent INTEGER DEFAULT 0,
  total_messages_received INTEGER DEFAULT 0,

  -- Duration Tracking
  total_conversation_seconds INTEGER DEFAULT 0,
  total_audio_seconds INTEGER DEFAULT 0,

  -- Language Usage
  language_usage JSONB DEFAULT '{}',
  -- Example: {"en-US": 5, "hi-IN": 2, "ml-IN": 1}

  -- Subscription Tier (at time of use)
  tier_at_time TEXT NOT NULL CHECK (tier_at_time IN ('free', 'standard', 'premium')),

  -- Quota Management
  daily_quota_limit INTEGER, -- Conversations allowed per day
  daily_quota_used INTEGER DEFAULT 0,
  quota_exceeded BOOLEAN DEFAULT FALSE,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, usage_date)
);

-- Indexes for voice_usage_tracking
CREATE INDEX IF NOT EXISTS idx_voice_usage_user_id ON voice_usage_tracking(user_id);
CREATE INDEX IF NOT EXISTS idx_voice_usage_date ON voice_usage_tracking(usage_date);
CREATE INDEX IF NOT EXISTS idx_voice_usage_tier ON voice_usage_tracking(tier_at_time);

-- Comments
COMMENT ON TABLE voice_usage_tracking IS 'Daily usage tracking for voice conversation quota management';
COMMENT ON COLUMN voice_usage_tracking.language_usage IS 'JSONB object tracking conversation count per language';
COMMENT ON COLUMN voice_usage_tracking.tier_at_time IS 'User subscription tier when usage occurred';

-- ============================================================================
-- 4. VOICE PREFERENCES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS voice_preferences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Language Preferences
  preferred_language TEXT NOT NULL DEFAULT 'en-US' CHECK (preferred_language IN ('en-US', 'hi-IN', 'ml-IN')),
  auto_detect_language BOOLEAN DEFAULT TRUE,

  -- Voice Settings
  tts_voice_gender TEXT DEFAULT 'female' CHECK (tts_voice_gender IN ('male', 'female')),
  speaking_rate DECIMAL(3,2) DEFAULT 0.95 CHECK (speaking_rate BETWEEN 0.5 AND 2.0),
  pitch DECIMAL(4,2) DEFAULT 0.0 CHECK (pitch BETWEEN -20.0 AND 20.0),

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
COMMENT ON TABLE voice_preferences IS 'User preferences for voice conversation settings';
COMMENT ON COLUMN voice_preferences.speaking_rate IS 'TTS speaking rate from 0.5 (slow) to 2.0 (fast)';
COMMENT ON COLUMN voice_preferences.pitch IS 'TTS pitch adjustment from -20.0 to 20.0';
COMMENT ON COLUMN voice_preferences.continuous_mode IS 'Keep microphone open for continuous conversation';

-- ============================================================================
-- 5. ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE voice_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_conversation_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_usage_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_preferences ENABLE ROW LEVEL SECURITY;

-- voice_conversations policies
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

-- voice_conversation_messages policies
CREATE POLICY "Users can view own voice messages"
  ON voice_conversation_messages FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own voice messages"
  ON voice_conversation_messages FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- voice_usage_tracking policies
CREATE POLICY "Users can view own usage"
  ON voice_usage_tracking FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own usage"
  ON voice_usage_tracking FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own usage"
  ON voice_usage_tracking FOR UPDATE
  USING (auth.uid() = user_id);

-- voice_preferences policies
CREATE POLICY "Users can view own preferences"
  ON voice_preferences FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own preferences"
  ON voice_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences"
  ON voice_preferences FOR UPDATE
  USING (auth.uid() = user_id);

-- ============================================================================
-- 6. DATABASE FUNCTIONS
-- ============================================================================

-- Function to check daily voice quota
CREATE OR REPLACE FUNCTION check_voice_quota(p_user_id UUID, p_tier TEXT)
RETURNS JSONB AS $$
DECLARE
  v_usage RECORD;
  v_quota_limit INTEGER;
  v_can_start BOOLEAN;
BEGIN
  -- Determine quota based on tier
  v_quota_limit := CASE
    WHEN p_tier = 'free' THEN 3
    WHEN p_tier = 'standard' THEN 10
    WHEN p_tier = 'premium' THEN 999999 -- Unlimited
    ELSE 0
  END;

  -- Get today's usage
  SELECT * INTO v_usage
  FROM voice_usage_tracking
  WHERE user_id = p_user_id
    AND usage_date = CURRENT_DATE;

  -- If no record, create one
  IF v_usage IS NULL THEN
    INSERT INTO voice_usage_tracking (user_id, tier_at_time, daily_quota_limit)
    VALUES (p_user_id, p_tier, v_quota_limit)
    RETURNING * INTO v_usage;
  END IF;

  -- Check if can start new conversation
  v_can_start := v_usage.daily_quota_used < v_quota_limit;

  RETURN jsonb_build_object(
    'can_start', v_can_start,
    'quota_limit', v_quota_limit,
    'quota_used', v_usage.daily_quota_used,
    'quota_remaining', GREATEST(0, v_quota_limit - v_usage.daily_quota_used)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION check_voice_quota IS 'Checks if user can start a new voice conversation based on tier quota';

-- Function to increment voice usage when starting a conversation
CREATE OR REPLACE FUNCTION increment_voice_usage(
  p_user_id UUID,
  p_tier TEXT,
  p_language TEXT
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO voice_usage_tracking (
    user_id,
    usage_date,
    tier_at_time,
    daily_quota_limit,
    daily_quota_used,
    conversations_started,
    language_usage
  )
  VALUES (
    p_user_id,
    CURRENT_DATE,
    p_tier,
    CASE
      WHEN p_tier = 'free' THEN 3
      WHEN p_tier = 'standard' THEN 10
      WHEN p_tier = 'premium' THEN 999999
    END,
    1,
    1,
    jsonb_build_object(p_language, 1)
  )
  ON CONFLICT (user_id, usage_date)
  DO UPDATE SET
    daily_quota_used = voice_usage_tracking.daily_quota_used + 1,
    conversations_started = voice_usage_tracking.conversations_started + 1,
    language_usage = jsonb_set(
      voice_usage_tracking.language_usage,
      ARRAY[p_language],
      to_jsonb(COALESCE((voice_usage_tracking.language_usage->>p_language)::INTEGER, 0) + 1)
    ),
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION increment_voice_usage IS 'Increments daily voice usage count when user starts a conversation';

-- Function to update conversation completion stats
CREATE OR REPLACE FUNCTION complete_voice_conversation(
  p_conversation_id UUID,
  p_duration_seconds INTEGER
)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Get user_id from conversation
  SELECT user_id INTO v_user_id
  FROM voice_conversations
  WHERE id = p_conversation_id;

  -- Update conversation status
  UPDATE voice_conversations
  SET
    status = 'completed',
    ended_at = NOW(),
    total_duration_seconds = p_duration_seconds,
    updated_at = NOW()
  WHERE id = p_conversation_id;

  -- Update daily usage tracking
  UPDATE voice_usage_tracking
  SET
    conversations_completed = conversations_completed + 1,
    total_conversation_seconds = total_conversation_seconds + p_duration_seconds,
    updated_at = NOW()
  WHERE user_id = v_user_id
    AND usage_date = CURRENT_DATE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION complete_voice_conversation IS 'Marks conversation as completed and updates usage statistics';

-- Function to get user voice preferences with defaults
CREATE OR REPLACE FUNCTION get_voice_preferences(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_prefs RECORD;
BEGIN
  SELECT * INTO v_prefs
  FROM voice_preferences
  WHERE user_id = p_user_id;

  -- Return defaults if no preferences exist
  IF v_prefs IS NULL THEN
    RETURN jsonb_build_object(
      'preferred_language', 'en-US',
      'auto_detect_language', true,
      'tts_voice_gender', 'female',
      'speaking_rate', 0.95,
      'pitch', 0.0,
      'auto_play_response', true,
      'show_transcription', true,
      'continuous_mode', false,
      'use_study_context', true,
      'cite_scripture_references', true,
      'notify_daily_quota_reached', true
    );
  END IF;

  RETURN to_jsonb(v_prefs) - 'id' - 'user_id' - 'created_at' - 'updated_at';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_voice_preferences IS 'Returns user voice preferences with sensible defaults if not set';

-- Function to get conversation history for a user
CREATE OR REPLACE FUNCTION get_voice_conversation_history(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
  v_conversations JSONB;
  v_total_count INTEGER;
BEGIN
  -- Get total count
  SELECT COUNT(*) INTO v_total_count
  FROM voice_conversations
  WHERE user_id = p_user_id;

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
        'started_at', vc.started_at,
        'ended_at', vc.ended_at,
        'messages', COALESCE(
          (SELECT jsonb_agg(
            jsonb_build_object(
              'id', cm.id,
              'role', cm.role,
              'content_text', cm.content_text,
              'scripture_references', cm.scripture_references,
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
    WHERE vc.user_id = p_user_id
    ORDER BY vc.started_at DESC
    LIMIT p_limit
    OFFSET p_offset
  ) sub;

  RETURN jsonb_build_object(
    'conversations', COALESCE(v_conversations, '[]'::jsonb),
    'total_count', v_total_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_voice_conversation_history IS 'Returns paginated conversation history with messages for a user';

-- ============================================================================
-- 7. TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

-- Trigger to update conversation message count
CREATE OR REPLACE FUNCTION update_conversation_message_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE voice_conversations
  SET
    total_messages = total_messages + 1,
    updated_at = NOW()
  WHERE id = NEW.conversation_id;

  -- Also update daily usage tracking for messages
  UPDATE voice_usage_tracking
  SET
    total_messages_sent = CASE WHEN NEW.role = 'user' THEN total_messages_sent + 1 ELSE total_messages_sent END,
    total_messages_received = CASE WHEN NEW.role = 'assistant' THEN total_messages_received + 1 ELSE total_messages_received END,
    total_audio_seconds = total_audio_seconds + COALESCE(NEW.audio_duration_seconds, 0),
    updated_at = NOW()
  WHERE user_id = NEW.user_id
    AND usage_date = CURRENT_DATE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_voice_conversation_message_count
  AFTER INSERT ON voice_conversation_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_message_count();

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_voice_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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

COMMIT;
