import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

const RS_BACKEND_URL = process.env.RS_BACKEND_URL || 'http://localhost:8080'

async function verifyAdminAndGetToken(request: NextRequest) {
  const supabase = await createClient()
  const { data: { user }, error } = await supabase.auth.getUser()
  if (error || !user) return { error: 'Unauthorized', status: 401, token: null }

  const supabaseAdmin = await createAdminClient()
  const { data: profile } = await supabaseAdmin
    .from('user_profiles')
    .select('is_admin')
    .eq('id', user.id)
    .single()

  if (!profile?.is_admin) return { error: 'Unauthorized - Admin access required', status: 403, token: null }

  const { data: { session } } = await supabase.auth.getSession()
  return { error: null, status: 200, token: session?.access_token ?? null, userId: user.id }
}

/**
 * GET - List all blog posts (all statuses) via Supabase admin client
 */
export async function GET(request: NextRequest) {
  try {
    const supabase = await createClient()
    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const supabaseAdmin = await createAdminClient()
    const { data: profile } = await supabaseAdmin
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()

    if (!profile?.is_admin) {
      return NextResponse.json({ error: 'Unauthorized - Admin access required' }, { status: 403 })
    }

    const { searchParams } = new URL(request.url)
    const locale = searchParams.get('locale')
    const status = searchParams.get('status')
    const page = parseInt(searchParams.get('page') || '1', 10)
    const limit = Math.min(parseInt(searchParams.get('limit') || '50', 10), 100)
    const offset = (page - 1) * limit

    let query = supabaseAdmin
      .from('blog_posts')
      .select('id, slug, title, excerpt, author, locale, tags, featured, status, source_type, created_at, published_at', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1)

    if (locale) query = query.eq('locale', locale)
    if (status) query = query.eq('status', status)

    const { data: posts, error: dbError, count } = await query

    if (dbError) {
      console.error('DB error listing blog posts:', dbError)
      return NextResponse.json({ error: 'Failed to list blog posts' }, { status: 500 })
    }

    return NextResponse.json({ posts: posts ?? [], total: count ?? 0 })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

/**
 * POST - Create a new blog post via RS backend
 */
export async function POST(request: NextRequest) {
  try {
    const auth = await verifyAdminAndGetToken(request)
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status })
    if (!auth.token) return NextResponse.json({ error: 'No session token' }, { status: 401 })

    const body = await request.json()

    const rsResponse = await fetch(`${RS_BACKEND_URL}/api/v1/admin/posts`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${auth.token}`,
      },
      body: JSON.stringify(body),
    })

    const data = await rsResponse.json().catch(() => ({ error: 'Unknown error' }))
    if (!rsResponse.ok) {
      console.error('RS backend error:', rsResponse.status, data)
      return NextResponse.json({ error: data.message || 'Failed to create blog post' }, { status: rsResponse.status })
    }

    return NextResponse.json({ post: data.data }, { status: 201 })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
