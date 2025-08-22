-- ============================================================================
-- Fix Display Order Migration - Remove Syntax Error
-- ============================================================================
-- This migration completes the display order update by adding the unique index
-- and removing the problematic DO block from the previous migration.

BEGIN;

-- Add unique constraint on display_order where is_active = true
CREATE UNIQUE INDEX IF NOT EXISTS idx_recommended_topics_unique_display_order_active 
ON recommended_topics (display_order) 
WHERE is_active = true AND display_order > 0;

-- Add comment explaining the display order logic
COMMENT ON COLUMN recommended_topics.display_order IS 'Unique display order for active topics: 1-6 Foundations, 7-11 Spiritual Disciplines, 12-17 Christian Life, 18-22 Church & Community, 23-27 Family & Relationships, 28-32 Discipleship & Growth, 33-37 Mission & Service, 38-42 Apologetics & Defense';

-- Migration completed successfully!
-- Topics organized by faith level progression:
-- Level 1: Foundations of Faith (1-6)
-- Level 2: Spiritual Disciplines (7-11) 
-- Level 3: Christian Life (12-17)
-- Level 4: Church & Community (18-22)
-- Level 5: Family & Relationships (23-27)
-- Level 6: Discipleship & Growth (28-32)
-- Level 7: Mission & Service (33-37)
-- Level 8: Apologetics & Defense (38-42)

COMMIT;