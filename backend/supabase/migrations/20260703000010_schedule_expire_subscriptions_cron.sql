-- F10: Schedule hourly subscription expiry reconciliation job.
-- The `expire-subscriptions` Edge Function marks active/pending_cancellation
-- subscriptions past their current_period_end as expired.
-- Requires pg_cron extension (enabled in Supabase by default on Pro+).
-- Reads project URL and service-role key from Vault at run time:
--   select vault.create_secret('https://<PROJECT_REF>.supabase.co', 'project_url');
--   select vault.create_secret('<SERVICE_ROLE_KEY>', 'service_role_key');

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed; skipping expire-subscriptions cron scheduling. Enable pg_cron, then re-run this migration.';
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    RAISE NOTICE 'pg_net not installed; skipping expire-subscriptions cron scheduling. Enable pg_net, then re-run this migration.';
    RETURN;
  END IF;

  PERFORM cron.schedule(
    'expire-subscriptions-hourly',
    '0 * * * *',   -- every hour on the hour
    $job$
    SELECT net.http_post(
      url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
             || '/functions/v1/expire-subscriptions',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' ||
          (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
      ),
      body := '{}'::jsonb
    );
    $job$
  );

  RAISE NOTICE 'Scheduled cron job: expire-subscriptions-hourly (requires Vault secrets project_url + service_role_key)';
END
$$;

-- To remove:
--   SELECT cron.unschedule('expire-subscriptions-hourly');
