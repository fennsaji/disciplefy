/**
 * Admin Real-Time Stats Endpoint
 * Provides live dashboard metrics (last 24 hours) and current active users
 * Admin-only access
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import type { AdminRealTimeStats } from '../_shared/types/usage-types.ts';

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
    // Verify authentication
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    );

    const {
      data: { user },
      error: authError,
    } = await supabaseClient.auth.getUser();

    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Verify admin status
    const { data: profile, error: profileError } = await supabaseClient
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single();

    if (profileError || !profile?.is_admin) {
      return new Response(
        JSON.stringify({ error: 'Forbidden - Admin access required' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const now = new Date();
    const last24h = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const last5min = new Date(now.getTime() - 5 * 60 * 1000);

    // Get last 24h stats
    const { data: last24hStats, error: statsError } = await supabaseClient.rpc(
      'get_usage_stats',
      {
        p_start_date: last24h.toISOString(),
        p_end_date: now.toISOString(),
        p_tier: null,
        p_feature_name: null,
      }
    );

    if (statsError) {
      throw new Error(`Failed to get 24h stats: ${statsError.message}`);
    }

    // Get active users (logged activity in last 5 minutes)
    const { data: recentActivity, error: activityError } = await supabaseClient
      .from('usage_logs')
      .select('user_id')
      .gte('created_at', last5min.toISOString());

    if (activityError) {
      console.error('Error fetching recent activity:', activityError);
    }

    const currentActiveUsers = new Set((recentActivity || []).map(log => log.user_id)).size;

    // Get rate limit violations (last 24h)
    const { data: violations, error: violationsError } = await supabaseClient
      .from('usage_logs')
      .select('id, response_metadata')
      .gte('created_at', last24h.toISOString());

    if (violationsError) {
      console.error('Error fetching violations:', violationsError);
    }

    const rateLimitViolations = (violations || []).filter(
      (log) => log.response_metadata?.rate_limit_exceeded === true
    ).length;

    // Calculate error rate (last 24h)
    const { data: errorLogs, error: errorLogsError } = await supabaseClient
      .from('usage_logs')
      .select('id, response_metadata')
      .gte('created_at', last24h.toISOString());

    if (errorLogsError) {
      console.error('Error fetching error logs:', errorLogsError);
    }

    const totalOperations = (errorLogs || []).length;
    const failedOperations = (errorLogs || []).filter(
      (log) => log.response_metadata?.success === false
    ).length;
    const errorRate = totalOperations > 0 ? failedOperations / totalOperations : 0;

    // Get hourly breakdown for the last 24 hours
    const { data: hourlyData, error: hourlyError } = await supabaseClient
      .from('usage_logs')
      .select('created_at, llm_cost_usd, estimated_revenue_inr, profit_margin_inr')
      .gte('created_at', last24h.toISOString())
      .order('created_at', { ascending: true });

    if (hourlyError) {
      console.error('Error fetching hourly data:', hourlyError);
    }

    // Group by hour
    const hourlyBreakdown: Record<string, { operations: number; cost: number; revenue: number; profit: number }> = {};

    (hourlyData || []).forEach((log) => {
      const hour = new Date(log.created_at).toISOString().substring(0, 13); // YYYY-MM-DDTHH
      if (!hourlyBreakdown[hour]) {
        hourlyBreakdown[hour] = { operations: 0, cost: 0, revenue: 0, profit: 0 };
      }
      hourlyBreakdown[hour].operations++;
      hourlyBreakdown[hour].cost += log.llm_cost_usd || 0;
      hourlyBreakdown[hour].revenue += log.estimated_revenue_inr || 0;
      hourlyBreakdown[hour].profit += log.profit_margin_inr || 0;
    });

    // Convert to array
    const hourlyArray = Object.entries(hourlyBreakdown)
      .map(([hour, stats]) => ({ hour, ...stats }))
      .sort((a, b) => a.hour.localeCompare(b.hour));

    // Detect anomalies (cost spikes, usage spikes)
    const { data: anomalies, error: anomaliesError } = await supabaseClient.rpc(
      'detect_usage_anomalies',
      { p_threshold_multiplier: 5.0 }
    );

    if (anomaliesError) {
      console.error('Error detecting anomalies:', anomaliesError);
    }

    const activeAnomalies = (anomalies || []).length;

    // Build real-time stats response
    const stats: AdminRealTimeStats = {
      last_24h: {
        operations: last24hStats?.total_operations || 0,
        active_users: last24hStats?.unique_users || 0,
        cost_usd: last24hStats?.total_cost_usd || 0,
        revenue_inr: last24hStats?.total_revenue_inr || 0,
        profit_margin_inr: last24hStats?.total_profit_margin_inr || 0,
      },
      current_active_users: currentActiveUsers,
      rate_limit_violations: rateLimitViolations,
      error_rate: parseFloat(errorRate.toFixed(4)),
    };

    const response = {
      ...stats,
      hourly_breakdown: hourlyArray,
      active_anomalies: activeAnomalies,
      anomaly_details: anomalies || [],
      timestamp: now.toISOString(),
    };

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error: unknown) {
    console.error('Admin real-time stats error:', error);
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
