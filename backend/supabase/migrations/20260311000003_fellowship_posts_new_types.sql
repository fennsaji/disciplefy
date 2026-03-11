-- 20260311000003_fellowship_posts_new_types.sql
-- Adds metadata columns for study_note and shared_guide post types.

BEGIN;

-- study_note fields (set when post_type = 'study_note')
ALTER TABLE fellowship_posts
  ADD COLUMN IF NOT EXISTS topic_title    TEXT,
  ADD COLUMN IF NOT EXISTS guide_title    TEXT,
  ADD COLUMN IF NOT EXISTS lesson_index   INT;

-- shared_guide fields (set when post_type = 'shared_guide')
ALTER TABLE fellowship_posts
  ADD COLUMN IF NOT EXISTS study_guide_id   UUID REFERENCES study_guides(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS guide_input_type TEXT,
  ADD COLUMN IF NOT EXISTS guide_language   TEXT;

COMMENT ON COLUMN fellowship_posts.topic_title    IS 'Lesson title for study_note posts';
COMMENT ON COLUMN fellowship_posts.guide_title    IS 'Learning path or guide name';
COMMENT ON COLUMN fellowship_posts.lesson_index   IS '1-based lesson number for study_note posts';
COMMENT ON COLUMN fellowship_posts.study_guide_id IS 'FK to study_guides for shared_guide posts';
COMMENT ON COLUMN fellowship_posts.guide_input_type IS 'scripture | topic for shared_guide posts';
COMMENT ON COLUMN fellowship_posts.guide_language IS 'Language code e.g. en, hi, ml';

-- Expand post_type check constraint to include new types
ALTER TABLE fellowship_posts DROP CONSTRAINT IF EXISTS fellowship_posts_post_type_check;
ALTER TABLE fellowship_posts ADD CONSTRAINT fellowship_posts_post_type_check
  CHECK (post_type = ANY (ARRAY[
    'general'::text, 'prayer'::text, 'praise'::text,
    'question'::text, 'system'::text,
    'study_note'::text, 'shared_guide'::text
  ]));

COMMIT;
