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

    const now = new Date().toISOString()

    // The status filter runs in SQL and is applied to BOTH the page and the
    // count, so pagination totals match the rows actually being browsed.
    const applyStatusFilter = (q: any) => {
      if (body.status === 'active') {
        return q.eq('is_active', true).lte('valid_from', now).gte('valid_until', now)
      }
      if (body.status === 'inactive') return q.eq('is_active', false)
      if (body.status === 'expired') return q.lt('valid_until', now)
      return q
    }

    const campaignColumns = `
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
      `

    // Execute query with pagination
    const { data: campaigns, error: listError } = await applyStatusFilter(
      adminSupabase.from('promotional_campaigns').select(campaignColumns)
    )
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
    const enhancedCampaigns = (campaigns || []).map((campaign: any) => ({
      ...campaign,
      code: campaign.campaign_code, // Add code alias for frontend compatibility
      current_uses: campaign.current_use_count || 0,
      is_expired: new Date(campaign.valid_until) < new Date(),
      start_date: campaign.valid_from, // Add aliases for frontend compatibility
      end_date: campaign.valid_until,
    }))

    // Total for pagination — same status filter as the page above
    const { count } = await applyStatusFilter(
      adminSupabase.from('promotional_campaigns').select('id', { count: 'exact', head: true })
    )

    // Stat cards describe EVERY campaign in the database, not the current page.
    // The campaign table is small, so a single read of the summary columns is
    // enough to compute redemptions and the expiring-soon window.
    const { data: allCampaigns } = await adminSupabase
      .from('promotional_campaigns')
      .select('is_active, valid_until, current_use_count')

    const sevenDaysOut = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    const stats = {
      total: (allCampaigns || []).length,
      active: 0,
      inactive: 0,
      expired: 0,
      expiring_soon: 0,
      total_redemptions: 0,
    }

    for (const c of allCampaigns || []) {
      const validUntil = new Date(c.valid_until)
      const isExpired = validUntil < new Date()
      stats.total_redemptions += c.current_use_count || 0
      if (isExpired) stats.expired++
      if (c.is_active && !isExpired) {
        stats.active++
        if (validUntil <= sevenDaysOut) stats.expiring_soon++
      }
      if (!c.is_active) stats.inactive++
    }

    return new Response(
      JSON.stringify({
        campaigns: enhancedCampaigns,
        total: count || 0,
        limit,
        offset,
        stats
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
