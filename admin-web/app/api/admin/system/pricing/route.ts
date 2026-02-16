import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch all subscription pricing from database
 */
export async function GET(request: NextRequest) {
  try {
    // Verify user authentication
    const supabaseUser = await createClient()
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()

    if (userError || !user) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      )
    }

    // Verify admin status
    const supabaseAdmin = createAdminClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    )
    const { data: profile } = await supabaseAdmin
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()

    if (!profile?.is_admin) {
      return NextResponse.json(
        { error: 'Unauthorized - Admin access required' },
        { status: 403 }
      )
    }

    // Fetch pricing data from subscription_plan_providers with subscription_plans join
    const { data: pricing, error: pricingError } = await supabaseAdmin
      .from('subscription_plan_providers')
      .select(`
        id,
        provider,
        plan_id,
        base_price_minor,
        currency,
        region,
        is_active,
        subscription_plans!inner (
          plan_code,
          plan_name
        )
      `)
      .order('provider', { ascending: true })
      .order('plan_id', { ascending: true })

    if (pricingError) {
      console.error('[PRICING API] Error fetching pricing:', pricingError)
      return NextResponse.json(
        { error: 'Failed to fetch pricing data' },
        { status: 500 }
      )
    }

    // Format pricing data for frontend
    const formattedPricing = pricing?.map((p: any) => ({
      id: p.id,
      provider: p.provider,
      planCode: p.subscription_plans.plan_code,
      planName: p.subscription_plans.plan_name,
      basePriceMinor: p.base_price_minor,
      currency: p.currency,
      region: p.region,
      isActive: p.is_active,
      // Calculate formatted price
      formattedPrice: formatPrice(p.base_price_minor, p.currency)
    })) || []

    return NextResponse.json({
      success: true,
      data: formattedPricing
    })

  } catch (error) {
    console.error('[PRICING API] Unexpected error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * PATCH - Update pricing for a specific plan/provider combination
 */
export async function PATCH(request: NextRequest) {
  try {
    // Verify user authentication
    const supabaseUser = await createClient()
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()

    if (userError || !user) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      )
    }

    // Verify admin status
    const supabaseAdmin = createAdminClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    )
    const { data: profile } = await supabaseAdmin
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()

    if (!profile?.is_admin) {
      return NextResponse.json(
        { error: 'Unauthorized - Admin access required' },
        { status: 403 }
      )
    }

    // Parse request body
    const body = await request.json()
    const { id, basePriceMinor, isActive } = body

    if (!id) {
      return NextResponse.json(
        { error: 'Missing required field: id' },
        { status: 400 }
      )
    }

    // Build update object
    const updates: any = {}
    if (basePriceMinor !== undefined) {
      updates.base_price_minor = basePriceMinor
    }
    if (isActive !== undefined) {
      updates.is_active = isActive
    }

    if (Object.keys(updates).length === 0) {
      return NextResponse.json(
        { error: 'No fields to update' },
        { status: 400 }
      )
    }

    // Update pricing
    const { data, error } = await supabaseAdmin
      .from('subscription_plan_providers')
      .update(updates)
      .eq('id', id)
      .select()
      .single()

    if (error) {
      console.error('[PRICING API] Error updating pricing:', error)
      return NextResponse.json(
        { error: 'Failed to update pricing' },
        { status: 500 }
      )
    }

    return NextResponse.json({
      success: true,
      data
    })

  } catch (error) {
    console.error('[PRICING API] Unexpected error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * Format price from minor units (paise/cents) to display format
 */
function formatPrice(amountMinor: number, currency: string): string {
  const amountMajor = amountMinor / 100

  switch (currency) {
    case 'INR':
      return `₹${Math.floor(amountMajor)}`
    case 'USD':
      return `$${amountMajor.toFixed(2)}`
    case 'EUR':
      return `€${amountMajor.toFixed(2)}`
    case 'GBP':
      return `£${amountMajor.toFixed(2)}`
    default:
      return `${currency} ${amountMajor.toFixed(2)}`
  }
}
