-- Explicit service_role grants for tables that relied on Supabase's default
-- public-schema grants.
--
-- New local stacks (and existing hosted projects from 2026-10-30) no longer
-- give service_role SELECT/INSERT/UPDATE/DELETE on new public tables by
-- default. 20260513000001_explicit_data_api_grants.sql added the anon and
-- authenticated grants for these tables but not service_role, so every Edge
-- Function reading them with the service-role client fails with
-- "permission denied" (locally today: get-bible-books, subscription-pricing).
-- GRANT is idempotent — a no-op where the privilege already exists.

GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.achievements,
  public.bible_book_config,
  public.blog_posts,
  public.content_pipeline_progress,
  public.daily_verses_cache,
  public.feature_flags,
  public.learning_path_topic_titles,
  public.promotional_campaigns,
  public.razorpay_webhook_events,
  public.recommended_topics_translations,
  public.subscription_config,
  public.subscription_plan_providers,
  public.subscription_plans,
  public.suggested_verse_translations,
  public.suggested_verses,
  public.token_packages,
  public.token_pricing_config,
  public.voice_preferences
TO service_role;
