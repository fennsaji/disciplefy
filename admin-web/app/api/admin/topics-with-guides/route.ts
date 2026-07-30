import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import { fetchAllRows } from '@/lib/supabase/fetch-all-rows'

/**
 * GET - List topics with their generated study guides count
 * This endpoint combines data from recommended_topics and study_guides tables
 */
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
    const isActive = searchParams.get('is_active')
    const category = searchParams.get('category')
    const inputType = searchParams.get('input_type')

    // Filters run in SQL. Both reads page past PostgREST's silent 1000-row cap,
    // otherwise the per-topic guide counts plateau once a thousand guides exist.
    const applyFilters = (q: any) => {
      if (isActive !== null) q = q.eq('is_active', isActive === 'true')
      if (category) q = q.eq('category', category)
      if (inputType) q = q.eq('input_type', inputType)
      return q
    }

    const { data: topics, error: topicsError } = await fetchAllRows<any>((from, to) =>
      applyFilters(supabaseAdmin.from('recommended_topics').select('*'))
        .order('display_order', { ascending: true })
        .order('id', { ascending: true })
        .range(from, to)
    )

    if (topicsError) {
      console.error('Failed to fetch topics:', topicsError)
      return NextResponse.json(
        { error: 'Failed to fetch topics' },
        { status: 500 }
      )
    }

    // Fetch all study guides for these topics
    const topicIds = topics?.map((t: any) => t.id) || []

    let guidesData: any[] = []
    if (topicIds.length > 0) {
      const { data: guides, error: guidesError } = await fetchAllRows<any>((from, to) =>
        supabaseAdmin
          .from('study_guides')
          .select('topic_id, study_mode, language, created_at')
          .in('topic_id', topicIds)
          .order('id', { ascending: true })
          .range(from, to)
      )

      if (guidesError) {
        console.error('Failed to fetch study guides:', guidesError)
        // Don't fail the whole request, just return topics without guide counts
        guidesData = []
      } else {
        guidesData = guides || []
      }
    }

    // Combine topics with their guide counts
    const topicsWithGuides = topics?.map((topic: any) => {
      const topicGuides = guidesData.filter(g => g.topic_id === topic.id)

      // Count guides by mode
      const guidesByMode = topicGuides.reduce((acc: Record<string, number>, guide) => {
        acc[guide.study_mode] = (acc[guide.study_mode] || 0) + 1
        return acc
      }, {})

      // Count guides by language
      const guidesByLanguage = topicGuides.reduce((acc: Record<string, number>, guide) => {
        acc[guide.language] = (acc[guide.language] || 0) + 1
        return acc
      }, {})

      return {
        ...topic,
        generated_guides_count: topicGuides.length,
        guides_by_mode: guidesByMode,
        guides_by_language: guidesByLanguage,
        has_guides: topicGuides.length > 0,
        latest_guide_created: topicGuides.length > 0
          ? topicGuides.sort((a, b) =>
              new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
            )[0].created_at
          : null
      }
    }) || []

    return NextResponse.json({
      topics: topicsWithGuides,
      total_count: topicsWithGuides.length,
    })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
