-- Drop the existing function
DROP FUNCTION IF EXISTS get_recommended_topics_categories();

-- Recreate with correct return type and proper ordering
CREATE OR REPLACE FUNCTION get_recommended_topics_categories()
RETURNS TABLE(category TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Set restricted search_path for security
    SET search_path = public, pg_catalog;

    RETURN QUERY
    SELECT rt.category::TEXT
    FROM public.recommended_topics rt
    WHERE rt.is_active = true
    GROUP BY rt.category
    ORDER BY MIN(rt.display_order); -- Order by minimum display_order for each category
END;
$$;
