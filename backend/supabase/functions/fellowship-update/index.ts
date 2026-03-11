/**
 * fellowship-update
 * Mentor updates fellowship name, description, or max_members.
 * PATCH /fellowship-update
 * Auth: Required (mentor only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

async function handleUpdateFellowship(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: { fellowship_id: string; name?: string; description?: string; max_members?: number }
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
    console.error('[fellowship-update] RPC error:', rpcError)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const updates: Record<string, unknown> = { updated_at: new Date().toISOString() }

  if (body.name !== undefined) {
    const name = body.name.trim()
    if (name.length < 3 || name.length > 60) {
      throw new AppError('VALIDATION_ERROR', 'name must be 3–60 characters', 400)
    }

    // Name uniqueness check — case-insensitive, exclude the fellowship being updated
    const { count: nameCount, error: nameCheckError } = await db
      .from('fellowships')
      .select('*', { count: 'exact', head: true })
      .ilike('name', name)
      .eq('is_active', true)
      .neq('id', body.fellowship_id)

    if (nameCheckError) {
      console.error('[fellowship-update] Name check error:', nameCheckError)
      throw new AppError('DATABASE_ERROR', 'Failed to check name availability', 500)
    }
    if ((nameCount || 0) > 0) {
      throw new AppError('CONFLICT', 'A fellowship with this name already exists', 409)
    }

    updates.name = name
  }
  if (body.description !== undefined) {
    const desc = body.description.trim()
    if (desc.length > 500) {
      throw new AppError('VALIDATION_ERROR', 'description must be 500 characters or fewer', 400)
    }
    updates.description = desc || null
  }
  if (body.max_members !== undefined) {
    if (typeof body.max_members !== 'number' || !Number.isInteger(body.max_members) || body.max_members < 2 || body.max_members > 50) {
      throw new AppError('VALIDATION_ERROR', 'max_members must be an integer between 2 and 50', 400)
    }
    updates.max_members = body.max_members
  }

  const hasUpdate = Object.keys(updates).some(k => k !== 'updated_at')
  if (!hasUpdate) {
    throw new AppError('VALIDATION_ERROR', 'No valid fields provided to update', 400)
  }

  const { data: fellowship, error } = await db
    .from('fellowships')
    .update(updates)
    .eq('id', body.fellowship_id)
    .select()
    .single()

  if (error) {
    console.error('[fellowship-update] Update error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to update fellowship', 500)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        id: fellowship.id,
        name: fellowship.name,
        description: fellowship.description,
        max_members: fellowship.max_members,
        updated_at: fellowship.updated_at
      }
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleUpdateFellowship, {
  allowedMethods: ['PATCH'],
  enableAnalytics: true,
  timeout: 10000
})
