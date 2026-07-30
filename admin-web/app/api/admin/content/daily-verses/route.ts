import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import { fetchAllRows } from '@/lib/supabase/fetch-all-rows'

/**
 * GET - Fetch daily verses cache
 */
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const language = searchParams.get('language') || ''
    const isActive = searchParams.get('is_active') || ''
    const limit = Math.min(Math.max(parseInt(searchParams.get('limit') || '50', 10) || 50, 1), 200)
    const offset = Math.max(parseInt(searchParams.get('offset') || '0', 10) || 0, 0)

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

    // Filters run in SQL, so the page, the total and the stats all describe the
    // same row set. Counts come from Postgres — never from the returned page.
    const applyFilters = (q: any) => {
      if (language) q = q.eq('language', language)
      if (isActive) q = q.eq('is_active', isActive === 'true')
      return q
    }

    const todayKey = new Date().toISOString().slice(0, 10)

    const [versesRes, totalRes, activeRes, upcomingRes, pastRes, languageRows] = await Promise.all([
      applyFilters(supabaseAdmin.from('daily_verses_cache').select('*'))
        .order('date_key', { ascending: false })
        .order('id', { ascending: true })
        .range(offset, offset + limit - 1),
      applyFilters(
        supabaseAdmin.from('daily_verses_cache').select('id', { count: 'exact', head: true })
      ),
      applyFilters(
        supabaseAdmin.from('daily_verses_cache').select('id', { count: 'exact', head: true })
      ).eq('is_active', true),
      applyFilters(
        supabaseAdmin.from('daily_verses_cache').select('id', { count: 'exact', head: true })
      ).gt('date_key', todayKey),
      applyFilters(
        supabaseAdmin.from('daily_verses_cache').select('id', { count: 'exact', head: true })
      ).lt('date_key', todayKey),
      fetchAllRows<{ language: string }>((from, to) =>
        applyFilters(supabaseAdmin.from('daily_verses_cache').select('language'))
          .order('id', { ascending: true })
          .range(from, to)
      ),
    ])

    const { data: dailyVerses, error: versesError } = versesRes

    if (versesError) {
      console.error('Failed to fetch daily verses:', versesError)
      return NextResponse.json(
        { error: 'Failed to fetch daily verses' },
        { status: 500 }
      )
    }

    // The currently active verse per language (one row each, so no paging needed)
    const { data: activeVerses } = await supabaseAdmin
      .from('daily_verses_cache')
      .select('*')
      .eq('is_active', true)
      .order('date_key', { ascending: false })
      .limit(50)

    const byLanguage: Record<string, number> = {}
    for (const row of languageRows.data || []) {
      byLanguage[row.language] = (byLanguage[row.language] || 0) + 1
    }

    const stats = {
      total: totalRes.count || 0,
      active: activeRes.count || 0,
      by_language: byLanguage,
      upcoming_count: upcomingRes.count || 0,
      past_count: pastRes.count || 0,
    }

    return NextResponse.json({
      daily_verses: dailyVerses,
      active_verses: activeVerses,
      total: stats.total,
      limit,
      offset,
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
 * POST - Create or update a daily verse
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { date_key, language, verse_data, is_active } = body

    if (!date_key || !language || !verse_data) {
      return NextResponse.json(
        { error: 'date_key, language, and verse_data are required' },
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

    // Upsert daily verse
    const { data, error } = await supabaseAdmin
      .from('daily_verses_cache')
      .upsert({
        date_key,
        language,
        verse_data,
        is_active: is_active !== undefined ? is_active : true,
        updated_at: new Date().toISOString()
      }, {
        onConflict: 'date_key,language'
      })
      .select()
      .single()

    if (error) {
      console.error('Failed to upsert daily verse:', error)
      return NextResponse.json(
        { error: 'Failed to save daily verse' },
        { status: 500 }
      )
    }

    return NextResponse.json({ daily_verse: data })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * PATCH - Toggle active status
 */
export async function PATCH(request: NextRequest) {
  try {
    const body = await request.json()
    const { id, is_active } = body

    if (!id) {
      return NextResponse.json(
        { error: 'Daily verse ID is required' },
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

    // Update daily verse
    const { data, error } = await supabaseAdmin
      .from('daily_verses_cache')
      .update({
        is_active,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single()

    if (error) {
      console.error('Failed to update daily verse:', error)
      return NextResponse.json(
        { error: 'Failed to update daily verse' },
        { status: 500 }
      )
    }

    return NextResponse.json({ daily_verse: data })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * DELETE - Delete a daily verse
 */
export async function DELETE(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const id = searchParams.get('id')

    if (!id) {
      return NextResponse.json(
        { error: 'Daily verse ID is required' },
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

    // Delete daily verse
    const { error } = await supabaseAdmin
      .from('daily_verses_cache')
      .delete()
      .eq('id', id)

    if (error) {
      console.error('Failed to delete daily verse:', error)
      return NextResponse.json(
        { error: 'Failed to delete daily verse' },
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
