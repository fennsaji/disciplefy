-- =====================================================
-- Migration: cron rows for Discipler jobs (rs-backend) and 1.0.5 version
-- Date: 2026-09-06
-- =====================================================

BEGIN;

INSERT INTO cron_config (name, schedule, label, enabled) VALUES
  ('fellowship_daily_post', '0 0 1 * * *', 'Daily 06:30 IST — Discipler learning-path post', false),
  ('discipler_reply_worker', '0 * * * * *', 'Every minute — drain Discipler reply queue', false)
ON CONFLICT (name) DO NOTHING;

UPDATE system_config SET value = '1.0.5', updated_at = now() WHERE key = 'latest_app_version';

COMMIT;
