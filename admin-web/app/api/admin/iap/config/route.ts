import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

/**
 * GET /api/admin/iap/config
 * Fetch IAP configuration for a specific provider and environment
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

    // Get query parameters
    const { searchParams } = new URL(req.url)
    const provider = searchParams.get('provider')
    const environment = searchParams.get('environment')

    if (!provider || !environment) {
      return NextResponse.json(
        { error: 'Provider and environment are required' },
        { status: 400 }
      )
    }

    // Fetch IAP configuration
    const { data: configs, error } = await supabase
      .from('iap_config')
      .select('*')
      .eq('provider', provider)
      .eq('environment', environment)
      .order('config_key')

    if (error) throw error

    return NextResponse.json({
      success: true,
      configs: configs || [],
    })
  } catch (error) {
    console.error('[IAP Config GET] Error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch IAP configuration' },
      { status: 500 }
    )
  }
}

/**
 * POST /api/admin/iap/config
 * Update IAP configuration for a specific provider and environment
 */
export async function POST(req: NextRequest) {
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
    const { provider, environment, configs, is_active } = body

    if (!provider || !environment || !configs) {
      return NextResponse.json(
        { error: 'Provider, environment, and configs are required' },
        { status: 400 }
      )
    }

    // Update each configuration key
    const updates = Object.entries(configs).map(([config_key, config_value]) =>
      supabase
        .from('iap_config')
        .upsert(
          {
            provider,
            environment,
            config_key,
            config_value: config_value as string,
            is_active: is_active ?? false,
          },
          {
            onConflict: 'provider,environment,config_key',
          }
        )
    )

    await Promise.all(updates)

    // Clear IAP config cache on backend
    await fetch(
      `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/iap-config-cache/clear`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
        },
      }
    ).catch((err) => console.warn('Failed to clear cache:', err))

    return NextResponse.json({
      success: true,
      message: 'IAP configuration updated successfully',
    })
  } catch (error) {
    console.error('[IAP Config POST] Error:', error)
    return NextResponse.json(
      { error: 'Failed to update IAP configuration' },
      { status: 500 }
    )
  }
}
