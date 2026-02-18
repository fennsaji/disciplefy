import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

/**
 * POST /api/admin/iap/verify-receipt
 * Verify a receipt with Google Play or Apple App Store (admin testing tool)
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
    const { provider, receipt_data } = body

    if (!provider || !receipt_data) {
      return NextResponse.json(
        { error: 'Provider and receipt_data are required' },
        { status: 400 }
      )
    }

    // Call backend receipt validation service
    const response = await fetch(
      `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/validate-receipt`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          provider,
          receipt_data,
          user_id: user.id, // Use admin user ID for testing
          product_id: 'test_product', // Placeholder for validation test
          environment: 'sandbox', // Default to sandbox for testing
        }),
      }
    )

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}))
      return NextResponse.json(
        {
          success: false,
          error: errorData.error || 'Receipt validation failed',
          details: errorData,
        },
        { status: response.status }
      )
    }

    const result = await response.json()

    return NextResponse.json({
      success: true,
      ...result,
    })
  } catch (error) {
    console.error('[IAP Verify Receipt] Error:', error)
    return NextResponse.json(
      {
        success: false,
        error: 'Failed to verify receipt',
        details: error instanceof Error ? error.message : String(error),
      },
      { status: 500 }
    )
  }
}
