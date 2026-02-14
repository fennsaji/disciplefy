import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch subscription configuration
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

    // Fetch subscription plans with provider pricing
    const { data: subscriptionPlans, error: plansError } = await supabaseAdmin
      .from('subscription_plans')
      .select(`
        *,
        subscription_plan_providers (
          provider,
          provider_plan_id,
          base_price_minor,
          currency
        )
      `)
      .order('tier', { ascending: true })

    if (plansError) {
      console.error('Failed to fetch subscription plans:', plansError)
      return NextResponse.json(
        { error: 'Failed to fetch subscription plans' },
        { status: 500 }
      )
    }

    // Get active subscription counts
    const { data: activeSubscriptions } = await supabaseAdmin
      .from('subscriptions')
      .select('plan_id, status')
      .in('status', ['active', 'trial'])

    // Count by plan ID
    const planCounts: Record<string, number> = {}
    ;(activeSubscriptions || []).forEach(sub => {
      if (sub.plan_id) {
        planCounts[sub.plan_id] = (planCounts[sub.plan_id] || 0) + 1
      }
    })

    // Format plans with pricing and counts
    const formattedPlans = (subscriptionPlans || []).map(plan => {
      // Get Razorpay pricing (primary provider)
      const razorpayProvider = plan.subscription_plan_providers?.find(
        (p: any) => p.provider === 'razorpay'
      )

      return {
        id: plan.id,
        plan_code: plan.plan_code,
        plan_name: plan.plan_name,
        tier: plan.tier,
        interval: plan.interval,
        features: plan.features,
        is_active: plan.is_active,
        razorpay_plan_id: razorpayProvider?.provider_plan_id || '',
        price_inr: razorpayProvider?.base_price_minor
          ? Math.round(razorpayProvider.base_price_minor / 100)
          : 0,
        billing_period: plan.interval,
        daily_tokens: plan.features?.daily_tokens || 0,
        active_users: planCounts[plan.id] || 0
      }
    })

    // Count by plan code for stats
    const planCodeCounts: Record<string, number> = {}
    formattedPlans.forEach(plan => {
      planCodeCounts[plan.plan_code] = plan.active_users
    })

    // Calculate statistics
    const stats = {
      total_plans: formattedPlans.length,
      total_active_subscriptions: Object.values(planCounts).reduce((sum, count) => sum + count, 0),
      by_plan: planCodeCounts,
    }

    return NextResponse.json({
      subscription_config: formattedPlans,
      stats
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * PATCH - Update subscription plan configuration
 */
export async function PATCH(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      id,
      plan_code,
      razorpay_plan_id,
      price_inr,
      billing_period,
      features,
      is_active
    } = body

    if (!id) {
      return NextResponse.json(
        { error: 'id is required' },
        { status: 400 }
      )
    }

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

    // Update subscription plan features with correct schema
    const updatedFeatures = {
      daily_tokens: features?.daily_tokens ?? 0,
      voice_conversations_monthly: features?.voice_conversations_monthly ?? 0,
      memory_verses: features?.memory_verses ?? 0,
      practice_modes: features?.practice_modes ?? 0,
      practice_limit: features?.practice_limit ?? 0,
      study_modes: features?.study_modes || ['standard']
    }

    const { data: planData, error: planError } = await supabaseAdmin
      .from('subscription_plans')
      .update({
        features: updatedFeatures,
        is_active: is_active ?? true,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single()

    if (planError) {
      console.error('Failed to update subscription plan:', planError)
      return NextResponse.json(
        { error: 'Failed to update subscription plan' },
        { status: 500 }
      )
    }

    // Update Razorpay provider pricing if provided
    if (razorpay_plan_id || price_inr !== undefined) {
      const { error: providerError } = await supabaseAdmin
        .from('subscription_plan_providers')
        .update({
          provider_plan_id: razorpay_plan_id,
          base_price_minor: price_inr ? price_inr * 100 : 0,
          updated_at: new Date().toISOString()
        })
        .eq('plan_id', id)
        .eq('provider', 'razorpay')

      if (providerError) {
        console.error('Failed to update provider pricing:', providerError)
      }
    }

    return NextResponse.json({ subscription_plan: planData })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * POST - Create new subscription plan
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      plan_code,
      plan_name,
      tier,
      interval,
      razorpay_plan_id,
      price_inr,
      features
    } = body

    if (!plan_code || !plan_name || tier === undefined || !interval) {
      return NextResponse.json(
        { error: 'plan_code, plan_name, tier, and interval are required' },
        { status: 400 }
      )
    }

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

    // Create subscription plan with correct schema
    const planFeatures = {
      daily_tokens: features?.daily_tokens || 0,
      voice_conversations_monthly: features?.voice_conversations_monthly || 0,
      memory_verses: features?.memory_verses || 0,
      practice_modes: features?.practice_modes || 0,
      practice_limit: features?.practice_limit || 0,
      study_modes: features?.study_modes || ['standard']
    }

    const { data: planData, error: planError } = await supabaseAdmin
      .from('subscription_plans')
      .insert({
        plan_code,
        plan_name,
        tier,
        interval,
        features: planFeatures,
        is_active: true,
        is_visible: true
      })
      .select()
      .single()

    if (planError) {
      console.error('Failed to create subscription plan:', planError)
      return NextResponse.json(
        { error: 'Failed to create subscription plan' },
        { status: 500 }
      )
    }

    // Create Razorpay provider pricing if provided
    if (razorpay_plan_id) {
      const { error: providerError } = await supabaseAdmin
        .from('subscription_plan_providers')
        .insert({
          plan_id: planData.id,
          provider: 'razorpay',
          provider_plan_id: razorpay_plan_id,
          base_price_minor: (price_inr || 0) * 100,
          currency: 'INR',
          region: 'IN',
          is_active: true
        })

      if (providerError) {
        console.error('Failed to create provider pricing:', providerError)
        // Don't fail the request, plan was created successfully
      }
    }

    return NextResponse.json({ subscription_plan: planData })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
