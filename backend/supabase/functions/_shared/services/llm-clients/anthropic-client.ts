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
   * Extracts usage metadata from Anthropic API response
   */
  private extractUsage(data: AnthropicResponse, model: string): LLMUsageMetadata {
    const inputTokens = data.usage.input_tokens
    const outputTokens = data.usage.output_tokens
    const cost = this.costTracker.calculateCost('anthropic', model, inputTokens, outputTokens)

    return {
      provider: 'anthropic',
      model,
      inputTokens,
      outputTokens,
      totalTokens: inputTokens + outputTokens,
      costUsd: cost.totalCost
    }
  }

  /**
   * Selects the optimal Anthropic model based on language and study mode.
   * v3.4: Cost optimization - Claude Haiku for Quick Read mode (73% cheaper).
   * v3.3: Using Claude Sonnet 4.5 for all other modes for better length compliance.
   *
   * @param language - Target language code
   * @param studyMode - Optional study mode for cost optimization
   * @returns Anthropic model name
   */
  selectModel(language: string, studyMode?: string): string {
    // v3.4 Cost Optimization: Use Claude Haiku 4.5 for Quick Read mode
    // Quick Read is simple (600-750 words), Haiku is sufficient and 73% cheaper
    // Savings: $0.013 → $0.0035 per guide (73% reduction)
    // Impact: ~₹1,533/month savings on Quick Read alone (1,758 guides/month)
    if (studyMode === 'quick') {
      return 'claude-haiku-4-5-20250929'
    }

    // v3.3: Claude Sonnet 4.5 for all other modes (better at following word count instructions)
    // Expected improvement: 30-50% longer outputs with better instruction adherence
    return 'claude-sonnet-4-5-20250929'
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
    const { systemMessage, userMessage, temperature = 0.3, maxTokens = 3000 } = options

    const model = this.selectModel('en')
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
      systemMessageLength: request.system?.length || 0
    })

    const data = await this.makeRequest(request)
    const content = this.parseResponse(data)
    const usage = this.extractUsage(data, model)
    console.log(`[Anthropic] Study guide usage: ${usage.totalTokens} tokens (cost: $${usage.costUsd.toFixed(4)})`)

    return { content, usage }
  }

  /**
   * Makes an API call for verse generation.
   * v3.3: Using Claude Sonnet 4.5 for consistency.
   *
   * @param systemMessage - System prompt for verse selection
   * @param userMessage - User prompt with verse request details
   * @returns Response content with usage metadata
   * @throws Error if the API request fails or returns invalid content
   */
  async callForVerse(systemMessage: string, userMessage: string): Promise<LLMResponseWithUsage<string>> {
    const model = 'claude-sonnet-4-5-20250929'
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
   * v3.3: Using Claude Sonnet 4.5 for all languages for consistency.
   *
   * @param systemMessage - System prompt for follow-up context
   * @param userMessage - User's follow-up question
   * @param language - Target language code ('en', 'hi', 'ml')
   * @returns Response content with usage metadata
   * @throws Error if the API request fails or returns invalid content
   */
  async callForFollowUp(systemMessage: string, userMessage: string, language: string): Promise<LLMResponseWithUsage<string>> {
    const model = 'claude-sonnet-4-5-20250929'
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

    // Anthropic streaming request
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
