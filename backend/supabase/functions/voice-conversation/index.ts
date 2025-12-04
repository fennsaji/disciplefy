/**
 * Voice Conversation Edge Function
 *
 * Handles AI Discipler voice conversations with streaming responses.
 * Features:
 * - Server-Sent Events (SSE) for real-time streaming
 * - Multi-language support (English, Hindi, Malayalam)
 * - Conversation context management
 * - Quota enforcement (Free: not available, Standard: 10/month, Premium: unlimited)
 * - Scripture reference integration
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getCorsHeaders } from '../_shared/utils/cors.ts'
import {
  getVoiceSystemPrompt,
  getVoiceExamples,
  getPrimaryTranslation
} from '../_shared/prompts/voice-conversation-prompts.ts'
import { AuthService } from '../_shared/services/auth-service.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')!

// Monthly quota limits by tier
// Free users cannot access voice conversations
// Standard users get 10 per month
// Premium users have unlimited access
const QUOTA_LIMITS: Record<string, number> = {
  free: 0, // Not available for free users
  standard: 10, // 10 per month
  premium: -1, // Unlimited
}

// Maximum messages per conversation to prevent abuse
const MAX_MESSAGES_PER_CONVERSATION = 50

interface VoiceConversationRequest {
  conversation_id: string
  message: string
  language_code?: string
  related_study_guide_id?: string
  related_scripture?: string
}

interface ConversationMessage {
  role: 'user' | 'assistant' | 'system'
  content: string
}

/**
 * Extract authentication from request
 */
function extractAuth(req: Request): { authToken: string | null; apiKey: string | null } {
  const url = new URL(req.url)
  let authToken = url.searchParams.get('authorization')
  let apiKey = url.searchParams.get('apikey')

  if (!authToken) {
    const authHeader = req.headers.get('authorization')
    if (authHeader?.startsWith('Bearer ')) {
      authToken = authHeader.substring(7)
    }
  }

  if (!apiKey) {
    apiKey = req.headers.get('apikey')
  }

  // If no apiKey provided, use the anon key from environment
  // This is safe because we still validate the user token
  if (!apiKey) {
    apiKey = SUPABASE_ANON_KEY
  }

  return { authToken, apiKey }
}



/**
 * Check and update user's voice quota (monthly)
 */
async function checkAndUpdateQuota(
  supabase: any,
  userId: string,
  tier: string
): Promise<{ canProceed: boolean; remaining: number; limit: number }> {
  const limit = QUOTA_LIMITS[tier]

  // Premium users have unlimited quota
  if (limit === -1) {
    return { canProceed: true, remaining: -1, limit: -1 }
  }

  // Free users cannot access
  if (limit === 0) {
    return { canProceed: false, remaining: 0, limit: 0 }
  }

  // Check this month's usage
  const now = new Date()
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0]
  const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().split('T')[0]

  const { data: usage } = await supabase
    .from('voice_usage_tracking')
    .select('daily_quota_used')
    .eq('user_id', userId)
    .gte('usage_date', monthStart)
    .lte('usage_date', monthEnd)

  // Sum up all daily usage for the month
  const currentUsage = usage?.reduce((sum: number, row: any) => sum + (row.daily_quota_used || 0), 0) || 0
  const remaining = limit - currentUsage

  if (remaining <= 0) {
    return { canProceed: false, remaining: 0, limit }
  }

  return { canProceed: true, remaining, limit }
}

/**
 * Check if conversation has exceeded message limit
 */
async function checkConversationMessageLimit(
  supabase: any,
  conversationId: string
): Promise<{ canProceed: boolean; messageCount: number }> {
  const { count } = await supabase
    .from('voice_conversation_messages')
    .select('*', { count: 'exact', head: true })
    .eq('conversation_id', conversationId)

  const messageCount = count || 0

  if (messageCount >= MAX_MESSAGES_PER_CONVERSATION) {
    return { canProceed: false, messageCount }
  }

  return { canProceed: true, messageCount }
}

/**
 * Get conversation history for context
 */
async function getConversationHistory(
  supabase: any,
  conversationId: string
): Promise<ConversationMessage[]> {
  const { data: messages } = await supabase
    .from('voice_conversation_messages')
    .select('role, content_text')
    .eq('conversation_id', conversationId)
    .order('message_order', { ascending: true })
    .limit(10) // Keep last 10 messages for context

  if (!messages) return []

  return messages.map((msg: any) => ({
    role: msg.role as 'user' | 'assistant',
    content: msg.content_text
  }))
}

/**
 * Get study context if related to a study guide
 */
async function getStudyContext(
  supabase: any,
  studyGuideId: string | null
): Promise<string | null> {
  if (!studyGuideId) return null

  const { data: guide } = await supabase
    .from('study_guides')
    .select('input_value, input_type, summary, context, interpretation')
    .eq('id', studyGuideId)
    .single()

  if (!guide) return null

  let context = `The user is studying: ${guide.input_value} (${guide.input_type})\n`
  if (guide.summary) context += `Summary: ${guide.summary}\n`
  if (guide.context) context += `Context: ${guide.context}\n`
  if (guide.interpretation) context += `Interpretation: ${guide.interpretation}`

  return context
}

/**
 * Get user profile for context
 */
async function getUserContext(
  supabase: any,
  userId: string
): Promise<{ maturityLevel: string; recentTopics: string[] }> {
  const { data: profile } = await supabase
    .from('user_profiles')
    .select('spiritual_maturity, favorite_topics')
    .eq('user_id', userId)
    .single()

  return {
    maturityLevel: profile?.spiritual_maturity || 'intermediate',
    recentTopics: profile?.favorite_topics || []
  }
}



/**
 * Stream LLM response using OpenAI
 */
async function* streamLLMResponse(
  messages: ConversationMessage[],
  languageCode: string
): AsyncGenerator<string> {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages: messages.map(m => ({ role: m.role, content: m.content })),
      stream: true,
      max_tokens: 500,
      temperature: 0.7,
    }),
  })

  if (!response.ok) {
    const error = await response.text()
    console.error('❌ [VOICE] OpenAI API error:', error)
    throw new Error(`OpenAI API error: ${response.status}`)
  }

  const reader = response.body?.getReader()
  if (!reader) throw new Error('No response body')

  const decoder = new TextDecoder()
  let buffer = ''

  while (true) {
    const { done, value } = await reader.read()
    if (done) break

    buffer += decoder.decode(value, { stream: true })
    const lines = buffer.split('\n')
    buffer = lines.pop() || ''

    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = line.slice(6)
        if (data === '[DONE]') return

        try {
          const parsed = JSON.parse(data)
          const content = parsed.choices?.[0]?.delta?.content
          if (content) yield content
        } catch {
          // Skip invalid JSON
        }
      }
    }
  }
}

/**
 * Save message to database
 */
async function saveMessage(
  supabase: any,
  conversationId: string,
  userId: string,
  role: string,
  content: string,
  language: string,
  metadata?: {
    llmModelUsed?: string
    llmTokensUsed?: number
    scriptureReferences?: string[]
  }
): Promise<void> {
  // Get current message count
  const { count } = await supabase
    .from('voice_conversation_messages')
    .select('*', { count: 'exact', head: true })
    .eq('conversation_id', conversationId)

  await supabase
    .from('voice_conversation_messages')
    .insert({
      conversation_id: conversationId,
      user_id: userId,
      message_order: count || 0,
      role,
      content_text: content,
      content_language: language,
      llm_model_used: metadata?.llmModelUsed,
      llm_tokens_used: metadata?.llmTokensUsed,
      scripture_references: metadata?.scriptureReferences,
    })

  // Update conversation stats
  await supabase
    .from('voice_conversations')
    .update({
      total_messages: (count || 0) + 1,
      updated_at: new Date().toISOString(),
    })
    .eq('id', conversationId)
}

/**
 * Extract scripture references from text
 */
function extractScriptureReferences(text: string): string[] {
  const pattern = /(?:\d\s)?[A-Za-z]+\s+\d+(?::\d+(?:-\d+)?)?/g
  const matches = text.match(pattern) || []
  return [...new Set(matches)]
}

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: getCorsHeaders(req.headers.get('origin')) })
  }

  const encoder = new TextEncoder()
  const stream = new TransformStream()
  const writer = stream.writable.getWriter()

  const sendEvent = async (event: string, data: any) => {
    await writer.write(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`))
  }

  // Start streaming response
  const responsePromise = (async () => {
    try {
      // Extract auth
      const { authToken, apiKey } = extractAuth(req)

      console.log('🔐 [VOICE] Auth extraction:', {
        hasAuthToken: !!authToken,
        hasApiKey: !!apiKey,
        method: req.method
      })

      if (!authToken) {
        await sendEvent('error', { code: 'UNAUTHORIZED', message: 'Authentication required' })
        await writer.close()
        return
      }

      // Create Supabase admin client for all operations
      const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

      // Get user by validating the JWT token directly
      const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(authToken)

      if (authError || !user) {
        console.error('❌ [VOICE] Auth error:', authError)
        await sendEvent('error', { code: 'UNAUTHORIZED', message: 'Invalid authentication' })
        await writer.close()
        return
      }

      console.log('✅ [VOICE] Authentication successful:', { userId: user.id })

      // Parse request
      let requestData: VoiceConversationRequest

      if (req.method === 'GET') {
        const url = new URL(req.url)
        requestData = {
          conversation_id: url.searchParams.get('conversation_id') || '',
          message: url.searchParams.get('message') || '',
          language_code: url.searchParams.get('language_code') || 'en-US',
          related_study_guide_id: url.searchParams.get('related_study_guide_id') || undefined,
          related_scripture: url.searchParams.get('related_scripture') || undefined,
        }
      } else {
        requestData = await req.json()
      }

      const {
        conversation_id,
        message,
        language_code = 'en-US',
        related_study_guide_id,
        related_scripture
      } = requestData

      if (!conversation_id || !message) {
        await sendEvent('error', { code: 'INVALID_REQUEST', message: 'Missing required fields' })
        await writer.close()
        return
      }

      console.log(`🎙️ [VOICE] Processing message for conversation: ${conversation_id}`)

      // Get user's subscription tier for message limit check
      const authService = new AuthService(SUPABASE_URL, SUPABASE_ANON_KEY, supabaseAdmin)
      const tier = await authService.getUserPlan(req)

      // NOTE: Monthly conversation quota (10/month for standard) is checked when STARTING
      // a conversation, not here. This endpoint handles messages in EXISTING conversations.
      // See: frontend/voice_buddy_remote_data_source.dart startConversation()
      
      // Check conversation message limit (50 messages per conversation for non-premium)
      if (tier !== 'premium') {
        const messageLimit = await checkConversationMessageLimit(supabaseAdmin, conversation_id)

        if (!messageLimit.canProceed) {
          await sendEvent('conversation_limit_exceeded', {
            message: 'This conversation has reached the maximum message limit (50). Please start a new conversation.',
            messageCount: messageLimit.messageCount,
            limit: MAX_MESSAGES_PER_CONVERSATION
          })
          await writer.close()
          return
        }
        
        // Send message limit status
        await sendEvent('message_limit_status', {
          messageCount: messageLimit.messageCount,
          limit: MAX_MESSAGES_PER_CONVERSATION,
          remaining: MAX_MESSAGES_PER_CONVERSATION - messageLimit.messageCount
        })
      }

      // Get user context
      const userContext = await getUserContext(supabaseAdmin, user.id)

      // Get study context if a study guide ID was provided
      const studyContext = related_study_guide_id
        ? await getStudyContext(supabaseAdmin, related_study_guide_id)
        : null

      // Build system prompt
      const systemPrompt = getVoiceSystemPrompt(language_code, {
        maturityLevel: userContext.maturityLevel,
        currentStudy: studyContext || related_scripture || 'General conversation',
        recentTopics: userContext.recentTopics,
      })

      // Get conversation history
      const history = await getConversationHistory(supabaseAdmin, conversation_id)

      // Build messages for LLM
      const llmMessages: ConversationMessage[] = [
        { role: 'system', content: systemPrompt },
        ...getVoiceExamples(language_code).map(ex => ({
          role: ex.role as 'user' | 'assistant',
          content: ex.content
        })),
        ...history,
        { role: 'user', content: message }
      ]

      // Save user message
      await saveMessage(
        supabaseAdmin,
        conversation_id,
        user.id,
        'user',
        message,
        language_code
      )

      // Stream AI response
      let fullResponse = ''

      await sendEvent('stream_start', { timestamp: Date.now() })

      for await (const chunk of streamLLMResponse(llmMessages, language_code)) {
        fullResponse += chunk
        await sendEvent('content', { text: chunk })
      }

      // Extract scripture references
      const scriptureRefs = extractScriptureReferences(fullResponse)

      // Save assistant message
      await saveMessage(
        supabaseAdmin,
        conversation_id,
        user.id,
        'assistant',
        fullResponse,
        language_code,
        {
          llmModelUsed: 'gpt-4o-mini',
          scriptureReferences: scriptureRefs,
        }
      )

      // Send completion event
      await sendEvent('stream_end', {
        timestamp: Date.now(),
        scripture_references: scriptureRefs,
        translation: getPrimaryTranslation(language_code),
      })

      console.log(`✅ [VOICE] Completed response for conversation: ${conversation_id}`)

    } catch (error) {
      console.error('❌ [VOICE] Error:', error)
      await sendEvent('error', {
        code: 'SERVER_ERROR',
        message: error instanceof Error ? error.message : 'An error occurred'
      })
    } finally {
      await writer.close()
    }
  })()

  // Don't await, let it stream
  responsePromise.catch(console.error)

  return new Response(stream.readable, {
    headers: {
      ...getCorsHeaders(req.headers.get('origin')),
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  })
})
