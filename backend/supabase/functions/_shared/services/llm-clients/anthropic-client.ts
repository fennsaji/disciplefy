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
        return 'claude-haiku-4-5-20250514'
    }
  }

  /**
   * Makes an API call to Anthropic.
   * 
   * @param options - Call options
   * @returns Response content string
   */
  async call(options: AnthropicCallOptions): Promise<string> {
    const {
      systemMessage,
      userMessage,
      temperature = 0.3,
      maxTokens = 3000
    } = options

    const request: AnthropicRequest = {
      model: 'claude-haiku-4-5-20250514',
      max_tokens: maxTokens,
      temperature,
      top_p: 0.9,
      top_k: 250,
      system: systemMessage,
      messages: [
        { role: 'user', content: userMessage }
      ]
    }

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

    const data: AnthropicResponse = await response.json()
    
    if (!data.content || data.content.length === 0) {
      throw new Error('Anthropic API returned no content')
    }

    const textContent = data.content.find(c => c.type === 'text')
    if (!textContent) {
      throw new Error('Anthropic API returned no text content')
    }

    console.log(`[Anthropic] Usage: ${data.usage.input_tokens + data.usage.output_tokens} tokens`)
    return textContent.text
  }

  /**
   * Makes an API call for study guide generation with optimized parameters.
   * 
   * @param systemMessage - System prompt
   * @param userMessage - User prompt
   * @param languageConfig - Language-specific configuration
   * @param params - Generation parameters
   * @returns Response content string
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
      messages: [
        { role: 'user', content: userMessage }
      ]
    }

    console.log(`[Anthropic] Calling API with request:`, {
      model: request.model,
      max_tokens: request.max_tokens,
      temperature: request.temperature,
      messageLength: request.messages[0].content.length,
      systemMessageLength: request.system?.length || 0
    })

    const response = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'x-api-key': this.apiKey,
        'Content-Type': 'application/json',
        'anthropic-version': this.apiVersion
      },
      body: JSON.stringify(request)
    })

    console.log(`[Anthropic] API response status: ${response.status}`)

    if (!response.ok) {
      const errorText = await response.text()
      console.error(`[Anthropic] API error details:`, {
        status: response.status,
        statusText: response.statusText,
        headers: Object.fromEntries(response.headers.entries()),
        errorBody: errorText,
        timestamp: new Date().toISOString()
      })
      throw new Error(`Anthropic API error (${response.status}): ${errorText}`)
    }

    const data: AnthropicResponse = await response.json()
    
    if (!data.content || data.content.length === 0) {
      throw new Error('Anthropic API returned no content')
    }

    const textContent = data.content.find(c => c.type === 'text')
    if (!textContent) {
      throw new Error('Anthropic API returned no text content')
    }

    console.log(`[Anthropic] Study guide usage: ${data.usage.input_tokens + data.usage.output_tokens} tokens`)
    return textContent.text
  }

  /**
   * Makes an API call for verse generation.
   * 
   * @param systemMessage - System prompt
   * @param userMessage - User prompt
   * @returns Response content string
   */
  async callForVerse(systemMessage: string, userMessage: string): Promise<string> {
    const request: AnthropicRequest = {
      model: 'claude-sonnet-4-20250514',
      max_tokens: 800,
      temperature: 0.2,
      system: systemMessage,
      messages: [
        { role: 'user', content: userMessage }
      ]
    }

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

    const data: AnthropicResponse = await response.json()
    
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
   * Makes an API call for follow-up responses.
   * 
   * @param systemMessage - System prompt
   * @param userMessage - User prompt
   * @param language - Target language
   * @returns Response content string
   */
  async callForFollowUp(systemMessage: string, userMessage: string, language: string): Promise<string> {
    const model = language === 'en' ? 'claude-haiku-4-5-20250514' : 'claude-sonnet-4-20250514'

    const request: AnthropicRequest = {
      model,
      max_tokens: 800,
      temperature: 0.4,
      system: systemMessage,
      messages: [
        { role: 'user', content: userMessage }
      ]
    }

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

    const data: AnthropicResponse = await response.json()
    
    if (!data.content || data.content.length === 0) {
      throw new Error('Anthropic API returned no content')
    }

    const textContent = data.content.find(c => c.type === 'text')
    if (!textContent) {
      throw new Error('Anthropic API returned no text content')
    }

    return textContent.text
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
