-- The four rollout switches were seeded with rollout_percentage 0, so the
-- admin list showed "Rollout: 0%" next to an enabled switch and the edit
-- dialog saved 0 back. They are plain on/off switches (is_enabled), like
-- every other flag at 100%. Idempotent: only rows still at 0 or null change.
UPDATE public.feature_flags
SET rollout_percentage = 100,
    updated_at = NOW()
WHERE feature_key IN ('new_first_run', 'guest_mode', 'home_today_layout', 'generate_single_input')
  AND (rollout_percentage IS NULL OR rollout_percentage = 0);
