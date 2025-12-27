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
  LanguageConfig
} from './llm-types.ts'

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
  private readonly openaiClient: OpenAIClient | null = null
  private readonly anthropicClient: AnthropicClient | null = null

  constructor(private readonly config: LLMServiceConfig) {
    this.availableProviders = new Set()
    this.useMockData = config.useMock

    if (this.useMockData) {
      console.log('[LLM] Using mock data mode')
      this.provider = 'openai'
      this.availableProviders.add('openai')
      this.availableProviders.add('anthropic')
      return
    }

    // Initialize available providers
    console.log('[LLM] Configuration check:', {
      hasOpenAI: !!config.openaiApiKey,
      hasAnthropic: !!config.anthropicApiKey,
      openaiKeyLength: config.openaiApiKey?.length || 0,
      anthropicKeyLength: config.anthropicApiKey?.length || 0
    })

    if (isValidOpenAIKey(config.openaiApiKey)) {
      this.availableProviders.add('openai')
      this.openaiClient = new OpenAIClient({ apiKey: config.openaiApiKey! })
      console.log('[LLM] OpenAI provider initialized')
    }

    if (isValidAnthropicKey(config.anthropicApiKey)) {
      this.availableProviders.add('anthropic')
      this.anthropicClient = new AnthropicClient({ apiKey: config.anthropicApiKey! })
      console.log('[LLM] Anthropic provider initialized')
    }

    if (this.availableProviders.size === 0) {
      throw new Error('No LLM providers available. Please configure OPENAI_API_KEY or ANTHROPIC_API_KEY')
    }

    // Set primary provider
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
   * @throws Error if mock mode is enabled or no provider is available
   */
  async *streamStudyGuide(
    params: LLMGenerationParams
  ): AsyncGenerator<string, void, unknown> {
    this.validateParams(params)
    console.log(`[LLM] Starting streaming study guide for ${params.inputType}: ${params.inputValue}`)

    if (this.useMockData) {
      // Yield mock data in chunks for testing
      const mockGuide = this.getMockStudyGuide()
      const mockJson = JSON.stringify(mockGuide)
      const chunkSize = 50

      for (let i = 0; i < mockJson.length; i += chunkSize) {
        yield mockJson.slice(i, i + chunkSize)
        // Small delay to simulate streaming
        await new Promise(resolve => setTimeout(resolve, 50))
      }
      return
    }

    const languageConfig = getLanguageConfigOrDefault(params.language)
    const prompt = createStudyGuidePrompt(params, languageConfig)
    const selectedProvider = this.selectOptimalProvider(params.language)

    console.log(`[LLM] Streaming with ${selectedProvider} API for language: ${languageConfig.name}`)

    try {
      if (selectedProvider === 'openai' && this.openaiClient) {
        yield* this.openaiClient.streamStudyGuide(
          prompt.systemMessage,
          prompt.userMessage,
          languageConfig,
          params
        )
      } else if (selectedProvider === 'anthropic' && this.anthropicClient) {
        yield* this.anthropicClient.streamStudyGuide(
          prompt.systemMessage,
          prompt.userMessage,
          languageConfig,
          params
        )
      } else {
        throw new Error(`No streaming client available for provider: ${selectedProvider}`)
      }
    } catch (error) {
      console.error(`[LLM] Streaming failed with ${selectedProvider}:`, error)

      // Try fallback provider
      const fallbackProvider = this.getFallbackProvider(selectedProvider)
      if (fallbackProvider) {
        console.log(`[LLM] Attempting streaming with fallback provider: ${fallbackProvider}`)

        if (fallbackProvider === 'openai' && this.openaiClient) {
          yield* this.openaiClient.streamStudyGuide(
            prompt.systemMessage,
            prompt.userMessage,
            languageConfig,
            params
          )
        } else if (fallbackProvider === 'anthropic' && this.anthropicClient) {
          yield* this.anthropicClient.streamStudyGuide(
            prompt.systemMessage,
            prompt.userMessage,
            languageConfig,
            params
          )
        }
      } else {
        throw error
      }
    }
  }

  /**
   * Generates a follow-up response for study guide questions.
   */
  async generateFollowUpResponse(
    prompt: { systemMessage: string; userMessage: string },
    language: string
  ): Promise<string> {
    console.log(`[LLM] Generating follow-up response for language: ${language}`)

    if (this.useMockData) {
      return this.getMockFollowUpResponse(prompt.userMessage, language)
    }

    try {
      const selectedProvider = this.selectOptimalProvider(language)
      console.log(`[LLM] Selected ${selectedProvider} for follow-up response`)

      let rawResponse: string

      if (selectedProvider === 'openai' && this.openaiClient) {
        rawResponse = await this.openaiClient.callForFollowUp(prompt.systemMessage, prompt.userMessage)
      } else if (this.anthropicClient) {
        rawResponse = await this.anthropicClient.callForFollowUp(prompt.systemMessage, prompt.userMessage, language)
      } else {
        throw new Error('No client available for follow-up')
      }

      const sanitizedResponse = sanitizeMarkdownText(rawResponse)
      console.log(`[LLM] Follow-up response generated: ${sanitizedResponse.length} characters`)
      return sanitizedResponse

    } catch (error) {
      console.error(`[LLM] Follow-up response generation failed:`, error)
      throw new Error(`Follow-up generation failed: ${error instanceof Error ? error.message : String(error)}`)
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
      const { fetchVerseAllLanguages, getCachedVerses, cacheVerses } = await import('./bible-api-service.ts')

      // Check cache first
      const today = new Date()
      const cachedVerses = await getCachedVerses(today)

      if (cachedVerses) {
        console.log(`[LLM] Using cached verses from ${today.toISOString().split('T')[0]}`)
        return {
          reference: cachedVerses.en.reference,
          referenceTranslations: {
            en: cachedVerses.en.reference,
            hi: cachedVerses.hi.reference,
            ml: cachedVerses.ml.reference,
          },
          translations: {
            esv: cachedVerses.en.text,
            hi: cachedVerses.hi.text,
            ml: cachedVerses.ml.text,
          }
        }
      }

      // Generate reference using LLM
      const prompt = createVerseReferencePrompt(excludeReferences, language)
      const selectedProvider = this.selectOptimalProvider(language)
      console.log(`[LLM] Selected ${selectedProvider} for verse reference generation`)

      let rawResponse: string

      if (selectedProvider === 'openai' && this.openaiClient) {
        rawResponse = await this.openaiClient.callForVerse(prompt.systemMessage, prompt.userMessage)
      } else if (this.anthropicClient) {
        rawResponse = await this.anthropicClient.callForVerse(prompt.systemMessage, prompt.userMessage)
      } else {
        throw new Error('No client available for verse generation')
      }

      const parsedReference = parseVerseReferenceResponse(rawResponse)
      console.log(`[LLM] LLM selected reference: ${parsedReference.reference}`)

      // Fetch verse text from Bible API
      const allVerses = await fetchVerseAllLanguages(parsedReference.reference)
      const hasAllTranslations = allVerses.en.text && allVerses.hi.text && allVerses.ml.text

      if (!hasAllTranslations) {
        console.warn(`[LLM] Bible API returned incomplete translations, falling back to LLM`)
        return this.generateDailyVerseLLMFallback(excludeReferences, language)
      }

      await cacheVerses(allVerses, today)

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
  }

  private async generateWithLLM(params: LLMGenerationParams): Promise<LLMResponse> {
    const languageConfig = getLanguageConfigOrDefault(params.language)
    const prompt = createStudyGuidePrompt(params, languageConfig)

    try {
      const selectedProvider = this.selectOptimalProvider(params.language)
      console.log(`[LLM] Selected ${selectedProvider} API for language: ${languageConfig.name}`)

      let rawResponse: string

      try {
        rawResponse = await this.callProvider(selectedProvider, prompt, languageConfig, params)
      } catch (primaryError) {
        console.error(`[LLM] Primary provider ${selectedProvider} failed:`, primaryError)

        // Try fallback
        const fallbackProvider = this.getFallbackProvider(selectedProvider)
        if (fallbackProvider) {
          console.log(`[LLM] Using fallback provider: ${fallbackProvider}`)
          rawResponse = await this.callProvider(fallbackProvider, prompt, languageConfig, params)
        } else {
          throw primaryError
        }
      }

      // Parse and validate response
      const parsedResponse = await this.parseWithRetry(rawResponse, params, languageConfig)

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
  ): Promise<string> {
    if (provider === 'openai' && this.openaiClient) {
      return this.openaiClient.callForStudyGuide(prompt.systemMessage, prompt.userMessage, languageConfig, params)
    } else if (provider === 'anthropic' && this.anthropicClient) {
      return this.anthropicClient.callForStudyGuide(prompt.systemMessage, prompt.userMessage, languageConfig, params)
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
          const retryResponse = await this.callProvider(selectedProvider, prompt, adjustedConfig, params)
          return await this.parseWithRetry(retryResponse, params, adjustedConfig, retryCount + 1)
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

      let rawResponse: string

      if (selectedProvider === 'openai' && this.openaiClient) {
        rawResponse = await this.openaiClient.callForVerse(prompt.systemMessage, prompt.userMessage)
      } else if (this.anthropicClient) {
        rawResponse = await this.anthropicClient.callForVerse(prompt.systemMessage, prompt.userMessage)
      } else {
        throw new Error('No client available')
      }

      return parseFullVerseResponse(rawResponse)
    } catch (error) {
      console.error(`[LLM] LLM fallback generation failed:`, error)
      return this.getMockDailyVerse()
    }
  }

  // ==================== Mock Data ====================

  private getMockStudyGuide(): LLMResponse {
    return {
      summary: "This passage reveals God's profound love for humanity and His plan for salvation through Jesus Christ.",
      interpretation: "The theological significance of this text lies in its demonstration of God's unconditional love. It teaches us that salvation is available to all who believe.",
      context: "Written during a period of spiritual awakening, this passage addresses fundamental questions about faith and redemption.",
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
