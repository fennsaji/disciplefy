import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import type { ListStudyGuidesResponse } from '@/types/admin'

/**
 * GET - List topics with optional filtering
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
    const input_type = searchParams.get('input_type') || undefined
    const study_mode = searchParams.get('study_mode') || undefined
    const language = searchParams.get('language') || undefined
    const search = searchParams.get('search') || undefined

    // Build URL with query params
    const params = new URLSearchParams()
    if (input_type) params.append('input_type', input_type)
    if (study_mode) params.append('study_mode', study_mode)
    if (language) params.append('language', language)
    if (search) params.append('search', search)

    const functionUrl = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/admin-study-guides${params.toString() ? `?${params.toString()}` : ''}`

    const response = await fetch(functionUrl, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
        'x-admin-user-id': user.id,
      },
    })

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({ error: 'Unknown error' }))
      console.error('[Topics API] Edge Function error:', response.status, errorData)
      return NextResponse.json(
        { error: errorData.error || 'Failed to list topics' },
        { status: response.status }
      )
    }

    const data = await response.json()
    console.log('[Study Guides API] Success, returning data:', { guidesCount: data?.study_guides?.length || 0 })
    return NextResponse.json(data as ListStudyGuidesResponse)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

