import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch study guides library with filtering
 */
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const inputType = searchParams.get('input_type') || ''
    const studyMode = searchParams.get('study_mode') || ''
    const language = searchParams.get('language') || ''
    const limit = parseInt(searchParams.get('limit') || '50')

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

    // Build query with filters
    let query = supabaseAdmin
      .from('study_guides')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(limit)

    if (inputType) {
      query = query.eq('input_type', inputType)
    }
    if (studyMode) {
      query = query.eq('study_mode', studyMode)
    }
    if (language) {
      query = query.eq('language', language)
    }

    const { data: studyGuides, error: guidesError } = await query

    if (guidesError) {
      console.error('Failed to fetch study guides:', guidesError)
      return NextResponse.json(
        { error: 'Failed to fetch study guides' },
        { status: 500 }
      )
    }

    // Get usage statistics
    const { data: userGuides } = await supabaseAdmin
      .from('user_study_guides')
      .select('study_guide_id, status, user_id')

    // Map usage stats to study guides
    const guidesWithStats = (studyGuides || []).map(guide => {
      const usageStats = (userGuides || []).filter(ug => ug.study_guide_id === guide.id)
      return {
        ...guide,
        total_users: new Set(usageStats.map(ug => ug.user_id)).size,
        completed_count: usageStats.filter(ug => ug.status === 'completed').length,
        in_progress_count: usageStats.filter(ug => ug.status === 'in_progress').length,
      }
    })

    // Get statistics
    const stats = {
      total: guidesWithStats.length,
      by_input_type: {} as Record<string, number>,
      by_study_mode: {} as Record<string, number>,
      by_language: {} as Record<string, number>,
    }

    guidesWithStats.forEach(guide => {
      stats.by_input_type[guide.input_type] = (stats.by_input_type[guide.input_type] || 0) + 1
      stats.by_study_mode[guide.study_mode || 'standard'] = (stats.by_study_mode[guide.study_mode || 'standard'] || 0) + 1
      stats.by_language[guide.language] = (stats.by_language[guide.language] || 0) + 1
    })

    return NextResponse.json({
      study_guides: guidesWithStats,
      stats
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * PATCH - Update a study guide
 */
export async function PATCH(request: NextRequest) {
  try {
    const body = await request.json()
    const { id, ...updates } = body

    if (!id) {
      return NextResponse.json(
        { error: 'Study guide ID is required' },
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

    // Update study guide
    const { data, error } = await supabaseAdmin
      .from('study_guides')
      .update({
        ...updates,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single()

    if (error) {
      console.error('Failed to update study guide:', error)
      return NextResponse.json(
        { error: 'Failed to update study guide' },
        { status: 500 }
      )
    }

    return NextResponse.json({ study_guide: data })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * DELETE - Delete a study guide
 */
export async function DELETE(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const id = searchParams.get('id')

    if (!id) {
      return NextResponse.json(
        { error: 'Study guide ID is required' },
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

    // Delete study guide (cascade will handle user_study_guides)
    const { error } = await supabaseAdmin
      .from('study_guides')
      .delete()
      .eq('id', id)

    if (error) {
      console.error('Failed to delete study guide:', error)
      return NextResponse.json(
        { error: 'Failed to delete study guide' },
        { status: 500 }
      )
    }

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
