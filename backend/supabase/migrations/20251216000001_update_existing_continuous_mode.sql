-- ============================================================================
-- Migration: Update Existing Users Continuous Mode to TRUE
-- Version: 1.0
-- Date: 2025-12-16
--
-- Description: Updates all existing voice_preferences records to have
--              continuous_mode = TRUE. This ensures all users (new and existing)
--              have continuous conversation mode enabled by default.
-- ============================================================================

BEGIN;

-- Update all existing preferences to enable continuous mode
UPDATE voice_preferences
SET continuous_mode = TRUE,
    updated_at = NOW()
WHERE continuous_mode = FALSE;

-- Log the number of affected rows (visible in migration output)
DO $$
DECLARE
  affected_count INTEGER;
BEGIN
  GET DIAGNOSTICS affected_count = ROW_COUNT;
  RAISE NOTICE 'Updated % voice_preferences records to continuous_mode = TRUE', affected_count;
END $$;

COMMIT;
