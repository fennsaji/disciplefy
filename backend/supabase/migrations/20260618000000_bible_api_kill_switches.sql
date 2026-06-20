-- Bible-API admin kill switches + purge function.
-- Two kill-switch feature flags (default enabled) and an atomic purge routine
-- for removing cached API.Bible content at rest (compliance).

INSERT INTO public.feature_flags
  (feature_key, feature_name, description, is_enabled, display_mode, enabled_for_plans, rollout_percentage, metadata)
VALUES
  ('bible_api_calls_enabled', 'Bible API — calls',
   'Operational switch. When OFF, the backend makes no new calls to API.Bible (serves cache + fallbacks).',
   true, 'hide', ARRAY['free','standard','plus','premium'], 100,
   '{"category":"kill_switches","critical":true}'::jsonb),
  ('bible_content_enabled', 'Bible API — content',
   'Compliance kill-switch. When OFF, API.Bible content is not served or shown (hides verse surfaces, blocks endpoints).',
   true, 'hide', ARRAY['free','standard','plus','premium'], 100,
   '{"category":"kill_switches","critical":true}'::jsonb)
ON CONFLICT (feature_key) DO NOTHING;

-- Atomic purge of cached API.Bible content at rest.
CREATE OR REPLACE FUNCTION public.purge_bible_content()
RETURNS TABLE(deleted_cache_rows integer, blanked_memory_verses integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted integer;
  v_blanked integer;
BEGIN
  DELETE FROM daily_verses_cache;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  UPDATE memory_verses
  SET verse_text = '',
      verse_text_synced_at = 'epoch'::timestamptz,
      updated_at = now()
  WHERE source_type = 'daily_verse' AND verse_text <> '';
  GET DIAGNOSTICS v_blanked = ROW_COUNT;

  RETURN QUERY SELECT v_deleted, v_blanked;
END;
$$;

REVOKE ALL ON FUNCTION public.purge_bible_content() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_bible_content() TO service_role;
