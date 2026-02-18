import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ListPromoCodesRequest {
  status?: 'all' | 'active' | 'inactive' | 'expired'
  limit?: number
  offset?: number
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify service role authentication
    const authHeader = req.headers.get('Authorization')
    const adminUserId = req.headers.get('x-admin-user-id')

    if (!authHeader || !adminUserId) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized - Missing credentials' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify it's the service role key
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const providedKey = authHeader.replace('Bearer ', '')

    if (providedKey !== serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized - Invalid credentials' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create admin client with service role key
    const adminSupabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      serviceRoleKey
    )

    // Verify admin status
    const { data: profile, error: profileError } = await adminSupabase
      .from('user_profiles')
      .select('is_admin')
      .eq('id', adminUserId)
      .single()

    if (profileError || !profile?.is_admin) {
      return new Response(
        JSON.stringify({ error: 'Forbidden - Admin access required' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const body: ListPromoCodesRequest = await req.json()
    const limit = body.limit || 100
    const offset = body.offset || 0

    // Build query
    let query = adminSupabase
      .from('promotional_campaigns')
      .select(`
        id,
        campaign_code,
        campaign_name,
        description,
        discount_type,
        discount_value,
        applicable_plans,
        applicable_providers,
        max_total_uses,
        max_uses_per_user,
        current_use_count,
        new_users_only,
        valid_from,
        valid_until,
        is_active,
        created_at,
        updated_at
      `)

    // Filter by status
    const now = new Date().toISOString()
    if (body.status === 'active') {
      query = query.eq('is_active', true).lte('valid_from', now).gte('valid_until', now)
    } else if (body.status === 'inactive') {
      query = query.eq('is_active', false)
    } else if (body.status === 'expired') {
      query = query.lt('valid_until', now)
    }

    // Execute query with pagination
    const { data: campaigns, error: listError } = await query
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1)

    if (listError) {
      console.error('Error listing promo codes:', listError)
      return new Response(
        JSON.stringify({ error: 'Failed to list promo codes', details: listError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Enhance campaigns with computed fields
    const enhancedCampaigns = campaigns.map(campaign => ({
      ...campaign,
      code: campaign.campaign_code, // Add code alias for frontend compatibility
      current_uses: campaign.current_use_count || 0,
      is_expired: new Date(campaign.valid_until) < new Date(),
      start_date: campaign.valid_from, // Add aliases for frontend compatibility
      end_date: campaign.valid_until,
    }))

    // Get total count for pagination
    const { count } = await adminSupabase
      .from('promotional_campaigns')
      .select('id', { count: 'exact', head: true })

    return new Response(
      JSON.stringify({
        campaigns: enhancedCampaigns,
        total: count || 0,
        limit,
        offset
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error in admin-list-promo-codes:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
