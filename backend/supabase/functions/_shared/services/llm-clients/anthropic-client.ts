/**
 * Anthropic Client Module
 * 
 * Handles all Anthropic Claude API interactions including:
 * - Study guide generation (especially for multilingual content)
 * - Daily verse generation
 * - Follow-up responses
 */

import type { AnthropicRequest, AnthropicResponse, LanguageConfig, LLMGenerationParams, LLMUsageMetadata, LLMResponseWithUsage } from '../llm-types.ts'
import { calculateOptimalTokens } from '../llm-utils/prompt-builder.ts'
import { CostTrackingService } from '../cost-tracking-service.ts'

/**
 * Anthropic API configuration
 */
export interface AnthropicClientConfig {
  apiKey: string
}

/**
 * Anthropic call options
 */
export interface AnthropicCallOptions {
  systemMessage: string
  userMessage: string
  temperature?: number
  maxTokens?: number
  model?: string  // Optional model override (e.g., Haiku for sentiment analysis)
}

/**
 * Anthropic Client for handling all Claude API interactions
 */
export class AnthropicClient {
  private readonly apiKey: string
  private readonly baseUrl = 'https://api.anthropic.com/v1/messages'
  private readonly apiVersion = '2023-06-01'
  private readonly costTracker = new CostTrackingService()

  constructor(config: AnthropicClientConfig) {
    if (!config.apiKey || !config.apiKey.startsWith('sk-ant-')) {
      throw new Error('Invalid Anthropic API key format')
    }
    this.apiKey = config.apiKey
  }

  /**
   * Extracts usage metadata from Anthropic API response.
   * Accounts for cached token pricing (90% discount on cache reads).
   */
  private extractUsage(data: AnthropicResponse, model: string): LLMUsageMetadata {
    const inputTokens = data.usage.input_tokens
    const outputTokens = data.usage.output_tokens
    const cacheCreationTokens = data.usage.cache_creation_input_tokens || 0
    const cacheReadTokens = data.usage.cache_read_input_tokens || 0

    // Calculate cost: cache reads are 10% of input price, cache writes are 125%
    const cost = this.costTracker.calculateCost('anthropic', model, inputTokens, outputTokens)

    // Adjust cost for cached tokens
    const pricing = this.costTracker.getModelPricing('anthropic', model)
    let cacheSavings = 0
    if (pricing && cacheReadTokens > 0) {
      // Cache reads cost 10% of input price (saving 90%)
      cacheSavings = (cacheReadTokens / 1000) * pricing.input_per_1k * 0.9
    }
    let cacheWriteCost = 0
    if (pricing && cacheCreationTokens > 0) {
      // Cache writes cost 125% of input price (25% surcharge)
      cacheWriteCost = (cacheCreationTokens / 1000) * pricing.input_per_1k * 0.25
    }

    const adjustedCost = cost.totalCost - cacheSavings + cacheWriteCost

    if (cacheReadTokens > 0 || cacheCreationTokens > 0) {
      console.log(`[Anthropic] Cache: ${cacheReadTokens} read, ${cacheCreationTokens} written (savings: $${cacheSavings.toFixed(4)})`)
    }

    return {
      provider: 'anthropic',
      model,
      inputTokens: inputTokens + cacheReadTokens + cacheCreationTokens,
      outputTokens,
      totalTokens: inputTokens + cacheReadTokens + cacheCreationTokens + outputTokens,
      costUsd: adjustedCost
    }
  }

  /**
   * Selects the optimal Anthropic model based on language and study mode.
   * v3.6: Cost optimization - Claude Haiku 4.5 for lightweight tasks (73% cheaper).
   * v3.5: Claude Sonnet 4.5 for study guide generation (better quality).
   *
   * @param language - Target language code
   * @param studyMode - Optional study mode for cost optimization
   * @returns Anthropic model name
   */
  selectModel(language: string, studyMode?: string): string {
    // v3.6: Claude Sonnet 4.5 for study guide generation
    return 'claude-sonnet-4-5-20250929'
  }

  /**
   * Selects a lightweight model for short-response tasks.
   * Claude Haiku 4.5 is 73% cheaper than Sonnet ($0.0008/$0.004 vs $0.003/$0.015).
   * Used for: daily verse, follow-ups, sentiment analysis.
   */
  private selectLightweightModel(): string {
    return 'claude-haiku-4-5-20251001'
  }

  /**
   * Makes an HTTP POST request to the Anthropic API.
   *
   * @param request - The Anthropic request payload
   * @returns The parsed API response
   * @throws Error if the API request fails
   */
  private async makeRequest(request: AnthropicRequest): Promise<AnthropicResponse> {
    const response = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'x-api-key': this.apiKey,
        'Content-Type': 'application/json',
        'anthropic-version': this.apiVersion
      },
      body: JSON.stringify(request)
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`Anthropic API error (${response.status}): ${errorText}`)
    }

    return await response.json()
  }

  /**
   * Parses and validates the Anthropic API response.
   *
   * @param data - The raw API response
   * @returns The extracted text content
   * @throws Error if the response contains no valid text content
   */
  private parseResponse(data: AnthropicResponse): string {
    if (!data.content || data.content.length === 0) {
      throw new Error('Anthropic API returned no content')
    }

    const textContent = data.content.find(c => c.type === 'text')
    if (!textContent) {
      throw new Error('Anthropic API returned no text content')
    }

    return textContent.text
  }

  /**
   * Makes an API call to Anthropic.
   *
   * @param options - Call options including system/user messages and parameters
   * @returns Response content with usage metadata
   * @throws Error if the API request fails or returns invalid content
   */
  async call(options: AnthropicCallOptions): Promise<LLMResponseWithUsage<string>> {
    const { systemMessage, userMessage, temperature = 0.3, maxTokens = 3000, model: modelOverride } = options

    const model = modelOverride || this.selectModel('en')
    const request: AnthropicRequest = {
      model,
      max_tokens: maxTokens,
      temperature,
      top_k: 250,
      system: systemMessage,
      messages: [{ role: 'user', content: userMessage }]
    }

    const data = await this.makeRequest(request)
    const content = this.parseResponse(data)
    const usage = this.extractUsage(data, model)
    console.log(`[Anthropic] Usage: ${usage.totalTokens} tokens (cost: $${usage.costUsd.toFixed(4)})`)

    return { content, usage }
  }

  /**
   * Makes an API call for study guide generation with optimized parameters.
   *
   * @param systemMessage - System prompt for study guide generation
   * @param userMessage - User prompt with scripture/topic details
   * @param languageConfig - Language-specific configuration for token limits
   * @param params - Generation parameters including language
   * @returns Response content with usage metadata
   * @throws Error if the API request fails or returns invalid content
   */
  async callForStudyGuide(
    systemMessage: string,
    userMessage: string,
    languageConfig: LanguageConfig,
    params: LLMGenerationParams
  ): Promise<LLMResponseWithUsage<string>> {
    const model = this.selectModel(params.language, params.studyMode)
    const maxTokens = calculateOptimalTokens(params, languageConfig)

    const request: AnthropicRequest = {
      model,
      max_tokens: maxTokens,
      temperature: languageConfig.temperature,
      top_k: 250,
      system: systemMessage,
      messages: [{ role: 'user', content: userMessage }]
    }

    console.log(`[Anthropic] Calling API with request:`, {
      model: request.model,
      max_tokens: request.max_tokens,
      temperature: request.temperature,
      messageLength: request.messages[0].content.length,
      systemMessageLength: typeof request.system === 'string' ? request.system.length : Array.isArray(request.system) ? request.system.reduce((sum, b) => sum + b.text.length, 0) : 0
    })

    const data = await this.makeRequest(request)
    const content = this.parseResponse(data)
    const usage = this.extractUsage(data, model)
    console.log(`[Anthropic] Study guide usage: ${usage.totalTokens} tokens (cost: $${usage.costUsd.toFixed(4)})`)

    return { content, usage }
  }

  /**
   * Makes an API call for verse generation.
   * v3.6: Uses Claude Haiku 4.5 (73% cheaper - short response, simple task).
   *
   * @param systemMessage - System prompt for verse selection
   * @param userMessage - User prompt with verse request details
   * @returns Response content with usage metadata
   * @throws Error if the API request fails or returns invalid content
   */
  async callForVerse(systemMessage: string, userMessage: string): Promise<LLMResponseWithUsage<string>> {
    const model = this.selectLightweightModel()
    const request: AnthropicRequest = {
      model,
      max_tokens: 800,
      temperature: 0.2,
      system: systemMessage,
      messages: [{ role: 'user', content: userMessage }]
    }

    const data = await this.makeRequest(request)
    const content = this.parseResponse(data)
    const usage = this.extractUsage(data, model)

    return { content, usage }
  }

  /**
   * Makes an API call for follow-up responses.
   * v3.6: Uses Claude Haiku 4.5 (73% cheaper - short response, contextual Q&A).
   *
   * @param systemMessage - System prompt for follow-up context
   * @param userMessage - User's follow-up question
   * @param language - Target language code ('en', 'hi', 'ml')
   * @returns Response content with usage metadata
   * @throws Error if the API request fails or returns invalid content
   */
  async callForFollowUp(systemMessage: string, userMessage: string, language: string): Promise<LLMResponseWithUsage<string>> {
    const model = this.selectLightweightModel()
    const request: AnthropicRequest = {
      model,
      max_tokens: 800,
      temperature: 0.4,
      system: systemMessage,
      messages: [{ role: 'user', content: userMessage }]
    }

    const data = await this.makeRequest(request)
    const content = this.parseResponse(data)
    const usage = this.extractUsage(data, model)

    return { content, usage }
  }

  /**
   * Builds the system parameter for split-block prompt caching.
   * If the shared prefix is long enough (>= 1024 tokens), uses two content blocks
   * with cache_control on the shared prefix. Otherwise concatenates as plain string.
   */
  private buildCachedSystem(
    sharedSystem: string,
    passSystem: string,
    language: string
  ): string | Array<{ type: 'text'; text: string; cache_control?: { type: 'ephemeral' } }> {
    // Estimate tokens: Hindi ~2 chars/token, Malayalam ~1.5, English ~4
    const charPerToken = language === 'ml' ? 1.5 : language === 'hi' ? 2 : 4
    const estimatedSharedTokens = Math.ceil(sharedSystem.length / charPerToken)
    const MIN_CACHEABLE = 1024

    if (estimatedSharedTokens >= MIN_CACHEABLE) {
      console.log(`[Anthropic] Caching: shared prefix ~${estimatedSharedTokens} tokens (caching: enabled)`)
      return [
        { type: 'text' as const, text: sharedSystem, cache_control: { type: 'ephemeral' as const } },
        { type: 'text' as const, text: passSystem }
      ]
    }

    console.log(`[Anthropic] Caching: shared prefix ~${estimatedSharedTokens} tokens (caching: disabled, below 1024 minimum)`)
    return sharedSystem + '\n\n' + passSystem
  }

  /**
   * Non-streaming call with split-block prompt caching for multipass generation.
   * Used by sermon multipass (4 passes) where shared prefix is cached across passes 2-4.
   */
  async callWithCachedPrefix(
    sharedSystem: string,
    passSystem: string,
    userMessage: string,
    languageConfig: LanguageConfig,
    params: LLMGenerationParams
  ): Promise<LLMResponseWithUsage<string>> {
    const model = this.selectModel(params.language, params.studyMode)
    const maxTokens = calculateOptimalTokens(params, languageConfig)
    const system = this.buildCachedSystem(sharedSystem, passSystem, params.language)

    const request: AnthropicRequest = {
      model,
      max_tokens: maxTokens,
      temperature: languageConfig.temperature,
      top_k: 250,
      system,
      messages: [{ role: 'user', content: userMessage }]
    }

    console.log(`[Anthropic] Calling API with cached prefix:`, {
      model: request.model,
      max_tokens: request.max_tokens,
      temperature: request.temperature,
      messageLength: request.messages[0].content.length,
      systemBlocks: Array.isArray(system) ? system.length : 1
    })

    const data = await this.makeRequest(request)
    const content = this.parseResponse(data)
    const usage = this.extractUsage(data, model)
    console.log(`[Anthropic] Cached prefix call usage: ${usage.totalTokens} tokens (cost: $${usage.costUsd.toFixed(4)})`)

    return { content, usage }
  }

  /**
   * Streaming call with split-block prompt caching for multipass generation.
   * Used by standard/deep/lectio multipass (2 passes) where shared prefix is cached on pass 2.
   */
  async *streamWithCachedPrefix(
    sharedSystem: string,
    passSystem: string,
    userMessage: string,
    languageConfig: LanguageConfig,
    params: LLMGenerationParams
  ): AsyncGenerator<string, LLMUsageMetadata, unknown> {
    const model = this.selectModel(params.language, params.studyMode)
    const maxTokens = calculateOptimalTokens(params, languageConfig)
    const system = this.buildCachedSystem(sharedSystem, passSystem, params.language)

    const request = {
      model,
      max_tokens: maxTokens,
      temperature: languageConfig.temperature,
      top_k: 250,
      system,
      messages: [{ role: 'user', content: userMessage }],
      stream: true
    }

    console.log(`[Anthropic] Starting streaming with cached prefix, model: ${model}`)

    const response = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'x-api-key': this.apiKey,
        'Content-Type': 'application/json',
        'anthropic-version': this.apiVersion
      },
      body: JSON.stringify(request)
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`Anthropic API error (${response.status}): ${errorText}`)
    }

    const reader = response.body?.getReader()
    if (!reader) {
      throw new Error('No response body reader available')
    }

    const decoder = new TextDecoder()
    let totalChars = 0
    let buffer = ''
    let jsonStarted = false
    let accumulatedChunks = ''
    let usageData: LLMUsageMetadata | null = null

    try {
      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        buffer += decoder.decode(value, { stream: true })

        const lines = buffer.split('\n')
        buffer = lines.pop() || ''

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const data = line.slice(6)
            if (!data || data === '[DONE]') continue

            try {
              const parsed = JSON.parse(data)

              if (parsed.type === 'content_block_delta') {
                const delta = parsed.delta?.text
                if (delta) {
                  totalChars += delta.length

                  if (!jsonStarted) {
                    accumulatedChunks += delta
                    if (accumulatedChunks.length >= 10) {
                      let cleaned = accumulatedChunks
                      cleaned = cleaned.replace(/^```json\s*/, '')
                      cleaned = cleaned.replace(/^```\s*/, '')
                      if (cleaned.includes('{')) {
                        jsonStarted = true
                        const braceIndex = cleaned.indexOf('{')
                        yield cleaned.substring(0, braceIndex + 1)
                        if (braceIndex + 1 < cleaned.length) {
                          yield cleaned.substring(braceIndex + 1)
                        }
                        accumulatedChunks = ''
                      }
                    }
                    continue
                  }

                  const cleanedDelta = delta.replace(/```\s*$/g, '')
                  if (cleanedDelta) {
                    yield cleanedDelta
                  }
                }
              } else if (parsed.type === 'message_stop') {
                console.log(`[Anthropic] Cached stream completed: ${totalChars} total characters`)
                if (usageData) {
                  console.log(`[Anthropic] Usage: ${usageData.totalTokens} tokens (cost: $${usageData.costUsd.toFixed(4)})`)
                  return usageData
                } else {
                  console.warn(`[Anthropic] No usage data from cached stream, estimating...`)
                  const estimatedTokens = Math.ceil(totalChars / 4)
                  return {
                    provider: 'anthropic', model,
                    inputTokens: estimatedTokens * 0.3, outputTokens: estimatedTokens * 0.7,
                    totalTokens: estimatedTokens, costUsd: 0
                  }
                }
              } else if (parsed.type === 'message_start') {
                if (parsed.message?.usage) {
                  const inputTokens = parsed.message.usage.input_tokens || 0
                  const outputTokens = parsed.message.usage.output_tokens || 0
                  if (inputTokens > 0 || outputTokens > 0) {
                    usageData = this.extractUsage({
                      content: [], usage: { input_tokens: inputTokens, output_tokens: outputTokens },
                      stop_reason: 'end_turn'
                    } as AnthropicResponse, model)
                  }
                }
              } else if (parsed.type === 'message_delta') {
                if (parsed.usage) {
                  usageData = this.extractUsage({
                    content: [], usage: parsed.usage, stop_reason: 'end_turn'
                  } as AnthropicResponse, model)
                }
              } else if (parsed.type === 'error') {
                throw new Error(`Anthropic stream error: ${parsed.error?.message || 'Unknown error'}`)
              }
            } catch (parseError) {
              if (parseError instanceof SyntaxError) continue
              throw parseError
            }
          }
        }
      }
    } finally {
      reader.releaseLock()
    }

    console.log(`[Anthropic] Cached stream ended: ${totalChars} total characters`)
    if (usageData) return usageData
    const estimatedTokens = Math.ceil(totalChars / 4)
    return {
      provider: 'anthropic', model,
      inputTokens: estimatedTokens * 0.3, outputTokens: estimatedTokens * 0.7,
      totalTokens: estimatedTokens, costUsd: 0
    }
  }

  /**
   * Streams study guide generation, yielding chunks as they arrive.
   *
   * This is an async generator that yields raw text chunks from the LLM.
   * The caller is responsible for parsing these chunks into sections.
   *
   * @param systemMessage - System prompt
   * @param userMessage - User prompt
   * @param languageConfig - Language configuration
   * @param params - Generation parameters
   * @yields Raw text chunks from the LLM stream
   * @returns Usage metadata from the LLM API
   */
  async *streamStudyGuide(
    systemMessage: string,
    userMessage: string,
    languageConfig: LanguageConfig,
    params: LLMGenerationParams
  ): AsyncGenerator<string, LLMUsageMetadata, unknown> {
    const model = this.selectModel(params.language, params.studyMode)
    const maxTokens = calculateOptimalTokens(params, languageConfig)

    const request = {
      model,
      max_tokens: maxTokens,
      temperature: languageConfig.temperature,
      top_k: 250,
      system: systemMessage,
      messages: [{ role: 'user', content: userMessage }],
      stream: true
    }

    console.log(`[Anthropic] Starting streaming study guide generation with model: ${model}`)

    const response = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'x-api-key': this.apiKey,
        'Content-Type': 'application/json',
        'anthropic-version': this.apiVersion
      },
      body: JSON.stringify(request)
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`Anthropic API error (${response.status}): ${errorText}`)
    }

    const reader = response.body?.getReader()
    if (!reader) {
      throw new Error('No response body reader available')
    }

    const decoder = new TextDecoder()
    let totalChars = 0
    let fullResponse = '' // Track complete response for debugging
    let buffer = ''
    let jsonStarted = false // Track if we've seen the opening {
    let accumulatedChunks = '' // Accumulate first few chars to detect markdown
    let usageData: LLMUsageMetadata | null = null

    try {
      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        buffer += decoder.decode(value, { stream: true })

        // Process complete SSE events from buffer
        const lines = buffer.split('\n')
        buffer = lines.pop() || '' // Keep incomplete line in buffer

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const data = line.slice(6)

            // Skip empty data or ping events
            if (!data || data === '[DONE]') continue

            try {
              const parsed = JSON.parse(data)

              // Handle different Anthropic SSE event types
              if (parsed.type === 'content_block_delta') {
                const delta = parsed.delta?.text
                if (delta) {
                  totalChars += delta.length
                  fullResponse += delta

                  let cleanedDelta = delta

                  // If we haven't seen JSON start yet, accumulate and check for markdown
                  if (!jsonStarted) {
                    accumulatedChunks += delta

                    // Check if we have enough to detect markdown wrapper
                    if (accumulatedChunks.length >= 10) {
                      // Strip markdown wrapper from accumulated chunks
                      let cleaned = accumulatedChunks

                      // Remove opening markdown patterns
                      cleaned = cleaned.replace(/^```json\s*/, '')
                      cleaned = cleaned.replace(/^```\s*/, '')

                      // Check if JSON has started
                      if (cleaned.includes('{')) {
                        jsonStarted = true

                        // Yield everything up to and including the opening brace
                        const braceIndex = cleaned.indexOf('{')
                        const firstYield = cleaned.substring(0, braceIndex + 1)
                        yield firstYield

                        // If there's content after the brace, yield it too
                        if (braceIndex + 1 < cleaned.length) {
                          const secondYield = cleaned.substring(braceIndex + 1)
                          yield secondYield
                        }

                        accumulatedChunks = '' // Clear accumulator
                      }
                    }
                    continue // Don't yield yet, keep accumulating
                  }

                  // After JSON started, just strip closing markdown if present
                  cleanedDelta = cleanedDelta.replace(/```\s*$/g, '')

                  // Yield cleaned content
                  if (cleanedDelta) {
                    yield cleanedDelta
                  }
                }
              } else if (parsed.type === 'message_stop') {
                console.log(`[Anthropic] Stream completed: ${totalChars} total characters`)

                // Return usage metadata if captured, otherwise estimate
                if (usageData) {
                  console.log(`[Anthropic] Usage: ${usageData.totalTokens} tokens (cost: $${usageData.costUsd.toFixed(4)})`)
                  return usageData
                } else {
                  // Fallback: estimate if usage not captured
                  console.warn(`[Anthropic] ⚠️ No usage data from streaming, estimating...`)
                  const estimatedTokens = Math.ceil(totalChars / 4)
                  return {
                    provider: 'anthropic',
                    model,
                    inputTokens: estimatedTokens * 0.3,
                    outputTokens: estimatedTokens * 0.7,
                    totalTokens: estimatedTokens,
                    costUsd: 0
                  }
                }
              } else if (parsed.type === 'message_start') {
                // Anthropic sends usage in message_start event
                if (parsed.message?.usage) {
                  const inputTokens = parsed.message.usage.input_tokens || 0
                  const outputTokens = parsed.message.usage.output_tokens || 0
                  if (inputTokens > 0 || outputTokens > 0) {
                    usageData = this.extractUsage({
                      content: [],
                      usage: { input_tokens: inputTokens, output_tokens: outputTokens },
                      stop_reason: 'end_turn'
                    } as AnthropicResponse, model)
                  }
                }
              } else if (parsed.type === 'message_delta') {
                // Anthropic sends final usage in message_delta event
                if (parsed.usage) {
                  usageData = this.extractUsage({
                    content: [],
                    usage: parsed.usage,
                    stop_reason: 'end_turn'
                  } as AnthropicResponse, model)
                }
              } else if (parsed.type === 'error') {
                throw new Error(`Anthropic stream error: ${parsed.error?.message || 'Unknown error'}`)
              }
            } catch (parseError) {
              // Skip malformed JSON chunks
              if (parseError instanceof SyntaxError) {
                continue
              }
              throw parseError
            }
          }
        }
      }
    } finally {
      reader.releaseLock()
    }

    console.log(`[Anthropic] Stream ended: ${totalChars} total characters`)

    // Return usage or estimate if not captured during stream
    if (usageData) {
      return usageData
    } else {
      const estimatedTokens = Math.ceil(totalChars / 4)
      return {
        provider: 'anthropic',
        model,
        inputTokens: estimatedTokens * 0.3,
        outputTokens: estimatedTokens * 0.7,
        totalTokens: estimatedTokens,
        costUsd: 0
      }
    }
  }
}

/**
 * Validates Anthropic API key format.
 * 
 * @param apiKey - API key to validate
 * @returns True if valid format
 */
export function isValidAnthropicKey(apiKey: string | undefined): boolean {
  return !!apiKey && apiKey.trim().length > 0 && apiKey.startsWith('sk-ant-')
}
