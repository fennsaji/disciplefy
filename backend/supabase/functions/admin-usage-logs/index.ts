/**
 * Admin Usage Logs Endpoint
 * Returns paginated individual usage_logs records for study_generate operations
 * Admin-only access via service role key
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    const adminUserId = req.headers.get('x-admin-user-id');

    if (!authHeader || !adminUserId) {
      return new Response(JSON.stringify({ error: 'Unauthorized - Missing credentials' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    if (authHeader.replace('Bearer ', '') !== serviceRoleKey) {
      return new Response(JSON.stringify({ error: 'Unauthorized - Invalid credentials' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

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

    if (profileError || !profile?.is_admin) {
      return new Response(JSON.stringify({ error: 'Forbidden - Admin access required' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Parse request body
    const body = await req.json().catch(() => ({}));
    const startDate = body.start_date || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    const endDate = body.end_date || new Date().toISOString();
    const language: string | null = body.language || null;
    const studyMode: string | null = body.study_mode || null;
    const tier: string | null = body.tier || null;
    const page: number = Math.max(1, parseInt(body.page) || 1);
    const limit: number = Math.min(100, Math.max(1, parseInt(body.limit) || 25));
    const offset = (page - 1) * limit;

    // Build query
    let query = supabaseClient
      .from('usage_logs')
      .select(
        'id, created_at, user_id, tier, llm_model, llm_provider, llm_input_tokens, llm_output_tokens, llm_cost_usd, request_metadata',
        { count: 'exact' }
      )
      .eq('feature_name', 'study_generate')
      .gte('created_at', startDate)
      .lte('created_at', endDate)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (tier) {
      query = query.eq('tier', tier);
    }
    if (language) {
      query = query.filter('request_metadata->>language', 'eq', language);
    }
    if (studyMode) {
      query = query.filter('request_metadata->>study_mode', 'eq', studyMode);
    }

    const { data: rows, error: queryError, count } = await query;

    if (queryError) {
      throw new Error(`Failed to fetch usage logs: ${queryError.message}`);
    }

    // Extract JSONB fields into flat response objects
    const items = (rows || []).map((row: any) => ({
      id: row.id,
      created_at: row.created_at,
      user_id: row.user_id,
      tier: row.tier,
      language: row.request_metadata?.language ?? null,
      study_mode: row.request_metadata?.study_mode ?? null,
      input_type: row.request_metadata?.input_type ?? null,
      llm_model: row.llm_model ?? null,
      llm_provider: row.llm_provider ?? null,
      llm_input_tokens: row.llm_input_tokens ?? null,
      llm_output_tokens: row.llm_output_tokens ?? null,
      llm_cost_usd: row.llm_cost_usd ?? null,
    }));

    return new Response(
      JSON.stringify({ items, total: count ?? 0, page, limit }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error: unknown) {
    console.error('Admin usage logs error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Internal server error';
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
