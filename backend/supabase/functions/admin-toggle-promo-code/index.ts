import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface TogglePromoCodeRequest {
  campaign_id: string
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
    const body: TogglePromoCodeRequest = await req.json()

    if (!body.campaign_id) {
      return new Response(
        JSON.stringify({ error: 'Missing campaign_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Update the campaign status
    const { data: campaign, error: updateError } = await adminSupabase
      .from('promotional_campaigns')
      .update({ is_active: body.is_active })
      .eq('id', body.campaign_id)
      .select()
      .single()

    if (updateError) {
      console.error('Error toggling promo code:', updateError)
      return new Response(
        JSON.stringify({ error: 'Failed to toggle promo code', details: updateError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Log admin action
    try {
      await adminSupabase
        .from('admin_audit_log')
        .insert({
          admin_user_id: adminUserId,
          action: 'toggle_promo_code',
          details: {
            campaign_id: body.campaign_id,
            code: campaign.campaign_code,
            is_active: body.is_active
          }
        })
    } catch (auditError) {
      console.warn('Failed to log admin action:', auditError)
    }

    return new Response(
      JSON.stringify({
        success: true,
        campaign,
        message: `Promo code ${body.is_active ? 'activated' : 'deactivated'} successfully`
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error in admin-toggle-promo-code:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
