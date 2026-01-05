/**
 * Streaming JSON Parser for Study Guide Generation
 *
 * Parses incremental JSON chunks from LLM streaming responses and
 * emits complete sections as they become available.
 *
 * The parser expects JSON in this order:
 * 1. summary (string) - Required
 * 2. interpretation (string) - Required
 * 3. context (string) - Required
 * 4. relatedVerses (array of strings) - Required
 * 5. reflectionQuestions (array of strings) - Required
 * 6. prayerPoints (array of strings) - Required
 * 7. interpretationInsights (array of strings) - Optional
 * 8. summaryInsights (array of strings) - Optional
 * 9. reflectionAnswers (array of strings) - Optional
 * 10. contextQuestion (string) - Optional
 * 11. summaryQuestion (string) - Optional
 * 12. relatedVersesQuestion (string) - Optional
 * 13. reflectionQuestion (string) - Optional
 * 14. prayerQuestion (string) - Optional
 */

/**
 * Section types in the order they appear in the study guide
 */
export type SectionType =
  | 'summary'
  | 'interpretation'
  | 'context'
  | 'relatedVerses'
  | 'reflectionQuestions'
  | 'prayerPoints'
  | 'interpretationInsights'
  | 'summaryInsights'
  | 'reflectionAnswers'
  | 'contextQuestion'
  | 'summaryQuestion'
  | 'relatedVersesQuestion'
  | 'reflectionQuestion'
  | 'prayerQuestion'

/**
 * A parsed section from the streaming response
 */
export interface ParsedSection {
  type: SectionType
  content: string | string[]
  index: number
}

/**
 * Complete study guide structure
 */
export interface CompleteStudyGuide {
  summary: string
  interpretation: string
  context: string
  relatedVerses: string[]
  reflectionQuestions: string[]
  prayerPoints: string[]
  interpretationInsights?: string[]
  summaryInsights?: string[]
  reflectionAnswers?: string[]
  contextQuestion?: string
  summaryQuestion?: string
  relatedVersesQuestion?: string
  reflectionQuestion?: string
  prayerQuestion?: string
}

/**
 * Section order for parsing (matches LLM output order)
 */
const SECTION_ORDER: SectionType[] = [
  'summary',
  'interpretation',
  'context',
  'relatedVerses',
  'reflectionQuestions',
  'prayerPoints',
  'interpretationInsights',
  'summaryInsights',
  'reflectionAnswers',
  'contextQuestion',
  'summaryQuestion',
  'relatedVersesQuestion',
  'reflectionQuestion',
  'prayerQuestion'
]

/**
 * Required sections that must be present for completion
 */
const REQUIRED_SECTIONS: SectionType[] = [
  'summary',
  'interpretation',
  'context',
  'relatedVerses',
  'reflectionQuestions',
  'prayerPoints'
]

/**
 * Streaming JSON Parser
 * 
 * Accumulates LLM chunks and emits complete sections as they're detected.
 * Uses regex-based detection to find complete JSON field values.
 */
export class StreamingJsonParser {
  private buffer: string = ''
  private emittedSections: Set<SectionType> = new Set()
  private parsedData: Partial<CompleteStudyGuide> = {}

  /**
   * Adds a new chunk to the buffer and checks for complete sections
   *
   * @param chunk - Raw text chunk from LLM stream
   * @returns Array of newly completed sections (may be empty)
   */
  addChunk(chunk: string): ParsedSection[] {
    this.buffer += chunk
    return this.extractCompleteSections()
  }

  /**
   * Extracts any complete sections from the buffer
   *
   * @returns Array of newly completed sections
   */
  private extractCompleteSections(): ParsedSection[] {
    const newSections: ParsedSection[] = []

    for (let i = 0; i < SECTION_ORDER.length; i++) {
      const sectionType = SECTION_ORDER[i]

      // Skip already emitted sections
      if (this.emittedSections.has(sectionType)) {
        continue
      }

      const extracted = this.tryExtractSection(sectionType)

      if (extracted !== null) {
        this.emittedSections.add(sectionType)
        this.parsedData[sectionType] = extracted as any

        newSections.push({
          type: sectionType,
          content: extracted,
          index: i
        })
      }
    }

    return newSections
  }

  /**
   * Attempts to extract a complete section value from the buffer
   *
   * @param sectionType - The section type to look for
   * @returns The extracted value or null if not complete
   */
  private tryExtractSection(sectionType: SectionType): string | string[] | null {
    const isArrayType = [
      'relatedVerses',
      'reflectionQuestions',
      'prayerPoints',
      'interpretationInsights',
      'summaryInsights',
      'reflectionAnswers'
    ].includes(sectionType)

    if (isArrayType) {
      return this.tryExtractArray(sectionType)
    } else {
      return this.tryExtractString(sectionType)
    }
  }

  /**
   * Extracts a string field value from the buffer
   * 
   * Pattern: "fieldName": "value"
   * Handles escaped quotes and special characters
   */
  private tryExtractString(fieldName: string): string | null {
    // Match pattern: "fieldName": "value"
    // The value continues until we find an unescaped quote followed by comma or closing brace
    const pattern = new RegExp(
      `"${fieldName}"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"`
    )
    
    const match = this.buffer.match(pattern)
    
    if (match && match[1] !== undefined) {
      // Check if there's content after this field (indicating it's complete)
      const afterMatch = this.buffer.substring(this.buffer.indexOf(match[0]) + match[0].length)
      
      // A field is complete if followed by comma, closing brace, or another field
      if (/^\s*[,}]/.test(afterMatch) || /^\s*"[a-zA-Z]/.test(afterMatch)) {
        // Unescape the string value
        return this.unescapeJsonString(match[1])
      }
    }

    return null
  }

  /**
   * Extracts an array field value from the buffer
   * 
   * Pattern: "fieldName": ["value1", "value2", ...]
   */
  private tryExtractArray(fieldName: string): string[] | null {
    // Find the start of the array
    const startPattern = new RegExp(`"${fieldName}"\\s*:\\s*\\[`)
    const startMatch = this.buffer.match(startPattern)
    
    if (!startMatch) {
      return null
    }

    const arrayStart = this.buffer.indexOf(startMatch[0]) + startMatch[0].length
    
    // Find the matching closing bracket
    let depth = 1
    let pos = arrayStart
    let inString = false
    let escaped = false

    while (pos < this.buffer.length && depth > 0) {
      const char = this.buffer[pos]
      
      if (escaped) {
        escaped = false
      } else if (char === '\\') {
        escaped = true
      } else if (char === '"') {
        inString = !inString
      } else if (!inString) {
        if (char === '[') depth++
        if (char === ']') depth--
      }
      
      pos++
    }

    if (depth === 0) {
      // Found complete array
      const arrayContent = this.buffer.substring(arrayStart, pos - 1)
      return this.parseArrayContent(arrayContent)
    }

    return null
  }

  /**
   * Parses the content inside an array
   * 
   * @param content - The string content between [ and ]
   * @returns Array of string values
   */
  private parseArrayContent(content: string): string[] {
    const result: string[] = []
    
    // Match all quoted strings in the array
    const stringPattern = /"((?:[^"\\]|\\.)*)"/g
    let match

    while ((match = stringPattern.exec(content)) !== null) {
      result.push(this.unescapeJsonString(match[1]))
    }

    return result
  }

  /**
   * Unescapes JSON string escape sequences
   */
  private unescapeJsonString(str: string): string {
    return str
      .replace(/\\n/g, '\n')
      .replace(/\\r/g, '\r')
      .replace(/\\t/g, '\t')
      .replace(/\\"/g, '"')
      .replace(/\\\\/g, '\\')
  }

  /**
   * Returns the number of sections emitted so far
   */
  getSectionsEmitted(): number {
    return this.emittedSections.size
  }

  /**
   * Returns the total number of sections expected
   */
  getTotalSections(): number {
    return SECTION_ORDER.length
  }

  /**
   * Checks if all required sections have been emitted
   * (Optional sections like interpretationInsights and contextQuestion are not required)
   */
  isComplete(): boolean {
    return REQUIRED_SECTIONS.every(section => this.emittedSections.has(section))
  }

  /**
   * Gets the parsed data collected so far
   */
  getParsedData(): Partial<CompleteStudyGuide> {
    return { ...this.parsedData }
  }

  /**
   * Gets the complete study guide if all required sections are parsed
   *
   * @throws Error if parsing is not complete
   */
  getCompleteStudyGuide(): CompleteStudyGuide {
    if (!this.isComplete()) {
      throw new Error('Study guide parsing is not complete')
    }

    const result: CompleteStudyGuide = {
      summary: this.parsedData.summary!,
      interpretation: this.parsedData.interpretation!,
      context: this.parsedData.context!,
      relatedVerses: this.parsedData.relatedVerses!,
      reflectionQuestions: this.parsedData.reflectionQuestions!,
      prayerPoints: this.parsedData.prayerPoints!
    }

    // Add optional fields if present
    if (this.parsedData.interpretationInsights) {
      result.interpretationInsights = this.parsedData.interpretationInsights
    }
    if (this.parsedData.summaryInsights) {
      result.summaryInsights = this.parsedData.summaryInsights
    }
    if (this.parsedData.reflectionAnswers) {
      result.reflectionAnswers = this.parsedData.reflectionAnswers
    }
    if (this.parsedData.contextQuestion) {
      result.contextQuestion = this.parsedData.contextQuestion
    }
    if (this.parsedData.summaryQuestion) {
      result.summaryQuestion = this.parsedData.summaryQuestion
    }
    if (this.parsedData.relatedVersesQuestion) {
      result.relatedVersesQuestion = this.parsedData.relatedVersesQuestion
    }
    if (this.parsedData.reflectionQuestion) {
      result.reflectionQuestion = this.parsedData.reflectionQuestion
    }
    if (this.parsedData.prayerQuestion) {
      result.prayerQuestion = this.parsedData.prayerQuestion
    }

    return result
  }

  /**
   * Attempts to parse the complete buffer as JSON (fallback)
   *
   * Used when streaming completes but some sections weren't detected
   */
  async tryParseComplete(): Promise<CompleteStudyGuide | null> {
    try {
      // Clean up the buffer to ensure valid JSON
      let cleanBuffer = this.buffer.trim()

      // Strip markdown code fences (from Anthropic responses)
      if (cleanBuffer.startsWith('```json\n')) {
        cleanBuffer = cleanBuffer.substring(8)
      } else if (cleanBuffer.startsWith('```json')) {
        cleanBuffer = cleanBuffer.substring(7)
      } else if (cleanBuffer.startsWith('```\n')) {
        cleanBuffer = cleanBuffer.substring(4)
      } else if (cleanBuffer.startsWith('```')) {
        cleanBuffer = cleanBuffer.substring(3)
      }

      if (cleanBuffer.endsWith('\n```')) {
        cleanBuffer = cleanBuffer.substring(0, cleanBuffer.length - 4)
      } else if (cleanBuffer.endsWith('```')) {
        cleanBuffer = cleanBuffer.substring(0, cleanBuffer.length - 3)
      }

      cleanBuffer = cleanBuffer.trim()

      // Ensure it starts with { and ends with }
      if (!cleanBuffer.startsWith('{')) {
        const startIndex = cleanBuffer.indexOf('{')
        if (startIndex === -1) return null
        cleanBuffer = cleanBuffer.substring(startIndex)
      }

      if (!cleanBuffer.endsWith('}')) {
        const endIndex = cleanBuffer.lastIndexOf('}')
        if (endIndex === -1) return null
        cleanBuffer = cleanBuffer.substring(0, endIndex + 1)
      }

      // First attempt: parse the cleaned buffer directly
      // LLM should return properly escaped JSON; additional escaping corrupts valid sequences
      const parsed = JSON.parse(cleanBuffer)

      // Validate required structure
      if (
        typeof parsed.summary === 'string' &&
        typeof parsed.interpretation === 'string' &&
        typeof parsed.context === 'string' &&
        Array.isArray(parsed.relatedVerses) &&
        Array.isArray(parsed.reflectionQuestions) &&
        Array.isArray(parsed.prayerPoints)
      ) {
        const result: CompleteStudyGuide = {
          summary: parsed.summary,
          interpretation: parsed.interpretation,
          context: parsed.context,
          relatedVerses: parsed.relatedVerses,
          reflectionQuestions: parsed.reflectionQuestions,
          prayerPoints: parsed.prayerPoints
        }

        // Add optional fields if present and valid
        if (Array.isArray(parsed.interpretationInsights)) {
          result.interpretationInsights = parsed.interpretationInsights
        }
        if (Array.isArray(parsed.summaryInsights)) {
          result.summaryInsights = parsed.summaryInsights
        }
        if (Array.isArray(parsed.reflectionAnswers)) {
          result.reflectionAnswers = parsed.reflectionAnswers
        }
        if (typeof parsed.contextQuestion === 'string') {
          result.contextQuestion = parsed.contextQuestion
        }
        if (typeof parsed.summaryQuestion === 'string') {
          result.summaryQuestion = parsed.summaryQuestion
        }
        if (typeof parsed.relatedVersesQuestion === 'string') {
          result.relatedVersesQuestion = parsed.relatedVersesQuestion
        }
        if (typeof parsed.reflectionQuestion === 'string') {
          result.reflectionQuestion = parsed.reflectionQuestion
        }
        if (typeof parsed.prayerQuestion === 'string') {
          result.prayerQuestion = parsed.prayerQuestion
        }

        return result
      }

      return null
    } catch (error) {
      // Create deterministic fingerprint of buffer without exposing content
      const bufferHash = await this.hashBuffer(this.buffer)

      console.error('[Parser] ❌ JSON.parse() failed!')
      console.error('[Parser] Error:', error instanceof Error ? error.message : String(error))
      console.error('[Parser] Error stack:', error instanceof Error ? error.stack : 'N/A')
      console.error('[Parser] Buffer length:', this.buffer.length, 'characters')
      console.error('[Parser] Buffer fingerprint (SHA-256):', bufferHash)
      return null
    }
  }

  /**
   * Creates a SHA-256 hash fingerprint of the buffer for debugging
   * without exposing sensitive content
   */
  private async hashBuffer(content: string): Promise<string> {
    try {
      const encoder = new TextEncoder()
      const data = encoder.encode(content)
      const hashBuffer = await crypto.subtle.digest('SHA-256', data)
      const hashArray = Array.from(new Uint8Array(hashBuffer))
      const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
      return hashHex
    } catch (error) {
      return '[REDACTED]'
    }
  }

  /**
   * Resets the parser state for reuse
   */
  reset(): void {
    this.buffer = ''
    this.emittedSections.clear()
    this.parsedData = {}
  }

  /**
   * Gets the current buffer content (for debugging)
   */
  getBuffer(): string {
    return this.buffer
  }
}

/**
 * Creates SSE event data string
 * 
 * @param eventType - The event type (init, section, complete, error)
 * @param data - The data to include in the event
 * @returns Formatted SSE event string
 */
export function formatSSEEvent(eventType: string, data: Record<string, unknown>): string {
  return `event: ${eventType}\ndata: ${JSON.stringify(data)}\n\n`
}

/**
 * Creates an SSE section event
 */
export function createSectionEvent(section: ParsedSection, total: number = 6): string {
  return formatSSEEvent('section', {
    type: section.type,
    content: section.content,
    index: section.index,
    total
  })
}

/**
 * Creates an SSE init event
 */
export function createInitEvent(status: 'started' | 'cache_hit', estimatedSections: number = 6): string {
  return formatSSEEvent('init', {
    status,
    estimatedSections
  })
}

/**
 * Creates an SSE complete event
 */
export function createCompleteEvent(studyGuideId: string, tokensConsumed: number, fromCache: boolean): string {
  return formatSSEEvent('complete', {
    studyGuideId,
    tokensConsumed,
    fromCache
  })
}

/**
 * Creates an SSE error event
 */
export function createErrorEvent(code: string, message: string, retryable: boolean): string {
  return formatSSEEvent('error', {
    code,
    message,
    retryable
  })
}
