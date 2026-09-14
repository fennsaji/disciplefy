import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

const RS_BACKEND_URL = process.env.RS_BACKEND_URL || 'http://localhost:8080'

/**
 * POST - Start writing the missing blogs for one lesson on a learning path.
 * Generation runs in the background; poll the blog-status route.
 */
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; topicId: string }> },
) {
  try {
    const { id, topicId } = await params

    const supabase = await createClient()
    const {
      data: { user },
      error,
    } = await supabase.auth.getUser()
    if (error || !user)
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

    const supabaseAdmin = await createAdminClient()
    const { data: profile } = await supabaseAdmin
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()
    if (!profile?.is_admin)
      return NextResponse.json(
        { error: 'Unauthorized - Admin access required' },
        { status: 403 },
      )

    const {
      data: { session },
    } = await supabase.auth.getSession()
    const token = session?.access_token
    if (!token)
      return NextResponse.json({ error: 'No session token' }, { status: 401 })

    const body = await request.json().catch(() => ({}))
    const rsResponse = await fetch(
      `${RS_BACKEND_URL}/api/v1/admin/learning-paths/${id}/topics/${topicId}/generate-blog`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body ?? {}),
      },
    )
    const data = await rsResponse.json().catch(() => ({}))
    if (!rsResponse.ok) {
      return NextResponse.json(
        { error: data.error?.message || 'Failed to start blog generation' },
        { status: rsResponse.status },
      )
    }
    return NextResponse.json(data)
  } catch (err) {
    console.error('topic generate-blog route error:', err)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
