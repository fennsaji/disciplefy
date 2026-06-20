-- Schedule API.Bible content-recency background jobs via pg_cron (Supabase backend).
--
-- Two jobs:
--   1. cleanup-expired-verse-cache  — keyless pure-SQL DELETE of expired cache rows.
--   2. refresh-stale-memory-verses  — HTTP call (pg_net) to the edge function that
--      re-fetches API.Bible text for daily_verse memory rows older than 30 days.
--
-- Guarded so a missing extension (e.g. on a local `supabase db reset`) only raises a
-- NOTICE instead of failing the migration. No secrets are committed: job 2 reads the
-- project URL and service-role key from Vault at run time, so those two secrets must
-- exist for it to fire:
--   select vault.create_secret('https://<PROJECT_REF>.supabase.co', 'project_url');
--   select vault.create_secret('<SERVICE_ROLE_KEY>', 'service_role_key');

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed; skipping recency cron scheduling. Enable pg_cron, then re-run this migration.';
    RETURN;
  END IF;

  -- Job 1: delete expired daily_verses_cache rows daily at 03:00 UTC (keyless).
  PERFORM cron.schedule(
    'cleanup-expired-verse-cache',
    '0 3 * * *',
    $job$DELETE FROM daily_verses_cache WHERE expires_at < now()$job$
  );
  RAISE NOTICE 'Scheduled cron job: cleanup-expired-verse-cache';

  -- Job 2: refresh stale memory_verses daily at 04:00 UTC (needs pg_net + Vault secrets).
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    PERFORM cron.schedule(
      'refresh-stale-memory-verses',
      '0 4 * * *',
      $job$
      SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
               || '/functions/v1/refresh-stale-memory-verses',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' ||
            (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
        ),
        body := '{}'::jsonb
      );
      $job$
    );
    RAISE NOTICE 'Scheduled cron job: refresh-stale-memory-verses (requires Vault secrets project_url + service_role_key)';
  ELSE
    RAISE NOTICE 'pg_net not installed; skipping refresh-stale-memory-verses schedule. Enable pg_net and re-run.';
  END IF;
END
$$;

-- To remove:
--   SELECT cron.unschedule('cleanup-expired-verse-cache');
--   SELECT cron.unschedule('refresh-stale-memory-verses');
