-- Add source_guide_id to blog_posts so we can track which study guide a blog was generated from.
-- Also adds 'study_guide' as a valid source_type.

BEGIN;

-- 1. Drop the old CHECK constraint on source_type so we can add a new allowed value
ALTER TABLE blog_posts DROP CONSTRAINT IF EXISTS blog_posts_source_type_check;

-- 2. Re-add with 'study_guide' included
ALTER TABLE blog_posts
  ADD CONSTRAINT blog_posts_source_type_check
  CHECK (source_type IN ('learning_path_topic', 'manual', 'study_guide'));

-- 3. Add source_guide_id column (nullable FK; SET NULL on guide deletion so blog survives)
ALTER TABLE blog_posts
  ADD COLUMN IF NOT EXISTS source_guide_id UUID
    REFERENCES study_guides(id) ON DELETE SET NULL;

-- 4. Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_blog_posts_source_guide_id
  ON blog_posts(source_guide_id)
  WHERE source_guide_id IS NOT NULL;

-- 5. One blog post per study guide (prevent duplicate generation)
CREATE UNIQUE INDEX IF NOT EXISTS idx_blog_posts_source_guide_unique
  ON blog_posts(source_guide_id)
  WHERE source_guide_id IS NOT NULL;

COMMIT;
