/**
 * fellowship-study-set
 * Mentor assigns a learning path as the fellowship's active study.
 * POST /fellowship-study-set
 * Auth: Required (mentor only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleSetStudy(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { fellowship_id: string; learning_path_id: string }
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!body.learning_path_id) throw new AppError('VALIDATION_ERROR', 'learning_path_id is required', 400)

  const db = services.supabaseServiceClient

  const { data: isMentor, error: rpcError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-study-set] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  // Verify learning path exists
  const { data: learningPath, error: pathError } = await db
    .from('learning_paths')
    .select('id, title')
    .eq('id', body.learning_path_id)
    .maybeSingle()

  if (pathError) {
    console.error('[fellowship-study-set] Learning path fetch error:', pathError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify learning path', 500)
  }
  if (!learningPath) throw new AppError('NOT_FOUND', 'Learning path not found', 404)

  // Upsert fellowship_study (replaces any existing active study)
  const { data: study, error } = await db
    .from('fellowship_study')
    .upsert({
      fellowship_id: body.fellowship_id,
      learning_path_id: body.learning_path_id,
      current_guide_index: 0,
      started_at: new Date().toISOString(),
      completed_at: null,
      updated_at: new Date().toISOString()
    }, { onConflict: 'fellowship_id' })
    .select()
    .single()

  if (error) {
    console.error('[fellowship-study-set] Upsert error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to set study', 500)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        fellowship_id: study.fellowship_id,
        learning_path_id: study.learning_path_id,
        learning_path_title: learningPath.title,
        current_guide_index: study.current_guide_index,
        started_at: study.started_at
      }
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleSetStudy, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
