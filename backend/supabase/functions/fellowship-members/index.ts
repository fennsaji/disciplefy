/**
 * fellowship-members  (merged)
 * Routes:
 *   GET  /fellowship-members?fellowship_id=UUID  → list members (member)
 *   POST /fellowship-members/mute                → mute member (mentor)
 *   POST /fellowship-members/unmute              → unmute member (mentor)
 *   POST /fellowship-members/remove              → remove member (mentor)
 *   POST /fellowship-members/transfer            → transfer mentor role (current mentor)
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
  display_name: string
  avatar_url: string | null
  topics_completed: number | null
}

interface FellowshipMemberRow {
  user_id: string
  role: 'mentor' | 'member'
  joined_at: string
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

  const [membersResult, mutesResult, studyResult] = await Promise.all([
    db.from('fellowship_members').select('user_id, role, joined_at')
      .eq('fellowship_id', fellowshipId).eq('is_active', true).order('joined_at', { ascending: true }),
    db.from('fellowship_mutes').select('muted_user_id').eq('fellowship_id', fellowshipId),
    db.from('fellowship_study').select('learning_path_id, current_guide_index')
      .eq('fellowship_id', fellowshipId).maybeSingle()
  ])

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
    const { data: progressRows } = await db
      .from('user_learning_path_progress')
      .select('user_id, topics_completed')
      .eq('learning_path_id', activeLearningPathId)
      .in('user_id', memberUserIds)
    for (const row of progressRows ?? []) {
      progressByUserId.set(row.user_id, row.topics_completed ?? 0)
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
      const topics_completed = personallyCompleted !== null
        ? Math.max(personallyCompleted, currentGuideIndex)
        : null

      try {
        const { data: userData, error: userError } =
          await services.supabaseServiceClient.auth.admin.getUserById(row.user_id)
        if (userError || !userData?.user) {
          return { user_id: row.user_id, role: row.role, joined_at: row.joined_at, is_muted, display_name: 'Unknown Member', avatar_url: null, topics_completed }
        }
        const u = userData.user
        const display_name: string =
          u.user_metadata?.full_name ?? u.user_metadata?.name ??
          u.user_metadata?.display_name ?? u.email ?? 'Unknown Member'
        const avatar_url: string | null = u.user_metadata?.avatar_url ?? null
        return { user_id: row.user_id, role: row.role, joined_at: row.joined_at, is_muted, display_name, avatar_url, topics_completed }
      } catch (err) {
        console.error('[fellowship-members/list] Unexpected error fetching user:', row.user_id, err)
        return { user_id: row.user_id, role: row.role, joined_at: row.joined_at, is_muted, display_name: 'Unknown Member', avatar_url: null, topics_completed }
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
    .update({ is_active: false, left_at: new Date().toISOString() })
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
  }

  throw new AppError('METHOD_NOT_ALLOWED', 'Method not allowed', 405)
}

createSimpleFunction(handleMembers, {
  allowedMethods: ['GET', 'POST'],
  enableAnalytics: true,
  timeout: 15000,
})
