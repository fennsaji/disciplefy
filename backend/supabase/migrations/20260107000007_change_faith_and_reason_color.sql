-- ============================================================================
-- Migration: Change Faith & Reason Color
-- Date: 2026-01-07
-- Description: Changes the color of "Faith & Reason" learning path from
--              purple (#7C3AED) to deep blue (#2563EB) to make it more
--              distinctive and align with the wisdom/knowledge theme.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. UPDATE COLOR
-- ============================================================================

UPDATE learning_paths
SET color = '#F59E0B'  -- Amber/Orange (enlightenment, understanding, knowledge)
WHERE id = 'aaa00000-0000-0000-0000-000000000010'; -- Faith & Reason

-- ============================================================================
-- 2. VERIFICATION
-- ============================================================================

DO $$
DECLARE
  updated_color VARCHAR;
BEGIN
  -- Check color was updated
  SELECT color INTO updated_color
  FROM learning_paths
  WHERE id = 'aaa00000-0000-0000-0000-000000000010';

  IF updated_color != '#F59E0B' THEN
    RAISE EXCEPTION 'Faith & Reason color should be #F59E0B, but is %', updated_color;
  END IF;

  RAISE NOTICE '✓ Migration completed successfully:';
  RAISE NOTICE '  - Faith & Reason color changed to amber/orange (#F59E0B)';
  RAISE NOTICE '  - Previous color: #7C3AED (purple)';
  RAISE NOTICE '  - New color represents enlightenment, understanding, and knowledge';
END $$;

COMMIT;
