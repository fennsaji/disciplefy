-- =====================================================
-- Migration: study_guides full-text index for Discipler context lookup
-- Date: 2026-09-06
-- =====================================================

BEGIN;

CREATE INDEX IF NOT EXISTS idx_study_guides_fts
  ON study_guides
  USING GIN (to_tsvector('simple', coalesce(input_value, '') || ' ' || coalesce(summary, '')));

-- Top-1 related guide in a language. 'simple' config works for all three scripts.
CREATE OR REPLACE FUNCTION discipler_related_guide(p_query TEXT, p_language TEXT)
RETURNS TABLE(id UUID, input_value TEXT, summary TEXT, interpretation TEXT)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT sg.id, sg.input_value, sg.summary, sg.interpretation
  FROM study_guides sg
  WHERE sg.language = p_language
    AND to_tsvector('simple', coalesce(sg.input_value, '') || ' ' || coalesce(sg.summary, ''))
        @@ plainto_tsquery('simple', p_query)
  ORDER BY ts_rank(
    to_tsvector('simple', coalesce(sg.input_value, '') || ' ' || coalesce(sg.summary, '')),
    plainto_tsquery('simple', p_query)) DESC
  LIMIT 1;
$$;

COMMIT;
