/**
 * Anthropic Client Module
 * 
 * Handles all Anthropic Claude API interactions including:
 * - Study guide generation (especially for multilingual content)
 * - Daily verse generation
 * - Follow-up responses
 */

import type { AnthropicRequest, AnthropicResponse, LanguageConfig, LLMGenerationParams } from '../llm-types.ts'
import { calculateOptimalTokens } from '../llm-utils/prompt-builder.ts'

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

  constructor(config: AnthropicClientConfig) {
    if (!config.apiKey || !config.apiKey.startsWith('sk-ant-')) {
      throw new Error('Invalid Anthropic API key format')
    }
    this.apiKey = config.apiKey
  }

  /**
   * Selects the optimal Anthropic model based on language.
   *
   * @param language - Target language code
   * @returns Anthropic model name
   */
  selectModel(language: string): string {
    switch (language) {
      case 'hi':
      case 'ml':
        return 'claude-sonnet-4-20250514'
      case 'en':
      default:
        return 'claude-haiku-4-5-20251001'
    }
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
   * @returns Response content string
   * @throws Error if the API request fails or returns invalid content
   */
  async call(options: AnthropicCallOptions): Promise<string> {
    const { systemMessage, userMessage, temperature = 0.3, maxTokens = 3000 } = options

    const request: AnthropicRequest = {
      model: this.selectModel('en'),
      max_tokens: maxTokens,
      temperature,
      top_p: 0.9,
      top_k: 250,
      system: systemMessage,
      messages: [{ role: 'user', content: userMessage }]
    }

    const data = await this.makeRequest(request)
    console.log(`[Anthropic] Usage: ${data.usage.input_tokens + data.usage.output_tokens} tokens`)
    return this.parseResponse(data)
  }

  /**
   * Makes an API call for study guide generation with optimized parameters.
   *
   * @param systemMessage - System prompt for study guide generation
   * @param userMessage - User prompt with scripture/topic details
   * @param languageConfig - Language-specific configuration for token limits
   * @param params - Generation parameters including language
   * @returns Response content string with generated study guide
   * @throws Error if the API request fails or returns invalid content
   */
  async callForStudyGuide(
    systemMessage: string,
    userMessage: string,
    languageConfig: LanguageConfig,
    params: LLMGenerationParams
  ): Promise<string> {
    const model = this.selectModel(params.language)
    const maxTokens = calculateOptimalTokens(params, languageConfig)

    const request: AnthropicRequest = {
      model,
      max_tokens: maxTokens,
      temperature: languageConfig.temperature,
      top_p: 0.9,
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
    console.log(`[Anthropic] Study guide usage: ${data.usage.input_tokens + data.usage.output_tokens} tokens`)
    return this.parseResponse(data)
  }

  /**
   * Makes an API call for verse generation.
   *
   * @param systemMessage - System prompt for verse selection
   * @param userMessage - User prompt with verse request details
   * @returns Response content string with generated verse content
   * @throws Error if the API request fails or returns invalid content
   */
  async callForVerse(systemMessage: string, userMessage: string): Promise<string> {
    const request: AnthropicRequest = {
      model: 'claude-sonnet-4-20250514',
      max_tokens: 800,
      temperature: 0.2,
      system: systemMessage,
      messages: [{ role: 'user', content: userMessage }]
    }

    const data = await this.makeRequest(request)
    return this.parseResponse(data)
  }

  /**
   * Makes an API call for follow-up responses.
   *
   * @param systemMessage - System prompt for follow-up context
   * @param userMessage - User's follow-up question
   * @param language - Target language code ('en', 'hi', 'ml')
   * @returns Response content string with follow-up answer
   * @throws Error if the API request fails or returns invalid content
   */
  async callForFollowUp(systemMessage: string, userMessage: string, language: string): Promise<string> {
    const model = language === 'en' ? 'claude-haiku-4-5-20251001' : 'claude-sonnet-4-20250514'

    const request: AnthropicRequest = {
      model,
      max_tokens: 800,
      temperature: 0.4,
      system: systemMessage,
      messages: [{ role: 'user', content: userMessage }]
    }

    const data = await this.makeRequest(request)
    return this.parseResponse(data)
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
   */
  async *streamStudyGuide(
    systemMessage: string,
    userMessage: string,
    languageConfig: LanguageConfig,
    params: LLMGenerationParams
  ): AsyncGenerator<string, void, unknown> {
    const model = this.selectModel(params.language)
    const maxTokens = calculateOptimalTokens(params, languageConfig)

    // Anthropic streaming request
    const request = {
      model,
      max_tokens: maxTokens,
      temperature: languageConfig.temperature,
      top_p: 0.9,
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
    let buffer = ''

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
                  yield delta
                }
              } else if (parsed.type === 'message_stop') {
                console.log(`[Anthropic] Stream completed: ${totalChars} total characters`)
                return
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
