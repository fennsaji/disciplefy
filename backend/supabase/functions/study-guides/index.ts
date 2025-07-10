import { serve } from "https://deno.land/std@0.208.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { ErrorHandler, AppError } from '../_shared/error-handler.ts'
import { SecurityValidator } from '../_shared/security-validator.ts'

interface SaveGuideRequest {
  guide_id: string
  action: 'save' | 'unsave'
}

interface StudyGuideResponse {
  id: string
  input_type: string
  input_value?: string
  input_value_hash?: string
  summary: string
  interpretation: string
  context: string
  related_verses: string[]
  reflection_questions: string[]
  prayer_points: string[]
  language: string
  is_saved?: boolean
  created_at: string
  updated_at: string
}

serve(async (req: Request) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Get user context
    const authHeader = req.headers.get('Authorization')
    const { user, sessionId, isAuthenticated } = await getUserContext(supabaseClient, authHeader)

    if (req.method === 'GET') {
      return await handleGetStudyGuides(supabaseClient, user?.id, sessionId, isAuthenticated, req)
    } else if (req.method === 'POST') {
      return await handleSaveUnsaveGuide(supabaseClient, user?.id, sessionId, isAuthenticated, req)
    } else {
      throw new AppError('METHOD_NOT_ALLOWED', 'Only GET and POST methods are allowed', 405)
    }

  } catch (error) {
    return ErrorHandler.handleError(error, corsHeaders)
  }
})

async function getUserContext(supabaseClient: any, authHeader: string | null) {
  let user = null
  let sessionId = null
  let isAuthenticated = false

  try {
    if (authHeader?.startsWith('Bearer ')) {
      const { data: { user: authUser } } = await supabaseClient.auth.getUser(authHeader.replace('Bearer ', ''))
      if (authUser) {
        user = authUser
        isAuthenticated = true
      }
    }
  } catch (e) {
    // Not authenticated, will use session-based approach
  }

  if (!isAuthenticated) {
    // For anonymous users, try to extract session ID from request
    sessionId = 'anonymous-session'  // This should come from request body or headers
  }

  return { user, sessionId, isAuthenticated }
}

async function handleGetStudyGuides(
  supabaseClient: any, 
  userId: string | undefined, 
  sessionId: string | null,
  isAuthenticated: boolean,
  req: Request
): Promise<Response> {
  const url = new URL(req.url)
  const savedOnly = url.searchParams.get('saved') === 'true'
  const limit = parseInt(url.searchParams.get('limit') || '20')
  const offset = parseInt(url.searchParams.get('offset') || '0')

  let query
  let guides: StudyGuideResponse[] = []

  if (isAuthenticated && userId) {
    // Fetch authenticated user's guides
    query = supabaseClient
      .from('study_guides')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1)

    if (savedOnly) {
      query = query.eq('is_saved', true)
    }

    const { data, error } = await query

    if (error) {
      throw new AppError('DATABASE_ERROR', `Failed to fetch study guides: ${error.message}`)
    }

    guides = data || []
  } else if (sessionId) {
    // Fetch anonymous user's guides
    const { data, error } = await supabaseClient
      .from('anonymous_study_guides')
      .select('*')
      .eq('session_id', sessionId)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1)

    if (error) {
      throw new AppError('DATABASE_ERROR', `Failed to fetch anonymous study guides: ${error.message}`)
    }

    guides = data || []
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        guides: guides.map(formatStudyGuideResponse),
        total: guides.length,
        hasMore: guides.length === limit
      }
    }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    }
  )
}

async function handleSaveUnsaveGuide(
  supabaseClient: any,
  userId: string | undefined,
  sessionId: string | null,
  isAuthenticated: boolean,
  req: Request
): Promise<Response> {
  if (!isAuthenticated || !userId) {
    throw new AppError('UNAUTHORIZED', 'Authentication required to save guides', 401)
  }

  const requestBody: SaveGuideRequest = await req.json()
  
  // Validate request
  if (!requestBody.guide_id || !requestBody.action) {
    throw new AppError('INVALID_REQUEST', 'guide_id and action are required')
  }

  if (!['save', 'unsave'].includes(requestBody.action)) {
    throw new AppError('INVALID_REQUEST', 'action must be "save" or "unsave"')
  }

  // Validate input
  await SecurityValidator.validateInput(requestBody.guide_id, 'guid')

  const isSaved = requestBody.action === 'save'

  // Update the guide's saved status
  const { data, error } = await supabaseClient
    .from('study_guides')
    .update({ 
      is_saved: isSaved,
      updated_at: new Date().toISOString()
    })
    .eq('id', requestBody.guide_id)
    .eq('user_id', userId)  // Ensure user can only modify their own guides
    .select()
    .single()

  if (error) {
    if (error.code === 'PGRST116') {
      throw new AppError('NOT_FOUND', 'Study guide not found or you do not have permission to modify it')
    }
    throw new AppError('DATABASE_ERROR', `Failed to ${requestBody.action} study guide: ${error.message}`)
  }

  if (!data) {
    throw new AppError('NOT_FOUND', 'Study guide not found')
  }

  return new Response(
    JSON.stringify({
      success: true,
      message: `Guide ${requestBody.action}d successfully`,
      data: {
        guide: formatStudyGuideResponse(data)
      }
    }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    }
  )
}

function formatStudyGuideResponse(guide: any): StudyGuideResponse {
  return {
    id: guide.id,
    input_type: guide.input_type,
    input_value: guide.input_value,
    input_value_hash: guide.input_value_hash,
    summary: guide.summary,
    interpretation: guide.interpretation || '',
    context: guide.context,
    related_verses: guide.related_verses || [],
    reflection_questions: guide.reflection_questions || [],
    prayer_points: guide.prayer_points || [],
    language: guide.language || 'en',
    is_saved: guide.is_saved || false,
    created_at: guide.created_at,
    updated_at: guide.updated_at
  }
}