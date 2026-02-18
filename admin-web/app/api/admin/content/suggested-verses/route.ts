import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

/**
 * GET - Fetch suggested verses with translations
 */
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const category = searchParams.get('category') || ''
    const language = searchParams.get('language') || ''
    const limit = parseInt(searchParams.get('limit') || '100')

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

    // Fetch suggested verses
    let query = supabaseAdmin
      .from('suggested_verses')
      .select('*')
      .order('display_order', { ascending: true })
      .limit(limit)

    if (category) {
      query = query.eq('category', category)
    }

    const { data: suggestedVerses, error: versesError } = await query

    if (versesError) {
      console.error('Failed to fetch suggested verses:', versesError)
      return NextResponse.json(
        { error: 'Failed to fetch suggested verses' },
        { status: 500 }
      )
    }

    // Fetch translations for all verses
    const verseIds = (suggestedVerses || []).map(v => v.id)
    let translationsQuery = supabaseAdmin
      .from('suggested_verse_translations')
      .select('*')
      .in('suggested_verse_id', verseIds)

    if (language) {
      translationsQuery = translationsQuery.eq('language_code', language)
    }

    const { data: translations } = await translationsQuery

    // Map translations to verses using correct column names (language_code, verse_text, localized_reference)
    const versesWithTranslations = (suggestedVerses || []).map(verse => {
      const verseTranslations = (translations || []).filter(t => t.suggested_verse_id === verse.id)
      return {
        ...verse,
        translations: verseTranslations.reduce((acc, t) => {
          acc[t.language_code] = {
            reference: t.localized_reference,
            text: t.verse_text
          }
          return acc
        }, {} as Record<string, { reference: string; text: string }>)
      }
    })

    // Get statistics
    const stats = {
      total: versesWithTranslations.length,
      by_category: {} as Record<string, number>,
      translation_coverage: {
        en: 0,
        hi: 0,
        ml: 0
      }
    }

    versesWithTranslations.forEach(verse => {
      stats.by_category[verse.category] = (stats.by_category[verse.category] || 0) + 1
      if (verse.translations['en']) stats.translation_coverage.en++
      if (verse.translations['hi']) stats.translation_coverage.hi++
      if (verse.translations['ml']) stats.translation_coverage.ml++
    })

    return NextResponse.json({
      suggested_verses: versesWithTranslations,
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
