/**
 * Study Guide Follow-up Questions Edge Function
 *
 * Handles streaming follow-up questions about existing study guides.
 * Features:
 * - Server-Sent Events (SSE) for real-time streaming
 * - 5 token cost per follow-up question
 * - Conversation history management
 * - Secure authentication and rate limiting
 * - Context-aware responses based on study guide content
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { SupportedLanguage } from '../_shared/types/token-types.ts'
import { UserContext } from '../_shared/types/index.ts'
import { getCorsHeaders } from '../_shared/utils/cors.ts'
import { isFeatureEnabledForPlan } from '../_shared/services/feature-flag-service.ts'
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Request payload for follow-up questions
 */
interface FollowUpRequest {
  readonly study_guide_id: string
  readonly question: string
  readonly language?: string
}

/**
 * Conversation message interface
 */
interface ConversationMessage {
  readonly id: string
  readonly role: 'user' | 'assistant'
  readonly content: string
  readonly tokens_consumed: number
  readonly created_at: string
}

/**
 * Partial conversation message for history queries (without tokens_consumed)
 */
interface ConversationHistoryMessage {
  readonly id: string
  readonly role: 'user' | 'assistant'
  readonly content: string
  readonly created_at: string
}

/**
 * Study guide database record
 */
interface StudyGuide {
  readonly id: string
  readonly input_type: string
  readonly input_value: string
  readonly summary: string | null
  readonly interpretation: string | null
  readonly context: string | null
  readonly language: string | null
  readonly created_at: string
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
}


/**
 * Extract authentication credentials from request
 */
function extractAuthCredentials(req: Request): { authToken: string | null; apiKey: string | null } {
  const url = new URL(req.url)
  let authToken = url.searchParams.get('authorization') // From query params (EventSource)
  let apiKey = url.searchParams.get('apikey') // From query params (EventSource)

  // Fallback to headers if query params not found (standard requests)
  if (!authToken) {
    const authHeader = req.headers.get('authorization')
    if (authHeader?.startsWith('Bearer ')) {
      authToken = authHeader.substring(7) // Remove 'Bearer ' prefix
    }
  }

  if (!apiKey) {
    apiKey = req.headers.get('apikey')
  }

  return { authToken, apiKey }
}

/**
 * Parse request parameters from GET or POST
 */
function parseRequestParams(req: Request): { study_guide_id: string; question: string; language: string } | null {
  if (req.method === 'GET') {
    const url = new URL(req.url)
    const study_guide_id = url.searchParams.get('study_guide_id') || ''
    const question = url.searchParams.get('question') || ''
    const language = url.searchParams.get('language') || 'en'
    
    console.log('🔍 [FOLLOW-UP] GET request with query params:', { study_guide_id, question, language })
    return { study_guide_id, question, language }
  }
  
  return null // Will be handled by POST parsing in main handler
}

/**
 * Find or create conversation for study guide and user
 */
async function getOrCreateConversation(
  supabaseClient: SupabaseClient,
  studyGuideId: string,
  userContext: UserContext
): Promise<Conversation> {
  // First, try to find existing conversation
  if (userContext.userId) {
    const { data, error } = await supabaseClient
      .from('study_guide_conversations')
      .select('*')
      .eq('study_guide_id', studyGuideId)
      .eq('user_id', userContext.userId)
      .single()

    if (data) {
      console.log('💬 [FOLLOW-UP] Found existing conversation:', data.id)
      return data
    }
  } else if (userContext.sessionId) {
    const { data, error } = await supabaseClient
      .from('study_guide_conversations')
      .select('*')
      .eq('study_guide_id', studyGuideId)
      .eq('session_id', userContext.sessionId)
      .single()

    if (data) {
      console.log('💬 [FOLLOW-UP] Found existing conversation:', data.id)
      return data
    }
  }

  // Create new conversation
  const { data: newConversation, error: createError } = await supabaseClient
    .from('study_guide_conversations')
    .insert({
      study_guide_id: studyGuideId,
      user_id: userContext.userId || null,
      session_id: userContext.sessionId || null
    })
    .select()
    .single()

  if (createError) {
    console.error('❌ [FOLLOW-UP] Failed to create conversation:', createError)
    throw new AppError('SERVER_ERROR', 'Failed to create conversation', 500)
  }

  console.log('💬 [FOLLOW-UP] Created new conversation:', newConversation.id)
  return newConversation
}

/**
 * Build LLM context from study guide and conversation history
 */
function buildLLMContext(
  studyGuide: StudyGuide,
  conversationHistory: ConversationHistoryMessage[],
  targetLanguage: SupportedLanguage
): { systemMessage: string; conversationContext: string } {
  let studyContext = `Study Guide for: ${studyGuide.input_value || 'No input'} (${studyGuide.input_type || 'unknown'})\n`
  studyContext += `Summary: ${studyGuide.summary || 'No summary available'}\n`
  studyContext += `Context: ${studyGuide.context || 'No additional context'}`
  
  if (studyGuide.interpretation) {
    studyContext += `\nInterpretation: ${studyGuide.interpretation}`
  }

  const conversationContext = conversationHistory.length > 0
    ? conversationHistory.map(msg => `${msg.role}: ${msg.content}`).join('\n')
    : 'No previous conversation'

  // Language-specific instructions for output
  const languageInstructions: Record<SupportedLanguage, string> = {
    'en': 'Output only in clear, accessible English.',
    'hi': 'Output only in simple, everyday Hindi (avoid complex Sanskrit words, use common spoken Hindi). हिंदी में ही उत्तर दें।',
    'ml': 'Output only in simple, everyday Malayalam (avoid complex literary words, use common spoken Malayalam). മലയാളത്തിൽ മാത്രം ഉത്തരം നൽകുക।'
  }

  const languageInstruction = languageInstructions[targetLanguage] || languageInstructions['en']

  const systemMessage = `You are a Bible study assistant helping users explore Scripture deeper.
  Provide thoughtful, theologically sound responses to follow-up questions about this study guide.
  Keep responses pastoral, accessible, and grounded in orthodox Christian theology.

  **CRITICAL LANGUAGE REQUIREMENT:**
  ${languageInstruction}
  You MUST respond in ${targetLanguage === 'hi' ? 'Hindi' : targetLanguage === 'ml' ? 'Malayalam' : 'English'} language ONLY. Do not use any other language.

  **IMPORTANT: Keep responses brief and concise (3-4 sentences max, 80-100 words). Be direct and helpful.**
  **STRICT FORMAT & LENGTH RULES:
  - Output must be valid **Markdown**.
  - Keep it brief: **3-4 sentences total (80–100 words)** unless the user explicitly requests more.
  - Use **bold** for emphasis.
  - Use *italics* for Scripture references (e.g., *John 3:16*).
  - **Insert a blank line between paragraphs.**
  - For lists, always use **numbered Markdown lists** (e.g., "1. ", "2. ", "3. "). Each item on its own line.
  - Never return code fences unless the user asks for code.

  EXAMPLE OF CORRECT MARKDOWN:
  Bold sentence with a key idea.

  1. First item  
  2. Second item  
  3. Third item
  **

  Study Guide Context:
  ${studyContext}

  Previous Conversation:
  ${conversationContext}`

  return { systemMessage, conversationContext }
}

/**
 * Study guide follow-up handler with streaming support
 */
async function handleStudyFollowUp(
  req: Request,
  { llmService, tokenService, analyticsLogger, securityValidator, authService, supabaseServiceClient, usageLoggingService, costTrackingService }: ServiceContainer
): Promise<Response> {
  console.log('🚀 [FOLLOW-UP] Starting follow-up question handler')

  const corsHeaders = getCorsHeaders(req.headers.get('origin'))

  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  // Authenticate user
  let userContext: UserContext
  let authReq: Request

  try {
    const { authToken, apiKey } = extractAuthCredentials(req)

    console.log('🔐 [FOLLOW-UP] Auth extraction:', {
      hasAuthToken: !!authToken,
      hasApiKey: !!apiKey,
      method: req.method
    })

    if (!authToken && !apiKey) {
      return new Response(
        JSON.stringify({ error: 'UNAUTHORIZED', message: 'Missing authorization header or query parameter' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create request object with auth token for validation
    authReq = new Request(req.url, {
      method: req.method,
      headers: new Headers({
        'Authorization': authToken ? `Bearer ${authToken}` : '',
        'apikey': apiKey || ''
      })
    })

    // Use authService to validate and get user context
    userContext = await authService.getUserContext(authReq)

    console.log('✅ [FOLLOW-UP] Authentication successful:', {
      userType: userContext.type,
      hasUserId: !!userContext.userId,
      hasSessionId: !!userContext.sessionId
    })

  } catch (error) {
    console.error('❌ [FOLLOW-UP] Authentication failed:', error)
    return new Response(
      JSON.stringify({
        error: 'UNAUTHORIZED',
        message: error instanceof Error ? error.message : 'Authentication failed'
      }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Determine user plan using AuthService (use authReq with proper headers)
  const userPlan = await authService.getUserPlan(authReq)
  console.log(`👤 [FOLLOW-UP] User plan: ${userPlan}`)

  // Feature flag validation - Check if study_chat is enabled for user's plan
  const hasFollowUpAccess = await isFeatureEnabledForPlan('study_chat', userPlan)

  if (!hasFollowUpAccess) {
    console.warn(`⛔ [FOLLOW-UP] Feature access denied: study_chat not available for plan ${userPlan}`)
    return new Response(
      JSON.stringify({
        error: 'FEATURE_NOT_AVAILABLE',
        message: `Study Chat is not available for your current plan (${userPlan}). Please upgrade to Standard, Plus, or Premium to ask follow-up questions.`,
        requiredFeature: 'study_chat',
        plan: userPlan
      }),
      { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  console.log(`✅ [FOLLOW-UP] Feature access granted: study_chat available for plan ${userPlan}`)

  // Parse request parameters
  let study_guide_id: string
  let question: string
  let language: string = 'en'

  const getParams = parseRequestParams(req)
  if (getParams) {
    ({ study_guide_id, question, language } = getParams)
  } else {
    // Regular POST request with JSON body
    let requestBody: FollowUpRequest
    try {
      requestBody = await req.json()
    } catch (error) {
      return new Response(
        JSON.stringify({ error: 'INVALID_JSON', message: 'Invalid JSON in request body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    study_guide_id = requestBody.study_guide_id
    question = requestBody.question
    language = requestBody.language || 'en'
    
    console.log('📝 [FOLLOW-UP] POST request with JSON body:', { study_guide_id, question, language })
  }

  if (!study_guide_id || !question) {
    return new Response(
      JSON.stringify({ error: 'MISSING_FIELDS', message: 'study_guide_id and question are required' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Load study guide from database
  let studyGuide: StudyGuide
  try {
    const { data, error } = await supabaseServiceClient
      .from('study_guides')
      .select('id, input_type, input_value, summary, interpretation, context, language, created_at')
      .eq('id', study_guide_id)
      .single()

    if (error) {
      console.error('❌ [FOLLOW-UP] Study guide query failed:', error)
      return new Response(
        JSON.stringify({ error: 'NOT_FOUND', message: 'Study guide not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!data) {
      return new Response(
        JSON.stringify({ error: 'NOT_FOUND', message: 'Study guide not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    studyGuide = data

    console.log('🔍 [FOLLOW-UP] Study guide loaded:', {
      id: studyGuide.id,
      input_type: studyGuide.input_type,
      input_value: studyGuide.input_value,
      language: studyGuide.language
    })

  } catch (error) {
    console.error('❌ [FOLLOW-UP] Failed to load study guide:', error)
    return new Response(
      JSON.stringify({ error: 'SERVER_ERROR', message: 'Failed to load study guide' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Find or create conversation
  let conversation: Conversation
  try {
    conversation = await getOrCreateConversation(supabaseServiceClient, study_guide_id, userContext)
  } catch (error) {
    console.error('❌ [FOLLOW-UP] Conversation handling failed:', error)
    return new Response(
      JSON.stringify({ error: 'SERVER_ERROR', message: 'Failed to handle conversation' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Determine target language from study guide (not request parameter)
  const targetLanguage = (studyGuide.language || 'en') as SupportedLanguage
  console.log('🌐 [FOLLOW-UP] Target language determined:', {
    studyGuideLanguage: studyGuide.language,
    targetLanguage,
    requestLanguage: language // For comparison
  })
  const followUpTokenCost = 5 // Fixed 5 tokens for follow-up questions

  // Define follow-up limits per plan
  const followUpLimits: Record<string, number> = {
    'free': 3,
    'standard': 10,
    'premium': 20
  }

  const maxFollowUps = followUpLimits[userPlan] || followUpLimits['free']
  console.log('📊 [FOLLOW-UP] Plan limits:', {
    userPlan,
    maxFollowUps
  })

  // CRITICAL: Load conversation history FIRST to check limits BEFORE consuming tokens
  let conversationHistory: ConversationHistoryMessage[] = []
  let userQuestionCount = 0
  try {
    const { data, error } = await supabaseServiceClient
      .from('conversation_messages')
      .select('id, role, content, created_at')
      .eq('conversation_id', conversation.id)
      .order('created_at', { ascending: true })

    if (!error && data) {
      conversationHistory = data
      // Count user questions (to check against limit)
      userQuestionCount = data.filter(msg => msg.role === 'user').length
      
      console.log('📜 [FOLLOW-UP] Loaded conversation history:', {
        totalMessages: conversationHistory.length,
        userQuestions: userQuestionCount,
        maxAllowed: maxFollowUps
      })

      // Check if user has exceeded follow-up limit BEFORE consuming tokens
      if (userQuestionCount >= maxFollowUps) {
        console.warn('🚫 [FOLLOW-UP] Follow-up limit exceeded (BEFORE token consumption):', {
          currentCount: userQuestionCount,
          maxAllowed: maxFollowUps,
          userPlan
        })
        return new Response(
          JSON.stringify({
            error: 'FOLLOW_UP_LIMIT_EXCEEDED',
            message: `You have reached the maximum of ${maxFollowUps} follow-up questions for this study guide`,
            current: userQuestionCount,
            max: maxFollowUps,
            plan: userPlan
          }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

  } catch (error) {
    console.error('❌ [FOLLOW-UP] Failed to load conversation history:', error)
    return new Response(
      JSON.stringify({ error: 'SERVER_ERROR', message: 'Failed to load conversation history' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Only consume tokens AFTER passing the limit check
  try {
    const result = await tokenService.consumeTokens(
      userContext.userId || userContext.sessionId || 'unknown',
      userPlan,
      followUpTokenCost,
      {
        userId: userContext.userId,
        sessionId: userContext.sessionId,
        userPlan: userPlan,
        operation: 'consume',
        language: targetLanguage,
        ipAddress: req.headers.get('x-forwarded-for') || undefined,
        timestamp: new Date(),
        // Usage history context
        featureName: 'study_followup',
        operationType: 'follow_up_question',
        studyMode: undefined, // Study mode not available in follow-up context
        contentTitle: question.length > 50 ? question.substring(0, 47) + '...' : question,
        contentReference: `Q: ${question.substring(0, 100)}`,
        inputType: 'question'
      }
    )

    if (!result.success) {
      console.warn('🪙 [FOLLOW-UP] Token consumption failed:', result.errorMessage)
      return new Response(
        JSON.stringify({
          error: 'TOKEN_LIMIT_EXCEEDED',
          message: result.errorMessage || 'Token limit exceeded'
        }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('🪙 [FOLLOW-UP] Token consumption successful:', {
      cost: followUpTokenCost,
      userPlan,
      remaining: result.totalTokens
    })

  } catch (error) {
    console.error('❌ [FOLLOW-UP] Token service error:', error)
    
    // Check if it's an AppError with specific code
    if (error instanceof AppError) {
      if (error.code === 'INSUFFICIENT_TOKENS') {
        return new Response(
          JSON.stringify({
            error: 'TOKEN_LIMIT_EXCEEDED',
            message: error.message || 'Insufficient tokens'
          }),
          { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      // Other AppErrors
      return new Response(
        JSON.stringify({ error: error.code, message: error.message }),
        { status: error.statusCode || 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Generic error fallback
    return new Response(
      JSON.stringify({ error: 'SERVER_ERROR', message: 'Token validation failed' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Store user message in database AFTER token consumption succeeds
  let userMessage: ConversationMessage
  try {
    const { data, error } = await supabaseServiceClient
      .from('conversation_messages')
      .insert({
        conversation_id: conversation.id,
        role: 'user',
        content: question,
        tokens_consumed: followUpTokenCost
      })
      .select()
      .single()

    if (error) {
      console.error('❌ [FOLLOW-UP] Failed to store user message:', error)
      return new Response(
        JSON.stringify({ error: 'SERVER_ERROR', message: 'Failed to store message' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    userMessage = data
    console.log('💾 [FOLLOW-UP] User message stored:', userMessage.id)

  } catch (error) {
    console.error('❌ [FOLLOW-UP] Message storage failed:', error)
    return new Response(
      JSON.stringify({ error: 'SERVER_ERROR', message: 'Failed to store message' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Check if this is an EventSource request
  const acceptsEventStream = req.headers.get('accept')?.includes('text/event-stream') ||
                            req.headers.get('cache-control') === 'no-cache'

  if (acceptsEventStream || req.method === 'GET') {
    console.log('🌊 [FOLLOW-UP] Setting up EventSource response')

    // Create a readable stream for Server-Sent Events
    const stream = new ReadableStream({
      start(controller) {
        // Send connection established event
        controller.enqueue(new TextEncoder().encode(`data: ${JSON.stringify({
          type: 'connection',
          message: 'Connected to follow-up service',
          conversation_id: conversation.id
        })}\n\n`))

        // Generate real LLM follow-up response
        const processFollowUpQuestion = async () => {
          try {
            // Use only last 10 messages for context to avoid token bloat
            const recentHistory = conversationHistory.slice(-10)
            const { systemMessage } = buildLLMContext(studyGuide, recentHistory, targetLanguage)
            const userMessage = `Follow-up question: ${question}`

            // Generate follow-up response using LLM service
            const { response, usage: followUpUsage } = await llmService.generateFollowUpResponse(
              { systemMessage, userMessage },
              targetLanguage
            )

            // Split response into chunks and send with delay
            const chunks = response.match(/.{1,25}/g) || [response]
            let chunkIndex = 0

            const sendChunk = async () => {
              if (chunkIndex < chunks.length) {
                controller.enqueue(new TextEncoder().encode(`data: ${JSON.stringify({
                  type: 'content',
                  content: chunks[chunkIndex]
                })}\n\n`))
                chunkIndex++
                setTimeout(sendChunk, 150) // 150ms delay between chunks
              } else {
                // Store assistant response in database
                try {
                  const { data: assistantMessage, error } = await supabaseServiceClient
                    .from('conversation_messages')
                    .insert({
                      conversation_id: conversation.id,
                      role: 'assistant',
                      content: response,
                      tokens_consumed: 0 // Assistant responses don't consume user tokens
                    })
                    .select()
                    .single()

                  if (error) {
                    console.error('❌ [FOLLOW-UP] Failed to store assistant message:', error)
                    throw error
                  }

                  console.log('💾 [FOLLOW-UP] Assistant message stored:', assistantMessage.id)

                  // Log usage for profitability tracking (streaming path)
                  try {
                    await usageLoggingService.logUsage({
                      userId: userContext.userId || userContext.sessionId || 'anonymous',
                      tier: userPlan,
                      featureName: 'study_followup',
                      operationType: 'create',
                      tokensConsumed: 5, // App tokens for follow-up
                      llmProvider: followUpUsage.provider,
                      llmModel: followUpUsage.model,
                      llmInputTokens: followUpUsage.inputTokens,
                      llmOutputTokens: followUpUsage.outputTokens,
                      llmCostUsd: followUpUsage.costUsd,
                      requestMetadata: {
                        study_guide_id: study_guide_id,
                        conversation_id: conversation.id,
                        question_length: question.length
                      },
                      responseMetadata: {
                        success: true,
                        response_length: response.length
                      }
                    })
                    console.log(`💰 [FOLLOW-UP] Usage logged: ${followUpUsage.totalTokens} tokens, $${followUpUsage.costUsd.toFixed(4)}`)
                  } catch (logError) {
                    console.error('⚠️ [FOLLOW-UP] Failed to log usage:', logError)
                  }

                  controller.enqueue(new TextEncoder().encode(`data: ${JSON.stringify({
                    type: 'complete',
                    message_id: assistantMessage.id
                  })}\n\n`))
                  controller.close()

                } catch (error) {
                  console.error('❌ [FOLLOW-UP] Assistant message storage failed:', error)
                  controller.enqueue(new TextEncoder().encode(`data: ${JSON.stringify({
                    type: 'error',
                    message: 'Failed to store response'
                  })}\n\n`))
                  controller.close()
                }
              }
            }

            // Start sending chunks after a brief delay
            setTimeout(sendChunk, 300)
          } catch (error) {
            console.error('[FOLLOW-UP] Stream error:', error)
            controller.enqueue(new TextEncoder().encode(`data: ${JSON.stringify({
              type: 'error',
              message: 'Failed to generate response'
            })}\n\n`))
            controller.close()
          }
        }

        processFollowUpQuestion()
      }
    })

    return new Response(stream, {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      }
    })
  } else {
    // Regular JSON response for non-streaming requests
    console.log('📝 [FOLLOW-UP] Sending JSON response')

    try {
      // Use only last 10 messages for context to avoid token bloat
      const recentHistory = conversationHistory.slice(-10)
      const { systemMessage } = buildLLMContext(studyGuide, recentHistory, targetLanguage)
      const userMessage = `Follow-up question: ${question}`

      // Generate follow-up response using LLM service
      const { response, usage: followUpUsage } = await llmService.generateFollowUpResponse(
        { systemMessage, userMessage },
        targetLanguage
      )

      // Store assistant message in database
      const { data: assistantMessage, error } = await supabaseServiceClient
        .from('conversation_messages')
        .insert({
          conversation_id: conversation.id,
          role: 'assistant',
          content: response,
          tokens_consumed: 0 // Assistant responses don't consume user tokens
        })
        .select()
        .single()

      if (error) {
        console.error('❌ [FOLLOW-UP] Failed to store assistant message (JSON):', error)
        return new Response(
          JSON.stringify({ error: 'SERVER_ERROR', message: 'Failed to store response' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      console.log('💾 [FOLLOW-UP] Assistant message stored (JSON):', assistantMessage.id)

      // Log usage for profitability tracking (JSON path)
      try {
        await usageLoggingService.logUsage({
          userId: userContext.userId || userContext.sessionId || 'anonymous',
          tier: userPlan,
          featureName: 'study_followup',
          operationType: 'create',
          tokensConsumed: 5, // App tokens for follow-up
          llmProvider: followUpUsage.provider,
          llmModel: followUpUsage.model,
          llmInputTokens: followUpUsage.inputTokens,
          llmOutputTokens: followUpUsage.outputTokens,
          llmCostUsd: followUpUsage.costUsd,
          requestMetadata: {
            study_guide_id: study_guide_id,
            conversation_id: conversation.id,
            question_length: question.length
          },
          responseMetadata: {
            success: true,
            response_length: response.length
          }
        })
        console.log(`💰 [FOLLOW-UP] Usage logged (JSON): ${followUpUsage.totalTokens} tokens, $${followUpUsage.costUsd.toFixed(4)}`)
      } catch (usageLogError) {
        console.error('Usage logging failed (JSON):', usageLogError)
      }

      const responseObj = {
        success: true,
        data: {
          response,
          message_id: assistantMessage.id,
          conversation_id: conversation.id,
          language: targetLanguage
        }
      }

      return new Response(JSON.stringify(responseObj), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })

    } catch (error) {
      console.error('❌ [FOLLOW-UP] LLM generation failed (JSON):', error)
      return new Response(
        JSON.stringify({ error: 'SERVER_ERROR', message: 'Failed to generate response' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
  }
}

// Wrap the handler in the simple function factory (bypasses Kong authentication)
// Allow both GET (for EventSource) and POST (for regular requests)
createSimpleFunction(handleStudyFollowUp, {
  allowedMethods: ['GET', 'POST', 'OPTIONS']
})