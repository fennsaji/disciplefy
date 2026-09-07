-- "Disciple AI" was a fourth name for the voice conversation feature, living
-- in subscription_plans.marketing_features — so it is what users read on the
-- pricing page while the app, admin and marketing site all say
-- "Talk to Discipler". Being data rather than code, it survived the
-- repository-wide rename.

UPDATE public.subscription_plans
SET marketing_features = (
      SELECT jsonb_agg(replace(feature, 'Disciple AI', 'Talk to Discipler') ORDER BY ord)
      FROM jsonb_array_elements_text(marketing_features) WITH ORDINALITY AS t(feature, ord)
    ),
    updated_at = now()
WHERE marketing_features::text LIKE '%Disciple AI%';
