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
interface LLMGenerationParams {
  readonly inputType: 'scripture' | 'topic'
  readonly inputValue: string
  readonly language: string
}

/**
 * LLM response structure (matches expected format).
 */
interface LLMResponse {
  readonly summary: string
  readonly interpretation: string // Optional field for additional context
  readonly context: string
  readonly relatedVerses: readonly string[]
  readonly reflectionQuestions: readonly string[]
  readonly prayerPoints: readonly string[]
}

/**
 * Daily verse generation response structure.
 */
interface DailyVerseResponse {
  readonly reference: string
  readonly translations: {
    readonly esv: string
    readonly hindi: string
    readonly malayalam: string
  }
}

/**
 * OpenAI ChatCompletion API request structure.
 */
interface OpenAIRequest {
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
interface OpenAIResponse {
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
interface AnthropicRequest {
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
interface AnthropicResponse {
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
type LLMProvider = 'openai' | 'anthropic'

/**
 * Language-specific configuration for LLM generation.
 */
interface LanguageConfig {
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

/**
 * Service for generating Bible study content using Large Language Models.
 * 
 * This service handles LLM integration with provider selection via environment variables.
 * Supports OpenAI GPT and Anthropic Claude APIs with proper error handling and validation.
 * Features language-specific configurations for optimal results in English, Hindi, and Malayalam.
 */
export class LLMService {
  private readonly provider: LLMProvider
  private readonly apiKey: string
  private readonly useMockData: boolean
  private readonly languageConfigs: Map<string, LanguageConfig>
  private readonly availableProviders: Set<LLMProvider>

  /**
   * Creates a new LLM service instance with dependency injection.
   * @param config - LLM service configuration from centralized config
   */
  constructor(private readonly config: LLMServiceConfig) {
    // Initialize language configurations
    this.languageConfigs = new Map()
    this.initializeLanguageConfigs()
    
    // Initialize available providers set
    this.availableProviders = new Set()
    
    // Use injected configuration
    this.useMockData = config.useMock
    
    if (this.useMockData) {
      console.log('[LLM] Using mock data mode')
      // Set dummy values when using mock data
      this.provider = 'openai'
      this.apiKey = 'mock'
      this.availableProviders.add('openai')
      this.availableProviders.add('anthropic')
      return
    }

    // Check available providers by validating API keys
    console.log('[LLM] Configuration check:', {
      hasOpenAI: !!config.openaiApiKey,
      hasAnthropic: !!config.anthropicApiKey,
      openaiKeyLength: config.openaiApiKey?.length || 0,
      anthropicKeyLength: config.anthropicApiKey?.length || 0,
      anthropicKeyPrefix: config.anthropicApiKey?.substring(0, 12) || 'MISSING'
    })
    
    if (config.openaiApiKey && config.openaiApiKey.trim().length > 0) {
      this.availableProviders.add('openai')
    }
    
    if (config.anthropicApiKey && config.anthropicApiKey.trim().length > 0) {
      this.availableProviders.add('anthropic')
    }
    
    if (this.availableProviders.size === 0) {
      throw new Error('No LLM providers available. Please configure OPENAI_API_KEY or ANTHROPIC_API_KEY')
    }

    // Set primary provider based on configuration or default to available provider
    if (config.provider && this.availableProviders.has(config.provider)) {
      this.provider = config.provider
    } else {
      // Default to first available provider (Anthropic preferred for multilingual)
      this.provider = this.availableProviders.has('anthropic') ? 'anthropic' : 'openai'
      if (config.provider) {
        console.warn(`[LLM] Configured provider ${config.provider} not available, using ${this.provider}`)
      }
    }
    
    // Set API key for primary provider
    this.apiKey = this.provider === 'openai' ? config.openaiApiKey! : config.anthropicApiKey!
    
    console.log(`[LLM] Initialized with primary provider: ${this.provider}`)
    console.log(`[LLM] Available providers: ${Array.from(this.availableProviders).join(', ')}`)
    
    // Log streaming configuration (disabled for now)
    const streamingEnabled = false
    console.log(`[LLM] Streaming support: ${streamingEnabled ? 'enabled' : 'disabled'}`)
  }

  /**
   * Initializes language-specific configurations for supported languages.
   */
  private initializeLanguageConfigs(): void {
    // English configuration
    this.languageConfigs.set('en', {
      name: 'English',
      modelPreference: 'openai',
      maxTokens: 3000,
      temperature: 0.3,
      promptModifiers: {
        languageInstruction: 'Output only in clear, accessible English',
        complexityInstruction: 'Use clear, pastoral language appropriate for all education levels'
      },
      culturalContext: 'Western Christian context with Protestant theological emphasis'
    })

    // Hindi configuration
    this.languageConfigs.set('hi', {
      name: 'Hindi',
      modelPreference: 'anthropic',
      maxTokens: 4000,
      temperature: 0.2,
      promptModifiers: {
        languageInstruction: 'Output only in simple, everyday Hindi (avoid complex Sanskrit words, use common spoken Hindi)',
        complexityInstruction: 'Use easy level language that common people can easily understand'
      },
      culturalContext: 'Indian Christian context with cultural sensitivity to local traditions and practices'
    })

    // Malayalam configuration
    this.languageConfigs.set('ml', {
      name: 'Malayalam',
      modelPreference: 'anthropic',
      maxTokens: 4000,
      temperature: 0.2,
      promptModifiers: {
        languageInstruction: 'Output only in simple, everyday Malayalam (avoid complex literary words, use common spoken Malayalam)',
        complexityInstruction: 'Use simple vocabulary accessible to Malayalam speakers across Kerala'
      },
      culturalContext: 'Kerala Christian context with awareness of the strong Protestant Christian heritage in the region'
    })

    console.log(`[LLM] Initialized configurations for ${this.languageConfigs.size} languages`)
  }

  /**
   * Generates a Bible study guide using LLM or mock data.
   * 
   * @param params - Generation parameters
   * @returns Promise resolving to LLM response
   * @throws {Error} When generation fails
   */
  async generateStudyGuide(params: LLMGenerationParams): Promise<LLMResponse> {
    this.validateParams(params)

    console.log(`[LLM] Generating study guide for ${params.inputType}: ${params.inputValue}`)
    
    // Always use real LLM in production
    return await this.generateWithLLM(params)
  }

  /**
   * Generates a daily Bible verse with translations using LLM.
   * 
   * @param excludeReferences - Array of recently used verses to avoid
   * @param language - Target language for cultural context (default: 'en')
   * @returns Promise resolving to daily verse response
   * @throws {Error} When generation fails
   */
  async generateDailyVerse(
    excludeReferences: string[] = [], 
    language: string = 'en'
  ): Promise<DailyVerseResponse> {
    console.log(`[LLM] Generating daily verse, excluding: ${excludeReferences.join(', ')}`)
    
    if (this.useMockData) {
      console.log('[LLM] Using mock data for daily verse')
      return this.getMockDailyVerse()
    }

    try {
      // Create verse-specific prompt
      const prompt = this.createDailyVersePrompt(excludeReferences, language)
      
      // Select optimal provider for verse generation
      const selectedProvider = this.selectOptimalProvider(language)
      console.log(`[LLM] Selected ${selectedProvider} for daily verse generation`)
      
      let rawResponse: string
      
      // Call the selected provider
      if (selectedProvider === 'openai') {
        rawResponse = await this.callOpenAIForVerse(prompt.systemMessage, prompt.userMessage)
      } else {
        rawResponse = await this.callAnthropicForVerse(prompt.systemMessage, prompt.userMessage)
      }
      
      // Parse and validate the response
      const parsedResponse = await this.parseVerseResponse(rawResponse)
      
      console.log(`[LLM] Successfully generated daily verse: ${parsedResponse.reference}`)
      return parsedResponse
      
    } catch (error) {
      console.error(`[LLM] Daily verse generation failed:`, error)
      throw new Error(`Daily verse generation failed: ${error instanceof Error ? error.message : String(error)}`)
    }
  }

  /**
   * Gets a mock daily verse for development/testing.
   * 
   * @returns Mock daily verse response
   */
  private getMockDailyVerse(): DailyVerseResponse {
    const mockVerses = [
      {
        reference: "John 3:16",
        translations: {
          esv: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
          hindi: "क्योंकि परमेश्वर ने जगत से ऐसा प्रेम रखा कि उसने अपना एकलौता पुत्र दे दिया, ताकि जो कोई उस पर विश्वास करे वह नष्ट न हो, परन्तु अनन्त जीवन पाए।",
          malayalam: "കാരണം ദൈവം ലോകത്തെ ഇങ്ങനെ സ്നേഹിച്ചു, തന്റെ ഏകജാതനായ പുത്രനെ നൽകി, അവനിൽ വിശ്വസിക്കുന്നവൻ നശിക്കാതെ നിത്യജീവൻ പ്രാപിക്കേണ്ടതിന്."
        }
      },
      {
        reference: "Philippians 4:13",
        translations: {
          esv: "I can do all things through him who strengthens me.",
          hindi: "मैं उसके द्वारा जो मुझे सामर्थ्य देता है, सब कुछ कर सकता हूँ।",
          malayalam: "എന്നെ ബലപ്പെടുത്തുന്ന ക്രിസ്തുവിൽ എനിക്കു സകലവും ചെയ്വാൻ കഴിയും."
        }
      },
      {
        reference: "Psalm 23:1",
        translations: {
          esv: "The Lord is my shepherd; I shall not want.",
          hindi: "यहोवा मेरा चरवाहा है; मुझे कमी न होगी।",
          malayalam: "യഹോവ എന്റെ ഇടയൻ ആകുന്നു; എനിക്കു മുട്ടു വരികയില്ല."
        }
      }
    ]
    
    // Select verse based on current time to provide some variety
    const index = Math.floor(Date.now() / (1000 * 60 * 60 * 24)) % mockVerses.length
    return mockVerses[index]
  }

  /**
   * Validates generation parameters.
   * 
   * @param params - Parameters to validate
   * @throws {Error} When parameters are invalid
   */
  private validateParams(params: LLMGenerationParams): void {
    if (!params.inputType || !['scripture', 'topic'].includes(params.inputType)) {
      throw new Error('Invalid input type')
    }

    if (!params.inputValue || typeof params.inputValue !== 'string') {
      throw new Error('Invalid input value')
    }

    if (!params.language || typeof params.language !== 'string') {
      throw new Error('Invalid language')
    }

    // Validate language is supported
    if (!this.languageConfigs.has(params.language)) {
      const supportedLanguages = Array.from(this.languageConfigs.keys()).join(', ')
      throw new Error(`Unsupported language: "${params.language}". Supported languages: ${supportedLanguages}`)
    }
  }

  /**
   * Generates study guide using actual LLM service with optimal provider selection.
   * 
   * @param params - Generation parameters
   * @returns Promise resolving to LLM response
   * @throws {Error} When LLM API call fails or response is invalid
   */
  private async generateWithLLM(params: LLMGenerationParams): Promise<LLMResponse> {
    const languageConfig = this.languageConfigs.get(params.language)!
    const prompt = this.createEnhancedPrompt(params, languageConfig)
    
    try {
      // Select optimal provider based on language and availability
      const selectedProvider = this.selectOptimalProvider(params.language)
      console.log(`[LLM] Selected ${selectedProvider} API for language: ${languageConfig.name}`)
      
      let rawResponse: string
      
      // Call the selected provider with fallback logic
      try {
        if (selectedProvider === 'openai') {
          rawResponse = await this.callOpenAI(prompt.systemMessage, prompt.userMessage, languageConfig, params)
        } else if (selectedProvider === 'anthropic') {
          rawResponse = await this.callAnthropic(prompt.systemMessage, prompt.userMessage, languageConfig, params)
        } else {
          throw new Error(`Unsupported provider: ${selectedProvider}`)
        }
      } catch (primaryError) {
        console.error(`[LLM] Primary provider ${selectedProvider} failed:`, {
          error: primaryError instanceof Error ? primaryError.message : String(primaryError),
          stack: primaryError instanceof Error ? primaryError.stack : undefined,
          provider: selectedProvider,
          language: params.language,
          timestamp: new Date().toISOString()
        })
        console.warn(`[LLM] Primary provider ${selectedProvider} failed, attempting fallback`)
        
        // Attempt fallback to alternative provider
        const fallbackProvider = this.getFallbackProvider(selectedProvider)
        if (fallbackProvider && fallbackProvider !== selectedProvider) {
          console.log(`[LLM] Using fallback provider: ${fallbackProvider}`)
          
          if (fallbackProvider === 'openai') {
            rawResponse = await this.callOpenAI(prompt.systemMessage, prompt.userMessage, languageConfig, params)
          } else {
            rawResponse = await this.callAnthropic(prompt.systemMessage, prompt.userMessage, languageConfig, params)
          }
        } else {
          throw primaryError
        }
      }
      
      // Parse JSON response with retry mechanism
      const parsedResponse = await this.parseWithRetry(rawResponse, params, languageConfig)
      
      // Validate response structure
      if (!this.validateLLMResponse(parsedResponse)) {
        throw new Error('LLM response does not match expected structure')
      }
      
      // Sanitize and return response
      const sanitizedResponse = this.sanitizeLLMResponse(parsedResponse)
      console.log('[LLM] Successfully generated study guide')
      
      return sanitizedResponse
      
    } catch (error) {
      console.error(`[LLM] ${this.provider} API call failed:`, error)
      throw new Error(`LLM generation failed: ${error instanceof Error ? error.message : String(error)}`)
    }
  }

  /**
   * Gets the correct API key for a specific provider.
   * 
   * @param provider - The LLM provider to get API key for
   * @returns API key for the provider
   * @throws {Error} When API key is not available
   */
  private getApiKeyForProvider(provider: LLMProvider): string {
    const apiKey = provider === 'openai' ? this.config.openaiApiKey : this.config.anthropicApiKey
    
    if (!apiKey || apiKey.trim().length === 0) {
      throw new Error(`API key not available for provider: ${provider}`)
    }
    
    console.log(`[LLM] Using API key for ${provider}: ${apiKey.substring(0, 15)}...`)
    return apiKey
  }

  /**
   * Calls OpenAI ChatCompletion API with enhanced parameters and optional streaming.
   * 
   * @param systemMessage - The system message defining AI behavior
   * @param userMessage - The user message with task details
   * @param languageConfig - Language-specific configuration
   * @param params - Generation parameters for optimization
   * @returns Promise resolving to response content
   * @throws {Error} When API call fails
   */
  private async callOpenAI(systemMessage: string, userMessage: string, languageConfig: LanguageConfig, params: LLMGenerationParams): Promise<string> {
    // Streaming is disabled for now
    const enableStreaming = false
    
    if (enableStreaming) {
      return this.callOpenAIWithStreaming(systemMessage, userMessage, languageConfig, params)
    }
    
    return this.callOpenAIStandard(systemMessage, userMessage, languageConfig, params)
  }

  /**
   * Calls OpenAI API with standard (non-streaming) approach.
   */
  private async callOpenAIStandard(systemMessage: string, userMessage: string, languageConfig: LanguageConfig, params: LLMGenerationParams): Promise<string> {
    const model = this.selectOpenAIModel(params.language)
    const maxTokens = this.calculateOptimalTokens(params, languageConfig)
    
    const request: OpenAIRequest = {
      model,
      messages: [
        {
          role: 'system',
          content: systemMessage
        },
        {
          role: 'user',
          content: userMessage
        }
      ],
      temperature: languageConfig.temperature,
      max_tokens: maxTokens,
      presence_penalty: 0.1, // Reduce repetition
      frequency_penalty: 0.1, // Reduce repetition
      response_format: { type: 'json_object' }
    }

    const apiKey = this.getApiKeyForProvider('openai')
    
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
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

    console.log(`[LLM] OpenAI usage: ${data.usage.total_tokens} tokens`)
    return content
  }

  /**
   * Calls Anthropic Claude API with enhanced parameters.
   * 
   * @param systemMessage - The system message defining AI behavior
   * @param userMessage - The user message with task details
   * @param languageConfig - Language-specific configuration
   * @param params - Generation parameters for optimization
   * @returns Promise resolving to response content
   * @throws {Error} When API call fails
   */
  private async callAnthropic(systemMessage: string, userMessage: string, languageConfig: LanguageConfig, params: LLMGenerationParams): Promise<string> {
    const model = this.selectAnthropicModel(params.language)
    const maxTokens = this.calculateOptimalTokens(params, languageConfig)
    
    const request: AnthropicRequest = {
      model,
      max_tokens: maxTokens,
      temperature: languageConfig.temperature,
      top_p: 0.9, // Diversity parameter
      top_k: 250, // Top-k sampling
      system: systemMessage,
      messages: [
        {
          role: 'user',
          content: userMessage
        }
      ]
    }

    console.log(`[LLM] Calling Anthropic API with request:`, {
      model: request.model,
      max_tokens: request.max_tokens,
      temperature: request.temperature,
      messageLength: request.messages[0].content.length,
      systemMessageLength: request.system?.length || 0
    })

    const apiKey = this.getApiKeyForProvider('anthropic')
    
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify(request)
    })

    console.log(`[LLM] Anthropic API response status: ${response.status}`)

    if (!response.ok) {
      const errorText = await response.text()
      console.error(`[LLM] Anthropic API error details:`, {
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

    console.log(`[LLM] Anthropic usage: ${data.usage.input_tokens + data.usage.output_tokens} tokens`)
    return textContent.text
  }

  /**
   * Calls OpenAI API with streaming support.
   * 
   * @param systemMessage - The system message defining AI behavior
   * @param userMessage - The user message with task details
   * @param languageConfig - Language-specific configuration
   * @param params - Generation parameters for optimization
   * @returns Promise resolving to response content
   */
  private async callOpenAIWithStreaming(systemMessage: string, userMessage: string, languageConfig: LanguageConfig, params: LLMGenerationParams): Promise<string> {
    const model = this.selectOpenAIModel(params.language)
    const maxTokens = this.calculateOptimalTokens(params, languageConfig)
    
    const request: OpenAIRequest = {
      model,
      messages: [
        {
          role: 'system',
          content: systemMessage
        },
        {
          role: 'user',
          content: userMessage
        }
      ],
      temperature: languageConfig.temperature,
      max_tokens: maxTokens,
      presence_penalty: 0.1,
      frequency_penalty: 0.1,
      stream: true
    }

    try {
      const apiKey = this.getApiKeyForProvider('openai')
      
      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(request)
      })

      if (!response.ok) {
        // Fallback to non-streaming on streaming failure
        console.warn('[LLM] Streaming failed, falling back to standard mode')
        return this.callOpenAIStandard(systemMessage, userMessage, languageConfig, params)
      }

      // Process streaming response
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
              } catch (e) {
                // Skip invalid JSON chunks
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

      console.log(`[LLM] OpenAI streaming completed: ${fullContent.length} characters`)
      return fullContent

    } catch (error) {
      console.warn('[LLM] Streaming error, falling back to standard mode:', error instanceof Error ? error.message : String(error))
      return this.callOpenAIStandard(systemMessage, userMessage, languageConfig, params)
    }
  }

  /**
   * Selects the optimal OpenAI model based on language.
   * 
   * @param language - Target language code
   * @returns OpenAI model name
   */
  private selectOpenAIModel(language: string): string {
    switch (language) {
      case 'hi': // Hindi
      case 'ml': // Malayalam
        return 'gpt-4o-mini' // Better multilingual performance
      case 'en': // English
      default:
        return 'gpt-3.5-turbo-1106' // Cost-effective for English
    }
  }

  /**
   * Selects the optimal Anthropic model based on language.
   * 
   * @param language - Target language code
   * @returns Anthropic model name
   */
  private selectAnthropicModel(language: string): string {
    switch (language) {
      case 'hi': // Hindi
      case 'ml': // Malayalam
        return 'claude-3-5-sonnet-20241022' // Better multilingual understanding
      case 'en': // English
      default:
        return 'claude-3-5-haiku-20241022' // Fast and cost-effective
    }
  }

  /**
   * Calculates optimal token count based on input complexity and language.
   * 
   * @param params - Generation parameters
   * @param languageConfig - Language-specific configuration
   * @returns Optimal token count
   */
  private calculateOptimalTokens(params: LLMGenerationParams, languageConfig: LanguageConfig): number {
    const baseTokens = languageConfig.maxTokens
    const complexityFactor = this.estimateContentComplexity(params.inputValue, params.inputType)
    const languageBonus = (params.language === 'hi' || params.language === 'ml') ? 500 : 0
    
    return Math.min(baseTokens + complexityFactor + languageBonus, 8000) // Cap at 8k tokens
  }

  /**
   * Estimates content complexity to adjust token requirements.
   * 
   * @param inputValue - Input text to analyze
   * @param inputType - Type of input (scripture or topic)
   * @returns Token adjustment factor
   */
  private estimateContentComplexity(inputValue: string, inputType: string): number {
    const inputLength = inputValue.length
    
    if (inputType === 'scripture') {
      // Scripture references are typically simpler
      return inputLength < 20 ? 0 : 500 // Simple vs complex references
    } else {
      // Topic complexity based on length and complexity indicators
      const complexityIndicators = [
        'theology', 'doctrine', 'hermeneutics', 'exegesis',
        'eschatology', 'soteriology', 'pneumatology'
      ]
      
      const hasComplexTerms = complexityIndicators.some(term => 
        inputValue.toLowerCase().includes(term)
      )
      
      if (hasComplexTerms || inputLength > 100) {
        return 1000 // Complex theological topic
      } else if (inputLength > 50) {
        return 500 // Medium complexity
      } else {
        return 0 // Simple topic
      }
    }
  }

  /**
   * Parses LLM response with retry mechanism for JSON parsing failures.
   * 
   * @param rawResponse - Raw response from LLM
   * @param params - Generation parameters
   * @param languageConfig - Language-specific configuration
   * @param retryCount - Current retry attempt (default: 0)
   * @returns Parsed JSON response
   * @throws {Error} When all retry attempts fail
   */
  private async parseWithRetry(rawResponse: string, params: LLMGenerationParams, languageConfig: LanguageConfig, retryCount: number = 0): Promise<any> {
    const maxRetries = 3
    
    try {
      // Clean and attempt to parse the response
      let cleanedResponse = this.cleanJSONResponse(rawResponse)
      return JSON.parse(cleanedResponse)
    } catch (parseError) {
      console.error(`[LLM] JSON parse attempt ${retryCount + 1} failed:`, parseError instanceof Error ? parseError.message : String(parseError))
      
      if (retryCount < maxRetries) {
        console.log(`[LLM] Retrying with adjusted parameters (attempt ${retryCount + 2}/${maxRetries + 1})`)
        
        // Adjust parameters for retry - calculate adjustments based on ORIGINAL config
        const originalLanguageConfig = this.languageConfigs.get(params.language)!
        const adjustedLanguageConfig = {
          ...languageConfig,
          temperature: Math.max(0.1, originalLanguageConfig.temperature - (0.1 * (retryCount + 1))), // Reduce temperature progressively
          maxTokens: originalLanguageConfig.maxTokens + (500 * (retryCount + 1)) // Increase tokens progressively
        }
        
        // Re-generate with adjusted parameters
        const prompt = this.createEnhancedPrompt(params, adjustedLanguageConfig)
        const selectedProvider = this.selectOptimalProvider(params.language)
        
        let retryResponse: string
        try {
          if (selectedProvider === 'openai') {
            retryResponse = await this.callOpenAI(prompt.systemMessage, prompt.userMessage, adjustedLanguageConfig, params)
          } else {
            retryResponse = await this.callAnthropic(prompt.systemMessage, prompt.userMessage, adjustedLanguageConfig, params)
          }
          
          // Recursive retry with incremented count
          return await this.parseWithRetry(retryResponse, params, adjustedLanguageConfig, retryCount + 1)
        } catch (retryError) {
          console.error(`[LLM] Retry ${retryCount + 1} failed:`, retryError instanceof Error ? retryError.message : String(retryError))
          
          // If retry generation fails, try parsing original response one more time
          if (retryCount === 0) {
            try {
              const repairedResponse = this.repairTruncatedJSON(rawResponse)
              return JSON.parse(repairedResponse)
            } catch (repairError) {
              // Continue to next retry or throw original error
            }
          }
          
          // If this is the last retry, throw the original parse error
          if (retryCount >= maxRetries - 1) {
            throw new Error(`Failed to parse LLM response after ${maxRetries} attempts: ${parseError instanceof Error ? parseError.message : String(parseError)}`)
          }
          
          // Continue with retries
          return await this.parseWithRetry(rawResponse, params, languageConfig, retryCount + 1)
        }
      } else {
        // All retries exhausted
        console.error('[LLM] Raw response that failed to parse:', rawResponse.substring(0, 500) + '...')
        throw new Error(`Failed to parse LLM response after ${maxRetries} attempts: ${parseError instanceof Error ? parseError.message : String(parseError)}`)
      }
    }
  }

  /**
   * Selects the optimal LLM provider based on language performance characteristics.
   * 
   * @param language - Target language code (en, hi, ml)
   * @returns Optimal LLM provider for the given language
   */
  private selectOptimalProvider(language: string): LLMProvider {
    const languageConfig = this.languageConfigs.get(language)
    
    // Start with language-specific preference from configuration
    let preferredProvider: LLMProvider = languageConfig?.modelPreference || this.provider
    
    // Apply language-based optimization rules
    switch (language) {
      case 'hi': // Hindi
      case 'ml': // Malayalam
        // Anthropic generally performs better with multilingual content
        if (this.isProviderAvailable('anthropic')) {
          preferredProvider = 'anthropic'
          console.log(`[LLM] Selecting Anthropic for ${language} (better multilingual performance)`)
        } else {
          console.log(`[LLM] Anthropic not available for ${language}, using ${preferredProvider}`)
        }
        break
        
      case 'en': // English
        // Both providers work well for English, use configured preference
        if (this.isProviderAvailable(preferredProvider)) {
          console.log(`[LLM] Using configured provider ${preferredProvider} for English`)
        } else {
          // Fallback to any available provider
          preferredProvider = this.getAnyAvailableProvider()
          console.log(`[LLM] Configured provider not available, using ${preferredProvider} for English`)
        }
        break
        
      default:
        // For any other languages, use configured provider with availability check
        if (!this.isProviderAvailable(preferredProvider)) {
          preferredProvider = this.getAnyAvailableProvider()
          console.log(`[LLM] Configured provider not available for ${language}, using ${preferredProvider}`)
        }
        break
    }
    
    // Final validation
    if (!this.isProviderAvailable(preferredProvider)) {
      throw new Error(`No available LLM provider for language: ${language}`)
    }
    
    return preferredProvider
  }

  /**
   * Gets a fallback provider when the primary provider fails.
   * 
   * @param primaryProvider - The primary provider that failed
   * @returns Fallback provider or null if none available
   */
  private getFallbackProvider(primaryProvider: LLMProvider): LLMProvider | null {
    // Simple fallback: if OpenAI fails, try Anthropic and vice versa
    const fallbackProvider: LLMProvider = primaryProvider === 'openai' ? 'anthropic' : 'openai'
    
    if (this.isProviderAvailable(fallbackProvider)) {
      return fallbackProvider
    }
    
    return null
  }

  /**
   * Checks if a specific LLM provider is available (has valid API key).
   * 
   * @param provider - Provider to check
   * @returns True if provider is available
   */
  private isProviderAvailable(provider: LLMProvider): boolean {
    return this.availableProviders.has(provider)
  }

  /**
   * Gets any available provider as a last resort.
   * 
   * @returns Any available provider
   * @throws {Error} If no providers are available
   */
  private getAnyAvailableProvider(): LLMProvider {
    // Prefer Anthropic for multilingual support
    if (this.availableProviders.has('anthropic')) {
      return 'anthropic'
    }
    
    // Then try OpenAI
    if (this.availableProviders.has('openai')) {
      return 'openai'
    }
    
    throw new Error('No LLM providers are available - please check API key configuration')
  }

  /**
   * Creates an enhanced prompt for LLM with proper system/user message separation.
   * 
   * @param params - Generation parameters
   * @param languageConfig - Language-specific configuration
   * @returns Object containing separate system and user messages with cultural context and examples
   */
  private createEnhancedPrompt(params: LLMGenerationParams, languageConfig: LanguageConfig): {systemMessage: string, userMessage: string} {
    return {
      systemMessage: this.createSystemMessage(languageConfig),
      userMessage: this.createUserMessage(params, languageConfig)
    }
  }

  /**
   * Creates the system message defining the AI's persona and behavior.
   * 
   * @param languageConfig - Language-specific configuration
   * @returns System message string
   */
  private createSystemMessage(languageConfig: LanguageConfig): string {
    return `You are a biblical scholar creating Bible study guides. Your responses must be valid JSON only.

      THEOLOGICAL APPROACH:
      - Protestant theological alignment
      - Biblical accuracy and Christ-centered interpretation
      - Practical spiritual application

      LANGUAGE REQUIREMENTS:
      - ${languageConfig.promptModifiers.languageInstruction}
      - ${languageConfig.promptModifiers.complexityInstruction}
      - Cultural Context: ${languageConfig.culturalContext}
      - Use simple vocabulary accessible to common people

      JSON OUTPUT REQUIREMENTS:
      - Output ONLY valid JSON - no extra text before or after
      - Use proper JSON string escaping for any quotes or special characters
      - Keep sentences clear and well-structured
      - Ensure proper JSON structure with no trailing commas
      - Use standard JSON formatting with proper escaping

      TONE: Pastoral, warm, encouraging, practical for daily spiritual growth.`
  }

  /**
   * Creates the user message with task details and formatting requirements.
   * 
   * @param params - Generation parameters
   * @param languageConfig - Language-specific configuration (unused but kept for consistency)
   * @returns User message string
   */
  private createUserMessage(params: LLMGenerationParams, languageConfig: LanguageConfig): string {
    const { inputType, inputValue } = params
    const languageExamples = this.getLanguageSpecificExamples(params.language)

    return `TASK: Create a Bible study guide for the ${inputType === 'scripture' ? 'scripture reference' : 'topic'}: "${inputValue}"

      REQUIRED JSON OUTPUT FORMAT (follow exactly):
      {
        "summary": "Brief overview (2-3 sentences) capturing the main message",
        "interpretation": "Theological interpretation (3-4 paragraphs) explaining meaning and key teachings", 
        "context": "Historical and cultural background (1-2 paragraphs) for understanding",
        "relatedVerses": ["3-5 relevant Bible verses with references"],
        "reflectionQuestions": ["4-6 practical application questions"],
        "prayerPoints": ["3-4 prayer suggestions"]
      }

      CRITICAL JSON FORMATTING RULES:
      - Output ONLY valid JSON - no markdown, no extra text before or after
      - Use proper JSON string escaping for quotes and special characters
      - Keep content natural and readable while ensuring valid JSON
      - Use standard JSON formatting with proper escaping
      - No trailing commas in arrays or objects

      ${languageExamples}

      Output format: Start with { and end with } - nothing else.`
  }

  /**
   * Provides language-specific examples and formatting guidelines for better LLM output.
   * 
   * @param language - Target language code (en, hi, ml)
   * @returns Language-specific examples and guidelines
   */
  private getLanguageSpecificExamples(language: string): string {
    switch (language) {
      case 'en':
        return `ENGLISH EXAMPLES & STYLE:
Use clear, accessible English appropriate for all education levels.

Example Summary: "This passage teaches us about God's unfailing love and how we can trust Him in difficult times."

Example Reflection Question: "How can you practically show God's love to someone in your family or community this week?"

Example Prayer Point: "Ask God to help you trust His love even when circumstances are challenging."

Tone: Pastoral, encouraging, and practical with modern language that connects biblical truth to daily life.`

      case 'hi':
        return `हिंदी में उदाहरण और शैली:
सरल, रोजमर्रा की हिंदी का उपयोग करें। कठिन संस्कृत शब्दों से बचें।

उदाहरण सारांश: "यह पद हमें दिखाता है कि परमेश्वर हमसे प्रेम करता है।"

उदाहरण प्रश्न: "आप अपने जीवन में परमेश्वर के प्रेम को कैसे देख सकते हैं?"

उदाहरण प्रार्थना: "हे प्रभु, हमें अपने प्रेम को समझने में मदद करें।"

उदाहरण व्याख्या: "इस पद में पौलुस हमें बताता है कि परमेश्वर का प्रेम कभी खत्म नहीं होता। यह प्रेम हमारे लिए इतना गहरा है कि वह अपने बेटे यीशु को हमारे लिए दे दिया।"

शैली: गांव के लोग समझ सकें, ऐसी सरल भाषा। आम बोलचाल के शब्द। बाइबल की सच्चाई को रोजाना की जिंदगी से जोड़ें।

शब्दावली गाइड:
- "परमेश्वर" (न कि "ईश्वर")
- "प्रेम" (न कि "प्रीति") 
- "मदद" (न कि "सहायता")
- "जिंदगी" (न कि "जीवन")
- "दिल" (न कि "हृदय")
- "प्रार्थना" (न कि "प्रार्थना")
- "आशीर्वाद" (न कि "आशीष")`

      case 'ml':
        return `മലയാളത്തിൽ ഉദാഹരണം:
സാധാരണ മലയാളം ഉപയോഗിക്കുക. JSON പാഴ്സിംഗ് പ്രശ്നങ്ങൾ ഒഴിവാക്കാൻ:

JSON ഫോർമാറ്റിംഗ് നിയമങ്ങൾ:
- ഉദ്ധരണി ചിഹ്നങ്ങൾ ഉപയോഗിക്കരുത്
- ലളിതമായ വാക്യങ്ങൾ മാത്രം
- പ്രത്യേക ചിഹ്നങ്ങൾ ഒഴിവാക്കുക

ഉദാഹരണ സാരാംശം: ഈ വചനം ദൈവത്തിന്റെ സ്നേഹം കാണിക്കുന്നു.

ഉദാഹരണ ചോദ്യം: നിങ്ങളുടെ ജീവിതത്തിൽ ദൈവത്തിന്റെ സ്നേഹം എങ്ങനെ കാണാം.

ഉദാഹരണ പ്രാർത്ഥന: കർത്താവേ അങ്ങയുടെ സ്നേഹം മനസ്സിലാക്കാൻ സഹായിക്കേണമേ.

ശൈലി: ലളിതമായ മലയാളം. ബൈബിൾ സത്യത്തെ ദൈനംദിന ജീവിതവുമായി ബന്ധിപ്പിക്കുക.

പദാവലി:
- ദൈവം
- സ്നേഹം
- സഹായം
- ജീവിതം
- മനസ്സ്
- പ്രാർത്ഥന
- അനുഗ്രഹം`

      default:
        return 'Use clear, accessible language appropriate for your target audience.'
    }
  }

  /**
   * Validates LLM response structure and content.
   * 
   * @param response - Raw LLM response
   * @returns True if valid, false otherwise
   */
  private validateLLMResponse(response: any): boolean {
    if (!response || typeof response !== 'object') {
      console.error('[LLM] Response is not an object')
      return false
    }

    const requiredFields = ['summary', 'interpretation', 'context', 'relatedVerses', 'reflectionQuestions', 'prayerPoints']
    
    for (const field of requiredFields) {
      if (!(field in response)) {
        console.error(`[LLM] Missing required field: ${field}`)
        return false
      }
    }

    // Validate array fields
    const arrayFields = ['relatedVerses', 'reflectionQuestions', 'prayerPoints']
    for (const field of arrayFields) {
      if (!Array.isArray(response[field])) {
        console.error(`[LLM] Field ${field} is not an array`)
        return false
      }
      if (response[field].length === 0) {
        console.error(`[LLM] Field ${field} is empty`)
        return false
      }
    }

    // Validate string fields
    const stringFields = ['summary', 'context', 'interpretation']
    for (const field of stringFields) {
      if (typeof response[field] !== 'string' || response[field].trim().length === 0) {
        console.error(`[LLM] Field ${field} is not a valid string`)
        return false
      }
    }

    return true
  }

  /**
   * Sanitizes LLM response for security and consistency.
   * 
   * @param response - Raw LLM response
   * @returns Sanitized response
   */
  private sanitizeLLMResponse(response: any): LLMResponse {
    return {
      summary: this.sanitizeText(response.summary),
      interpretation: this.sanitizeText(response.interpretation || ''), // Optional field
      context: this.sanitizeText(response.context),
      relatedVerses: response.relatedVerses.map((verse: string) => this.sanitizeText(verse)),
      reflectionQuestions: response.reflectionQuestions.map((question: string) => this.sanitizeText(question)),
      prayerPoints: response.prayerPoints.map((point: string) => this.sanitizeText(point))
    }
  }

  /**
   * Cleans JSON response to handle common formatting issues with multilingual content.
   * 
   * @param response - Raw JSON response from LLM
   * @returns Cleaned JSON string
   */
  private cleanJSONResponse(response: string): string {
    let cleaned = response.trim()
    
    // Remove any markdown code block markers that might be included
    cleaned = cleaned.replace(/^```json\s*/i, '').replace(/\s*```$/, '')
    
    // Fix common JSON issues with quotes in multilingual content
    try {
      // Try to parse as-is first
      JSON.parse(cleaned)
      return cleaned
    } catch (error) {
      // If parsing fails, try to fix common issues
      console.log('[LLM] Attempting to repair malformed JSON response')
      
      // Try to extract JSON from response if there's additional text
      const jsonMatch = cleaned.match(/\{[\s\S]*\}/)
      if (jsonMatch) {
        cleaned = jsonMatch[0]
      }
      
      // Handle truncated JSON by trying to complete it
      if (error instanceof Error && error.message.includes('Unterminated string')) {
        console.log('[LLM] Detected truncated JSON, attempting repair')
        cleaned = this.repairTruncatedJSON(cleaned)
      }
      
      return cleaned
    }
  }

  /**
   * Attempts to repair truncated JSON by closing incomplete strings and objects.
   * 
   * @param json - Truncated JSON string
   * @returns Repaired JSON string
   */
  private repairTruncatedJSON(json: string): string {
    let repaired = json
    
    // Count unclosed braces and brackets
    const openBraces = (repaired.match(/\{/g) || []).length
    const closeBraces = (repaired.match(/\}/g) || []).length
    const openBrackets = (repaired.match(/\[/g) || []).length
    const closeBrackets = (repaired.match(/\]/g) || []).length
    
    // Check if we're in the middle of a string (odd number of quotes in the last line)
    const lines = repaired.split('\n')
    const lastLine = lines[lines.length - 1]
    const quotesInLastLine = (lastLine.match(/"/g) || []).length
    
    // If we're in an unterminated string, close it
    if (quotesInLastLine % 2 === 1) {
      repaired += '"'
    }
    
    // Remove any trailing commas before closing
    repaired = repaired.replace(/,\s*$/, '')
    
    // Close any unclosed arrays
    for (let i = 0; i < openBrackets - closeBrackets; i++) {
      repaired += ']'
    }
    
    // Close any unclosed objects
    for (let i = 0; i < openBraces - closeBraces; i++) {
      repaired += '}'
    }
    
    console.log('[LLM] JSON repair attempted')
    return repaired
  }

  /**
   * Creates a prompt specifically for daily verse generation.
   * 
   * @param excludeReferences - Verses to avoid
   * @param language - Target language for cultural context
   * @returns Prompt object with system and user messages
   */
  private createDailyVersePrompt(excludeReferences: string[], language: string): {systemMessage: string, userMessage: string} {
    const excludeList = excludeReferences.length > 0 
      ? ` Avoid these recently used verses: ${excludeReferences.join(', ')}.`
      : ''
    
    const languageConfig = this.languageConfigs.get(language) || this.languageConfigs.get('en')!
    
    const systemMessage = `You are a biblical scholar selecting meaningful Bible verses for daily encouragement.

Your task is to select ONE inspiring Bible verse and provide it with accurate translations.

OUTPUT REQUIREMENTS:
- Return ONLY valid JSON with the exact structure specified
- No markdown formatting, no extra text
- Use proper JSON string escaping for any quotes
- Ensure all translations are accurate and meaningful

LANGUAGE CONTEXT: ${languageConfig.culturalContext}
COMPLEXITY: ${languageConfig.promptModifiers.complexityInstruction}`

    const userMessage = `Select one meaningful Bible verse for daily spiritual encouragement.${excludeList}

Requirements:
- Choose a verse that offers comfort, strength, hope, faith, peace, or guidance
- Provide accurate translations in all three languages
- Focus on well-known, inspiring verses
- Ensure theological accuracy

Return in this EXACT JSON format (no other text):
{
  "reference": "Book Chapter:Verse",
  "translations": {
    "esv": "English verse text (ESV translation)",
    "hindi": "Hindi translation in Devanagari script",
    "malayalam": "Malayalam translation in Malayalam script"
  }
}

Examples of good verse types:
- God's love and grace (John 3:16, Romans 8:38-39)
- Strength and courage (Philippians 4:13, Joshua 1:9)
- Peace and comfort (Psalm 23:1, Matthew 11:28)
- Hope and faith (Jeremiah 29:11, Hebrews 11:1)
- Guidance and wisdom (Proverbs 3:5-6, Psalm 119:105)`

    return { systemMessage, userMessage }
  }

  /**
   * Calls OpenAI API specifically for verse generation.
   * 
   * @param systemMessage - System prompt
   * @param userMessage - User prompt
   * @returns Raw response text
   */
  private async callOpenAIForVerse(systemMessage: string, userMessage: string): Promise<string> {
    const model = 'gpt-3.5-turbo-1106'
    
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

    const apiKey = this.getApiKeyForProvider('openai')
    
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
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

    return content
  }

  /**
   * Calls Anthropic API specifically for verse generation.
   * 
   * @param systemMessage - System prompt
   * @param userMessage - User prompt
   * @returns Raw response text
   */
  private async callAnthropicForVerse(systemMessage: string, userMessage: string): Promise<string> {
    const model = 'claude-3-5-haiku-20241022'
    
    const request: AnthropicRequest = {
      model,
      max_tokens: 800,
      temperature: 0.2,
      system: systemMessage,
      messages: [
        { role: 'user', content: userMessage }
      ]
    }

    const apiKey = this.getApiKeyForProvider('anthropic')
    
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01'
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
   * Parses and validates verse response from LLM.
   * 
   * @param rawResponse - Raw response from LLM
   * @returns Parsed and validated verse response
   */
  private async parseVerseResponse(rawResponse: string): Promise<DailyVerseResponse> {
    try {
      // Clean the response
      const cleaned = this.cleanJSONResponse(rawResponse)
      const parsed = JSON.parse(cleaned)
      
      // Validate structure
      if (!parsed.reference || typeof parsed.reference !== 'string') {
        throw new Error('Missing or invalid reference field')
      }
      
      if (!parsed.translations || typeof parsed.translations !== 'object') {
        throw new Error('Missing or invalid translations field')
      }
      
      const { esv, hindi, malayalam } = parsed.translations
      
      if (!esv || typeof esv !== 'string') {
        throw new Error('Missing or invalid ESV translation')
      }
      
      if (!hindi || typeof hindi !== 'string') {
        throw new Error('Missing or invalid Hindi translation')
      }
      
      if (!malayalam || typeof malayalam !== 'string') {
        throw new Error('Missing or invalid Malayalam translation')
      }
      
      // Sanitize and return
      return {
        reference: this.sanitizeText(parsed.reference),
        translations: {
          esv: this.sanitizeText(esv),
          hindi: this.sanitizeText(hindi),
          malayalam: this.sanitizeText(malayalam)
        }
      }
      
    } catch (error) {
      console.error('[LLM] Failed to parse verse response:', error)
      console.error('[LLM] Raw response:', rawResponse.substring(0, 500))
      throw new Error(`Failed to parse verse response: ${error instanceof Error ? error.message : String(error)}`)
    }
  }

  /**
   * Sanitizes text content to prevent XSS and ensure data quality.
   * 
   * @param text - Text to sanitize
   * @returns Sanitized text
   */
  private sanitizeText(text: string): string {
    if (typeof text !== 'string') {
      return ''
    }

    return text
      .trim()
      .replace(/\s+/g, ' ') // Normalize whitespace
      .replace(/[<>]/g, '') // Remove potential HTML tags
      .substring(0, 2000) // Reasonable length limit
  }
}

/*
EXAMPLE USAGE AND TESTING:

// Example 1: OpenAI provider
// Set environment variables:
// LLM_PROVIDER=openai
// OPENAI_API_KEY=sk-...
// USE_MOCK=false

const llmService = new LLMService()
const response = await llmService.generateStudyGuide({
  inputType: 'scripture',
  inputValue: 'John 3:16',
  language: 'en'
})

// Example 2: Anthropic provider
// Set environment variables:
// LLM_PROVIDER=anthropic
// ANTHROPIC_API_KEY=sk-ant-...
// USE_MOCK=false

const anthropicService = new LLMService()
const anthropicResponse = await anthropicService.generateStudyGuide({
  inputType: 'topic',
  inputValue: 'Faith and Trust',
  language: 'en'
})

// Example 3: Development mode with mock data
// Set environment variables:
// USE_MOCK=true

const mockService = new LLMService()
const mockResponse = await mockService.generateStudyGuide({
  inputType: 'scripture',
  inputValue: 'Romans 8:28',
  language: 'en'
})

// Unit test cases should cover:
// 1. Test provider selection logic - constructor should correctly read LLM_PROVIDER
// 2. Test API key validation - should throw error when key is missing
// 3. Test response parsing and validation - should handle malformed JSON
// 4. Test error handling for invalid responses - should throw descriptive errors
// 5. Test text sanitization - should remove HTML tags and normalize whitespace
// 6. Test mock data fallback - should work when USE_MOCK=true
// 7. Test OpenAI API call - should format request correctly and parse response
// 8. Test Anthropic API call - should format request correctly and parse response
// 9. Test prompt generation - should include all required elements
// 10. Test validation logic - should reject incomplete responses
*/