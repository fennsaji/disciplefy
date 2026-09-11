-- Key the study cache on the catalogue topic.
--
-- The app sends a lesson's English title with a language code; the blog
-- generator sends the translated title. Their input_value_hash values never
-- match, so the same Hindi or Malayalam guide was generated twice and the app
-- could not find the one the blog had already paid for.
--
-- study_guides.topic_id already exists but was never written. New rows now set
-- it (see study-guide-repository findOrCreateCachedContent). This backfills the
-- rows already stored, matching on the title the topic is known by in that
-- language, and indexes the lookup.

-- English rows: the stored title is the topic's own title.
UPDATE public.study_guides g
   SET topic_id = rt.id
  FROM public.recommended_topics rt
 WHERE g.topic_id IS NULL
   AND g.input_type = 'topic'
   AND g.language = 'en'
   AND lower(btrim(g.input_value)) = lower(btrim(rt.title));

-- Hindi and Malayalam rows: the stored title is the translated one.
UPDATE public.study_guides g
   SET topic_id = t.topic_id
  FROM public.recommended_topics_translations t
 WHERE g.topic_id IS NULL
   AND g.input_type = 'topic'
   AND g.language = t.language_code
   AND lower(btrim(g.input_value)) = lower(btrim(t.title));

-- Some localised rows carry the English title with a non-English language code.
UPDATE public.study_guides g
   SET topic_id = rt.id
  FROM public.recommended_topics rt
 WHERE g.topic_id IS NULL
   AND g.input_type = 'topic'
   AND lower(btrim(g.input_value)) = lower(btrim(rt.title));

-- The lookup path: one row per topic, language and mode.
CREATE INDEX IF NOT EXISTS idx_study_guides_topic_lookup
    ON public.study_guides (topic_id, language, study_mode)
 WHERE topic_id IS NOT NULL;
