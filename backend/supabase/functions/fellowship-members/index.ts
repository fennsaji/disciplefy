/**
 * fellowship-members  (merged)
 * Routes:
 *   GET  /fellowship-members?fellowship_id=UUID  → list members (member)
 *   POST /fellowship-members/mute                → mute member (mentor)
 *   POST /fellowship-members/unmute              → unmute member (mentor)
 *   POST /fellowship-members/remove              → remove member (mentor)
 *   POST /fellowship-members/transfer            → transfer mentor role (current mentor)
 *   POST /fellowship-members/contact             → set own mentor contact channel (mentor)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

// ---------------------------------------------------------------------------
// List members  GET /fellowship-members?fellowship_id=UUID
// ---------------------------------------------------------------------------

interface MemberResponse {
  user_id: string
  role: 'mentor' | 'member'
  joined_at: string
  is_muted: boolean
  is_owner: boolean
  display_name: string
  avatar_url: string | null
  topics_completed: number | null
  mentor_whatsapp: string | null
  mentor_email: string | null
}

interface FellowshipMemberRow {
  user_id: string
  role: 'mentor' | 'member'
  joined_at: string
  mentor_whatsapp: string | null
  mentor_email: string | null
}

async function handleListMembers(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  const url = new URL(req.url)
  const fellowshipId = url.searchParams.get('fellowship_id')
  if (!fellowshipId) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!UUID_RE.test(fellowshipId)) throw new AppError('VALIDATION_ERROR', 'fellowship_id must be a valid UUID', 400)

  const db = services.supabaseServiceClient

  const { data: isMember, error: rpcError } = await db.rpc('is_fellowship_member', {
    p_fellowship_id: fellowshipId,
    p_user_id: user.id
  })
  if (rpcError) throw new AppError('DATABASE_ERROR', 'Failed to verify membership', 500)
  if (!isMember) throw new AppError('PERMISSION_DENIED', 'You are not a member of this fellowship', 403)

  const [membersResult, mutesResult, studyResult, fellowshipResult] = await Promise.all([
    db.from('fellowship_members').select('user_id, role, joined_at, mentor_whatsapp, mentor_email')
      .eq('fellowship_id', fellowshipId).eq('is_active', true).order('joined_at', { ascending: true }),
    db.from('fellowship_mutes').select('muted_user_id').eq('fellowship_id', fellowshipId),
    db.from('fellowship_study').select('learning_path_id, current_guide_index')
      .eq('fellowship_id', fellowshipId).is('completed_at', null).maybeSingle(),
    db.from('fellowships').select('mentor_user_id').eq('id', fellowshipId).maybeSingle()
  ])
  const ownerId: string | null = fellowshipResult.data?.mentor_user_id ?? null

  if (membersResult.error) {
    console.error('[fellowship-members/list] Members query error:', membersResult.error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch fellowship members', 500)
  }
  if (mutesResult.error) {
    console.error('[fellowship-members/list] Mutes query error:', mutesResult.error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch mute list', 500)
  }

  const memberRows = (membersResult.data ?? []) as FellowshipMemberRow[]
  const mutedUserIds = new Set((mutesResult.data ?? []).map((r: { muted_user_id: string }) => r.muted_user_id))

  const activeLearningPathId = studyResult.data?.learning_path_id ?? null
  const currentGuideIndex: number = studyResult.data?.current_guide_index ?? 0
  const progressByUserId = new Map<string, number>()

  if (activeLearningPathId && memberRows.length > 0) {
    const memberUserIds = memberRows.map((r) => r.user_id)

    // Fetch topic IDs for the active path, then count each member's completions
    // directly from user_topic_progress. This avoids requiring enrollment in
    // user_learning_path_progress (fellowship members complete guides without
    // individually enrolling in the path).
    const { data: pathTopics } = await db
      .from('learning_path_topics')
      .select('topic_id')
      .eq('learning_path_id', activeLearningPathId)
      .eq('is_active', true)

    const topicIds = (pathTopics ?? []).map((r: { topic_id: string }) => r.topic_id)

    if (topicIds.length > 0) {
      const { data: completedRows } = await db
        .from('user_topic_progress')
        .select('user_id')
        .in('user_id', memberUserIds)
        .in('topic_id', topicIds)
        .not('completed_at', 'is', null)

      for (const row of completedRows ?? []) {
        progressByUserId.set(row.user_id, (progressByUserId.get(row.user_id) ?? 0) + 1)
      }
    }
  }

  memberRows.sort((a, b) => {
    const rolePriority = (role: string) => (role === 'mentor' ? 0 : 1)
    const roleDiff = rolePriority(a.role) - rolePriority(b.role)
    if (roleDiff !== 0) return roleDiff
    return new Date(a.joined_at).getTime() - new Date(b.joined_at).getTime()
  })

  const members: MemberResponse[] = await Promise.all(
    memberRows.map(async (row): Promise<MemberResponse> => {
      const is_muted = mutedUserIds.has(row.user_id)
      const personallyCompleted = progressByUserId.has(row.user_id)
        ? progressByUserId.get(row.user_id)!
        : (activeLearningPathId ? 0 : null)
      const topics_completed = personallyCompleted

      const is_owner = row.user_id === ownerId
      // Only mentors may expose a contact channel. Server-side enforced —
      // never trust the stored value for non-mentor rows.
      const mentor_whatsapp: string | null = row.role === 'mentor' ? row.mentor_whatsapp : null
      const mentor_email: string | null = row.role === 'mentor' ? row.mentor_email : null
      try {
        const { data: userData, error: userError } =
          await services.supabaseServiceClient.auth.admin.getUserById(row.user_id)
        if (userError || !userData?.user) {
          return { user_id: row.user_id, role: row.role, joined_at: row.joined_at, is_muted, is_owner, display_name: 'Unknown Member', avatar_url: null, topics_completed, mentor_whatsapp, mentor_email }
        }
        const u = userData.user
        const display_name: string =
          u.user_metadata?.full_name ?? u.user_metadata?.name ??
          u.user_metadata?.display_name ?? u.email ?? 'Unknown Member'
        const avatar_url: string | null = u.user_metadata?.avatar_url ?? null
        return { user_id: row.user_id, role: row.role, joined_at: row.joined_at, is_muted, is_owner, display_name, avatar_url, topics_completed, mentor_whatsapp, mentor_email }
      } catch (err) {
        console.error('[fellowship-members/list] Unexpected error fetching user:', row.user_id, err)
        return { user_id: row.user_id, role: row.role, joined_at: row.joined_at, is_muted, is_owner, display_name: 'Unknown Member', avatar_url: null, topics_completed, mentor_whatsapp, mentor_email }
      }
    })
  )

  return new Response(
    JSON.stringify({ success: true, data: { members } }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Mute member  POST /fellowship-members/mute
// ---------------------------------------------------------------------------

async function handleMuteMember(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { fellowship_id: string; user_id: string }
  try { body = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!body.user_id) throw new AppError('VALIDATION_ERROR', 'user_id is required', 400)
  if (body.user_id === user.id) throw new AppError('VALIDATION_ERROR', 'Cannot mute yourself', 400)

  const db = services.supabaseServiceClient

  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id, p_user_id: user.id
  })
  if (rpcError) { console.error('[fellowship-members/mute] RPC error:', rpcError); throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500) }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const { data: targetMember, error: targetMemberError } = await db
    .from('fellowship_members').select('user_id, role')
    .eq('fellowship_id', body.fellowship_id).eq('user_id', body.user_id).eq('is_active', true).maybeSingle()

  if (targetMemberError) { console.error('[fellowship-members/mute] Target check error:', targetMemberError); throw new AppError('DATABASE_ERROR', 'Failed to verify target membership', 500) }
  if (!targetMember) throw new AppError('NOT_FOUND', 'Target user is not an active member of this fellowship', 404)
  if ((targetMember as any).role === 'mentor') throw new AppError('VALIDATION_ERROR', 'Cannot mute a mentor', 400)

  const { error } = await db.from('fellowship_mutes').insert({
    fellowship_id: body.fellowship_id, muted_user_id: body.user_id, muted_by: user.id
  })
  if (error) {
    if (error.code === '23505') return new Response(JSON.stringify({ success: true, message: 'Member is already muted' }), { status: 200, headers: { 'Content-Type': 'application/json' } })
    console.error('[fellowship-members/mute] Insert error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to mute member', 500)
  }
  return new Response(JSON.stringify({ success: true, message: 'Member muted' }), { status: 200, headers: { 'Content-Type': 'application/json' } })
}

// ---------------------------------------------------------------------------
// Unmute member  POST /fellowship-members/unmute
// ---------------------------------------------------------------------------

async function handleUnmuteMember(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { fellowship_id: string; user_id: string }
  try { body = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!body.user_id) throw new AppError('VALIDATION_ERROR', 'user_id is required', 400)

  const db = services.supabaseServiceClient

  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id, p_user_id: user.id
  })
  if (rpcError) { console.error('[fellowship-members/unmute] RPC error:', rpcError); throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500) }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const { error } = await db.from('fellowship_mutes').delete()
    .eq('fellowship_id', body.fellowship_id).eq('muted_user_id', body.user_id)
  if (error) { console.error('[fellowship-members/unmute] Delete error:', error); throw new AppError('DATABASE_ERROR', 'Failed to unmute member', 500) }
  return new Response(JSON.stringify({ success: true, message: 'Member unmuted' }), { status: 200, headers: { 'Content-Type': 'application/json' } })
}

// ---------------------------------------------------------------------------
// Remove member  POST /fellowship-members/remove
// ---------------------------------------------------------------------------

async function handleRemoveMember(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { fellowship_id: string; user_id: string }
  try { body = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!body.user_id) throw new AppError('VALIDATION_ERROR', 'user_id is required', 400)
  if (body.user_id === user.id) throw new AppError('VALIDATION_ERROR', 'Cannot remove yourself — use leave fellowship instead', 400)

  const db = services.supabaseServiceClient

  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id, p_user_id: user.id
  })
  if (rpcError) { console.error('[fellowship-members/remove] RPC error:', rpcError); throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500) }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const { data: targetMember, error: targetMemberError } = await db
    .from('fellowship_members').select('user_id, role')
    .eq('fellowship_id', body.fellowship_id).eq('user_id', body.user_id).eq('is_active', true).maybeSingle()

  if (targetMemberError) { console.error('[fellowship-members/remove] Target check error:', targetMemberError); throw new AppError('DATABASE_ERROR', 'Failed to verify target membership', 500) }
  if (!targetMember) throw new AppError('NOT_FOUND', 'Target user is not an active member of this fellowship', 404)
  if ((targetMember as any).role === 'mentor') throw new AppError('VALIDATION_ERROR', 'Cannot remove the mentor — transfer mentor role first', 400)

  const { error } = await db.from('fellowship_members')
    .update({ is_active: false, mentor_whatsapp: null, mentor_email: null })
    .eq('fellowship_id', body.fellowship_id).eq('user_id', body.user_id)
  if (error) { console.error('[fellowship-members/remove] Update error:', error); throw new AppError('DATABASE_ERROR', 'Failed to remove member', 500) }
  return new Response(JSON.stringify({ success: true, message: 'Member removed' }), { status: 200, headers: { 'Content-Type': 'application/json' } })
}

// ---------------------------------------------------------------------------
// Transfer mentor  POST /fellowship-members/transfer
// ---------------------------------------------------------------------------

async function handleTransferMentor(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { fellowship_id: string; new_mentor_user_id: string }
  try { body = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!body.new_mentor_user_id) throw new AppError('VALIDATION_ERROR', 'new_mentor_user_id is required', 400)
  if (body.new_mentor_user_id === user.id) throw new AppError('VALIDATION_ERROR', 'Cannot transfer mentor role to yourself', 400)

  const db = services.supabaseServiceClient

  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id, p_user_id: user.id
  })
  if (rpcError) { console.error('[fellowship-members/transfer] RPC error:', rpcError); throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500) }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const { data: targetMember, error: targetError } = await db
    .from('fellowship_members').select('id, role')
    .eq('fellowship_id', body.fellowship_id).eq('user_id', body.new_mentor_user_id).eq('is_active', true).maybeSingle()

  if (targetError) { console.error('[fellowship-members/transfer] Target fetch error:', targetError); throw new AppError('DATABASE_ERROR', 'Failed to verify target member', 500) }
  if (!targetMember) throw new AppError('NOT_FOUND', 'Target user is not an active member', 404)

  const { error: demoteError } = await db.from('fellowship_members')
    .update({ role: 'member' }).eq('fellowship_id', body.fellowship_id).eq('user_id', user.id)
  if (demoteError) { console.error('[fellowship-members/transfer] Demote error:', demoteError); throw new AppError('DATABASE_ERROR', 'Failed to transfer mentor role', 500) }

  const { error: promoteError } = await db.from('fellowship_members')
    .update({ role: 'mentor' }).eq('fellowship_id', body.fellowship_id).eq('user_id', body.new_mentor_user_id)
  if (promoteError) {
    console.error('[fellowship-members/transfer] Promote error:', promoteError)
    await db.from('fellowship_members').update({ role: 'mentor' }).eq('fellowship_id', body.fellowship_id).eq('user_id', user.id)
    throw new AppError('DATABASE_ERROR', 'Failed to promote new mentor', 500)
  }

  const { error: fellowshipError } = await db.from('fellowships')
    .update({ mentor_user_id: body.new_mentor_user_id }).eq('id', body.fellowship_id)
  if (fellowshipError) {
    console.error('[fellowship-members/transfer] Fellowship update error:', fellowshipError)
    return new Response(
      JSON.stringify({ success: true, warning: 'Mentor role transferred but fellowship record not updated. Please retry.', data: { new_mentor_user_id: body.new_mentor_user_id } }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  }

  return new Response(JSON.stringify({ success: true, message: 'Mentor role transferred successfully' }), { status: 200, headers: { 'Content-Type': 'application/json' } })
}

// ---------------------------------------------------------------------------
// Promote / demote mentor  POST /fellowship-members/promote|demote
// ---------------------------------------------------------------------------

async function handleChangeMentorRole(req: Request, services: ServiceContainer, to: 'mentor' | 'member'): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(authHeader.replace('Bearer ', ''))
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)
  let body: { fellowship_id: string; user_id: string }
  try { body = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!body.user_id) throw new AppError('VALIDATION_ERROR', 'user_id is required', 400)
  const db = services.supabaseServiceClient

  const [{ data: isMentor }, { data: profile }, { data: fellowship }] = await Promise.all([
    db.rpc('is_fellowship_mentor', { p_fellowship_id: body.fellowship_id, p_user_id: user.id }),
    db.from('user_profiles').select('is_admin').eq('id', user.id).maybeSingle(),
    db.from('fellowships').select('mentor_user_id').eq('id', body.fellowship_id).maybeSingle(),
  ])
  if (!isMentor && profile?.is_admin !== true) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)
  if (!fellowship) throw new AppError('NOT_FOUND', 'Fellowship not found', 404)
  if (to === 'member' && body.user_id === fellowship.mentor_user_id) throw new AppError('VALIDATION_ERROR', 'The owner cannot be demoted — transfer ownership first', 400)

  const { data: target } = await db.from('fellowship_members').select('role').eq('fellowship_id', body.fellowship_id).eq('user_id', body.user_id).eq('is_active', true).maybeSingle()
  if (!target) throw new AppError('NOT_FOUND', 'Target user is not an active member', 404)
  if (target.role === to) return new Response(JSON.stringify({ success: true, message: 'No change' }), { status: 200, headers: { 'Content-Type': 'application/json' } })

  // Demotion drops the private contact channels with the role that justified them,
  // rather than leaving the number or address stored but hidden.
  const roleUpdate: { role: 'mentor' | 'member'; mentor_whatsapp?: null; mentor_email?: null } =
    to === 'member'
      ? { role: to, mentor_whatsapp: null, mentor_email: null }
      : { role: to }
  const { error } = await db.from('fellowship_members').update(roleUpdate).eq('fellowship_id', body.fellowship_id).eq('user_id', body.user_id)
  if (error) { console.error('[fellowship-members/role] Update error:', error); throw new AppError('DATABASE_ERROR', 'Failed to change role', 500) }
  return new Response(JSON.stringify({ success: true, data: { user_id: body.user_id, role: to } }), { status: 200, headers: { 'Content-Type': 'application/json' } })
}

// ---------------------------------------------------------------------------
// Set own mentor contact channels  POST /fellowship-members/contact
// ---------------------------------------------------------------------------

const WHATSAPP_DIGITS_RE = /^\d{8,15}$/
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

function normalizeWhatsapp(raw: string): string {
  let digits = raw.replace(/[\s\-()]/g, '')
  if (digits.startsWith('+')) digits = digits.slice(1)
  return digits
}

async function handleSetMentorContact(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { fellowship_id: string; whatsapp?: string | null; email?: string | null }
  try { body = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!UUID_RE.test(body.fellowship_id)) throw new AppError('VALIDATION_ERROR', 'fellowship_id must be a valid UUID', 400)

  const hasWhatsapp = Object.prototype.hasOwnProperty.call(body, 'whatsapp')
  const hasEmail = Object.prototype.hasOwnProperty.call(body, 'email')
  if (!hasWhatsapp && !hasEmail) {
    throw new AppError('VALIDATION_ERROR', 'At least one of whatsapp or email must be provided', 400)
  }

  const db = services.supabaseServiceClient

  // Caller must be an active mentor of this fellowship. A mentor may only
  // ever set their own contact — there is no target user_id in this route.
  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id, p_user_id: user.id
  })
  if (rpcError) { console.error('[fellowship-members/contact] RPC error:', rpcError); throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500) }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  // Only keys present in the body are written — omitting a key leaves that
  // channel unchanged; explicit null/"" clears it. The two channels are
  // edited independently.
  const update: { mentor_whatsapp?: string | null; mentor_email?: string | null } = {}
  const changedChannels: string[] = []

  if (hasWhatsapp) {
    const rawValue = body.whatsapp
    if (rawValue === null || rawValue === '') {
      update.mentor_whatsapp = null
      changedChannels.push('whatsapp:cleared')
    } else {
      const digits = normalizeWhatsapp(String(rawValue).trim())
      if (!WHATSAPP_DIGITS_RE.test(digits)) {
        throw new AppError('VALIDATION_ERROR', 'whatsapp must be a number with 8-15 digits', 400)
      }
      update.mentor_whatsapp = digits
      changedChannels.push('whatsapp:set')
    }
  }

  if (hasEmail) {
    const rawValue = body.email
    if (rawValue === null || rawValue === '') {
      update.mentor_email = null
      changedChannels.push('email:cleared')
    } else {
      const trimmed = String(rawValue).trim().toLowerCase()
      if (trimmed.length > 254) throw new AppError('VALIDATION_ERROR', 'email must be at most 254 characters', 400)
      if (!EMAIL_RE.test(trimmed)) throw new AppError('VALIDATION_ERROR', 'email must be a valid email address', 400)
      update.mentor_email = trimmed
      changedChannels.push('email:set')
    }
  }

  const { data: updated, error } = await db.from('fellowship_members')
    .update(update)
    .eq('fellowship_id', body.fellowship_id).eq('user_id', user.id)
    .select('mentor_whatsapp, mentor_email')
    .maybeSingle()

  if (error) {
    // Never log contact values — only fellowship id and which channels changed.
    console.error('[fellowship-members/contact] Update error:', { fellowship_id: body.fellowship_id, changedChannels, error })
    throw new AppError('DATABASE_ERROR', 'Failed to update mentor contact', 500)
  }

  console.log('[fellowship-members/contact] Updated:', { fellowship_id: body.fellowship_id, changedChannels })

  return new Response(
    JSON.stringify({
      success: true,
      mentor_whatsapp: updated?.mentor_whatsapp ?? null,
      mentor_email: updated?.mentor_email ?? null,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

async function handleMembers(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const pathname = new URL(req.url).pathname

  if (req.method === 'GET') return handleListMembers(req, services)

  if (req.method === 'POST') {
    if (pathname.endsWith('/mute')) return handleMuteMember(req, services)
    if (pathname.endsWith('/unmute')) return handleUnmuteMember(req, services)
    if (pathname.endsWith('/remove')) return handleRemoveMember(req, services)
    if (pathname.endsWith('/transfer')) return handleTransferMentor(req, services)
    if (pathname.endsWith('/promote')) return handleChangeMentorRole(req, services, 'mentor')
    if (pathname.endsWith('/demote')) return handleChangeMentorRole(req, services, 'member')
    if (pathname.endsWith('/contact')) return handleSetMentorContact(req, services)
  }

  throw new AppError('METHOD_NOT_ALLOWED', 'Method not allowed', 405)
}

createSimpleFunction(handleMembers, {
  allowedMethods: ['GET', 'POST'],
  enableAnalytics: true,
  timeout: 15000,
})
