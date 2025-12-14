/**
 * Type definitions for LLM Service
 * 
 * Contains all interfaces and types used by the LLM service for study guide generation,
 * daily verse retrieval, and provider-specific API interactions.
 */

// Declare Deno types for Supabase Edge Functions environment
declare const Deno: {
  env: {
    get(key: string): string | undefined
  }
}

/**
 * LLM service configuration interface
 */
export interface LLMServiceConfig {
  readonly openaiApiKey?: string
  readonly anthropicApiKey?: string
  readonly provider?: 'openai' | 'anthropic'
  readonly useMock: boolean
}

/**
 * Parameters for LLM study guide generation.
 */
export interface LLMGenerationParams {
  readonly inputType: 'scripture' | 'topic' | 'question'
  readonly inputValue: string
  readonly topicDescription?: string  // Optional: provides additional context for topic-based guides
  readonly language: string
  readonly tier?: string  // Optional: user subscription tier for model selection
}

/**
 * LLM response structure (matches expected format).
 */
export interface LLMResponse {
  readonly summary: string
  readonly interpretation: string // Optional field for additional context
  readonly context: string
  readonly relatedVerses: readonly string[]
  readonly reflectionQuestions: readonly string[]
  readonly prayerPoints: readonly string[]
}

/**
 * Daily verse generation response structure.
 * Uses consistent 'hi'/'ml' keys for Hindi/Malayalam translations.
 */
export interface DailyVerseResponse {
  readonly reference: string
  readonly referenceTranslations: {
    readonly en: string
    readonly hi: string
    readonly ml: string
  }
  readonly translations: {
    readonly esv: string
    readonly hi: string
    readonly ml: string
  }
}

/**
 * OpenAI ChatCompletion API request structure.
 */
export interface OpenAIRequest {
  model: string
  messages: Array<{
    role: 'system' | 'user' | 'assistant'
    content: string
  }>
  temperature: number
  max_tokens: number
  presence_penalty?: number
  frequency_penalty?: number
  response_format?: { type: 'json_object' }
  stream?: boolean
}

/**
 * OpenAI ChatCompletion API response structure.
 */
export interface OpenAIResponse {
  choices: Array<{
    message: {
      content: string
      role: string
    }
    finish_reason: string
  }>
  usage: {
    prompt_tokens: number
    completion_tokens: number
    total_tokens: number
  }
}

/**
 * Anthropic Claude API request structure.
 */
export interface AnthropicRequest {
  model: string
  max_tokens: number
  temperature: number
  top_p?: number
  top_k?: number
  messages: Array<{
    role: 'user' | 'assistant'
    content: string
  }>
  system?: string
}

/**
 * Anthropic Claude API response structure.
 */
export interface AnthropicResponse {
  content: Array<{
    type: 'text'
    text: string
  }>
  usage: {
    input_tokens: number
    output_tokens: number
  }
  stop_reason: string
}

/**
 * Supported LLM providers.
 */
export type LLMProvider = 'openai' | 'anthropic'

/**
 * Language-specific configuration for LLM generation.
 */
export interface LanguageConfig {
  readonly name: string
  readonly modelPreference: LLMProvider
  readonly maxTokens: number
  readonly temperature: number
  readonly promptModifiers: {
    readonly languageInstruction: string
    readonly complexityInstruction: string
  }
  readonly culturalContext: string
}
