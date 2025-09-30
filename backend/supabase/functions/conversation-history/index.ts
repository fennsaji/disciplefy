/**
 * Conversation History Edge Function
 *
 * Retrieves existing conversation history for a study guide.
 * Features:
 * - Loads conversation and message history for authenticated users
 * - Returns formatted message history for chat interface
 * - Handles both authenticated and anonymous users
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { UserContext } from '../_shared/types/index.ts'

/**
 * Conversation history request parameters
 */
interface ConversationHistoryRequest {
  readonly study_guide_id: string
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
 * Handles loading conversation history for a study guide
 */
async function handleConversationHistory(
  req: Request,
  { authService }: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  console.log('🚀 [CONVERSATION-HISTORY] NEW FUNCTION CALLED - createAuthenticatedFunction working!')
  console.log('🚀 [CONVERSATION-HISTORY] Request URL:', req.url)
  console.log('🚀 [CONVERSATION-HISTORY] User context provided:', !!userContext)

  // Add CORS headers for all responses
  const corsHeaders = {
    'Access-Control-Allow-Origin': req.headers.get('origin') || '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info, apikey',
    'Access-Control-Allow-Credentials': 'true',
  };

  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  // Only support GET requests
  if (req.method !== 'GET') {
    return new Response(
      JSON.stringify({ error: 'METHOD_NOT_ALLOWED', message: 'Only GET requests are supported' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // 1. Ensure we have user context (provided by createAuthenticatedFunction)
  if (!userContext) {
    throw new AppError('UNAUTHORIZED', 'User context is required', 401);
  }

  // 2. Parse and validate request
  try {
    var { study_guide_id } = parseAndValidateRequest(req);
  } catch (error) {
    const message = error instanceof AppError ? error.message : 'Invalid request format';
    return new Response(
      JSON.stringify({ error: 'INVALID_REQUEST', message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // 3. Load conversation history
  try {
    const conversationHistory = await loadConversationHistory(study_guide_id, userContext);

    return new Response(JSON.stringify({
      success: true,
      data: conversationHistory
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  } catch (error) {
    if (error instanceof AppError && error.message.includes('not found')) {
      // No conversation found - return 404
      return new Response(
        JSON.stringify({ error: 'NOT_FOUND', message: 'No conversation history found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const message = error instanceof AppError ? error.message : 'Failed to load conversation history';
    return new Response(
      JSON.stringify({ error: 'SERVER_ERROR', message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
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
 * Loads conversation history from the database
 */
async function loadConversationHistory(studyGuideId: string, userContext: any): Promise<ConversationHistoryResponse> {
  const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );

  // Find existing conversation
  const { data: conversation, error: conversationError } = await supabase
    .from('study_guide_conversations')
    .select('*')
    .eq('study_guide_id', studyGuideId)
    .eq('user_id', userContext.userId || userContext.sessionId)
    .single();

  if (conversationError || !conversation) {
    throw new AppError('NOT_FOUND', 'Conversation not found', 404);
  }

  // Load messages for the conversation
  const { data: messages, error: messagesError } = await supabase
    .from('conversation_messages')
    .select('id, role, content, tokens_consumed, created_at')
    .eq('conversation_id', conversation.id)
    .order('created_at', { ascending: true });

  if (messagesError) {
    throw new AppError('DATABASE_ERROR', 'Failed to load messages', 500);
  }

  return {
    conversation_id: conversation.id,
    study_guide_id: studyGuideId,
    messages: messages || []
  };
}

// Wrap the handler in the authenticated function factory
createAuthenticatedFunction(handleConversationHistory);