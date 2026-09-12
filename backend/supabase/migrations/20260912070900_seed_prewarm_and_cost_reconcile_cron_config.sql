-- The pre-warm cron cannot be turned off, and the dashboard cannot see it.
--
-- Every recurring rs-backend job is a `cron_config` row that the admin Crons
-- page lists and toggles. Two jobs never got one: `prewarm` and
-- `cost_reconcile`. With no row, they are absent from the page — there is no
-- switch to find — and rs-backend's own guard reads the missing row as an
-- error and proceeds anyway:
--
--     Err(e) => tracing::warn!("Could not read cron_config: {} — proceeding anyway", e),
--
-- So pre-warm has been running hourly with no way to stop it short of setting
-- its monthly budget to zero, which only stops new batches — the tick still
-- fires, and a batch already in flight still completes. Pre-warm submits work
-- to the Anthropic Batch API (~$0.063 per guide, three languages per lesson)
-- and is deliberately exempt from the daily cost ceiling, so its monthly
-- budget is the only other guardrail. A job that spends money should have an
-- off switch.
--
-- Seeded disabled, matching the defaults rs-backend already declares for both
-- and the precedent of 20260908000006: enabling a job that spends money is a
-- decision for whoever opens the dashboard, not for a migration. Existing
-- deployments where these are wanted can switch them on there.

INSERT INTO public.cron_config (name, enabled, schedule, label, updated_at)
VALUES
  (
    'prewarm',
    false,
    -- 6-field format (sec min hour dom mon dow), as the other rs-backend jobs use.
    '0 0 * * * *',
    'Hourly — pre-generate learning-path guides on the Batch API',
    NOW()
  ),
  (
    'cost_reconcile',
    false,
    '0 0 2 * * *',
    'Daily 02:00 UTC — compare recorded spend with Anthropic''s bill',
    NOW()
  )
ON CONFLICT (name) DO NOTHING;
