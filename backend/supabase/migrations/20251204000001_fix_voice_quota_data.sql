-- ============================================================================
-- Migration: Fix Voice Quota Data
-- Version: 1.0
-- Date: 2025-12-04
-- Description: Fixes inflated daily_quota_used values caused by the bug where
--              increment_voice_usage was called on every message instead of
--              only when starting a conversation.
--              
--              The daily_quota_used should equal conversations_started, not
--              total messages sent.
-- ============================================================================

BEGIN;

-- Fix all voice_usage_tracking records where daily_quota_used was inflated
-- by being incremented on every message instead of per conversation
UPDATE voice_usage_tracking 
SET daily_quota_used = conversations_started,
    updated_at = NOW()
WHERE daily_quota_used > conversations_started;

-- Log the fix
DO $$
DECLARE
  affected_rows INTEGER;
BEGIN
  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  RAISE NOTICE 'Fixed % voice_usage_tracking records with inflated quota counts', affected_rows;
END $$;

COMMIT;
