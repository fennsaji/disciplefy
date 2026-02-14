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
import { config } from '../_shared/core/config.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { StudyGuideInput } from '../_shared/types/index.ts'
import { SupportedLanguage } from '../_shared/types/token-types.ts'
import { UserContext } from '../_shared/types/index.ts'
import type { StudyMode, LLMUsageMetadata } from '../_shared/services/llm-types.ts'
import { CostTrackingContext } from '../_shared/services/llm-types.ts'
import { getCorsHeaders } from '../_shared/utils/cors.ts'
import { getUsageLoggingService } from '../_shared/services/usage-logging-service.ts'
import { isFeatureEnabledForPlan } from '../_shared/services/feature-flag-service.ts'
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
 * Type definitions for multi-pass generation data
 */
interface SermonPass1Data {
  summary: string
  context: string
  passage: string  // LLM-generated Scripture passage
  interpretationPart1: string
}

interface SermonPass2Data {
  interpretationPart2: string
}

interface SermonPass3Data {
  interpretationPart3: string
}

interface SermonPass4Data {
  interpretationPart4: string
  altarCall?: string
  relatedVerses: Array<{ reference: string; text: string }>
  reflectionQuestions: string[]
  prayerPoints: string[]
  summaryInsights: string[]
  interpretationInsights: string[]
  reflectionAnswers: string[]
  contextQuestion: string
  summaryQuestion: string
  relatedVersesQuestion: string
  reflectionQuestion: string
  prayerQuestion: string
}

interface StandardPass1Data {
  summary: string
  context: string
  passage: string  // LLM-generated Scripture passage
  interpretationPart1: string
}

interface StandardPass2Data {
  interpretationPart2: string
  relatedVerses: Array<{ reference: string; text: string }>
  reflectionQuestions: string[]
  prayerPoints: string[]
}

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
  const validModes: StudyMode[] = ['quick', 'standard', 'deep', 'lectio', 'sermon']
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
    { type: 'context', content: studyGuide.context, index: 1 },
    { type: 'interpretation', content: studyGuide.interpretation, index: 2 },
    { type: 'relatedVerses', content: studyGuide.relatedVerses, index: 3 },
    { type: 'reflectionQuestions', content: studyGuide.reflectionQuestions, index: 4 },
    { type: 'prayerPoints', content: studyGuide.prayerPoints, index: 5 }
  ]

  // Add optional sections if present (in SECTION_ORDER)
  let currentIndex = 6

  // Add passage if present (matches new content logic at line 1102-1104)
  if (studyGuide.passage) {
    sections.push({ type: 'passage', content: studyGuide.passage, index: currentIndex++ })
  }

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
 * Stream a multi-pass generation pass and parse the complete JSON.
 * Emits sections progressively as they're parsed (except interpretation parts which are combined later).
 *
 * @param llmStream - Streaming LLM response
 * @param passName - Name of this pass for logging (e.g., "Pass 1/3")
 * @param emit - Function to emit SSE events
 * @param totalSections - Total sections for progress tracking
 * @param emitImmediately - Array of field names to emit immediately (e.g., ['summary', 'context'])
 * @returns Parsed JSON data from this pass
 */
async function streamAndParsePass(
  llmStream: AsyncGenerator<string, LLMUsageMetadata, unknown>,
  passName: string,
  emit: (data: string) => void,
  totalSections: number,
  emitImmediately: string[] = []
): Promise<{ data: Record<string, unknown>, usage: LLMUsageMetadata }> {
  const parser = new StreamingJsonParser()
  let accumulatedChunks = ''
  let lastKeepaliveTime = Date.now()
  const KEEPALIVE_INTERVAL = 15000 // Send keepalive every 15 seconds

  console.log(`[LLM-MultiPass] 📥 Streaming ${passName}...`)

  // Manually iterate to capture return value
  let usage: LLMUsageMetadata | undefined
  while (true) {
    const result = await llmStream.next()
    if (result.done) {
      usage = result.value
      break
    }

    const chunk = result.value
    accumulatedChunks += chunk
    const newSections = parser.addChunk(chunk)

    // Send keepalive ping to prevent timeout during long generation
    const now = Date.now()
    if (now - lastKeepaliveTime > KEEPALIVE_INTERVAL) {
      emit(': keepalive\n\n') // SSE comment format - won't trigger frontend events
      console.log(`[LLM-MultiPass] 💓 Keepalive sent during ${passName}`)
      lastKeepaliveTime = now
    }

    // Emit sections that don't need combining (summary, context, etc.)
    for (const section of newSections) {
      if (emitImmediately.includes(section.type)) {
        console.log(`[LLM-MultiPass] 📤 Emitting ${section.type} from ${passName}`)
        emit(createSectionEvent(section, totalSections))
      }
    }
  }
  console.log(`[LLM-MultiPass] ✅ ${passName} streamed: ${accumulatedChunks.length} chars, ${usage!.totalTokens} tokens, $${usage!.costUsd.toFixed(4)}`)

  // Parse complete response
  const { cleanJSONResponse } = await import('../_shared/services/llm-utils/response-parser.ts')
  const data = JSON.parse(cleanJSONResponse(accumulatedChunks))

  return { data, usage: usage! }
}

/**
 * Stream and parse Pass 2 with progressive section emission
 * Emits sections as they're parsed during streaming
 */
async function streamAndParsePass2WithEmission(
  llmStream: AsyncGenerator<string, LLMUsageMetadata, unknown>,
  passName: string,
  emit: (data: string) => void,
  totalSections: number,
  pass1Data: any,
  combinePasses: any
): Promise<{ data: Record<string, unknown>, usage: LLMUsageMetadata }> {
  const parser = new StreamingJsonParser()
  let accumulatedChunks = ''
  const emittedSections = new Set<string>()
  let lastKeepaliveTime = Date.now()
  const KEEPALIVE_INTERVAL = 15000 // Send keepalive every 15 seconds

  console.log(`[LLM-MultiPass] 📥 Streaming ${passName} with progressive emission...`)

  // Manually iterate to capture return value
  let usage: LLMUsageMetadata | undefined
  while (true) {
    const result = await llmStream.next()
    if (result.done) {
      usage = result.value
      break
    }

    const chunk = result.value
    accumulatedChunks += chunk
    const newSections = parser.addChunk(chunk)

    // Send keepalive ping to prevent timeout during long generation
    const now = Date.now()
    if (now - lastKeepaliveTime > KEEPALIVE_INTERVAL) {
      emit(': keepalive\n\n') // SSE comment format - won't trigger frontend events
      console.log(`[LLM-MultiPass] 💓 Keepalive sent during ${passName}`)
      lastKeepaliveTime = now
    }

    // Emit sections progressively as they're parsed
    for (const section of newSections) {
      const sectionType = section.type as string // Cast to string to handle intermediate field names
      console.log(`[LLM-MultiPass] 🔍 Parsed section type: "${sectionType}" in ${passName}`)

      if (emittedSections.has(sectionType)) {
        console.log(`[LLM-MultiPass] ⏭️ Skipping already emitted: ${sectionType}`)
        continue
      }

      if (sectionType === 'interpretationPart2') {
        // Combine with Part 1 and emit interpretation immediately
        console.log(`[LLM-MultiPass] 🔄 Combining interpretationPart1 (${pass1Data.interpretationPart1?.length || 0} chars) + interpretationPart2 (${section.content?.length || 0} chars)`)

        const combined = combinePasses(
          { interpretationPart1: pass1Data.interpretationPart1 } as Record<string, unknown>,
          { interpretationPart2: section.content } as Record<string, unknown>
        )

        console.log(`[LLM-MultiPass] ✅ Combined interpretation length: ${combined.interpretation?.length || 0} chars`)
        console.log(`[LLM-MultiPass] 📤 Emitting interpretation (combined) from ${passName}`)
        emit(createSectionEvent({ type: 'interpretation', content: combined.interpretation as string, index: 2 }, totalSections))
        emittedSections.add('interpretationPart2')
      } else if (sectionType === 'relatedVerses') {
        console.log(`[LLM-MultiPass] 📤 Emitting relatedVerses from ${passName}`)
        emit(createSectionEvent({ type: 'relatedVerses', content: section.content, index: 3 }, totalSections))
        emittedSections.add('relatedVerses')
      } else if (sectionType === 'reflectionQuestions') {
        console.log(`[LLM-MultiPass] 📤 Emitting reflectionQuestions from ${passName}`)
        emit(createSectionEvent({ type: 'reflectionQuestions', content: section.content, index: 4 }, totalSections))
        emittedSections.add('reflectionQuestions')
      } else if (sectionType === 'prayerPoints') {
        console.log(`[LLM-MultiPass] 📤 Emitting prayerPoints from ${passName}`)
        emit(createSectionEvent({ type: 'prayerPoints', content: section.content, index: 5 }, totalSections))
        emittedSections.add('prayerPoints')
      } else if (sectionType === 'summaryInsights') {
        console.log(`[LLM-MultiPass] 📤 Emitting summaryInsights from ${passName}`)
        emit(createSectionEvent({ type: 'summaryInsights', content: section.content, index: 6 }, totalSections))
        emittedSections.add('summaryInsights')
      } else if (sectionType === 'interpretationInsights') {
        console.log(`[LLM-MultiPass] 📤 Emitting interpretationInsights from ${passName}`)
        emit(createSectionEvent({ type: 'interpretationInsights', content: section.content, index: 7 }, totalSections))
        emittedSections.add('interpretationInsights')
      } else if (sectionType === 'reflectionAnswers') {
        console.log(`[LLM-MultiPass] 📤 Emitting reflectionAnswers from ${passName}`)
        emit(createSectionEvent({ type: 'reflectionAnswers', content: section.content, index: 8 }, totalSections))
        emittedSections.add('reflectionAnswers')
      } else if (sectionType === 'contextQuestion') {
        console.log(`[LLM-MultiPass] 📤 Emitting contextQuestion from ${passName}`)
        emit(createSectionEvent({ type: 'contextQuestion', content: section.content, index: 9 }, totalSections))
        emittedSections.add('contextQuestion')
      } else if (sectionType === 'summaryQuestion') {
        console.log(`[LLM-MultiPass] 📤 Emitting summaryQuestion from ${passName}`)
        emit(createSectionEvent({ type: 'summaryQuestion', content: section.content, index: 10 }, totalSections))
        emittedSections.add('summaryQuestion')
      } else if (sectionType === 'relatedVersesQuestion') {
        console.log(`[LLM-MultiPass] 📤 Emitting relatedVersesQuestion from ${passName}`)
        emit(createSectionEvent({ type: 'relatedVersesQuestion', content: section.content, index: 11 }, totalSections))
        emittedSections.add('relatedVersesQuestion')
      } else if (sectionType === 'reflectionQuestion') {
        console.log(`[LLM-MultiPass] 📤 Emitting reflectionQuestion from ${passName}`)
        emit(createSectionEvent({ type: 'reflectionQuestion', content: section.content, index: 12 }, totalSections))
        emittedSections.add('reflectionQuestion')
      } else if (sectionType === 'prayerQuestion') {
        console.log(`[LLM-MultiPass] 📤 Emitting prayerQuestion from ${passName}`)
        emit(createSectionEvent({ type: 'prayerQuestion', content: section.content, index: 13 }, totalSections))
        emittedSections.add('prayerQuestion')
      } else {
        console.log(`[LLM-MultiPass] ⚠️ Unhandled section type in ${passName}: "${sectionType}" - not emitting`)
      }
    }
  }

  console.log(`[LLM-MultiPass] ✅ ${passName} streamed with ${emittedSections.size} sections emitted during streaming, ${usage!.totalTokens} tokens, $${usage!.costUsd.toFixed(4)}`)
  console.log(`[LLM-MultiPass] 📋 Sections found: ${Array.from(emittedSections).join(', ')}`)

  // Parse complete response
  const { cleanJSONResponse } = await import('../_shared/services/llm-utils/response-parser.ts')
  const data = JSON.parse(cleanJSONResponse(accumulatedChunks))

  return { data, usage: usage! }
}

/**
 * Stream and parse Sermon Pass 4 with progressive section emission
 * Emits sections as they're parsed during streaming
 */
async function streamAndParseSermonPass4WithEmission(
  llmStream: AsyncGenerator<string, LLMUsageMetadata, unknown>,
  passName: string,
  emit: (data: string) => void,
  totalSections: number,
  pass1Data: any,
  pass2Data: any,
  pass3Data: any,
  combineSermonPasses: any
): Promise<{ data: Record<string, unknown>, usage: LLMUsageMetadata }> {
  const parser = new StreamingJsonParser()
  let accumulatedChunks = ''
  const emittedSections = new Set<string>()
  let lastKeepaliveTime = Date.now()
  const KEEPALIVE_INTERVAL = 15000 // Send keepalive every 15 seconds

  console.log(`[LLM-MultiPass] 📥 Streaming ${passName} with progressive emission...`)

  // Manually iterate to capture return value
  let usage: LLMUsageMetadata | undefined
  while (true) {
    const result = await llmStream.next()
    if (result.done) {
      usage = result.value
      break
    }

    const chunk = result.value
    accumulatedChunks += chunk
    const newSections = parser.addChunk(chunk)

    // Send keepalive ping to prevent timeout during long generation
    const now = Date.now()
    if (now - lastKeepaliveTime > KEEPALIVE_INTERVAL) {
      emit(': keepalive\n\n') // SSE comment format - won't trigger frontend events
      console.log(`[LLM-MultiPass] 💓 Keepalive sent during ${passName}`)
      lastKeepaliveTime = now
    }

    // Emit sections progressively as they're parsed
    for (const section of newSections) {
      const sectionType = section.type as string // Cast to string to handle intermediate field names
      console.log(`[LLM-MultiPass] 🔍 Parsed section type: "${sectionType}" in ${passName}`)

      if (emittedSections.has(sectionType)) {
        console.log(`[LLM-MultiPass] ⏭️ Skipping already emitted: ${sectionType}`)
        continue
      }

      if (sectionType === 'interpretationPart4') {
        // Combine all 4 parts and emit interpretation immediately
        console.log(`[LLM-MultiPass] 🔄 Combining interpretationPart1 (${pass1Data.interpretationPart1?.length || 0} chars) + Part2 (${pass2Data.interpretationPart2?.length || 0} chars) + Part3 (${pass3Data.interpretationPart3?.length || 0} chars) + Part4 (${section.content?.length || 0} chars)`)

        const combined = combineSermonPasses(
          { interpretationPart1: pass1Data.interpretationPart1 } as Record<string, unknown>,
          { interpretationPart2: pass2Data.interpretationPart2 } as Record<string, unknown>,
          { interpretationPart3: pass3Data.interpretationPart3 } as Record<string, unknown>,
          { interpretationPart4: section.content } as Record<string, unknown>
        )

        console.log(`[LLM-MultiPass] ✅ Combined interpretation length: ${combined.interpretation?.length || 0} chars`)
        console.log(`[LLM-MultiPass] 📤 Emitting interpretation (4 parts combined) from ${passName}`)
        emit(createSectionEvent({ type: 'interpretation', content: combined.interpretation as string, index: 2 }, totalSections))
        emittedSections.add('interpretationPart4')
      } else if (sectionType === 'relatedVerses') {
        console.log(`[LLM-MultiPass] 📤 Emitting relatedVerses from ${passName}`)
        emit(createSectionEvent({ type: 'relatedVerses', content: section.content, index: 3 }, totalSections))
        emittedSections.add('relatedVerses')
      } else if (sectionType === 'reflectionQuestions') {
        console.log(`[LLM-MultiPass] 📤 Emitting reflectionQuestions from ${passName}`)
        emit(createSectionEvent({ type: 'reflectionQuestions', content: section.content, index: 4 }, totalSections))
        emittedSections.add('reflectionQuestions')
      } else if (sectionType === 'prayerPoints') {
        console.log(`[LLM-MultiPass] 📤 Emitting prayerPoints from ${passName}`)
        emit(createSectionEvent({ type: 'prayerPoints', content: section.content, index: 5 }, totalSections))
        emittedSections.add('prayerPoints')
      } else if (sectionType === 'altarCall') {
        // Note: altarCall is not emitted here - it's part of the interpretation for Sermon mode
        console.log(`[LLM-MultiPass] 📝 Found altarCall (not emitting separately - part of interpretation)`)
        emittedSections.add('altarCall')
      } else {
        console.log(`[LLM-MultiPass] ⚠️ Unhandled section type in ${passName}: "${sectionType}" - not emitting`)
      }
    }
  }

  console.log(`[LLM-MultiPass] ✅ ${passName} streamed with ${emittedSections.size} sections emitted during streaming, ${usage!.totalTokens} tokens, $${usage!.costUsd.toFixed(4)}`)
  console.log(`[LLM-MultiPass] 📋 Sections found: ${Array.from(emittedSections).join(', ')}`)

  // Parse complete response
  const { cleanJSONResponse } = await import('../_shared/services/llm-utils/response-parser.ts')
  const data = JSON.parse(cleanJSONResponse(accumulatedChunks))

  return { data, usage: usage! }
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

  // Get user plan for feature flag validation
  const userPlan = await authService.getUserPlan(authReq)
  console.log(`👤 [STUDY-V2] User plan: ${userPlan}`)

  // Feature flag validation - Check if user's plan has access to requested study mode
  const modeFeatureMap: Record<StudyMode, string> = {
    'quick': 'quick_read_mode',
    'standard': 'standard_study_mode',
    'deep': 'deep_dive_mode',
    'lectio': 'lectio_divina_mode',
    'sermon': 'sermon_outline_mode'
  }

  const requiredFeature = modeFeatureMap[study_mode]
  const hasFeatureAccess = await isFeatureEnabledForPlan(requiredFeature, userPlan)

  if (!hasFeatureAccess) {
    console.warn(`⛔ [STUDY-V2] Feature access denied: ${requiredFeature} not available for plan ${userPlan}`)
    return new Response(
      JSON.stringify({
        error: 'FEATURE_NOT_AVAILABLE',
        message: `The ${study_mode} study mode is not available for your current plan (${userPlan}). Please upgrade to access this feature.`,
        requiredFeature: requiredFeature,
        currentPlan: userPlan
      }),
      { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  console.log(`✅ [STUDY-V2] Feature access granted: ${requiredFeature} available for plan ${userPlan}`)

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

  // Calculate token cost (with mode-based multiplier) - userPlan already fetched above for feature flag check
  const targetLanguage = (language || 'en') as SupportedLanguage
  const tokenCost = tokenService.calculateTokenCost(targetLanguage, study_mode)
  const identifier = userContext.type === 'authenticated' ? userContext.userId! : userContext.sessionId!

  // Declare inProgressId outside the stream for access in both start() and cancel()
  let inProgressId: string | undefined

  // Create SSE response stream
  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder()

      const emit = (data: string) => {
        try {
          controller.enqueue(encoder.encode(data))
        } catch (error) {
          // Client disconnected - stream is closed
          // This is fine - generation continues in background
          // Progressive saves ensure data isn't lost
          console.log('[STUDY-V2] Stream closed, continuing generation in background')
        }
      }

      const emitError = (code: string, message: string, retryable: boolean) => {
        emit(createErrorEvent(code, message, retryable))
        try {
          controller.close()
        } catch (error) {
          // Controller already closed - ignore
        }
      }

      // Emit keepalive immediately to prevent worker creation timeout
      // This establishes the SSE connection before any async operations
      emit(': keepalive\n\n')

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
          console.log('📝 [STUDY-V2] Cached passage from DB:', existingContent.content.passage ? `"${existingContent.content.passage.substring(0, 50)}..."` : 'NULL/UNDEFINED')

          // Stream cached sections (content is nested under 'content' property from repository)
          // Spread readonly arrays to create mutable copies for CompleteStudyGuide type
          const cachedGuide: CompleteStudyGuide = {
            summary: existingContent.content.summary || '',
            interpretation: existingContent.content.interpretation || '',
            context: existingContent.content.context || '',
            passage: existingContent.content.passage || undefined,  // Add passage field
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
            (cachedGuide.passage ? 1 : 0) +  // Add passage to section count
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

          // --- LOG USAGE: Track cache hit (no LLM cost) ---
          if (userContext.userId) {
            try {
              const usageService = getUsageLoggingService(config.supabaseUrl, config.supabaseServiceKey)
              await usageService.logUsage({
                userId: userContext.userId,
                tier: userPlan,
                featureName: 'study_generate',
                operationType: 'read',
                tokensConsumed: isCreator || tokenService.isUnlimitedPlan(userPlan) ? 0 : tokenCost,
                llmProvider: undefined, // No LLM call for cache hit
                llmModel: undefined,
                llmInputTokens: undefined,
                llmOutputTokens: undefined,
                llmCostUsd: 0.0, // Zero LLM cost for cache
                requestMetadata: {
                  cache_hit: true,
                  cached_guide_id: existingContent.id,
                  study_mode: study_mode,
                  language: targetLanguage,
                  input_type: input_type
                },
                responseMetadata: {
                  success: true
                }
              })
              console.log(`💰 [STUDY-V2] Cache hit usage logged: $0.00 LLM cost`)
            } catch (logError) {
              console.error(`⚠️ [STUDY-V2] Failed to log cache hit usage:`, logError)
            }
          }

          controller.close()
          return
        }

        // --- DUPLICATE DETECTION: Check for in-progress generation ---

        // Generate input hash for duplicate detection
        const inputHash = await generateInputHash(
          input_value,
          input_type,
          targetLanguage,
          study_mode,
          securityValidator
        )

        // Check if another client is already generating this exact study
        const inProgressStudy = await studyGuideRepository.findInProgressGeneration(
          input_type,
          inputHash,
          targetLanguage,
          study_mode
        )

        if (inProgressStudy) {
          // Check if the in-progress record is stale (>=5 minutes old with no updates)
          // We use 5 minutes because:
          // - Background generation with progressive saves typically completes in 3-5 minutes
          // - Progressive saves update last_updated_at every 30-60 seconds during active generation
          // - If no updates for 5+ minutes, the worker likely crashed or was killed
          const recordAge = Date.now() - new Date(inProgressStudy.last_updated_at).getTime()
          const MAX_RECORD_AGE = 5 * 60 * 1000 // 5 minutes

          if (recordAge >= MAX_RECORD_AGE) {
            console.log('⚠️ [STUDY-V2] Found stale in-progress record (no updates for 5+ minutes), marking as failed', {
              inProgressId: inProgressStudy.id,
              ageMinutes: Math.floor(recordAge / 60000),
              input: input_value.substring(0, 50)
            })

            // Mark stale record as failed (truly abandoned)
            await studyGuideRepository.markInProgressFailed(
              inProgressStudy.id,
              'TIMEOUT',
              'Generation abandoned - no updates for 5+ minutes'
            )

            // Continue with new generation (don't poll stale record)
          } else {
            console.log('🔄 [STUDY-V2] Duplicate request detected, polling for completion...', {
              inProgressId: inProgressStudy.id,
              input: input_value.substring(0, 50),
              language: targetLanguage,
              mode: study_mode,
              ageSeconds: Math.floor(recordAge / 1000),
              note: 'Background generation may still be in progress'
            })

            // Another client is already generating this study - poll for completion
            // The generation continues in background even if original client disconnected
            await pollForInProgressCompletion(
              inProgressStudy.id,
              controller,
              studyGuideRepository.getSupabaseClient(),
              emit,
              encoder
            )
            return
          }
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
        console.log(`📊 [STUDY-V2] Language: ${targetLanguage}, Mode: ${study_mode}`)

        // --- CREATE IN-PROGRESS RECORD: Track generation for duplicate detection ---

        // Clean up any old failed/completed records to avoid UNIQUE constraint conflicts
        await studyGuideRepository.cleanupOldInProgressRecords(
          input_type,
          inputHash,
          targetLanguage,
          study_mode
        )

        const clientId = crypto.randomUUID()
        inProgressId = crypto.randomUUID()

        const { error: inProgressError } = await studyGuideRepository.createInProgressRecord(
          inProgressId,
          userContext.userId,
          input_type,
          input_value,
          inputHash,
          targetLanguage,
          study_mode,
          clientId
        )

        if (inProgressError) {
          console.error('[STUDY-V2] Failed to create in-progress record:', inProgressError)
          // Continue anyway - this is optimization, not critical path
        } else {
          console.log('📝 [STUDY-V2] Created in-progress tracking record:', inProgressId)
        }

        // Declare studyGuideData before branching so it's accessible after
        // Initialize as undefined, will be assigned in either multi-pass or standard path
        let studyGuideData: CompleteStudyGuide | undefined

        // Check if we should use multi-pass generation
        // Multi-pass helps Hindi/Malayalam achieve better word counts due to token inefficiency
        // Sermon: 4-pass (ALL languages - split to avoid Edge Function timeout)
        // Deep: 2-pass (Hindi + Malayalam)
        // Lectio: 2-pass (Hindi + Malayalam)
        // Standard: 2-pass (Hindi + Malayalam)
        const useMultiPass = (
          (study_mode === 'sermon') ||  // ALWAYS use multi-pass for sermon (4-pass to stay under 200s per pass)
          (study_mode === 'deep' && (targetLanguage === 'hi' || targetLanguage === 'ml')) ||
          (study_mode === 'lectio' && (targetLanguage === 'hi' || targetLanguage === 'ml')) ||
          (study_mode === 'standard' && (targetLanguage === 'hi' || targetLanguage === 'ml'))
        )
        console.log(`🔍 [STUDY-V2] Multi-pass check: mode=${study_mode}, lang=${targetLanguage}, useMultiPass=${useMultiPass}`)

        // Declare streamingUsage variable for all paths
        let streamingUsage: LLMUsageMetadata | null = null

        if (useMultiPass) {
          console.log(`🔄 [STUDY-V2] Using multi-pass generation for ${study_mode} in`, targetLanguage)

          // Emit init event
          const parser = new StreamingJsonParser()
          emit(createInitEvent('started', parser.getTotalSections()))

          try {
            // Import common utilities
            const { getLanguageConfigOrDefault } = await import('../_shared/services/llm-config/language-configs.ts')
            const { cleanJSONResponse } = await import('../_shared/services/llm-utils/response-parser.ts')
            const languageConfig = getLanguageConfigOrDefault(targetLanguage)

            // Branch based on study mode to use appropriate multi-pass strategy
            if (study_mode === 'sermon') {
              // SERMON MODE: 4-pass generation
              const {
                createSermonPass1Prompt,
                createSermonPass2Prompt,
                createSermonPass3Prompt,
                createSermonPass4Prompt,
                combineSermonPasses
              } = await import('../_shared/services/llm-utils/sermon-multipass.ts')

            // Initialize cost tracking context for multi-pass aggregation
            const costContext = new CostTrackingContext()

            // PASS 1: Summary + Context + Passage + Intro + Point 1 (STREAMING)
            console.log(`[LLM-MultiPass] 🔄 Starting Pass 1/4 (Summary + Context + Passage + Intro + Point 1) - STREAMING`)
            const pass1Prompt = createSermonPass1Prompt({
              inputType: input_type,
              inputValue: input_value,
              topicDescription: topic_description,
              language: targetLanguage,
              tier: userPlan,
              studyMode: study_mode
            }, languageConfig)

            const pass1Stream = llmService.streamFromPrompt(pass1Prompt, {
              inputType: input_type,
              inputValue: input_value,
              topicDescription: topic_description,
              language: targetLanguage,
              tier: userPlan,
              studyMode: study_mode
            })
            // Emit summary and context during Pass 1 streaming
            const pass1Result = await streamAndParsePass(
              pass1Stream,
              'Sermon Pass 1/4',
              emit,
              14,
              ['summary', 'context', 'passage']
            )
            const pass1Data = pass1Result.data as unknown as SermonPass1Data
            costContext.addCall(pass1Result.usage)
            console.log(`[LLM-MultiPass] ✅ Pass 1/4 complete (streamed)`)
            console.log(`[LLM-MultiPass] Pass 1 fields:`, Object.keys(pass1Data))
            console.log(`[LLM-MultiPass] Pass 1 interpretationPart1 length:`, pass1Data.interpretationPart1?.length || 0)

            // PROGRESSIVE SAVE: Save Pass 1 sections to in-progress table
            await studyGuideRepository.updateInProgressSections(inProgressId, {
              summary: pass1Data.summary,
              context: pass1Data.context,
              passage: pass1Data.passage,
              interpretationPart1: pass1Data.interpretationPart1
            })

            // PRIORITY: Emit interpretationPart1 as "interpretation" (PARTIAL ~25%, Point 1 only) immediately after Pass 1
            if (pass1Data.interpretationPart1 && pass1Data.interpretationPart1.length > 0) {
              console.log(`[LLM-MultiPass] 📤 Emitting interpretationPart1 as "interpretation" (PARTIAL ~25%, Point 1 only)`)
              emit(createSectionEvent({
                type: 'interpretation',
                content: pass1Data.interpretationPart1,
                index: 2
              }, 14))
            }

            // PASS 2: Interpretation Part 2 (Point 2 ONLY) (STREAMING)
            console.log(`[LLM-MultiPass] 🔄 Starting Pass 2/4 (Point 2 Only) - STREAMING`)
            const pass2Prompt = createSermonPass2Prompt({
              inputType: input_type,
              inputValue: input_value,
              topicDescription: topic_description,
              language: targetLanguage,
              tier: userPlan,
              studyMode: study_mode
            }, languageConfig, pass1Data)

            const pass2Stream = llmService.streamFromPrompt(pass2Prompt, {
              inputType: input_type,
              inputValue: input_value,
              topicDescription: topic_description,
              language: targetLanguage,
              tier: userPlan,
              studyMode: study_mode
            })
            // Don't emit anything during streaming - will emit combined after
            const pass2Result = await streamAndParsePass(
              pass2Stream,
              'Sermon Pass 2/4',
              emit,
              14,
              []
            )
            const pass2Data = pass2Result.data as unknown as SermonPass2Data
            costContext.addCall(pass2Result.usage)
            console.log(`[LLM-MultiPass] ✅ Pass 2/4 complete (streamed)`)
            console.log(`[LLM-MultiPass] Pass 2 fields:`, Object.keys(pass2Data))
            console.log(`[LLM-MultiPass] Pass 2 interpretationPart2 length:`, pass2Data.interpretationPart2?.length || 0)

            // PROGRESSIVE SAVE: Save Pass 2 sections to in-progress table
            await studyGuideRepository.updateInProgressSections(inProgressId, {
              interpretationPart2: pass2Data.interpretationPart2
            })

            // Emit combined interpretation (Part1 + Part2) = ~50% progress
            if (pass2Data.interpretationPart2 && pass2Data.interpretationPart2.length > 0) {
              const combinedInterpretation = `${pass1Data.interpretationPart1}\n\n${pass2Data.interpretationPart2}`
              console.log(`[LLM-MultiPass] 📤 Emitting combined interpretation (Part1 + Part2, ~50% complete)`)
              emit(createSectionEvent({
                type: 'interpretation',
                content: combinedInterpretation,
                index: 2
              }, 14))
            }

            // PASS 3: Interpretation Part 3 (Point 3 ONLY) (STREAMING)
            console.log(`[LLM-MultiPass] 🔄 Starting Pass 3/4 (Point 3 Only) - STREAMING`)
            const pass3Prompt = createSermonPass3Prompt({
              inputType: input_type,
              inputValue: input_value,
              topicDescription: topic_description,
              language: targetLanguage,
              tier: userPlan,
              studyMode: study_mode
            }, languageConfig, pass1Data, pass2Data)

            const pass3Stream = llmService.streamFromPrompt(pass3Prompt, {
              inputType: input_type,
              inputValue: input_value,
              topicDescription: topic_description,
              language: targetLanguage,
              tier: userPlan,
              studyMode: study_mode
            })

            // Don't emit anything during streaming - will emit combined after
            const pass3Result = await streamAndParsePass(
              pass3Stream,
              'Sermon Pass 3/4',
              emit,
              14,
              []
            )
            const pass3Data = pass3Result.data as unknown as SermonPass3Data
            costContext.addCall(pass3Result.usage)
            console.log(`[LLM-MultiPass] ✅ Pass 3/4 complete (streamed)`)
            console.log(`[LLM-MultiPass] Pass 3 fields:`, Object.keys(pass3Data))
            console.log(`[LLM-MultiPass] Pass 3 interpretationPart3 length:`, pass3Data.interpretationPart3?.length || 0)

            // PROGRESSIVE SAVE: Save Pass 3 sections to in-progress table
            await studyGuideRepository.updateInProgressSections(inProgressId, {
              interpretationPart3: pass3Data.interpretationPart3
            })

            // Emit combined interpretation (Part1 + Part2 + Part3) = ~75% progress
            if (pass3Data.interpretationPart3 && pass3Data.interpretationPart3.length > 0) {
              const combinedInterpretation = `${pass1Data.interpretationPart1}\n\n${pass2Data.interpretationPart2}\n\n${pass3Data.interpretationPart3}`
              console.log(`[LLM-MultiPass] 📤 Emitting combined interpretation (Part1 + Part2 + Part3, ~75% complete)`)
              emit(createSectionEvent({
                type: 'interpretation',
                content: combinedInterpretation,
                index: 2
              }, 14))
            }

            // PASS 4: Conclusion + Altar Call + Supporting Fields (STREAMING)
            console.log(`[LLM-MultiPass] 🔄 Starting Pass 4/4 (Conclusion + Altar Call + Extras) - STREAMING`)
            const pass4Prompt = createSermonPass4Prompt({
              inputType: input_type,
              inputValue: input_value,
              topicDescription: topic_description,
              language: targetLanguage,
              tier: userPlan,
              studyMode: study_mode
            }, languageConfig, pass1Data)

            const pass4Stream = llmService.streamFromPrompt(pass4Prompt, {
              inputType: input_type,
              inputValue: input_value,
              topicDescription: topic_description,
              language: targetLanguage,
              tier: userPlan,
              studyMode: study_mode
            })

            // Stream Pass 4 with progressive section emission
            // Sections are emitted AS THEY'RE PARSED during streaming:
            // - interpretationPart4 → combine with Part1 + Part2 + Part3 → emit interpretation (index 2)
            // - relatedVerses → emit immediately (index 3)
            // - reflectionQuestions → emit immediately (index 4)
            // - prayerPoints → emit immediately (index 5)
            const pass4Result = await streamAndParseSermonPass4WithEmission(
              pass4Stream,
              'Sermon Pass 4/4',
              emit,
              14,
              pass1Data,
              pass2Data,
              pass3Data,
              combineSermonPasses
            )
            const pass4Data = pass4Result.data as unknown as SermonPass4Data
            costContext.addCall(pass4Result.usage)

            // Get aggregated usage for all 4 passes
            streamingUsage = costContext.getAggregate()
            console.log(`[LLM-MultiPass] 🎉 All 4 passes complete! Total: ${streamingUsage.totalTokens} tokens, $${streamingUsage.costUsd.toFixed(4)}`)
            console.log(`[LLM-MultiPass] ✅ Pass 4/4 complete (all core sections emitted progressively)`)
            console.log(`[LLM-MultiPass] Pass 4 fields:`, Object.keys(pass4Data))
            console.log(`[LLM-MultiPass] Combined interpretation parts:`, {
              part1Length: pass1Data.interpretationPart1?.length || 0,
              part2Length: pass2Data.interpretationPart2?.length || 0,
              part3Length: pass3Data.interpretationPart3?.length || 0,
              part4Length: pass4Data.interpretationPart4?.length || 0
            })

            // PROGRESSIVE SAVE: Save Pass 4 sections to in-progress table
            await studyGuideRepository.updateInProgressSections(inProgressId, {
              interpretationPart4: pass4Data.interpretationPart4,
              relatedVerses: pass4Data.relatedVerses,
              reflectionQuestions: pass4Data.reflectionQuestions,
              prayerPoints: pass4Data.prayerPoints
            })

            // Combine all passes
            const completeSermon = combineSermonPasses(
              pass1Data as any,
              pass2Data as any,
              pass3Data as any,
              pass4Data as any
            )
            studyGuideData = completeSermon as unknown as CompleteStudyGuide

            // NOTE: Full interpretation (Part1+Part2+Part3+Part4) already emitted during Pass 4 streaming
            // No need for redundant emission here

            // Emit optional sections (6+) immediately
            let currentIndex = 6
            if (studyGuideData.interpretationInsights) {
              emit(createSectionEvent({ type: 'interpretationInsights', content: studyGuideData.interpretationInsights, index: currentIndex++ }, 14))
            }
            if (studyGuideData.summaryInsights) {
              emit(createSectionEvent({ type: 'summaryInsights', content: studyGuideData.summaryInsights, index: currentIndex++ }, 14))
            }
            if (studyGuideData.reflectionAnswers) {
              emit(createSectionEvent({ type: 'reflectionAnswers', content: studyGuideData.reflectionAnswers, index: currentIndex++ }, 14))
            }
            if (studyGuideData.contextQuestion) {
              emit(createSectionEvent({ type: 'contextQuestion', content: studyGuideData.contextQuestion, index: currentIndex++ }, 14))
            }
            if (studyGuideData.summaryQuestion) {
              emit(createSectionEvent({ type: 'summaryQuestion', content: studyGuideData.summaryQuestion, index: currentIndex++ }, 14))
            }
            if (studyGuideData.relatedVersesQuestion) {
              emit(createSectionEvent({ type: 'relatedVersesQuestion', content: studyGuideData.relatedVersesQuestion, index: currentIndex++ }, 14))
            }
            if (studyGuideData.reflectionQuestion) {
              emit(createSectionEvent({ type: 'reflectionQuestion', content: studyGuideData.reflectionQuestion, index: currentIndex++ }, 14))
            }
            if (studyGuideData.prayerQuestion) {
              emit(createSectionEvent({ type: 'prayerQuestion', content: studyGuideData.prayerQuestion, index: currentIndex++ }, 14))
            }

            } else if (study_mode === 'deep' || study_mode === 'lectio' || study_mode === 'standard') {
              // DEEP / LECTIO / STANDARD MODES: 2-pass generation
              const modeName = study_mode.charAt(0).toUpperCase() + study_mode.slice(1)

              // Import appropriate multi-pass utilities based on mode
              let createPass1Prompt, createPass2Prompt, combinePasses
              if (study_mode === 'deep') {
                const deepModule = await import('../_shared/services/llm-utils/deep-multipass.ts')
                createPass1Prompt = deepModule.createDeepPass1Prompt
                createPass2Prompt = deepModule.createDeepPass2Prompt
                combinePasses = deepModule.combineDeepPasses
              } else if (study_mode === 'lectio') {
                const lectioModule = await import('../_shared/services/llm-utils/lectio-multipass.ts')
                createPass1Prompt = lectioModule.createLectioPass1Prompt
                createPass2Prompt = lectioModule.createLectioPass2Prompt
                combinePasses = lectioModule.combineLectioPasses
              } else {  // standard
                const standardModule = await import('../_shared/services/llm-utils/standard-multipass.ts')
                createPass1Prompt = standardModule.createStandardPass1Prompt
                createPass2Prompt = standardModule.createStandardPass2Prompt
                combinePasses = standardModule.combineStandardPasses
              }

              // Initialize cost tracking context for 2-pass aggregation
              const costContext = new CostTrackingContext()

              // PASS 1: Summary + Context + Interpretation Part 1 (STREAMING)
              console.log(`[LLM-MultiPass] 🔄 Starting ${modeName} Pass 1/2 - STREAMING`)
              const pass1Prompt = createPass1Prompt({
                inputType: input_type,
                inputValue: input_value,
                topicDescription: topic_description,
                language: targetLanguage,
                tier: userPlan,
                studyMode: study_mode
              }, languageConfig)

              const pass1Stream = llmService.streamFromPrompt(pass1Prompt, {
                inputType: input_type,
                inputValue: input_value,
                topicDescription: topic_description,
                language: targetLanguage,
                tier: userPlan,
                studyMode: study_mode
              })
              // Emit summary and context during Pass 1 streaming
              const pass1Result = await streamAndParsePass(
                pass1Stream,
                `${modeName} Pass 1/2`,
                emit,
                14,
                ['summary', 'context', 'passage']  // Add passage to emit during Pass 1
              )
              const pass1Data = pass1Result.data as unknown as StandardPass1Data
              costContext.addCall(pass1Result.usage)
              console.log(`[LLM-MultiPass] ✅ ${modeName} Pass 1 complete (streamed)`)
              console.log(`[LLM-MultiPass] Pass 1 fields:`, Object.keys(pass1Data))

              // PROGRESSIVE SAVE: Save Pass 1 sections to in-progress table
              await studyGuideRepository.updateInProgressSections(inProgressId, {
                summary: pass1Data.summary,
                context: pass1Data.context,
                passage: pass1Data.passage,
                interpretationPart1: pass1Data.interpretationPart1
              })

              // PRIORITY: Emit interpretationPart1 as "interpretation" (PARTIAL ~40%) immediately after Pass 1
              if (pass1Data.interpretationPart1 && pass1Data.interpretationPart1.length > 0) {
                console.log(`[LLM-MultiPass] 📤 Emitting interpretationPart1 as "interpretation" (PARTIAL ~40%)`)
                emit(createSectionEvent({
                  type: 'interpretation',
                  content: pass1Data.interpretationPart1,
                  index: 2
                }, 14))
              }

              // PASS 2: Interpretation Part 2 + Supporting Fields (STREAMING)
              console.log(`[LLM-MultiPass] 🔄 Starting ${modeName} Pass 2/2 - STREAMING`)
              const pass2Prompt = createPass2Prompt({
                inputType: input_type,
                inputValue: input_value,
                topicDescription: topic_description,
                language: targetLanguage,
                tier: userPlan,
                studyMode: study_mode
              }, languageConfig, pass1Data)

              const pass2Stream = llmService.streamFromPrompt(pass2Prompt, {
                inputType: input_type,
                inputValue: input_value,
                topicDescription: topic_description,
                language: targetLanguage,
                tier: userPlan,
                studyMode: study_mode
              })

              // Stream Pass 2 with progressive section emission
              const pass2Result = await streamAndParsePass2WithEmission(
                pass2Stream,
                `${modeName} Pass 2/2`,
                emit,
                14,
                pass1Data,
                combinePasses
              )
              const pass2Data = pass2Result.data as unknown as StandardPass2Data
              costContext.addCall(pass2Result.usage)

              // Get aggregated usage for both passes
              streamingUsage = costContext.getAggregate()
              console.log(`[LLM-MultiPass] 🎉 Both passes complete! Total: ${streamingUsage.totalTokens} tokens, $${streamingUsage.costUsd.toFixed(4)}`)
              console.log(`[LLM-MultiPass] ✅ ${modeName} Pass 2 complete`)
              console.log(`[LLM-MultiPass] Pass 2 fields:`, Object.keys(pass2Data))

              // PROGRESSIVE SAVE: Save Pass 2 sections to in-progress table
              await studyGuideRepository.updateInProgressSections(inProgressId, {
                interpretationPart2: pass2Data.interpretationPart2,
                relatedVerses: pass2Data.relatedVerses,
                reflectionQuestions: pass2Data.reflectionQuestions,
                prayerPoints: pass2Data.prayerPoints
              })

              // Combine both passes
              const completeStudy = combinePasses(
                pass1Data as any,
                pass2Data as any
              )
              studyGuideData = completeStudy as unknown as CompleteStudyGuide

              // NOTE: Full interpretation (Part1+Part2) already emitted during Pass 2 streaming
              // NOTE: All insights and questions already emitted during Pass 2 streaming
              // No need for redundant emission here
            }

          } catch (multiPassError) {
            console.error('[STUDY-V2] ❌ Multi-pass generation failed:', multiPassError)
            emit(createErrorEvent('LM-E-003', `Multi-pass ${study_mode} generation failed`, true))
            return
          }
        } else {
          // Use regular streaming generation for all other modes
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

            // Manually iterate to capture return value
            while (true) {
              const result = await llmStream.next()
              if (result.done) {
                streamingUsage = result.value
                break
              }

              const chunk = result.value
              const newSections = parser.addChunk(chunk)

              // Emit any newly complete sections
              for (const section of newSections) {
                console.log(`📤 [STUDY-V2] Emitting section: ${section.type}`)
                emit(createSectionEvent(section, parser.getTotalSections()))

                // Progressive save: Update in-progress record with newly emitted section
                if (inProgressId && section.content) {
                  try {
                    await studyGuideRepository.updateInProgressSections(inProgressId, {
                      [section.type]: section.content
                    })
                    console.log(`💾 [STUDY-V2] Saved ${section.type} to in-progress record`)
                  } catch (saveError) {
                    console.error(`⚠️ [STUDY-V2] Failed to save ${section.type}:`, saveError)
                    // Don't throw - progressive saves are optimization, not critical
                  }
                }
              }
            }

            console.log(`💰 [STUDY-V2] LLM Usage captured: ${streamingUsage?.totalTokens} tokens, $${streamingUsage?.costUsd.toFixed(4)}`)

            break // Success - exit retry loop
          } catch (streamError) {
            const errorMsg = streamError instanceof Error ? streamError.message : String(streamError)
            const isContentFilter = errorMsg.includes('CONTENT_FILTER')

            if (isContentFilter && !retryAttempted) {
              console.log('[STUDY-V2] 🔄 Content filter detected, resetting parser and retrying with Anthropic')
              parser.reset()
              forceProvider = 'anthropic'  // Force Anthropic on retry
              retryAttempted = true
              streamingUsage = null // Reset usage for retry
              // Loop will retry with fallback provider
            } else {
              throw streamError // Re-throw non-content-filter errors or if already retried
            }
          }
        }

          // Check if all sections were parsed (for streaming path)
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
              { type: 'context', content: studyGuideData.context, index: 1 },
              { type: 'interpretation', content: studyGuideData.interpretation, index: 2 },
              { type: 'relatedVerses', content: studyGuideData.relatedVerses, index: 3 },
              { type: 'reflectionQuestions', content: studyGuideData.reflectionQuestions, index: 4 },
              { type: 'prayerPoints', content: studyGuideData.prayerPoints, index: 5 }
            ]

            // Add passage if present (before other optional sections)
            let currentIndex = 6
            if (studyGuideData.passage) {
              allSections.push({ type: 'passage', content: studyGuideData.passage, index: currentIndex++ })
            }

            // Add optional sections if present (in SECTION_ORDER)

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
              const section = allSections[i]
              emit(createSectionEvent(section, totalSections))

              // Progressive save: Update in-progress record with fallback-emitted section
              if (inProgressId && section.content) {
                try {
                  await studyGuideRepository.updateInProgressSections(inProgressId, {
                    [section.type]: section.content
                  })
                  console.log(`💾 [STUDY-V2] Saved ${section.type} to in-progress record (fallback emission)`)
                } catch (saveError) {
                  console.error(`⚠️ [STUDY-V2] Failed to save ${section.type} (fallback):`, saveError)
                  // Don't throw - progressive saves are optimization, not critical
                }
              }
            }
            } else {
              console.error('❌ [STUDY-V2] Failed to parse complete study guide')
              emitError('LM-E-002', 'Failed to parse study guide response', true)
              return
            }
          }
        } // End of else block (streaming path)

        // Type guard: Ensure study guide data was generated before saving
        if (!studyGuideData) {
          console.error('❌ [STUDY-V2] Study guide data was not generated')
          emit(createErrorEvent('LM-E-004', 'Study guide generation failed', true))
          return
        }

        // Save to database (convert CompleteStudyGuide to StudyGuideContent with fallbacks)
        console.log('📝 [STUDY-V2] Passage before save:', studyGuideData.passage ? `"${studyGuideData.passage.substring(0, 50)}..."` : 'NULL/UNDEFINED')

        const savedGuide = await studyGuideRepository.saveStudyGuide(
          studyGuideInput,
          {
            summary: studyGuideData.summary,
            interpretation: studyGuideData.interpretation,
            context: studyGuideData.context,
            passage: studyGuideData.passage || null,
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
        console.log('📝 [STUDY-V2] Passage after save:', savedGuide.content.passage ? `"${savedGuide.content.passage.substring(0, 50)}..."` : 'NULL/UNDEFINED')

        // --- FINALIZE IN-PROGRESS RECORD: Mark as completed ---
        await studyGuideRepository.markInProgressCompleted(inProgressId)
        console.log('✅ [STUDY-V2] Marked in-progress record as completed:', inProgressId)

        // --- LOG USAGE: Track LLM costs and token consumption ---
        if (streamingUsage && userContext.userId) {
          try {
            const usageService = getUsageLoggingService(config.supabaseUrl, config.supabaseServiceKey)
            await usageService.logUsage({
              userId: userContext.userId,
              tier: userPlan,
              featureName: 'study_generate',
              operationType: 'create',
              tokensConsumed: 10, // App tokens
              llmProvider: streamingUsage.provider,
              llmModel: streamingUsage.model,
              llmInputTokens: streamingUsage.inputTokens,
              llmOutputTokens: streamingUsage.outputTokens,
              llmCostUsd: streamingUsage.costUsd,
              requestMetadata: {
                study_mode: study_mode,
                language: targetLanguage,
                input_type: input_type
              },
              responseMetadata: {
                success: true,
                study_guide_id: savedGuide.id
              }
            })
            console.log(`💰 [STUDY-V2] Usage logged: ${streamingUsage.totalTokens} tokens, $${streamingUsage.costUsd.toFixed(4)}`)
          } catch (logError) {
            console.error(`⚠️ [STUDY-V2] Failed to log usage:`, logError)
            // Don't throw - usage logging is important but not critical for user experience
          }
        }

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

        try {
          controller.close()
        } catch (error) {
          // Controller already closed (client disconnected)
          // Generation completed successfully in background
          console.log('✅ [STUDY-V2] Generation completed in background after client disconnect')
        }

      } catch (error) {
        console.error('❌ [STUDY-V2] Stream error:', error)

        const errorMessage = error instanceof Error ? error.message : 'Unknown error'
        const isRetryable = !(error instanceof AppError && error.statusCode >= 400 && error.statusCode < 500)
        const errorCode = error instanceof AppError ? error.code : 'LM-E-001'

        // Mark in-progress record as failed
        if (inProgressId) {
          await studyGuideRepository.markInProgressFailed(
            inProgressId,
            errorCode,
            errorMessage
          )
          console.log('❌ [STUDY-V2] Marked in-progress record as failed:', inProgressId)
        }

        emitError(
          errorCode,
          errorMessage,
          isRetryable
        )
      }
    },

    // Handle stream cancellation (client disconnected, navigated away, etc.)
    async cancel(reason) {
      console.log('🚫 [STUDY-V2] Client disconnected, but generation will continue in background:', {
        inProgressId,
        reason: reason || 'No reason provided'
      })

      // DO NOT mark as failed or stop generation
      // The generation continues in the background and will:
      // 1. Keep writing progressive updates to database
      // 2. Complete and mark record as "completed"
      // 3. Allow future requests to retrieve the completed study
      //
      // This is intentional behavior for background generation feature
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

/**
 * Generate input hash for duplicate detection
 *
 * Creates a consistent SHA-256 hash from study guide input parameters.
 * Includes type, language, mode, and normalized value to prevent collisions.
 */
async function generateInputHash(
  input: string,
  inputType: string,
  language: string,
  studyMode: string,
  securityValidator: any
): Promise<string> {
  // Normalize the value for consistent hashing
  const normalizedValue = input.toLowerCase().trim().replace(/\s+/g, ' ')

  // Include type, language, and study_mode to prevent collisions
  const hashInput = `${inputType}:${language}:${studyMode}:${normalizedValue}`

  return await securityValidator.hashSensitiveData(hashInput)
}

/**
 * Poll for in-progress generation completion
 *
 * When a duplicate request is detected, this function polls the in-progress
 * record and emits progressive sections as they become available.
 */
async function pollForInProgressCompletion(
  inProgressId: string,
  controller: ReadableStreamDefaultController,
  supabase: any,
  emit: (data: string) => void,
  encoder: TextEncoder
): Promise<void> {
  const MAX_POLL_DURATION = 300000 // 5 minutes
  const POLL_INTERVAL = 2000 // 2 seconds
  const startTime = Date.now()
  const emittedSections = new Set<string>()

  console.log('[POLL] Starting to poll for in-progress study:', inProgressId)

  while (Date.now() - startTime < MAX_POLL_DURATION) {
    // Check in-progress status
    const { data: progress, error: progressError } = await supabase
      .from('study_guides_in_progress')
      .select('*')
      .eq('id', inProgressId)
      .single()

    if (progressError) {
      console.log('[POLL] Progress record not found, checking main table')
      break
    }

    // Emit progressive sections to client
    if (progress.sections) {
      for (const [sectionType, content] of Object.entries(progress.sections)) {
        if (content && !emittedSections.has(sectionType)) {
          console.log('[POLL] Emitting section:', sectionType)
          emit(createSectionEvent(
            {
              type: sectionType as any, // Type cast for dynamic section types
              content: content as string,
              index: emittedSections.size
            },
            10 // Total sections is approximate
          ))
          emittedSections.add(sectionType)
        }
      }
    }

    if (progress.status === 'completed') {
      console.log('[POLL] Generation completed, fetching from main table')
      // Generation complete, fetch from main table
      const { data: completedStudy } = await supabase
        .from('study_guides')
        .select('*')
        .eq('input_type', progress.input_type)
        .eq('input_value_hash', progress.input_value_hash)
        .eq('language', progress.language)
        .eq('study_mode', progress.study_mode)
        .single()

      if (completedStudy) {
        // Emit final metadata
        emit(createCompleteEvent(
          completedStudy.id,
          0, // Already consumed by first request
          true // From cache
        ))

        console.log('[POLL] Polling complete, study found in main table')
        controller.close()
        return
      }
    }

    if (progress.status === 'failed') {
      const errorMsg = progress.error_message || 'Generation failed'
      console.error('[POLL] Generation failed:', errorMsg)
      emit(createErrorEvent(
        progress.error_code || 'GENERATION_ERROR',
        errorMsg,
        false
      ))
      controller.close()
      throw new Error(`Generation failed: ${errorMsg}`)
    }

    // Wait before next poll
    await new Promise(resolve => setTimeout(resolve, POLL_INTERVAL))
  }

  // Polling timeout
  console.error('[POLL] Polling timeout after 5 minutes')
  emit(createErrorEvent(
    'POLLING_TIMEOUT',
    'Study generation did not complete in time',
    true
  ))
  controller.close()
  throw new Error('Polling timeout: Study generation did not complete in time')
}

// Use simple function factory (bypasses Kong for EventSource compatibility)
createSimpleFunction(handleStudyGenerateV2, {
  allowedMethods: ['GET', 'OPTIONS']
})
