-- F10: Schedule hourly subscription expiry reconciliation job.
-- The `expire-subscriptions` Edge Function marks active/pending_cancellation
-- subscriptions past their current_period_end as expired.
-- Requires pg_cron extension (enabled in Supabase by default on Pro+).

SELECT cron.schedule(
  'expire-subscriptions-hourly',
  '0 * * * *',   -- every hour on the hour
  $$
    SELECT net.http_post(
      url := current_setting('app.settings.supabase_url') || '/functions/v1/expire-subscriptions',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
      ),
      body := '{}'::jsonb
    );
  $$
);
