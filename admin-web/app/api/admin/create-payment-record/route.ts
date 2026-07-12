import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import type { CreatePaymentRecordRequest, CreatePaymentRecordResponse } from '@/types/admin'

export async function POST(request: NextRequest) {
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
    const supabaseAdmin = await createAdminClient()
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
    const body: CreatePaymentRecordRequest = await request.json()

    // Validate required fields
    if (!body.user_id || !body.subscription_id || !body.amount || !body.payment_method || !body.payment_date) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      )
    }

    // Create payment record in purchase_history table
    // Note: purchase_history has no subscription_id/currency/notes columns;
    // amounts map to cost_rupees/cost_paise and payment_date to purchased_at.
    const orderId = `admin_manual_${Date.now()}`
    const { data: paymentRecord, error: insertError } = await supabaseAdmin
      .from('purchase_history')
      .insert({
        user_id: body.user_id,
        token_amount: 1, // Schema requires token_amount > 0; manual subscription payments carry no tokens
        cost_rupees: body.amount,
        cost_paise: Math.round(body.amount * 100),
        payment_id: body.reference_number || orderId,
        order_id: orderId,
        payment_method: body.payment_method,
        payment_provider: 'admin_manual',
        status: 'completed',
        purchased_at: body.payment_date,
      })
      .select()
      .single()

    if (insertError) {
      console.error('Failed to create payment record:', insertError)
      return NextResponse.json(
        { error: 'Failed to create payment record: ' + insertError.message },
        { status: 500 }
      )
    }

    const response: CreatePaymentRecordResponse = {
      success: true,
      payment_id: paymentRecord.id,
      message: 'Payment record created successfully',
    }

    return NextResponse.json(response)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
