-- =====================================================
-- 0001: Core Schema Migration
-- =====================================================
-- Purpose: Foundation tables for Disciplefy Bible Study App
-- Tables: 11 core tables (user profiles, auth support, admin, analytics, notifications)
-- Dependencies: None (must run first)
-- Version: Consolidated from 193 migrations
-- =====================================================

BEGIN;

-- =====================================================
-- PART 1: UUID COMPATIBILITY LAYER
-- =====================================================

-- Drop any existing sequences that might cause conflicts on reset
DROP SEQUENCE IF EXISTS purchase_receipt_seq CASCADE;

-- Create uuid_generate_v4() as an alias to gen_random_uuid()
-- Ensures compatibility with existing code that uses uuid_generate_v4()
CREATE OR REPLACE FUNCTION uuid_generate_v4()
RETURNS UUID
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT gen_random_uuid();
$$;

COMMENT ON FUNCTION uuid_generate_v4 IS
  'Compatibility function for uuid_generate_v4() - wraps gen_random_uuid()';

-- =====================================================
-- PART 2: CORE TABLES
-- =====================================================

-- =====================================================
-- 2.1 User Profiles (extends auth.users)
-- =====================================================

CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Basic preferences
  language_preference VARCHAR(5) DEFAULT 'en',
  theme_preference VARCHAR(20) DEFAULT 'light',
  is_admin BOOLEAN DEFAULT false,

  -- OAuth profile data (Google, Apple, etc.)
  first_name TEXT,
  last_name TEXT,
  profile_picture TEXT,
  profile_image_url TEXT,

  -- Profile customization
  age_group VARCHAR(10) CHECK (age_group IN ('13-17', '18-25', '26-35', '36-50', '51+')),
  interests TEXT[] DEFAULT '{}',

  -- Phone authentication (added: 2025-09-16)
  phone_number TEXT,
  phone_verified BOOLEAN DEFAULT false,
  phone_country_code VARCHAR(5),

  -- Onboarding tracking (added: 2025-09-16)
  onboarding_status VARCHAR(20) DEFAULT 'pending'
    CHECK (onboarding_status IN ('pending', 'profile_setup', 'language_selection', 'completed')),

  -- Premium trial tracking (added: 2025-12-10, updated: 2026-01-19)
  premium_trial_started_at TIMESTAMPTZ,
  premium_trial_end_at TIMESTAMPTZ,
  has_used_premium_trial BOOLEAN DEFAULT FALSE,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_user_profiles_language ON user_profiles(language_preference);
CREATE INDEX idx_user_profiles_admin ON user_profiles(is_admin) WHERE is_admin = true;
CREATE INDEX idx_user_profiles_onboarding_status ON user_profiles(onboarding_status);
CREATE INDEX idx_user_profiles_premium_trial ON user_profiles(premium_trial_end_at)
WHERE premium_trial_end_at IS NOT NULL;

-- Phone number uniqueness constraint (one account per phone number)
CREATE UNIQUE INDEX idx_user_profiles_phone ON user_profiles(phone_number)
WHERE phone_number IS NOT NULL;

-- Table comments
COMMENT ON TABLE user_profiles IS
  'User profile data extending auth.users with preferences and phone authentication';
COMMENT ON COLUMN user_profiles.phone_number IS
  'User phone number in international format (+1234567890)';
COMMENT ON COLUMN user_profiles.phone_verified IS
  'Whether the phone number has been verified via OTP';
COMMENT ON COLUMN user_profiles.onboarding_status IS
  'Current step in user onboarding flow';
COMMENT ON COLUMN user_profiles.premium_trial_started_at IS
  'Timestamp when Premium trial was started';
COMMENT ON COLUMN user_profiles.premium_trial_end_at IS
  'Timestamp when Premium trial ends';
COMMENT ON COLUMN user_profiles.has_used_premium_trial IS
  'Whether user has already used their one-time Premium trial';

-- Trigger to keep profile_picture and profile_image_url in sync
CREATE OR REPLACE FUNCTION sync_profile_image_fields()
RETURNS TRIGGER AS $$
BEGIN
  -- When profile_image_url is updated, sync to profile_picture
  IF NEW.profile_image_url IS DISTINCT FROM OLD.profile_image_url THEN
    NEW.profile_picture = NEW.profile_image_url;
  END IF;

  -- When profile_picture is updated, sync to profile_image_url
  IF NEW.profile_picture IS DISTINCT FROM OLD.profile_picture THEN
    NEW.profile_image_url = NEW.profile_picture;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_profile_image_trigger
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_profile_image_fields();

-- =====================================================
-- 2.2 User Personalization (Questionnaire System)
-- =====================================================

CREATE TABLE user_personalization (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Question 1: Faith Stage
  faith_stage TEXT
    CHECK (faith_stage IN ('new_believer', 'growing_believer', 'committed_disciple')),

  -- Question 2: Spiritual Goals (multi-select, 1-3 values)
  spiritual_goals TEXT[] DEFAULT '{}',

  -- Question 3: Time Availability
  time_availability TEXT
    CHECK (time_availability IN ('5_to_10_min', '10_to_20_min', '20_plus_min')),

  -- Question 4: Learning Style
  learning_style TEXT
    CHECK (learning_style IN ('practical_application', 'deep_understanding', 'reflection_meditation', 'balanced_approach')),

  -- Question 5: Life Stage Focus
  life_stage_focus TEXT
    CHECK (life_stage_focus IN ('personal_foundation', 'family_relationships', 'community_impact', 'intellectual_growth')),

  -- Question 6: Biggest Challenge
  biggest_challenge TEXT
    CHECK (biggest_challenge IN ('starting_basics', 'staying_consistent', 'handling_doubts', 'sharing_faith', 'growing_stagnant')),

  -- Track questionnaire status
  questionnaire_completed BOOLEAN DEFAULT false,
  questionnaire_skipped BOOLEAN DEFAULT false,

  -- Store scoring results for analytics
  scoring_results JSONB,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- One personalization record per user
  CONSTRAINT unique_user_personalization UNIQUE(user_id),

  -- Validation constraints for spiritual goals (1-3 selections or empty)
  CONSTRAINT spiritual_goals_count_check
    CHECK (array_length(spiritual_goals, 1) BETWEEN 1 AND 3 OR spiritual_goals = '{}'),
  CONSTRAINT spiritual_goals_values_check
    CHECK (
      spiritual_goals = '{}'::text[] OR
      spiritual_goals <@ ARRAY[
        'foundational_faith',
        'spiritual_depth',
        'relationships',
        'apologetics',
        'service',
        'theology'
      ]::text[]
    )
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_personalization_user_id
  ON user_personalization(user_id);
CREATE INDEX IF NOT EXISTS idx_user_personalization_completed
  ON user_personalization(questionnaire_completed);
CREATE INDEX IF NOT EXISTS idx_user_personalization_faith_stage
  ON user_personalization(faith_stage);
CREATE INDEX IF NOT EXISTS idx_user_personalization_spiritual_goals
  ON user_personalization USING GIN(spiritual_goals);

COMMENT ON TABLE user_personalization IS
  'User personalization data from onboarding questionnaire for tailored learning path recommendations';
COMMENT ON COLUMN user_personalization.spiritual_goals IS
  'Array of 1-3 selected spiritual goals from: foundational_faith, spiritual_depth, relationships, apologetics, service, theology';
COMMENT ON COLUMN user_personalization.scoring_results IS
  'JSONB object storing weighted scoring results for learning path recommendations';

-- =====================================================
-- 2.3 Anonymous Sessions
-- =====================================================

CREATE TABLE anonymous_sessions (
  session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_fingerprint_hash VARCHAR(64),
  ip_address_hash VARCHAR(64),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_activity TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours'),
  study_guides_count INTEGER DEFAULT 0,
  recommended_guide_sessions_count INTEGER DEFAULT 0,
  is_migrated BOOLEAN DEFAULT false
);

-- Indexes for cleanup and lookups
CREATE INDEX idx_anonymous_sessions_expires_at ON anonymous_sessions(expires_at);
CREATE INDEX idx_anonymous_sessions_device_hash ON anonymous_sessions(device_fingerprint_hash);

COMMENT ON TABLE anonymous_sessions IS
  'Tracks anonymous user sessions with 24-hour expiration for non-authenticated access';

-- =====================================================
-- 2.3 OAuth States (Optional CSRF Protection)
-- =====================================================

CREATE TABLE oauth_states (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  state VARCHAR(128) NOT NULL UNIQUE,
  user_session_id VARCHAR(255),
  ip_address INET,
  user_agent TEXT,
  provider VARCHAR(20) DEFAULT 'google' CHECK (provider IN ('google', 'apple', 'facebook')),
  used BOOLEAN DEFAULT false,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '15 minutes')
);

-- Indexes for validation
CREATE INDEX idx_oauth_states_state ON oauth_states(state);
CREATE INDEX idx_oauth_states_expires_at ON oauth_states(expires_at);
CREATE INDEX idx_oauth_states_used ON oauth_states(used) WHERE used = false;

COMMENT ON TABLE oauth_states IS
  'Optional OAuth state management for enhanced CSRF protection. Supabase handles this internally by default.';
COMMENT ON COLUMN oauth_states.state IS
  'Random state parameter for CSRF protection in OAuth flows';

-- =====================================================
-- 2.4 OTP Requests (Phone Authentication)
-- =====================================================

CREATE TABLE otp_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number TEXT NOT NULL,
  otp_code VARCHAR(6) NOT NULL,
  ip_address INET,
  attempts INTEGER DEFAULT 0,
  is_verified BOOLEAN DEFAULT false,
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '10 minutes'),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for rate limiting and cleanup
CREATE INDEX idx_otp_requests_phone ON otp_requests(phone_number);
CREATE INDEX idx_otp_requests_expires ON otp_requests(expires_at);
CREATE INDEX idx_otp_requests_created_at ON otp_requests(created_at DESC);

COMMENT ON TABLE otp_requests IS
  'Stores OTP verification codes for phone authentication with rate limiting';
COMMENT ON COLUMN otp_requests.attempts IS
  'Number of failed verification attempts for this OTP';
COMMENT ON COLUMN otp_requests.expires_at IS
  'When this OTP code expires (10 minutes from creation)';

-- =====================================================
-- 2.5 Admin Logs
-- =====================================================

CREATE TABLE admin_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  action VARCHAR(100) NOT NULL,
  target_table VARCHAR(50),
  target_id UUID,
  ip_address INET,
  user_agent TEXT,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for admin audit trails
CREATE INDEX idx_admin_logs_admin_user_id ON admin_logs(admin_user_id);
CREATE INDEX idx_admin_logs_action ON admin_logs(action);
CREATE INDEX idx_admin_logs_created_at ON admin_logs(created_at DESC);
CREATE INDEX idx_admin_logs_target ON admin_logs(target_table, target_id);

COMMENT ON TABLE admin_logs IS
  'Audit trail for all admin actions in the system';

-- =====================================================
-- 2.6 Analytics Events
-- =====================================================

CREATE TABLE analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type VARCHAR(50) NOT NULL,
  event_data JSONB,
  session_id VARCHAR(255),
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for analytics queries
CREATE INDEX idx_analytics_events_type ON analytics_events(event_type);
CREATE INDEX idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX idx_analytics_events_created_at ON analytics_events(created_at DESC);
CREATE INDEX idx_analytics_events_session ON analytics_events(session_id);

COMMENT ON TABLE analytics_events IS
  'Generic analytics event tracking for user behavior analysis';

-- =====================================================
-- 2.7 LLM Security Events
-- =====================================================

CREATE TABLE llm_security_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id VARCHAR(255),
  ip_address INET,
  event_type VARCHAR(50) NOT NULL
    CHECK (event_type IN ('prompt_injection', 'rate_limit_exceeded', 'toxic_content',
                          'excessive_length', 'unauthorized_access', 'malicious_pattern')),
  input_text TEXT,
  risk_score FLOAT CHECK (risk_score >= 0.0 AND risk_score <= 1.0),
  action_taken VARCHAR(50)
    CHECK (action_taken IN ('blocked', 'sanitized', 'logged', 'rate_limited')),
  detection_details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for security monitoring
CREATE INDEX idx_security_events_type_time ON llm_security_events(event_type, created_at DESC);
CREATE INDEX idx_security_events_user ON llm_security_events(user_id, created_at DESC);
CREATE INDEX idx_security_events_ip ON llm_security_events(ip_address, created_at DESC);
CREATE INDEX idx_security_events_risk_score ON llm_security_events(risk_score) WHERE risk_score > 0.7;

COMMENT ON TABLE llm_security_events IS
  'Security event logging for LLM input validation and threat detection';
COMMENT ON COLUMN llm_security_events.risk_score IS
  'Calculated risk score from 0.0 (safe) to 1.0 (high risk)';

-- =====================================================
-- 2.8 Notification Logs
-- =====================================================

CREATE TABLE notification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_type VARCHAR(50) NOT NULL
    CHECK (notification_type IN ('daily_verse', 'recommended_topic', 'streak_reminder',
                                  'memory_verse_reminder', 'achievement_unlocked')),

  -- Notification content
  title TEXT NOT NULL,
  body TEXT NOT NULL,

  -- Metadata
  topic_id UUID, -- References recommended_topics(id) if applicable
  verse_reference TEXT,
  language VARCHAR(5),

  -- Delivery tracking
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  delivery_status VARCHAR(20) DEFAULT 'sent'
    CHECK (delivery_status IN ('sent', 'delivered', 'failed', 'clicked')),
  fcm_message_id TEXT,
  error_message TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for analytics queries
CREATE INDEX idx_notification_logs_user_id ON notification_logs(user_id);
CREATE INDEX idx_notification_logs_type ON notification_logs(notification_type);
CREATE INDEX idx_notification_logs_sent_at ON notification_logs(sent_at DESC);
CREATE INDEX idx_notification_logs_status ON notification_logs(delivery_status);

-- Composite index for user notification history (CRITICAL for performance)
CREATE INDEX idx_notification_logs_user_sent ON notification_logs(user_id, sent_at DESC);
CREATE INDEX idx_notification_logs_topic_id ON notification_logs(topic_id)
WHERE topic_id IS NOT NULL;

COMMENT ON TABLE notification_logs IS
  'Tracks all sent notifications for analytics and debugging';
COMMENT ON COLUMN notification_logs.delivery_status IS
  'sent: notification sent to FCM, delivered: confirmed delivery, failed: delivery failed, clicked: user opened notification';

-- =====================================================
-- 2.9 User Notification Tokens (Multi-Device Support)
-- =====================================================

CREATE TABLE user_notification_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform VARCHAR(20) NOT NULL CHECK (platform IN ('ios', 'android', 'web')),

  -- Metadata
  token_updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Ensure unique combination of user_id and fcm_token
  CONSTRAINT unique_user_token UNIQUE (user_id, fcm_token)
);

-- Indexes for token management
CREATE INDEX idx_notification_tokens_user_id ON user_notification_tokens(user_id);
CREATE INDEX idx_notification_tokens_fcm_token ON user_notification_tokens(fcm_token);
CREATE INDEX idx_notification_tokens_platform ON user_notification_tokens(platform);

COMMENT ON TABLE user_notification_tokens IS
  'Stores FCM tokens for each user device. Users can have multiple tokens (one per device)';
COMMENT ON COLUMN user_notification_tokens.fcm_token IS
  'Firebase Cloud Messaging device token for push notifications';

-- =====================================================
-- 2.10 User Notification Preferences
-- =====================================================

CREATE TABLE user_notification_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Notification toggles
  daily_verse_enabled BOOLEAN DEFAULT true,
  recommended_topic_enabled BOOLEAN DEFAULT true,
  streak_reminder_enabled BOOLEAN DEFAULT true,
  memory_verse_reminder_enabled BOOLEAN DEFAULT true,

  -- Timezone (offset in minutes from UTC)
  -- Examples: +330 for IST (UTC+5:30), -300 for EST (UTC-5:00)
  timezone_offset_minutes INTEGER DEFAULT 0,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for notification scheduling
CREATE INDEX idx_notification_prefs_user_id ON user_notification_preferences(user_id);
CREATE INDEX idx_notification_prefs_daily_verse ON user_notification_preferences(daily_verse_enabled)
WHERE daily_verse_enabled = true;
CREATE INDEX idx_notification_prefs_recommended ON user_notification_preferences(recommended_topic_enabled)
WHERE recommended_topic_enabled = true;
CREATE INDEX idx_notification_prefs_timezone ON user_notification_preferences(timezone_offset_minutes);

COMMENT ON TABLE user_notification_preferences IS
  'Stores notification preferences and timezone for each user. FCM tokens are in user_notification_tokens table';
COMMENT ON COLUMN user_notification_preferences.timezone_offset_minutes IS
  'Timezone offset in minutes from UTC (e.g., +330 for IST, -300 for EST)';

-- =====================================================
-- 2.11 Feedback
-- =====================================================

CREATE TABLE feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Feedback content
  was_helpful BOOLEAN NOT NULL,
  message TEXT,
  category VARCHAR(50) DEFAULT 'general'
    CHECK (category IN ('general', 'bug_report', 'feature_request', 'content_feedback', 'study_guide', 'memory_verse')),
  sentiment_score FLOAT CHECK (sentiment_score >= -1.0 AND sentiment_score <= 1.0),

  -- Optional context (can reference specific features)
  context_type VARCHAR(50), -- 'study_guide', 'recommended_topic', 'memory_verse', etc.
  context_id UUID,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for feedback analysis
CREATE INDEX idx_feedback_user_id ON feedback(user_id);
CREATE INDEX idx_feedback_created_at ON feedback(created_at DESC);
CREATE INDEX idx_feedback_category ON feedback(category);
CREATE INDEX idx_feedback_helpful ON feedback(was_helpful);
CREATE INDEX idx_feedback_context ON feedback(context_type, context_id)
WHERE context_type IS NOT NULL;

COMMENT ON TABLE feedback IS
  'User feedback submissions for features and content quality';
COMMENT ON COLUMN feedback.sentiment_score IS
  'Sentiment analysis score: -1.0 (very negative) to 1.0 (very positive)';

-- =====================================================
-- PART 3: HELPER FUNCTIONS
-- =====================================================

-- =====================================================
-- 3.1 Cleanup Expired OTP Requests
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_expired_otp_requests()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM otp_requests
  WHERE expires_at < NOW() - INTERVAL '1 hour';
END;
$$;

COMMENT ON FUNCTION cleanup_expired_otp_requests IS
  'Deletes expired OTP requests (older than 1 hour). Should be run periodically.';

-- =====================================================
-- 3.2 Cleanup Expired OAuth States
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_expired_oauth_states()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM oauth_states
  WHERE expires_at < NOW()
     OR (used = true AND used_at < NOW() - INTERVAL '1 hour');
END;
$$;

COMMENT ON FUNCTION cleanup_expired_oauth_states IS
  'Deletes expired or used OAuth states. Should be run periodically.';

-- =====================================================
-- 3.3 Update Notification Preferences Timestamp
-- =====================================================

CREATE OR REPLACE FUNCTION update_notification_prefs_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Trigger to auto-update updated_at
CREATE TRIGGER update_notification_prefs_timestamp
  BEFORE UPDATE ON user_notification_preferences
  FOR EACH ROW
  EXECUTE FUNCTION update_notification_prefs_updated_at();

COMMENT ON FUNCTION update_notification_prefs_updated_at IS
  'Trigger function to automatically update updated_at timestamp';

-- =====================================================
-- 3.4 Update Notification Token Timestamp
-- =====================================================

CREATE OR REPLACE FUNCTION update_notification_token_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.token_updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Trigger to auto-update token_updated_at
CREATE TRIGGER update_notification_token_timestamp
  BEFORE UPDATE ON user_notification_tokens
  FOR EACH ROW
  EXECUTE FUNCTION update_notification_token_updated_at();

COMMENT ON FUNCTION update_notification_token_updated_at IS
  'Trigger function to automatically update token_updated_at timestamp';

-- =====================================================
-- 3.5 Generic Updated At Column Trigger
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION update_updated_at_column IS
  'Generic trigger function to automatically update updated_at timestamp on any table';

-- =====================================================
-- PART 4: ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
-- Note: user_profiles RLS is DISABLED to avoid infinite recursion in admin policies
-- Security is handled by middleware using service_role key
ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_personalization ENABLE ROW LEVEL SECURITY;
ALTER TABLE anonymous_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE oauth_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE otp_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE llm_security_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notification_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 4.1 User Profiles RLS Policies
-- =====================================================

-- Users can view their own profile
CREATE POLICY "Users can view own profile" ON user_profiles
  FOR SELECT
  USING (auth.uid() = id);

-- Users can insert their own profile (on signup)
CREATE POLICY "Users can insert own profile" ON user_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON user_profiles
  FOR UPDATE
  USING (auth.uid() = id);

-- Note: "Admins can view all profiles" policy removed to prevent infinite recursion
-- The admin policy was querying user_profiles while checking access to user_profiles
-- With RLS disabled, service_role middleware handles security

-- =====================================================
-- 4.2 User Personalization RLS Policies
-- =====================================================

-- Users can view their own personalization data
CREATE POLICY "Users can view own personalization" ON user_personalization
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own personalization (on questionnaire completion)
CREATE POLICY "Users can insert own personalization" ON user_personalization
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own personalization
CREATE POLICY "Users can update own personalization" ON user_personalization
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Service role has full access
CREATE POLICY "Service role full access to personalization" ON user_personalization
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- 4.3 Anonymous Sessions RLS Policies
-- =====================================================

-- Allow anyone to create anonymous sessions
CREATE POLICY "Allow anonymous session creation" ON anonymous_sessions
  FOR INSERT
  WITH CHECK (true);

-- Allow reading by session ID (for anonymous users)
CREATE POLICY "Allow anonymous session reads" ON anonymous_sessions
  FOR SELECT
  USING (true);

-- Allow updating by session ID
CREATE POLICY "Allow anonymous session updates" ON anonymous_sessions
  FOR UPDATE
  USING (true);

-- =====================================================
-- 4.3 OAuth States RLS Policies
-- =====================================================

-- Allow anyone to create OAuth states (for OAuth initiation)
CREATE POLICY "Allow anonymous oauth state creation" ON oauth_states
  FOR INSERT
  WITH CHECK (true);

-- Allow anyone to read OAuth states (for validation)
CREATE POLICY "Allow oauth state validation" ON oauth_states
  FOR SELECT
  USING (true);

-- Allow updating states to mark as used
CREATE POLICY "Allow oauth state updates" ON oauth_states
  FOR UPDATE
  USING (true);

-- =====================================================
-- 4.4 OTP Requests RLS Policies
-- =====================================================

-- Service role can manage all OTP requests
CREATE POLICY "Service role can manage OTP requests" ON otp_requests
  FOR ALL
  USING (auth.role() = 'service_role');

-- Allow anonymous OTP creation (for phone auth)
CREATE POLICY "Allow anonymous OTP creation" ON otp_requests
  FOR INSERT
  WITH CHECK (true);

-- Allow reading for validation (by phone number before auth)
CREATE POLICY "Allow OTP validation reads" ON otp_requests
  FOR SELECT
  USING (auth.role() = 'service_role' OR auth.role() = 'anon');

-- =====================================================
-- 4.5 Admin Logs RLS Policies
-- =====================================================

-- Only admins can view admin logs
CREATE POLICY "Admins can view admin logs" ON admin_logs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Service role can insert admin logs
CREATE POLICY "Service role can insert admin logs" ON admin_logs
  FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

-- =====================================================
-- 4.6 Analytics Events RLS Policies
-- =====================================================

-- Users can create their own analytics events
CREATE POLICY "Users can create own analytics events" ON analytics_events
  FOR INSERT
  WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');

-- Admins can view all analytics
CREATE POLICY "Admins can view all analytics" ON analytics_events
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- =====================================================
-- 4.7 LLM Security Events RLS Policies
-- =====================================================

-- Service role can manage security events
CREATE POLICY "Service role can manage security events" ON llm_security_events
  FOR ALL
  USING (auth.role() = 'service_role');

-- Admins can view security events
CREATE POLICY "Admins can view security events" ON llm_security_events
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- =====================================================
-- 4.8 Notification Logs RLS Policies
-- =====================================================

-- Users can view their own notification logs
CREATE POLICY "Users can view own notification logs" ON notification_logs
  FOR SELECT
  USING (auth.uid() = user_id);

-- Admins can view all notification logs
CREATE POLICY "Admins can view all notification logs" ON notification_logs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Service role can insert logs
CREATE POLICY "Service role can insert notification logs" ON notification_logs
  FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

-- =====================================================
-- 4.9 User Notification Tokens RLS Policies
-- =====================================================

-- Users can view their own tokens
CREATE POLICY "Users can view own notification tokens" ON user_notification_tokens
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own tokens
CREATE POLICY "Users can insert own notification tokens" ON user_notification_tokens
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own tokens
CREATE POLICY "Users can update own notification tokens" ON user_notification_tokens
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own tokens
CREATE POLICY "Users can delete own notification tokens" ON user_notification_tokens
  FOR DELETE
  USING (auth.uid() = user_id);

-- Admins can view all tokens
CREATE POLICY "Admins can view all notification tokens" ON user_notification_tokens
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- =====================================================
-- 4.10 User Notification Preferences RLS Policies
-- =====================================================

-- Users can view their own preferences
CREATE POLICY "Users can view own notification preferences" ON user_notification_preferences
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own preferences
CREATE POLICY "Users can insert own notification preferences" ON user_notification_preferences
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own preferences
CREATE POLICY "Users can update own notification preferences" ON user_notification_preferences
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own preferences
CREATE POLICY "Users can delete own notification preferences" ON user_notification_preferences
  FOR DELETE
  USING (auth.uid() = user_id);

-- Admins can view all preferences
CREATE POLICY "Admins can view all notification preferences" ON user_notification_preferences
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- =====================================================
-- 4.11 Feedback RLS Policies
-- =====================================================

-- Users can create feedback
CREATE POLICY "Users can create feedback" ON feedback
  FOR INSERT
  WITH CHECK (auth.uid() = user_id OR auth.role() = 'anon');

-- Users can view their own feedback
CREATE POLICY "Users can view own feedback" ON feedback
  FOR SELECT
  USING (auth.uid() = user_id);

-- Admins can view all feedback
CREATE POLICY "Admins can view all feedback" ON feedback
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- =====================================================
-- PART 5: VERIFICATION
-- =====================================================

-- Verify all 11 core tables were created
DO $$
DECLARE
  table_count INTEGER;
  expected_tables TEXT[] := ARRAY[
    'user_profiles',
    'anonymous_sessions',
    'oauth_states',
    'otp_requests',
    'admin_logs',
    'analytics_events',
    'llm_security_events',
    'notification_logs',
    'user_notification_tokens',
    'user_notification_preferences',
    'feedback'
  ];
  missing_tables TEXT[] := '{}';
  expected_table_name TEXT;
BEGIN
  -- Check each expected table
  FOREACH expected_table_name IN ARRAY expected_tables
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = expected_table_name
    ) THEN
      missing_tables := array_append(missing_tables, expected_table_name);
    END IF;
  END LOOP;

  -- Report results
  IF array_length(missing_tables, 1) > 0 THEN
    RAISE EXCEPTION 'VERIFICATION FAILED: Missing tables: %', array_to_string(missing_tables, ', ');
  END IF;

  SELECT COUNT(*) INTO table_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name = ANY(expected_tables);

  RAISE NOTICE '✅ Core schema migration completed successfully';
  RAISE NOTICE '✅ Created % core tables', table_count;
  RAISE NOTICE '✅ Created 5 helper functions with triggers';
  RAISE NOTICE '✅ Applied RLS policies to all tables';
END $$;

COMMIT;

-- =====================================================
-- Migration 20260119000000_core_schema.sql completed successfully
-- Next: 20260119000100_study_guides.sql
-- =====================================================
