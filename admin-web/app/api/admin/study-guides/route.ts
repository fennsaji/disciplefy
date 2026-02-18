import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

export async function GET(request: NextRequest) {
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

    // Get query parameters
    const { searchParams } = new URL(request.url)
    const topicId = searchParams.get('topic_id')
    const pathId = searchParams.get('path_id')
    const language = searchParams.get('language')
    const studyMode = searchParams.get('study_mode')

    // Build query
    let query = supabaseAdmin
      .from('study_guides')
      .select('*')
      .order('created_at', { ascending: false })

    // Apply filters
    if (topicId) {
      query = query.eq('topic_id', topicId)
    }

    if (pathId) {
      query = query.eq('learning_path_id', pathId)
    }

    if (language) {
      query = query.eq('language', language)
    }

    if (studyMode) {
      query = query.eq('study_mode', studyMode)
    }

    const { data, error } = await query

    if (error) {
      console.error('Failed to fetch study guides:', error)
      return NextResponse.json(
        { error: 'Failed to fetch study guides' },
        { status: 500 }
      )
    }

    return NextResponse.json({
      study_guides: data || [],
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
