import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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
    const body: CreatePromoCodeRequest = await req.json()

    // Validate required fields
    if (!body.code || !body.campaign_name || !body.discount_type || !body.discount_value) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate discount value
    if (body.discount_type === 'percentage' && (body.discount_value <= 0 || body.discount_value > 100)) {
      return new Response(
        JSON.stringify({ error: 'Percentage discount must be between 1 and 100' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (body.discount_type === 'fixed_amount' && body.discount_value <= 0) {
      return new Response(
        JSON.stringify({ error: 'Fixed amount discount must be greater than 0' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if promo code already exists
    const { data: existing } = await adminSupabase
      .from('promotional_campaigns')
      .select('id')
      .eq('campaign_code', body.code.toUpperCase())
      .maybeSingle()

    if (existing) {
      return new Response(
        JSON.stringify({ error: 'Promo code already exists' }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create the promotional campaign
    const { data: campaign, error: createError } = await adminSupabase
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
      return new Response(
        JSON.stringify({ error: 'Failed to create promo code', details: createError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Log admin action
    try {
      await adminSupabase
        .from('admin_audit_log')
        .insert({
          admin_user_id: adminUserId,
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

    return new Response(
      JSON.stringify({
        success: true,
        campaign,
        message: `Promo code ${body.code} created successfully`
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error in admin-create-promo-code:', error)
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
