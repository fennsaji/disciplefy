-- Fix get_recommended_topics function to remove difficulty_level and estimated_duration references

-- Drop existing functions that reference removed columns
DROP FUNCTION IF EXISTS get_recommended_topics(TEXT, TEXT, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS get_recommended_topics_count(TEXT, TEXT);

-- Create updated get_recommended_topics function without difficulty parameters
CREATE OR REPLACE FUNCTION get_recommended_topics(
    p_category TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    description TEXT,
    category VARCHAR,
    tags TEXT[],
    display_order INTEGER,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rt.id,
        rt.title,
        rt.description,
        rt.category,
        rt.tags,
        rt.display_order,
        rt.created_at
    FROM recommended_topics rt
    WHERE 
        rt.is_active = true
        AND (p_category IS NULL OR rt.category = p_category)
    ORDER BY rt.display_order ASC, rt.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;

-- Create updated get_recommended_topics_count function without difficulty parameter
CREATE OR REPLACE FUNCTION get_recommended_topics_count(
    p_category TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    topic_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO topic_count
    FROM recommended_topics rt
    WHERE 
        rt.is_active = true
        AND (p_category IS NULL OR rt.category = p_category);
    
    RETURN topic_count;
END;
$$;

-- Create get_recommended_topics_categories function
CREATE OR REPLACE FUNCTION get_recommended_topics_categories()
RETURNS TABLE (
    category VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT rt.category
    FROM recommended_topics rt
    WHERE rt.is_active = true
    ORDER BY rt.category;
END;
$$;