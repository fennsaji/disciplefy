-- Telegram ledgers: claim a day's slot before sending, so a run whose ledger
-- write fails after a successful send can never be re-posted by a retry.
-- Flow: insert/claim 'pending' -> send -> mark 'sent' or 'failed'.
-- A 'pending' row older than the stale window may be reclaimed by a retry.
-- Rollback: delete pending rows, restore CHECK (status IN ('sent','failed')),
--           drop claimed_at.
ALTER TABLE public.telegram_daily_posts
  DROP CONSTRAINT IF EXISTS telegram_daily_posts_status_check,
  ADD CONSTRAINT telegram_daily_posts_status_check CHECK (status IN ('pending', 'sent', 'failed')),
  ADD COLUMN IF NOT EXISTS claimed_at TIMESTAMPTZ;

ALTER TABLE public.telegram_daily_verse_posts
  DROP CONSTRAINT IF EXISTS telegram_daily_verse_posts_status_check,
  ADD CONSTRAINT telegram_daily_verse_posts_status_check CHECK (status IN ('pending', 'sent', 'failed')),
  ADD COLUMN IF NOT EXISTS claimed_at TIMESTAMPTZ;
