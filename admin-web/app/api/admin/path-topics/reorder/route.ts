import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import type { ReorderTopicsRequest, ReorderTopicsResponse } from '@/types/admin'

/**
 * PATCH - Reorder topics in learning path
 */
export async function PATCH(request: NextRequest) {
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
    const body: ReorderTopicsRequest = await request.json()

    // Call the admin-learning-path-topics Edge Function
    // (forwards the user's JWT — the Edge Function verifies admin identity itself)
    const { data, error } = await supabaseUser.functions.invoke('admin-learning-path-topics/reorder', {
      method: 'PATCH',
      body,
    })

    if (error) {
      console.error('Supabase function error:', error)
      return NextResponse.json(
        { error: error.message || 'Failed to reorder topics' },
        { status: 500 }
      )
    }

    return NextResponse.json(data as ReorderTopicsResponse)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
