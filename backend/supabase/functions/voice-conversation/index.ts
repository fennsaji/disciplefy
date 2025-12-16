/**
 * Voice Conversation Edge Function
 *
 * Handles AI Discipler voice conversations with streaming responses.
 * Features:
 * - Server-Sent Events (SSE) for real-time streaming
 * - Multi-language support (English, Hindi, Malayalam)
 * - Conversation context management via VoiceConversationRepository
 * - Message limits via VoiceQuotaService
 * - LLM streaming with fallback via VoiceStreamingService
 */

import { createFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { UserContext } from '../_shared/types/index.ts'
import {
  getVoiceSystemPrompt,
  getVoiceExamples,
  getPrimaryTranslation
} from '../_shared/prompts/voice-conversation-prompts.ts'
import { StreamMessage } from '../_shared/services/voice-streaming-service.ts'

/**
 * Request payload for voice conversation
 */
interface VoiceConversationRequest {
  conversation_id: string
  message: string
  language_code?: string
  related_study_guide_id?: string
  related_scripture?: string
}

/**
 * SSE event types
 */
type SSEEvent =
  | { type: 'stream_start'; data: { timestamp: number } }
  | { type: 'content'; data: { text: string } }
  | { type: 'stream_end'; data: { timestamp: number; scripture_references: string[]; translation: string } }
  | { type: 'message_limit_status'; data: { messageCount: number; limit: number; remaining: number } }
  | { type: 'conversation_limit_exceeded'; data: { message: string; messageCount: number; limit: number } }
  | { type: 'error'; data: { code: string; message: string } }

/**
 * Extract scripture references from text using regex
 * Supports English, Hindi (Devanagari), and Malayalam scripts
 */
function extractScriptureReferences(text: string): string[] {
  // Pattern supports:
  // - English: "John 3:16", "1 John 3:16", "Genesis 1:1-3"
  // - Hindi (Devanagari \u0900-\u097F): "यूहन्ना 3:16", "उत्पत्ति 1:1"
  // - Malayalam (\u0D00-\u0D7F): "യോഹന്നാൻ 3:16", "ഉല്പത്തി 1:1"
  const pattern = /(?:\d\s)?(?:[A-Za-z]+|[\u0900-\u097F]+|[\u0D00-\u0D7F]+)\s+\d+(?::\d+(?:-\d+)?)?/g
  const matches = text.match(pattern) || []
  return [...new Set(matches)]
}

/**
 * Parse request data from GET or POST
 */
function parseRequest(req: Request): VoiceConversationRequest {
  const url = new URL(req.url)

  if (req.method === 'GET') {
    return {
      conversation_id: url.searchParams.get('conversation_id') || '',
      message: url.searchParams.get('message') || '',
      language_code: url.searchParams.get('language_code') || 'en-US',
      related_study_guide_id: url.searchParams.get('related_study_guide_id') || undefined,
      related_scripture: url.searchParams.get('related_scripture') || undefined,
    }
  }

  // For POST, we'll parse JSON in the handler
  return {
    conversation_id: '',
    message: '',
    language_code: 'en-US'
  }
}

/**
 * Create SSE response with streaming handler
 */
function createSSEResponse(
  handler: (sendEvent: (event: SSEEvent) => Promise<void>) => Promise<void>,
  corsHeaders: Record<string, string>
): Response {
  const encoder = new TextEncoder()
  const stream = new TransformStream()
  const writer = stream.writable.getWriter()

  const sendEvent = async (event: SSEEvent) => {
    const data = JSON.stringify(event.data)
    await writer.write(encoder.encode(`event: ${event.type}\ndata: ${data}\n\n`))
  }

  // Run handler in background
  handler(sendEvent)
    .catch(async (error) => {
      console.error('[Voice] Handler error:', error)
      try {
        await sendEvent({
          type: 'error',
          data: {
            code: 'SERVER_ERROR',
            message: error instanceof Error ? error.message : 'An error occurred'
          }
        })
      } catch {
        // Ignore write errors during cleanup
      }
    })
    .finally(async () => {
      try {
        await writer.close()
      } catch {
        // Ignore close errors
      }
    })

  return new Response(stream.readable, {
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  })
}

/**
 * Main voice conversation handler
 */
async function handleVoiceConversation(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  const corsHeaders = {
    'Access-Control-Allow-Origin': req.headers.get('origin') || '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  }

  // Require authentication
  if (!userContext?.userId) {
    return new Response(
      JSON.stringify({ success: false, error: { code: 'UNAUTHORIZED', message: 'Authentication required' } }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  const userId = userContext.userId

  // Parse request
  let requestData: VoiceConversationRequest
  if (req.method === 'POST') {
    try {
      requestData = await req.json()
    } catch (error) {
      console.error('[Voice] Failed to parse JSON request body:', error)
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: { 
            code: 'INVALID_JSON', 
            message: 'Request body contains malformed JSON' 
          } 
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
  } else {
    requestData = parseRequest(req)
  }

  const {
    conversation_id,
    message,
    language_code = 'en-US',
    related_study_guide_id,
    related_scripture
  } = requestData

  // Validate required fields
  if (!conversation_id || !message) {
    return new Response(
      JSON.stringify({ success: false, error: { code: 'INVALID_REQUEST', message: 'Missing required fields' } }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Get user's subscription tier
  const tier = await services.authService.getUserPlan(req)

  // Return SSE streaming response
  return createSSEResponse(async (sendEvent) => {
    const {
      voiceConversationRepository,
      voiceStreamingService,
      voiceQuotaService
    } = services

    // Check message limit (non-premium users have 50 messages per conversation)
    const limitResult = await voiceQuotaService.checkMessageLimit(conversation_id, tier)

    if (!limitResult.canProceed) {
      await sendEvent({
        type: 'conversation_limit_exceeded',
        data: {
          message: 'This conversation has reached the maximum message limit. Please start a new conversation.',
          messageCount: limitResult.messageCount,
          limit: limitResult.limit
        }
      })
      return
    }

    // Send message limit status for non-premium users
    if (tier !== 'premium') {
      await sendEvent({
        type: 'message_limit_status',
        data: {
          messageCount: limitResult.messageCount,
          limit: limitResult.limit,
          remaining: limitResult.remaining
        }
      })
    }

    // Get contexts in parallel
    const [userContextData, studyContext, conversationHistory] = await Promise.all([
      voiceConversationRepository.getUserContext(userId),
      related_study_guide_id
        ? voiceConversationRepository.getStudyContext(related_study_guide_id)
        : Promise.resolve(null),
      voiceConversationRepository.getConversationHistory(conversation_id)
    ])

    // Build system prompt
    const systemPrompt = getVoiceSystemPrompt(language_code, {
      maturityLevel: userContextData.maturityLevel,
      currentStudy: studyContext || related_scripture || 'General conversation',
      recentTopics: userContextData.recentTopics,
    })

    // Build LLM messages
    const llmMessages: StreamMessage[] = [
      { role: 'system', content: systemPrompt },
      ...getVoiceExamples(language_code).map(ex => ({
        role: ex.role as 'user' | 'assistant',
        content: ex.content
      })),
      ...conversationHistory.map(msg => ({
        role: msg.role,
        content: msg.content
      })),
      { role: 'user', content: message }
    ]

    // Stream AI response - defer message persistence until streaming succeeds
    let fullResponse = ''
    const modelUsed = voiceStreamingService.selectModel(tier)
    let streamingSucceeded = false

    console.log(`[Voice] Starting stream for conversation: ${conversation_id}, tier: ${tier}, model: ${modelUsed}`)

    try {
      await sendEvent({
        type: 'stream_start',
        data: { timestamp: Date.now() }
      })

      for await (const chunk of voiceStreamingService.stream(llmMessages, tier)) {
        fullResponse += chunk
        await sendEvent({
          type: 'content',
          data: { text: chunk }
        })
      }

      // Mark streaming as successful only after complete iteration
      streamingSucceeded = true
    } catch (streamError) {
      console.error(`[Voice] Streaming failed for conversation ${conversation_id}:`, streamError)
      await sendEvent({
        type: 'error',
        data: {
          code: 'STREAMING_ERROR',
          message: 'Failed to generate response. Please try again.'
        }
      })
      // Do not save any messages on streaming failure
      return
    }

    // Only persist messages after streaming succeeds
    if (!streamingSucceeded || !fullResponse.trim()) {
      console.error(`[Voice] Streaming incomplete for conversation ${conversation_id}`)
      await sendEvent({
        type: 'error',
        data: {
          code: 'INCOMPLETE_RESPONSE',
          message: 'Response generation was incomplete. Please try again.'
        }
      })
      return
    }

    // Extract scripture references
    const scriptureRefs = extractScriptureReferences(fullResponse)

    // Save both messages together after successful streaming
    // This ensures no orphaned messages on failure
    try {
      // Save user message first
      await voiceConversationRepository.saveMessage({
        conversationId: conversation_id,
        userId,
        role: 'user',
        content: message,
        language: language_code
      })

      // Save assistant message
      await voiceConversationRepository.saveMessage({
        conversationId: conversation_id,
        userId,
        role: 'assistant',
        content: fullResponse,
        language: language_code,
        metadata: {
          llmModelUsed: modelUsed,
          scriptureReferences: scriptureRefs,
        }
      })
    } catch (saveError) {
      console.error(`[Voice] Failed to save messages for conversation ${conversation_id}:`, saveError)
      // Streaming succeeded but save failed - still send the response to user
      // The messages won't be persisted but user gets the response
      await sendEvent({
        type: 'error',
        data: {
          code: 'SAVE_WARNING',
          message: 'Response generated but conversation history may not be saved.'
        }
      })
    }

    // Send completion event
    await sendEvent({
      type: 'stream_end',
      data: {
        timestamp: Date.now(),
        scripture_references: scriptureRefs,
        translation: getPrimaryTranslation(language_code),
      }
    })

    console.log(`[Voice] Completed stream for conversation: ${conversation_id}`)

  }, corsHeaders)
}

// Export using function factory
createFunction(handleVoiceConversation, {
  allowedMethods: ['GET', 'POST', 'OPTIONS'],
  requireAuth: false, // We handle auth manually for SSE support
  enableAnalytics: true,
  timeout: 120000 // 2 minutes for streaming
})
