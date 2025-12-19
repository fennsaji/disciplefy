-- Migration: Add CHECK constraints for practice_mode columns
-- Created: 2025-12-19
-- Purpose: Add validation constraints to review_sessions.practice_mode and
--          memory_verses.preferred_practice_mode columns (using new mode names)

BEGIN;

-- =============================================================================
-- review_sessions.practice_mode
-- =============================================================================

-- Drop existing constraint if any
ALTER TABLE review_sessions
DROP CONSTRAINT IF EXISTS review_sessions_practice_mode_check;

-- Migrate existing data: convert old mode names to new ones FIRST
UPDATE review_sessions SET practice_mode = 'word_bank' WHERE practice_mode = 'word_order';
UPDATE review_sessions SET practice_mode = 'type_it_out' WHERE practice_mode = 'typing';

-- Add CHECK constraint with new mode names
ALTER TABLE review_sessions
ADD CONSTRAINT review_sessions_practice_mode_check
CHECK (practice_mode IS NULL OR practice_mode IN (
    'flip_card', 'type_it_out', 'cloze', 'first_letter',
    'progressive', 'word_scramble', 'word_bank', 'audio'
));

-- =============================================================================
-- memory_verses.preferred_practice_mode
-- =============================================================================

-- Drop existing constraint if any
ALTER TABLE memory_verses
DROP CONSTRAINT IF EXISTS memory_verses_preferred_practice_mode_check;

-- Migrate existing data: convert old mode names to new ones FIRST
UPDATE memory_verses SET preferred_practice_mode = 'word_bank' WHERE preferred_practice_mode = 'word_order';
UPDATE memory_verses SET preferred_practice_mode = 'type_it_out' WHERE preferred_practice_mode = 'typing';

-- Add CHECK constraint with new mode names
ALTER TABLE memory_verses
ADD CONSTRAINT memory_verses_preferred_practice_mode_check
CHECK (preferred_practice_mode IS NULL OR preferred_practice_mode IN (
    'flip_card', 'type_it_out', 'cloze', 'first_letter',
    'progressive', 'word_scramble', 'word_bank', 'audio'
));

COMMIT;
