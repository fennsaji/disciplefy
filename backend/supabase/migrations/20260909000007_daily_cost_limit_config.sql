-- The day's spending ceiling belongs in config, not in a deploy.
--
-- It has to move with growth: $15 is right for a few hundred users and wrong
-- for ten thousand. Putting it in system_config means it can be raised from
-- the admin dashboard the moment traffic needs it, rather than waiting on a
-- release.

INSERT INTO public.system_config (key, value, description, is_active, metadata)
VALUES (
  'daily_cost_limit_usd',
  '15',
  'Dollars the app may spend with the model providers in a day before study generation stops. Learning-path studies keep working, since they are served from the cache. Raise this as traffic grows.',
  TRUE,
  jsonb_build_object('unit', 'usd', 'min', 1, 'editable_in_admin', true)
)
ON CONFLICT (key) DO UPDATE
  SET description = EXCLUDED.description,
      metadata    = EXCLUDED.metadata,
      is_active   = TRUE;
