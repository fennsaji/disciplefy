-- Follow-up copy quotes the limits study-followup enforces
-- (study-followup/follow-up-limits.ts): Standard 10, Plus 15, Premium 20.
-- Item 6 (index 5) of each paid plan's list is its follow-up line, as set by
-- 20261006100000_plan_marketing_copy_credits.sql. Re-running gives the same rows.
UPDATE public.subscription_plans p SET
  marketing_features = jsonb_set(p.marketing_features, '{5}', to_jsonb(v.en)),
  marketing_features_i18n = jsonb_set(jsonb_set(p.marketing_features_i18n,
    '{hi,5}', to_jsonb(v.hi)), '{ml,5}', to_jsonb(v.ml)),
  updated_at = NOW()
FROM (VALUES
  ('standard', '10 follow-ups per study', 'हर अध्ययन पर 10 प्रश्न', 'ഓരോ പഠനത്തിനും 10 ചോദ്യം'),
  ('plus',     '15 follow-ups per study', 'हर अध्ययन पर 15 प्रश्न', 'ഓരോ പഠനത്തിനും 15 ചോദ്യം'),
  ('premium',  '20 follow-ups per study', 'हर अध्ययन पर 20 प्रश्न', 'ഓരോ പഠനത്തിനും 20 ചോദ്യം')
) AS v(plan_code, en, hi, ml)
WHERE p.plan_code = v.plan_code
  AND jsonb_array_length(p.marketing_features) > 5
  AND jsonb_array_length(p.marketing_features_i18n->'hi') > 5
  AND jsonb_array_length(p.marketing_features_i18n->'ml') > 5;
