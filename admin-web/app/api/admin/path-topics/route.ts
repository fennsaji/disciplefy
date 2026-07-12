import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import type { AddTopicToPathRequest, AddTopicToPathResponse, RemoveTopicFromPathRequest, RemoveTopicFromPathResponse } from '@/types/admin'

/**
 * POST - Add topic to learning path
 */
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
    const body: AddTopicToPathRequest = await request.json()

    // Call the admin-learning-path-topics Edge Function
    // (forwards the user's JWT — the Edge Function verifies admin identity itself)
    const { data, error } = await supabaseUser.functions.invoke('admin-learning-path-topics', {
      method: 'POST',
      body,
    })

    if (error) {
      console.error('Supabase function error:', error)
      return NextResponse.json(
        { error: error.message || 'Failed to add topic to path' },
        { status: 500 }
      )
    }

    return NextResponse.json(data as AddTopicToPathResponse, { status: 201 })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * DELETE - Remove topic from learning path
 */
export async function DELETE(request: NextRequest) {
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
    const body: RemoveTopicFromPathRequest = await request.json()

    // Call the admin-learning-path-topics Edge Function
    // (forwards the user's JWT — the Edge Function verifies admin identity itself)
    const { data, error } = await supabaseUser.functions.invoke('admin-learning-path-topics', {
      method: 'DELETE',
      body,
    })

    if (error) {
      console.error('Supabase function error:', error)
      return NextResponse.json(
        { error: error.message || 'Failed to remove topic from path' },
        { status: error.message?.includes('not found') ? 404 : 500 }
      )
    }

    return NextResponse.json(data as RemoveTopicFromPathResponse)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
