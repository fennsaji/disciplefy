-- Hindi and Malayalam teasers now generate on Sonnet (see llm-service
-- teaserModelForLanguage). Drop the few cached Haiku wordings in those
-- languages so the next request regenerates them on the better model.
-- English rows are untouched.
DELETE FROM public.discipler_teaser_cache
 WHERE language IN ('hi', 'ml')
   AND model LIKE 'claude-haiku%';
