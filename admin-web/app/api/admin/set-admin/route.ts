import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

export async function POST(request: NextRequest) {
  try {
    const supabase = await createClient()
    const { data: { user }, error: userError } = await supabase.auth.getUser()

    if (userError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const supabaseAdmin = createAdminClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    )

    const { data: callerProfile } = await supabaseAdmin
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()

    if (!callerProfile?.is_admin) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const body: { userId: string; isAdmin: boolean } = await request.json()

    if (!body.userId || typeof body.isAdmin !== 'boolean') {
      return NextResponse.json({ error: 'Invalid request body' }, { status: 400 })
    }

    // Prevent an admin from revoking their own access
    if (!body.isAdmin && body.userId === user.id) {
      return NextResponse.json(
        { error: 'You cannot revoke your own admin access' },
        { status: 400 }
      )
    }

    // Verify the target user exists
    const { data: targetProfile } = await supabaseAdmin
      .from('user_profiles')
      .select('id, first_name, last_name')
      .eq('id', body.userId)
      .single()

    if (!targetProfile) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 })
    }

    const { error: updateError } = await supabaseAdmin
      .from('user_profiles')
      .update({ is_admin: body.isAdmin })
      .eq('id', body.userId)

    if (updateError) {
      return NextResponse.json({ error: updateError.message }, { status: 500 })
    }

    const action = body.isAdmin ? 'granted' : 'revoked'
    const fullName = [targetProfile.first_name, targetProfile.last_name]
      .filter(Boolean)
      .join(' ')

    return NextResponse.json({
      success: true,
      message: `Admin access ${action} for ${fullName || body.userId}`,
    })
  } catch (err) {
    console.error('[set-admin]', err)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
