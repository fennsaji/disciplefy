import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import type { LoadStudyGuideResponse, UpdateStudyGuideRequest, UpdateStudyGuideResponse } from '@/types/admin'

/**
 * GET - Load study guide for editing
 */
export async function GET(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params

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

    // Fetch the study guide using admin client
    const { data: studyGuide, error } = await supabaseAdmin
      .from('study_guides')
      .select('*')
      .eq('id', id)
      .single()

    if (error || !studyGuide) {
      console.error('Failed to fetch study guide:', error)
      return NextResponse.json(
        { error: 'Study guide not found' },
        { status: 404 }
      )
    }

    return NextResponse.json({
      study_guide: studyGuide
    } as LoadStudyGuideResponse)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * PUT - Update study guide content
 */
export async function PUT(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params

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
    const body: UpdateStudyGuideRequest = await request.json()

    // Update the study guide using admin client
    const { data: studyGuide, error } = await supabaseAdmin
      .from('study_guides')
      .update(body)
      .eq('id', id)
      .select()
      .single()

    if (error || !studyGuide) {
      console.error('Failed to update study guide:', error)
      return NextResponse.json(
        { error: 'Failed to update study guide' },
        { status: 500 }
      )
    }

    return NextResponse.json({
      study_guide: studyGuide,
      message: 'Study guide updated successfully'
    } as UpdateStudyGuideResponse)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
