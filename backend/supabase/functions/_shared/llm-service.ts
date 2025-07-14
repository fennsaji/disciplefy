// Declare Deno types for Supabase Edge Functions environment
declare const Deno: {
  env: {
    get(key: string): string | undefined
  }
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
   * Creates a new LLM service instance.
   * Reads LLM_PROVIDER and USE_MOCK environment variables to configure behavior.
   * Initializes language-specific configurations for English, Hindi, and Malayalam.
   */
  constructor() {
    // Initialize language configurations
    this.languageConfigs = new Map()
    this.initializeLanguageConfigs()
    
    // Initialize available providers set
    this.availableProviders = new Set()
    
    // Check if we should use mock data (development mode)
    this.useMockData = Deno.env.get('USE_MOCK') === 'true'
    
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
    const openaiKey = Deno.env.get('OPENAI_API_KEY')
    const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY')
    
    if (openaiKey && openaiKey.trim().length > 0) {
      this.availableProviders.add('openai')
    }
    
    if (anthropicKey && anthropicKey.trim().length > 0) {
      this.availableProviders.add('anthropic')
    }
    
    if (this.availableProviders.size === 0) {
      throw new Error('No LLM providers available. Please configure OPENAI_API_KEY or ANTHROPIC_API_KEY')
    }

    // Determine primary LLM provider from environment variable
    const providerEnv = Deno.env.get('LLM_PROVIDER')?.toLowerCase()
    
    if (providerEnv && providerEnv !== 'openai' && providerEnv !== 'anthropic') {
      throw new Error(`Invalid LLM_PROVIDER: "${providerEnv}". Must be "openai" or "anthropic"`)
    }
    
    // Set primary provider based on configuration or default to available provider
    if (providerEnv && this.availableProviders.has(providerEnv as LLMProvider)) {
      this.provider = providerEnv as LLMProvider
    } else {
      // Default to first available provider (Anthropic preferred for multilingual)
      this.provider = this.availableProviders.has('anthropic') ? 'anthropic' : 'openai'
      if (providerEnv) {
        console.warn(`[LLM] Configured provider ${providerEnv} not available, using ${this.provider}`)
      }
    }
    
    // Set API key for primary provider
    const apiKeyEnv = this.provider === 'openai' ? 'OPENAI_API_KEY' : 'ANTHROPIC_API_KEY'
    this.apiKey = Deno.env.get(apiKeyEnv)!
    
    console.log(`[LLM] Initialized with primary provider: ${this.provider}`)
    console.log(`[LLM] Available providers: ${Array.from(this.availableProviders).join(', ')}`)
    
    // Log streaming configuration
    const streamingEnabled = Deno.env.get('ENABLE_STREAMING') === 'true'
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
      throw new Error(`LLM generation failed: ${error.message}`)
    }
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
    // Check if streaming is enabled
    const enableStreaming = Deno.env.get('ENABLE_STREAMING') === 'true'
    
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

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
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

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': this.apiKey,
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
      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
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
      console.warn('[LLM] Streaming error, falling back to standard mode:', error.message)
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
        return 'claude-3-sonnet-20240229' // Better multilingual understanding
      case 'en': // English
      default:
        return 'claude-3-haiku-20240307' // Fast and cost-effective
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
      console.error(`[LLM] JSON parse attempt ${retryCount + 1} failed:`, parseError.message)
      
      if (retryCount < maxRetries) {
        console.log(`[LLM] Retrying with adjusted parameters (attempt ${retryCount + 2}/${maxRetries + 1})`)
        
        // Adjust parameters for retry
        const adjustedLanguageConfig = {
          ...languageConfig,
          temperature: Math.max(0.1, languageConfig.temperature - 0.1), // Reduce temperature
          maxTokens: languageConfig.maxTokens + 500 // Increase tokens
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
          console.error(`[LLM] Retry ${retryCount + 1} failed:`, retryError.message)
          
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
            throw new Error(`Failed to parse LLM response after ${maxRetries} attempts: ${parseError.message}`)
          }
          
          // Continue with retries
          return await this.parseWithRetry(rawResponse, params, languageConfig, retryCount + 1)
        }
      } else {
        // All retries exhausted
        console.error('[LLM] Raw response that failed to parse:', rawResponse.substring(0, 500) + '...')
        throw new Error(`Failed to parse LLM response after ${maxRetries} attempts: ${parseError.message}`)
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
    return `You are a biblical scholar and theologian specializing in creating Bible study guides using the Inductive Bible Study Method. Your expertise combines deep theological knowledge with pastoral sensitivity.

THEOLOGICAL FOUNDATION:
- Maintain Protestant (especially Pentecostal) theological alignment
- Ensure biblical accuracy and Christ-centered interpretation
- Apply sound hermeneutical principles
- Emphasize practical spiritual application

LANGUAGE & CULTURAL APPROACH:
- ${languageConfig.promptModifiers.languageInstruction}
- ${languageConfig.promptModifiers.complexityInstruction}
- Cultural Context: ${languageConfig.culturalContext}
- Use vocabulary accessible to common people
- Avoid scholarly jargon or overly complex theological terms

TONE & STYLE:
- Maintain a pastoral, warm, and encouraging tone
- Focus on practical life application
- Make content useful for both individual and group study
- Connect biblical truth to daily spiritual growth
- Provide actionable guidance for spiritual development

Your responses should demonstrate theological depth while remaining accessible to believers at all levels of spiritual maturity.`
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

    return `TASK: Create a comprehensive Bible study guide for the ${inputType === 'scripture' ? 'scripture reference' : 'topic'}: "${inputValue}"

REQUIRED JSON OUTPUT FORMAT (follow exactly):
{
  "summary": "Brief (2-3 sentence) overview capturing the main message or theme",
  "interpretation": "In-depth theological interpretation (4-5 well-structured paragraphs) explaining the intended meaning, key teachings, and broader biblical connections", 
  "context": "Historical, cultural, and literary background (1-2 concise paragraphs) to help understand the setting and authorship",
  "relatedVerses": ["3-5 relevant Bible verses with references that support or expand the message"],
  "reflectionQuestions": ["4-6 practical questions to help apply the message in personal or group life"],
  "prayerPoints": ["3-4 prayer suggestions aligned with the message and reflection"]
}

CRITICAL FORMATTING RULES:
- Return ONLY valid JSON - no markdown, no code blocks, no extra text
- Properly escape all quotes within text content using \\"
- Ensure all strings are properly closed with matching quotes
- Use simple punctuation to avoid JSON parsing issues
- No trailing commas
- Each field must contain meaningful, substantive content

${languageExamples}

IMPORTANT: Output ONLY the JSON object. No additional text, explanations, or formatting markers.`
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
സാധാരണ, എളുപ്പത്തിൽ മനസ്സിലാകുന്ന മലയാളം ഉപയോഗിക്കുക. സാഹിത്യിക വാക്കുകൾ ഒഴിവാക്കുക.

ഉദാഹരണ സാരാംശം: "ഈ വചനം നമ്മോട് ദൈവത്തിന്റെ സ്നേഹം കാണിക്കുന്നു."

ഉദാഹരണ ചോദ്യം: "നിങ്ങളുടെ ജീവിതത്തിൽ ദൈവത്തിന്റെ സ്നേഹം എങ്ങനെ കാണാം?"

ഉദാഹരണ പ്രാർത്ഥന: "കർത്താവേ, അങ്ങയുടെ സ്നേഹം മനസ്സിലാക്കാൻ സഹായിക്കേണമേ."

ഉദാഹരണ വ്യാഖ്യാനം: "ഈ വചനത്തിൽ പൗലോസ് നമ്മോട് പറയുന്നത് ദൈവത്തിന്റെ സ്നേഹം ഒരിക്കലും തീരാത്തതാണെന്നാണ്. ഈ സ്നേഹം നമുക്ക് വേണ്ടി തന്റെ പുത്രനായ യേശുവിനെ നൽകുവാൻ പോലും അവനെ പ്രേരിപ്പിച്ചു."

ശൈലി: കേരളത്തിലെ എല്ലാ ക്രിസ്ത്യാനികൾക്കും മനസ്സിലാകുന്ന സാധാരണ മലയാളം. ബൈബിൾ സത്യത്തെ ദൈനംദിന ജീവിതവുമായി ബന്ധിപ്പിക്കുക.

പദാവലി ഗൈഡ്:
- "ദൈവം" (നല്ല സാധാരണ വാക്ക്)
- "സ്നേഹം" (എളുപ്പത്തിൽ മനസ്സിലാകും)
- "സഹായം" (ലളിതമായ വാക്ക്)
- "ജീവിതം" (എല്ലാവർക്കും അറിയാം)
- "മനസ്സ്" (ഹൃദയത്തെക്കാൾ സാധാരണം)
- "പ്രാർത്ഥന" (ലളിതമായ വാക്ക്)
- "അനുഗ്രഹം" (ആശീർവാദത്തേക്കാൾ നല്ലത്)`

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
      if (error.message.includes('Unterminated string')) {
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