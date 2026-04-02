/**
 * fellowship-study  (merged)
 * Routes:
 *   POST /fellowship-study/set      → assign learning path as active study (mentor only)
 *   POST /fellowship-study/advance  → advance to next guide / mark complete (mentor only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

// ---------------------------------------------------------------------------
// Set study  POST /fellowship-study/set
// ---------------------------------------------------------------------------

async function handleSetStudy(req: Request, services: ServiceContainer): Promise<Response> {
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
    console.error('[fellowship-study/set] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const { data: learningPath, error: pathError } = await db
    .from('learning_paths')
    .select('id, title')
    .eq('id', body.learning_path_id)
    .maybeSingle()

  if (pathError) {
    console.error('[fellowship-study/set] Learning path fetch error:', pathError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify learning path', 500)
  }
  if (!learningPath) throw new AppError('NOT_FOUND', 'Learning path not found', 404)

  // Read current study to preserve completed path history
  const { data: currentStudy } = await db
    .from('fellowship_study')
    .select('learning_path_id, completed_at, completed_path_ids')
    .eq('fellowship_id', body.fellowship_id)
    .maybeSingle()

  // Accumulate completed paths: carry over existing history, and add current
  // path if it was completed before being replaced by the new one.
  const existingCompleted: string[] = (currentStudy?.completed_path_ids as string[]) ?? []
  const newCompleted = new Set<string>(existingCompleted)
  if (currentStudy?.completed_at && currentStudy?.learning_path_id) {
    newCompleted.add(currentStudy.learning_path_id as string)
  }
  // Remove the newly assigned path from completed set (it's being restarted)
  newCompleted.delete(body.learning_path_id)

  const { data: study, error } = await db
    .from('fellowship_study')
    .upsert({
      fellowship_id: body.fellowship_id,
      learning_path_id: body.learning_path_id,
      current_guide_index: 0,
      started_at: new Date().toISOString(),
      completed_at: null,
      updated_at: new Date().toISOString(),
      completed_path_ids: Array.from(newCompleted),
    }, { onConflict: 'fellowship_id' })
    .select()
    .single()

  if (error) {
    console.error('[fellowship-study/set] Upsert error:', error)
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

// ---------------------------------------------------------------------------
// Advance study  POST /fellowship-study/advance
// ---------------------------------------------------------------------------

async function handleAdvanceStudy(req: Request, services: ServiceContainer): Promise<Response> {
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
    console.error('[fellowship-study/advance] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const { data: study, error: studyError } = await db
    .from('fellowship_study')
    .select('id, current_guide_index, learning_path_id')
    .eq('fellowship_id', body.fellowship_id)
    .is('completed_at', null)
    .maybeSingle()

  if (studyError) {
    console.error('[fellowship-study/advance] Study fetch error:', studyError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch active study', 500)
  }
  if (!study) throw new AppError('NOT_FOUND', 'No active study found for this fellowship', 404)

  const { count: topicCount, error: countError } = await db
    .from('learning_path_topics')
    .select('id', { count: 'exact', head: true })
    .eq('learning_path_id', study.learning_path_id)

  if (countError) {
    console.error('[fellowship-study/advance] Topic count error:', countError)
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

  const { error: updateError } = await db.from('fellowship_study').update(updateData).eq('id', study.id)

  if (updateError) {
    console.error('[fellowship-study/advance] Update error:', updateError)
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

// ---------------------------------------------------------------------------
// Reset study  POST /fellowship-study/reset
// ---------------------------------------------------------------------------

async function handleResetStudy(req: Request, services: ServiceContainer): Promise<Response> {
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
    console.error('[fellowship-study/reset] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const { data: study, error: studyError } = await db
    .from('fellowship_study')
    .select('id, learning_path_id')
    .eq('fellowship_id', body.fellowship_id)
    .maybeSingle()

  if (studyError) {
    console.error('[fellowship-study/reset] Study fetch error:', studyError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch study', 500)
  }
  if (!study) throw new AppError('NOT_FOUND', 'No study found for this fellowship', 404)

  const now = new Date().toISOString()
  const { error: updateError } = await db
    .from('fellowship_study')
    .update({
      current_guide_index: 0,
      completed_at: null,
      started_at: now,
      updated_at: now,
    })
    .eq('id', study.id)

  if (updateError) {
    console.error('[fellowship-study/reset] Update error:', updateError)
    throw new AppError('DATABASE_ERROR', 'Failed to reset study', 500)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        fellowship_id: body.fellowship_id,
        learning_path_id: study.learning_path_id,
        current_guide_index: 0,
      },
      message: 'Study progress reset to Guide 1'
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

async function handleStudy(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  if (req.method !== 'POST') throw new AppError('METHOD_NOT_ALLOWED', 'Method not allowed', 405)

  const pathname = new URL(req.url).pathname
  if (pathname.endsWith('/set'))     return handleSetStudy(req, services)
  if (pathname.endsWith('/advance')) return handleAdvanceStudy(req, services)
  if (pathname.endsWith('/reset'))   return handleResetStudy(req, services)

  throw new AppError('NOT_FOUND', 'Route not found', 404)
}

createSimpleFunction(handleStudy, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000,
})
