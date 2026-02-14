/**
 * Admin User Analytics Endpoint
 * Provides per-user usage and profitability metrics
 * Admin-only access
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import type { UserProfitability } from '../_shared/types/usage-types.ts';

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

    // Parse query parameters
    const url = new URL(req.url);
    const targetUserId = url.searchParams.get('user_id');
    const limit = parseInt(url.searchParams.get('limit') || '50', 10);
    const sortBy = url.searchParams.get('sort_by') || 'profit'; // profit, cost, operations

    // Single user profitability
    if (targetUserId) {
      const { data: userProfit, error: profitError } = await supabaseClient.rpc(
        'calculate_user_profitability',
        { p_user_id: targetUserId }
      );

      if (profitError) {
        throw new Error(`Failed to calculate user profitability: ${profitError.message}`);
      }

      // Get user email for context
      const { data: userData } = await supabaseClient.auth.admin.getUserById(targetUserId);

      const response = {
        ...userProfit,
        user_email: userData?.user?.email || 'unknown',
      };

      return new Response(JSON.stringify(response), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Top users by profitability (or loss)
    const { data: usageLogs, error: logsError } = await supabaseClient
      .from('usage_logs')
      .select('user_id, tier, llm_cost_usd, estimated_revenue_inr, profit_margin_inr')
      .order('created_at', { ascending: false })
      .limit(10000); // Last 10k operations

    if (logsError) {
      throw new Error(`Failed to fetch usage logs: ${logsError.message}`);
    }

    // Aggregate by user
    const userAggregates: Record<string, {
      operations: number;
      cost: number;
      revenue: number;
      profit: number;
      tier: string;
    }> = {};

    (usageLogs || []).forEach((log) => {
      if (!userAggregates[log.user_id]) {
        userAggregates[log.user_id] = {
          operations: 0,
          cost: 0,
          revenue: 0,
          profit: 0,
          tier: log.tier,
        };
      }
      userAggregates[log.user_id].operations++;
      userAggregates[log.user_id].cost += log.llm_cost_usd || 0;
      userAggregates[log.user_id].revenue += log.estimated_revenue_inr || 0;
      userAggregates[log.user_id].profit += log.profit_margin_inr || 0;
    });

    // Convert to array
    const userList = Object.entries(userAggregates).map(([userId, stats]) => ({
      user_id: userId,
      ...stats,
      profitability_status: stats.profit > 0 ? 'profit' : stats.profit === 0 ? 'break_even' : 'loss',
    }));

    // Sort based on sortBy parameter
    userList.sort((a, b) => {
      switch (sortBy) {
        case 'cost':
          return b.cost - a.cost;
        case 'operations':
          return b.operations - a.operations;
        case 'profit':
        default:
          return b.profit - a.profit; // Most profitable first, then most loss
      }
    });

    // Take top N
    const topUsers = userList.slice(0, limit);

    // Build summary
    const summary = {
      total_users_analyzed: userList.length,
      profitable_users: userList.filter(u => u.profit > 0).length,
      loss_making_users: userList.filter(u => u.profit < 0).length,
      break_even_users: userList.filter(u => u.profit === 0).length,
      total_profit: userList.reduce((sum, u) => sum + u.profit, 0),
      total_cost: userList.reduce((sum, u) => sum + u.cost, 0),
      total_revenue: userList.reduce((sum, u) => sum + u.revenue, 0),
      total_operations: userList.reduce((sum, u) => sum + u.operations, 0),
    };

    const response = {
      summary,
      top_users: topUsers,
      sort_by: sortBy,
      limit,
    };

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error: unknown) {
    console.error('Admin user analytics error:', error);
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
