import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import { NextRequest, NextResponse } from 'next/server'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ issueId: string }> }
) {
  try {
    // Await params (Next.js 15+ requirement)
    const { issueId } = await params

    // Verify user authentication
    const supabaseUser = await createClient()
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()

    if (userError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // Create admin client with service role key
    const supabaseAdmin = createAdminClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    )

    // Check if user is admin
    const { data: profile } = await supabaseAdmin
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()

    if (!profile?.is_admin) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    // Fetch the purchase issue
    const { data: issue, error: issueError } = await supabaseAdmin
      .from('purchase_issue_reports')
      .select('*')
      .eq('id', issueId)
      .single()

    if (issueError || !issue) {
      console.error('Issue fetch error:', issueError)
      return NextResponse.json({ error: 'Issue not found' }, { status: 404 })
    }

    // Fetch user email from auth
    let userEmail = null
    if (issue.user_id) {
      const { data: authData } = await supabaseAdmin.auth.admin.listUsers()
      const authUser = authData?.users.find(u => u.id === issue.user_id)
      userEmail = authUser?.email || null
    }

    // Add user email to issue object
    const issueWithEmail = {
      ...issue,
      user_email: userEmail,
    }

    // Fetch database payment record - try purchase_id first, then payment_id
    let dbPayment = null

    // First, try to get from purchase_history using purchase_id
    if (issue.purchase_id) {
      const { data: purchase } = await supabaseAdmin
        .from('purchase_history')
        .select('*')
        .eq('id', issue.purchase_id)
        .single()

      dbPayment = purchase
    }

    // If not found, try pending_token_purchases using payment_id
    if (!dbPayment && issue.payment_id) {
      const { data: pending } = await supabaseAdmin
        .from('pending_token_purchases')
        .select('*')
        .eq('razorpay_payment_id', issue.payment_id)
        .single()

      dbPayment = pending
    }

    // Fetch purchase history for this user (excluding current purchase)
    let purchaseHistory = []
    if (issue.user_id) {
      const { data: history } = await supabaseAdmin
        .from('purchase_history')
        .select('*')
        .eq('user_id', issue.user_id)
        .order('processed_at', { ascending: false })
        .limit(10)

      purchaseHistory = history || []
    }

    // Fetch Razorpay payment details if payment_id exists
    let razorpayPayment = null
    if (issue.payment_id) {
      try {
        const razorpayKeyId = process.env.RAZORPAY_KEY_ID
        const razorpayKeySecret = process.env.RAZORPAY_KEY_SECRET

        console.log('[PURCHASE ISSUE] Razorpay credentials:', {
          hasKeyId: !!razorpayKeyId,
          hasKeySecret: !!razorpayKeySecret,
          keyIdLength: razorpayKeyId?.length || 0
        })

        if (razorpayKeyId && razorpayKeySecret) {
          const auth = Buffer.from(`${razorpayKeyId}:${razorpayKeySecret}`).toString('base64')

          const paymentResponse = await fetch(
            `https://api.razorpay.com/v1/payments/${issue.payment_id}`,
            {
              headers: {
                Authorization: `Basic ${auth}`,
              },
            }
          )

          console.log('[PURCHASE ISSUE] Razorpay payment API response:', paymentResponse.status)

          if (paymentResponse.ok) {
            razorpayPayment = await paymentResponse.json()
          } else {
            const errorText = await paymentResponse.text()
            console.error('[PURCHASE ISSUE] Razorpay payment API error:', errorText)
          }
        } else {
          console.warn('[PURCHASE ISSUE] Razorpay credentials not configured')
        }
      } catch (error) {
        console.error('[PURCHASE ISSUE] Error fetching Razorpay payment:', error)
        // Continue without Razorpay data
      }
    }

    // Fetch Razorpay order details if order_id exists
    let razorpayOrder = null
    if (issue.order_id) {
      try {
        const razorpayKeyId = process.env.RAZORPAY_KEY_ID
        const razorpayKeySecret = process.env.RAZORPAY_KEY_SECRET

        if (razorpayKeyId && razorpayKeySecret) {
          const auth = Buffer.from(`${razorpayKeyId}:${razorpayKeySecret}`).toString('base64')

          const orderResponse = await fetch(
            `https://api.razorpay.com/v1/orders/${issue.order_id}`,
            {
              headers: {
                Authorization: `Basic ${auth}`,
              },
            }
          )

          console.log('[PURCHASE ISSUE] Razorpay order API response:', orderResponse.status)

          if (orderResponse.ok) {
            razorpayOrder = await orderResponse.json()
          } else {
            const errorText = await orderResponse.text()
            console.error('[PURCHASE ISSUE] Razorpay order API error:', errorText)
          }
        }
      } catch (error) {
        console.error('[PURCHASE ISSUE] Error fetching Razorpay order:', error)
        // Continue without Razorpay data
      }
    }

    return NextResponse.json({
      issue: issueWithEmail,
      dbPayment,
      razorpayPayment,
      razorpayOrder,
      purchaseHistory,
    })
  } catch (error) {
    console.error('Error fetching purchase issue details:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
