-- Post one lesson a day to the official Telegram channel.
--
-- 09:00 UTC = 14:30 IST, inside the Indian afternoon rather than overnight.
-- Guarded like the other cron migrations so a local `supabase db reset` without
-- pg_cron only raises a NOTICE. The job reads the project URL and service-role
-- key from Vault at run time, so those two secrets must exist for it to fire:
--   select vault.create_secret('https://<PROJECT_REF>.supabase.co', 'project_url');
--   select vault.create_secret('<SERVICE_ROLE_KEY>', 'service_role_key');
--
-- The function itself is idempotent: a second run on the same day returns
-- 'already_posted_today' rather than posting twice.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed; skipping telegram-daily-post scheduling.';
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    RAISE NOTICE 'pg_net not installed; skipping telegram-daily-post scheduling.';
    RETURN;
  END IF;

  PERFORM cron.schedule(
    'telegram-daily-post',
    '0 9 * * *',
    $job$
    SELECT net.http_post(
      url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
             || '/functions/v1/telegram-daily-post',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' ||
          (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
      ),
      body := '{}'::jsonb
    );
    $job$
  );
  RAISE NOTICE 'Scheduled cron job: telegram-daily-post (09:00 UTC)';
END
$$;

-- To remove:
--   SELECT cron.unschedule('telegram-daily-post');
