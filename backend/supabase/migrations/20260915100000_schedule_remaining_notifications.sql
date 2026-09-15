-- Move the remaining scheduled pushes from GitHub Actions to pg_cron.
--
-- GitHub's hourly schedule dropped most runs, so these pushes arrived hours
-- late. Each selector matches on a local-time catch-up window and dedups per
-- day, so running every 15 minutes is safe. Minutes are staggered so no two
-- categories start together and the cross-category spacing check sees what
-- was just sent (daily verse :00, recommended topic :07 are scheduled earlier):
--   memory verse reminder :03   streak lost :05   streak reminder :10
--   memory verse overdue  :12   meeting reminders every minute
--
-- Meeting reminders run every minute: "starts in 10 minutes" is only useful
-- on time. The handler claims each reminder atomically, so overlapping runs
-- never double-send.
--
-- Reads the project URL and service-role key from Vault, like
-- telegram-daily-post. Guarded so a local reset without pg_cron only notices.

DO $$
DECLARE
  job RECORD;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed; skipping notification scheduling.';
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    RAISE NOTICE 'pg_net not installed; skipping notification scheduling.';
    RETURN;
  END IF;

  IF (SELECT count(*) FROM vault.decrypted_secrets WHERE name IN ('project_url', 'service_role_key')) < 2 THEN
    RAISE WARNING 'Vault secrets project_url and service_role_key are missing: the notification cron jobs will fail until they are added.';
  END IF;

  FOR job IN
    SELECT * FROM (VALUES
      ('memory-verse-reminder-notification',  '3-59/15 * * * *',  '/functions/v1/send-memory-verse-notification?type=reminder'),
      ('streak-lost-notification',            '5-59/15 * * * *',  '/functions/v1/send-streak-reminder-notification?type=lost'),
      ('streak-reminder-notification',        '10-59/15 * * * *', '/functions/v1/send-streak-reminder-notification?type=reminder'),
      ('memory-verse-overdue-notification',   '12-59/15 * * * *', '/functions/v1/send-memory-verse-notification?type=overdue'),
      ('meeting-reminder-notification',       '* * * * *',        '/functions/v1/fellowship-meetings/reminder')
    ) AS j(name, schedule, path)
  LOOP
    PERFORM cron.schedule(
      job.name,
      job.schedule,
      format($job$
      SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
               || %L,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' ||
            (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 120000
      );
      $job$, job.path)
    );
    RAISE NOTICE 'Scheduled cron job: % (%)', job.name, job.schedule;
  END LOOP;
END
$$;

-- To remove:
--   SELECT cron.unschedule('memory-verse-reminder-notification');
--   SELECT cron.unschedule('streak-lost-notification');
--   SELECT cron.unschedule('streak-reminder-notification');
--   SELECT cron.unschedule('memory-verse-overdue-notification');
--   SELECT cron.unschedule('meeting-reminder-notification');
