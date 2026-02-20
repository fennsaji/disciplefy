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
    const content = body.content

    // Map content fields to actual flat DB columns (no JSONB 'content' column exists)
    const updateData: Record<string, unknown> = {
      updated_at: new Date().toISOString(),
    }

    if (content.summary !== undefined) updateData.summary = content.summary
    if (content.context !== undefined) updateData.context = content.context
    if (content.interpretation !== undefined) updateData.interpretation = content.interpretation
    if (content.passage !== undefined) updateData.passage = content.passage

    const relatedVerses = content.relatedVerses ?? content.related_verses
    if (relatedVerses !== undefined) updateData.related_verses = relatedVerses

    const reflectionQuestions = content.reflectionQuestions ?? content.reflection_questions
    if (reflectionQuestions !== undefined) updateData.reflection_questions = reflectionQuestions

    const prayerPoints = content.prayerPoints ?? content.prayer_points
    if (prayerPoints !== undefined) updateData.prayer_points = prayerPoints

    const interpretationInsights = content.interpretationInsights ?? content.interpretation_insights
    if (interpretationInsights !== undefined) updateData.interpretation_insights = interpretationInsights

    const summaryInsights = content.summaryInsights ?? content.summary_insights
    if (summaryInsights !== undefined) updateData.summary_insights = summaryInsights

    const reflectionAnswers = content.reflectionAnswers ?? content.reflection_answers
    if (reflectionAnswers !== undefined) updateData.reflection_answers = reflectionAnswers

    if (content.contextQuestion !== undefined) updateData.context_question = content.contextQuestion
    else if (content.context_question !== undefined) updateData.context_question = content.context_question

    if (content.summaryQuestion !== undefined) updateData.summary_question = content.summaryQuestion
    else if (content.summary_question !== undefined) updateData.summary_question = content.summary_question

    // Update the study guide using admin client (separate update + fetch to avoid PGRST116)
    const { error: updateError } = await supabaseAdmin
      .from('study_guides')
      .update(updateData)
      .eq('id', id)

    if (updateError) {
      console.error('Failed to update study guide:', JSON.stringify(updateError))
      return NextResponse.json(
        { error: 'Failed to update study guide', detail: updateError.message, code: updateError.code },
        { status: 500 }
      )
    }

    // Fetch the updated guide separately
    const { data: studyGuide } = await supabaseAdmin
      .from('study_guides')
      .select('*')
      .eq('id', id)
      .single()

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
