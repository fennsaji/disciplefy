-- Migration: Create unified rate_limit_usage table
-- Date: 2025-07-11
-- Purpose: Create a dedicated table for rate limiting that abstracts from business logic tables

-- Begin transaction
BEGIN;

-- Step 1: Create the rate_limit_usage table
CREATE TABLE rate_limit_usage (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  identifier TEXT NOT NULL,
  user_type TEXT NOT NULL CHECK (user_type IN ('anonymous', 'authenticated')),
  count INTEGER NOT NULL DEFAULT 0,
  window_start TIMESTAMP WITH TIME ZONE NOT NULL,
  last_activity TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Step 2: Create indexes for optimal query performance
CREATE INDEX idx_rate_limit_usage_lookup 
ON rate_limit_usage(identifier, user_type, window_start);

CREATE INDEX idx_rate_limit_usage_cleanup 
ON rate_limit_usage(window_start);

CREATE INDEX idx_rate_limit_usage_last_activity 
ON rate_limit_usage(last_activity);

-- Step 3: Create unique constraint to prevent duplicate entries
CREATE UNIQUE INDEX idx_rate_limit_usage_unique 
ON rate_limit_usage(identifier, user_type, window_start);

-- Step 4: Add comments for documentation
COMMENT ON TABLE rate_limit_usage IS 'Unified rate limiting usage tracking for both anonymous and authenticated users';
COMMENT ON COLUMN rate_limit_usage.identifier IS 'User ID for authenticated users or session ID for anonymous users';
COMMENT ON COLUMN rate_limit_usage.user_type IS 'Type of user: anonymous or authenticated';
COMMENT ON COLUMN rate_limit_usage.count IS 'Number of requests made in this time window';
COMMENT ON COLUMN rate_limit_usage.window_start IS 'Start time of the rate limit window';
COMMENT ON COLUMN rate_limit_usage.last_activity IS 'Last time this record was updated';

-- Step 5: Enable Row Level Security (RLS)
ALTER TABLE rate_limit_usage ENABLE ROW LEVEL SECURITY;

-- Step 6: Create RLS policies for rate limiting access
-- Allow Edge Functions to read/write rate limit data
CREATE POLICY "Edge Functions can manage rate limit usage" ON rate_limit_usage
  FOR ALL USING (
    -- Allow all operations for service role (Edge Functions)
    true
  );

-- Step 7: Create a function to clean up old rate limit records
CREATE OR REPLACE FUNCTION cleanup_old_rate_limit_records()
RETURNS void AS $$
BEGIN
  -- Delete records older than 24 hours
  DELETE FROM rate_limit_usage 
  WHERE window_start < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Create a function to get or create rate limit usage record
CREATE OR REPLACE FUNCTION get_or_create_rate_limit_usage(
  p_identifier TEXT,
  p_user_type TEXT,
  p_window_start TIMESTAMP WITH TIME ZONE
)
RETURNS TABLE(
  id UUID,
  identifier TEXT,
  user_type TEXT,
  count INTEGER,
  window_start TIMESTAMP WITH TIME ZONE,
  last_activity TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  -- Try to get existing record
  RETURN QUERY
  SELECT 
    rlu.id,
    rlu.identifier,
    rlu.user_type,
    rlu.count,
    rlu.window_start,
    rlu.last_activity
  FROM rate_limit_usage rlu
  WHERE rlu.identifier = p_identifier
    AND rlu.user_type = p_user_type
    AND rlu.window_start = p_window_start;
  
  -- If no record found, create one
  IF NOT FOUND THEN
    INSERT INTO rate_limit_usage (identifier, user_type, count, window_start)
    VALUES (p_identifier, p_user_type, 0, p_window_start)
    ON CONFLICT (identifier, user_type, window_start) 
    DO UPDATE SET 
      last_activity = NOW(),
      updated_at = NOW()
    RETURNING 
      rate_limit_usage.id,
      rate_limit_usage.identifier,
      rate_limit_usage.user_type,
      rate_limit_usage.count,
      rate_limit_usage.window_start,
      rate_limit_usage.last_activity;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 9: Create a function to increment usage count
CREATE OR REPLACE FUNCTION increment_rate_limit_usage(
  p_identifier TEXT,
  p_user_type TEXT,
  p_window_start TIMESTAMP WITH TIME ZONE
)
RETURNS INTEGER AS $$
DECLARE
  new_count INTEGER;
BEGIN
  -- Insert or update the usage record
  INSERT INTO rate_limit_usage (identifier, user_type, count, window_start)
  VALUES (p_identifier, p_user_type, 1, p_window_start)
  ON CONFLICT (identifier, user_type, window_start)
  DO UPDATE SET 
    count = rate_limit_usage.count + 1,
    last_activity = NOW(),
    updated_at = NOW()
  RETURNING count INTO new_count;
  
  RETURN new_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 10: Create a scheduled job to clean up old records (optional)
-- Note: This would typically be set up as a cron job or periodic task
-- For now, we'll just create the function that can be called periodically

-- Commit transaction
COMMIT;