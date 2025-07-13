-- Add input_value field for display purposes
-- This field stores the original input for UI display while maintaining the hash for deduplication

BEGIN;

-- Add input_value column to store original input for display
-- This is separate from input_value_hash which is used for deduplication
ALTER TABLE study_guides 
ADD COLUMN IF NOT EXISTS input_value TEXT;

-- Create index for better query performance when searching by input value
CREATE INDEX IF NOT EXISTS idx_study_guides_input_value 
ON study_guides(input_value);

-- Update existing records to have a placeholder value
-- In production, you would populate this with actual values if available
UPDATE study_guides 
SET input_value = '[Legacy Content]' 
WHERE input_value IS NULL;

-- Make the field NOT NULL for future inserts
ALTER TABLE study_guides 
ALTER COLUMN input_value SET NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN study_guides.input_value IS 'Original input value for display purposes (separate from hash used for deduplication)';

COMMIT;