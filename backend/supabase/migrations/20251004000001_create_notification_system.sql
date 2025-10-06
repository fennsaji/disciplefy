-- ============================================================================
-- Migration: Create Notification System
-- Version: 1.0
-- Date: 2025-10-04
-- Description: Creates tables and policies for push notification service
--
-- This migration creates:
-- 1. user_notification_preferences - Stores FCM tokens and user preferences
-- 2. notification_logs - Tracks sent notifications for analytics
-- 3. RLS policies for both tables
-- 4. Indexes for efficient querying
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. USER NOTIFICATION PREFERENCES TABLE
-- ============================================================================

-- Store FCM device tokens and notification preferences
CREATE TABLE user_notification_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  fcm_token TEXT NOT NULL,
  platform VARCHAR(20) CHECK (platform IN ('ios', 'android', 'web')),

  -- Notification toggles
  daily_verse_enabled BOOLEAN DEFAULT true,
  recommended_topic_enabled BOOLEAN DEFAULT true,

  -- Timezone (offset in minutes from UTC)
  -- Examples: +330 for IST (UTC+5:30), -300 for EST (UTC-5:00)
  timezone_offset_minutes INTEGER DEFAULT 0,

  -- Metadata
  token_updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for efficient querying
CREATE INDEX idx_notification_prefs_user_id
  ON user_notification_preferences(user_id);

CREATE INDEX idx_notification_prefs_fcm_token
  ON user_notification_preferences(fcm_token);

CREATE INDEX idx_notification_prefs_daily_verse
  ON user_notification_preferences(daily_verse_enabled)
  WHERE daily_verse_enabled = true;

CREATE INDEX idx_notification_prefs_recommended
  ON user_notification_preferences(recommended_topic_enabled)
  WHERE recommended_topic_enabled = true;

CREATE INDEX idx_notification_prefs_timezone
  ON user_notification_preferences(timezone_offset_minutes);

-- Comments for documentation
COMMENT ON TABLE user_notification_preferences IS
  'Stores FCM tokens and notification preferences for each user';

COMMENT ON COLUMN user_notification_preferences.timezone_offset_minutes IS
  'Timezone offset in minutes from UTC (e.g., +330 for IST, -300 for EST)';

COMMENT ON COLUMN user_notification_preferences.fcm_token IS
  'Firebase Cloud Messaging device token for push notifications';

COMMENT ON COLUMN user_notification_preferences.platform IS
  'Platform the FCM token was generated from: ios, android, or web';

-- ============================================================================
-- 2. NOTIFICATION LOGS TABLE
-- ============================================================================

-- Track sent notifications for analytics and debugging
CREATE TABLE notification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_type VARCHAR(50) NOT NULL
    CHECK (notification_type IN ('daily_verse', 'recommended_topic')),

  -- Notification content
  title TEXT NOT NULL,
  body TEXT NOT NULL,

  -- Metadata
  topic_id UUID REFERENCES recommended_topics(id) ON DELETE SET NULL,
  verse_reference TEXT,
  language VARCHAR(5),

  -- Delivery tracking
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  delivery_status VARCHAR(20) DEFAULT 'sent'
    CHECK (delivery_status IN ('sent', 'delivered', 'failed', 'clicked')),
  fcm_message_id TEXT,
  error_message TEXT,

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for analytics queries
CREATE INDEX idx_notification_logs_user_id
  ON notification_logs(user_id);

CREATE INDEX idx_notification_logs_type
  ON notification_logs(notification_type);

CREATE INDEX idx_notification_logs_sent_at
  ON notification_logs(sent_at DESC);

CREATE INDEX idx_notification_logs_status
  ON notification_logs(delivery_status);

-- Composite index for user notification history (CRITICAL for performance)
-- This index significantly speeds up queries like "get user's recent notifications"
-- which filter by user_id and order by sent_at
CREATE INDEX idx_notification_logs_user_sent
  ON notification_logs(user_id, sent_at DESC);

CREATE INDEX idx_notification_logs_topic_id
  ON notification_logs(topic_id)
  WHERE topic_id IS NOT NULL;

-- Comments for documentation
COMMENT ON TABLE notification_logs IS
  'Tracks all sent notifications for analytics and debugging';

COMMENT ON COLUMN notification_logs.delivery_status IS
  'sent: notification sent to FCM, delivered: confirmed delivery, failed: delivery failed, clicked: user opened notification';

COMMENT ON COLUMN notification_logs.notification_type IS
  'Type of notification: daily_verse (6 AM) or recommended_topic (8 AM)';

COMMENT ON COLUMN notification_logs.fcm_message_id IS
  'Unique message ID returned by Firebase Cloud Messaging';

-- ============================================================================
-- 3. ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Enable RLS
ALTER TABLE user_notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- user_notification_preferences RLS Policies
-- ----------------------------------------------------------------------------

-- Users can view their own preferences
CREATE POLICY "Users can view own notification preferences"
  ON user_notification_preferences
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own preferences
CREATE POLICY "Users can insert own notification preferences"
  ON user_notification_preferences
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own preferences
CREATE POLICY "Users can update own notification preferences"
  ON user_notification_preferences
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own preferences
CREATE POLICY "Users can delete own notification preferences"
  ON user_notification_preferences
  FOR DELETE
  USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- notification_logs RLS Policies
-- ----------------------------------------------------------------------------

-- Users can view their own notification logs
CREATE POLICY "Users can view own notification logs"
  ON notification_logs
  FOR SELECT
  USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- Admin Policies (for monitoring and analytics)
-- ----------------------------------------------------------------------------

-- Admins can view all notification preferences
CREATE POLICY "Admins can view all notification preferences"
  ON user_notification_preferences
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Admins can view all notification logs
CREATE POLICY "Admins can view all notification logs"
  ON notification_logs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- ============================================================================
-- 4. HELPER FUNCTIONS (Optional, for future use)
-- ============================================================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_notification_prefs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at on row update
CREATE TRIGGER update_notification_prefs_timestamp
  BEFORE UPDATE ON user_notification_preferences
  FOR EACH ROW
  EXECUTE FUNCTION update_notification_prefs_updated_at();

-- ============================================================================
-- 5. VALIDATION AND VERIFICATION
-- ============================================================================

-- Verify tables were created
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_notification_preferences') THEN
    RAISE EXCEPTION 'Table user_notification_preferences was not created';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notification_logs') THEN
    RAISE EXCEPTION 'Table notification_logs was not created';
  END IF;

  RAISE NOTICE 'Migration completed successfully: Notification system tables created';
END $$;

COMMIT;
