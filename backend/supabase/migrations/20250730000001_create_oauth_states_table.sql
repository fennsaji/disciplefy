-- OAuth States Table Migration
-- 
-- This table supports custom OAuth state management for enhanced CSRF protection.
-- Note: Supabase handles OAuth state validation internally by default.
-- This table is optional and only needed for custom state management implementations.

-- Create oauth_states table
CREATE TABLE oauth_states (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  state VARCHAR(128) NOT NULL UNIQUE,
  user_session_id VARCHAR(255),
  ip_address INET,
  user_agent TEXT,
  provider VARCHAR(20) DEFAULT 'google',
  used BOOLEAN DEFAULT false,
  used_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '15 minutes')
);

-- Create indexes for performance
CREATE INDEX idx_oauth_states_state ON oauth_states(state);
CREATE INDEX idx_oauth_states_expires_at ON oauth_states(expires_at);
CREATE INDEX idx_oauth_states_used ON oauth_states(used);

-- Add RLS policies
ALTER TABLE oauth_states ENABLE ROW LEVEL SECURITY;

-- Allow anonymous users to insert states (for OAuth initiation)  
CREATE POLICY "Allow anonymous oauth state creation" ON oauth_states
  FOR INSERT 
  WITH CHECK (true);

-- Allow anyone to read their own states (for validation)
CREATE POLICY "Allow oauth state validation" ON oauth_states
  FOR SELECT 
  USING (true);

-- Allow updating states to mark as used
CREATE POLICY "Allow oauth state updates" ON oauth_states
  FOR UPDATE 
  USING (true);

-- Function to clean up expired OAuth states
CREATE OR REPLACE FUNCTION cleanup_expired_oauth_states()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM oauth_states 
  WHERE expires_at < NOW() 
     OR (used = true AND used_at < NOW() - INTERVAL '1 hour');
END;
$$;

-- Comment explaining the table purpose
COMMENT ON TABLE oauth_states IS 'Optional table for custom OAuth state management with enhanced CSRF protection. Not required for basic Supabase OAuth flows.';
COMMENT ON COLUMN oauth_states.state IS 'Random state parameter for CSRF protection';
COMMENT ON COLUMN oauth_states.used IS 'Whether this state has been consumed';
COMMENT ON COLUMN oauth_states.expires_at IS 'State expiration time (15 minutes from creation)';