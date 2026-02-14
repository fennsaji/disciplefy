/**
 * OpenAI Client Module
 * 
 * Handles all OpenAI API interactions including:
 * - Study guide generation
 * - Daily verse generation
 * - Follow-up responses
 * - Streaming support
 */

import type { OpenAIRequest, OpenAIResponse, LanguageConfig, LLMGenerationParams, LLMUsageMetadata, LLMResponseWithUsage } from '../llm-types.ts'
import { calculateOptimalTokens } from '../llm-utils/prompt-builder.ts'
import { studyGuideSchema } from '../llm-utils/study-guide-schema.ts'
import { CostTrackingService } from '../cost-tracking-service.ts'

/**
 * OpenAI API configuration
 */
export interface OpenAIClientConfig {
  apiKey: string
}

/**
 * OpenAI call options
 */
export interface OpenAICallOptions {
  systemMessage: string
  userMessage: string
  temperature?: number
  maxTokens?: number
  jsonMode?: boolean
  stream?: boolean
}

/**
 * OpenAI Client for handling all OpenAI API interactions
 */
export class OpenAIClient {
  private readonly apiKey: string
  private readonly baseUrl = 'https://api.openai.com/v1/chat/completions'
  private readonly costTracker = new CostTrackingService()

  constructor(config: OpenAIClientConfig) {
    if (!config.apiKey || !config.apiKey.startsWith('sk-')) {
      throw new Error('Invalid OpenAI API key format')
    }
    this.apiKey = config.apiKey
  }

  /**
   * Extracts usage metadata from OpenAI API response
   */
  private extractUsage(data: OpenAIResponse, model: string): LLMUsageMetadata {
    const inputTokens = data.usage.prompt_tokens
    const outputTokens = data.usage.completion_tokens
    const cost = this.costTracker.calculateCost('openai', model, inputTokens, outputTokens)

    return {
      provider: 'openai',
      model,
      inputTokens,
      outputTokens,
      totalTokens: inputTokens + outputTokens,
      costUsd: cost.totalCost
    }
  }

  /**
   * Selects the optimal OpenAI model based on language and tier.
   * Premium English users get GPT-4.1-mini for better quality.
   * 
   * @param language - Target language code
   * @param tier - User subscription tier (optional)
   * @returns OpenAI model identifier
   */
  selectModel(language: string, tier?: string): string {
    if (language === 'en' && tier === 'premium') {
      return 'gpt-4.1-mini-2025-04-14'
    }
    return 'gpt-4o-mini-2024-07-18'
  }

  /**
   * Makes a standard (non-streaming) API call to OpenAI.
   *
   * @param options - Call options
   * @returns Response content with usage metadata
   */
  async call(options: OpenAICallOptions): Promise<LLMResponseWithUsage<string>> {
    const {
      systemMessage,
      userMessage,
      temperature = 0.3,
      maxTokens = 3000,
      jsonMode = false
    } = options

    const model = 'gpt-4o-mini-2024-07-18'
    const request: OpenAIRequest = {
      model,
      messages: [
        { role: 'system', content: systemMessage },
        { role: 'user', content: userMessage }
      ],
      temperature,
      max_tokens: maxTokens,
      presence_penalty: 0.1,
      frequency_penalty: 0.1,
      ...(jsonMode && { response_format: { type: 'json_object' as const } })
    }

    const response = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(request)
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`OpenAI API error (${response.status}): ${errorText}`)
    }

    const data: OpenAIResponse = await response.json()

    if (!data.choices || data.choices.length === 0) {
      throw new Error('OpenAI API returned no choices')
    }

    const content = data.choices[0].message.content
    if (!content) {
      throw new Error('OpenAI API returned empty content')
    }

    const usage = this.extractUsage(data, model)
    console.log(`[OpenAI] Usage: ${usage.totalTokens} tokens (cost: $${usage.costUsd.toFixed(4)})`)

    return { content, usage }
  }

  /**
   * Makes an API call for study guide generation with optimized parameters.
   *
   * @param systemMessage - System prompt
   * @param userMessage - User prompt
   * @param languageConfig - Language-specific configuration
   * @param params - Generation parameters
   * @returns Response content with usage metadata
   */
  async callForStudyGuide(
    systemMessage: string,
    userMessage: string,
    languageConfig: LanguageConfig,
    params: LLMGenerationParams,
    useSchema: boolean = true
  ): Promise<LLMResponseWithUsage<string>> {
    const model = this.selectModel(params.language, params.tier)
    const maxTokens = calculateOptimalTokens(params, languageConfig)

    const request: OpenAIRequest = {
      model,
      messages: [
        { role: 'system', content: systemMessage },
        { role: 'user', content: userMessage }
      ],
      temperature: languageConfig.temperature,
      max_tokens: maxTokens,
      presence_penalty: 0.1,
      frequency_penalty: 0.1,
      response_format: useSchema ? {
        type: 'json_schema',
        json_schema: studyGuideSchema
      } : {
        type: 'json_object'
      }
    }

    const response = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(request)
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`OpenAI API error (${response.status}): ${errorText}`)
    }

    const data: OpenAIResponse = await response.json()

    if (!data.choices || data.choices.length === 0) {
      throw new Error('OpenAI API returned no choices')
    }

    const content = data.choices[0].message.content
    if (!content) {
      throw new Error('OpenAI API returned empty content')
    }

    const usage = this.extractUsage(data, model)
    console.log(`[OpenAI] Study guide usage: ${usage.totalTokens} tokens (cost: $${usage.costUsd.toFixed(4)})`)

    return { content, usage }
  }

  /**
   * Makes an API call for verse generation.
   *
   * @param systemMessage - System prompt
   * @param userMessage - User prompt
   * @returns Response content with usage metadata
   */
  async callForVerse(systemMessage: string, userMessage: string): Promise<LLMResponseWithUsage<string>> {
    const model = 'gpt-4o-mini-2024-07-18'
    const request: OpenAIRequest = {
      model,
      messages: [
        { role: 'system', content: systemMessage },
        { role: 'user', content: userMessage }
      ],
      temperature: 0.3,
      max_tokens: 800,
      response_format: { type: 'json_object' }
    }

    const response = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(request)
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`OpenAI API error (${response.status}): ${errorText}`)
    }

    const data: OpenAIResponse = await response.json()

    if (!data.choices || data.choices.length === 0) {
      throw new Error('OpenAI API returned no choices')
    }

    const content = data.choices[0].message.content
    if (!content) {
      throw new Error('OpenAI API returned empty content')
    }

    const usage = this.extractUsage(data, model)
    return { content, usage }
  }

  /**
   * Makes an API call for follow-up responses.
   *
   * @param systemMessage - System prompt
   * @param userMessage - User prompt
   * @returns Response content with usage metadata
   */
  async callForFollowUp(systemMessage: string, userMessage: string): Promise<LLMResponseWithUsage<string>> {
    const model = 'gpt-4o-mini-2024-07-18'
    const request: OpenAIRequest = {
      model,
      messages: [
        { role: 'system', content: systemMessage },
        { role: 'user', content: userMessage }
      ],
      temperature: 0.4,
      max_tokens: 800,
      presence_penalty: 0.2,
      frequency_penalty: 0.1
    }

    const response = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(request)
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`OpenAI API error (${response.status}): ${errorText}`)
    }

    const data: OpenAIResponse = await response.json()

    if (!data.choices || data.choices.length === 0) {
      throw new Error('OpenAI API returned no choices')
    }

    const content = data.choices[0].message.content
    if (!content) {
      throw new Error('OpenAI API returned empty content')
    }

    const usage = this.extractUsage(data, model)
    return { content, usage }
  }

  /**
   * Makes a streaming API call to OpenAI.
   * 
   * @param systemMessage - System prompt
   * @param userMessage - User prompt
   * @param languageConfig - Language configuration
   * @param params - Generation parameters
   * @returns Response content string
   */
  async callWithStreaming(
    systemMessage: string,
    userMessage: string,
    languageConfig: LanguageConfig,
    params: LLMGenerationParams
  ): Promise<string> {
    const model = this.selectModel(params.language, params.tier)
    const maxTokens = calculateOptimalTokens(params, languageConfig)

    const request: OpenAIRequest = {
      model,
      messages: [
        { role: 'system', content: systemMessage },
        { role: 'user', content: userMessage }
      ],
      temperature: languageConfig.temperature,
      max_tokens: maxTokens,
      presence_penalty: 0.1,
      frequency_penalty: 0.1,
      stream: true
    }

    try {
      const response = await fetch(this.baseUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(request)
      })

      if (!response.ok) {
        console.warn('[OpenAI] Streaming failed, falling back to standard mode')
        const fallbackResult = await this.callForStudyGuide(systemMessage, userMessage, languageConfig, params)
        return fallbackResult.content
      }

      const reader = response.body?.getReader()
      if (!reader) {
        throw new Error('No response body reader available')
      }

      let fullContent = ''
      const decoder = new TextDecoder()

      try {
        while (true) {
          const { done, value } = await reader.read()
          if (done) break

          const chunk = decoder.decode(value, { stream: true })
          const lines = chunk.split('\n')

          for (const line of lines) {
            if (line.startsWith('data: ')) {
              const data = line.slice(6)
              if (data === '[DONE]') continue

              try {
                const parsed = JSON.parse(data)
                const delta = parsed.choices?.[0]?.delta?.content
                if (delta) {
                  fullContent += delta
                }
              } catch {
                continue
              }
            }
          }
        }
      } finally {
        reader.releaseLock()
      }

      if (!fullContent.trim()) {
        throw new Error('Empty streaming response')
      }

      console.log(`[OpenAI] Streaming completed: ${fullContent.length} characters`)
      return fullContent

    } catch (error) {
      console.warn('[OpenAI] Streaming error, falling back to standard mode:',
        error instanceof Error ? error.message : String(error))
      const fallbackResult = await this.callForStudyGuide(systemMessage, userMessage, languageConfig, params)
      return fallbackResult.content
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
   * @param useSchema - Whether to enforce complete study guide schema (default: true). Set to false for multi-pass prompts that define partial JSON structures.
   * @yields Raw text chunks from the LLM stream
   * @returns Usage metadata from the LLM API
   */
  async *streamStudyGuide(
    systemMessage: string,
    userMessage: string,
    languageConfig: LanguageConfig,
    params: LLMGenerationParams,
    useSchema: boolean = true
  ): AsyncGenerator<string, LLMUsageMetadata, unknown> {
    const model = this.selectModel(params.language, params.tier)
    const maxTokens = calculateOptimalTokens(params, languageConfig)

    const request: OpenAIRequest = {
      model,
      messages: [
        { role: 'system', content: systemMessage },
        { role: 'user', content: userMessage }
      ],
      temperature: languageConfig.temperature,
      max_tokens: maxTokens,
      presence_penalty: 0.1,
      frequency_penalty: 0.1,
      // Only enforce complete schema for single-pass generation
      // Multi-pass prompts define their own partial JSON structure
      ...(useSchema ? {
        response_format: {
          type: 'json_schema',
          json_schema: studyGuideSchema
        }
      } : {
        response_format: { type: 'json_object' as const }
      }),
      stream: true
    }

    console.log(`[OpenAI] Starting streaming study guide generation with model: ${model}`)

    const response = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(request)
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`OpenAI API error (${response.status}): ${errorText}`)
    }

    const reader = response.body?.getReader()
    if (!reader) {
      throw new Error('No response body reader available')
    }

    const decoder = new TextDecoder()
    let totalChars = 0
    let fullResponse = '' // For debugging
    let usageData: LLMUsageMetadata | null = null

    try {
      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        const chunk = decoder.decode(value, { stream: true })
        const lines = chunk.split('\n')

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const data = line.slice(6)
            if (data === '[DONE]') {
              console.log(`[OpenAI] Stream completed: ${totalChars} total characters`)
              if (totalChars < 500) {
                console.warn(`[OpenAI] ⚠️ Short response detected! Length: ${totalChars} characters`)
              }

              // Return usage metadata if captured, otherwise estimate
              if (usageData) {
                console.log(`[OpenAI] Usage: ${usageData.totalTokens} tokens (cost: $${usageData.costUsd.toFixed(4)})`)
                return usageData
              } else {
                // Fallback: estimate tokens if usage not provided
                console.warn(`[OpenAI] ⚠️ No usage data from streaming, estimating...`)
                const estimatedTokens = Math.ceil(totalChars / 4)
                return {
                  provider: 'openai',
                  model,
                  inputTokens: estimatedTokens * 0.3, // Rough estimate
                  outputTokens: estimatedTokens * 0.7,
                  totalTokens: estimatedTokens,
                  costUsd: 0 // Can't calculate accurately without real token counts
                }
              }
            }

            try {
              const parsed = JSON.parse(data)

              // Capture usage data if present (OpenAI sends this in final chunk before [DONE])
              if (parsed.usage) {
                usageData = this.extractUsage(parsed as OpenAIResponse, model)
              }

              // Check for content filter
              const finishReason = parsed.choices?.[0]?.finish_reason
              if (finishReason) {
                console.log(`[OpenAI] Finish reason: ${finishReason}`)

                if (finishReason === 'content_filter') {
                  console.warn(`[OpenAI] ⚠️ Content filter triggered - will fallback to Anthropic`)
                  throw new Error('CONTENT_FILTER: OpenAI content filter blocked this request - likely Biblical content with words like "sacrifice", "blood", etc.')
                }
              }

              const delta = parsed.choices?.[0]?.delta?.content
              if (delta) {
                totalChars += delta.length
                fullResponse += delta
                yield delta
              }
            } catch (parseError) {
              // Re-throw content filter errors
              if (parseError instanceof Error && parseError.message.startsWith('CONTENT_FILTER:')) {
                throw parseError
              }

              // Log malformed chunks for debugging
              console.warn(`[OpenAI] Failed to parse chunk: ${data.substring(0, 100)}...`)
              continue
            }
          }
        }
      }
    } finally {
      reader.releaseLock()
    }

    console.log(`[OpenAI] Stream ended: ${totalChars} total characters`)
    if (totalChars < 500) {
      console.warn(`[OpenAI] ⚠️ Short response at stream end! Length: ${totalChars} characters`)
    }

    // Return usage or estimate if not captured during stream
    if (usageData) {
      return usageData
    } else {
      const estimatedTokens = Math.ceil(totalChars / 4)
      return {
        provider: 'openai',
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
 * Validates OpenAI API key format.
 *
 * @param apiKey - API key to validate
 * @returns True if valid format
 */
export function isValidOpenAIKey(apiKey: string | undefined): boolean {
  return !!apiKey && apiKey.trim().length > 0 && apiKey.startsWith('sk-')
}
