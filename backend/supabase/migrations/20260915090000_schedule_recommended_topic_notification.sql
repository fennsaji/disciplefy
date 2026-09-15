-- Trigger the daily study guide (recommended topic) push every 15 minutes
-- from pg_cron, replacing the unreliable hourly GitHub Actions schedule.
--
-- The function selects users whose local time has reached 09:00 (with a
-- catch-up window) and dedups per day. Runs at :07/:22/:37/:52 so it never
-- starts alongside the daily verse job (:00/:15/:30/:45), letting the
-- cross-category spacing check see verses that were just sent.
--
-- Reads the project URL and service-role key from Vault, like
-- telegram-daily-post. Guarded so a local reset without pg_cron only notices.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed; skipping recommended-topic-notification scheduling.';
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    RAISE NOTICE 'pg_net not installed; skipping recommended-topic-notification scheduling.';
    RETURN;
  END IF;

  PERFORM cron.schedule(
    'recommended-topic-notification',
    '7-59/15 * * * *',
    $job$
    SELECT net.http_post(
      url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
             || '/functions/v1/send-recommended-topic-notification',
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
  RAISE NOTICE 'Scheduled cron job: recommended-topic-notification (every 15 minutes)';
END
$$;

-- To remove:
--   SELECT cron.unschedule('recommended-topic-notification');
