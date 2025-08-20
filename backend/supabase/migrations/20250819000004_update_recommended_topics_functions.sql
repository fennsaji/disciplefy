-- Update recommended_topics functions after column removal
-- This migration recreates functions without removed columns and adds backward compatibility

BEGIN;

-- ============================================================================
-- FUNCTION UPDATES
-- ============================================================================

-- Create updated function definitions without removed columns and add backward compatibility

-- ============================================================================
-- MAIN QUERY FUNCTION
-- ============================================================================

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
    -- Set restricted search_path for security
    SET search_path = public, pg_catalog;
    
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
        AND (p_category IS NULL OR rt.category = p_category)
    ORDER BY rt.display_order ASC, rt.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;

-- ============================================================================
-- COUNT FUNCTION
-- ============================================================================

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
    -- Set restricted search_path for security
    SET search_path = public, pg_catalog;
    
    SELECT COUNT(*)
    INTO topic_count
    FROM public.recommended_topics rt
    WHERE 
        rt.is_active = true
        AND (p_category IS NULL OR rt.category = p_category);
    
    RETURN topic_count;
END;
$$;

-- ============================================================================
-- CATEGORIES FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION get_recommended_topics_categories()
RETURNS TABLE (
    category VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Set restricted search_path for security
    SET search_path = public, pg_catalog;
    
    RETURN QUERY
    SELECT DISTINCT rt.category
    FROM public.recommended_topics rt
    WHERE rt.is_active = true
    ORDER BY rt.category;
END;
$$;

-- ============================================================================
-- BACKWARD COMPATIBILITY WRAPPERS
-- ============================================================================

-- Legacy function signature with difficulty parameter (deprecated)
CREATE OR REPLACE FUNCTION get_recommended_topics(
    p_category TEXT,
    p_difficulty TEXT, -- DEPRECATED: This parameter is ignored
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
    -- Wrapper for backward compatibility - ignores difficulty parameter
    -- Set restricted search_path for security
    SET search_path = public, pg_catalog;
    
    -- Log deprecation warning
    RAISE NOTICE 'DEPRECATED: get_recommended_topics with difficulty parameter is deprecated. Use get_recommended_topics(category, limit, offset) instead.';
    
    -- Delegate to new function signature
    RETURN QUERY
    SELECT * FROM get_recommended_topics(p_category, p_limit, p_offset);
END;
$$;

-- Legacy count function with difficulty parameter (deprecated)
CREATE OR REPLACE FUNCTION get_recommended_topics_count(
    p_category TEXT,
    p_difficulty TEXT -- DEPRECATED: This parameter is ignored
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Wrapper for backward compatibility - ignores difficulty parameter
    -- Set restricted search_path for security
    SET search_path = public, pg_catalog;
    
    -- Log deprecation warning
    RAISE NOTICE 'DEPRECATED: get_recommended_topics_count with difficulty parameter is deprecated. Use get_recommended_topics_count(category) instead.';
    
    -- Delegate to new function signature
    RETURN get_recommended_topics_count(p_category);
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify new function signatures exist
DO $$
BEGIN
    -- Check new main function
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
        AND p.proname = 'get_recommended_topics'
        AND pg_get_function_arguments(p.oid) = 'p_category text DEFAULT NULL::text, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0'
    ) THEN
        RAISE NOTICE 'VERIFIED: New get_recommended_topics function signature exists';
    ELSE
        RAISE EXCEPTION 'VERIFICATION FAILED: New get_recommended_topics function signature missing';
    END IF;
    
    -- Check backward compatibility function
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
        AND p.proname = 'get_recommended_topics'
        AND pg_get_function_arguments(p.oid) LIKE '%p_difficulty text%'
    ) THEN
        RAISE NOTICE 'VERIFIED: Backward compatibility get_recommended_topics function exists';
    ELSE
        RAISE EXCEPTION 'VERIFICATION FAILED: Backward compatibility get_recommended_topics function missing';
    END IF;
    
    -- Check categories function
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
        AND p.proname = 'get_recommended_topics_categories'
    ) THEN
        RAISE NOTICE 'VERIFIED: get_recommended_topics_categories function exists';
    ELSE
        RAISE EXCEPTION 'VERIFICATION FAILED: get_recommended_topics_categories function missing';
    END IF;
END;
$$;

SELECT 
  'FUNCTION UPDATES COMPLETED SUCCESSFULLY' as status,
  NOW() as completed_at,
  'Updated functions with new signatures and backward compatibility' as summary;

COMMIT;