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
import { BibleBookNormalizer } from '../_shared/utils/bible-book-normalizer.ts'
import { VoiceConversationLimitService } from '../_shared/services/voice-conversation-limit-service.ts'
import { isFeatureEnabledForPlan } from '../_shared/services/feature-flag-service.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

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
  | { type: 'monthly_conversation_limit_exceeded'; data: { message: string; conversations_used: number; limit: number; remaining: number; tier: string; month: string } }
  | { type: 'error'; data: { code: string; message: string } }

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
  // Check maintenance mode FIRST
  await checkMaintenanceMode(req, services)

  const startTime = Date.now()
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
  console.log(`👤 [Voice] User plan: ${tier}`)

  // Feature flag validation - Check if ai_discipler is enabled for user's plan
  const hasVoiceAccess = await isFeatureEnabledForPlan('ai_discipler', tier)

  if (!hasVoiceAccess) {
    console.warn(`⛔ [Voice] Feature access denied: ai_discipler not available for plan ${tier}`)
    return new Response(
      JSON.stringify({
        success: false,
        error: {
          code: 'FEATURE_NOT_AVAILABLE',
          message: `AI Discipler voice conversation is not available for your current plan (${tier}). Please upgrade to Plus or Premium to access this feature.`,
          requiredFeature: 'ai_discipler',
          currentPlan: tier
        }
      }),
      { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  console.log(`✅ [Voice] Feature access granted: ai_discipler available for plan ${tier}`)

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

    // Check monthly conversation limit for NEW conversations only
    // A conversation is considered new if it has no prior messages in history
    const isNewConversation = conversationHistory.length === 0

    if (isNewConversation) {
      console.log(`[Voice] New conversation detected: ${conversation_id}, checking monthly limit for user ${userId} (tier: ${tier})`)

      // Initialize monthly limit service
      const limitService = new VoiceConversationLimitService(services.supabaseServiceClient)

      try {
        const limitStatus = await limitService.checkMonthlyLimit(userId, tier)

        if (!limitStatus.canStart) {
          console.log(`[Voice] Monthly limit exceeded for user ${userId}: ${limitStatus.conversationsUsed}/${limitStatus.limit}`)

          await sendEvent({
            type: 'monthly_conversation_limit_exceeded',
            data: {
              message: limitService.getMonthlyLimitMessage(tier, limitStatus.conversationsUsed, limitStatus.limit),
              conversations_used: limitStatus.conversationsUsed,
              limit: limitStatus.limit,
              remaining: limitStatus.remaining,
              tier: limitStatus.tier,
              month: limitStatus.month || new Date().toISOString().substring(0, 7)
            }
          })
          return // Stop execution - do not proceed with conversation
        }

        console.log(`[Voice] Monthly limit OK for user ${userId}: ${limitStatus.conversationsUsed}/${limitStatus.limit} (${limitStatus.remaining} remaining)`)

        // Increment monthly counter AFTER we know the conversation will proceed
        // Using fire-and-forget pattern (non-blocking)
        // This will be incremented again after successful message save
        limitService.incrementMonthlyCounter(userId, tier)
          .catch(err => console.error(`[Voice] Failed to increment monthly counter for user ${userId}:`, err))

      } catch (limitError) {
        console.error(`[Voice] Error checking monthly limit for user ${userId}:`, limitError)
        // Fail-open: if limit check fails, allow conversation to proceed
        // This prevents service disruption if the limit checking system has issues
      }
    }

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

    // Normalize Bible book names (auto-correct common abbreviations and mistakes)
    const normalizer = new BibleBookNormalizer(language_code)
    const normalizedResponse = normalizer.normalizeBibleBooks(fullResponse)

    // Validate and log any corrections made
    const validation = normalizer.validateBibleBooks(fullResponse)
    if (validation.correctedBooks.length > 0 || validation.invalidBooks.length > 0) {
      normalizer.logValidationWarnings(validation, conversation_id)
    }

    // Extract scripture references from normalized response using shared utility
    const scriptureRefs = normalizer.extractScriptureReferences(normalizedResponse)

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

      // Save assistant message (using normalized response with corrected book names)
      await voiceConversationRepository.saveMessage({
        conversationId: conversation_id,
        userId,
        role: 'assistant',
        content: normalizedResponse,
        language: language_code,
        metadata: {
          llmModelUsed: modelUsed,
          scriptureReferences: scriptureRefs,
          bookNamesCorrected: validation.correctedBooks.length > 0,
          correctionsMade: validation.correctedBooks
        }
      })

      // Log usage for profitability tracking
      try {
        const latencyMs = Date.now() - startTime

        // Estimate token usage for voice conversation
        const inputTokens = message.length * 4 // Rough estimate
        const outputTokens = normalizedResponse.length * 4

        // Calculate LLM cost based on model used
        let llmCost = 0
        if (modelUsed.includes('openai') || modelUsed.includes('gpt')) {
          const costCalc = services.costTrackingService.calculateCost(
            'openai',
            modelUsed,
            inputTokens,
            outputTokens
          )
          llmCost = costCalc.totalCost
        } else if (modelUsed.includes('anthropic') || modelUsed.includes('claude')) {
          const costCalc = services.costTrackingService.calculateCost(
            'anthropic',
            modelUsed,
            inputTokens,
            outputTokens
          )
          llmCost = costCalc.totalCost
        }

        await services.usageLoggingService.logVoiceConversation(
          userId,
          tier,
          llmCost,
          language_code,
          latencyMs,
          true // success
        )
      } catch (usageLogError) {
        console.error('[Voice] Usage logging failed:', usageLogError)
        // Don't fail the request if usage logging fails
      }

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
