-- API.Bible content-recency compliance for memory_verses.
--
-- memory_verses sourced from the daily verse (source_type = 'daily_verse') store
-- API.Bible verse text indefinitely. API.Bible's terms require stored content to
-- be refreshed at least every 30 days. Track when each row's verse_text was last
-- synced from API.Bible so a scheduled job (refresh-stale-memory-verses) can
-- re-fetch rows older than 30 days.
--
-- manual / ai_generated rows are NOT API.Bible content and are never refreshed.

ALTER TABLE memory_verses
  ADD COLUMN IF NOT EXISTS verse_text_synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Baseline existing rows to their last-updated time. Rows already older than
-- 30 days become immediately eligible for refresh on the next job run.
UPDATE memory_verses
SET verse_text_synced_at = COALESCE(updated_at, created_at);

-- Efficiently locate API.Bible-sourced rows that need refreshing.
CREATE INDEX IF NOT EXISTS idx_memory_verses_stale_text
  ON memory_verses (verse_text_synced_at)
  WHERE source_type = 'daily_verse';
