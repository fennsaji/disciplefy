/**
 * fellowship-study-advance
 * Mentor marks current guide complete and advances to the next.
 * POST /fellowship-study-advance
 * Auth: Required (mentor only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleAdvanceStudy(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { fellowship_id: string }
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)

  const db = services.supabaseServiceClient

  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-study-advance] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  // Fetch active study
  const { data: study, error: studyError } = await db
    .from('fellowship_study')
    .select('id, current_guide_index, learning_path_id')
    .eq('fellowship_id', body.fellowship_id)
    .is('completed_at', null)
    .maybeSingle()

  if (studyError) {
    console.error('[fellowship-study-advance] Study fetch error:', studyError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch active study', 500)
  }
  if (!study) throw new AppError('NOT_FOUND', 'No active study found for this fellowship', 404)

  // Count topics in the learning path
  const { count: topicCount, error: countError } = await db
    .from('learning_path_topics')
    .select('id', { count: 'exact', head: true })
    .eq('learning_path_id', study.learning_path_id)

  if (countError) {
    console.error('[fellowship-study-advance] Topic count error:', countError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch topic count', 500)
  }
  if (!topicCount || topicCount <= 0) {
    throw new AppError('DATABASE_ERROR', 'Learning path has no guides configured', 500)
  }
  const totalGuides = topicCount
  const nextIndex = study.current_guide_index + 1
  const isComplete = nextIndex >= totalGuides

  const updateData = isComplete
    ? { completed_at: new Date().toISOString(), updated_at: new Date().toISOString() }
    : { current_guide_index: nextIndex, updated_at: new Date().toISOString() }

  const { error: updateError } = await db
    .from('fellowship_study')
    .update(updateData)
    .eq('id', study.id)

  if (updateError) {
    console.error('[fellowship-study-advance] Update error:', updateError)
    throw new AppError('DATABASE_ERROR', 'Failed to advance study', 500)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        fellowship_id: body.fellowship_id,
        is_complete: isComplete,
        current_guide_index: isComplete ? study.current_guide_index : nextIndex,
        total_guides: totalGuides
      },
      message: isComplete ? 'Learning path completed!' : 'Advanced to next guide'
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleAdvanceStudy, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
