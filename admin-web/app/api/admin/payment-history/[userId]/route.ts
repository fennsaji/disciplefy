import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

/**
 * GET - Fetch payment history for a specific user
 */
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ userId: string }> }
) {
  try {
    const { userId } = await params

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

    // Fetch payment history for the user
    const { data: payments, error: paymentsError } = await supabaseAdmin
      .from('purchase_history')
      .select(`
        id,
        token_amount,
        cost_rupees,
        cost_paise,
        payment_id,
        order_id,
        payment_method,
        payment_provider,
        status,
        receipt_number,
        receipt_url,
        purchased_at,
        created_at
      `)
      .eq('user_id', userId)
      .order('purchased_at', { ascending: false })

    if (paymentsError) {
      console.error('Failed to fetch payment history:', paymentsError)
      return NextResponse.json(
        { error: 'Failed to fetch payment history' },
        { status: 500 }
      )
    }

    // Also fetch subscription invoices if they exist
    const { data: invoices, error: invoicesError } = await supabaseAdmin
      .from('subscription_invoices')
      .select(`
        id,
        subscription_id,
        invoice_number,
        amount_minor,
        currency,
        payment_status,
        payment_date,
        due_date,
        created_at
      `)
      .eq('user_id', userId)
      .order('created_at', { ascending: false })

    return NextResponse.json({
      payments: payments || [],
      invoices: invoices || [],
      total_payments: payments?.length || 0,
      total_spent: payments?.reduce((sum, p) => sum + parseFloat(p.cost_rupees || '0'), 0) || 0
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
