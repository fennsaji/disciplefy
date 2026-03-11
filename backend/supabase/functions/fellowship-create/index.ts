/**
 * fellowship-create
 * Creates a new fellowship and adds the creator as mentor.
 * POST /fellowship-create
 * Auth: Required
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

interface CreateFellowshipRequest {
  name: string
  description?: string
  max_members?: number
  is_public?: boolean
  language?: 'en' | 'hi' | 'ml'
}

async function handleCreateFellowship(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  await checkMaintenanceMode(req, services)

  // Auth
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: CreateFellowshipRequest
  try {
    body = await req.json() as CreateFellowshipRequest
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }

  // Validate
  if (!body.name || typeof body.name !== 'string') {
    throw new AppError('VALIDATION_ERROR', 'name is required', 400)
  }
  const name = body.name.trim()
  if (name.length < 3 || name.length > 60) {
    throw new AppError('VALIDATION_ERROR', 'name must be 3–60 characters', 400)
  }
  if (body.max_members !== undefined) {
    if (typeof body.max_members !== 'number' || !Number.isInteger(body.max_members) || body.max_members < 2 || body.max_members > 50) {
      throw new AppError('VALIDATION_ERROR', 'max_members must be an integer between 2 and 50', 400)
    }
  }

  if (body.description && body.description.trim().length > 500) {
    throw new AppError('VALIDATION_ERROR', 'description must be 500 characters or fewer', 400)
  }

  // Validate language
  const language = body.language ?? 'en'
  if (!['en', 'hi', 'ml'].includes(language)) {
    throw new AppError('VALIDATION_ERROR', 'language must be en, hi, or ml', 400)
  }

  const db = services.supabaseServiceClient

  // Name uniqueness check — case-insensitive, active fellowships only
  const { count: nameCount, error: nameCheckError } = await db
    .from('fellowships')
    .select('*', { count: 'exact', head: true })
    .ilike('name', name)
    .eq('is_active', true)

  if (nameCheckError) {
    console.error('[fellowship-create] Name check error:', nameCheckError)
    throw new AppError('DATABASE_ERROR', 'Failed to check name availability', 500)
  }
  if ((nameCount || 0) > 0) {
    throw new AppError('CONFLICT', 'A fellowship with this name already exists', 409)
  }

  // Admin gate: only admins may create public fellowships
  if (body.is_public === true) {
    const { data: profile, error: profileError } = await services.supabaseServiceClient
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .maybeSingle()
    if (profileError) {
      console.error('[fellowship-create] Profile lookup error:', profileError)
      throw new AppError('DATABASE_ERROR', 'Failed to verify admin status', 500)
    }
    if (!profile?.is_admin) {
      throw new AppError('PERMISSION_DENIED', 'Only admins can create public fellowships', 403)
    }
  }

  // Create fellowship
  const { data: fellowship, error: createError } = await db
    .from('fellowships')
    .insert({
      name,
      description: body.description?.trim() || null,
      mentor_user_id: user.id,
      max_members: body.max_members || 12,
      is_public: body.is_public ?? false,
      language,
    })
    .select()
    .single()

  if (createError) {
    console.error('[fellowship-create] DB error:', createError)
    throw new AppError('DATABASE_ERROR', 'Failed to create fellowship', 500)
  }

  // Add creator as mentor member
  const { error: memberError } = await db
    .from('fellowship_members')
    .insert({
      fellowship_id: fellowship.id,
      user_id: user.id,
      role: 'mentor'
    })

  if (memberError) {
    console.error('[fellowship-create] Member insert error:', memberError)
    // Attempt cleanup
    const { error: cleanupError } = await db.from('fellowships').delete().eq('id', fellowship.id)
    if (cleanupError) {
      console.error('[fellowship-create] Cleanup failed — orphaned fellowship:', fellowship.id, cleanupError)
    }
    throw new AppError('DATABASE_ERROR', 'Failed to initialize fellowship membership', 500)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        id: fellowship.id,
        name: fellowship.name,
        description: fellowship.description,
        max_members: fellowship.max_members,
        is_public: fellowship.is_public,
        language: fellowship.language,
        mentor_user_id: fellowship.mentor_user_id,
        created_at: fellowship.created_at
      },
      message: 'Fellowship created successfully'
    }),
    { status: 201, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleCreateFellowship, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 10000
})
