/**
 * Conversation History Edge Function
 *
 * Retrieves existing conversation history for a study guide.
 *
 * Authentication: REQUIRED (enforced via createAuthenticatedFunction)
 * - Supports both authenticated users and anonymous sessions
 * - Authenticated users: Queries by user_id
 * - Anonymous users: Queries by session_id
 *
 * Features:
 * - Validates study guide access before loading conversation history
 * - Loads conversation and message history with proper access control
 * - Returns formatted message history for chat interface
 * - Enforces ownership validation via validateStudyGuideAccess
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { UserContext } from '../_shared/types/index.ts'
import { getCorsHeaders } from '../_shared/utils/cors.ts'
import { validateStudyGuideAccess } from '../_shared/services/notes-validation.ts'
import { StudyGuideRepository } from '../_shared/repositories/study-guide-repository.ts'

/**
 * Conversation history request parameters
 */
interface ConversationHistoryRequest {
  readonly study_guide_id: string
}

/**
 * Conversation database record
 */
interface Conversation {
  readonly id: string
  readonly study_guide_id: string
  readonly user_id: string | null
  readonly session_id: string | null
  readonly created_at: string
  readonly updated_at: string
}

/**
 * Message interface for response
 */
interface MessageResponse {
  readonly id: string
  readonly role: 'user' | 'assistant'
  readonly content: string
  readonly tokens_consumed: number
  readonly created_at: string
}

/**
 * Conversation history response
 */
interface ConversationHistoryResponse {
  readonly conversation_id: string
  readonly study_guide_id: string
  readonly messages: MessageResponse[]
}

/**
 * Handles preflight CORS requests
 */
function handlePreflight(req: Request): Response {
  const corsHeaders = getCorsHeaders(req.headers.get('origin'))
  return new Response(null, { status: 200, headers: corsHeaders })
}

/**
 * Returns method not allowed response
 */
function methodNotAllowedResponse(req: Request): Response {
  const corsHeaders = getCorsHeaders(req.headers.get('origin'))
  return new Response(
    JSON.stringify({ error: 'METHOD_NOT_ALLOWED', message: 'Only GET requests are supported' }),
    { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

/**
 * Parses request or returns bad request response
 */
function parseRequestOrBadRequest(req: Request): ConversationHistoryRequest | Response {
  const corsHeaders = getCorsHeaders(req.headers.get('origin'))
  try {
    return parseAndValidateRequest(req)
  } catch (error) {
    const message = error instanceof AppError ? error.message : 'Invalid request format'
    return new Response(
      JSON.stringify({ error: 'INVALID_REQUEST', message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
}

/**
 * Loads history or returns error response
 */
async function loadHistoryOrErrorResponse(
  studyGuideId: string,
  userContext: UserContext,
  services: ServiceContainer,
  req: Request
): Promise<Response> {
  const corsHeaders = getCorsHeaders(req.headers.get('origin'))
  try {
    const conversationHistory = await loadConversationHistory(studyGuideId, userContext, services)
    return successResponse(conversationHistory, req)
  } catch (error) {
    if (error instanceof AppError && error.message.includes('not found')) {
      return new Response(
        JSON.stringify({ error: 'NOT_FOUND', message: 'No conversation history found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    return serverErrorResponse(error, req)
  }
}

/**
 * Returns success response with conversation history
 */
function successResponse(data: ConversationHistoryResponse, req: Request): Response {
  const corsHeaders = getCorsHeaders(req.headers.get('origin'))
  return new Response(
    JSON.stringify({ success: true, data }),
    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

/**
 * Returns server error response
 */
function serverErrorResponse(error: unknown, req: Request): Response {
  const corsHeaders = getCorsHeaders(req.headers.get('origin'))
  const message = error instanceof AppError ? error.message : 'Failed to load conversation history'
  return new Response(
    JSON.stringify({ error: 'SERVER_ERROR', message }),
    { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

/**
 * Handles loading conversation history for a study guide
 */
async function handleConversationHistory(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  // Handle preflight
  if (req.method === 'OPTIONS') {
    return handlePreflight(req)
  }

  // Only support GET
  if (req.method !== 'GET') {
    return methodNotAllowedResponse(req)
  }

  // Require authentication
  if (!userContext) {
    throw new AppError('UNAUTHORIZED', 'User context is required', 401)
  }

  // Parse and validate request
  const parseResult = parseRequestOrBadRequest(req)
  if (parseResult instanceof Response) {
    return parseResult
  }

  const { study_guide_id } = parseResult

  // Load and return conversation history
  return await loadHistoryOrErrorResponse(study_guide_id, userContext, services, req)
}

/**
 * Parses and validates the request parameters
 */
function parseAndValidateRequest(req: Request): ConversationHistoryRequest {
  const url = new URL(req.url);
  const studyGuideId = url.searchParams.get('study_guide_id');

  if (!studyGuideId) {
    throw new AppError('INVALID_REQUEST', 'study_guide_id is required', 400);
  }

  // UUID validation
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuidPattern.test(studyGuideId)) {
    throw new AppError('INVALID_REQUEST', 'study_guide_id must be a valid UUID', 400);
  }

  return {
    study_guide_id: studyGuideId
  };
}

/**
 * Applies user context filter to query (userId or sessionId)
 */
function applyUserContextFilter(query: any, userContext: UserContext): any {
  if (userContext.userId) return query.eq('user_id', userContext.userId)
  if (userContext.sessionId) return query.eq('session_id', userContext.sessionId)
  throw new AppError('INVALID_CONTEXT', 'User context must have userId or sessionId', 400)
}

/**
 * Finds conversation for study guide and user
 */
async function findConversation(
  studyGuideId: string,
  userContext: UserContext,
  services: ServiceContainer
): Promise<Conversation> {
  const supabase = services.supabaseServiceClient
  const baseQuery = supabase
    .from('study_guide_conversations')
    .select('*')
    .eq('study_guide_id', studyGuideId)

  const query = applyUserContextFilter(baseQuery, userContext)
  const { data, error } = await query.single()
  if (error || !data) throw new AppError('NOT_FOUND', 'Conversation not found', 404)
  return data as Conversation
}

/**
 * Loads messages for a conversation
 */
async function loadMessages(conversationId: string, services: ServiceContainer): Promise<MessageResponse[]> {
  const { data, error } = await services.supabaseServiceClient
    .from('conversation_messages')
    .select('id, role, content, tokens_consumed, created_at')
    .eq('conversation_id', conversationId)
    .order('created_at', { ascending: true })

  if (error) throw new AppError('DATABASE_ERROR', 'Failed to load messages', 500)
  return data || []
}

/**
 * Loads conversation history from the database
 */
async function loadConversationHistory(
  studyGuideId: string,
  userContext: UserContext,
  services: ServiceContainer
): Promise<ConversationHistoryResponse> {
  // Validate study guide access
  const studyGuideRepository = new StudyGuideRepository(services.supabaseServiceClient)
  await validateStudyGuideAccess(studyGuideId, userContext, studyGuideRepository)

  // Load conversation and messages
  const conversation = await findConversation(studyGuideId, userContext, services)
  const messages = await loadMessages(conversation.id, services)

  return {
    conversation_id: conversation.id,
    study_guide_id: studyGuideId,
    messages
  }
}

// Wrap the handler in the authenticated function factory
createAuthenticatedFunction(handleConversationHistory);