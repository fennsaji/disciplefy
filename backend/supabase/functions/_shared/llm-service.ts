import { getMockStudyGuide, DEFAULT_MOCK_GUIDE } from './mock-data.ts'

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
  response_format?: { type: 'json_object' }
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
 * Service for generating Bible study content using Large Language Models.
 * 
 * This service handles LLM integration with provider selection via environment variables.
 * Supports OpenAI GPT and Anthropic Claude APIs with proper error handling and validation.
 */
export class LLMService {
  private readonly provider: LLMProvider
  private readonly apiKey: string
  private readonly useMockData: boolean

  /**
   * Creates a new LLM service instance.
   * Reads LLM_PROVIDER and USE_MOCK environment variables to configure behavior.
   */
  constructor() {
    // Check if we should use mock data (development mode)
    this.useMockData = Deno.env.get('USE_MOCK') === 'true'
    
    if (this.useMockData) {
      console.log('[LLM] Using mock data mode')
      // Set dummy values when using mock data
      this.provider = 'openai'
      this.apiKey = 'mock'
      return
    }

    // Determine LLM provider from environment variable
    const providerEnv = Deno.env.get('LLM_PROVIDER')?.toLowerCase()
    
    if (providerEnv !== 'openai' && providerEnv !== 'anthropic') {
      throw new Error(`Invalid LLM_PROVIDER: "${providerEnv}". Must be "openai" or "anthropic"`)
    }
    
    this.provider = providerEnv as LLMProvider
    
    // Get appropriate API key based on provider
    const apiKeyEnv = this.provider === 'openai' ? 'OPENAI_API_KEY' : 'ANTHROPIC_API_KEY'
    const apiKey = Deno.env.get(apiKeyEnv)
    
    if (!apiKey) {
      throw new Error(`Missing ${apiKeyEnv} environment variable for ${this.provider} provider`)
    }
    
    this.apiKey = apiKey
    console.log(`[LLM] Initialized with provider: ${this.provider}`)
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
    
    if (this.useMockData) {
      console.log('[LLM] Using mock data (development mode)')
      return this.generateWithMockData(params)
    }

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
  }

  /**
   * Generates study guide using actual LLM service based on configured provider.
   * 
   * @param params - Generation parameters
   * @returns Promise resolving to LLM response
   * @throws {Error} When LLM API call fails or response is invalid
   */
  private async generateWithLLM(params: LLMGenerationParams): Promise<LLMResponse> {
    const prompt = this.createPrompt(params)
    
    try {
      console.log(`[LLM] Calling ${this.provider} API`)
      
      let rawResponse: string
      
      // Call the appropriate provider
      if (this.provider === 'openai') {
        rawResponse = await this.callOpenAI(prompt)
      } else if (this.provider === 'anthropic') {
        rawResponse = await this.callAnthropic(prompt)
      } else {
        throw new Error(`Unsupported provider: ${this.provider}`)
      }
      
      // Parse JSON response
      let parsedResponse: any
      try {
        parsedResponse = JSON.parse(rawResponse)
      } catch (parseError) {
        throw new Error(`Failed to parse LLM response as JSON: ${parseError.message}`)
      }
      
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
   * Calls OpenAI ChatCompletion API.
   * 
   * @param prompt - The formatted prompt
   * @returns Promise resolving to response content
   * @throws {Error} When API call fails
   */
  private async callOpenAI(prompt: string): Promise<string> {
    const request: OpenAIRequest = {
      model: 'gpt-3.5-turbo-1106', // Supports JSON mode
      messages: [
        {
          role: 'system',
          content: 'You are a biblical scholar and theologian who creates Bible study guides following Jeff Reed methodology. Always respond with valid JSON in the exact format requested.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.3, // Lower temperature for more consistent theological content
      max_tokens: 2000,
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
   * Calls Anthropic Claude API.
   * 
   * @param prompt - The formatted prompt
   * @returns Promise resolving to response content
   * @throws {Error} When API call fails
   */
  private async callAnthropic(prompt: string): Promise<string> {
    const request: AnthropicRequest = {
      model: 'claude-3-haiku-20240307', // Fast and cost-effective
      max_tokens: 2000,
      temperature: 0.3,
      system: 'You are a biblical scholar and theologian who creates Bible study guides following Jeff Reed methodology. Always respond with valid JSON in the exact format requested.',
      messages: [
        {
          role: 'user',
          content: prompt
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
   * Generates study guide using mock data.
   * 
   * @param params - Generation parameters
   * @returns LLM response with mock data
   */
  private generateWithMockData(params: LLMGenerationParams): LLMResponse {
    console.log(`[LLM] Using mock data for ${params.inputType}: ${params.inputValue}`)
    
    const mockGuide = getMockStudyGuide(params.inputType, params.inputValue) || DEFAULT_MOCK_GUIDE
    
    // Convert mock data format to expected LLM response format
    return {
      summary: mockGuide.summary,
      interpretation: mockGuide.interpretation || `This ${params.inputType === 'scripture' ? 'passage' : 'topic'} reveals God's character and His relationship with humanity. The original meaning emphasizes themes of faith, redemption, and spiritual growth. Understanding the context helps us apply these timeless truths to our modern lives, encouraging us to deepen our relationship with God and live according to His will.`,
      context: mockGuide.context,
      relatedVerses: mockGuide.related_verses, // Convert snake_case to camelCase
      reflectionQuestions: mockGuide.reflection_questions,
      prayerPoints: mockGuide.prayer_points
    }
  }

  /**
   * Creates a prompt for LLM based on Jeff Reed methodology.
   * 
   * @param params - Generation parameters
   * @returns Formatted prompt string
   */
  private createPrompt(params: LLMGenerationParams): string {
    const { inputType, inputValue, language } = params
    
    const basePrompt = `You are a Bible scholar generating a comprehensive Bible study guide using the Inductive Bible Study Method. The user has submitted a ${inputType === 'scripture' ? 'scripture reference' : 'topic'}: "${inputValue}". Your task is to return ONLY valid JSON in the following format:

      {
        "summary": "Brief (2-3 sentence) overview capturing the main message or theme.",
        "interpretation": "In-depth theological interpretation explaining the intended meaning, key teachings, and how they relate to broader biblical themes. Use 4-5 well-structured paragraphs.",
        "context": "Historical, cultural, and literary background to help the reader understand the setting and authorship. Use 1-2 concise paragraphs.",
        "relatedVerses": ["3-5 relevant Bible verses with references that support or expand the message."],
        "reflectionQuestions": ["4-6 practical questions to help apply the message in personal or group life."],
        "prayerPoints": ["3-4 prayer suggestions aligned with the message and reflection."]
      }

      Instructions:
      - Maintain Protestant (especially Pentecostal) theological alignment.
      - Output only in ${language === 'en' ? 'English' : language === 'hi' ? 'Hindi' : 'Malayalam'}.
      - Do NOT include markdown, headers, commentary, or extra text. Return strictly valid JSON only.
      - Keep the tone pastoral, clear, and applicable to real-life spiritual growth.
      - Ensure every section is biblically rooted, Christ-centered, and practically useful for group or individual study.`

    return basePrompt
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