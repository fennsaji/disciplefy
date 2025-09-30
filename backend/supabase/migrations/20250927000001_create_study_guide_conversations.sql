-- Migration: Create study guide conversation and message tables for follow-up questions feature
-- Author: Claude Code Assistant
-- Date: 2025-09-27

-- Enable UUID generation if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create study_guide_conversations table
CREATE TABLE study_guide_conversations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    study_guide_id uuid NOT NULL REFERENCES study_guides(id) ON DELETE CASCADE,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id text,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,

    -- Ensure either user_id or session_id is provided
    CONSTRAINT check_user_or_session CHECK (
        (user_id IS NOT NULL AND session_id IS NULL) OR 
        (user_id IS NULL AND session_id IS NOT NULL)
    ),
    
    -- Add constraint to ensure one conversation per study guide per user/session
    CONSTRAINT unique_conversation_per_study_guide_user UNIQUE (study_guide_id, user_id),
    CONSTRAINT unique_conversation_per_study_guide_session UNIQUE (study_guide_id, session_id)
);

-- Create conversation_messages table
CREATE TABLE conversation_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id uuid NOT NULL REFERENCES study_guide_conversations(id) ON DELETE CASCADE,
    role text NOT NULL CHECK (role IN ('user', 'assistant')),
    content text NOT NULL,
    tokens_consumed integer DEFAULT 0 CHECK (tokens_consumed >= 0),
    created_at timestamptz DEFAULT now() NOT NULL,

    -- Add indexes for performance
    CONSTRAINT valid_role CHECK (role IN ('user', 'assistant')),
    CONSTRAINT non_empty_content CHECK (length(trim(content)) > 0)
);

-- Create indexes for better query performance
CREATE INDEX idx_study_guide_conversations_study_guide_id ON study_guide_conversations(study_guide_id);
CREATE INDEX idx_study_guide_conversations_user_id ON study_guide_conversations(user_id);
CREATE INDEX idx_study_guide_conversations_session_id ON study_guide_conversations(session_id);
CREATE INDEX idx_conversation_messages_conversation_id ON conversation_messages(conversation_id);
CREATE INDEX idx_conversation_messages_created_at ON conversation_messages(created_at DESC);

-- Create updated_at trigger for study_guide_conversations
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_study_guide_conversations_updated_at
    BEFORE UPDATE ON study_guide_conversations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- RLS (Row Level Security) Policies

-- Enable RLS on both tables
ALTER TABLE study_guide_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_messages ENABLE ROW LEVEL SECURITY;

-- Study guide conversations policies
CREATE POLICY "Users can view their own conversations"
ON study_guide_conversations FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Anonymous users can view their session conversations"
ON study_guide_conversations FOR SELECT
USING (auth.uid() IS NULL AND session_id IS NOT NULL);

CREATE POLICY "Users can create conversations for their accessible study guides"
ON study_guide_conversations FOR INSERT
WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
        SELECT 1 FROM user_study_guides usg
        WHERE usg.study_guide_id = study_guide_conversations.study_guide_id
        AND usg.user_id = auth.uid()
    )
);

CREATE POLICY "Anonymous users can create session conversations"
ON study_guide_conversations FOR INSERT
WITH CHECK (auth.uid() IS NULL AND session_id IS NOT NULL);

CREATE POLICY "Users can update their own conversations"
ON study_guide_conversations FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Anonymous users can update their session conversations"
ON study_guide_conversations FOR UPDATE
USING (auth.uid() IS NULL AND session_id IS NOT NULL)
WITH CHECK (auth.uid() IS NULL AND session_id IS NOT NULL);

CREATE POLICY "Users can delete their own conversations"
ON study_guide_conversations FOR DELETE
USING (auth.uid() = user_id);

CREATE POLICY "Anonymous users can delete their session conversations"
ON study_guide_conversations FOR DELETE
USING (auth.uid() IS NULL AND session_id IS NOT NULL);

-- Conversation messages policies
CREATE POLICY "Users can view messages from their conversations"
ON conversation_messages FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM study_guide_conversations sgc
        WHERE sgc.id = conversation_messages.conversation_id
        AND sgc.user_id = auth.uid()
    )
);

CREATE POLICY "Anonymous users can view messages from their session conversations"
ON conversation_messages FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM study_guide_conversations sgc
        WHERE sgc.id = conversation_messages.conversation_id
        AND auth.uid() IS NULL 
        AND sgc.session_id IS NOT NULL
    )
);

CREATE POLICY "Users can create messages in their conversations"
ON conversation_messages FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM study_guide_conversations sgc
        WHERE sgc.id = conversation_messages.conversation_id
        AND sgc.user_id = auth.uid()
    )
);

CREATE POLICY "Anonymous users can create messages in their session conversations"
ON conversation_messages FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM study_guide_conversations sgc
        WHERE sgc.id = conversation_messages.conversation_id
        AND auth.uid() IS NULL 
        AND sgc.session_id IS NOT NULL
    )
);

-- Only allow updates to assistant messages (for streaming)
CREATE POLICY "System can update assistant messages"
ON conversation_messages FOR UPDATE
USING (role = 'assistant')
WITH CHECK (role = 'assistant');

CREATE POLICY "Users can delete messages from their conversations"
ON conversation_messages FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM study_guide_conversations sgc
        WHERE sgc.id = conversation_messages.conversation_id
        AND sgc.user_id = auth.uid()
    )
);

CREATE POLICY "Anonymous users can delete messages from their session conversations"
ON conversation_messages FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM study_guide_conversations sgc
        WHERE sgc.id = conversation_messages.conversation_id
        AND auth.uid() IS NULL 
        AND sgc.session_id IS NOT NULL
    )
);

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON study_guide_conversations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON conversation_messages TO authenticated;

-- Add helpful comments
COMMENT ON TABLE study_guide_conversations IS 'Conversation threads for follow-up questions on study guides';
COMMENT ON TABLE conversation_messages IS 'Individual messages within study guide conversations';
COMMENT ON COLUMN conversation_messages.tokens_consumed IS 'Number of tokens consumed for this message (5 for user questions, 0 for assistant responses)';
COMMENT ON COLUMN conversation_messages.role IS 'Message sender: user (for questions) or assistant (for AI responses)';