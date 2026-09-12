-- A shared study guide is content on its own — the guide card the client
-- renders from study_guide_id/guide_title — so the optional message next to
-- it is allowed to be blank, matching the share sheet's own "optional"
-- label. The edge function's application-level check was relaxed for this
-- case, but this table-level constraint still rejected an empty message for
-- every post type, so sharing a guide with no personal note failed with a
-- raw 500 (constraint violation) instead of ever reaching the app's own
-- validation.
ALTER TABLE public.fellowship_posts
  DROP CONSTRAINT IF EXISTS fellowship_posts_content_check;

ALTER TABLE public.fellowship_posts
  ADD CONSTRAINT fellowship_posts_content_check CHECK (
    char_length(content) <= 2000
    AND (
      char_length(content) >= 1
      OR (post_type = 'shared_guide' AND study_guide_id IS NOT NULL)
    )
  );
