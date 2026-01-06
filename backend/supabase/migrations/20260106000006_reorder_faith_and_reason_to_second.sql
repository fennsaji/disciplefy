-- ============================================================================
-- Migration: Reorder Faith & Reason to Position 2
-- Date: 2026-01-07
-- Description: Moves the "Faith & Reason" learning path to display position 2
--              (right after "New Believer Essentials"). Shifts all paths that
--              were at positions 2-9 down by one position.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. SHIFT DOWN PATHS FROM POSITIONS 2-9 (to make room at position 2)
-- ============================================================================

-- Temporarily move Faith & Reason to position 99 to avoid conflicts
UPDATE learning_paths
SET display_order = 99
WHERE id = 'aaa00000-0000-0000-0000-000000000010'; -- Faith & Reason

-- Shift positions 2-9 down by 1 (becomes 3-10)
UPDATE learning_paths
SET display_order = display_order + 1
WHERE display_order >= 2 AND display_order <= 9;

-- ============================================================================
-- 2. MOVE FAITH & REASON TO POSITION 2
-- ============================================================================

UPDATE learning_paths
SET display_order = 2
WHERE id = 'aaa00000-0000-0000-0000-000000000010'; -- Faith & Reason

-- ============================================================================
-- 3. VERIFICATION
-- ============================================================================

DO $$
DECLARE
  faith_reason_order INTEGER;
  new_believer_order INTEGER;
  growing_order INTEGER;
BEGIN
  -- Check Faith & Reason is at position 2
  SELECT display_order INTO faith_reason_order
  FROM learning_paths
  WHERE id = 'aaa00000-0000-0000-0000-000000000010';

  IF faith_reason_order != 2 THEN
    RAISE EXCEPTION 'Faith & Reason display_order should be 2, but is %', faith_reason_order;
  END IF;

  -- Check New Believer Essentials is still at position 1
  SELECT display_order INTO new_believer_order
  FROM learning_paths
  WHERE id = 'aaa00000-0000-0000-0000-000000000001';

  IF new_believer_order != 1 THEN
    RAISE EXCEPTION 'New Believer Essentials should remain at position 1, but is %', new_believer_order;
  END IF;

  -- Check Growing in Discipleship moved to position 3
  SELECT display_order INTO growing_order
  FROM learning_paths
  WHERE id = 'aaa00000-0000-0000-0000-000000000002';

  IF growing_order != 3 THEN
    RAISE EXCEPTION 'Growing in Discipleship should be at position 3, but is %', growing_order;
  END IF;

  RAISE NOTICE '✓ Migration completed successfully:';
  RAISE NOTICE '  - Faith & Reason moved to display position 2';
  RAISE NOTICE '  - Previous paths (positions 2-9) shifted down by 1';
  RAISE NOTICE '  - New order: New Believer Essentials (1) → Faith & Reason (2) → Growing in Discipleship (3)';
END $$;

COMMIT;
