/**
 * fellowship-transfer-mentor
 * Current mentor transfers mentor role to another active member.
 * POST /fellowship-transfer-mentor
 * Auth: Required (current mentor only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleTransferMentor(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { fellowship_id: string; new_mentor_user_id: string }
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!body.new_mentor_user_id) throw new AppError('VALIDATION_ERROR', 'new_mentor_user_id is required', 400)
  if (body.new_mentor_user_id === user.id) throw new AppError('VALIDATION_ERROR', 'Cannot transfer mentor role to yourself', 400)

  const db = services.supabaseServiceClient

  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-transfer-mentor] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  // Verify target is an active member
  const { data: targetMember, error: targetError } = await db
    .from('fellowship_members')
    .select('id, role')
    .eq('fellowship_id', body.fellowship_id)
    .eq('user_id', body.new_mentor_user_id)
    .eq('is_active', true)
    .maybeSingle()

  if (targetError) {
    console.error('[fellowship-transfer-mentor] Target fetch error:', targetError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify target member', 500)
  }
  if (!targetMember) throw new AppError('NOT_FOUND', 'Target user is not an active member', 404)

  // Demote current mentor to member
  const { error: demoteError } = await db
    .from('fellowship_members')
    .update({ role: 'member' })
    .eq('fellowship_id', body.fellowship_id)
    .eq('user_id', user.id)

  if (demoteError) {
    console.error('[fellowship-transfer-mentor] Demote error:', demoteError)
    throw new AppError('DATABASE_ERROR', 'Failed to transfer mentor role', 500)
  }

  // Promote new mentor
  const { error: promoteError } = await db
    .from('fellowship_members')
    .update({ role: 'mentor' })
    .eq('fellowship_id', body.fellowship_id)
    .eq('user_id', body.new_mentor_user_id)

  if (promoteError) {
    console.error('[fellowship-transfer-mentor] Promote error:', promoteError)
    // Attempt to restore caller's mentor role
    await db.from('fellowship_members').update({ role: 'mentor' }).eq('fellowship_id', body.fellowship_id).eq('user_id', user.id)
    throw new AppError('DATABASE_ERROR', 'Failed to promote new mentor', 500)
  }

  // Update fellowships.mentor_user_id
  const { error: fellowshipError } = await db
    .from('fellowships')
    .update({ mentor_user_id: body.new_mentor_user_id })
    .eq('id', body.fellowship_id)

  if (fellowshipError) {
    console.error('[fellowship-transfer-mentor] Fellowship update error:', fellowshipError)
    return new Response(
      JSON.stringify({
        success: true,
        warning: 'Mentor role transferred but fellowship record not updated. Please retry.',
        data: { new_mentor_user_id: body.new_mentor_user_id }
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  }

  return new Response(
    JSON.stringify({ success: true, message: 'Mentor role transferred successfully' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleTransferMentor, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
