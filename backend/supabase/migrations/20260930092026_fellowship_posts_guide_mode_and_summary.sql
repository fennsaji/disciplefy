-- 20260930092026_fellowship_posts_guide_mode_and_summary.sql
-- Adds the study mode and a short summary to shared_guide posts, so the feed
-- card can read "SCRIPTURE · STANDARD · 8 MIN" with a two-line preview.
--
-- Both columns are nullable: posts shared before this migration (and older
-- clients that do not send them) keep NULL and render as before.
-- No RLS changes: fellowship_posts is only reached through Edge Functions
-- (service_role policy + table-level grant cover new columns).

BEGIN;

ALTER TABLE fellowship_posts
  ADD COLUMN IF NOT EXISTS guide_study_mode TEXT,
  ADD COLUMN IF NOT EXISTS guide_summary    TEXT;

COMMENT ON COLUMN fellowship_posts.guide_study_mode IS
  'quick | standard | deep | lectio | sermon for shared_guide posts';
COMMENT ON COLUMN fellowship_posts.guide_summary IS
  'Plain-text preview (<= 280 chars) of the guide summary for shared_guide posts';

ALTER TABLE fellowship_posts DROP CONSTRAINT IF EXISTS fellowship_posts_guide_study_mode_check;
ALTER TABLE fellowship_posts ADD CONSTRAINT fellowship_posts_guide_study_mode_check
  CHECK (guide_study_mode IS NULL OR guide_study_mode = ANY (ARRAY[
    'quick'::text, 'standard'::text, 'deep'::text, 'lectio'::text, 'sermon'::text
  ]));

ALTER TABLE fellowship_posts DROP CONSTRAINT IF EXISTS fellowship_posts_guide_summary_length_check;
ALTER TABLE fellowship_posts ADD CONSTRAINT fellowship_posts_guide_summary_length_check
  CHECK (guide_summary IS NULL OR char_length(guide_summary) <= 280);

COMMIT;
