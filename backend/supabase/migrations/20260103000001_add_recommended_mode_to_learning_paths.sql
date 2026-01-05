-- Migration: Add recommended_mode to learning_paths
-- Purpose: Store recommended study mode for each learning path (Quick/Standard/Deep/Lectio)
-- Related Feature: Recommended Study Modes for Learning Paths with XP Bonuses

-- Add recommended_mode column
ALTER TABLE learning_paths
ADD COLUMN recommended_mode TEXT DEFAULT 'standard'
CHECK (recommended_mode IN ('quick', 'standard', 'deep', 'lectio'));

-- Add column comment for documentation
COMMENT ON COLUMN learning_paths.recommended_mode IS 
'Recommended study mode for this learning path:
- quick: 3-5 min sessions (quick overviews)
- standard: 10-15 min sessions (balanced study)
- deep: 20-30 min sessions (in-depth analysis)
- lectio: 15-20 min sessions (spiritual meditation)';

-- Update existing learning paths with recommended modes
-- Based on path content depth and spiritual focus

-- Beginner paths → Standard mode
UPDATE learning_paths 
SET recommended_mode = 'standard' 
WHERE slug = 'new-believer-essentials';

UPDATE learning_paths 
SET recommended_mode = 'standard' 
WHERE slug = 'serving-and-mission';

UPDATE learning_paths 
SET recommended_mode = 'standard' 
WHERE slug = 'faith-and-family';

UPDATE learning_paths 
SET recommended_mode = 'standard' 
WHERE slug = 'heart-for-the-world';

-- Advanced theological paths → Deep mode
UPDATE learning_paths 
SET recommended_mode = 'deep' 
WHERE slug = 'growing-in-discipleship';

UPDATE learning_paths 
SET recommended_mode = 'deep' 
WHERE slug = 'defending-your-faith';

-- Spiritual formation path → Lectio mode
UPDATE learning_paths 
SET recommended_mode = 'lectio' 
WHERE slug = 'deepening-your-walk';
