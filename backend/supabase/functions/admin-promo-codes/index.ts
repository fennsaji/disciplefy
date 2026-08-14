import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

interface ListPromoCodesRequest {
  status?: 'all' | 'active' | 'inactive' | 'expired'
  limit?: number
  offset?: number
}

interface CreatePromoCodeRequest {
  code: string
  campaign_name: string
  description?: string
  discount_type: 'percentage' | 'fixed_amount'
  discount_value: number
  applies_to_plan: string[]
  max_total_uses?: number
  max_uses_per_user: number
  eligible_for: 'all' | 'new_users_only' | 'specific_tiers' | 'specific_users'
  eligible_tiers?: string[]
  eligible_user_ids?: string[]
  start_date: string
  end_date: string
  is_active: boolean
}

interface TogglePromoCodeRequest {
  campaign_id: string
  is_active: boolean
}

// Returns the admin client, or a Response if auth failed.
async function requireAdmin(req: Request): Promise<
  { adminSupabase: ReturnType<typeof createClient>; adminUserId: string } | Response
> {
  const authHeader = req.headers.get('Authorization')
  const adminUserId = req.headers.get('x-admin-user-id')
  if (!authHeader || !adminUserId) return json({ error: 'Unauthorized - Missing credentials' }, 401)

  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  if (authHeader.replace('Bearer ', '') !== serviceRoleKey)
    return json({ error: 'Unauthorized - Invalid credentials' }, 401)

  const adminSupabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', serviceRoleKey)
  const { data: profile, error } = await adminSupabase
    .from('user_profiles')
    .select('is_admin')
    .eq('id', adminUserId)
    .single() as any
  if (error || !(profile as any)?.is_admin) return json({ error: 'Forbidden - Admin access required' }, 403)

  return { adminSupabase, adminUserId } as any
}

// Copied verbatim from admin-list-promo-codes/index.ts
async function handleList(auth: { adminSupabase: ReturnType<typeof createClient>; adminUserId: string }, req: Request) {
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
    (auth.adminSupabase as any).from('promotional_campaigns').select(campaignColumns)
  )
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1)

  if (listError) {
    console.error('Error listing promo codes:', listError)
    return json({ error: 'Failed to list promo codes', details: listError.message }, 500)
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
    (auth.adminSupabase as any).from('promotional_campaigns').select('id', { count: 'exact', head: true })
  )

  // Stat cards describe EVERY campaign in the database, not the current page.
  // The campaign table is small, so a single read of the summary columns is
  // enough to compute redemptions and the expiring-soon window.
  const { data: allCampaigns } = await (auth.adminSupabase as any)
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

  return json({
    campaigns: enhancedCampaigns,
    total: count || 0,
    limit,
    offset,
    stats
  })
}

// Copied verbatim from admin-create-promo-code/index.ts
async function handleCreate(auth: { adminSupabase: ReturnType<typeof createClient>; adminUserId: string }, req: Request) {
  // Parse request body
  const body: CreatePromoCodeRequest = await req.json()

  // Validate required fields
  if (!body.code || !body.campaign_name || !body.discount_type || !body.discount_value) {
    return json({ error: 'Missing required fields' }, 400)
  }

  // Validate discount value
  if (body.discount_type === 'percentage' && (body.discount_value <= 0 || body.discount_value > 100)) {
    return json({ error: 'Percentage discount must be between 1 and 100' }, 400)
  }

  if (body.discount_type === 'fixed_amount' && body.discount_value <= 0) {
    return json({ error: 'Fixed amount discount must be greater than 0' }, 400)
  }

  // Check if promo code already exists
  const { data: existing } = await (auth.adminSupabase as any)
    .from('promotional_campaigns')
    .select('id')
    .eq('campaign_code', body.code.toUpperCase())
    .maybeSingle()

  if (existing) {
    return json({ error: 'Promo code already exists' }, 409)
  }

  // Create the promotional campaign
  const { data: campaign, error: createError } = await (auth.adminSupabase as any)
    .from('promotional_campaigns')
    .insert({
      campaign_code: body.code.toUpperCase(), // Store codes in uppercase
      campaign_name: body.campaign_name,
      description: body.description,
      discount_type: body.discount_type,
      discount_value: body.discount_value,
      applicable_plans: body.applies_to_plan || [],
      applicable_providers: ['razorpay'], // Default to razorpay
      max_total_uses: body.max_total_uses,
      max_uses_per_user: body.max_uses_per_user || 1,
      new_users_only: body.eligible_for === 'new_users_only',
      valid_from: body.start_date,
      valid_until: body.end_date,
      is_active: body.is_active
    })
    .select()
    .single()

  if (createError) {
    console.error('Error creating promo code:', createError)
    return json({ error: 'Failed to create promo code', details: createError.message }, 500)
  }

  // Log admin action
  try {
    await (auth.adminSupabase as any)
      .from('admin_logs')
      .insert({
        admin_user_id: auth.adminUserId,
        action: 'create_promo_code',
        details: {
          code: body.code,
          campaign_name: body.campaign_name,
          discount_type: body.discount_type,
          discount_value: body.discount_value
        }
      })
  } catch (auditError) {
    console.warn('Failed to log admin action:', auditError)
  }

  return json({
    success: true,
    campaign,
    message: `Promo code ${body.code} created successfully`
  })
}

// Copied verbatim from admin-toggle-promo-code/index.ts
async function handleToggle(auth: { adminSupabase: ReturnType<typeof createClient>; adminUserId: string }, req: Request) {
  // Parse request body
  const body: TogglePromoCodeRequest = await req.json()

  if (!body.campaign_id) {
    return json({ error: 'Missing campaign_id' }, 400)
  }

  // Update the campaign status
  const { data: campaign, error: updateError } = await (auth.adminSupabase as any)
    .from('promotional_campaigns')
    .update({ is_active: body.is_active })
    .eq('id', body.campaign_id)
    .select()
    .single()

  if (updateError) {
    console.error('Error toggling promo code:', updateError)
    return json({ error: 'Failed to toggle promo code', details: updateError.message }, 500)
  }

  // Log admin action
  try {
    await (auth.adminSupabase as any)
      .from('admin_logs')
      .insert({
        admin_user_id: auth.adminUserId,
        action: 'toggle_promo_code',
        details: {
          campaign_id: body.campaign_id,
          code: (campaign as any).campaign_code,
          is_active: body.is_active
        }
      })
  } catch (auditError) {
    console.warn('Failed to log admin action:', auditError)
  }

  return json({
    success: true,
    campaign,
    message: `Promo code ${body.is_active ? 'activated' : 'deactivated'} successfully`
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const auth = await requireAdmin(req)
    if (auth instanceof Response) return auth

    const url = new URL(req.url)
    // pathParts[0] is always this function's own name (Supabase does not
    // strip it) — base route = length 1.
    const pathParts = url.pathname.split('/').filter(Boolean)
    const method = req.method

    // list is POST-with-filter-body (matches source admin-list-promo-codes,
    // which reads {status, limit, offset} via req.json(), not query params).
    // Uses the action-suffix pattern (POST /list) to avoid colliding with
    // create's POST /, consistent with admin-learning-paths' convention.
    if (method === 'POST' && pathParts.length === 2 && pathParts[1] === 'list') return await handleList(auth, req)
    if (method === 'POST' && pathParts.length === 1) return await handleCreate(auth, req)
    if (method === 'POST' && pathParts.length === 2 && pathParts[1] === 'toggle') return await handleToggle(auth, req)

    return json({ error: 'Not found' }, 404)
  } catch (error) {
    console.error('Error in admin-promo-codes:', error)
    return json({ error: 'Internal server error', message: error instanceof Error ? error.message : 'Unknown error' }, 500)
  }
})
