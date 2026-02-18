import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

/**
 * POST /api/admin/subscription/update-price
 *
 * Update subscription price for any provider (Razorpay, Google Play, Apple App Store)
 * Proxies to Edge Function: admin-update-subscription-price
 */
export async function POST(request: NextRequest) {
  try {
    // Verify user authentication
    const supabaseUser = await createClient()
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()

    if (userError || !user) {
      return NextResponse.json(
        { success: false, error: 'Unauthorized' },
        { status: 401 }
      )
    }

    // Verify admin status
    const { data: profile } = await supabaseUser
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()

    if (!profile?.is_admin) {
      return NextResponse.json(
        { success: false, error: 'Unauthorized - Admin access required' },
        { status: 403 }
      )
    }

    // Parse request body
    const body = await request.json()
    const {
      plan_provider_id,
      new_price_minor,
      notes,
      external_console_updated
    } = body

    // Validate required fields
    if (!plan_provider_id || !new_price_minor) {
      return NextResponse.json(
        { success: false, error: 'plan_provider_id and new_price_minor are required' },
        { status: 400 }
      )
    }

    // Get auth token for Edge Function call
    const { data: { session } } = await supabaseUser.auth.getSession()
    if (!session) {
      return NextResponse.json(
        { success: false, error: 'No active session' },
        { status: 401 }
      )
    }

    // Call Edge Function
    const edgeFunctionUrl = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/admin-update-subscription-price`

    console.log('[update-price API] Calling Edge Function:', {
      plan_provider_id,
      new_price_minor,
      has_notes: !!notes,
      external_console_updated
    })

    const edgeFunctionResponse = await fetch(edgeFunctionUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${session.access_token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        plan_provider_id,
        new_price_minor,
        notes,
        external_console_updated
      })
    })

    const edgeFunctionData = await edgeFunctionResponse.json()

    if (!edgeFunctionResponse.ok || !edgeFunctionData.success) {
      console.error('[update-price API] Edge Function error:', edgeFunctionData)
      return NextResponse.json(
        {
          success: false,
          error: edgeFunctionData.error || 'Failed to update price'
        },
        { status: edgeFunctionResponse.status }
      )
    }

    console.log('[update-price API] Success:', {
      provider: edgeFunctionData.provider,
      old_price: edgeFunctionData.old_price_minor,
      new_price: edgeFunctionData.new_price_minor,
      new_provider_plan_id: edgeFunctionData.new_provider_plan_id
    })

    // Return success response
    return NextResponse.json({
      success: true,
      provider: edgeFunctionData.provider,
      old_price_minor: edgeFunctionData.old_price_minor,
      new_price_minor: edgeFunctionData.new_price_minor,
      old_provider_plan_id: edgeFunctionData.old_provider_plan_id,
      new_provider_plan_id: edgeFunctionData.new_provider_plan_id,
      sync_status: edgeFunctionData.sync_status,
      audit_log_id: edgeFunctionData.audit_log_id,
      warning: edgeFunctionData.warning
    })

  } catch (error) {
    console.error('[update-price API] Unexpected error:', error)
    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Internal server error'
      },
      { status: 500 }
    )
  }
}
