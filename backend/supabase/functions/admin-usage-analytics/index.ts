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

    // Parse request body (POST)
    const body = await req.json().catch(() => ({}));
    const startDate = body.start_date || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    const endDate = body.end_date || new Date().toISOString();
    const tier = body.tier || null;
    const feature = body.feature || null;

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
      'daily_verse',
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

    // Get language breakdown
    const { data: languageData, error: languageError } = await supabaseClient.rpc(
      'get_language_breakdown',
      { p_start_date: startDate, p_end_date: endDate }
    );

    if (languageError) {
      console.error('Error fetching language breakdown:', languageError);
    }

    const transformedLanguageStats: Record<string, any> = {};
    if (languageData) {
      (languageData as any[]).forEach((row) => {
        transformedLanguageStats[row.language] = {
          operations: Number(row.operations) || 0,
          cost_usd: Number(row.cost_usd) || 0,
          avg_cost_per_operation: Number(row.avg_cost_per_operation) || 0,
          input_tokens: Number(row.input_tokens) || 0,
          output_tokens: Number(row.output_tokens) || 0,
        };
      });
    }

    // Get study mode breakdown
    const { data: studyModeData, error: studyModeError } = await supabaseClient.rpc(
      'get_study_mode_breakdown',
      { p_start_date: startDate, p_end_date: endDate }
    );

    if (studyModeError) {
      console.error('Error fetching study mode breakdown:', studyModeError);
    }

    const transformedStudyModeStats: Record<string, any> = {};
    if (studyModeData) {
      (studyModeData as any[]).forEach((row) => {
        transformedStudyModeStats[row.study_mode] = {
          operations: Number(row.operations) || 0,
          cost_usd: Number(row.cost_usd) || 0,
          avg_cost_per_operation: Number(row.avg_cost_per_operation) || 0,
          input_tokens: Number(row.input_tokens) || 0,
          output_tokens: Number(row.output_tokens) || 0,
        };
      });
    }

    // Get language × study mode cross-breakdown
    const { data: crossData, error: crossError } = await supabaseClient.rpc(
      'get_language_study_mode_breakdown',
      { p_start_date: startDate, p_end_date: endDate }
    );

    if (crossError) {
      console.error('Error fetching cross breakdown:', crossError);
    }

    const transformedCrossBreakdown: any[] = [];
    if (crossData) {
      (crossData as any[]).forEach((row) => {
        transformedCrossBreakdown.push({
          language: row.language,
          study_mode: row.study_mode,
          operations: Number(row.operations) || 0,
          cost_usd: Number(row.cost_usd) || 0,
          avg_cost_per_operation: Number(row.avg_cost_per_operation) || 0,
        });
      });
    }

    // Get provider breakdown
    const { data: providerData, error: providerError } = await supabaseClient
      .from('usage_logs')
      .select('llm_provider, llm_cost_usd, llm_input_tokens, llm_output_tokens')
      .gte('created_at', startDate)
      .lte('created_at', endDate)
      .not('llm_provider', 'is', null);

    if (providerError) {
      console.error('Error fetching provider breakdown:', providerError);
    }

    const transformedProviderStats: Record<string, any> = {};
    if (providerData) {
      (providerData as any[]).forEach((row) => {
        const key = row.llm_provider;
        if (!transformedProviderStats[key]) {
          transformedProviderStats[key] = { operations: 0, cost_usd: 0, input_tokens: 0, output_tokens: 0, avg_cost_per_operation: 0 };
        }
        transformedProviderStats[key].operations += 1;
        transformedProviderStats[key].cost_usd += Number(row.llm_cost_usd) || 0;
        transformedProviderStats[key].input_tokens += Number(row.llm_input_tokens) || 0;
        transformedProviderStats[key].output_tokens += Number(row.llm_output_tokens) || 0;
      });
      Object.values(transformedProviderStats).forEach((v: any) => {
        v.avg_cost_per_operation = v.operations > 0 ? v.cost_usd / v.operations : 0;
      });
    }

    // Get model breakdown
    const { data: modelData, error: modelError } = await supabaseClient
      .from('usage_logs')
      .select('llm_model, llm_provider, llm_cost_usd, llm_input_tokens, llm_output_tokens')
      .gte('created_at', startDate)
      .lte('created_at', endDate)
      .not('llm_model', 'is', null);

    if (modelError) {
      console.error('Error fetching model breakdown:', modelError);
    }

    const transformedModelStats: Record<string, any> = {};
    if (modelData) {
      (modelData as any[]).forEach((row) => {
        const key = row.llm_model;
        if (!transformedModelStats[key]) {
          transformedModelStats[key] = { operations: 0, cost_usd: 0, input_tokens: 0, output_tokens: 0, provider: row.llm_provider };
        }
        transformedModelStats[key].operations += 1;
        transformedModelStats[key].cost_usd += Number(row.llm_cost_usd) || 0;
        transformedModelStats[key].input_tokens += Number(row.llm_input_tokens) || 0;
        transformedModelStats[key].output_tokens += Number(row.llm_output_tokens) || 0;
      });
    }

    // Get daily breakdown (also used for total token sum)
    const { data: dailyData, error: dailyError } = await supabaseClient
      .from('usage_logs')
      .select('created_at, llm_cost_usd, llm_input_tokens, llm_output_tokens, estimated_revenue_inr, profit_margin_inr')
      .gte('created_at', startDate)
      .lte('created_at', endDate);

    if (dailyError) {
      console.error('Error fetching daily data:', dailyError);
    }

    // Group by date
    const byDate: Record<string, { operations: number; cost: number; revenue: number; profit: number }> = {};

    let totalTokens = 0;
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
        totalTokens += (log.llm_input_tokens || 0) + (log.llm_output_tokens || 0);
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

    // Count distinct users via the RPC result (COUNT(DISTINCT user_id))
    const uniqueUsers: number = overallStats?.unique_users ?? 0;

    // Transform daily data to match DailyCost interface
    const dailyCosts = byDateArray.map((day) => ({
      date: day.date,
      total_cost_usd: day.cost,
      operations: day.operations,
      total_tokens: 0, // daily breakdown doesn't track tokens per-day yet
    }));

    // Transform tier stats to match TierBreakdown interface
    const transformedTierStats: Record<string, any> = {};
    Object.entries(tierStats).forEach(([tier, stats]) => {
      const tierUsers = stats.unique_users || 0;
      const tierCost = stats.total_cost_usd || 0;
      transformedTierStats[tier] = {
        operations: stats.total_operations || 0,
        cost_usd: tierCost,
        unique_users: tierUsers,
        avg_cost_per_user: tierUsers > 0 ? tierCost / tierUsers : 0,
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
        total_llm_tokens: totalTokens,
        avg_cost_per_operation: avgCostPerOp,
        unique_users: uniqueUsers,
      },
      by_tier: transformedTierStats,
      by_feature: transformedFeatureStats,
      by_provider: transformedProviderStats,
      by_model: transformedModelStats,
      daily_costs: dailyCosts,
      by_language: transformedLanguageStats,
      by_study_mode: transformedStudyModeStats,
      by_language_x_study_mode: transformedCrossBreakdown,
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
