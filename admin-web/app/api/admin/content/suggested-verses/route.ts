import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import { fetchAllRows } from '@/lib/supabase/fetch-all-rows'

/**
 * GET - Fetch suggested verses with translations
 */
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const category = searchParams.get('category') || ''
    const language = searchParams.get('language') || ''
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

    // The category filter runs in SQL, so paging and the total both describe
    // the same matching row set.
    const applyFilter = (q: any) => (category ? q.eq('category', category) : q)

    const [versesRes, totalRes] = await Promise.all([
      applyFilter(supabaseAdmin.from('suggested_verses').select('*'))
        .order('display_order', { ascending: true })
        .order('id', { ascending: true })
        .range(offset, offset + limit - 1),
      applyFilter(supabaseAdmin.from('suggested_verses').select('id', { count: 'exact', head: true })),
    ])

    const { data: suggestedVerses, error: versesError } = versesRes

    if (versesError) {
      console.error('Failed to fetch suggested verses:', versesError)
      return NextResponse.json(
        { error: 'Failed to fetch suggested verses' },
        { status: 500 }
      )
    }

    // Fetch translations for all verses
    const verseIds = (suggestedVerses || []).map((v: any) => v.id)
    let translationsQuery = supabaseAdmin
      .from('suggested_verse_translations')
      .select('*')
      .in('suggested_verse_id', verseIds)

    if (language) {
      translationsQuery = translationsQuery.eq('language_code', language)
    }

    const { data: translations } = await translationsQuery

    // Map translations to verses using correct column names (language_code, verse_text, localized_reference)
    const versesWithTranslations = (suggestedVerses || []).map((verse: any) => {
      const verseTranslations = (translations || []).filter((t: any) => t.suggested_verse_id === verse.id)
      return {
        ...verse,
        translations: verseTranslations.reduce((acc: Record<string, { reference: string; text: string }>, t: any) => {
          acc[t.language_code] = {
            reference: t.localized_reference,
            text: t.verse_text
          }
          return acc
        }, {} as Record<string, { reference: string; text: string }>)
      }
    })

    // Statistics cover EVERY suggested verse in the database, not the page.
    // Both reads page past PostgREST's silent 1000-row response cap.
    const [allCategories, allTranslations] = await Promise.all([
      fetchAllRows<{ category: string }>((from, to) =>
        supabaseAdmin
          .from('suggested_verses')
          .select('category')
          .order('id', { ascending: true })
          .range(from, to)
      ),
      fetchAllRows<{ suggested_verse_id: string; language_code: string }>((from, to) =>
        supabaseAdmin
          .from('suggested_verse_translations')
          .select('suggested_verse_id, language_code')
          .order('suggested_verse_id', { ascending: true })
          .range(from, to)
      ),
    ])

    const byCategory: Record<string, number> = {}
    for (const row of allCategories.data || []) {
      byCategory[row.category] = (byCategory[row.category] || 0) + 1
    }

    const coverageSets: Record<string, Set<string>> = { en: new Set(), hi: new Set(), ml: new Set() }
    for (const row of allTranslations.data || []) {
      coverageSets[row.language_code]?.add(row.suggested_verse_id)
    }

    const stats = {
      /** Verses matching the current category filter. */
      total: totalRes.count || 0,
      /** Every suggested verse in the database, ignoring filters. */
      total_all: (allCategories.data || []).length,
      by_category: byCategory,
      translation_coverage: {
        en: coverageSets.en.size,
        hi: coverageSets.hi.size,
        ml: coverageSets.ml.size
      }
    }

    return NextResponse.json({
      suggested_verses: versesWithTranslations,
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
 * POST - Create a new suggested verse with translations
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { category, display_order, translations } = body

    if (!category || !translations || !translations.en) {
      return NextResponse.json(
        { error: 'category and at least English translation are required' },
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

    // Create suggested verse
    const { data: verse, error: verseError } = await supabaseAdmin
      .from('suggested_verses')
      .insert({
        category,
        display_order: display_order || 0
      })
      .select()
      .single()

    if (verseError) {
      console.error('Failed to create suggested verse:', verseError)
      return NextResponse.json(
        { error: 'Failed to create suggested verse' },
        { status: 500 }
      )
    }

    // Create translations using correct column names (language_code, verse_text, localized_reference)
    const translationInserts = Object.entries(translations).map(([lang, data]: [string, any]) => ({
      suggested_verse_id: verse.id,
      language_code: lang,
      localized_reference: data.reference,
      verse_text: data.text
    }))

    const { error: translationsError } = await supabaseAdmin
      .from('suggested_verse_translations')
      .insert(translationInserts)

    if (translationsError) {
      console.error('Failed to create translations:', translationsError)
      // Rollback verse creation
      await supabaseAdmin.from('suggested_verses').delete().eq('id', verse.id)
      return NextResponse.json(
        { error: 'Failed to create translations' },
        { status: 500 }
      )
    }

    return NextResponse.json({ suggested_verse: verse })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

/**
 * PATCH - Update a suggested verse and its translations
 */
export async function PATCH(request: NextRequest) {
  try {
    const body = await request.json()
    const { id, category, display_order, translations } = body

    if (!id) {
      return NextResponse.json(
        { error: 'Suggested verse ID is required' },
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

    // Update suggested verse
    if (category !== undefined || display_order !== undefined) {
      const updates: any = {}
      if (category !== undefined) updates.category = category
      if (display_order !== undefined) updates.display_order = display_order

      const { error: verseError } = await supabaseAdmin
        .from('suggested_verses')
        .update(updates)
        .eq('id', id)

      if (verseError) {
        console.error('Failed to update suggested verse:', verseError)
        return NextResponse.json(
          { error: 'Failed to update suggested verse' },
          { status: 500 }
        )
      }
    }

    // Update translations if provided
    if (translations) {
      // Upsert translations using correct column names (language_code, verse_text, localized_reference)
      for (const [lang, data] of Object.entries(translations) as [string, any][]) {
        await supabaseAdmin
          .from('suggested_verse_translations')
          .upsert({
            suggested_verse_id: id,
            language_code: lang,
            localized_reference: data.reference,
            verse_text: data.text
          }, {
            onConflict: 'suggested_verse_id,language_code'
          })
      }
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

/**
 * DELETE - Delete a suggested verse and its translations
 */
export async function DELETE(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const id = searchParams.get('id')

    if (!id) {
      return NextResponse.json(
        { error: 'Suggested verse ID is required' },
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

    // Delete suggested verse (cascade will handle translations)
    const { error } = await supabaseAdmin
      .from('suggested_verses')
      .delete()
      .eq('id', id)

    if (error) {
      console.error('Failed to delete suggested verse:', error)
      return NextResponse.json(
        { error: 'Failed to delete suggested verse' },
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
