import { LLMService } from '../_shared/llm-service.ts'

/**
 * Input parameters for study guide generation.
 */
interface StudyGuideGenerationParams {
  readonly inputType: 'scripture' | 'topic'
  readonly inputValue: string
  readonly language: string
}

/**
 * Generated study guide structure.
 */
interface GeneratedStudyGuide {
  readonly summary: string
  readonly interpretation: string
  readonly context: string
  readonly relatedVerses: readonly string[]
  readonly reflectionQuestions: readonly string[]
  readonly prayerPoints: readonly string[]
}

/**
 * Service for generating Bible study guides.
 * 
 * Orchestrates the study guide generation process using LLM services
 * and applying structured methodology principles.
 */
export class StudyGuideService {
  private readonly llmService: LLMService

  /**
   * Creates a new study guide service instance.
   */
  constructor() {
    this.llmService = new LLMService()
  }

  /**
   * Generates a comprehensive Bible study guide.
   * 
   * This method applies structured 4-step methodology:
   * 1. Context - Historical and cultural background
   * 2. Scholar's Guide - Original meaning and interpretation
   * 3. Group Discussion - Contemporary application questions
   * 4. Application - Personal life transformation steps
   * 
   * @param params - Generation parameters
   * @returns Promise resolving to generated study guide
   * @throws {AppError} When generation fails
   */
  async generateStudyGuide(params: StudyGuideGenerationParams): Promise<GeneratedStudyGuide> {
    this.validateGenerationParams(params)

    // Generate study guide using LLM service
    const llmResult = await this.llmService.generateStudyGuide({
      inputType: params.inputType,
      inputValue: params.inputValue,
      language: params.language
    })

    // Validate and format the result
    return this.formatStudyGuideResult(llmResult)
  }

  /**
   * Validates generation parameters.
   * 
   * @param params - Parameters to validate
   * @throws {AppError} When parameters are invalid
   */
  private validateGenerationParams(params: StudyGuideGenerationParams): void {
    if (!params.inputType || !['scripture', 'topic'].includes(params.inputType)) {
      throw new Error('Invalid input type. Must be "scripture" or "topic"')
    }

    if (!params.inputValue || typeof params.inputValue !== 'string') {
      throw new Error('Input value must be a non-empty string')
    }

    if (!params.language || typeof params.language !== 'string') {
      throw new Error('Language must be a valid string')
    }
  }

  /**
   * Formats and validates the LLM result.
   * 
   * @param llmResult - Raw result from LLM service
   * @returns Formatted study guide
   * @throws {Error} When result format is invalid
   */
  private formatStudyGuideResult(llmResult: any): GeneratedStudyGuide {
    // Validate required fields
    if (!llmResult.summary || typeof llmResult.summary !== 'string') {
      throw new Error('Invalid LLM result: missing or invalid summary')
    }

    if (!llmResult.context || typeof llmResult.context !== 'string') {
      throw new Error('Invalid LLM result: missing or invalid context')
    }

    if (!llmResult.interpretation || typeof llmResult.interpretation !== 'string') {
      throw new Error('Invalid LLM result: missing or invalid interpretation')
    }

    if (!Array.isArray(llmResult.relatedVerses)) {
      throw new Error('Invalid LLM result: relatedVerses must be an array')
    }

    if (!Array.isArray(llmResult.reflectionQuestions)) {
      throw new Error('Invalid LLM result: reflectionQuestions must be an array')
    }

    if (!Array.isArray(llmResult.prayerPoints)) {
      throw new Error('Invalid LLM result: prayerPoints must be an array')
    }

    return {
      summary: this.sanitizeText(llmResult.summary),
      interpretation: this.sanitizeText(llmResult.interpretation),
      context: this.sanitizeText(llmResult.context),
      relatedVerses: llmResult.relatedVerses.map((verse: string) => this.sanitizeText(verse)),
      reflectionQuestions: llmResult.reflectionQuestions.map((question: string) => this.sanitizeText(question)),
      prayerPoints: llmResult.prayerPoints.map((point: string) => this.sanitizeText(point))
    }
  }

  /**
   * Sanitizes text content for safe storage and display.
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
      .substring(0, 5000) // Prevent excessively long content
  }
}