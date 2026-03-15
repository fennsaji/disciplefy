import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

const RS_BACKEND_URL = process.env.RS_BACKEND_URL || 'http://localhost:8080'

async function verifyAdminAndGetToken() {
  const supabase = await createClient()
  const { data: { user }, error } = await supabase.auth.getUser()
  if (error || !user) return { error: 'Unauthorized', status: 401, token: null, userId: null }

  const supabaseAdmin = await createAdminClient()
  const { data: profile } = await supabaseAdmin
    .from('user_profiles')
    .select('is_admin')
    .eq('id', user.id)
    .single()

  if (!profile?.is_admin) return { error: 'Unauthorized - Admin access required', status: 403, token: null, userId: null }

  const { data: { session } } = await supabase.auth.getSession()
  return { error: null, status: 200, token: session?.access_token ?? null, userId: user.id, supabaseAdmin }
}

/**
 * GET - Get a single blog post by ID (including drafts)
 */
export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
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

    const { data: post, error: dbError } = await supabaseAdmin
      .from('blog_posts')
      .select('*')
      .eq('id', id)
      .single()

    if (dbError || !post) {
      return NextResponse.json({ error: 'Post not found' }, { status: 404 })
    }

    return NextResponse.json({ post })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

/**
 * PUT - Update a blog post via RS backend
 */
export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const auth = await verifyAdminAndGetToken()
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status })
    if (!auth.token) return NextResponse.json({ error: 'No session token' }, { status: 401 })

    const body = await request.json()

    const rsResponse = await fetch(`${RS_BACKEND_URL}/api/v1/admin/posts/${id}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${auth.token}`,
      },
      body: JSON.stringify(body),
    })

    const data = await rsResponse.json().catch(() => ({ error: 'Unknown error' }))
    if (!rsResponse.ok) {
      console.error('RS backend error:', rsResponse.status, data)
      return NextResponse.json({ error: data.message || 'Failed to update blog post' }, { status: rsResponse.status })
    }

    return NextResponse.json({ post: data.data })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

/**
 * DELETE - Delete a blog post via RS backend
 */
export async function DELETE(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const auth = await verifyAdminAndGetToken()
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status })
    if (!auth.token) return NextResponse.json({ error: 'No session token' }, { status: 401 })

    const rsResponse = await fetch(`${RS_BACKEND_URL}/api/v1/admin/posts/${id}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${auth.token}` },
    })

    const data = await rsResponse.json().catch(() => ({ error: 'Unknown error' }))
    if (!rsResponse.ok) {
      console.error('RS backend error:', rsResponse.status, data)
      return NextResponse.json({ error: data.message || 'Failed to delete blog post' }, { status: rsResponse.status })
    }

    return NextResponse.json({ message: 'Post deleted' })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
