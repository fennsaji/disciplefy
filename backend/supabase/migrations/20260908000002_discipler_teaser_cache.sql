-- Reuse a topic's Discipler teaser across fellowships instead of paying for it again.
--
-- The teaser prompt takes only the topic, path, language, summary, verse and
-- question — nothing about the group — so two fellowships studying the same
-- lesson were buying two identical generations. The rows are also the source
-- for posting a lesson anywhere else (Telegram, socials) without a fresh call.
--
-- A handful of variants per topic keeps two groups on the same lesson from
-- seeing word-identical posts; the caller picks one deterministically, so a
-- given fellowship always sees the same wording for a given topic.

CREATE TABLE IF NOT EXISTS public.discipler_teaser_cache (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Topic id when the caller knows it, else a hash of path + topic title.
  topic_key   TEXT NOT NULL,
  language    TEXT NOT NULL CHECK (language IN ('en', 'hi', 'ml')),
  variant     SMALLINT NOT NULL CHECK (variant BETWEEN 0 AND 9),
  topic_title TEXT NOT NULL,
  path_title  TEXT NOT NULL,
  hook        TEXT NOT NULL,
  body        TEXT NOT NULL,
  model       TEXT,
  use_count   INTEGER NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at TIMESTAMPTZ,
  CONSTRAINT discipler_teaser_cache_slot_unique UNIQUE (topic_key, language, variant)
);

-- The read path is always (topic_key, language); the unique constraint above
-- already indexes it, so no second index is added.

ALTER TABLE public.discipler_teaser_cache ENABLE ROW LEVEL SECURITY;

-- No policies: only the service role (which bypasses RLS) reads or writes.
-- Teasers reach users through fellowship posts, never by direct table access.

COMMENT ON TABLE public.discipler_teaser_cache IS
  'Generated Discipler teasers keyed by topic + language, reused across fellowships and other channels.';
COMMENT ON COLUMN public.discipler_teaser_cache.topic_key IS
  'recommended_topics.id when known, else sha256 of "path title|topic title".';
COMMENT ON COLUMN public.discipler_teaser_cache.variant IS
  'Slot within a topic; the caller picks one by hashing the fellowship id.';

-- Data-API grants are explicit in this project (see 20260513000001): without
-- this the service role's PostgREST calls fail with "permission denied".
GRANT ALL ON public.discipler_teaser_cache TO service_role;
