-- =====================================================
-- Migration: Fix Supabase Security Lint Errors
-- Date: 2026-03-18
-- Issues addressed:
--   1. policy_exists_rls_disabled on public.user_profiles
--   2. rls_disabled_in_public on public.user_profiles
--   3. rls_disabled_in_public on public.bible_book_config
--   4. security_definer_view on public.subscription_plans_with_pricing
--   5. security_definer_view on public.user_subscriptions
--   6. security_definer_view on public.admin_price_change_history
-- =====================================================

BEGIN;

-- =====================================================
-- FIX 1 & 2: Enable RLS on user_profiles
-- =====================================================
-- Context: RLS was explicitly disabled in 20260119000000_core_schema.sql with the
-- comment "to avoid infinite recursion in admin policies". That admin policy
-- (which queried user_profiles while checking access to user_profiles) has since
-- been removed. The three existing policies — SELECT/INSERT/UPDATE scoped to
-- auth.uid() = id — are correct and safe to enforce. Edge Functions and the admin
-- panel use the service_role key which bypasses RLS entirely, so re-enabling RLS
-- here does not break any server-side access patterns.
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- FIX 3: Enable RLS on bible_book_config + read policy
-- =====================================================
-- Context: bible_book_config is a single-row reference table. The original
-- migration comment said "No RLS needed" because it is read-only and public.
-- Supabase flags any table in the public schema without RLS as a lint error
-- regardless of intent. The correct fix is to enable RLS and grant all
-- authenticated (and anon) users read access, while preventing any user-level
-- writes (only service_role may modify this table).
ALTER TABLE public.bible_book_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bible_book_config_public_read"
  ON public.bible_book_config
  FOR SELECT
  TO authenticated, anon
  USING (true);

CREATE POLICY "bible_book_config_service_role_all"
  ON public.bible_book_config
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- FIX 4: subscription_plans_with_pricing — SECURITY INVOKER
-- =====================================================
-- Context: This view joins subscription_plans and subscription_plan_providers.
-- Both tables have RLS enabled with policies that allow SELECT to authenticated
-- users (read-only plan catalogue). There is no user-scoped data here — it is a
-- public pricing catalogue. Switching to SECURITY INVOKER is safe and correct:
-- the caller's RLS policies already permit SELECT on these tables.
CREATE OR REPLACE VIEW public.subscription_plans_with_pricing
  WITH (security_invoker = true)
AS
SELECT
  sp.id,
  sp.plan_code,
  sp.plan_name,
  sp.tier,
  sp.interval,
  sp.features,
  sp.is_active,
  sp.is_visible,
  sp.description,
  -- Razorpay pricing
  spp_rp.provider_plan_id AS razorpay_plan_id,
  (spp_rp.base_price_minor / 100)::INTEGER AS price_inr,
  -- Google Play pricing
  spp_gp.provider_plan_id AS google_play_sku,
  (spp_gp.base_price_minor / 100)::INTEGER AS price_google_play,
  -- Apple App Store pricing
  spp_ap.provider_plan_id AS apple_product_id,
  (spp_ap.base_price_minor / 100)::INTEGER AS price_apple,
  sp.created_at,
  sp.updated_at
FROM public.subscription_plans sp
LEFT JOIN public.subscription_plan_providers spp_rp
  ON sp.id = spp_rp.plan_id AND spp_rp.provider = 'razorpay'
LEFT JOIN public.subscription_plan_providers spp_gp
  ON sp.id = spp_gp.plan_id AND spp_gp.provider = 'google_play'
LEFT JOIN public.subscription_plan_providers spp_ap
  ON sp.id = spp_ap.plan_id AND spp_ap.provider = 'apple_appstore';

COMMENT ON VIEW public.subscription_plans_with_pricing IS
  'View combining subscription plans with pricing from all providers. '
  'Uses SECURITY INVOKER so the caller''s RLS context applies (plan catalogue '
  'is readable by all authenticated users via existing subscription_plans policies).';

-- =====================================================
-- FIX 5: user_subscriptions — SECURITY INVOKER
-- =====================================================
-- Context: This view joins subscriptions (RLS enabled, "Users can view own
-- subscription" policy: auth.uid() = user_id) with subscription_plans (public
-- read). The view was created without explicit SECURITY DEFINER/INVOKER, which
-- means PostgreSQL defaulted it to SECURITY DEFINER (the view owner's rights).
-- With SECURITY DEFINER the user_id filter on subscriptions is bypassed,
-- meaning any authenticated caller could potentially see all subscriptions.
-- Switching to SECURITY INVOKER restores the intended row-level isolation:
-- each caller only sees their own subscription rows as enforced by the
-- "Users can view own subscription" RLS policy.
CREATE OR REPLACE VIEW public.user_subscriptions
  WITH (security_invoker = true)
AS
SELECT
  s.id,
  s.user_id,
  s.provider,
  s.provider_subscription_id,
  s.plan_id,
  sp.plan_code AS tier,
  s.status,
  s.plan_type,
  s.current_period_start,
  s.current_period_end,
  s.cancel_at_cycle_end,
  s.metadata,
  s.created_at,
  s.updated_at
FROM public.subscriptions s
LEFT JOIN public.subscription_plans sp ON s.plan_id = sp.id;

COMMENT ON VIEW public.user_subscriptions IS
  'Convenience view of subscriptions with tier (plan_code) exposed for Edge Function '
  'queries. Uses SECURITY INVOKER so the subscriptions RLS policy '
  '("Users can view own subscription": auth.uid() = user_id) is enforced per caller. '
  'Edge Functions use service_role which bypasses RLS and can see all rows.';

GRANT SELECT ON public.user_subscriptions TO authenticated, service_role;

-- =====================================================
-- FIX 6: admin_price_change_history — SECURITY INVOKER
-- =====================================================
-- Context: This view joins admin_subscription_price_audit (RLS enabled, admin-only
-- SELECT policy: is_admin = true) with subscription_plans (public read). The view
-- was granted SELECT to all authenticated users, but the underlying table's RLS
-- already limits access to admins only. With SECURITY DEFINER the view owner
-- bypasses the RLS check on admin_subscription_price_audit, effectively allowing
-- any authenticated user to read price audit logs through the view despite the
-- restrictive table-level policy.
-- Switching to SECURITY INVOKER ensures the caller must satisfy the admin RLS
-- policy on admin_subscription_price_audit to read any rows. Non-admin callers
-- will receive an empty result set, which is the correct behaviour.
CREATE OR REPLACE VIEW public.admin_price_change_history
  WITH (security_invoker = true)
AS
SELECT
  a.id,
  a.created_at,
  a.admin_email,
  a.plan_code,
  a.provider,
  a.action,
  CONCAT(a.currency, ' ', ROUND(a.old_price_minor::numeric / 100, 2)) AS old_price_formatted,
  CONCAT(a.currency, ' ', ROUND(a.new_price_minor::numeric / 100, 2)) AS new_price_formatted,
  CONCAT(
    CASE
      WHEN a.price_difference_minor > 0 THEN '+'
      WHEN a.price_difference_minor < 0 THEN '-'
      ELSE ''
    END,
    a.currency, ' ', ROUND(ABS(a.price_difference_minor)::numeric / 100, 2)
  ) AS price_change_formatted,
  a.affected_active_subscriptions,
  a.old_provider_plan_id,
  a.new_provider_plan_id,
  a.notes,
  sp.plan_name
FROM public.admin_subscription_price_audit a
JOIN public.subscription_plans sp ON a.plan_id = sp.id
ORDER BY a.created_at DESC;

COMMENT ON VIEW public.admin_price_change_history IS
  'Formatted view of price changes for admin dashboard display. '
  'Uses SECURITY INVOKER so the admin-only RLS policy on '
  'admin_subscription_price_audit is enforced per caller. '
  'Non-admin callers receive zero rows; service_role has unrestricted access.';

GRANT SELECT ON public.admin_price_change_history TO authenticated;

COMMIT;
