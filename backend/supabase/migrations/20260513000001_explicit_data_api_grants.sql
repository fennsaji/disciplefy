-- =====================================================
-- Migration: Explicit Data API Grants for All Tables
-- Date: 2026-05-13
-- Context:
--   Starting May 30 2026 (new projects) and October 30 2026 (existing projects),
--   Supabase will no longer expose public-schema tables to the Data API by default.
--   PostgREST / supabase-js / GraphQL will require explicit GRANTs per role.
--
--   This migration adds explicit grants matching each table's existing RLS policies
--   so that our Data API access is preserved after the change takes effect.
--   GRANTs are idempotent — re-granting an existing privilege is a no-op.
-- =====================================================

BEGIN;

-- =============================================================================
-- CATEGORY 1: anon + authenticated SELECT (public reference / config tables)
-- =============================================================================
-- These tables have RLS policies allowing unauthenticated read access.

GRANT SELECT ON public.daily_verses_cache TO anon, authenticated;
GRANT SELECT ON public.recommended_topics TO anon, authenticated;
GRANT SELECT ON public.recommended_topics_translations TO anon, authenticated;
GRANT SELECT ON public.system_config TO anon, authenticated;
GRANT SELECT ON public.bible_book_config TO anon, authenticated;
GRANT SELECT ON public.subscription_config TO anon, authenticated;
GRANT SELECT ON public.feature_flags TO anon, authenticated;
GRANT SELECT ON public.blog_posts TO anon, authenticated;
GRANT SELECT ON public.subscription_plans TO anon, authenticated;
GRANT SELECT ON public.subscription_plan_providers TO anon, authenticated;
GRANT SELECT ON public.promotional_campaigns TO anon, authenticated;
GRANT SELECT ON public.suggested_verses TO anon, authenticated;
GRANT SELECT ON public.suggested_verse_translations TO anon, authenticated;
GRANT SELECT ON public.achievements TO anon, authenticated;
GRANT SELECT ON public.memory_challenges TO anon, authenticated;
GRANT SELECT ON public.learning_paths TO anon, authenticated;
GRANT SELECT ON public.learning_path_topics TO anon, authenticated;
GRANT SELECT ON public.learning_path_translations TO anon, authenticated;
GRANT SELECT ON public.rate_limit_rules TO anon, authenticated;

-- =============================================================================
-- CATEGORY 2: anon CRUD (anonymous user session tables)
-- =============================================================================
-- These tables allow anonymous users to create/manage their own session data.

GRANT SELECT, INSERT, UPDATE ON public.anonymous_sessions TO anon;
GRANT SELECT ON public.study_guides TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.study_guide_conversations TO anon;
GRANT SELECT, INSERT, DELETE ON public.conversation_messages TO anon;
GRANT SELECT, INSERT, UPDATE ON public.oauth_states TO anon;
GRANT SELECT, INSERT ON public.otp_requests TO anon;

-- =============================================================================
-- CATEGORY 3: authenticated CRUD (user-owned data tables)
-- =============================================================================
-- These tables have RLS policies scoped to auth.uid() = user_id.

-- User profile & preferences
GRANT SELECT, INSERT, UPDATE ON public.user_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_preferences TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_personalization TO authenticated;

-- Study guides & conversations
GRANT SELECT ON public.study_guides TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_study_guides TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.study_reflections TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.recommended_guide_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.study_guide_conversations TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.conversation_messages TO authenticated;
GRANT SELECT, INSERT ON public.feedback TO authenticated;

-- Subscriptions & payments (mostly read-only for users)
GRANT SELECT ON public.subscriptions TO authenticated;
GRANT SELECT ON public.subscription_invoices TO authenticated;
GRANT SELECT ON public.subscription_history TO authenticated;
GRANT SELECT ON public.promotional_redemptions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.pending_token_purchases TO authenticated;
GRANT SELECT ON public.purchase_history TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.saved_payment_methods TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.payment_preferences TO authenticated;
GRANT SELECT, INSERT ON public.purchase_issue_reports TO authenticated;
GRANT SELECT ON public.iap_receipts TO authenticated;
GRANT SELECT ON public.iap_verification_logs TO authenticated;
GRANT SELECT ON public.token_usage_history TO authenticated;

-- Memory verse system
GRANT SELECT, INSERT, UPDATE, DELETE ON public.memory_verses TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.memory_verse_collections TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.memory_verse_collection_items TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.memory_verse_mastery TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.memory_verse_streaks TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.memory_practice_modes TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.memory_daily_goals TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.review_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.review_history TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.daily_unlocked_modes TO authenticated;

-- Streaks & gamification
GRANT SELECT, INSERT, UPDATE ON public.daily_verse_streaks TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_study_streaks TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_achievements TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_challenge_progress TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_topic_progress TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_learning_path_progress TO authenticated;

-- Notifications
GRANT SELECT ON public.notification_logs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_notification_tokens TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_notification_preferences TO authenticated;

-- Analytics (insert-only for users)
GRANT INSERT ON public.analytics_events TO authenticated;

-- Voice
GRANT SELECT, INSERT, UPDATE, DELETE ON public.voice_conversations TO authenticated;
GRANT SELECT, INSERT ON public.voice_conversation_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.voice_usage_tracking TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.voice_preferences TO authenticated;

-- Fellowships (read-only for users; writes via service_role)
GRANT SELECT ON public.fellowships TO authenticated;

-- Usage logs (read-only for users)
GRANT SELECT ON public.usage_logs TO authenticated;

-- =============================================================================
-- CATEGORY 4: service_role ALL (internal / admin-only tables)
-- =============================================================================
-- These tables are only accessed by Edge Functions using the service_role key.
-- service_role bypasses RLS, but still needs schema-level GRANT after the change.

GRANT ALL ON public.user_tokens TO service_role;
GRANT ALL ON public.study_guides TO service_role;
GRANT ALL ON public.study_guides_in_progress TO service_role;
GRANT ALL ON public.cron_config TO service_role;
GRANT ALL ON public.iap_config TO service_role;
GRANT ALL ON public.iap_webhook_events TO service_role;
GRANT ALL ON public.receipt_counters TO service_role;
GRANT ALL ON public.llm_api_costs TO service_role;
GRANT ALL ON public.llm_security_events TO service_role;
GRANT ALL ON public.admin_logs TO service_role;
GRANT ALL ON public.admin_actions TO service_role;
GRANT ALL ON public.admin_subscription_price_audit TO service_role;
GRANT ALL ON public.usage_alerts TO service_role;
GRANT ALL ON public.rate_limit_rules TO service_role;
GRANT ALL ON public.fellowship_members TO service_role;
GRANT ALL ON public.fellowship_posts TO service_role;
GRANT ALL ON public.fellowship_comments TO service_role;
GRANT ALL ON public.fellowship_reactions TO service_role;
GRANT ALL ON public.fellowship_invites TO service_role;
GRANT ALL ON public.fellowship_mutes TO service_role;
GRANT ALL ON public.fellowship_reports TO service_role;
GRANT ALL ON public.fellowship_study TO service_role;
GRANT ALL ON public.fellowship_notification_queue TO service_role;
GRANT ALL ON public.fellowship_meetings TO service_role;
GRANT ALL ON public.meeting_reminders TO service_role;
GRANT ALL ON public.fellowships TO service_role;
GRANT ALL ON public.anonymous_sessions TO service_role;
GRANT ALL ON public.analytics_events TO service_role;
GRANT ALL ON public.notification_logs TO service_role;
GRANT ALL ON public.subscriptions TO service_role;
GRANT ALL ON public.subscription_invoices TO service_role;
GRANT ALL ON public.subscription_history TO service_role;
GRANT ALL ON public.promotional_redemptions TO service_role;
GRANT ALL ON public.purchase_history TO service_role;
GRANT ALL ON public.iap_receipts TO service_role;
GRANT ALL ON public.iap_verification_logs TO service_role;
GRANT ALL ON public.token_usage_history TO service_role;
GRANT ALL ON public.feedback TO service_role;
GRANT ALL ON public.memory_verses TO service_role;
GRANT ALL ON public.memory_verse_mastery TO service_role;
GRANT ALL ON public.memory_verse_streaks TO service_role;
GRANT ALL ON public.user_profiles TO service_role;
GRANT ALL ON public.user_study_guides TO service_role;
GRANT ALL ON public.study_reflections TO service_role;
GRANT ALL ON public.recommended_guide_sessions TO service_role;
GRANT ALL ON public.study_guide_conversations TO service_role;
GRANT ALL ON public.conversation_messages TO service_role;
GRANT ALL ON public.oauth_states TO service_role;
GRANT ALL ON public.otp_requests TO service_role;
GRANT ALL ON public.user_tokens TO service_role;
GRANT ALL ON public.voice_conversations TO service_role;
GRANT ALL ON public.voice_conversation_messages TO service_role;
GRANT ALL ON public.voice_usage_tracking TO service_role;
GRANT ALL ON public.daily_verse_streaks TO service_role;
GRANT ALL ON public.user_study_streaks TO service_role;
GRANT ALL ON public.user_achievements TO service_role;
GRANT ALL ON public.user_challenge_progress TO service_role;
GRANT ALL ON public.user_topic_progress TO service_role;
GRANT ALL ON public.user_learning_path_progress TO service_role;
GRANT ALL ON public.pending_token_purchases TO service_role;
GRANT ALL ON public.daily_unlocked_modes TO service_role;
GRANT ALL ON public.review_sessions TO service_role;
GRANT ALL ON public.review_history TO service_role;
GRANT ALL ON public.memory_practice_modes TO service_role;
GRANT ALL ON public.memory_daily_goals TO service_role;
GRANT ALL ON public.memory_verse_collections TO service_role;
GRANT ALL ON public.memory_verse_collection_items TO service_role;
GRANT ALL ON public.memory_challenges TO service_role;
GRANT ALL ON public.user_notification_tokens TO service_role;
GRANT ALL ON public.user_notification_preferences TO service_role;
GRANT ALL ON public.user_preferences TO service_role;
GRANT ALL ON public.user_personalization TO service_role;
GRANT ALL ON public.saved_payment_methods TO service_role;
GRANT ALL ON public.payment_preferences TO service_role;
GRANT ALL ON public.purchase_issue_reports TO service_role;
GRANT ALL ON public.usage_logs TO service_role;

-- =============================================================================
-- CATEGORY 5: Admin tables — authenticated SELECT for admin users
-- =============================================================================
-- Admin access is enforced by RLS policies checking is_admin flag.
-- The GRANT just allows the role to reach the table; RLS filters the rows.

GRANT SELECT ON public.admin_actions TO authenticated;
GRANT SELECT ON public.admin_logs TO authenticated;
GRANT SELECT ON public.admin_subscription_price_audit TO authenticated;
GRANT SELECT ON public.llm_api_costs TO authenticated;
GRANT SELECT ON public.llm_security_events TO authenticated;
GRANT SELECT ON public.usage_alerts TO authenticated;

-- =============================================================================
-- VIEWS — grant SELECT so PostgREST can serve them
-- =============================================================================

GRANT SELECT ON public.subscription_plans_with_pricing TO anon, authenticated, service_role;
GRANT SELECT ON public.user_subscriptions TO authenticated, service_role;
GRANT SELECT ON public.admin_price_change_history TO authenticated, service_role;

COMMIT;
