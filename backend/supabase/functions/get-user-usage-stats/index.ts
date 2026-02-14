import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/utils/cors.ts';
import { DEFAULT_PLAN_CONFIGS, type UserPlan } from '../_shared/types/token-types.ts';

/**
 * Get User Usage Stats Edge Function
 *
 * Returns comprehensive usage statistics for the authenticated user:
 * - Daily token consumption (today's usage vs daily limit)
 * - Study streak (consecutive days)
 * - Current plan details
 * - Usage percentage and thresholds
 *
 * Used for:
 * - Usage meter display on home screen
 * - Soft paywall threshold detection (30%, 50%, 80%)
 * - User engagement tracking
 *
 * Daily Limits:
 * - Limits are defined in DEFAULT_PLAN_CONFIGS (token-types.ts)
 * - Free, Standard, Plus plans have daily limits
 * - Premium plan has unlimited access
 */

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Authenticate user
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Authentication required' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const jwt = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid authentication' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get today's token usage from token_usage_history
    // We need to SUM all daily_tokens_used for today (multiple operations)
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const startOfDayISO = startOfDay.toISOString();

    const { data: usageRecords, error: usageError } = await supabase
      .from('token_usage_history')
      .select('daily_tokens_used')
      .eq('user_id', user.id)
      .gte('created_at', startOfDayISO);

    if (usageError) {
      console.error('[get-user-usage-stats] Error fetching token usage:', usageError);
    }

    // Aggregate total daily tokens consumed today
    const tokensUsedToday = usageRecords?.reduce(
      (sum, record) => sum + (record.daily_tokens_used || 0),
      0
    ) || 0;

    // Get study streak using the calculate_study_streak function
    const { data: streakData, error: streakError } = await supabase.rpc(
      'calculate_study_streak',
      { p_user_id: user.id }
    );

    if (streakError) {
      console.error('[get-user-usage-stats] Error calculating streak:', streakError);
    }

    const streakDays = streakData || 0;

    /**
     * Plan priority ranking (highest to lowest)
     * Used to merge subscription and user_tokens plans
     */
    const PLAN_PRIORITY: Record<string, number> = {
      'premium': 4,
      'plus': 3,
      'standard': 2,
      'free': 1,
    };

    /**
     * Returns the higher priority plan between two plans
     */
    const getHigherPlan = (plan1: string | null | undefined, plan2: string | null | undefined): string => {
      const p1 = plan1 || 'free';
      const p2 = plan2 || 'free';
      const priority1 = PLAN_PRIORITY[p1] ?? 1;
      const priority2 = PLAN_PRIORITY[p2] ?? 1;
      return priority1 >= priority2 ? p1 : p2;
    };

    // MERGE LOGIC: Query BOTH subscription and user_tokens tables
    // Use the highest plan found between them (premium > plus > standard > free)

    // 1. Get subscription plan from subscriptions table
    const { data: subscription, error: subError } = await supabase
      .from('subscriptions')
      .select('subscription_plan, status')
      .eq('user_id', user.id)
      .in('status', ['active', 'authenticated', 'pending_cancellation'])
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (subError) {
      console.error('[get-user-usage-stats] Error fetching subscription:', subError);
    }

    const subscriptionPlan = subscription?.subscription_plan;

    // 2. Get user plan from user_tokens table (check ALL rows for this user)
    const { data: userTokens, error: tokensError } = await supabase
      .from('user_tokens')
      .select('user_plan')
      .eq('identifier', user.id)
      .order('user_plan', { ascending: false }); // Order by plan (premium first)

    if (tokensError) {
      console.error('[get-user-usage-stats] Error fetching user_tokens:', tokensError);
    }

    // Get the highest plan from user_tokens (could have multiple rows)
    let userTokensPlan = 'free';
    if (userTokens && userTokens.length > 0) {
      // Find the highest priority plan among all user_tokens rows
      userTokensPlan = userTokens.reduce((highest, row) =>
        getHigherPlan(highest, row.user_plan), 'free');
    }

    // 3. MERGE: Use the highest plan between subscriptions and user_tokens
    const currentPlan = getHigherPlan(subscriptionPlan, userTokensPlan);

    console.log('[get-user-usage-stats] Plan determination:', {
      subscription_plan: subscriptionPlan || 'none',
      user_tokens_plan: userTokensPlan,
      merged_plan: currentPlan,
      source: subscriptionPlan === currentPlan ? 'subscriptions' :
              userTokensPlan === currentPlan ? 'user_tokens' : 'default',
    });

    // Get daily limit from centralized config
    const planConfig = DEFAULT_PLAN_CONFIGS[currentPlan as UserPlan];
    const dailyLimit = planConfig?.dailyLimit ?? DEFAULT_PLAN_CONFIGS.free.dailyLimit;
    const isUnlimited = dailyLimit === -1;
    const percentage = isUnlimited ? 0 : Math.round((tokensUsedToday / dailyLimit) * 100);

    // Determine threshold state (for soft paywall triggers)
    let thresholdState: 'normal' | 'warning' | 'critical' = 'normal';
    if (percentage >= 80) {
      thresholdState = 'critical';
    } else if (percentage >= 50) {
      thresholdState = 'warning';
    }

    const response = {
      success: true,
      data: {
        tokens_used: tokensUsedToday,
        tokens_total: dailyLimit,
        tokens_remaining: isUnlimited ? -1 : Math.max(0, dailyLimit - tokensUsedToday),
        percentage,
        streak_days: streakDays,
        current_plan: currentPlan,
        is_unlimited: isUnlimited,
        threshold_state: thresholdState,
        month_year: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`,
      },
    };

    console.log('[get-user-usage-stats] Success:', {
      user_id: user.id,
      plan: currentPlan,
      subscription_plan: subscriptionPlan || 'none',
      user_tokens_plan: userTokensPlan,
      usage: `${tokensUsedToday}/${dailyLimit} (today)`,
      streak: streakDays,
      percentage: `${percentage}%`,
      is_unlimited: isUnlimited,
    });

    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error: unknown) {
    console.error('[get-user-usage-stats] Unexpected error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Internal server error';
    return new Response(
      JSON.stringify({ error: errorMessage }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
