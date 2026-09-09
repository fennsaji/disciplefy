-- A daily fair-use ceiling for the plan whose tokens are unlimited.
--
-- Premium deliberately does not count tokens, which is the point of the plan
-- and also the one place with no bound at all. The monthly cap from
-- 20260909000006 holds the month, but nothing stops a single day: 150 studies
-- could all be made this afternoon, and on Malayalam deep dives that is real
-- money in an hour.
--
-- Ten new studies a day is far above genuine use — a reader gets through one or
-- two — while keeping "unlimited" honest for everyone except the top fraction
-- of a percent. Learning-path studies come from the cache and never count.

UPDATE public.subscription_plans
   SET features = features
     || jsonb_build_object(
          'daily_fresh_studies',
          CASE plan_code
            -- The other plans are already bounded by their daily tokens, so a
            -- second daily limit would only be a second thing to keep in step.
            WHEN 'premium' THEN 10
            ELSE -1
          END
        )
 WHERE plan_code IN ('free', 'standard', 'plus', 'premium');
