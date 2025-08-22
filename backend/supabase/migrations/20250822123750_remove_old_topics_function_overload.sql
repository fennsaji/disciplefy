-- Fix function overload issue by removing old 3-parameter version
-- The repository now calls the 4-parameter version with p_difficulty

-- Drop the old 3-parameter version that's causing overload conflicts
DROP FUNCTION IF EXISTS get_recommended_topics(text, integer, integer);

-- Drop the old count function that might also have overload issues  
DROP FUNCTION IF EXISTS get_recommended_topics_count(text, text);

-- Ensure we only have the correct 4-parameter version
-- (The 4-parameter version should already exist from previous migrations)