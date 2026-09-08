-- Move the Telegram schedule off pg_cron and into cron_config, where the admin
-- dashboard's Crons page can change it.
--
-- The job was scheduled in pg_cron (see 20260908000005), which no UI can see:
-- changing when the channel posts, or pausing it, meant SQL against production.
-- Every other recurring job — including the fellowship daily post this one is a
-- sibling of — is a row in `cron_config` that rs-backend reads and the
-- dashboard edits. This makes the Telegram job one of them.
--
-- Disabled on arrival, deliberately: enabling it is a decision to start posting
-- to a public channel, and that belongs to whoever opens the dashboard, not to
-- a migration.

INSERT INTO public.cron_config (name, enabled, schedule, label, updated_at)
VALUES (
  'telegram_daily_post',
  false,
  -- 6-field format, as the other rs-backend jobs use: 09:00 UTC = 14:30 IST.
  '0 0 9 * * *',
  'Daily 14:30 IST — Telegram channel post (en, hi, ml)',
  NOW()
)
ON CONFLICT (name) DO NOTHING;

-- Retire the pg_cron entries. Leaving them would post twice a day from two
-- schedulers, and the dashboard would only control one of them.
DO $$
DECLARE
  job_name TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed; nothing to unschedule.';
    RETURN;
  END IF;

  FOREACH job_name IN ARRAY ARRAY[
    'telegram-daily-post',
    'telegram-daily-post-en',
    'telegram-daily-post-hi',
    'telegram-daily-post-ml'
  ]
  LOOP
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = job_name) THEN
      PERFORM cron.unschedule(job_name);
      RAISE NOTICE 'Unscheduled pg_cron job: %', job_name;
    END IF;
  END LOOP;
END
$$;
