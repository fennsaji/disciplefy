/**
 * Check Usage Alerts (Cron Job)
 * Runs every 15 minutes to detect cost spikes, usage anomalies, and profitability issues
 * Triggers notifications via send-alert-notification function
 *
 * Configure in Supabase Dashboard:
 * Edge Functions > Cron Jobs > Add Job
 * Schedule: "star-slash-15 star star star star" (every 15 minutes)
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import type { AlertTrigger, AlertType } from '../_shared/types/usage-types.ts';

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
    // This is a cron job, verify it's called from Supabase or has proper auth
    const authHeader = req.headers.get('Authorization');
    const cronSecret = Deno.env.get('CRON_SECRET');

    // Allow either Supabase service role or cron secret
    if (authHeader !== `Bearer ${cronSecret}` && !authHeader?.includes('service_role')) {
      return new Response(JSON.stringify({ error: 'Unauthorized - Cron job only' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const triggeredAlerts: AlertTrigger[] = [];

    // Get active alert rules
    const { data: alertRules, error: rulesError } = await supabaseClient
      .from('usage_alerts')
      .select('*')
      .eq('is_active', true);

    if (rulesError) {
      throw new Error(`Failed to fetch alert rules: ${rulesError.message}`);
    }

    console.log(`Checking ${alertRules?.length || 0} active alert rules...`);

    // Check each alert type
    for (const rule of alertRules || []) {
      try {
        const alerts = await checkAlertType(supabaseClient, rule);
        triggeredAlerts.push(...alerts);
      } catch (error) {
        console.error(`Error checking alert type ${rule.alert_type}:`, error);
      }
    }

    console.log(`Found ${triggeredAlerts.length} triggered alerts`);

    // Send notifications for triggered alerts
    if (triggeredAlerts.length > 0) {
      for (const alert of triggeredAlerts) {
        try {
          await sendNotification(supabaseClient, alert);
        } catch (error) {
          console.error(`Failed to send notification for alert:`, alert, error);
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        checked_rules: alertRules?.length || 0,
        triggered_alerts: triggeredAlerts.length,
        alerts: triggeredAlerts,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error: unknown) {
    console.error('Alert check error:', error);
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

/**
 * Check specific alert type and return triggered alerts
 */
async function checkAlertType(
  supabaseClient: any,
  rule: any
): Promise<AlertTrigger[]> {
  const alerts: AlertTrigger[] = [];

  switch (rule.alert_type as AlertType) {
    case 'cost_spike':
      return await checkCostSpikes(supabaseClient, rule.threshold_value);

    case 'usage_anomaly':
      return await checkUsageAnomalies(supabaseClient, rule.threshold_value);

    case 'rate_limit_exceeded':
      return await checkRateLimitViolations(supabaseClient, rule.threshold_value);

    case 'negative_profitability':
      return await checkNegativeProfitability(supabaseClient, rule.threshold_value);

    default:
      console.warn(`Unknown alert type: ${rule.alert_type}`);
      return [];
  }
}

/**
 * Check for cost spikes (user spending > threshold in last hour)
 */
async function checkCostSpikes(
  supabaseClient: any,
  threshold: number
): Promise<AlertTrigger[]> {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

  const { data, error } = await supabaseClient
    .from('usage_logs')
    .select('user_id, llm_cost_usd')
    .gte('created_at', oneHourAgo.toISOString());

  if (error) {
    console.error('Error checking cost spikes:', error);
    return [];
  }

  // Aggregate by user
  const userCosts: Record<string, number> = {};
  (data || []).forEach((log: any) => {
    userCosts[log.user_id] = (userCosts[log.user_id] || 0) + (log.llm_cost_usd || 0);
  });

  // Find users exceeding threshold
  return Object.entries(userCosts)
    .filter(([_, cost]) => cost > threshold)
    .map(([userId, cost]) => ({
      alert_type: 'cost_spike' as AlertType,
      user_id: userId,
      current_value: cost,
      threshold_value: threshold,
      message: `User ${userId} has spent $${cost.toFixed(2)} in the last hour (threshold: $${threshold})`,
      timestamp: new Date(),
    }));
}

/**
 * Check for usage anomalies (using RPC function)
 */
async function checkUsageAnomalies(
  supabaseClient: any,
  threshold: number
): Promise<AlertTrigger[]> {
  const { data, error } = await supabaseClient.rpc('detect_usage_anomalies', {
    p_threshold_multiplier: threshold,
  });

  if (error) {
    console.error('Error detecting anomalies:', error);
    return [];
  }

  return (data || []).map((anomaly: any) => ({
    alert_type: 'usage_anomaly' as AlertType,
    user_id: anomaly.user_id,
    feature_name: anomaly.feature_name,
    current_value: anomaly.recent_usage_count,
    threshold_value: anomaly.avg_usage_count * threshold,
    message: `User ${anomaly.user_id} has ${anomaly.anomaly_factor}x normal usage for ${anomaly.feature_name} (${anomaly.recent_usage_count} vs avg ${anomaly.avg_usage_count})`,
    timestamp: new Date(),
  }));
}

/**
 * Check for rate limit violations
 */
async function checkRateLimitViolations(
  supabaseClient: any,
  threshold: number
): Promise<AlertTrigger[]> {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

  const { data, error } = await supabaseClient
    .from('usage_logs')
    .select('user_id, feature_name')
    .gte('created_at', oneHourAgo.toISOString());

  if (error) {
    console.error('Error checking rate limits:', error);
    return [];
  }

  // Count operations per user per feature
  const userFeatureCounts: Record<string, Record<string, number>> = {};
  (data || []).forEach((log: any) => {
    if (!userFeatureCounts[log.user_id]) {
      userFeatureCounts[log.user_id] = {};
    }
    const feature = log.feature_name;
    userFeatureCounts[log.user_id][feature] = (userFeatureCounts[log.user_id][feature] || 0) + 1;
  });

  // Find violations
  const alerts: AlertTrigger[] = [];
  Object.entries(userFeatureCounts).forEach(([userId, features]) => {
    Object.entries(features).forEach(([feature, count]) => {
      if (count > threshold) {
        alerts.push({
          alert_type: 'rate_limit_exceeded' as AlertType,
          user_id: userId,
          feature_name: feature,
          current_value: count,
          threshold_value: threshold,
          message: `User ${userId} made ${count} ${feature} requests in the last hour (threshold: ${threshold})`,
          timestamp: new Date(),
        });
      }
    });
  });

  return alerts;
}

/**
 * Check for users with highly negative profitability
 */
async function checkNegativeProfitability(
  supabaseClient: any,
  threshold: number
): Promise<AlertTrigger[]> {
  const { data, error } = await supabaseClient
    .from('usage_logs')
    .select('user_id, profit_margin_inr');

  if (error) {
    console.error('Error checking profitability:', error);
    return [];
  }

  // Aggregate profit by user
  const userProfits: Record<string, number> = {};
  (data || []).forEach((log: any) => {
    userProfits[log.user_id] = (userProfits[log.user_id] || 0) + (log.profit_margin_inr || 0);
  });

  // Find users with losses exceeding threshold (negative)
  return Object.entries(userProfits)
    .filter(([_, profit]) => profit < threshold) // threshold is negative, e.g., -500
    .map(([userId, profit]) => ({
      alert_type: 'negative_profitability' as AlertType,
      user_id: userId,
      current_value: profit,
      threshold_value: threshold,
      message: `User ${userId} has lifetime profit of ₹${profit.toFixed(2)} (threshold: ₹${threshold})`,
      timestamp: new Date(),
    }));
}

/**
 * Send notification for triggered alert
 */
async function sendNotification(supabaseClient: any, alert: AlertTrigger): Promise<void> {
  // For now, just log to database
  // In production, this would call send-alert-notification function or directly send emails/Slack

  console.log('ALERT TRIGGERED:', alert);

  // Store alert in database for admin dashboard
  await supabaseClient.from('analytics_events').insert({
    event_type: 'usage_alert',
    event_data: alert,
    created_at: new Date().toISOString(),
  });
}
