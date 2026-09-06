import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import { getAuthEmailMap } from '@/lib/supabase/list-all-users'

const DEFAULT_LIMIT = 50
const MAX_LIMIT = 200
const LANGUAGES = ['en', 'hi', 'ml']

async function requireAdmin() {
  const supabaseUser = await createClient()
  const { data: { user }, error: userError } = await supabaseUser.auth.getUser()
  if (userError || !user) return { error: NextResponse.json({ error: 'Unauthorized' }, { status: 401 }) }
  const supabaseAdmin = createAdminClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!)
  const { data: profile } = await supabaseAdmin.from('user_profiles').select('is_admin').eq('id', user.id).single()
  if (!profile?.is_admin) return { error: NextResponse.json({ error: 'Unauthorized - Admin access required' }, { status: 403 }) }
  return { supabaseAdmin, userId: user.id }
}

export async function GET(request: NextRequest) {
  const auth = await requireAdmin()
  if ('error' in auth) return auth.error
  const { supabaseAdmin } = auth
  const p = request.nextUrl.searchParams
  const limit = Math.min(Math.max(parseInt(p.get('limit') || String(DEFAULT_LIMIT), 10) || DEFAULT_LIMIT, 1), MAX_LIMIT)
  const offset = Math.max(parseInt(p.get('offset') || '0', 10) || 0, 0)
  const search = p.get('search')?.trim()

  if (p.get('view') === 'activity') {
    let aq = supabaseAdmin.from('discipler_activity')
      .select('id, fellowship_id, comment_id, kind, reaction, language, summary, reviewed_at, created_at, fellowships(name), fellowship_posts(content), fellowship_comments(content, is_pending_review, is_deleted)', { count: 'exact' })
      .order('created_at', { ascending: false }).range(offset, offset + limit - 1)
    const kind = p.get('kind')
    if (kind && ['reply', 'react', 'draft', 'daily_post'].includes(kind)) aq = aq.eq('kind', kind)
    const { data, count, error } = await aq
    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    const one = <T,>(x: T | T[] | null): T | null => (Array.isArray(x) ? x[0] ?? null : x)
    return NextResponse.json({
      data: (data ?? []).map((r: any) => {
        const fellowship = one(r.fellowships)
        const post = one(r.fellowship_posts)
        const comment = one(r.fellowship_comments)
        return {
          id: r.id, fellowship_id: r.fellowship_id, fellowship_name: fellowship?.name ?? '', kind: r.kind, reaction: r.reaction,
          language: r.language, summary: r.summary, reviewed_at: r.reviewed_at, created_at: r.created_at,
          comment_id: r.comment_id, comment_content: comment?.content ?? null, comment_pending: comment?.is_pending_review ?? false,
          comment_deleted: comment?.is_deleted ?? false, post_content: post?.content ?? null,
        }
      }), total: count ?? 0, limit, offset,
    })
  }

  let q = supabaseAdmin.from('fellowships')
    .select('id, name, language, is_public, is_active, is_official, discipler_allowed, daily_post_allowed, discipler_reply_mode, discipler_reply_scope, discipler_reply_delay_min, discipler_react_enabled, daily_post_on, daily_post_frequency_days, daily_post_auto_advance, max_members, created_at', { count: 'exact' })
    .order('created_at', { ascending: false }).order('id', { ascending: true }).range(offset, offset + limit - 1)
  if (search) q = q.ilike('name', `%${search}%`)
  const { data: rows, count, error } = await q
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  const ids = (rows ?? []).map((r) => r.id)
  if (ids.length === 0) return NextResponse.json({ data: [], total: count ?? 0, limit, offset })

  const dayStart = new Date(); dayStart.setUTCHours(0, 0, 0, 0)
  const [members, mentors, replies] = await Promise.all([
    supabaseAdmin.from('fellowship_members').select('fellowship_id').in('fellowship_id', ids).eq('is_active', true),
    supabaseAdmin.from('fellowship_members').select('fellowship_id, user_id').in('fellowship_id', ids).eq('is_active', true).eq('role', 'mentor'),
    supabaseAdmin.from('discipler_replies').select('fellowship_id, cost_usd').in('fellowship_id', ids).gte('created_at', dayStart.toISOString()),
  ])
  const memberCount = new Map<string, number>()
  for (const m of members.data ?? []) memberCount.set(m.fellowship_id, (memberCount.get(m.fellowship_id) ?? 0) + 1)
  const mentorIds = [...new Set((mentors.data ?? []).map((m) => m.user_id))]
  let emails: Record<string, string> = {}
  try { emails = await getAuthEmailMap(supabaseAdmin, mentorIds) } catch (e) { console.error('Failed to fetch mentor emails:', e) }
  const mentorsBy = new Map<string, { user_id: string; email: string }[]>()
  for (const m of mentors.data ?? []) {
    const list = mentorsBy.get(m.fellowship_id) ?? []
    list.push({ user_id: m.user_id, email: emails[m.user_id] ?? m.user_id })
    mentorsBy.set(m.fellowship_id, list)
  }
  const repliesBy = new Map<string, { n: number; cost: number }>()
  for (const r of replies.data ?? []) {
    const cur = repliesBy.get(r.fellowship_id) ?? { n: 0, cost: 0 }
    cur.n += 1; cur.cost += Number(r.cost_usd ?? 0)
    repliesBy.set(r.fellowship_id, cur)
  }
  const data = (rows ?? []).map((r) => ({
    ...r,
    member_count: memberCount.get(r.id) ?? 0,
    mentors: mentorsBy.get(r.id) ?? [],
    replies_today: repliesBy.get(r.id)?.n ?? 0,
    cost_today_usd: Number((repliesBy.get(r.id)?.cost ?? 0).toFixed(4)),
  }))
  return NextResponse.json({ data, total: count ?? 0, limit, offset })
}

export async function POST(request: NextRequest) {
  const auth = await requireAdmin()
  if ('error' in auth) return auth.error
  const { supabaseAdmin } = auth
  const body = await request.json().catch(() => null)
  if (!body) return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 })
  const name = String(body.name ?? '').trim()
  if (name.length < 3 || name.length > 60) return NextResponse.json({ error: 'name must be 3–60 characters' }, { status: 400 })
  if (!LANGUAGES.includes(body.language)) return NextResponse.json({ error: 'language must be en, hi or ml' }, { status: 400 })
  const isOfficial = body.is_official === true
  const disciplerAllowed = body.discipler_allowed === true
  const dailyAllowed = body.daily_post_allowed === true
  if ((disciplerAllowed || dailyAllowed) && !isOfficial) return NextResponse.json({ error: 'Discipler and daily post require an official fellowship' }, { status: 400 })
  const mentorEmail = String(body.mentor_email ?? '').trim().toLowerCase()
  if (!mentorEmail) return NextResponse.json({ error: 'mentor_email is required' }, { status: 400 })

  let users
  try {
    const result = await supabaseAdmin.auth.admin.listUsers({ page: 1, perPage: 1000 })
    if (result.error) {
      console.error('Failed to list users:', result.error)
      return NextResponse.json({ error: 'Failed to look up users' }, { status: 500 })
    }
    users = result.data
  } catch (e) {
    console.error('Failed to list users:', e)
    return NextResponse.json({ error: 'Failed to look up users' }, { status: 500 })
  }
  const mentor = users?.users.find((u) => u.email?.toLowerCase() === mentorEmail)
  if (!mentor) return NextResponse.json({ error: 'No user with that email' }, { status: 404 })

  const { data: f, error } = await supabaseAdmin.from('fellowships').insert({
    name, description: body.description?.trim() || null, mentor_user_id: mentor.id,
    max_members: body.unlimited_members ? null : 12, is_public: body.is_public === true, language: body.language,
    posting_permission: 'all_members', is_official: isOfficial, discipler_allowed: disciplerAllowed, daily_post_allowed: dailyAllowed,
  }).select('id').single()
  if (error || !f) return NextResponse.json({ error: error?.message ?? 'Insert failed' }, { status: 500 })
  const { error: mErr } = await supabaseAdmin.from('fellowship_members').insert({ fellowship_id: f.id, user_id: mentor.id, role: 'mentor' })
  if (mErr) {
    await supabaseAdmin.from('fellowships').delete().eq('id', f.id)
    return NextResponse.json({ error: 'Failed to add mentor' }, { status: 500 })
  }

  // Every fellowship gets a default study path (non-fatal on failure).
  const { data: defaultPathId, error: defaultPathError } = await supabaseAdmin.rpc('default_learning_path_id')
  if (defaultPathError) {
    console.error('[admin/fellowships] default study insert failed', { fellowshipId: f.id, error: defaultPathError })
  } else if (defaultPathId) {
    const { error: studyError } = await supabaseAdmin.from('fellowship_study').insert({
      fellowship_id: f.id, learning_path_id: defaultPathId, current_guide_index: 0,
    })
    if (studyError) console.error('[admin/fellowships] default study insert failed', { fellowshipId: f.id, error: studyError })
  }

  return NextResponse.json({ data: { id: f.id } }, { status: 201 })
}

export async function PATCH(request: NextRequest) {
  const auth = await requireAdmin()
  if ('error' in auth) return auth.error
  const { supabaseAdmin } = auth
  const body = await request.json().catch(() => null)
  if (!body?.fellowship_id) return NextResponse.json({ error: 'fellowship_id is required' }, { status: 400 })
  const updates: Record<string, unknown> = { updated_at: new Date().toISOString() }
  for (const k of ['is_official', 'discipler_allowed', 'daily_post_allowed', 'is_public', 'is_active'] as const) {
    if (typeof body[k] === 'boolean') updates[k] = body[k]
  }
  const { data: current } = await supabaseAdmin.from('fellowships').select('is_official, discipler_allowed, daily_post_allowed').eq('id', body.fellowship_id).single()
  if (!current) return NextResponse.json({ error: 'Not found' }, { status: 404 })
  const next = { ...current, ...updates }
  if ((next.discipler_allowed || next.daily_post_allowed) && !next.is_official) {
    return NextResponse.json({ error: 'Discipler and daily post require an official fellowship' }, { status: 400 })
  }
  const { error } = await supabaseAdmin.from('fellowships').update(updates).eq('id', body.fellowship_id)
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({ success: true })
}

export async function PUT(request: NextRequest) {
  const auth = await requireAdmin()
  if ('error' in auth) return auth.error
  const { supabaseAdmin } = auth
  const body = await request.json().catch(() => null)
  if (!body?.fellowship_id || !body?.user_id || !['add_mentor', 'remove_mentor'].includes(body.action)) {
    return NextResponse.json({ error: 'fellowship_id, user_id and action are required' }, { status: 400 })
  }
  const { data: f } = await supabaseAdmin.from('fellowships').select('mentor_user_id').eq('id', body.fellowship_id).single()
  if (!f) return NextResponse.json({ error: 'Not found' }, { status: 404 })
  if (body.action === 'remove_mentor' && f.mentor_user_id === body.user_id) return NextResponse.json({ error: 'The owner cannot be demoted' }, { status: 400 })
  const role = body.action === 'add_mentor' ? 'mentor' : 'member'
  const { error } = await supabaseAdmin.from('fellowship_members')
    .upsert({ fellowship_id: body.fellowship_id, user_id: body.user_id, role, is_active: true }, { onConflict: 'fellowship_id,user_id' })
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({ success: true })
}

export async function DELETE(request: NextRequest) {
  const auth = await requireAdmin()
  if ('error' in auth) return auth.error
  const { supabaseAdmin, userId } = auth
  const body = await request.json().catch(() => null)
  if (!body?.comment_id) return NextResponse.json({ error: 'comment_id is required' }, { status: 400 })

  const { data: updatedComments, error: commentError } = await supabaseAdmin.from('fellowship_comments')
    .update({ is_deleted: true })
    .eq('id', body.comment_id)
    .select('id')
  if (commentError) return NextResponse.json({ error: commentError.message }, { status: 500 })
  if (!updatedComments || updatedComments.length === 0) {
    return NextResponse.json({ error: 'Comment not found' }, { status: 404 })
  }

  const { error: activityError } = await supabaseAdmin.from('discipler_activity')
    .update({ reviewed_by: userId, reviewed_at: new Date().toISOString() })
    .eq('comment_id', body.comment_id)
  if (activityError) return NextResponse.json({ error: activityError.message }, { status: 500 })

  return NextResponse.json({ success: true })
}
