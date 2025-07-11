import { serve } from "https://deno.land/std@0.208.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { ErrorHandler, AppError } from '../_shared/error-handler.ts'
import { StudyGuideService } from '../_shared/study-guide-service.ts'

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
    const { user, isAuthenticated } = await getUserContext(supabaseClient, authHeader)

    // Block anonymous users completely
    if (!isAuthenticated || !user) {
      throw new AppError('UNAUTHORIZED', 'Anonymous access is not allowed for this API', 401)
    }

    const studyGuideService = new StudyGuideService(supabaseClient)

    if (req.method === 'GET') {
      return await handleGetStudyGuides(studyGuideService, user.id, req)
    } else if (req.method === 'POST') {
      return await handleSaveUnsaveGuide(studyGuideService, user.id, req)
    } else {
      throw new AppError('METHOD_NOT_ALLOWED', 'Only GET and POST methods are allowed', 405)
    }

  } catch (error) {
    return ErrorHandler.handleError(error, corsHeaders)
  }
})

async function getUserContext(supabaseClient: any, authHeader: string | null) {
  let user: any = null
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
    // Not authenticated
    console.error('Failed to get user context:', e)
  }

  return { user, isAuthenticated }
}

async function handleGetStudyGuides(
  studyGuideService: StudyGuideService, 
  userId: string,
  req: Request
): Promise<Response> {
  const url = new URL(req.url)
  const savedOnly = url.searchParams.get('saved') === 'true'
  const limit = parseInt(url.searchParams.get('limit') || '20')
  const offset = parseInt(url.searchParams.get('offset') || '0')

  const guides = await studyGuideService.getStudyGuides(userId, savedOnly, limit, offset);

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
  studyGuideService: StudyGuideService,
  userId: string,
  req: Request
): Promise<Response> {
  const requestBody: SaveGuideRequest = await req.json()
  
  if (!requestBody.guide_id || !requestBody.action) {
    throw new AppError('INVALID_REQUEST', 'guide_id and action are required')
  }

  if (!['save', 'unsave'].includes(requestBody.action)) {
    throw new AppError('INVALID_REQUEST', 'action must be "save" or "unsave"')
  }

  if (!requestBody.guide_id || typeof requestBody.guide_id !== 'string') {
    throw new AppError('INVALID_REQUEST', 'Invalid guide_id format')
  }

  const isSaved = requestBody.action === 'save'

  const data = await studyGuideService.updateStudyGuide(userId, requestBody.guide_id, isSaved);

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