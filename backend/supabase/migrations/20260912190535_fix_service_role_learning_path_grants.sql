-- admin-learning-paths Edge Function (uses the service_role key) was failing with
-- "permission denied for table learning_paths" — these tables predate the
-- 20260513000001_explicit_data_api_grants convention and never received the
-- service_role grants that every other admin-managed table has.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.learning_paths TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.learning_path_topics TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.learning_path_translations TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.recommended_topics TO service_role;
