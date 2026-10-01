-- Recreate every pg_cron job, now that pg_cron and pg_net are enabled.
--
-- Production had neither extension until now, so each earlier scheduling
-- migration took its "not installed" NOTICE branch and scheduled nothing.
-- This re-applies the latest definition of each job, idempotently
-- (unschedule if present, then schedule).
--
-- Deliberately NOT recreated (later migrations moved them to rs-backend's
-- cron_config, whose rows were inserted outside the guarded blocks):
--   expire-subscriptions-hourly  (20260722000001 -> cron_config subscription_reconcile)
--   telegram-daily-post[-en|-hi|-ml] (20260908000006 -> cron_config telegram_daily_post)
--
-- Without pg_cron (local dev) this only raises a NOTICE. With pg_cron but no
-- pg_net or no Vault secrets it fails loudly, so a deploy cannot silently
-- schedule nothing again. Secrets are read from Vault at run time only.

DO $$
DECLARE
  job RECORD;
  http_cmd CONSTANT TEXT := $tpl$
    SELECT net.http_post(
      url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
             || %L,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' ||
          (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
      ),
      body := '{}'::jsonb%s
    );
  $tpl$;
  long_timeout CONSTANT TEXT := E',\n      timeout_milliseconds := 120000';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed; skipping cron job rescheduling.';
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    RAISE EXCEPTION 'pg_cron is installed but pg_net is not: enable pg_net before applying this migration.';
  END IF;

  IF (SELECT count(DISTINCT name) FROM vault.decrypted_secrets
       WHERE name IN ('project_url', 'service_role_key')
         AND coalesce(decrypted_secret, '') <> '') < 2 THEN
    RAISE EXCEPTION 'Vault secrets project_url and service_role_key must both exist before applying this migration.';
  END IF;

  FOR job IN
    SELECT * FROM (VALUES
      -- Keyless SQL jobs
      ('cleanup-expired-verse-cache', '0 3 * * *',
        $j$DELETE FROM daily_verses_cache WHERE expires_at < now()$j$),
      ('cleanup-old-analytics-events', '30 3 * * *',
        $j$DELETE FROM public.analytics_events WHERE created_at < now() - interval '90 days'$j$),
      -- Edge Function calls (default pg_net timeout)
      ('refresh-stale-memory-verses', '0 4 * * *',
        format(http_cmd, '/functions/v1/refresh-stale-memory-verses', '')),
      -- Notification pushes (120s timeout)
      ('daily-verse-notification', '*/15 * * * *',
        format(http_cmd, '/functions/v1/send-daily-verse-notification', long_timeout)),
      ('memory-verse-reminder-notification', '3-59/15 * * * *',
        format(http_cmd, '/functions/v1/send-memory-verse-notification?type=reminder', long_timeout)),
      ('streak-lost-notification', '5-59/15 * * * *',
        format(http_cmd, '/functions/v1/send-streak-reminder-notification?type=lost', long_timeout)),
      ('recommended-topic-notification', '7-59/15 * * * *',
        format(http_cmd, '/functions/v1/send-recommended-topic-notification', long_timeout)),
      ('streak-reminder-notification', '10-59/15 * * * *',
        format(http_cmd, '/functions/v1/send-streak-reminder-notification?type=reminder', long_timeout)),
      ('memory-verse-overdue-notification', '12-59/15 * * * *',
        format(http_cmd, '/functions/v1/send-memory-verse-notification?type=overdue', long_timeout)),
      ('meeting-reminder-notification', '* * * * *',
        format(http_cmd, '/functions/v1/fellowship-meetings/reminder', long_timeout))
    ) AS j(name, schedule, command)
  LOOP
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = job.name;
    PERFORM cron.schedule(job.name, job.schedule, job.command);
    RAISE NOTICE 'Scheduled cron job: % (%)', job.name, job.schedule;
  END LOOP;

  -- Make sure the retired pg_cron jobs stay retired.
  PERFORM cron.unschedule(jobid) FROM cron.job
   WHERE jobname IN ('expire-subscriptions-hourly', 'telegram-daily-post',
                     'telegram-daily-post-en', 'telegram-daily-post-hi', 'telegram-daily-post-ml');
END
$$;
