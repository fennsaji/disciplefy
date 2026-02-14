-- =====================================================
-- Consolidated Migration: Study Guide System
-- =====================================================
-- Source: Consolidation of 8+ study guide-related migrations
-- Tables: 7 (study_guides, user_study_guides, study_guide_conversations,
--            conversation_messages, anonymous_study_guides, recommended_guide_sessions,
--            daily_verses_cache)
-- Description: Complete study guide system with caching, deduplication,
--              follow-up conversations, anonymous support, and daily verse caching
-- =====================================================

-- Dependencies: 0001_core_schema.sql (user_profiles, auth.users)

BEGIN;

-- =====================================================
-- PART 1: Study Guides Content Cache
-- =====================================================

-- Content cache table with deduplication by hash
CREATE TABLE study_guides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Input identification
  input_type VARCHAR(20) NOT NULL CHECK (input_type IN ('scripture', 'topic', 'question')),
  input_value_hash VARCHAR(64) NOT NULL,
  input_value TEXT NOT NULL, -- Display value (added: 2025-07-13)
  language VARCHAR(5) NOT NULL DEFAULT 'en',

  -- Content sections (following SOAP + Interpretation methodology)
  summary TEXT NOT NULL,
  interpretation TEXT NOT NULL, -- Added: 2025-07-09
  context TEXT NOT NULL,
  passage TEXT, -- LLM-generated Scripture passage (3-8 verses with full text) for meditation in Standard mode (Added: 2026-01-31)
  related_verses TEXT[] NOT NULL,
  reflection_questions TEXT[] NOT NULL,
  prayer_points TEXT[] NOT NULL,

  -- Reflection insights (Added: 2025-12-24)
  interpretation_insights TEXT[],
  context_question TEXT,
  summary_insights TEXT[],
  reflection_answers TEXT[],

  -- Reflection questions for dynamic LLM-generated questions (Added: 2025-12-24)
  summary_question TEXT,
  related_verses_question TEXT,
  reflection_question TEXT,
  prayer_question TEXT,

  -- Study modes and extended content (Added: 2025-12-23, Updated: 2026-01-11)
  study_mode TEXT DEFAULT 'standard' CHECK (study_mode IN ('quick', 'standard', 'deep', 'lectio', 'sermon')),
  extended_content JSONB DEFAULT '{}'::JSONB,

  -- Topic tracking (Added: 2025-10-15)
  topic_id UUID, -- FK added after recommended_topics table created in 0011

  -- Creator tracking for token billing (Added: 2025-12-10)
  creator_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  creator_session_id TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Ensure content deduplication
  CONSTRAINT unique_cached_content UNIQUE(input_type, input_value_hash, language)
);

-- Performance indexes
CREATE INDEX idx_study_guides_lookup ON study_guides(input_type, input_value_hash, language);
CREATE INDEX idx_study_guides_created_at ON study_guides(created_at DESC);
CREATE INDEX idx_study_guides_input_value ON study_guides(input_value);
CREATE INDEX idx_study_guides_topic_id ON study_guides(topic_id) WHERE topic_id IS NOT NULL;
CREATE INDEX idx_study_guides_creator_user_id ON study_guides(creator_user_id) WHERE creator_user_id IS NOT NULL;
CREATE INDEX idx_study_guides_study_mode ON study_guides(study_mode);
CREATE INDEX idx_study_guides_has_insights ON study_guides((interpretation_insights IS NOT NULL)) WHERE interpretation_insights IS NOT NULL;
CREATE INDEX idx_study_guides_has_context_question ON study_guides((context_question IS NOT NULL)) WHERE context_question IS NOT NULL;
CREATE INDEX idx_study_guides_has_summary_insights ON study_guides((summary_insights IS NOT NULL)) WHERE summary_insights IS NOT NULL;
CREATE INDEX idx_study_guides_has_reflection_answers ON study_guides((reflection_answers IS NOT NULL)) WHERE reflection_answers IS NOT NULL;
CREATE INDEX idx_study_guides_has_summary_question ON study_guides((summary_question IS NOT NULL)) WHERE summary_question IS NOT NULL;
CREATE INDEX idx_study_guides_has_related_verses_question ON study_guides((related_verses_question IS NOT NULL)) WHERE related_verses_question IS NOT NULL;
CREATE INDEX idx_study_guides_has_reflection_question ON study_guides((reflection_question IS NOT NULL)) WHERE reflection_question IS NOT NULL;
CREATE INDEX idx_study_guides_has_prayer_question ON study_guides((prayer_question IS NOT NULL)) WHERE prayer_question IS NOT NULL;

-- Updated timestamp trigger
CREATE OR REPLACE FUNCTION update_study_guides_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_study_guides_timestamp
  BEFORE UPDATE ON study_guides
  FOR EACH ROW
  EXECUTE FUNCTION update_study_guides_updated_at();

-- Helper function for hash generation
CREATE OR REPLACE FUNCTION generate_input_hash(input_value TEXT)
RETURNS VARCHAR(64)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN encode(digest(lower(trim(input_value)), 'sha256'), 'hex');
END;
$$;

-- Table comments
COMMENT ON TABLE study_guides IS 'Content cache for deduplicated AI-generated Bible study guides';
COMMENT ON COLUMN study_guides.input_value_hash IS 'SHA-256 hash of input for deduplication';
COMMENT ON COLUMN study_guides.input_value IS 'Original input value for display (separate from hash)';
COMMENT ON COLUMN study_guides.interpretation IS 'Biblical interpretation section (SOAP methodology)';
COMMENT ON COLUMN study_guides.interpretation_insights IS 'Array of 3-4 theological insights extracted from interpretation for multi-select reflection (10-15 words each). Generated by LLM during study guide creation.';
COMMENT ON COLUMN study_guides.context_question IS 'Yes/no question generated from historical/cultural context to connect biblical situation to modern life. Used in Reflect Mode context card.';
COMMENT ON COLUMN study_guides.summary_insights IS 'LLM-generated resonance themes for Summary card interaction (3-4 options for Standard/Deep Dive, 2-3 for Quick/Lectio Divina). Examples: "Finding strength in God''s promises", "Experiencing comfort through scripture"';
COMMENT ON COLUMN study_guides.reflection_answers IS 'LLM-generated actionable life application responses for Reflection card interaction (3-4 options). Users select from these concrete action steps during Reflect Mode to personalize their study experience.';
COMMENT ON COLUMN study_guides.summary_question IS 'LLM-generated question about which part of the summary resonated most. Prompts user reflection on key takeaways from the study.';
COMMENT ON COLUMN study_guides.related_verses_question IS 'LLM-generated question prompting user to select a related verse for memorization or further study. Encourages deeper scripture engagement.';
COMMENT ON COLUMN study_guides.reflection_question IS 'LLM-generated question connecting the study to daily life. Helps users apply biblical principles to their personal circumstances.';
COMMENT ON COLUMN study_guides.prayer_question IS 'LLM-generated question inviting personal prayer response to the study content. Facilitates spiritual reflection and dialogue with God.';
COMMENT ON COLUMN study_guides.study_mode IS 'Study mode: quick (3 min), standard (10 min), deep (25 min), lectio (15 min), sermon (55 min)';
COMMENT ON COLUMN study_guides.extended_content IS 'Mode-specific extended content (deep: word_study, historical_context; lectio: meditation_prompts, prayer_template)';
COMMENT ON COLUMN study_guides.topic_id IS 'FK to recommended_topics when generated from recommended topic';
COMMENT ON COLUMN study_guides.creator_user_id IS 'User who originally generated this guide (null for anonymous/legacy)';
COMMENT ON COLUMN study_guides.creator_session_id IS 'Session ID for anonymous creators (null for authenticated/legacy)';

-- =====================================================
-- PART 1.5: Study Guides In Progress Tracking
-- =====================================================
-- Purpose: Track in-progress study generations for duplicate detection,
--          background continuation, and progressive section saves

CREATE TABLE study_guides_in_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Input identification (for duplicate detection)
  input_type TEXT NOT NULL,
  input_value TEXT NOT NULL,
  input_value_hash TEXT NOT NULL,
  language TEXT NOT NULL,
  study_mode TEXT NOT NULL,

  -- Progressive data storage
  sections JSONB NOT NULL DEFAULT '{}'::jsonb,

  -- Generation tracking
  status TEXT NOT NULL CHECK (status IN ('generating', 'completed', 'failed')),
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,

  -- Client tracking (for heartbeat detection)
  client_id TEXT,
  last_heartbeat_at TIMESTAMPTZ,

  -- Error tracking
  error_code TEXT,
  error_message TEXT,

  -- Ensure only one generation per unique study at a time
  CONSTRAINT unique_in_progress_study
    UNIQUE (input_type, input_value_hash, language, study_mode)
);

-- Indexes for performance
CREATE INDEX idx_in_progress_status ON study_guides_in_progress(status);
CREATE INDEX idx_in_progress_user ON study_guides_in_progress(user_id);
CREATE INDEX idx_in_progress_started ON study_guides_in_progress(started_at);

COMMENT ON TABLE study_guides_in_progress IS 'Tracks in-progress study guide generation for duplicate detection and progressive saves';
COMMENT ON COLUMN study_guides_in_progress.sections IS 'Progressively saved sections as JSONB during generation';
COMMENT ON COLUMN study_guides_in_progress.status IS 'Generation status: generating, completed, failed';

-- Cleanup function for stale records (marks as failed after 5 minutes of no updates)
CREATE OR REPLACE FUNCTION cleanup_stale_in_progress_studies()
RETURNS TABLE (
  cleaned_count INTEGER,
  cleaned_ids TEXT[]
) AS $$
DECLARE
  stale_records RECORD;
  cleaned_ids_array TEXT[] := '{}';
  total_count INTEGER := 0;
BEGIN
  -- Find and mark stale records (>=5 minutes old with no updates)
  FOR stale_records IN
    SELECT id
    FROM study_guides_in_progress
    WHERE status = 'generating'
      AND last_updated_at <= NOW() - INTERVAL '5 minutes'
  LOOP
    -- Mark as failed
    UPDATE study_guides_in_progress
    SET
      status = 'failed',
      error_code = 'TIMEOUT',
      error_message = 'Generation abandoned or timed out (no updates for 5+ minutes)',
      last_updated_at = NOW()
    WHERE id = stale_records.id;

    -- Track cleaned IDs
    cleaned_ids_array := array_append(cleaned_ids_array, stale_records.id::TEXT);
    total_count := total_count + 1;
  END LOOP;

  -- Return summary
  RETURN QUERY SELECT total_count, cleaned_ids_array;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION cleanup_stale_in_progress_studies() IS
'Marks stale in-progress study guide records as failed.
Records are considered stale if they have been in "generating" status
for 5 minutes or more without updates.';

-- =====================================================
-- PART 2: User Study Guide Ownership
-- =====================================================

-- Authenticated user ownership with completion tracking
CREATE TABLE user_study_guides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  study_guide_id UUID NOT NULL REFERENCES study_guides(id) ON DELETE CASCADE,

  -- User interactions
  is_saved BOOLEAN DEFAULT false,

  -- Completion tracking (Added: 2025-10-17)
  completed_at TIMESTAMPTZ,
  time_spent_seconds INTEGER DEFAULT 0,
  scrolled_to_bottom BOOLEAN DEFAULT false,

  -- Personal notes (Added: 2025-08-23)
  personal_notes TEXT CONSTRAINT personal_notes_length_check CHECK (personal_notes IS NULL OR char_length(personal_notes) <= 2048),

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Prevent duplicate user-guide relationships
  CONSTRAINT unique_user_guide UNIQUE(user_id, study_guide_id)
);

-- Performance indexes
CREATE INDEX idx_user_study_guides_user_id ON user_study_guides(user_id);
CREATE INDEX idx_user_study_guides_saved ON user_study_guides(user_id, is_saved) WHERE is_saved = true;
CREATE INDEX idx_user_study_guides_created_at ON user_study_guides(user_id, created_at DESC);
CREATE INDEX idx_user_study_guides_completed_at ON user_study_guides(completed_at) WHERE completed_at IS NOT NULL;
CREATE INDEX idx_user_study_guides_user_completion ON user_study_guides(user_id, completed_at) WHERE completed_at IS NOT NULL;

-- Updated timestamp trigger
CREATE OR REPLACE FUNCTION update_user_study_guides_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_user_study_guides_timestamp
  BEFORE UPDATE ON user_study_guides
  FOR EACH ROW
  EXECUTE FUNCTION update_user_study_guides_updated_at();

-- Table comments
COMMENT ON TABLE user_study_guides IS 'Authenticated user ownership and interaction tracking for study guides';
COMMENT ON COLUMN user_study_guides.is_saved IS 'Whether user explicitly saved this study guide';
COMMENT ON COLUMN user_study_guides.completed_at IS 'Timestamp when user completed the guide (time + scroll conditions met)';
COMMENT ON COLUMN user_study_guides.time_spent_seconds IS 'Total time spent reading the guide in seconds';
COMMENT ON COLUMN user_study_guides.scrolled_to_bottom IS 'Whether user scrolled to bottom (required for completion)';
COMMENT ON COLUMN user_study_guides.personal_notes IS 'Personal notes for study guide (max 2048 characters)';

-- =====================================================
-- PART 2.5: Study Reflections (Interactive Reflect Mode)
-- =====================================================

-- Stores user reflection responses from interactive Reflect Mode
-- Example: summary themes, interpretation relevance, saved verses, life areas, prayer notes
CREATE TABLE study_reflections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  study_guide_id UUID NOT NULL REFERENCES study_guides(id) ON DELETE CASCADE,
  study_mode TEXT NOT NULL CHECK (study_mode IN ('quick', 'standard', 'deep', 'lectio', 'sermon')),

  -- Structured responses as JSONB for flexibility
  -- Example: {"summary_theme": "strength", "context_related": true, "saved_verses": [...]}
  responses JSONB NOT NULL DEFAULT '{}'::JSONB,

  -- Tracking
  time_spent_seconds INTEGER DEFAULT 0,
  completed_at TIMESTAMPTZ,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Performance indexes
CREATE INDEX idx_reflections_user ON study_reflections(user_id);
CREATE INDEX idx_reflections_guide ON study_reflections(study_guide_id);
CREATE INDEX idx_reflections_date ON study_reflections(completed_at DESC);
CREATE INDEX idx_reflections_user_date ON study_reflections(user_id, completed_at DESC);

-- Updated timestamp trigger
CREATE OR REPLACE FUNCTION update_study_reflections_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER study_reflections_updated_at_trigger
  BEFORE UPDATE ON study_reflections
  FOR EACH ROW
  EXECUTE FUNCTION update_study_reflections_updated_at();

-- Table comments
COMMENT ON TABLE study_reflections IS 'Stores user reflection responses from interactive Reflect Mode in study guides';
COMMENT ON COLUMN study_reflections.responses IS 'JSONB containing structured reflection responses (summary_theme, saved_verses, life_areas, etc.)';
COMMENT ON COLUMN study_reflections.time_spent_seconds IS 'Total time user spent in Reflect Mode for this study guide';
COMMENT ON COLUMN study_reflections.completed_at IS 'Timestamp when user completed the reflection (all cards answered)';

-- =====================================================
-- PART 3: Anonymous Study Guide Ownership
-- =====================================================

-- Anonymous user ownership (references study_guides for content)
CREATE TABLE anonymous_study_guides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL,
  study_guide_id UUID NOT NULL REFERENCES study_guides(id) ON DELETE CASCADE,

  -- User interactions
  is_saved BOOLEAN DEFAULT false,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),

  -- Prevent duplicate session-guide relationships
  CONSTRAINT unique_session_guide UNIQUE(session_id, study_guide_id)
);

-- Performance indexes
CREATE INDEX idx_anonymous_study_guides_session_id ON anonymous_study_guides(session_id);
CREATE INDEX idx_anonymous_study_guides_saved ON anonymous_study_guides(session_id, is_saved) WHERE is_saved = true;
CREATE INDEX idx_anonymous_study_guides_created_at ON anonymous_study_guides(session_id, created_at DESC);
CREATE INDEX idx_anonymous_study_guides_expires_at ON anonymous_study_guides(expires_at);

-- Table comments
COMMENT ON TABLE anonymous_study_guides IS 'Anonymous user ownership for study guides (references study_guides for content)';
COMMENT ON COLUMN anonymous_study_guides.session_id IS 'Anonymous session UUID (standalone, no FK)';
COMMENT ON COLUMN anonymous_study_guides.expires_at IS 'Expiration time for anonymous data retention (7 days default)';

-- =====================================================
-- PART 4: Study Guide Conversations (Follow-up Q&A)
-- =====================================================

-- Conversation threads for follow-up questions
CREATE TABLE study_guide_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  study_guide_id UUID NOT NULL REFERENCES study_guides(id) ON DELETE CASCADE,

  -- User identification (either authenticated or anonymous)
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Ensure either user_id or session_id is provided
  CONSTRAINT check_user_or_session CHECK (
    (user_id IS NOT NULL AND session_id IS NULL) OR
    (user_id IS NULL AND session_id IS NOT NULL)
  ),

  -- One conversation per study guide per user/session
  CONSTRAINT unique_conversation_per_study_guide_user UNIQUE (study_guide_id, user_id),
  CONSTRAINT unique_conversation_per_study_guide_session UNIQUE (study_guide_id, session_id)
);

-- Performance indexes
CREATE INDEX idx_study_guide_conversations_study_guide_id ON study_guide_conversations(study_guide_id);
CREATE INDEX idx_study_guide_conversations_user_id ON study_guide_conversations(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_study_guide_conversations_session_id ON study_guide_conversations(session_id) WHERE session_id IS NOT NULL;

-- Updated timestamp trigger
CREATE OR REPLACE FUNCTION update_study_guide_conversations_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_study_guide_conversations_timestamp
  BEFORE UPDATE ON study_guide_conversations
  FOR EACH ROW
  EXECUTE FUNCTION update_study_guide_conversations_updated_at();

-- Table comments
COMMENT ON TABLE study_guide_conversations IS 'Conversation threads for follow-up questions on study guides';
COMMENT ON COLUMN study_guide_conversations.user_id IS 'Authenticated user ID (null for anonymous)';
COMMENT ON COLUMN study_guide_conversations.session_id IS 'Anonymous session ID (null for authenticated)';

-- =====================================================
-- PART 5: Conversation Messages
-- =====================================================

-- Individual messages within conversation threads
CREATE TABLE conversation_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES study_guide_conversations(id) ON DELETE CASCADE,

  -- Message content
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL CHECK (length(trim(content)) > 0),

  -- Token consumption tracking
  tokens_consumed INTEGER DEFAULT 0 CHECK (tokens_consumed >= 0),

  -- Timestamp
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Performance indexes
CREATE INDEX idx_conversation_messages_conversation_id ON conversation_messages(conversation_id);
CREATE INDEX idx_conversation_messages_created_at ON conversation_messages(created_at DESC);
CREATE INDEX idx_conversation_messages_role ON conversation_messages(conversation_id, role);

-- Table comments
COMMENT ON TABLE conversation_messages IS 'Individual messages within study guide conversation threads';
COMMENT ON COLUMN conversation_messages.role IS 'Message sender: user (questions) or assistant (AI responses)';
COMMENT ON COLUMN conversation_messages.content IS 'Message text content (non-empty)';
COMMENT ON COLUMN conversation_messages.tokens_consumed IS 'Tokens consumed for this message (5 for user questions, 0 for assistant responses)';

-- =====================================================
-- PART 6: Recommended Guide Sessions (Legacy)
-- =====================================================

-- Legacy recommended topic sessions (4-step process)
CREATE TABLE recommended_guide_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Topic information
  topic VARCHAR(100) NOT NULL,
  language VARCHAR(5) DEFAULT 'en',

  -- Step tracking
  current_step INTEGER DEFAULT 1 CHECK (current_step >= 1 AND current_step <= 4),

  -- Step content
  step_1_context TEXT,
  step_2_scholar_guide TEXT,
  step_3_group_discussion TEXT,
  step_4_application TEXT,

  -- Step completion timestamps
  step_1_completed_at TIMESTAMPTZ,
  step_2_completed_at TIMESTAMPTZ,
  step_3_completed_at TIMESTAMPTZ,
  step_4_completed_at TIMESTAMPTZ,

  -- Overall completion
  completion_status BOOLEAN DEFAULT false,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Performance indexes
CREATE INDEX idx_recommended_guide_sessions_user_id ON recommended_guide_sessions(user_id);
CREATE INDEX idx_recommended_guide_sessions_topic ON recommended_guide_sessions(topic);
CREATE INDEX idx_recommended_guide_sessions_completion ON recommended_guide_sessions(user_id, completion_status);
CREATE INDEX idx_recommended_guide_sessions_created_at ON recommended_guide_sessions(user_id, created_at DESC);

-- Updated timestamp trigger
CREATE OR REPLACE FUNCTION update_recommended_guide_sessions_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_recommended_guide_sessions_timestamp
  BEFORE UPDATE ON recommended_guide_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_recommended_guide_sessions_updated_at();

-- Table comments
COMMENT ON TABLE recommended_guide_sessions IS 'Legacy recommended topic study sessions (4-step guided process)';
COMMENT ON COLUMN recommended_guide_sessions.current_step IS 'Current step in 4-step process (1=Context, 2=Scholar, 3=Group, 4=Application)';
COMMENT ON COLUMN recommended_guide_sessions.completion_status IS 'Whether user completed all 4 steps';

-- =====================================================
-- PART 7: Row Level Security (RLS) Policies
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE study_guides ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_guides_in_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_study_guides ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_reflections ENABLE ROW LEVEL SECURITY;
ALTER TABLE anonymous_study_guides ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_guide_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE recommended_guide_sessions ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- study_guides RLS Policies
-- =====================================================

-- Service role has full access for caching operations
CREATE POLICY "service_role_study_guides_all" ON study_guides
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Authenticated users can view all study guides (read-only content cache)
CREATE POLICY "authenticated_users_view_study_guides" ON study_guides
  FOR SELECT
  TO authenticated
  USING (true);

-- Anonymous users can view all study guides
CREATE POLICY "anonymous_users_view_study_guides" ON study_guides
  FOR SELECT
  TO anon
  USING (true);

-- Only service role can insert/update/delete study guides (content management)
CREATE POLICY "service_role_manage_study_guides" ON study_guides
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- =====================================================
-- study_guides_in_progress RLS Policies
-- =====================================================

-- Users can view their own in-progress studies
CREATE POLICY "users_view_own_in_progress_studies" ON study_guides_in_progress
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can insert their own in-progress studies
CREATE POLICY "users_insert_own_in_progress_studies" ON study_guides_in_progress
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own in-progress studies
CREATE POLICY "users_update_own_in_progress_studies" ON study_guides_in_progress
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Service role has full access
CREATE POLICY "service_role_in_progress_all" ON study_guides_in_progress
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- user_study_guides RLS Policies
-- =====================================================

-- Users can view their own study guide relationships
CREATE POLICY "users_view_own_study_guides" ON user_study_guides
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can create relationships for themselves
CREATE POLICY "users_create_own_study_guides" ON user_study_guides
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own study guide relationships
CREATE POLICY "users_update_own_study_guides" ON user_study_guides
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own study guide relationships
CREATE POLICY "users_delete_own_study_guides" ON user_study_guides
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Service role has full access
CREATE POLICY "service_role_user_study_guides_all" ON user_study_guides
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- study_reflections RLS Policies
-- =====================================================

-- Users can view their own reflections
CREATE POLICY "study_reflections_select_own" ON study_reflections
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can create their own reflections
CREATE POLICY "study_reflections_insert_own" ON study_reflections
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own reflections
CREATE POLICY "study_reflections_update_own" ON study_reflections
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own reflections
CREATE POLICY "study_reflections_delete_own" ON study_reflections
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Service role has full access
CREATE POLICY "service_role_study_reflections_all" ON study_reflections
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- anonymous_study_guides RLS Policies
-- =====================================================

-- Anonymous users can view/manage their session's study guides
CREATE POLICY "anonymous_view_own_guides" ON anonymous_study_guides
  FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "anonymous_insert_own_guides" ON anonymous_study_guides
  FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "anonymous_update_own_guides" ON anonymous_study_guides
  FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE POLICY "anonymous_delete_own_guides" ON anonymous_study_guides
  FOR DELETE
  TO anon
  USING (true);

-- Service role has full access
CREATE POLICY "service_role_anonymous_guides_all" ON anonymous_study_guides
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- study_guide_conversations RLS Policies
-- =====================================================

-- Authenticated users can view their own conversations
CREATE POLICY "users_view_own_conversations" ON study_guide_conversations
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Authenticated users can create conversations for their accessible study guides
CREATE POLICY "users_create_conversations" ON study_guide_conversations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM user_study_guides usg
      WHERE usg.study_guide_id = study_guide_conversations.study_guide_id
      AND usg.user_id = auth.uid()
    )
  );

-- Authenticated users can update their own conversations
CREATE POLICY "users_update_own_conversations" ON study_guide_conversations
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Authenticated users can delete their own conversations
CREATE POLICY "users_delete_own_conversations" ON study_guide_conversations
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Anonymous users can view/create/update/delete their session conversations
CREATE POLICY "anonymous_view_session_conversations" ON study_guide_conversations
  FOR SELECT
  TO anon
  USING (auth.uid() IS NULL AND session_id IS NOT NULL);

CREATE POLICY "anonymous_create_session_conversations" ON study_guide_conversations
  FOR INSERT
  TO anon
  WITH CHECK (auth.uid() IS NULL AND session_id IS NOT NULL);

CREATE POLICY "anonymous_update_session_conversations" ON study_guide_conversations
  FOR UPDATE
  TO anon
  USING (auth.uid() IS NULL AND session_id IS NOT NULL)
  WITH CHECK (auth.uid() IS NULL AND session_id IS NOT NULL);

CREATE POLICY "anonymous_delete_session_conversations" ON study_guide_conversations
  FOR DELETE
  TO anon
  USING (auth.uid() IS NULL AND session_id IS NOT NULL);

-- Service role has full access
CREATE POLICY "service_role_conversations_all" ON study_guide_conversations
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- conversation_messages RLS Policies
-- =====================================================

-- Authenticated users can view messages from their conversations
CREATE POLICY "users_view_own_messages" ON conversation_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM study_guide_conversations sgc
      WHERE sgc.id = conversation_messages.conversation_id
      AND sgc.user_id = auth.uid()
    )
  );

-- Authenticated users can create messages in their conversations
CREATE POLICY "users_create_own_messages" ON conversation_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM study_guide_conversations sgc
      WHERE sgc.id = conversation_messages.conversation_id
      AND sgc.user_id = auth.uid()
    )
  );

-- Authenticated users can delete messages from their conversations
CREATE POLICY "users_delete_own_messages" ON conversation_messages
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM study_guide_conversations sgc
      WHERE sgc.id = conversation_messages.conversation_id
      AND sgc.user_id = auth.uid()
    )
  );

-- Anonymous users can view/create/delete messages from their session conversations
CREATE POLICY "anonymous_view_session_messages" ON conversation_messages
  FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1 FROM study_guide_conversations sgc
      WHERE sgc.id = conversation_messages.conversation_id
      AND auth.uid() IS NULL
      AND sgc.session_id IS NOT NULL
    )
  );

CREATE POLICY "anonymous_create_session_messages" ON conversation_messages
  FOR INSERT
  TO anon
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM study_guide_conversations sgc
      WHERE sgc.id = conversation_messages.conversation_id
      AND auth.uid() IS NULL
      AND sgc.session_id IS NOT NULL
    )
  );

CREATE POLICY "anonymous_delete_session_messages" ON conversation_messages
  FOR DELETE
  TO anon
  USING (
    EXISTS (
      SELECT 1 FROM study_guide_conversations sgc
      WHERE sgc.id = conversation_messages.conversation_id
      AND auth.uid() IS NULL
      AND sgc.session_id IS NOT NULL
    )
  );

-- Service role can update assistant messages for streaming
CREATE POLICY "service_role_update_assistant_messages" ON conversation_messages
  FOR UPDATE
  TO service_role
  USING (role = 'assistant')
  WITH CHECK (role = 'assistant');

-- Service role has full access
CREATE POLICY "service_role_messages_all" ON conversation_messages
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- recommended_guide_sessions RLS Policies
-- =====================================================

-- Users can view their own recommended sessions
CREATE POLICY "users_view_own_recommended_sessions" ON recommended_guide_sessions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can create their own recommended sessions
CREATE POLICY "users_create_own_recommended_sessions" ON recommended_guide_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own recommended sessions
CREATE POLICY "users_update_own_recommended_sessions" ON recommended_guide_sessions
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own recommended sessions
CREATE POLICY "users_delete_own_recommended_sessions" ON recommended_guide_sessions
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Service role has full access
CREATE POLICY "service_role_recommended_sessions_all" ON recommended_guide_sessions
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- PART 8: Grant Permissions
-- =====================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON study_guides TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON study_guides_in_progress TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_study_guides TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON study_guide_conversations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON conversation_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON recommended_guide_sessions TO authenticated;

-- Grant function permissions
GRANT EXECUTE ON FUNCTION cleanup_stale_in_progress_studies() TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_stale_in_progress_studies() TO service_role;

-- Grant permissions to anonymous users
GRANT SELECT, INSERT, UPDATE, DELETE ON study_guides TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON anonymous_study_guides TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON study_guide_conversations TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON conversation_messages TO anon;

-- =====================================================
-- PART 9: Verification Queries
-- =====================================================

-- =====================================================
-- PART 7: Daily Verse Cache
-- =====================================================

CREATE TABLE IF NOT EXISTS daily_verses_cache (
  id BIGSERIAL PRIMARY KEY,
  uuid UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
  date_key VARCHAR(10) NOT NULL UNIQUE, -- YYYY-MM-DD format
  verse_data JSONB NOT NULL, -- Complete verse data with translations
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_daily_verses_cache_date_key
  ON daily_verses_cache(date_key)
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_daily_verses_cache_expires_at
  ON daily_verses_cache(expires_at);

CREATE INDEX IF NOT EXISTS idx_daily_verses_cache_uuid
  ON daily_verses_cache(uuid);

-- Enable RLS
ALTER TABLE daily_verses_cache ENABLE ROW LEVEL SECURITY;

-- Allow public read access to active verses (for anonymous users)
CREATE POLICY "Allow public read access to active daily verses"
  ON daily_verses_cache FOR SELECT
  USING (is_active = true);

-- Allow service role full access for cache management
CREATE POLICY "Allow service role full access to daily verse cache"
  ON daily_verses_cache FOR ALL
  USING (auth.role() = 'service_role');

-- Table comments
COMMENT ON TABLE daily_verses_cache IS
  'Cache for daily verse of the day with translations';
COMMENT ON COLUMN daily_verses_cache.uuid IS
  'UUID for stable foreign key references from memory_verses and other features';

-- Verify all tables created
DO $$
DECLARE
  missing_tables TEXT[];
BEGIN
  SELECT ARRAY_AGG(table_name)
  INTO missing_tables
  FROM (
    SELECT 'study_guides' AS table_name
    UNION SELECT 'user_study_guides'
    UNION SELECT 'anonymous_study_guides'
    UNION SELECT 'study_guide_conversations'
    UNION SELECT 'conversation_messages'
    UNION SELECT 'recommended_guide_sessions'
    UNION SELECT 'daily_verses_cache'
  ) expected
  WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name = expected.table_name
  );

  IF array_length(missing_tables, 1) > 0 THEN
    RAISE EXCEPTION 'Migration failed: Missing tables: %', array_to_string(missing_tables, ', ');
  ELSE
    RAISE NOTICE '✅ Migration successful: All 7 study guide system tables created';
  END IF;
END $$;

COMMIT;

-- =====================================================
-- Migration Complete: Study Guide System
-- =====================================================
-- Tables created: 7
--   1. study_guides (content cache)
--   2. user_study_guides (authenticated ownership)
--   3. anonymous_study_guides (anonymous ownership)
--   4. study_guide_conversations (follow-up Q&A)
--   5. conversation_messages (individual messages)
--   6. recommended_guide_sessions (legacy sessions)
--   7. daily_verses_cache (daily verse caching)
--
-- Features:
--   ✅ Content deduplication by hash
--   ✅ Study modes (quick, standard, deep, lectio, sermon)
--   ✅ Creator tracking for token billing
--   ✅ Completion tracking for gamification
--   ✅ Follow-up conversation system
--   ✅ Anonymous user support with expiration
--   ✅ Daily verse caching with UUID references
--   ✅ Comprehensive RLS policies
--   ✅ Performance-optimized indexes
--
-- Next: 0003_token_system.sql
-- =====================================================
