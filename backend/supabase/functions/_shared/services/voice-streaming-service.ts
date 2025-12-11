/**
 * Voice Streaming Service
 *
 * Handles LLM streaming for voice conversations with:
 * - OpenAI as primary provider
 * - Anthropic Claude as fallback
 * - Tier-based model selection
 */

/**
 * Message format for LLM requests
 */
export interface StreamMessage {
  role: 'user' | 'assistant' | 'system'
  content: string
}

/**
 * Configuration for voice streaming service
 */
export interface VoiceStreamingConfig {
  openaiApiKey: string
  anthropicApiKey?: string
}

/**
 * Model configuration
 */
interface ModelConfig {
  provider: 'openai' | 'anthropic'
  model: string
  maxTokens: number
  temperature: number
}

/**
 * Service for streaming LLM responses in voice conversations
 */
export class VoiceStreamingService {
  private readonly openaiApiKey: string
  private readonly anthropicApiKey?: string

  // Model configurations by tier
  private readonly MODELS: Record<string, ModelConfig> = {
    premium: {
      provider: 'openai',
      model: 'gpt-4.1-mini-2025-04-14',
      maxTokens: 500,
      temperature: 0.7
    },
    standard: {
      provider: 'openai',
      model: 'gpt-4o-mini-2024-07-18',
      maxTokens: 500,
      temperature: 0.7
    },
    free: {
      provider: 'openai',
      model: 'gpt-4o-mini-2024-07-18',
      maxTokens: 500,
      temperature: 0.7
    }
  }

  // Fallback model (Anthropic Claude)
  private readonly FALLBACK_MODEL: ModelConfig = {
    provider: 'anthropic',
    model: 'claude-haiku-4-5-20250514',
    maxTokens: 500,
    temperature: 0.7
  }

  constructor(config: VoiceStreamingConfig) {
    this.openaiApiKey = config.openaiApiKey
    this.anthropicApiKey = config.anthropicApiKey
  }

  /**
   * Select the appropriate model based on subscription tier
   *
   * @param tier - User's subscription tier
   */
  selectModel(tier: string): string {
    const config = this.MODELS[tier] || this.MODELS.standard
    return config.model
  }

  /**
   * Get model configuration for a tier
   *
   * @param tier - User's subscription tier
   */
  private getModelConfig(tier: string): ModelConfig {
    return this.MODELS[tier] || this.MODELS.standard
  }

  /**
   * Stream LLM response with automatic fallback
   * Primary: OpenAI, Fallback: Anthropic Claude
   *
   * @param messages - Conversation messages
   * @param tier - User's subscription tier
   */
  async *stream(
    messages: StreamMessage[],
    tier: string = 'standard'
  ): AsyncGenerator<string> {
    const config = this.getModelConfig(tier)
    console.log(`[VoiceStreaming] Using model: ${config.model} for tier: ${tier}`)

    try {
      // Try primary provider (OpenAI)
      yield* this.streamOpenAI(messages, config)
    } catch (error) {
      console.error('[VoiceStreaming] OpenAI failed, trying fallback:', error)

      // Try fallback (Anthropic) if available
      if (this.anthropicApiKey) {
        try {
          yield* this.streamAnthropic(messages, this.FALLBACK_MODEL)
        } catch (fallbackError) {
          console.error('[VoiceStreaming] Anthropic fallback also failed:', fallbackError)
          throw new Error('All LLM providers failed')
        }
      } else {
        throw error
      }
    }
  }

  /**
   * Stream response from OpenAI
   *
   * @param messages - Conversation messages
   * @param config - Model configuration
   */
  async *streamOpenAI(
    messages: StreamMessage[],
    config: ModelConfig
  ): AsyncGenerator<string> {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.openaiApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: config.model,
        messages: messages.map(m => ({ role: m.role, content: m.content })),
        stream: true,
        max_tokens: config.maxTokens,
        temperature: config.temperature,
      }),
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error('[VoiceStreaming] OpenAI API error:', errorText)
      throw new Error(`OpenAI API error: ${response.status}`)
    }

    const reader = response.body?.getReader()
    if (!reader) throw new Error('No response body from OpenAI')

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
            // Skip invalid JSON lines
          }
        }
      }
    }
  }

  /**
   * Stream response from Anthropic Claude
   *
   * @param messages - Conversation messages
   * @param config - Model configuration
   */
  async *streamAnthropic(
    messages: StreamMessage[],
    config: ModelConfig
  ): AsyncGenerator<string> {
    if (!this.anthropicApiKey) {
      throw new Error('Anthropic API key not configured')
    }

    // Convert messages to Anthropic format
    // System message should be separate
    const systemMessage = messages.find(m => m.role === 'system')?.content || ''
    const conversationMessages = messages
      .filter(m => m.role !== 'system')
      .map(m => ({
        role: m.role as 'user' | 'assistant',
        content: m.content
      }))

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': this.anthropicApiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: config.model,
        system: systemMessage,
        messages: conversationMessages,
        stream: true,
        max_tokens: config.maxTokens,
        temperature: config.temperature,
      }),
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error('[VoiceStreaming] Anthropic API error:', errorText)
      throw new Error(`Anthropic API error: ${response.status}`)
    }

    const reader = response.body?.getReader()
    if (!reader) throw new Error('No response body from Anthropic')

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

          try {
            const parsed = JSON.parse(data)

            // Handle different Anthropic event types
            if (parsed.type === 'content_block_delta') {
              const text = parsed.delta?.text
              if (text) yield text
            } else if (parsed.type === 'message_stop') {
              return
            }
          } catch {
            // Skip invalid JSON lines
          }
        }
      }
    }
  }

  /**
   * Check if fallback provider is available
   */
  hasFallback(): boolean {
    return !!this.anthropicApiKey
  }
}
