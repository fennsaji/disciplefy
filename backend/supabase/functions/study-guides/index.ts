import { serve } from "https://deno.land/std@0.208.0/http/server.ts"
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { ErrorHandler, AppError } from '../_shared/error-handler.ts'
import { 
  StudyGuideRepository,
  StudyGuideResponse,
  UserContext
} from '../_shared/repositories/study-guide-repository.ts'

/**
 * Request payload for save/unsave operations.
 */
interface SaveGuideRequest {
  readonly guide_id: string
  readonly action: 'save' | 'unsave'
}

/**
 * Response payload for study guide operations.
 */
interface StudyGuideManagementApiResponse {
  readonly success: true
  readonly data: {
    readonly guides?: StudyGuideResponse[]
    readonly guide?: StudyGuideResponse
    readonly total?: number
    readonly hasMore?: boolean
    readonly message?: string
  }
}

/**
 * Study Guide Management Edge Function
 * 
 * Handles retrieval and save/unsave operations for study guides
 * using the cached architecture with content deduplication.
 */
serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createSupabaseClient(req)
    const repository = new StudyGuideRepository(supabaseClient)

    // Get user context
    const userContext = await getUserContext(supabaseClient, req)

    // Route to appropriate handler
    switch (req.method) {
      case 'GET':
        return await handleGetStudyGuides(repository, userContext, req)
      case 'POST':
        return await handleSaveUnsaveGuide(repository, userContext, req)
      case 'DELETE':
        return await handleDeleteGuide(repository, userContext, req)
      default:
        throw new AppError(
          'METHOD_NOT_ALLOWED',
          'Only GET, POST, and DELETE methods are allowed',
          405
        )
    }

  } catch (error) {
    return ErrorHandler.handleError(error, corsHeaders)
  }
})

/**
 * Creates configured Supabase client.
 * Uses service role for database operations but validates user tokens separately.
 */
function createSupabaseClient(req: Request): SupabaseClient {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  return createClient(supabaseUrl, supabaseServiceKey, {
    global: {
      headers: { 
        Authorization: req.headers.get('Authorization') || '' 
      },
    },
  })
}

/**
 * Creates a separate client for user authentication validation.
 */
function createAuthClient(req: Request): SupabaseClient {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!

  return createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { 
        Authorization: req.headers.get('Authorization') || '' 
      },
    },
  })
}

/**
 * Extracts user context from request.
 * Uses separate auth client for user validation.
 */
async function getUserContext(
  supabaseClient: SupabaseClient,
  req: Request
): Promise<UserContext> {
  const authHeader = req.headers.get('Authorization')
  
  // Check for session ID (anonymous user)
  const sessionId = req.headers.get('x-session-id')
  
  if (authHeader?.startsWith('Bearer ')) {
    try {
      // Create separate auth client for user validation
      const authClient = createAuthClient(req)
      const { data: { user } } = await authClient.auth.getUser(
        authHeader.replace('Bearer ', '')
      )
      
      if (user) {
        return {
          type: 'authenticated',
          userId: user.id
        }
      }
    } catch (error) {
      console.warn('Failed to authenticate user:', error)
    }
  }

  // Handle anonymous user
  if (sessionId) {
    return {
      type: 'anonymous',
      sessionId: sessionId
    }
  }

  throw new AppError(
    'UNAUTHORIZED',
    'Authentication required. Provide either Bearer token or x-session-id header',
    401
  )
}

/**
 * Handles GET requests to retrieve study guides.
 */
async function handleGetStudyGuides(
  repository: StudyGuideRepository,
  userContext: UserContext,
  req: Request
): Promise<Response> {
  const url = new URL(req.url)
  const savedOnly = url.searchParams.get('saved') === 'true'
  const limit = Math.min(
    parseInt(url.searchParams.get('limit') || '20'),
    100
  )
  const offset = Math.max(
    parseInt(url.searchParams.get('offset') || '0'),
    0
  )

  // Get user's study guides
  const guides = await repository.getUserStudyGuides(userContext, {
    savedOnly,
    limit,
    offset
  })

  const response: StudyGuideManagementApiResponse = {
    success: true,
    data: {
      guides,
      total: guides.length,
      hasMore: guides.length === limit
    }
  }

  return new Response(JSON.stringify(response), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    status: 200,
  })
}

/**
 * Handles POST requests to save/unsave study guides.
 */
async function handleSaveUnsaveGuide(
  repository: StudyGuideRepository,
  userContext: UserContext,
  req: Request
): Promise<Response> {
  const requestBody: SaveGuideRequest = await req.json()

  // Validate request
  validateSaveRequest(requestBody)

  const isSaved = requestBody.action === 'save'

  // Update save status
  const updatedGuide = await repository.updateSaveStatus(
    requestBody.guide_id,
    isSaved,
    userContext
  )

  const response: StudyGuideManagementApiResponse = {
    success: true,
    data: {
      guide: updatedGuide,
      message: `Study guide ${requestBody.action}d successfully`
    }
  }

  return new Response(JSON.stringify(response), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    status: 200,
  })
}

/**
 * Handles DELETE requests to remove study guides.
 */
async function handleDeleteGuide(
  repository: StudyGuideRepository,
  userContext: UserContext,
  req: Request
): Promise<Response> {
  const url = new URL(req.url)
  const guideId = url.searchParams.get('id')

  if (!guideId) {
    throw new AppError(
      'INVALID_REQUEST',
      'Guide ID is required as query parameter',
      400
    )
  }

  // Note: In cached architecture, we only delete the user's relationship
  // to the content, not the cached content itself
  await repository.deleteUserGuideRelationship(guideId, userContext)

  const response: StudyGuideManagementApiResponse = {
    success: true,
    data: {
      message: 'Study guide removed successfully'
    }
  }

  return new Response(JSON.stringify(response), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    status: 200,
  })
}

/**
 * Validates save/unsave request.
 */
function validateSaveRequest(request: SaveGuideRequest): void {
  if (!request.guide_id || typeof request.guide_id !== 'string') {
    throw new AppError(
      'INVALID_REQUEST',
      'guide_id is required and must be a string',
      400
    )
  }

  if (!request.action || !['save', 'unsave'].includes(request.action)) {
    throw new AppError(
      'INVALID_REQUEST',
      'action must be either "save" or "unsave"',
      400
    )
  }
}

/**
 * Extension to StudyGuideRepository for deletion operations.
 */
declare module '../_shared/repositories/study-guide-repository.ts' {
  interface StudyGuideRepository {
    deleteUserGuideRelationship(guideId: string, userContext: UserContext): Promise<void>
  }
}

// Add the delete method to the repository
StudyGuideRepository.prototype.deleteUserGuideRelationship = async function(
  guideId: string,
  userContext: UserContext
): Promise<void> {
  if (userContext.type === 'authenticated') {
    const { error } = await this.supabase
      .from('user_study_guides_new')
      .delete()
      .eq('study_guide_id', guideId)
      .eq('user_id', userContext.userId!)

    if (error) {
      throw new AppError(
        'DATABASE_ERROR',
        `Failed to delete user study guide relationship: ${error.message}`,
        500
      )
    }
  } else {
    const { error } = await this.supabase
      .from('anonymous_study_guides_new')
      .delete()
      .eq('study_guide_id', guideId)
      .eq('session_id', userContext.sessionId!)

    if (error) {
      throw new AppError(
        'DATABASE_ERROR',
        `Failed to delete anonymous study guide relationship: ${error.message}`,
        500
      )
    }
  }
}