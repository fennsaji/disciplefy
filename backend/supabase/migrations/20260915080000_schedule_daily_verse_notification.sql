-- Trigger the daily verse push every 15 minutes from pg_cron.
--
-- The hourly GitHub Actions schedule drops most of its runs, so users in IST
-- received the morning verse hours late. The function itself selects users
-- whose local time has reached 08:00 (with a catch-up window) and dedups per
-- day, so running it often is safe. The GitHub workflow stays as a backup.
--
-- Reads the project URL and service-role key from Vault, like
-- telegram-daily-post. Guarded so a local reset without pg_cron only notices.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed; skipping daily-verse-notification scheduling.';
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    RAISE NOTICE 'pg_net not installed; skipping daily-verse-notification scheduling.';
    RETURN;
  END IF;

  PERFORM cron.schedule(
    'daily-verse-notification',
    '*/15 * * * *',
    $job$
    SELECT net.http_post(
      url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
             || '/functions/v1/send-daily-verse-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' ||
          (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 120000
    );
    $job$
  );
  RAISE NOTICE 'Scheduled cron job: daily-verse-notification (every 15 minutes)';
END
$$;

-- To remove:
--   SELECT cron.unschedule('daily-verse-notification');
