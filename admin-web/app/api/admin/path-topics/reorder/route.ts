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

    // Call Edge Function using service role key
    const functionUrl = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/admin-learning-paths/topics/reorder`

    const response = await fetch(functionUrl, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
        'x-admin-user-id': user.id,
      },
      body: JSON.stringify(body),
    })

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({ error: 'Unknown error' }))
      console.error('Edge Function error:', response.status, errorData)
      return NextResponse.json(
        { error: errorData.error || 'Failed to reorder topics' },
        { status: response.status }
      )
    }

    const data = await response.json()
    return NextResponse.json(data as ReorderTopicsResponse)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
