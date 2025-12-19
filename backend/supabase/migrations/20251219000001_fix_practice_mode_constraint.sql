-- Migration: Fix practice mode type constraint
-- Created: 2025-12-19
-- Purpose: Update mode_type constraint to use correct names (word_bank, type_it_out)
--          instead of old names (word_order, typing)

BEGIN;

-- Drop the old constraint
ALTER TABLE memory_practice_modes
DROP CONSTRAINT IF EXISTS memory_practice_modes_mode_type_check;

-- Add the new constraint with correct mode names
ALTER TABLE memory_practice_modes
ADD CONSTRAINT memory_practice_modes_mode_type_check
CHECK (mode_type IN (
    'flip_card', 'type_it_out', 'cloze', 'first_letter',
    'progressive', 'word_scramble', 'word_bank', 'audio'
));

COMMIT;
