-- ============================================================================
-- Migration: Split Notification Tables for Multi-Device Support
-- Version: 2.0
-- Date: 2025-10-07
-- Description: Splits user_notification_preferences into two tables to support
--              multiple FCM tokens per user (one per device)
--
-- This migration:
-- 1. Creates user_notification_tokens table for FCM tokens
-- 2. Migrates existing tokens from user_notification_preferences
-- 3. Removes fcm_token and platform columns from preferences table
-- 4. Updates RLS policies for the new table
-- 5. Creates indexes for efficient querying
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. CREATE NEW TOKENS TABLE
-- ============================================================================

-- Store multiple FCM tokens per user (one per device)
CREATE TABLE user_notification_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform VARCHAR(20) NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  
  -- Metadata
  token_updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure unique combination of user_id and fcm_token (same token can't be registered twice)
  CONSTRAINT unique_user_token UNIQUE (user_id, fcm_token)
);

-- Indexes for efficient querying
CREATE INDEX idx_notification_tokens_user_id
  ON user_notification_tokens(user_id);

CREATE INDEX idx_notification_tokens_fcm_token
  ON user_notification_tokens(fcm_token);

CREATE INDEX idx_notification_tokens_platform
  ON user_notification_tokens(platform);

-- Comments for documentation
COMMENT ON TABLE user_notification_tokens IS
  'Stores FCM tokens for each user device. Users can have multiple tokens (one per device)';

COMMENT ON COLUMN user_notification_tokens.fcm_token IS
  'Firebase Cloud Messaging device token for push notifications';

COMMENT ON COLUMN user_notification_tokens.platform IS
  'Platform the FCM token was generated from: ios, android, or web';

-- ============================================================================
-- 2. MIGRATE EXISTING DATA
-- ============================================================================

-- Copy existing tokens from user_notification_preferences to user_notification_tokens
INSERT INTO user_notification_tokens (user_id, fcm_token, platform, token_updated_at, created_at)
SELECT 
  user_id,
  fcm_token,
  platform,
  token_updated_at,
  created_at
FROM user_notification_preferences
WHERE fcm_token IS NOT NULL AND fcm_token != '';

-- Log migration results
DO $$
DECLARE
  migrated_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO migrated_count FROM user_notification_tokens;
  RAISE NOTICE 'Migrated % tokens to user_notification_tokens table', migrated_count;
END $$;

-- ============================================================================
-- 3. UPDATE PREFERENCES TABLE SCHEMA
-- ============================================================================

-- Remove FCM token and platform columns (now in separate table)
ALTER TABLE user_notification_preferences
  DROP COLUMN IF EXISTS fcm_token,
  DROP COLUMN IF EXISTS platform,
  DROP COLUMN IF EXISTS token_updated_at;

-- Drop old indexes that referenced removed columns
DROP INDEX IF EXISTS idx_notification_prefs_fcm_token;

-- Update table comment
COMMENT ON TABLE user_notification_preferences IS
  'Stores notification preferences and timezone for each user. FCM tokens are stored in user_notification_tokens table';

-- ============================================================================
-- 4. ROW LEVEL SECURITY POLICIES FOR TOKENS TABLE
-- ============================================================================

-- Enable RLS
ALTER TABLE user_notification_tokens ENABLE ROW LEVEL SECURITY;

-- Users can view their own tokens
CREATE POLICY "Users can view own notification tokens"
  ON user_notification_tokens
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own tokens
CREATE POLICY "Users can insert own notification tokens"
  ON user_notification_tokens
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own tokens
CREATE POLICY "Users can update own notification tokens"
  ON user_notification_tokens
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own tokens
CREATE POLICY "Users can delete own notification tokens"
  ON user_notification_tokens
  FOR DELETE
  USING (auth.uid() = user_id);

-- Admins can view all tokens
CREATE POLICY "Admins can view all notification tokens"
  ON user_notification_tokens
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- ============================================================================
-- 5. HELPER FUNCTIONS
-- ============================================================================

-- Function to automatically update token_updated_at timestamp
CREATE OR REPLACE FUNCTION update_notification_token_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.token_updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update token_updated_at on row update
CREATE TRIGGER update_notification_token_timestamp
  BEFORE UPDATE ON user_notification_tokens
  FOR EACH ROW
  EXECUTE FUNCTION update_notification_token_updated_at();

-- ============================================================================
-- 6. VALIDATION AND VERIFICATION
-- ============================================================================

-- Verify new table was created
DO $$
DECLARE
  token_count INTEGER;
  pref_has_fcm_token BOOLEAN;
BEGIN
  -- Check table exists
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_notification_tokens') THEN
    RAISE EXCEPTION 'Table user_notification_tokens was not created';
  END IF;

  -- Check fcm_token column was removed from preferences
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'user_notification_preferences' 
    AND column_name = 'fcm_token'
  ) INTO pref_has_fcm_token;

  IF pref_has_fcm_token THEN
    RAISE EXCEPTION 'Column fcm_token still exists in user_notification_preferences';
  END IF;

  -- Count migrated tokens
  SELECT COUNT(*) INTO token_count FROM user_notification_tokens;

  RAISE NOTICE 'Migration completed successfully:';
  RAISE NOTICE '  - user_notification_tokens table created';
  RAISE NOTICE '  - % tokens migrated', token_count;
  RAISE NOTICE '  - fcm_token and platform columns removed from preferences';
  RAISE NOTICE '  - RLS policies created';
END $$;

COMMIT;
