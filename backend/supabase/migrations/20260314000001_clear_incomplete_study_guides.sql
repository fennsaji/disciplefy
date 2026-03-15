-- Clear study guides that are missing optional interactive sections due to the
-- OpenAI SSE chunk-drop bug (fixed in commit: buffer incomplete SSE lines).
-- These guides passed required-field validation but are missing summary_insights,
-- reflection_answers, and/or the reflection question fields, causing empty
-- reflection cards on the client. Deleting them forces fresh regeneration.
--
-- Cascades: user_study_guides rows reference study_guides via ON DELETE CASCADE.
-- study_guides_in_progress rows are status='failed'/'completed' and separate.

DELETE FROM study_guides
WHERE
  summary_insights IS NULL
  OR reflection_answers IS NULL
  OR context_question IS NULL
  OR summary_question IS NULL
  OR reflection_question IS NULL
  OR prayer_question IS NULL;

-- Also clear any stale in-progress records with failed/generating status
-- older than 1 hour (these are abandoned generation attempts).
DELETE FROM study_guides_in_progress
WHERE
  status IN ('failed', 'generating')
  AND started_at < NOW() - INTERVAL '1 hour';
