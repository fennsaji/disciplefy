import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

interface AdjustTokensRequest {
  identifier: string
  amount: number
  reason: string
  type: 'add' | 'remove'
}

/**
 * POST - Adjust user token balance (add or remove tokens)
 */
export async function POST(request: NextRequest) {
  try {
    // Parse request body
    const body: AdjustTokensRequest = await request.json()
    const { identifier, amount, reason, type } = body

    // Validate input
    if (!identifier || !amount || !reason || !type) {
      return NextResponse.json(
        { error: 'Missing required fields: identifier, amount, reason, type' },
        { status: 400 }
      )
    }

    if (type !== 'add' && type !== 'remove') {
      return NextResponse.json(
        { error: 'Type must be either "add" or "remove"' },
        { status: 400 }
      )
    }

    if (amount <= 0) {
      return NextResponse.json(
        { error: 'Amount must be greater than 0' },
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

    // Fetch current token balance
    const { data: currentBalance, error: balanceError } = await supabaseAdmin
      .from('user_tokens')
      .select('purchased_tokens, available_tokens')
      .eq('identifier', identifier)
      .single()

    if (balanceError || !currentBalance) {
      return NextResponse.json(
        { error: 'User token record not found' },
        { status: 404 }
      )
    }

    // Calculate new balance
    let newPurchasedTokens: number

    if (type === 'add') {
      newPurchasedTokens = currentBalance.purchased_tokens + amount
    } else {
      // Remove tokens, but don't go below 0
      newPurchasedTokens = Math.max(0, currentBalance.purchased_tokens - amount)
    }

    // Update token balance
    const { data: updatedBalance, error: updateError } = await supabaseAdmin
      .from('user_tokens')
      .update({
        purchased_tokens: newPurchasedTokens,
        updated_at: new Date().toISOString()
      })
      .eq('identifier', identifier)
      .select('purchased_tokens, available_tokens')
      .single()

    if (updateError) {
      console.error('Failed to update token balance:', updateError)
      return NextResponse.json(
        { error: 'Failed to update token balance' },
        { status: 500 }
      )
    }

    // Log admin action for audit trail
    const { error: logError } = await supabaseAdmin
      .from('admin_actions')
      .insert({
        admin_user_id: user.id,
        action_type: 'adjust_tokens',
        target_user_id: identifier,
        details: {
          type,
          amount,
          reason,
          previous_balance: currentBalance.purchased_tokens,
          new_balance: updatedBalance.purchased_tokens
        }
      })

    if (logError) {
      console.error('Failed to log admin action:', logError)
      // Don't fail the request if logging fails
    }

    return NextResponse.json({
      success: true,
      new_balance: {
        available_tokens: updatedBalance.available_tokens,
        purchased_tokens: updatedBalance.purchased_tokens
      },
      message: `Successfully ${type === 'add' ? 'added' : 'removed'} ${amount} tokens`
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
