/**
 * Study Guide Generation V2 Edge Function - Streaming SSE
 *
 * This endpoint provides streaming study guide generation using Server-Sent Events (SSE).
 * Sections are emitted progressively as they're parsed from the LLM response.
 *
 * SSE Event Types:
 * - init: {"status":"started"|"cache_hit","estimatedSections":6}
 * - section: {"type":"summary"|"interpretation"|etc,"content":"...","index":0,"total":6}
 * - complete: {"studyGuideId":"uuid","tokensConsumed":20,"fromCache":false}
 * - error: {"code":"LM-E-001","message":"...","retryable":true}
 *
 * Authentication is handled via query parameters for EventSource compatibility:
 * - authorization: Bearer token (without "Bearer " prefix)
 * - apikey: Supabase anon key
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { StudyGuideInput } from '../_shared/types/index.ts'
import { SupportedLanguage } from '../_shared/types/token-types.ts'
import { UserContext } from '../_shared/types/index.ts'
import type { StudyMode } from '../_shared/services/llm-types.ts'
import { getCorsHeaders } from '../_shared/utils/cors.ts'
import {
  StreamingJsonParser,
  createInitEvent,
  createSectionEvent,
  createCompleteEvent,
  createErrorEvent,
  ParsedSection,
  CompleteStudyGuide
} from '../_shared/services/streaming-json-parser.ts'

/**
 * Extract authentication credentials from request (query params for EventSource)
 */
function extractAuthCredentials(req: Request): { authToken: string | null; apiKey: string | null } {
  const url = new URL(req.url)
  let authToken = url.searchParams.get('authorization')
  let apiKey = url.searchParams.get('apikey')

  // Fallback to headers for non-EventSource requests
  if (!authToken) {
    const authHeader = req.headers.get('authorization')
    if (authHeader?.startsWith('Bearer ')) {
      authToken = authHeader.substring(7)
    }
  }

  if (!apiKey) {
    apiKey = req.headers.get('apikey')
  }

  return { authToken, apiKey }
}

/**
 * Parse request parameters from query string
 */
function parseRequestParams(req: Request): {
  input_type: 'scripture' | 'topic' | 'question'
  input_value: string
  topic_description?: string
  language: string
  study_mode: StudyMode
} | null {
  const url = new URL(req.url)

  const input_type = url.searchParams.get('input_type') as 'scripture' | 'topic' | 'question' | null
  const input_value = url.searchParams.get('input_value')
  const topic_description = url.searchParams.get('topic_description') || undefined
  const language = url.searchParams.get('language') || 'en'
  const mode = url.searchParams.get('mode') as StudyMode | null

  if (!input_type || !input_value) {
    return null
  }

  if (!['scripture', 'topic', 'question'].includes(input_type)) {
    return null
  }

  // Validate and default study mode
  const validModes: StudyMode[] = ['quick', 'standard', 'deep', 'lectio']
  const study_mode: StudyMode = mode && validModes.includes(mode) ? mode : 'standard'

  return { input_type, input_value, topic_description, language, study_mode }
}

/**
 * Check if the current user is the original creator of the cached content
 */
function checkIsCreator(
  content: { creatorUserId?: string | null; creatorSessionId?: string | null },
  userContext: UserContext
): boolean {
  // Legacy guides (no creator tracked) - free for all
  if (!content.creatorUserId && !content.creatorSessionId) {
    return true
  }

  if (userContext.type === 'authenticated') {
    return content.creatorUserId === userContext.userId
  } else {
    return content.creatorSessionId === userContext.sessionId
  }
}

/**
 * Stream cached content with delays for smooth UX
 */
async function* streamCachedContent(
  studyGuide: CompleteStudyGuide
): AsyncGenerator<string, void, unknown> {
  const sections: ParsedSection[] = [
    { type: 'summary', content: studyGuide.summary, index: 0 },
    { type: 'interpretation', content: studyGuide.interpretation, index: 1 },
    { type: 'context', content: studyGuide.context, index: 2 },
    { type: 'relatedVerses', content: studyGuide.relatedVerses, index: 3 },
    { type: 'reflectionQuestions', content: studyGuide.reflectionQuestions, index: 4 },
    { type: 'prayerPoints', content: studyGuide.prayerPoints, index: 5 }
  ]

  // Add optional sections if present (in SECTION_ORDER)
  let currentIndex = 6

  if (studyGuide.interpretationInsights) {
    sections.push({ type: 'interpretationInsights', content: studyGuide.interpretationInsights, index: currentIndex++ })
  }
  if (studyGuide.summaryInsights) {
    sections.push({ type: 'summaryInsights', content: studyGuide.summaryInsights, index: currentIndex++ })
  }
  if (studyGuide.reflectionAnswers) {
    sections.push({ type: 'reflectionAnswers', content: studyGuide.reflectionAnswers, index: currentIndex++ })
  }
  if (studyGuide.contextQuestion) {
    sections.push({ type: 'contextQuestion', content: studyGuide.contextQuestion, index: currentIndex++ })
  }
  if (studyGuide.summaryQuestion) {
    sections.push({ type: 'summaryQuestion', content: studyGuide.summaryQuestion, index: currentIndex++ })
  }
  if (studyGuide.relatedVersesQuestion) {
    sections.push({ type: 'relatedVersesQuestion', content: studyGuide.relatedVersesQuestion, index: currentIndex++ })
  }
  if (studyGuide.reflectionQuestion) {
    sections.push({ type: 'reflectionQuestion', content: studyGuide.reflectionQuestion, index: currentIndex++ })
  }
  if (studyGuide.prayerQuestion) {
    sections.push({ type: 'prayerQuestion', content: studyGuide.prayerQuestion, index: currentIndex++ })
  }

  const totalSections = sections.length

  for (const section of sections) {
    yield createSectionEvent(section, totalSections)
    // Small delay between cached sections for smooth UX
    await new Promise(resolve => setTimeout(resolve, 50))
  }
}

/**
 * Main handler for streaming study guide generation
 */
async function handleStudyGenerateV2(
  req: Request,
  {
    authService,
    llmService,
    studyGuideRepository,
    tokenService,
    analyticsLogger,
    securityValidator
  }: ServiceContainer
): Promise<Response> {
  console.log('🚀 [STUDY-V2] Starting streaming study guide generation')

  const corsHeaders = getCorsHeaders(req.headers.get('origin'))

  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders })
  }

  // Only allow GET for EventSource
  if (req.method !== 'GET') {
    return new Response(
      JSON.stringify({ error: 'METHOD_NOT_ALLOWED', message: 'Use GET for SSE streaming' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Authenticate user
  let userContext: UserContext
  let authReq: Request

  try {
    const { authToken, apiKey } = extractAuthCredentials(req)

    if (!authToken && !apiKey) {
      return new Response(
        JSON.stringify({ error: 'UNAUTHORIZED', message: 'Missing authorization' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    authReq = new Request(req.url, {
      method: req.method,
      headers: new Headers({
        'Authorization': authToken ? `Bearer ${authToken}` : '',
        'apikey': apiKey || ''
      })
    })

    userContext = await authService.getUserContext(authReq)

    console.log('✅ [STUDY-V2] Authentication successful:', {
      userType: userContext.type,
      hasUserId: !!userContext.userId,
      hasSessionId: !!userContext.sessionId
    })
  } catch (error) {
    console.error('❌ [STUDY-V2] Authentication failed:', error)
    return new Response(
      JSON.stringify({
        error: 'UNAUTHORIZED',
        message: error instanceof Error ? error.message : 'Authentication failed'
      }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Parse request parameters
  const params = parseRequestParams(req)
  if (!params) {
    return new Response(
      JSON.stringify({
        error: 'INVALID_REQUEST',
        message: 'Missing required parameters: input_type, input_value'
      }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  const { input_type, input_value, topic_description, language, study_mode } = params

  console.log(`📝 [STUDY-V2] Study mode: ${study_mode}`)

  // Security validation
  const securityResult = await securityValidator.validateInput(input_value, input_type)
  if (!securityResult.isValid) {
    await analyticsLogger.logEvent('security_violation', {
      event_type: securityResult.eventType,
      risk_score: securityResult.riskScore,
      action_taken: 'BLOCKED',
      user_id: userContext.userId,
      session_id: userContext.sessionId
    }, req.headers.get('x-forwarded-for'))

    return new Response(
      JSON.stringify({
        error: 'SECURITY_VIOLATION',
        message: securityResult.message
      }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Check for cached content (including study_mode for mode-specific caching)
  const studyGuideInput: StudyGuideInput = {
    type: input_type,
    value: input_value,
    language: language,
    study_mode: study_mode
  }

  const existingContent = await studyGuideRepository.findExistingContent(studyGuideInput, userContext)

  // Get user plan and calculate token cost
  const userPlan = await authService.getUserPlan(authReq)
  const targetLanguage = (language || 'en') as SupportedLanguage
  const tokenCost = tokenService.calculateTokenCost(targetLanguage)
  const identifier = userContext.type === 'authenticated' ? userContext.userId! : userContext.sessionId!

  // Create SSE response stream
  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder()

      const emit = (data: string) => {
        controller.enqueue(encoder.encode(data))
      }

      const emitError = (code: string, message: string, retryable: boolean) => {
        emit(createErrorEvent(code, message, retryable))
        controller.close()
      }

      try {
        // Handle cached content
        if (existingContent) {
          const isCreator = checkIsCreator(existingContent, userContext)

          // Non-creator needs to pay tokens for cached content
          if (!isCreator && !tokenService.isUnlimitedPlan(userPlan)) {
            const consumptionResult = await tokenService.consumeTokens(
              identifier,
              userPlan,
              tokenCost,
              {
                userId: userContext.userId,
                sessionId: userContext.sessionId,
                userPlan: userPlan,
                operation: 'consume',
                language: targetLanguage,
                ipAddress: req.headers.get('x-forwarded-for') || undefined,
                timestamp: new Date()
              }
            )

            if (!consumptionResult.success) {
              emitError('TOKEN_LIMIT_EXCEEDED', consumptionResult.errorMessage || 'Insufficient tokens', false)
              return
            }
          }

          console.log('📦 [STUDY-V2] Streaming cached content')

          // Stream cached sections (content is nested under 'content' property from repository)
          // Spread readonly arrays to create mutable copies for CompleteStudyGuide type
          const cachedGuide: CompleteStudyGuide = {
            summary: existingContent.content.summary || '',
            interpretation: existingContent.content.interpretation || '',
            context: existingContent.content.context || '',
            relatedVerses: [...(existingContent.content.relatedVerses || [])],
            reflectionQuestions: [...(existingContent.content.reflectionQuestions || [])],
            prayerPoints: [...(existingContent.content.prayerPoints || [])],
            // Reflection Mode fields - insights and answers
            interpretationInsights: existingContent.content.interpretationInsights
              ? [...existingContent.content.interpretationInsights]
              : undefined,
            summaryInsights: existingContent.content.summaryInsights
              ? [...existingContent.content.summaryInsights]
              : undefined,
            reflectionAnswers: existingContent.content.reflectionAnswers
              ? [...existingContent.content.reflectionAnswers]
              : undefined,
            // Reflection Mode fields - dynamic questions
            contextQuestion: existingContent.content.contextQuestion || undefined,
            summaryQuestion: existingContent.content.summaryQuestion || undefined,
            relatedVersesQuestion: existingContent.content.relatedVersesQuestion || undefined,
            reflectionQuestion: existingContent.content.reflectionQuestion || undefined,
            prayerQuestion: existingContent.content.prayerQuestion || undefined
          }

          // Calculate total sections for this cached guide (base 6 + optional fields)
          const cachedSectionCount = 6 +
            (cachedGuide.interpretationInsights ? 1 : 0) +
            (cachedGuide.summaryInsights ? 1 : 0) +
            (cachedGuide.reflectionAnswers ? 1 : 0) +
            (cachedGuide.contextQuestion ? 1 : 0) +
            (cachedGuide.summaryQuestion ? 1 : 0) +
            (cachedGuide.relatedVersesQuestion ? 1 : 0) +
            (cachedGuide.reflectionQuestion ? 1 : 0) +
            (cachedGuide.prayerQuestion ? 1 : 0)

          console.log('📊 [STUDY-V2] Cached section count:', cachedSectionCount)

          // Emit init event for cache hit
          emit(createInitEvent('cache_hit', cachedSectionCount))

          for await (const event of streamCachedContent(cachedGuide)) {
            emit(event)
          }

          // Emit complete event
          emit(createCompleteEvent(
            existingContent.id,
            isCreator || tokenService.isUnlimitedPlan(userPlan) ? 0 : tokenCost,
            true
          ))

          await analyticsLogger.logEvent('study_guide_stream_cache_hit', {
            input_type,
            language: targetLanguage,
            user_type: userContext.type,
            user_plan: userPlan,
            is_creator: isCreator,
            study_guide_id: existingContent.id,
            study_mode
          }, req.headers.get('x-forwarded-for'))

          controller.close()
          return
        }

        // --- NEW GENERATION: Consume tokens BEFORE streaming ---

        let consumptionResult
        if (tokenService.isUnlimitedPlan(userPlan)) {
          consumptionResult = {
            success: true,
            availableTokens: 999999,
            purchasedTokens: 0,
            dailyLimit: 999999,
            totalTokens: 999999,
            errorMessage: undefined
          }
        } else {
          consumptionResult = await tokenService.consumeTokens(
            identifier,
            userPlan,
            tokenCost,
            {
              userId: userContext.userId,
              sessionId: userContext.sessionId,
              userPlan: userPlan,
              operation: 'consume',
              language: targetLanguage,
              ipAddress: req.headers.get('x-forwarded-for') || undefined,
              timestamp: new Date()
            }
          )

          if (!consumptionResult.success) {
            emitError('TOKEN_LIMIT_EXCEEDED', consumptionResult.errorMessage || 'Insufficient tokens', false)
            return
          }
        }

        console.log('🪙 [STUDY-V2] Tokens consumed, starting generation')

        // Initialize streaming JSON parser
        const parser = new StreamingJsonParser()

        // Emit init event with expected total sections
        emit(createInitEvent('started', parser.getTotalSections()))

        // Stream from LLM with retry on content filter
        let forceProvider: 'openai' | 'anthropic' | undefined = undefined
        let retryAttempted = false

        while (true) {
          try {
            const llmStream = llmService.streamStudyGuide({
              inputType: input_type,
              inputValue: input_value,
              topicDescription: topic_description,
              language: targetLanguage,
              tier: userPlan,
              studyMode: study_mode,
              forceProvider
            })

            for await (const chunk of llmStream) {
              const newSections = parser.addChunk(chunk)

              // Emit any newly complete sections
              for (const section of newSections) {
                console.log(`📤 [STUDY-V2] Emitting section: ${section.type}`)
                emit(createSectionEvent(section, parser.getTotalSections()))
              }
            }
            break // Success - exit retry loop
          } catch (streamError) {
            const errorMsg = streamError instanceof Error ? streamError.message : String(streamError)
            const isContentFilter = errorMsg.includes('CONTENT_FILTER')

            if (isContentFilter && !retryAttempted) {
              console.log('[STUDY-V2] 🔄 Content filter detected, resetting parser and retrying with Anthropic')
              parser.reset()
              forceProvider = 'anthropic'  // Force Anthropic on retry
              retryAttempted = true
              // Loop will retry with fallback provider
            } else {
              throw streamError // Re-throw non-content-filter errors or if already retried
            }
          }
        }

        // Check if all sections were parsed
        let studyGuideData: CompleteStudyGuide

        if (parser.isComplete()) {
          studyGuideData = parser.getCompleteStudyGuide()
        } else {
          // Try to parse the complete buffer as fallback
          const fallbackData = await parser.tryParseComplete()
          if (fallbackData) {
            studyGuideData = fallbackData

            // Emit any sections that weren't emitted during streaming
            const emittedCount = parser.getSectionsEmitted()
            const allSections: ParsedSection[] = [
              { type: 'summary', content: studyGuideData.summary, index: 0 },
              { type: 'interpretation', content: studyGuideData.interpretation, index: 1 },
              { type: 'context', content: studyGuideData.context, index: 2 },
              { type: 'relatedVerses', content: studyGuideData.relatedVerses, index: 3 },
              { type: 'reflectionQuestions', content: studyGuideData.reflectionQuestions, index: 4 },
              { type: 'prayerPoints', content: studyGuideData.prayerPoints, index: 5 }
            ]

            // Add optional sections if present (in SECTION_ORDER)
            let currentIndex = 6

            if (studyGuideData.interpretationInsights) {
              allSections.push({ type: 'interpretationInsights', content: studyGuideData.interpretationInsights, index: currentIndex++ })
            }
            if (studyGuideData.summaryInsights) {
              allSections.push({ type: 'summaryInsights', content: studyGuideData.summaryInsights, index: currentIndex++ })
            }
            if (studyGuideData.reflectionAnswers) {
              allSections.push({ type: 'reflectionAnswers', content: studyGuideData.reflectionAnswers, index: currentIndex++ })
            }
            if (studyGuideData.contextQuestion) {
              allSections.push({ type: 'contextQuestion', content: studyGuideData.contextQuestion, index: currentIndex++ })
            }
            if (studyGuideData.summaryQuestion) {
              allSections.push({ type: 'summaryQuestion', content: studyGuideData.summaryQuestion, index: currentIndex++ })
            }
            if (studyGuideData.relatedVersesQuestion) {
              allSections.push({ type: 'relatedVersesQuestion', content: studyGuideData.relatedVersesQuestion, index: currentIndex++ })
            }
            if (studyGuideData.reflectionQuestion) {
              allSections.push({ type: 'reflectionQuestion', content: studyGuideData.reflectionQuestion, index: currentIndex++ })
            }
            if (studyGuideData.prayerQuestion) {
              allSections.push({ type: 'prayerQuestion', content: studyGuideData.prayerQuestion, index: currentIndex++ })
            }

            const totalSections = allSections.length

            for (let i = emittedCount; i < allSections.length; i++) {
              emit(createSectionEvent(allSections[i], totalSections))
            }
          } else {
            console.error('❌ [STUDY-V2] Failed to parse complete study guide')
            emitError('LM-E-002', 'Failed to parse study guide response', true)
            return
          }
        }

        // Save to database (convert CompleteStudyGuide to StudyGuideContent with fallbacks)
        const savedGuide = await studyGuideRepository.saveStudyGuide(
          studyGuideInput,
          {
            summary: studyGuideData.summary,
            interpretation: studyGuideData.interpretation,
            context: studyGuideData.context,
            relatedVerses: studyGuideData.relatedVerses,
            reflectionQuestions: studyGuideData.reflectionQuestions,
            prayerPoints: studyGuideData.prayerPoints,
            interpretationInsights: studyGuideData.interpretationInsights || [],
            summaryInsights: studyGuideData.summaryInsights || [],
            reflectionAnswers: studyGuideData.reflectionAnswers || [],
            contextQuestion: studyGuideData.contextQuestion || '',
            summaryQuestion: studyGuideData.summaryQuestion || '',
            relatedVersesQuestion: studyGuideData.relatedVersesQuestion || '',
            reflectionQuestion: studyGuideData.reflectionQuestion || '',
            prayerQuestion: studyGuideData.prayerQuestion || ''
          },
          userContext
        )

        console.log('💾 [STUDY-V2] Study guide saved:', savedGuide.id)

        // Emit complete event
        emit(createCompleteEvent(
          savedGuide.id,
          tokenService.isUnlimitedPlan(userPlan) ? 0 : tokenCost,
          false
        ))

        // Log analytics
        await analyticsLogger.logEvent('study_guide_stream_generated', {
          input_type,
          language: targetLanguage,
          user_type: userContext.type,
          user_plan: userPlan,
          tokens_consumed: tokenCost,
          study_guide_id: savedGuide.id,
          study_mode
        }, req.headers.get('x-forwarded-for'))

        controller.close()

      } catch (error) {
        console.error('❌ [STUDY-V2] Stream error:', error)

        const errorMessage = error instanceof Error ? error.message : 'Unknown error'
        const isRetryable = !(error instanceof AppError && error.statusCode >= 400 && error.statusCode < 500)

        emitError(
          error instanceof AppError ? error.code : 'LM-E-001',
          errorMessage,
          isRetryable
        )
      }
    }
  })

  return new Response(stream, {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive'
    }
  })
}

// Use simple function factory (bypasses Kong for EventSource compatibility)
createSimpleFunction(handleStudyGenerateV2, {
  allowedMethods: ['GET', 'OPTIONS']
})
