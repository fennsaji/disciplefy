/**
 * LLM Service - Main Orchestrator
 * 
 * Provides a unified interface for LLM-powered content generation.
 * Supports multiple providers (OpenAI, Anthropic) with automatic fallback.
 * 
 * Features:
 * - Study guide generation
 * - Daily verse generation  
 * - Follow-up responses
 * - Provider fallback on failure
 * - Language-specific optimizations
 */

import type {
  LLMServiceConfig,
  LLMGenerationParams,
  LLMResponse,
  DailyVerseResponse,
  LLMProvider,
  LanguageConfig,
  LLMUsageMetadata,
  LLMResponseWithUsage
} from './llm-types.ts'
import { CostTrackingContext } from './llm-types.ts'

// Import extracted modules
import { OpenAIClient, isValidOpenAIKey } from './llm-clients/openai-client.ts'
import { AnthropicClient, isValidAnthropicKey } from './llm-clients/anthropic-client.ts'
import {
  getLanguageConfig,
  getLanguageConfigOrDefault,
  isLanguageSupported,
  getSupportedLanguages,
  getLanguageCount
} from './llm-config/language-configs.ts'
import {
  createStudyGuidePrompt,
  createVerseReferencePrompt,
  createFullVersePrompt
} from './llm-utils/prompt-builder.ts'
import {
  cleanJSONResponse,
  repairTruncatedJSON,
  validateStudyGuideResponse,
  sanitizeStudyGuideResponse,
  sanitizeMarkdownText,
  parseVerseReferenceResponse,
  parseFullVerseResponse
} from './llm-utils/response-parser.ts'
import {
  validateInputSecurity,
  sanitizeInput,
  determineAction
} from './llm-utils/security-validator.ts'
import {
  logPromptInjectionAttempt,
  logJailbreakAttempt,
  logInputValidationFailure
} from './llm-utils/security-logger.ts'

// Re-export types for external use
export type { LLMServiceConfig } from './llm-types.ts'

/**
 * Service for generating Bible study content using Large Language Models.
 * 
 * This service handles LLM integration with provider selection and fallback.
 * Supports OpenAI GPT and Anthropic Claude APIs with proper error handling.
 */
export class LLMService {
  private readonly provider: LLMProvider
  private readonly useMockData: boolean
  private readonly availableProviders: Set<LLMProvider>
  private openaiClient: OpenAIClient | null = null
  private anthropicClient: AnthropicClient | null = null
  private readonly supabaseClient: any | null = null

  constructor(private readonly config: LLMServiceConfig) {
    this.supabaseClient = config.supabaseClient || null
    this.availableProviders = new Set()
    this.useMockData = config.useMock

    if (this.useMockData) {
      console.log('[LLM] Using mock data mode')
      this.provider = 'openai'
      this.availableProviders.add('openai')
      this.availableProviders.add('anthropic')
      return
    }

    // Check which providers are available (but don't initialize clients yet - lazy load)
    console.log('[LLM] Configuration check:', {
      hasOpenAI: !!config.openaiApiKey,
      hasAnthropic: !!config.anthropicApiKey,
      openaiKeyLength: config.openaiApiKey?.length || 0,
      anthropicKeyLength: config.anthropicApiKey?.length || 0
    })

    if (isValidOpenAIKey(config.openaiApiKey)) {
      this.availableProviders.add('openai')
      console.log('[LLM] OpenAI provider available (will initialize on first use)')
    }

    if (isValidAnthropicKey(config.anthropicApiKey)) {
      this.availableProviders.add('anthropic')
      console.log('[LLM] Anthropic provider available (will initialize on first use)')
    }

    if (this.availableProviders.size === 0) {
      throw new Error('No LLM providers available. Please configure OPENAI_API_KEY or ANTHROPIC_API_KEY')
    }

    // Set primary provider
    // v3.3: Prefer Anthropic (Claude Sonnet 4.5) by default for better length compliance
    if (config.provider && this.availableProviders.has(config.provider)) {
      this.provider = config.provider
    } else {
      this.provider = this.availableProviders.has('anthropic') ? 'anthropic' : 'openai'
    }

    console.log(`[LLM] Initialized with primary provider: ${this.provider}`)
    console.log(`[LLM] Available providers: ${Array.from(this.availableProviders).join(', ')}`)
    console.log(`[LLM] Language configs loaded: ${getLanguageCount()}`)
  }

  /**
   * Lazy-load OpenAI client on first use
   */
  private getOpenAIClient(): OpenAIClient {
    if (!this.openaiClient) {
      if (!isValidOpenAIKey(this.config.openaiApiKey)) {
        throw new Error('OpenAI API key not configured')
      }
      console.log('[LLM] Lazy-initializing OpenAI client...')
      this.openaiClient = new OpenAIClient({ apiKey: this.config.openaiApiKey! })
      console.log('[LLM] OpenAI client initialized')
    }
    return this.openaiClient
  }

  /**
   * Lazy-load Anthropic client on first use
   */
  private getAnthropicClient(): AnthropicClient {
    if (!this.anthropicClient) {
      if (!isValidAnthropicKey(this.config.anthropicApiKey)) {
        throw new Error('Anthropic API key not configured')
      }
      console.log('[LLM] Lazy-initializing Anthropic client...')
      this.anthropicClient = new AnthropicClient({ apiKey: this.config.anthropicApiKey! })
      console.log('[LLM] Anthropic client initialized')
    }
    return this.anthropicClient
  }

  /**
   * Generates a Bible study guide using LLM.
   */
  async generateStudyGuide(params: LLMGenerationParams): Promise<LLMResponse> {
    this.validateParams(params)
    console.log(`[LLM] Generating study guide for ${params.inputType}: ${params.inputValue}`)

    if (this.useMockData) {
      return this.getMockStudyGuide()
    }

    return await this.generateWithLLM(params)
  }

  /**
   * Streams study guide generation, yielding raw text chunks.
   *
   * This is an async generator that yields raw text chunks from the LLM.
   * The caller is responsible for parsing these chunks into sections
   * using the StreamingJsonParser.
   *
   * @param params - Generation parameters (input type, value, language, tier)
   * @yields Raw text chunks from the LLM stream
   * @returns Usage metadata from the LLM API
   * @throws Error if mock mode is enabled or no provider is available
   */
  async *streamStudyGuide(
    params: LLMGenerationParams
  ): AsyncGenerator<string, LLMUsageMetadata, unknown> {
    this.validateParams(params)
    console.log(`[LLM] Starting streaming study guide for ${params.inputType}: ${params.inputValue}`)

    if (this.useMockData) {
      yield* this.streamMockStudyGuide()
      return {
        provider: 'openai',
        model: 'gpt-4o-mini-2024-07-18',
        inputTokens: 100,
        outputTokens: 500,
        totalTokens: 600,
        costUsd: 0.0001
      }
    }

    const languageConfig = getLanguageConfigOrDefault(params.language)
    const prompt = createStudyGuidePrompt(params, languageConfig)
    const selectedProvider = params.forceProvider || this.selectOptimalProvider(params.language)

    console.log(`[LLM] Streaming with ${selectedProvider} API for language: ${languageConfig.name}${params.forceProvider ? ' (forced)' : ''}`)

    try {
      if (selectedProvider === 'openai') {
        const generator = this.getOpenAIClient().streamStudyGuide(
          prompt.systemMessage,
          prompt.userMessage,
          languageConfig,
          params
        )
        // Manually iterate to capture return value
        let usage: LLMUsageMetadata | undefined
        while (true) {
          const result = await generator.next()
          if (result.done) {
            usage = result.value
            break
          }
          yield result.value
        }
        return usage!
      } else if (selectedProvider === 'anthropic') {
        const generator = this.getAnthropicClient().streamStudyGuide(
          prompt.systemMessage,
          prompt.userMessage,
          languageConfig,
          params
        )
        // Manually iterate to capture return value
        let usage: LLMUsageMetadata | undefined
        while (true) {
          const result = await generator.next()
          if (result.done) {
            usage = result.value
            break
          }
          yield result.value
        }
        return usage!
      } else {
        throw new Error(`No streaming client available for provider: ${selectedProvider}`)
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error)
      const isContentFilter = errorMsg.includes('CONTENT_FILTER')

      if (isContentFilter) {
        console.warn(`[LLM] ⚠️ Content filter triggered by ${selectedProvider} - will retry with fallback`)
      } else {
        console.error(`[LLM] Streaming failed with ${selectedProvider}:`, error)
      }

      // Re-throw error to let caller handle parser reset and retry
      throw error
    }
  }

  /**
   * Calls LLM for a single sermon pass with a custom prompt.
   * Used for progressive multi-pass generation to avoid timeout.
   *
   * @param prompt - The prompt pair (systemMessage and userMessage)
   * @param params - Generation parameters
   * @returns Raw LLM response as string (JSON)
   */
  /**
   * Streams a multi-pass generation using a custom prompt pair.
   * This allows progressive emission of sections during each pass instead of blocking.
   *
   * @param prompt - Custom prompt pair for this pass
   * @param params - Generation parameters
   * @yields Raw text chunks from the LLM stream
   * @returns Usage metadata from the LLM API
   */
  async *streamFromPrompt(
    prompt: { systemMessage: string; userMessage: string },
    params: LLMGenerationParams
  ): AsyncGenerator<string, LLMUsageMetadata, unknown> {
    this.validateParams(params)

    if (this.useMockData) {
      yield* this.streamMockStudyGuide()
      return {
        provider: 'openai',
        model: 'gpt-4o-mini-2024-07-18',
        inputTokens: 100,
        outputTokens: 500,
        totalTokens: 600,
        costUsd: 0.0001
      }
    }

    const languageConfig = getLanguageConfigOrDefault(params.language)
    const selectedProvider = params.forceProvider || this.selectOptimalProvider(params.language)

    console.log(`[LLM-StreamPass] Streaming with ${selectedProvider} for language: ${languageConfig.name}`)

    try {
      if (selectedProvider === 'openai') {
        // For multi-pass, disable schema enforcement - let prompt define JSON structure
        const generator = this.getOpenAIClient().streamStudyGuide(
          prompt.systemMessage,
          prompt.userMessage,
          languageConfig,
          params,
          false // useSchema = false for multi-pass prompts
        )
        // Manually iterate to capture return value
        let usage: LLMUsageMetadata | undefined
        while (true) {
          const result = await generator.next()
          if (result.done) {
            usage = result.value
            break
          }
          yield result.value
        }
        return usage!
      } else if (selectedProvider === 'anthropic') {
        const generator = this.getAnthropicClient().streamStudyGuide(
          prompt.systemMessage,
          prompt.userMessage,
          languageConfig,
          params
        )
        // Manually iterate to capture return value
        let usage: LLMUsageMetadata | undefined
        while (true) {
          const result = await generator.next()
          if (result.done) {
            usage = result.value
            break
          }
          yield result.value
        }
        return usage!
      } else {
        throw new Error(`No client available for provider: ${selectedProvider}`)
      }
    } catch (error) {
      console.error(`[LLM-StreamPass] ❌ Streaming failed with ${selectedProvider}:`, error)
      throw error
    }
  }

  /**
   * Non-streaming multi-pass call (DEPRECATED - use streamFromPrompt for better UX).
   * Blocks until entire pass completes, then returns complete JSON with usage.
   *
   * @param prompt - The prompt pair (systemMessage and userMessage)
   * @param params - Generation parameters
   * @returns Response with content and usage metadata
   */
  async callForSermonPass(
    prompt: { systemMessage: string; userMessage: string },
    params: LLMGenerationParams
  ): Promise<LLMResponseWithUsage<string>> {
    this.validateParams(params)

    if (this.useMockData) {
      return {
        content: JSON.stringify(this.getMockStudyGuide()),
        usage: {
          provider: 'openai',
          model: 'gpt-4o-mini-2024-07-18',
          inputTokens: 100,
          outputTokens: 500,
          totalTokens: 600,
          costUsd: 0.0001
        }
      }
    }

    const languageConfig = getLanguageConfigOrDefault(params.language)
    const selectedProvider = params.forceProvider || this.selectOptimalProvider(params.language)

    console.log(`[LLM-SermonPass] Calling ${selectedProvider} for language: ${languageConfig.name}`)

    try {
      if (selectedProvider === 'openai') {
        // Disable JSON schema for multi-pass - prompts define custom field names
        return await this.getOpenAIClient().callForStudyGuide(
          prompt.systemMessage,
          prompt.userMessage,
          languageConfig,
          params,
          false  // useSchema = false for multi-pass
        )
      } else if (selectedProvider === 'anthropic') {
        return await this.getAnthropicClient().callForStudyGuide(
          prompt.systemMessage,
          prompt.userMessage,
          languageConfig,
          params
        )
      } else {
        throw new Error(`No client available for provider: ${selectedProvider}`)
      }
    } catch (error) {
      console.error(`[LLM-SermonPass] ❌ Call failed with ${selectedProvider}:`, error)
      throw error
    }
  }

  /**
   * Generates a sermon using multi-pass approach to work within token limits.
   * Breaks sermon generation into 4 passes:
   * - Pass 1: Summary + Context + Interpretation (Intro + Point 1)
   * - Pass 2: Interpretation (Point 2)
   * - Pass 3: Interpretation (Point 3)
   * - Pass 4: Conclusion + Altar Call + Supporting Fields
   *
   * This helps Hindi/Malayalam sermons achieve better word counts despite token inefficiency.
   *
   * @returns Sermon data with aggregated usage metadata
   */
  async generateSermonMultiPass(params: LLMGenerationParams): Promise<{ sermon: Record<string, unknown>, usage: LLMUsageMetadata }> {
    this.validateParams(params)
    console.log(`[LLM-MultiPass] Starting 4-pass sermon generation for ${params.inputType}: ${params.inputValue}`)

    if (this.useMockData) {
      const mockSermon = this.getMockStudyGuide() as unknown as Record<string, unknown>
      const mockUsage: LLMUsageMetadata = {
        provider: 'openai',
        model: 'gpt-4o-mini-2024-07-18',
        inputTokens: 400,
        outputTokens: 2000,
        totalTokens: 2400,
        costUsd: 0.0004
      }
      return { sermon: mockSermon, usage: mockUsage }
    }

    const languageConfig = getLanguageConfigOrDefault(params.language)
    const selectedProvider = params.forceProvider || this.selectOptimalProvider(params.language)
    console.log(`[LLM-MultiPass] Using ${selectedProvider} for all passes`)

    // Initialize cost tracking context
    const costContext = new CostTrackingContext()

    // Import multi-pass utilities
    const {
      createSermonPass1Prompt,
      createSermonPass2Prompt,
      createSermonPass3Prompt,
      createSermonPass4Prompt,
      combineSermonPasses
    } = await import('./llm-utils/sermon-multipass.ts')

    try {
      // PASS 1: Summary + Context + Interpretation Part 1
      console.log(`[LLM-MultiPass] 🔄 Starting Pass 1/4 (Summary + Context + Intro + Point 1)`)
      const pass1Prompt = createSermonPass1Prompt(params, languageConfig)
      const pass1Result = selectedProvider === 'openai'
        ? await this.getOpenAIClient().callForStudyGuide(
            pass1Prompt.systemMessage,
            pass1Prompt.userMessage,
            languageConfig,
            params
          )
        : await this.getAnthropicClient().callForStudyGuide(
            pass1Prompt.systemMessage,
            pass1Prompt.userMessage,
            languageConfig,
            params
          )

      costContext.addCall(pass1Result.usage)
      const pass1Data = JSON.parse(cleanJSONResponse(pass1Result.content))
      console.log(`[LLM-MultiPass] ✅ Pass 1 complete: ${pass1Result.content.length} chars, ${pass1Result.usage.totalTokens} tokens`)

      // PASS 2: Interpretation Part 2 (Point 2)
      console.log(`[LLM-MultiPass] 🔄 Starting Pass 2/4 (Point 2)`)
      const pass2Prompt = createSermonPass2Prompt(params, languageConfig, pass1Data)
      const pass2Result = selectedProvider === 'openai'
        ? await this.getOpenAIClient().callForStudyGuide(
            pass2Prompt.systemMessage,
            pass2Prompt.userMessage,
            languageConfig,
            params
          )
        : await this.getAnthropicClient().callForStudyGuide(
            pass2Prompt.systemMessage,
            pass2Prompt.userMessage,
            languageConfig,
            params
          )

      costContext.addCall(pass2Result.usage)
      const pass2Data = JSON.parse(cleanJSONResponse(pass2Result.content))
      console.log(`[LLM-MultiPass] ✅ Pass 2 complete: ${pass2Result.content.length} chars, ${pass2Result.usage.totalTokens} tokens`)

      // PASS 3: Interpretation Part 3 (Point 3)
      console.log(`[LLM-MultiPass] 🔄 Starting Pass 3/4 (Point 3)`)
      const pass3Prompt = createSermonPass3Prompt(params, languageConfig, pass1Data, pass2Data)
      const pass3Result = selectedProvider === 'openai'
        ? await this.getOpenAIClient().callForStudyGuide(
            pass3Prompt.systemMessage,
            pass3Prompt.userMessage,
            languageConfig,
            params
          )
        : await this.getAnthropicClient().callForStudyGuide(
            pass3Prompt.systemMessage,
            pass3Prompt.userMessage,
            languageConfig,
            params
          )

      costContext.addCall(pass3Result.usage)
      const pass3Data = JSON.parse(cleanJSONResponse(pass3Result.content))
      console.log(`[LLM-MultiPass] ✅ Pass 3 complete: ${pass3Result.content.length} chars, ${pass3Result.usage.totalTokens} tokens`)

      // PASS 4: Conclusion + Altar Call + Supporting Fields
      console.log(`[LLM-MultiPass] 🔄 Starting Pass 4/4 (Conclusion + Altar Call + Extras)`)
      const pass4Prompt = createSermonPass4Prompt(params, languageConfig, pass1Data)
      const pass4Result = selectedProvider === 'openai'
        ? await this.getOpenAIClient().callForStudyGuide(
            pass4Prompt.systemMessage,
            pass4Prompt.userMessage,
            languageConfig,
            params
          )
        : await this.getAnthropicClient().callForStudyGuide(
            pass4Prompt.systemMessage,
            pass4Prompt.userMessage,
            languageConfig,
            params
          )

      costContext.addCall(pass4Result.usage)
      const pass4Data = JSON.parse(cleanJSONResponse(pass4Result.content))
      console.log(`[LLM-MultiPass] ✅ Pass 4 complete: ${pass4Result.content.length} chars, ${pass4Result.usage.totalTokens} tokens`)

      // Combine all passes into complete sermon
      const completeSermon = combineSermonPasses(pass1Data, pass2Data, pass3Data, pass4Data)

      // Get aggregated usage
      const aggregateUsage = costContext.getAggregate()
      console.log(`[LLM-MultiPass] 🎉 Sermon generation complete!`)
      console.log(`[LLM-MultiPass] Total interpretation: ${completeSermon.interpretation?.toString().length || 0} chars`)
      console.log(`[LLM-MultiPass] Total tokens: ${aggregateUsage.totalTokens} (${aggregateUsage.inputTokens} input + ${aggregateUsage.outputTokens} output)`)
      console.log(`[LLM-MultiPass] Total cost: $${aggregateUsage.costUsd.toFixed(4)}`)

      return { sermon: completeSermon, usage: aggregateUsage }

    } catch (error) {
      console.error(`[LLM-MultiPass] ❌ Multi-pass generation failed:`, error)
      throw new Error(`Multi-pass sermon generation failed: ${error instanceof Error ? error.message : String(error)}`)
    }
  }

  /**
   * Generates a follow-up response for study guide questions.
   *
   * @returns Response text with usage metadata
   */
  async generateFollowUpResponse(
    prompt: { systemMessage: string; userMessage: string },
    language: string
  ): Promise<{ response: string, usage: LLMUsageMetadata }> {
    console.log(`[LLM] Generating follow-up response for language: ${language}`)

    if (this.useMockData) {
      const mockResponse = this.getMockFollowUpResponse(prompt.userMessage, language)
      const mockUsage: LLMUsageMetadata = {
        provider: 'anthropic',
        model: 'claude-sonnet-4-5-20250929',
        inputTokens: 50,
        outputTokens: 150,
        totalTokens: 200,
        costUsd: 0.0001
      }
      return { response: mockResponse, usage: mockUsage }
    }

    try {
      const selectedProvider = this.selectOptimalProvider(language)
      console.log(`[LLM] Selected ${selectedProvider} for follow-up response`)

      let result: LLMResponseWithUsage<string>

      if (selectedProvider === 'openai') {
        result = await this.getOpenAIClient().callForFollowUp(prompt.systemMessage, prompt.userMessage)
      } else {
        result = await this.getAnthropicClient().callForFollowUp(prompt.systemMessage, prompt.userMessage, language)
      }

      const sanitizedResponse = sanitizeMarkdownText(result.content)
      console.log(`[LLM] Follow-up response generated: ${sanitizedResponse.length} characters`)
      console.log(`[LLM] Usage: ${result.usage.totalTokens} tokens (cost: $${result.usage.costUsd.toFixed(4)})`)

      return { response: sanitizedResponse, usage: result.usage }

    } catch (error) {
      console.error(`[LLM] Follow-up response generation failed:`, error)
      throw new Error(`Follow-up generation failed: ${error instanceof Error ? error.message : String(error)}`)
    }
  }

  /**
   * Analyzes the sentiment of a message and returns a score.
   *
   * @param message - The feedback message to analyze
   * @returns Sentiment score from -1.0 (very negative) to 1.0 (very positive)
   */
  async analyzeSentiment(message: string): Promise<number> {
    console.log(`[LLM] Analyzing sentiment for message: "${message.substring(0, 50)}..."`)

    if (this.useMockData) {
      // Return a random sentiment for mock mode
      return Math.random() * 2 - 1
    }

    if (!message || message.trim().length === 0) {
      console.log('[LLM] Empty message, returning neutral sentiment')
      return 0
    }

    try {
      const systemPrompt = `You are a sentiment analysis expert. Analyze the sentiment of user feedback messages and return ONLY a single number between -1.0 and 1.0.

Score interpretation:
- 1.0: Very positive (enthusiastic, grateful, highly satisfied)
- 0.5: Positive (satisfied, pleased)
- 0.0: Neutral (factual, no clear emotion)
- -0.5: Negative (disappointed, frustrated)
- -1.0: Very negative (angry, very dissatisfied)

Return ONLY the numeric score, nothing else.`

      const userPrompt = `Analyze this feedback message and return its sentiment score:\n\n"${message}"`

      // Use the faster Anthropic Haiku model for sentiment analysis (cheaper and faster)
      const selectedProvider = this.provider === 'anthropic' && this.availableProviders.has('anthropic')
        ? 'anthropic'
        : this.selectOptimalProvider('en')

      let result: LLMResponseWithUsage<string>

      if (selectedProvider === 'anthropic') {
        const client = await this.getAnthropicClient()
        result = await client.call({
          systemMessage: systemPrompt,
          userMessage: userPrompt,
          temperature: 0.3,
          maxTokens: 10 // Low token count for just the numeric score
        })
      } else {
        const client = await this.getOpenAIClient()
        result = await client.call({
          systemMessage: systemPrompt,
          userMessage: userPrompt,
          temperature: 0.3,
          maxTokens: 10
        })
      }

      // Parse the response to extract the numeric score
      const scoreText = result.content.trim()
      const score = parseFloat(scoreText)

      if (isNaN(score) || score < -1.0 || score > 1.0) {
        console.warn(`[LLM] Invalid sentiment score: ${scoreText}, defaulting to 0`)
        return 0
      }

      console.log(`[LLM] Sentiment analysis complete: ${score} (${result.usage.totalTokens} tokens, $${result.usage.costUsd.toFixed(6)})`)
      return score

    } catch (error) {
      console.error(`[LLM] Sentiment analysis failed:`, error)
      // Return neutral sentiment on error rather than failing the feedback submission
      return 0
    }
  }

  /**
   * Generates a daily Bible verse with translations.
   */
  async generateDailyVerse(
    excludeReferences: string[] = [],
    language: string = 'en'
  ): Promise<DailyVerseResponse> {
    console.log(`[LLM] Generating daily verse, excluding: ${excludeReferences.join(', ')}`)

    if (this.useMockData) {
      return this.getMockDailyVerse()
    }

    try {
      // Import Bible API service dynamically
      const { fetchVerseAllLanguages } = await import('./bible-api-service.ts')

      // NOTE: No cache check here — caching is handled by DailyVerseService with the
      // correct per-date key. A cache here used new Date() (always today), which caused
      // all dates generated on the same day to return the same verse, bypassing exclusions.

      // Generate reference using LLM
      const prompt = createVerseReferencePrompt(excludeReferences, language)
      const selectedProvider = this.selectOptimalProvider(language)
      console.log(`[LLM] Selected ${selectedProvider} for verse reference generation`)

      let result: LLMResponseWithUsage<string>

      if (selectedProvider === 'openai') {
        result = await this.getOpenAIClient().callForVerse(prompt.systemMessage, prompt.userMessage)
      } else {
        result = await this.getAnthropicClient().callForVerse(prompt.systemMessage, prompt.userMessage)
      }

      const parsedReference = parseVerseReferenceResponse(result.content)
      console.log(`[LLM] LLM selected reference: ${parsedReference.reference}`)

      // Fetch verse text from Bible API
      const allVerses = await fetchVerseAllLanguages(parsedReference.reference)
      const hasAllTranslations = allVerses.en.text && allVerses.hi.text && allVerses.ml.text

      if (!hasAllTranslations) {
        console.warn(`[LLM] Bible API returned incomplete translations, falling back to LLM`)
        return this.generateDailyVerseLLMFallback(excludeReferences, language)
      }

      return {
        reference: parsedReference.reference,
        referenceTranslations: parsedReference.referenceTranslations,
        translations: {
          esv: allVerses.en.text,
          hi: allVerses.hi.text,
          ml: allVerses.ml.text,
        }
      }

    } catch (error) {
      console.error(`[LLM] Daily verse generation failed:`, error)
      return this.generateDailyVerseLLMFallback(excludeReferences, language)
    }
  }

  // ==================== Private Methods ====================

  private validateParams(params: LLMGenerationParams): void {
    // Basic validation
    if (!params.inputType || !['scripture', 'topic', 'question'].includes(params.inputType)) {
      throw new Error('Invalid input type')
    }
    if (!params.inputValue || typeof params.inputValue !== 'string') {
      throw new Error('Invalid input value')
    }
    if (!params.language || typeof params.language !== 'string') {
      throw new Error('Invalid language')
    }
    if (!isLanguageSupported(params.language)) {
      throw new Error(`Unsupported language: "${params.language}". Supported: ${getSupportedLanguages().join(', ')}`)
    }

    // Security validation
    const validation = validateInputSecurity(params.inputValue)

    if (!validation.isValid) {
      const action = determineAction(validation.riskScore)

      // Log security event if Supabase client is available
      if (this.supabaseClient) {
        const hasPromptInjection = validation.violations.some(
          v => v.type === 'prompt_injection' || v.type === 'instruction_override' || v.type === 'system_prompt_access'
        )
        const hasJailbreak = validation.violations.some(
          v => v.type === 'jailbreak_attempt'
        )

        const metadata = {
          inputLength: params.inputValue.length,
          actionTaken: action
        }

        if (hasPromptInjection) {
          logPromptInjectionAttempt(this.supabaseClient, validation, metadata)
        } else if (hasJailbreak) {
          logJailbreakAttempt(this.supabaseClient, validation, metadata)
        } else {
          logInputValidationFailure(this.supabaseClient, validation, metadata)
        }
      }

      // Block high-risk requests
      if (action === 'blocked') {
        console.error(`[LLM] Security validation failed - BLOCKED (risk: ${validation.riskScore.toFixed(2)})`, validation.violations)
        throw new Error('Input validation failed: potential security risk detected')
      }

      // Allow flagged requests but log them
      console.warn(`[LLM] Security validation flagged (risk: ${validation.riskScore.toFixed(2)})`, validation.violations)
    }
  }

  private async generateWithLLM(params: LLMGenerationParams): Promise<LLMResponse> {
    const languageConfig = getLanguageConfigOrDefault(params.language)
    const prompt = createStudyGuidePrompt(params, languageConfig)

    try {
      const selectedProvider = this.selectOptimalProvider(params.language)
      console.log(`[LLM] Selected ${selectedProvider} API for language: ${languageConfig.name}`)

      let result: LLMResponseWithUsage<string>

      try {
        result = await this.callProvider(selectedProvider, prompt, languageConfig, params)
      } catch (primaryError) {
        console.error(`[LLM] Primary provider ${selectedProvider} failed:`, primaryError)

        // Try fallback
        const fallbackProvider = this.getFallbackProvider(selectedProvider)
        if (fallbackProvider) {
          console.log(`[LLM] Using fallback provider: ${fallbackProvider}`)
          result = await this.callProvider(fallbackProvider, prompt, languageConfig, params)
        } else {
          throw primaryError
        }
      }

      console.log(`[LLM] Usage: ${result.usage.totalTokens} tokens (cost: $${result.usage.costUsd.toFixed(4)})`)

      // Parse and validate response
      const parsedResponse = await this.parseWithRetry(result.content, params, languageConfig)

      if (!validateStudyGuideResponse(parsedResponse)) {
        throw new Error('LLM response does not match expected structure')
      }

      const sanitizedResponse = sanitizeStudyGuideResponse(parsedResponse)
      console.log('[LLM] Successfully generated study guide')
      return sanitizedResponse

    } catch (error) {
      console.error(`[LLM] Generation failed:`, error)
      throw new Error(`LLM generation failed: ${error instanceof Error ? error.message : String(error)}`)
    }
  }

  private async callProvider(
    provider: LLMProvider,
    prompt: { systemMessage: string; userMessage: string },
    languageConfig: LanguageConfig,
    params: LLMGenerationParams
  ): Promise<LLMResponseWithUsage<string>> {
    if (provider === 'openai') {
      return this.getOpenAIClient().callForStudyGuide(prompt.systemMessage, prompt.userMessage, languageConfig, params)
    } else if (provider === 'anthropic') {
      return this.getAnthropicClient().callForStudyGuide(prompt.systemMessage, prompt.userMessage, languageConfig, params)
    }
    throw new Error(`Provider ${provider} not available`)
  }

  private selectOptimalProvider(language: string): LLMProvider {
    if (this.isProviderAvailable(this.provider)) {
      return this.provider
    }

    const languageConfig = getLanguageConfig(language)
    const preferredProvider = languageConfig?.modelPreference || this.provider

    if (this.isProviderAvailable(preferredProvider)) {
      return preferredProvider
    }

    return this.getAnyAvailableProvider()
  }

  private getFallbackProvider(primaryProvider: LLMProvider): LLMProvider | null {
    const fallback: LLMProvider = primaryProvider === 'openai' ? 'anthropic' : 'openai'
    return this.isProviderAvailable(fallback) ? fallback : null
  }

  private isProviderAvailable(provider: LLMProvider): boolean {
    return this.availableProviders.has(provider)
  }

  private getAnyAvailableProvider(): LLMProvider {
    if (this.availableProviders.has('anthropic')) return 'anthropic'
    if (this.availableProviders.has('openai')) return 'openai'
    throw new Error('No LLM providers available')
  }

  private async parseWithRetry(
    rawResponse: string,
    params: LLMGenerationParams,
    languageConfig: LanguageConfig,
    retryCount: number = 0
  ): Promise<Record<string, unknown>> {
    const maxRetries = 3

    try {
      const cleanedResponse = cleanJSONResponse(rawResponse)
      return JSON.parse(cleanedResponse)
    } catch (parseError) {
      console.error(`[LLM] JSON parse attempt ${retryCount + 1} failed`)

      if (retryCount < maxRetries) {
        console.log(`[LLM] Retrying with adjusted parameters`)

        const originalConfig = getLanguageConfigOrDefault(params.language)
        const adjustedConfig: LanguageConfig = {
          ...languageConfig,
          temperature: Math.max(0.1, originalConfig.temperature - (0.1 * (retryCount + 1))),
          maxTokens: originalConfig.maxTokens + (500 * (retryCount + 1))
        }

        const prompt = createStudyGuidePrompt(params, adjustedConfig)
        const selectedProvider = this.selectOptimalProvider(params.language)

        try {
          const retryResult = await this.callProvider(selectedProvider, prompt, adjustedConfig, params)
          return await this.parseWithRetry(retryResult.content, params, adjustedConfig, retryCount + 1)
        } catch (retryError) {
          if (retryCount === 0) {
            try {
              const repairedResponse = repairTruncatedJSON(rawResponse)
              return JSON.parse(repairedResponse)
            } catch {
              // Continue with retries
            }
          }

          if (retryCount >= maxRetries - 1) {
            throw new Error(`Failed to parse after ${maxRetries} attempts`)
          }

          return await this.parseWithRetry(rawResponse, params, languageConfig, retryCount + 1)
        }
      }

      throw new Error(`Failed to parse LLM response after ${maxRetries} attempts`)
    }
  }

  private async generateDailyVerseLLMFallback(
    excludeReferences: string[],
    language: string
  ): Promise<DailyVerseResponse> {
    try {
      const prompt = createFullVersePrompt(excludeReferences, language)
      const selectedProvider = this.selectOptimalProvider(language)

      let result: LLMResponseWithUsage<string>

      if (selectedProvider === 'openai') {
        result = await this.getOpenAIClient().callForVerse(prompt.systemMessage, prompt.userMessage)
      } else {
        result = await this.getAnthropicClient().callForVerse(prompt.systemMessage, prompt.userMessage)
      }

      return parseFullVerseResponse(result.content)
    } catch (error) {
      console.error(`[LLM] LLM fallback generation failed:`, error)
      return this.getMockDailyVerse()
    }
  }

  // ==================== Mock Data ====================

  /**
   * Streams the mock study guide in small, variable-size chunks with variable
   * delays — matching the token-by-token behaviour of a real LLM stream.
   *
   * Chunk sizes (1–8 chars) and delays (5–20 ms for content, 25–45 ms after
   * structural boundaries) are randomised so the streaming JSON parser is
   * exercised with splits across field names, string values, and delimiters.
   */
  private async *streamMockStudyGuide(): AsyncGenerator<string> {
    const mockJson = JSON.stringify(this.getMockStudyGuide(), null, 2)
    let i = 0
    while (i < mockJson.length) {
      // Token-like chunk: 1–8 chars
      const chunkSize = Math.floor(Math.random() * 8) + 1
      yield mockJson.slice(i, i + chunkSize)
      i += chunkSize

      // Longer pause after structural boundaries to mimic LLM "thinking"
      const tail = mockJson.slice(Math.max(0, i - 3), i)
      const atBoundary = /[,\[{]\s*$/.test(tail) || /}\s*$/.test(tail)
      const delay = atBoundary
        ? Math.random() * 20 + 25   // 25–45 ms between fields / structures
        : Math.random() * 15 + 5    // 5–20 ms for regular content
      await new Promise(resolve => setTimeout(resolve, delay))
    }
  }

  private getMockStudyGuide(): LLMResponse {
    return {
      summary: "This passage reveals God's profound love for humanity and His plan for salvation through Jesus Christ.",
      context: "Written during a period of spiritual awakening, this passage addresses fundamental questions about faith and redemption.",
      passage: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life. For God did not send his Son into the world to condemn the world, but in order that the world might be saved through him. Whoever believes in him is not condemned, but whoever does not believe is condemned already, because he has not believed in the name of the only Son of God. (John 3:16-18)",
      interpretation: "The theological significance of this text lies in its demonstration of God's unconditional love. It teaches us that salvation is available to all who believe.",
      relatedVerses: ["Romans 8:28", "Jeremiah 29:11", "Philippians 4:13"],
      reflectionQuestions: [
        "How does this passage speak to your current situation?",
        "What practical steps can you take to apply this teaching?",
        "How can you share this truth with others?"
      ],
      prayerPoints: [
        "Thank God for His unfailing love",
        "Ask for wisdom to understand His Word",
        "Pray for opportunities to share this message"
      ],
      interpretationInsights: [
        "God's love is unconditional and universal",
        "Salvation requires faith and trust in Christ",
        "Divine grace transforms our understanding"
      ],
      summaryInsights: [
        "Divine love manifested through sacrifice",
        "Universal offer of eternal life",
        "Faith as the path to redemption"
      ],
      reflectionAnswers: [
        "Strengthen my daily prayer practice",
        "Share God's love with those around me",
        "Trust God's plan in difficult times"
      ],
      contextQuestion: "Does this historical context change how you view God's timing?",
      summaryQuestion: "What aspect of God's love resonates most with you today?",
      relatedVersesQuestion: "Which of these verses speaks to your current journey?",
      reflectionQuestion: "How will you apply this truth in your daily walk?",
      prayerQuestion: "What would you like to tell God right now?"
    }
  }

  private getMockDailyVerse(): DailyVerseResponse {
    const mockVerses = [
      {
        reference: "John 3:16",
        referenceTranslations: { en: "John 3:16", hi: "यूहन्ना 3:16", ml: "യോഹന്നാൻ 3:16" },
        translations: {
          esv: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
          hi: "क्योंकि परमेश्वर ने जगत से ऐसा प्रेम रखा कि उसने अपना एकलौता पुत्र दे दिया।",
          ml: "കാരണം ദൈവം ലോകത്തെ ഇങ്ങനെ സ്നേഹിച്ചു, തന്റെ ഏകജാതനായ പുത്രനെ നൽകി."
        }
      },
      {
        reference: "Philippians 4:13",
        referenceTranslations: { en: "Philippians 4:13", hi: "फिलिप्पियों 4:13", ml: "ഫിലിപ്പിയർ 4:13" },
        translations: {
          esv: "I can do all things through him who strengthens me.",
          hi: "मैं उसके द्वारा जो मुझे सामर्थ्य देता है, सब कुछ कर सकता हूँ।",
          ml: "എന്നെ ബലപ്പെടുത്തുന്ന ക്രിസ്തുവിൽ എനിക്കു സകലവും ചെയ്വാൻ കഴിയും."
        }
      }
    ]

    const index = Math.floor(Date.now() / (1000 * 60 * 60 * 24)) % mockVerses.length
    return mockVerses[index]
  }

  private getMockFollowUpResponse(question: string, language: string): string {
    const responses: Record<string, string> = {
      en: `Thank you for your thoughtful question about "${question}". Based on the study guide content, this relates to the key themes we've explored.`,
      hi: `"${question}" के बारे में आपका सवाल बहुत अच्छा है। इस अध्ययन गाइड में जो मुख्य बातें हैं, वे इस विषय से जुड़ी हैं।`,
      ml: `"${question}" എന്ന നിങ്ങളുടെ ചോദ്യം വളരെ നല്ലതാണ്. ഈ പഠന ഗൈഡിലെ പ്രധാന വിഷയങ്ങൾ ഇതുമായി ബന്ധപ്പെട്ടിരിക്കുന്നു.`
    }
    return responses[language] || responses.en
  }
}
