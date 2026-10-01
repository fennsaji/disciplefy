-- Daily verse text was LLM-written (ESV-style wording) while labelled KJV/IRV.
-- The daily-verse function now takes only the reference from the LLM and the
-- wording from the Bible API (KJV for English, IRV for Hindi/Malayalam).
--
-- text_source marks rows whose wording came from the Bible API. Rows without
-- it (all existing rows) are refreshed by the function on their next read:
-- same reference, same uuid (memory_verses.source_id), new wording. expires_at
-- is NOT touched here, so a row can never change its reference mid-day or be
-- deleted by the cleanup job before it is refreshed.
-- Rollback: ALTER TABLE public.daily_verses_cache DROP COLUMN text_source;
ALTER TABLE public.daily_verses_cache
  ADD COLUMN IF NOT EXISTS text_source TEXT;

COMMENT ON COLUMN public.daily_verses_cache.text_source IS
  'Where verse_data.translations came from: bible_api, or NULL for legacy LLM text (refreshed on next read).';

-- The cleanup job must never delete today's or a future row, even if expired:
-- the function refreshes such rows in place (keeping uuid and reference).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron')
     AND EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup-expired-verse-cache') THEN
    PERFORM cron.schedule(
      'cleanup-expired-verse-cache',
      '0 3 * * *',
      $j$DELETE FROM daily_verses_cache WHERE expires_at < now() AND date_key < to_char((now() AT TIME ZONE 'UTC')::date, 'YYYY-MM-DD')$j$
    );
  END IF;
END $$;
