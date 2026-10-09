-- Dark-launch switches for the new-user redesign (first run, guest mode,
-- Home today layout, single-input Generate). All start off; flip them from
-- admin-web > Feature flags. Idempotent: existing rows are left untouched.
INSERT INTO public.feature_flags
  (feature_key, feature_name, description, is_enabled, display_mode, enabled_for_plans, rollout_percentage, metadata)
VALUES
  ('new_first_run', 'New first run', 'Language → goal → lesson 1 → sign up / guest.', false, 'hide', ARRAY['free','standard','plus','premium'], 0, '{"category":"rollout"}'::jsonb),
  ('guest_mode', 'Guest mode', 'Anonymous users can finish their first path before signing up.', false, 'hide', ARRAY['free','standard','plus','premium'], 0, '{"category":"rollout"}'::jsonb),
  ('home_today_layout', 'Home today layout', 'Verse + path strip + today''s lesson + New for you.', false, 'hide', ARRAY['free','standard','plus','premium'], 0, '{"category":"rollout"}'::jsonb),
  ('generate_single_input', 'Generate single input', 'One auto-detecting input on Generate.', false, 'hide', ARRAY['free','standard','plus','premium'], 0, '{"category":"rollout"}'::jsonb)
ON CONFLICT (feature_key) DO NOTHING;
