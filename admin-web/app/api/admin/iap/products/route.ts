import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

/**
 * GET /api/admin/iap/products
 * Fetch product ID mappings for all plans and providers
 */
export async function GET(req: NextRequest) {
  try {
    const supabase = await createClient()

    // Check admin authorization
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser()

    if (authError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { data: profile } = await supabase
      .from('user_profiles')
      .select('is_admin')
      .eq('user_id', user.id)
      .single()

    if (!profile?.is_admin) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    // Fetch product mappings from subscription_plan_providers
    const { data: products, error } = await supabase
      .from('subscription_plan_providers')
      .select(
        `
        id,
        plan_id,
        provider,
        product_id,
        subscription_plans!inner(
          plan_code,
          plan_name
        )
      `
      )
      .in('provider', ['google_play', 'apple_appstore'])
      .order('plan_id')
      .order('provider')

    if (error) throw error

    // Transform data to include plan details
    const transformedProducts = products?.map((p: any) => ({
      id: p.plan_id,
      plan_code: p.subscription_plans.plan_code,
      plan_name: p.subscription_plans.plan_name,
      provider: p.provider,
      product_id: p.product_id,
    }))

    return NextResponse.json({
      success: true,
      products: transformedProducts || [],
    })
  } catch (error) {
    console.error('[IAP Products GET] Error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch product mappings' },
      { status: 500 }
    )
  }
}

/**
 * PATCH /api/admin/iap/products
 * Update product ID for a specific plan and provider
 */
export async function PATCH(req: NextRequest) {
  try {
    const supabase = await createClient()

    // Check admin authorization
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser()

    if (authError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { data: profile } = await supabase
      .from('user_profiles')
      .select('is_admin')
      .eq('user_id', user.id)
      .single()

    if (!profile?.is_admin) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    // Parse request body
    const body = await req.json()
    const { plan_id, provider, product_id } = body

    if (!plan_id || !provider || !product_id) {
      return NextResponse.json(
        { error: 'plan_id, provider, and product_id are required' },
        { status: 400 }
      )
    }

    // Update product ID
    const { error: updateError } = await supabase
      .from('subscription_plan_providers')
      .update({ product_id })
      .eq('plan_id', plan_id)
      .eq('provider', provider)

    if (updateError) throw updateError

    // Clear pricing cache on backend
    await fetch(
      `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/subscription-pricing`,
      {
        method: 'DELETE',
        headers: {
          Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
        },
      }
    ).catch((err) => console.warn('Failed to clear pricing cache:', err))

    return NextResponse.json({
      success: true,
      message: 'Product ID updated successfully',
    })
  } catch (error) {
    console.error('[IAP Products PATCH] Error:', error)
    return NextResponse.json(
      { error: 'Failed to update product ID' },
      { status: 500 }
    )
  }
}
