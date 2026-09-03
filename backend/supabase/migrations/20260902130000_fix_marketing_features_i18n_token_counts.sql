-- =====================================================
-- Migration: Fix localized marketing features token counts (2026-09-02)
-- =====================================================
-- 20260319000004_update_token_economy.sql raised the daily token limits
-- (free 3→15, standard 20→40, plus 50→60) and 20260319000005 updated the
-- English `marketing_features` strings to match — but neither touched
-- `marketing_features_i18n`, so the Hindi and Malayalam pricing pages still
-- advertise the pre-March limits (free "8", standard "20", plus "50").
--
-- Hindi and Malayalam users are shown lower token counts than they actually
-- receive, on the screen they use to decide whether to pay.
--
-- Depends on: 20260220000001_add_marketing_features_i18n.sql
-- =====================================================

BEGIN;

-- Rewrites one language array of a plan, replacing `old_text` with `new_text`.
CREATE OR REPLACE FUNCTION pg_temp.replace_i18n_feature(
  i18n JSONB,
  lang TEXT,
  old_text TEXT,
  new_text TEXT
) RETURNS JSONB AS $$
  SELECT CASE
    WHEN i18n IS NULL OR i18n -> lang IS NULL THEN i18n
    ELSE jsonb_set(
      i18n,
      ARRAY[lang],
      (
        SELECT jsonb_agg(
          CASE WHEN elem #>> '{}' = old_text THEN to_jsonb(new_text) ELSE elem END
          ORDER BY ord
        )
        FROM jsonb_array_elements(i18n -> lang) WITH ORDINALITY AS t(elem, ord)
      )
    )
  END;
$$ LANGUAGE sql IMMUTABLE;

-- Free: 8 → 15
UPDATE subscription_plans
SET marketing_features_i18n = pg_temp.replace_i18n_feature(
      pg_temp.replace_i18n_feature(
        marketing_features_i18n, 'hi', '8 अध्ययन टोकन/दिन', '15 अध्ययन टोकन/दिन'),
      'ml', 'ദിവസം 8 സ്റ്റഡി ടോക്കൺ', 'ദിവസം 15 സ്റ്റഡി ടോക്കൺ')
WHERE plan_code = 'free';

-- Standard: 20 → 40
UPDATE subscription_plans
SET marketing_features_i18n = pg_temp.replace_i18n_feature(
      pg_temp.replace_i18n_feature(
        marketing_features_i18n, 'hi', '20 अध्ययन टोकन/दिन', '40 अध्ययन टोकन/दिन'),
      'ml', 'ദിവസം 20 സ്റ്റഡി ടോക്കൺ', 'ദിവസം 40 സ്റ്റഡി ടോക്കൺ')
WHERE plan_code = 'standard';

-- Plus: 50 → 60
UPDATE subscription_plans
SET marketing_features_i18n = pg_temp.replace_i18n_feature(
      pg_temp.replace_i18n_feature(
        marketing_features_i18n, 'hi', '50 अध्ययन टोकन/दिन', '60 अध्ययन टोकन/दिन'),
      'ml', 'ദിവസം 50 സ്റ്റഡി ടോക്കൺ', 'ദിവസം 60 സ്റ്റഡി ടോക്കൺ')
WHERE plan_code = 'plus';

COMMIT;
