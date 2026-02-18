/**
 * Admin Profitability Report Endpoint
 * Provides detailed profitability analysis per tier and feature with recommendations
 * Admin-only access
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import type { ProfitabilityReport } from '../_shared/types/usage-types.ts';

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
    const tier = url.searchParams.get('tier');
    const feature = url.searchParams.get('feature');

    if (!tier || !feature) {
      return new Response(
        JSON.stringify({ error: 'Missing required parameters: tier and feature' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Get profitability report from RPC function
    const { data: report, error: reportError } = await supabaseClient.rpc(
      'get_profitability_report',
      {
        p_tier: tier,
        p_feature_name: feature,
      }
    );

    if (reportError) {
      throw new Error(`Failed to get profitability report: ${reportError.message}`);
    }

    // Add additional context
    const enhancedReport: ProfitabilityReport & { metadata: any } = {
      ...report,
      metadata: {
        query_timestamp: new Date().toISOString(),
        period: 'last_30_days',
        tier_description: getTierDescription(tier),
        feature_description: getFeatureDescription(feature),
      },
    };

    return new Response(JSON.stringify(enhancedReport), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error: unknown) {
    console.error('Admin profitability report error:', error);
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

// Helper functions
function getTierDescription(tier: string): string {
  const descriptions: Record<string, string> = {
    free: 'Free tier - ₹0/month',
    standard: 'Standard tier - ₹79/month',
    plus: 'Plus tier - ₹149/month',
    premium: 'Premium tier - ₹499/month',
  };
  return descriptions[tier] || 'Unknown tier';
}

function getFeatureDescription(feature: string): string {
  const descriptions: Record<string, string> = {
    study_generate: 'AI-powered Bible study guide generation',
    study_followup: 'Follow-up questions on study guides (Haiku)',
    voice_conversation: 'AI Discipler voice conversations (ElevenLabs)',
    memory_practice: 'Memory verse practice sessions (non-LLM)',
    memory_verse_add: 'Add memory verses (non-LLM)',
  };
  return descriptions[feature] || 'Unknown feature';
}
