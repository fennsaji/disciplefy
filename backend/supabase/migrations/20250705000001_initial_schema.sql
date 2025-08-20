-- Initial Schema Migration for Disciplefy Bible Study App
-- Based on Data Model.md and Technical Architecture Document
-- Version: 1.0.0

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Note: JWT secret is handled by Supabase configuration, not database settings

-- User profile extensions (extends auth.users)
-- Note: In Supabase, modifying auth.users requires special handling
-- These fields will be managed via user metadata in auth.users.user_metadata
-- Or via a separate user_profiles table with proper RLS policies

-- User profiles table (extends auth.users functionality)
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  language_preference VARCHAR(5) DEFAULT 'en',
  theme_preference VARCHAR(20) DEFAULT 'light',
  is_admin BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Study Guides table
CREATE TABLE study_guides (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  input_type VARCHAR(20) NOT NULL CHECK (input_type IN ('scripture', 'topic')),
  input_value VARCHAR(255) NOT NULL,
  summary TEXT NOT NULL,
  context TEXT NOT NULL,
  related_verses TEXT[] NOT NULL,
  reflection_questions TEXT[] NOT NULL,
  prayer_points TEXT[] NOT NULL,
  language VARCHAR(5) DEFAULT 'en',
  is_saved BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Recommended Guide Sessions table
CREATE TABLE recommended_guide_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  topic VARCHAR(100) NOT NULL,
  current_step INTEGER DEFAULT 1 CHECK (current_step >= 1 AND current_step <= 4),
  step_1_context TEXT,
  step_2_scholar_guide TEXT,
  step_3_group_discussion TEXT,
  step_4_application TEXT,
  step_1_completed_at TIMESTAMP WITH TIME ZONE,
  step_2_completed_at TIMESTAMP WITH TIME ZONE,
  step_3_completed_at TIMESTAMP WITH TIME ZONE,
  step_4_completed_at TIMESTAMP WITH TIME ZONE,
  completion_status BOOLEAN DEFAULT false,
  language VARCHAR(5) DEFAULT 'en',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Feedback table
CREATE TABLE feedback (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  study_guide_id UUID REFERENCES study_guides(id) ON DELETE CASCADE,
  recommended_guide_session_id UUID REFERENCES recommended_guide_sessions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  was_helpful BOOLEAN NOT NULL,
  message TEXT,
  category VARCHAR(50) DEFAULT 'general',
  sentiment_score FLOAT CHECK (sentiment_score >= -1.0 AND sentiment_score <= 1.0),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraint: Must reference either study_guide or recommended_guide_session
  CONSTRAINT feedback_reference_check 
    CHECK ((study_guide_id IS NOT NULL AND recommended_guide_session_id IS NULL) OR 
           (study_guide_id IS NULL AND recommended_guide_session_id IS NOT NULL))
);

-- Anonymous sessions table (from Anonymous User Data Lifecycle)
-- ⚠️ WARNING: This table was removed in migration 20250818000001_remove_unused_tables.sql
-- The table definition is commented out to preserve migration history
/*
CREATE TABLE anonymous_sessions (
  session_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_fingerprint_hash VARCHAR(64),
  ip_address_hash VARCHAR(64),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '24 hours'),
  study_guides_count INTEGER DEFAULT 0,
  recommended_guide_sessions_count INTEGER DEFAULT 0,
  is_migrated BOOLEAN DEFAULT false
);
*/

-- Anonymous study guides
-- ⚠️ NOTE: This table structure needs updating due to anonymous_sessions removal
-- The session_id reference was changed to UUID (without FK) in later migrations
CREATE TABLE anonymous_study_guides (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID, -- Reference to anonymous_sessions removed, now standalone UUID
  input_type VARCHAR(20) NOT NULL CHECK (input_type IN ('scripture', 'topic')),
  input_value_hash VARCHAR(64),
  summary TEXT NOT NULL,
  context TEXT NOT NULL,
  related_verses TEXT[] NOT NULL,
  reflection_questions TEXT[] NOT NULL,
  prayer_points TEXT[] NOT NULL,
  language VARCHAR(5) DEFAULT 'en',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '7 days')
);

-- Donations table
CREATE TABLE donations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  razorpay_payment_id VARCHAR(255) UNIQUE,
  razorpay_order_id VARCHAR(255) NOT NULL,
  amount INTEGER NOT NULL CHECK (amount > 0),
  currency VARCHAR(3) DEFAULT 'INR',
  status VARCHAR(20) DEFAULT 'created',
  receipt_email VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE
);

-- LLM Security Events table (from LLM Input Validation Specification)
CREATE TABLE llm_security_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id VARCHAR(255),
  ip_address INET,
  event_type VARCHAR(50) NOT NULL,
  input_text TEXT,
  risk_score FLOAT CHECK (risk_score >= 0.0 AND risk_score <= 1.0),
  action_taken VARCHAR(50),
  detection_details JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Admin logs table
CREATE TABLE admin_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  admin_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  action VARCHAR(100) NOT NULL,
  target_table VARCHAR(50),
  target_id UUID,
  ip_address INET,
  user_agent TEXT,
  details JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Analytics events table
CREATE TABLE analytics_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type VARCHAR(50) NOT NULL,
  event_data JSONB,
  session_id VARCHAR(255),
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
-- User profiles indexes
CREATE INDEX idx_user_profiles_language ON user_profiles(language_preference);
CREATE INDEX idx_user_profiles_admin ON user_profiles(is_admin);

-- Study guides indexes
CREATE INDEX idx_study_guides_user_id ON study_guides(user_id);
CREATE INDEX idx_study_guides_created_at ON study_guides(created_at DESC);
CREATE INDEX idx_study_guides_input_type ON study_guides(input_type);
CREATE INDEX idx_study_guides_language ON study_guides(language);

-- Recommended Guide sessions indexes
CREATE INDEX idx_recommended_guide_sessions_user_id ON recommended_guide_sessions(user_id);
CREATE INDEX idx_recommended_guide_sessions_topic ON recommended_guide_sessions(topic);
CREATE INDEX idx_recommended_guide_sessions_completion ON recommended_guide_sessions(completion_status);

-- Feedback indexes
CREATE INDEX idx_feedback_study_guide_id ON feedback(study_guide_id);
CREATE INDEX idx_feedback_recommended_guide_session_id ON feedback(recommended_guide_session_id);
CREATE INDEX idx_feedback_user_id ON feedback(user_id);
CREATE INDEX idx_feedback_created_at ON feedback(created_at DESC);

-- Anonymous sessions indexes (removed - table deleted in migration 20250818000001)
-- CREATE INDEX idx_anonymous_sessions_expires_at ON anonymous_sessions(expires_at);
-- CREATE INDEX idx_anonymous_sessions_device_hash ON anonymous_sessions(device_fingerprint_hash);

-- Anonymous study guides indexes
CREATE INDEX idx_anonymous_guides_session ON anonymous_study_guides(session_id);
CREATE INDEX idx_anonymous_guides_expiry ON anonymous_study_guides(expires_at);

-- Donations indexes
CREATE INDEX idx_donations_user_id ON donations(user_id);
CREATE INDEX idx_donations_status ON donations(status);
CREATE INDEX idx_donations_created_at ON donations(created_at DESC);

-- Security events indexes
CREATE INDEX idx_security_events_type_time ON llm_security_events(event_type, created_at DESC);
CREATE INDEX idx_security_events_user ON llm_security_events(user_id, created_at DESC);
CREATE INDEX idx_security_events_ip ON llm_security_events(ip_address, created_at DESC);

-- Admin logs indexes
CREATE INDEX idx_admin_logs_admin_user_id ON admin_logs(admin_user_id);
CREATE INDEX idx_admin_logs_action ON admin_logs(action);
CREATE INDEX idx_admin_logs_created_at ON admin_logs(created_at DESC);

-- Analytics events indexes
CREATE INDEX idx_analytics_events_type ON analytics_events(event_type);
CREATE INDEX idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX idx_analytics_events_created_at ON analytics_events(created_at DESC);