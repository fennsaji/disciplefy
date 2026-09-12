-- On 18 July 2026, a missing LLM API key silently enabled mock mode in
-- production (fixed since — see config.ts's isProduction guard). Six mock
-- study guides were written to the cache and served to readers as real
-- content. They were never cleaned up; pre-warm was expected to eventually
-- overwrite them but only fills topics with NO cached guide, so these
-- placeholders — having a row — were never touched.
--
-- Identified by the mock service's exact, distinctive summary text
-- (llm-service.ts's getMockStudyGuide()). Verified before writing this
-- migration: exactly 6 matching rows exist, none are referenced by any
-- public blog post or fellowship post, and study_guides' foreign keys are
-- CASCADE/SET NULL everywhere (a handful of personal user_study_guides
-- saves cascade-delete with the row; nothing else breaks). Deleting them
-- makes the topic "missing" again, so pre-warm or the next real request
-- regenerates genuine content in its place.
DELETE FROM study_guides
WHERE id IN (
  'b4ad162f-d58c-4f5b-9c74-bb201068b51e',
  'a4da1dd7-06d3-4e70-9ffc-b4809f6560e7',
  '263ca7e1-98b0-4c02-a92f-578f1d685ae4',
  '027f37d0-c47d-41d0-98a4-fa7d26806cfd',
  '95611b91-2990-48fd-a436-141cf4dafa61',
  '19008be2-37f9-4119-bdce-5396a15600ee'
)
AND summary = 'This passage reveals God''s profound love for humanity and His plan for salvation through Jesus Christ.';
