import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch daily verses cache
 */
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const language = searchParams.get('language') || ''
    const isActive = searchParams.get('is_active') || ''
    const limit = parseInt(searchParams.get('limit') || '30')

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
      .from('daily_verses_cache')
      .select('*')
      .order('date_key', { ascending: false })
      .limit(limit)

    if (language) {
      query = query.eq('language', language)
    }
    if (isActive) {
      query = query.eq('is_active', isActive === 'true')
    }

    const { data: dailyVerses, error: versesError } = await query

    if (versesError) {
      console.error('Failed to fetch daily verses:', versesError)
      return NextResponse.json(
        { error: 'Failed to fetch daily verses' },
        { status: 500 }
      )
    }

    // Get current active verse for each language
    const { data: activeVerses } = await supabaseAdmin
      .from('daily_verses_cache')
      .select('*')
      .eq('is_active', true)
      .order('date_key', { ascending: false })

    // Get statistics
    const stats = {
      total: dailyVerses?.length || 0,
      active: activeVerses?.length || 0,
      by_language: {} as Record<string, number>,
      upcoming_count: (dailyVerses || []).filter(v => new Date(v.date_key) > new Date()).length,
      past_count: (dailyVerses || []).filter(v => new Date(v.date_key) < new Date()).length,
    }

    ;(dailyVerses || []).forEach(verse => {
      stats.by_language[verse.language] = (stats.by_language[verse.language] || 0) + 1
    })

    return NextResponse.json({
      daily_verses: dailyVerses,
      active_verses: activeVerses,
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
