-- Migration: Update Daily Verse Cache Cleanup Retention
-- Created: 2025-10-15
-- Purpose: Update cleanup function retention from 30 days to 90 days to align with 60-day cache expiration

-- Update the cleanup function to retain cache entries for 90 days (30-day grace period beyond 60-day expiration)
CREATE OR REPLACE FUNCTION cleanup_expired_daily_verses()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM daily_verses_cache
    WHERE expires_at < timezone('utc'::text, now())
    OR (created_at < timezone('utc'::text, now()) - INTERVAL '90 days');

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Update function comment to reflect new retention period
COMMENT ON FUNCTION cleanup_expired_daily_verses() IS 'Removes expired cache entries and entries older than 90 days to keep table size manageable';
