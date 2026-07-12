import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import type { ToggleMilestoneRequest, ToggleMilestoneResponse } from '@/types/admin'

/**
 * PATCH - Toggle milestone flag for topic in path
 */
export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ pathId: string; topicId: string }> }
) {
  try {
    const { pathId, topicId } = await params

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
    const body: ToggleMilestoneRequest = await request.json()

    // Call the admin-learning-path-topics Edge Function
    // (forwards the user's JWT — the Edge Function verifies admin identity itself)
    const { data, error } = await supabaseUser.functions.invoke(
      `admin-learning-path-topics/${pathId}/${topicId}/milestone`,
      {
        method: 'PATCH',
        body,
      }
    )

    if (error) {
      console.error('Supabase function error:', error)
      return NextResponse.json(
        { error: error.message || 'Failed to toggle milestone' },
        { status: error.message?.includes('not found') ? 404 : 500 }
      )
    }

    return NextResponse.json(data as ToggleMilestoneResponse)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
