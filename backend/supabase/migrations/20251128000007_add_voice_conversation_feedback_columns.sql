-- ============================================================================
-- Migration: Add Feedback Columns to voice_conversations
-- Version: 1.0
-- Date: 2025-11-28
-- Description: Adds user_rating, feedback_text, and was_helpful columns to
--              the voice_conversations table for user feedback support.
-- ============================================================================

ALTER TABLE voice_conversations
ADD COLUMN IF NOT EXISTS user_rating INTEGER CHECK (user_rating >= 1 AND user_rating <= 5),
ADD COLUMN IF NOT EXISTS feedback_text TEXT,
ADD COLUMN IF NOT EXISTS was_helpful BOOLEAN;

COMMENT ON COLUMN voice_conversations.user_rating IS 'User rating from 1-5 stars';
COMMENT ON COLUMN voice_conversations.feedback_text IS 'Optional user feedback text';
COMMENT ON COLUMN voice_conversations.was_helpful IS 'Whether the conversation was helpful';
