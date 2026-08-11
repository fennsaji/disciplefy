import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import { getAuthEmailMap } from '@/lib/supabase/list-all-users'

const DEFAULT_LIMIT = 50
const MAX_LIMIT = 200

/** Shared auth + admin check. Returns the admin client or a NextResponse to short-circuit with. */
async function requireAdmin() {
  const supabaseUser = await createClient()
  const { data: { user }, error: userError } = await supabaseUser.auth.getUser()

  if (userError || !user) {
    return { error: NextResponse.json({ error: 'Unauthorized' }, { status: 401 }) }
  }

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
    return { error: NextResponse.json({ error: 'Unauthorized - Admin access required' }, { status: 403 }) }
  }

  return { supabaseAdmin, userId: user.id }
}

/**
 * GET - Fetch moderation reports or blocks, paginated. All filtering,
 * counting and paging happens in SQL via `.range()` / `{ count: 'exact' }`.
 */
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const tab = searchParams.get('tab') === 'blocks' ? 'blocks' : 'reports'
    const status = searchParams.get('status') || 'pending'
    const limit = Math.min(
      Math.max(parseInt(searchParams.get('limit') || String(DEFAULT_LIMIT), 10) || DEFAULT_LIMIT, 1),
      MAX_LIMIT
    )
    const offset = Math.max(parseInt(searchParams.get('offset') || '0', 10) || 0, 0)

    const auth = await requireAdmin()
    if ('error' in auth) return auth.error
    const { supabaseAdmin } = auth

    if (tab === 'blocks') {
      const { data: blockRows, error: blocksError, count } = await supabaseAdmin
        .from('user_blocks')
        .select('id, blocker_id, blocked_id, reason, created_at', { count: 'exact' })
        .order('created_at', { ascending: false })
        .order('id', { ascending: true })
        .range(offset, offset + limit - 1)

      if (blocksError) {
        console.error('Failed to fetch user_blocks:', blocksError)
        return NextResponse.json({ error: 'Failed to fetch blocks' }, { status: 500 })
      }

      const blocks: any[] = blockRows || []
      if (blocks.length === 0) {
        return NextResponse.json({ data: [], total: count || 0, limit, offset })
      }

      const userIds = [...new Set(blocks.flatMap(b => [b.blocker_id, b.blocked_id]))] as string[]
      let emailsMap: Record<string, string>
      try {
        emailsMap = await getAuthEmailMap(supabaseAdmin, userIds)
      } catch (authError) {
        console.error('Failed to fetch auth users:', authError)
        return NextResponse.json({ error: 'Failed to fetch user emails' }, { status: 500 })
      }

      const data = blocks.map(b => ({
        id: b.id,
        blocker_id: b.blocker_id,
        blocker_email: emailsMap[b.blocker_id] || null,
        blocked_id: b.blocked_id,
        blocked_email: emailsMap[b.blocked_id] || null,
        reason: b.reason,
        created_at: b.created_at,
      }))

      return NextResponse.json({ data, total: count || 0, limit, offset })
    }

    // tab === 'reports'
    const { data: reportRows, error: reportsError, count } = await supabaseAdmin
      .from('fellowship_reports')
      .select('id, fellowship_id, reporter_user_id, content_type, content_id, reason, status, created_at', { count: 'exact' })
      .eq('status', status)
      .order('created_at', { ascending: false })
      .order('id', { ascending: true })
      .range(offset, offset + limit - 1)

    if (reportsError) {
      console.error('Failed to fetch fellowship_reports:', reportsError)
      return NextResponse.json({ error: 'Failed to fetch reports' }, { status: 500 })
    }

    const reports: any[] = reportRows || []
    if (reports.length === 0) {
      return NextResponse.json({ data: [], total: count || 0, limit, offset })
    }

    const postIds = reports.filter(r => r.content_type === 'post').map(r => r.content_id)
    const commentIds = reports.filter(r => r.content_type === 'comment').map(r => r.content_id)

    const [postsRes, commentsRes] = await Promise.all([
      postIds.length
        ? supabaseAdmin.from('fellowship_posts').select('id, content, author_user_id, is_deleted').in('id', postIds)
        : Promise.resolve({ data: [], error: null }),
      commentIds.length
        ? supabaseAdmin.from('fellowship_comments').select('id, content, author_user_id, is_deleted').in('id', commentIds)
        : Promise.resolve({ data: [], error: null }),
    ])

    if (postsRes.error) console.error('Failed to fetch reported posts:', postsRes.error)
    if (commentsRes.error) console.error('Failed to fetch reported comments:', commentsRes.error)

    const postsMap = Object.fromEntries((postsRes.data || []).map((p: any) => [p.id, p]))
    const commentsMap = Object.fromEntries((commentsRes.data || []).map((c: any) => [c.id, c]))

    const contentOf = (r: any) => (r.content_type === 'post' ? postsMap[r.content_id] : commentsMap[r.content_id])

    const userIds = [
      ...new Set(
        reports.flatMap(r => {
          const content = contentOf(r)
          return [r.reporter_user_id, content?.author_user_id].filter(Boolean)
        })
      ),
    ] as string[]

    let emailsMap: Record<string, string>
    try {
      emailsMap = await getAuthEmailMap(supabaseAdmin, userIds)
    } catch (authError) {
      console.error('Failed to fetch auth users:', authError)
      return NextResponse.json({ error: 'Failed to fetch user emails' }, { status: 500 })
    }

    const data = reports.map(r => {
      const content = contentOf(r)
      return {
        id: r.id,
        fellowship_id: r.fellowship_id,
        content_type: r.content_type,
        content_id: r.content_id,
        content_excerpt: content?.content ?? null,
        content_is_deleted: content?.is_deleted ?? null,
        reporter_user_id: r.reporter_user_id,
        reporter_email: emailsMap[r.reporter_user_id] || null,
        author_user_id: content?.author_user_id ?? null,
        author_email: content?.author_user_id ? emailsMap[content.author_user_id] || null : null,
        reason: r.reason,
        source: r.reason === 'user_blocked' ? 'block' : 'flag',
        status: r.status,
        created_at: r.created_at,
      }
    })

    return NextResponse.json({ data, total: count || 0, limit, offset })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

/**
 * PATCH - Update a report's status ('reviewed' | 'dismissed')
 */
export async function PATCH(request: NextRequest) {
  try {
    const body = await request.json()
    const { report_id, status } = body

    if (!report_id || !['reviewed', 'dismissed'].includes(status)) {
      return NextResponse.json(
        { error: 'report_id and a valid status (reviewed | dismissed) are required' },
        { status: 400 }
      )
    }

    const auth = await requireAdmin()
    if ('error' in auth) return auth.error
    const { supabaseAdmin } = auth

    const { error: updateError } = await supabaseAdmin
      .from('fellowship_reports')
      .update({ status })
      .eq('id', report_id)

    if (updateError) {
      console.error('Failed to update fellowship_report:', updateError)
      return NextResponse.json({ error: 'Failed to update report' }, { status: 500 })
    }

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

/**
 * DELETE - Soft-delete reported content by setting is_deleted = true
 */
export async function DELETE(request: NextRequest) {
  try {
    const body = await request.json()
    const { content_type, content_id } = body

    if (!content_id || !['post', 'comment'].includes(content_type)) {
      return NextResponse.json(
        { error: 'content_type (post | comment) and content_id are required' },
        { status: 400 }
      )
    }

    const auth = await requireAdmin()
    if ('error' in auth) return auth.error
    const { supabaseAdmin } = auth

    const table = content_type === 'post' ? 'fellowship_posts' : 'fellowship_comments'
    const { error: deleteError } = await supabaseAdmin
      .from(table)
      .update({ is_deleted: true })
      .eq('id', content_id)

    if (deleteError) {
      console.error(`Failed to soft-delete ${table} row:`, deleteError)
      return NextResponse.json({ error: 'Failed to delete content' }, { status: 500 })
    }

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
