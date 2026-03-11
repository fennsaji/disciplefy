/**
 * fellowship-reports-create
 * Member reports a post or comment.
 * POST /fellowship-reports-create
 * Auth: Required (member only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleCreateReport(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { fellowship_id: string; content_type: string; content_id: string; reason: string }
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!body.content_type || !['post', 'comment'].includes(body.content_type)) {
    throw new AppError('VALIDATION_ERROR', 'content_type must be "post" or "comment"', 400)
  }
  if (!body.content_id) throw new AppError('VALIDATION_ERROR', 'content_id is required', 400)
  const reason = body.reason?.trim() || ''
  if (reason.length < 5 || reason.length > 500) {
    throw new AppError('VALIDATION_ERROR', 'reason must be 5–500 characters', 400)
  }

  const db = services.supabaseServiceClient

  const { data: isMember, error: rpcError } = await db.rpc('is_fellowship_member', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id
  })
  if (rpcError) {
    console.error('[fellowship-reports-create] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify membership', 500)
  }
  if (!isMember) throw new AppError('PERMISSION_DENIED', 'Must be a fellowship member', 403)

  const { data: report, error } = await db
    .from('fellowship_reports')
    .insert({
      fellowship_id: body.fellowship_id,
      reporter_user_id: user.id,
      content_type: body.content_type,
      content_id: body.content_id,
      reason
    })
    .select()
    .single()

  if (error) {
    console.error('[fellowship-reports-create] Insert error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to submit report', 500)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: { id: report.id, status: report.status, created_at: report.created_at },
      message: 'Report submitted. Thank you for keeping the fellowship safe.'
    }),
    { status: 201, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleCreateReport, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
