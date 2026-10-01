-- Daily verse text was LLM-written (ESV-style wording) while labelled KJV/IRV.
-- The daily-verse function now takes only the reference from the LLM and the
-- wording from the Bible API (KJV for English, IRV for Hindi/Malayalam).
-- Expire today's and future cached rows so they are regenerated on next read.
-- Rows are expired, not deleted: the upsert on date_key reuses the row, so its
-- uuid (memory_verses.source_id) stays valid. Past dates are left untouched.
-- Rollback: none needed; regenerated rows simply replace the expired ones.
UPDATE public.daily_verses_cache
SET expires_at = now()
WHERE date_key::date >= (now() AT TIME ZONE 'UTC')::date
  AND expires_at > now();
