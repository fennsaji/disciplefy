-- Drop the existing function
DROP FUNCTION IF EXISTS public.get_recommended_topics_categories();

-- Recreate with correct return type and proper ordering
CREATE OR REPLACE FUNCTION public.get_recommended_topics_categories()
RETURNS TABLE(category TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = pg_catalog, public
AS $$
BEGIN
    RETURN QUERY
    SELECT rt.category::TEXT
    FROM public.recommended_topics rt
    WHERE rt.is_active = true
    GROUP BY rt.category
    ORDER BY MIN(rt.display_order); -- Order by minimum display_order for each category
END;
$$;
