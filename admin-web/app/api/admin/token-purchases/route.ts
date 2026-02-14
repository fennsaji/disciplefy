import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch token purchase history with filtering options
 */
export async function GET(request: NextRequest) {
  try {
    // Parse query parameters
    const searchParams = request.nextUrl.searchParams
    const range = searchParams.get('range') || 'today'
    const status = searchParams.get('status') || ''
    const search = searchParams.get('search') || ''

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

    // Calculate date filter based on range
    let dateFilter: Date
    const now = new Date()

    switch (range) {
      case 'today':
        dateFilter = new Date()
        dateFilter.setHours(0, 0, 0, 0)
        break
      case 'week':
        dateFilter = new Date()
        dateFilter.setDate(now.getDate() - 7)
        dateFilter.setHours(0, 0, 0, 0)
        break
      case 'month':
        dateFilter = new Date()
        dateFilter.setMonth(now.getMonth() - 1)
        dateFilter.setHours(0, 0, 0, 0)
        break
      case 'all':
      default:
        dateFilter = new Date(0) // Epoch
        break
    }

    // Fetch purchase history without joins
    let query = supabaseAdmin
      .from('purchase_history')
      .select('*')
      .gte('purchased_at', dateFilter.toISOString())

    // Apply status filter
    if (status) {
      query = query.eq('status', status)
    }

    // Execute query with ordering and limit
    const { data: purchases, error: purchasesError } = await query
      .order('purchased_at', { ascending: false })
      .limit(500)

    if (purchasesError) {
      console.error('Failed to fetch purchases:', purchasesError)
      return NextResponse.json(
        { error: 'Failed to fetch purchases' },
        { status: 500 }
      )
    }

    if (!purchases || purchases.length === 0) {
      return NextResponse.json({
        purchases: [],
        summary: {
          total_purchases: 0,
          total_tokens_sold: 0,
          total_revenue: 0
        }
      })
    }

    // Extract unique user IDs
    const userIds = [...new Set(purchases.map(p => p.user_id))]

    // Fetch emails from auth.users
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.listUsers()
    if (authError) {
      console.error('Failed to fetch auth users:', authError)
      return NextResponse.json(
        { error: 'Failed to fetch user emails' },
        { status: 500 }
      )
    }

    const emailsMap = Object.fromEntries(
      authData.users
        .filter(u => userIds.includes(u.id))
        .map(u => [u.id, u.email || ''])
    )

    // Fetch user profiles for names
    const { data: userProfiles, error: profilesError } = await supabaseAdmin
      .from('user_profiles')
      .select('id, first_name, last_name')
      .in('id', userIds)

    if (profilesError) {
      console.error('Failed to fetch user profiles:', profilesError)
    }

    const profilesMap = Object.fromEntries(
      (userProfiles || []).map(p => [
        p.id,
        [p.first_name, p.last_name].filter(Boolean).join(' ') || 'Unknown',
      ])
    )

    // Apply search filter manually (email or payment_id)
    let filteredPurchases = purchases
    if (search) {
      const searchLower = search.toLowerCase()
      filteredPurchases = purchases.filter(p =>
        emailsMap[p.user_id]?.toLowerCase().includes(searchLower) ||
        p.payment_id?.toLowerCase() === searchLower
      )
    }

    // Format response
    const formattedPurchases = filteredPurchases.map(purchase => ({
      id: purchase.id,
      user_id: purchase.user_id,
      user_email: emailsMap[purchase.user_id] || null,
      user_name: profilesMap[purchase.user_id] || null,
      token_amount: purchase.token_amount,
      cost_rupees: purchase.cost_rupees,
      cost_paise: purchase.cost_paise,
      payment_id: purchase.payment_id,
      order_id: purchase.order_id,
      payment_method: purchase.payment_method,
      payment_provider: purchase.payment_provider,
      status: purchase.status,
      receipt_number: purchase.receipt_number,
      receipt_url: purchase.receipt_url,
      purchased_at: purchase.purchased_at,
      created_at: purchase.created_at
    }))

    // Calculate summary
    const totalPurchases = formattedPurchases.length
    const totalTokensSold = formattedPurchases.reduce((sum, p) => sum + (p.token_amount || 0), 0)
    const totalRevenue = formattedPurchases
      .filter(p => p.status === 'completed')
      .reduce((sum, p) => sum + parseFloat(p.cost_rupees || '0'), 0)

    return NextResponse.json({
      purchases: formattedPurchases,
      summary: {
        total_purchases: totalPurchases,
        total_tokens_sold: totalTokensSold,
        total_revenue: totalRevenue
      }
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
