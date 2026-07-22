-- Register the subscription reconciliation job in cron_config.
--
-- Scheduling for this project lives in rs-backend's tokio-cron-scheduler, which
-- reads cron_config at startup and re-checks `enabled` on every run. Adding the
-- row here makes the job controllable from the admin cron UI like the others.
INSERT INTO cron_config (name, schedule, label) VALUES
  ('subscription_reconcile', '0 0 * * * *', 'Hourly — reconcile subscriptions with Razorpay')
ON CONFLICT (name) DO NOTHING;

-- Retire the earlier pg_cron-based attempt at the same job.
--
-- 20260703000010 tried to schedule expire-subscriptions via pg_cron + pg_net.
-- That is not how this project schedules work, and the migration silently
-- no-ops when pg_cron is absent (RAISE NOTICE, not an error) — so it may have
-- appeared applied while scheduling nothing. Where it DID schedule, leaving it
-- in place would double-run the job alongside rs-backend.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'expire-subscriptions-hourly') THEN
      PERFORM cron.unschedule('expire-subscriptions-hourly');
      RAISE NOTICE 'Unscheduled pg_cron job expire-subscriptions-hourly (now owned by rs-backend)';
    END IF;
  END IF;
END
$$;
