-- =============================================================================
-- Migration: Add Bible Book Name Correction Fields to Voice Messages
-- =============================================================================
-- Adds columns to track when Bible book names have been auto-corrected
-- in voice conversation assistant responses.

BEGIN;

-- Add book_names_corrected column (boolean flag)
ALTER TABLE voice_conversation_messages
ADD COLUMN IF NOT EXISTS book_names_corrected BOOLEAN DEFAULT FALSE;

-- Add corrections_made column (JSONB array of corrections)
-- Stores array of objects like: [{"original": "Jn", "corrected": "John"}]
ALTER TABLE voice_conversation_messages
ADD COLUMN IF NOT EXISTS corrections_made JSONB DEFAULT NULL;

-- Add comments for documentation
COMMENT ON COLUMN voice_conversation_messages.book_names_corrected IS 'Whether Bible book names were auto-corrected in this message';
COMMENT ON COLUMN voice_conversation_messages.corrections_made IS 'Array of corrections made: [{original, corrected}]';

COMMIT;
