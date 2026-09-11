-- Monthly ceiling on studies that actually call the model, plus a daily
-- sermon cap.
--
-- Daily tokens control how fast a user goes; they do nothing about how much we
-- spend over a month. Measured 9 September 2026, a standard guide costs
-- $0.052 in English and $0.150 in Malayalam, and Standard is free for its
-- first year, so a handful of heavy users can cost more than every paying user
-- brings in. Cached and learning-path studies are free to serve and never
-- count against these limits.
--
-- Sermon is four Sonnet passes, the most expensive thing the app can make, and
-- it sits on the plan whose tokens are unlimited. Two a day is far above real
-- use — a preacher prepares one or two a week — and stops a runaway.

UPDATE public.subscription_plans
   SET features = features
     || jsonb_build_object(
          'monthly_fresh_studies',
          CASE plan_code
            WHEN 'free'     THEN 10
            -- Standard is free for the first year, so it carries the bill.
            -- Raise this to 30 when it starts charging.
            WHEN 'standard' THEN 20
            WHEN 'plus'     THEN 60
            WHEN 'premium'  THEN 150
            ELSE 20
          END,
          'daily_sermons',
          CASE plan_code WHEN 'premium' THEN 2 ELSE 0 END
        )
 WHERE plan_code IN ('free', 'standard', 'plus', 'premium');

-- Studies a user generated fresh (not served from cache) since a given time.
-- usage_logs records operation_type 'create' for a generation and 'read' for a
-- cache hit, so counting creates counts exactly what cost money.
CREATE OR REPLACE FUNCTION public.count_fresh_studies(
  p_user_id    UUID,
  p_since      TIMESTAMPTZ,
  p_study_mode TEXT DEFAULT NULL
)
RETURNS INT
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COUNT(*)::INT
    FROM usage_logs
   WHERE user_id = p_user_id
     AND feature_name = 'study_generate'
     AND operation_type = 'create'
     AND created_at >= p_since
     AND (p_study_mode IS NULL OR request_metadata->>'study_mode' = p_study_mode);
$$;

GRANT EXECUTE ON FUNCTION public.count_fresh_studies(UUID, TIMESTAMPTZ, TEXT) TO service_role;
