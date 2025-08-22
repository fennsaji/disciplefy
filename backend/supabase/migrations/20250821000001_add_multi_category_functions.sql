-- Add multi-category filtering functions for recommended topics
-- This migration adds support for filtering by multiple categories simultaneously

BEGIN;

-- ============================================================================
-- MULTI-CATEGORY FUNCTIONS
-- ============================================================================

-- Function to get topics by multiple categories
CREATE OR REPLACE FUNCTION get_recommended_topics_by_categories(
    p_categories TEXT[],
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
    -- Set restricted search_path for security
    SET search_path = public, pg_catalog;
    
    -- Validate input parameters
    IF p_categories IS NULL OR array_length(p_categories, 1) = 0 THEN
        -- Return empty result for invalid input
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        rt.id,
        rt.title,
        rt.description,
        rt.category,
        rt.tags,
        rt.display_order,
        rt.created_at
    FROM public.recommended_topics rt
    WHERE 
        rt.is_active = true
        AND rt.category = ANY(p_categories)
    ORDER BY rt.display_order ASC, rt.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;

-- Function to get count of topics by multiple categories
CREATE OR REPLACE FUNCTION get_recommended_topics_count_by_categories(
    p_categories TEXT[]
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    topic_count INTEGER;
BEGIN
    -- Set restricted search_path for security
    SET search_path = public, pg_catalog;
    
    -- Validate input parameters
    IF p_categories IS NULL OR array_length(p_categories, 1) = 0 THEN
        RETURN 0;
    END IF;
    
    SELECT COUNT(*)
    INTO topic_count
    FROM public.recommended_topics rt
    WHERE 
        rt.is_active = true
        AND rt.category = ANY(p_categories);
    
    RETURN topic_count;
END;
$$;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant execution permissions to authenticated and anonymous users
GRANT EXECUTE ON FUNCTION get_recommended_topics_by_categories(TEXT[], INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_recommended_topics_by_categories(TEXT[], INTEGER, INTEGER) TO anon;

GRANT EXECUTE ON FUNCTION get_recommended_topics_count_by_categories(TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION get_recommended_topics_count_by_categories(TEXT[]) TO anon;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Test the new functions with sample data
DO $$
DECLARE
    test_categories TEXT[] := ARRAY['Christian Life', 'Foundations of Faith'];
    topic_count INTEGER;
    topics_result RECORD;
BEGIN
    -- Test count function
    SELECT get_recommended_topics_count_by_categories(test_categories) INTO topic_count;
    RAISE NOTICE 'Test multi-category count: % topics found', topic_count;
    
    -- Test query function (limit to 1 for testing)
    FOR topics_result IN 
        SELECT * FROM get_recommended_topics_by_categories(test_categories, 1, 0)
    LOOP
        RAISE NOTICE 'Test multi-category query: Found topic "%"', topics_result.title;
    END LOOP;
    
    RAISE NOTICE 'Multi-category functions tested successfully';
END;
$$;

-- Verify function signatures
DO $$
BEGIN
    -- Check multi-category query function
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
        AND p.proname = 'get_recommended_topics_by_categories'
        AND pg_get_function_arguments(p.oid) = 'p_categories text[], p_limit integer DEFAULT 20, p_offset integer DEFAULT 0'
    ) THEN
        RAISE NOTICE 'VERIFIED: get_recommended_topics_by_categories function created';
    ELSE
        RAISE EXCEPTION 'VERIFICATION FAILED: get_recommended_topics_by_categories function missing';
    END IF;
    
    -- Check multi-category count function
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
        AND p.proname = 'get_recommended_topics_count_by_categories'
        AND pg_get_function_arguments(p.oid) = 'p_categories text[]'
    ) THEN
        RAISE NOTICE 'VERIFIED: get_recommended_topics_count_by_categories function created';
    ELSE
        RAISE EXCEPTION 'VERIFICATION FAILED: get_recommended_topics_count_by_categories function missing';
    END IF;
END;
$$;

SELECT 
  'MULTI-CATEGORY FUNCTIONS CREATED SUCCESSFULLY' as status,
  NOW() as completed_at,
  'Added support for filtering by multiple categories simultaneously' as summary;

COMMIT;