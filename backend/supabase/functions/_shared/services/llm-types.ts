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
  readonly supabaseClient?: any  // Optional Supabase client for security event logging
}

/**
 * Study mode for different study guide experiences.
 * - quick: 3 min read - condensed key insight, verse, and reflection
 * - standard: 10 min read - full 6-section guide (default)
 * - deep: 25 min read - extended with word studies and cross-references
 * - lectio: 15 min - Lectio Divina meditative format
 */
export type StudyMode = 'quick' | 'standard' | 'deep' | 'lectio'

/**
 * Parameters for LLM study guide generation.
 */
export interface LLMGenerationParams {
  readonly inputType: 'scripture' | 'topic' | 'question'
  readonly inputValue: string
  readonly topicDescription?: string  // Optional: provides additional context for topic-based guides
  readonly language: string
  readonly tier?: string  // Optional: user subscription tier for model selection
  readonly studyMode?: StudyMode  // Optional: study mode for different experiences (default: 'standard')
  readonly forceProvider?: 'openai' | 'anthropic'  // Optional: force specific provider (used for retry/fallback)
}

/**
 * LLM response structure (matches expected format).
 * All 14 fields are required to ensure complete study guide generation.
 */
export interface LLMResponse {
  readonly summary: string
  readonly interpretation: string
  readonly context: string
  readonly relatedVerses: readonly string[]
  readonly reflectionQuestions: readonly string[]
  readonly prayerPoints: readonly string[]
  readonly interpretationInsights: readonly string[]  // 2-5 theological insights for Reflect Mode multi-select
  readonly summaryInsights: readonly string[]  // 2-5 resonance themes for Summary card (Quick/Lectio: 2-3, Standard/Deep: 3-5)
  readonly reflectionAnswers: readonly string[]  // 2-5 actionable life application responses for Reflection card (Quick/Lectio: 2-3, Standard/Deep: 3-5)
  readonly contextQuestion: string  // Yes/no question from historical context for Reflect Mode
  readonly summaryQuestion: string  // Engaging question about the summary (8-12 words)
  readonly relatedVersesQuestion: string  // Question prompting verse selection/memorization (8-12 words)
  readonly reflectionQuestion: string  // Question connecting study to daily life (8-12 words)
  readonly prayerQuestion: string  // Question inviting personal prayer response (6-10 words)
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
 * OpenAI JSON Schema structure for structured outputs.
 */
export interface OpenAIJsonSchema {
  name: string
  strict?: boolean
  schema: Record<string, unknown>
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
  response_format?: 
    | { type: 'json_object' } 
    | { type: 'json_schema'; json_schema: OpenAIJsonSchema }
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
