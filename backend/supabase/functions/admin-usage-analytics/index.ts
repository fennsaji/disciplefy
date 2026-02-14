/**
 * Admin Usage Analytics Endpoint
 * Provides aggregate usage statistics by tier, feature, and date range
 * Admin-only access
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import type { AdminUsageAnalytics, UsageStats } from '../_shared/types/usage-types.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Verify service role authentication
    const authHeader = req.headers.get('Authorization');
    const adminUserId = req.headers.get('x-admin-user-id');

    console.log('[DEBUG] Auth check:', {
      hasAuthHeader: !!authHeader,
      hasUserId: !!adminUserId
    });

    if (!authHeader || !adminUserId) {
      return new Response(JSON.stringify({ error: 'Unauthorized - Missing credentials' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Verify it's the service role key by checking the header format
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const providedKey = authHeader.replace('Bearer ', '');

    if (providedKey !== serviceRoleKey) {
      console.error('[ERROR] Invalid service role key');
      return new Response(JSON.stringify({ error: 'Unauthorized - Invalid credentials' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Create admin client with service role key to verify user is admin
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      serviceRoleKey
    );

    // Verify admin status
    const { data: profile, error: profileError } = await supabaseClient
      .from('user_profiles')
      .select('is_admin')
      .eq('id', adminUserId)
      .single();

    console.log('[DEBUG] Admin verification:', {
      userId: adminUserId,
      isAdmin: profile?.is_admin,
      error: profileError?.message
    });

    if (profileError || !profile?.is_admin) {
      return new Response(
        JSON.stringify({ error: 'Forbidden - Admin access required' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Parse query parameters
    const url = new URL(req.url);
    const startDate = url.searchParams.get('start_date') || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    const endDate = url.searchParams.get('end_date') || new Date().toISOString();
    const tier = url.searchParams.get('tier') || null;
    const feature = url.searchParams.get('feature') || null;

    // Get overall stats
    const { data: overallStats, error: statsError } = await supabaseClient.rpc(
      'get_usage_stats',
      {
        p_start_date: startDate,
        p_end_date: endDate,
        p_tier: tier,
        p_feature_name: feature,
      }
    );

    if (statsError) {
      throw new Error(`Failed to get usage stats: ${statsError.message}`);
    }

    // Get stats by tier
    const tierStats: Record<string, UsageStats> = {};
    const tiers = ['free', 'standard', 'plus', 'premium'];

    for (const t of tiers) {
      const { data: tierData, error: tierError } = await supabaseClient.rpc(
        'get_usage_stats',
        {
          p_start_date: startDate,
          p_end_date: endDate,
          p_tier: t,
          p_feature_name: feature,
        }
      );

      if (!tierError && tierData) {
        tierStats[t] = tierData;
      }
    }

    // Get stats by feature
    const featureStats: Record<string, UsageStats> = {};
    const features = [
      'study_generate',
      'study_followup',
      'voice_conversation',
      'memory_practice',
      'memory_verse_add',
    ];

    for (const f of features) {
      const { data: featureData, error: featureError } = await supabaseClient.rpc(
        'get_usage_stats',
        {
          p_start_date: startDate,
          p_end_date: endDate,
          p_tier: tier,
          p_feature_name: f,
        }
      );

      if (!featureError && featureData) {
        featureStats[f] = featureData;
      }
    }

    // Get daily breakdown
    const { data: dailyData, error: dailyError } = await supabaseClient
      .from('usage_logs')
      .select('created_at, llm_cost_usd, estimated_revenue_inr, profit_margin_inr')
      .gte('created_at', startDate)
      .lte('created_at', endDate);

    if (dailyError) {
      console.error('Error fetching daily data:', dailyError);
    }

    // Group by date
    const byDate: Record<string, { operations: number; cost: number; revenue: number; profit: number }> = {};

    if (dailyData) {
      dailyData.forEach((log) => {
        const date = new Date(log.created_at).toISOString().split('T')[0];
        if (!byDate[date]) {
          byDate[date] = { operations: 0, cost: 0, revenue: 0, profit: 0 };
        }
        byDate[date].operations++;
        byDate[date].cost += log.llm_cost_usd || 0;
        byDate[date].revenue += log.estimated_revenue_inr || 0;
        byDate[date].profit += log.profit_margin_inr || 0;
      });
    }

    // Convert to array and sort by date
    const byDateArray = Object.entries(byDate)
      .map(([date, stats]) => ({ date, ...stats }))
      .sort((a, b) => a.date.localeCompare(b.date));

    // Calculate average cost per operation
    const totalOps = overallStats?.total_operations || 0;
    const totalCost = overallStats?.total_cost_usd || 0;
    const avgCostPerOp = totalOps > 0 ? totalCost / totalOps : 0;

    // Count unique users
    const { count: uniqueUsers } = await supabaseClient
      .from('usage_logs')
      .select('user_id', { count: 'exact', head: true })
      .gte('created_at', startDate)
      .lte('created_at', endDate);

    // Transform daily data to match DailyCost interface
    const dailyCosts = byDateArray.map((day) => ({
      date: day.date,
      total_cost_usd: day.cost,
      operations: day.operations,
      total_tokens: 0, // TODO: Add token tracking to usage_logs
    }));

    // Transform tier stats to match TierBreakdown interface
    const transformedTierStats: Record<string, any> = {};
    Object.entries(tierStats).forEach(([tier, stats]) => {
      transformedTierStats[tier] = {
        operations: stats.total_operations || 0,
        cost_usd: stats.total_cost_usd || 0,
        unique_users: 0, // TODO: Add per-tier user counting
        avg_cost_per_user: 0,
      };
    });

    // Transform feature stats to match FeatureBreakdown interface
    const transformedFeatureStats: Record<string, any> = {};
    Object.entries(featureStats).forEach(([feature, stats]) => {
      transformedFeatureStats[feature] = {
        operations: stats.total_operations || 0,
        cost_usd: stats.total_cost_usd || 0,
        input_tokens: 0, // TODO: Add token tracking
        output_tokens: 0,
        avg_cost_per_operation: stats.avg_cost_usd || 0,
      };
    });

    // Build response matching UsageAnalyticsResponse interface
    const analytics = {
      overview: {
        total_operations: totalOps,
        total_llm_cost_usd: totalCost,
        total_llm_tokens: 0, // TODO: Add token tracking to usage_logs
        avg_cost_per_operation: avgCostPerOp,
        unique_users: uniqueUsers || 0,
      },
      by_tier: transformedTierStats,
      by_feature: transformedFeatureStats,
      by_provider: {}, // TODO: Add provider-level tracking
      by_model: {}, // TODO: Add model-level tracking
      daily_costs: dailyCosts,
    };

    return new Response(JSON.stringify(analytics), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error: unknown) {
    console.error('Admin usage analytics error:', error);
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
