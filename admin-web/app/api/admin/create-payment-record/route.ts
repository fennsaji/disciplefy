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
    const { data: paymentRecord, error: insertError } = await supabaseAdmin
      .from('purchase_history')
      .insert({
        user_id: body.user_id,
        subscription_id: body.subscription_id,
        amount_paid: body.amount,
        currency: body.currency || 'INR',
        payment_method: body.payment_method,
        payment_date: body.payment_date,
        transaction_id: body.reference_number || null,
        notes: body.notes || null,
        status: 'completed',
        created_by_admin: user.id,
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
