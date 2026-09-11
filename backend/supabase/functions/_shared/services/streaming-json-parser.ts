/**
 * Streaming JSON Parser for Study Guide Generation
 *
 * Parses incremental JSON chunks from LLM streaming responses and
 * emits complete sections as they become available.
 *
 * The parser expects JSON in this order (matching prompt templates):
 * 1. summary (string) - Required
 * 2. context (string) - Required
 * 3. passage (string) - Required (Bible reference only)
 * 4. interpretation (string) - Required
 * 5. relatedVerses (array of strings) - Required
 * 6. reflectionQuestions (array of strings) - Required
 * 7. prayerPoints (array of strings) - Required
 */

/**
 * Section types in the order they appear in the study guide
 */
export type SectionType =
  | 'summary'
  | 'interpretation'
  | 'interpretationPart1'
  | 'interpretationPart2'
  | 'interpretationPart3'
  | 'interpretationPart4'
  | 'context'
  | 'passage'
  | 'relatedVerses'
  | 'reflectionQuestions'
  | 'prayerPoints'

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
  passage: string  // LLM-generated Scripture passage reference for meditation
  relatedVerses: string[]
  reflectionQuestions: string[]
  prayerPoints: string[]
}

/**
 * Section order for parsing (MUST match LLM generation order for optimal streaming)
 * Order: Summary → Context → Passage → Interpretation → Related Verses → Questions → Prayer
 * This order matches the JSON structure in all prompt templates to minimize buffering delays
 */
const SECTION_ORDER: SectionType[] = [
  'summary',
  'context',
  'passage',
  'interpretation',
  // Multi-pass interpretation parts (used by multipass generators, ignored in single-pass)
  'interpretationPart1',
  'interpretationPart2',
  'interpretationPart3',
  'interpretationPart4',
  'relatedVerses',
  'reflectionQuestions',
  'prayerPoints'
]

/**
 * Required sections that must be present for completion
 */
const REQUIRED_SECTIONS: SectionType[] = [
  'summary',
  'interpretation',
  'context',
  'passage',
  'relatedVerses',
  'reflectionQuestions',
  'prayerPoints'
]

/**
 * Sanitizes invalid characters inside JSON string values so that JSON.parse() succeeds.
 *
 * Fixes two classes of LLM output errors:
 * 1. Literal control characters (actual \n, \r, \t bytes inside string values)
 *    → escaped to \\n, \\r, \\t
 * 2. Unescaped double-quote characters inside string values
 *    (e.g., The word "faith" in Greek...) → escaped to \\"
 *    Detection: a quote is structural (field boundary) only when followed by
 *    a comma, closing brace/bracket, or next JSON key. Otherwise it is content.
 *
 * Structural whitespace between fields is never modified.
 */
function sanitizeJsonStringLiterals(json: string): string {
  let inString = false
  let escaped = false
  let result = ''

  for (let i = 0; i < json.length; i++) {
    const char = json[i]

    if (escaped) {
      result += char
      escaped = false
    } else if (char === '\\' && inString) {
      result += char
      escaped = true
    } else if (char === '"') {
      if (inString) {
        // Determine if this quote closes the string value or is an unescaped
        // quote inside the value (e.g., LLM writes The word "faith" literally).
        // A quote is structural (closes the string) if followed by:
        //   - optional whitespace + comma, closing brace, or closing bracket
        //   - optional whitespace + a JSON key (quote + letter/underscore)
        //   - end of input
        const remaining = json.substring(i + 1)
        const isStructural =
          /^\s*[,}\]]/.test(remaining) ||
          /^\s*"[a-zA-Z_]/.test(remaining) ||
          remaining.trim() === ''
        if (isStructural) {
          inString = false
          result += char
        } else {
          // Unescaped quote inside string value — escape it so JSON.parse succeeds
          result += '\\"'
        }
      } else {
        inString = true
        result += char
      }
    } else if (inString && char === '\n') {
      result += '\\n'
    } else if (inString && char === '\r') {
      result += '\\r'
    } else if (inString && char === '\t') {
      result += '\\t'
    } else {
      result += char
    }
  }

  return result
}

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
   * Resume state for a string field that has not closed yet, keyed by field
   * name. Without this, every incoming chunk re-scanned every unclosed
   * field's value from its first character, which is O(length x chunk count)
   * — quadratic in the field's total size. A 20,000+ token sermon pass in
   * Malayalam streams over hundreds of chunks and pushed this well past the
   * platform's 2-second CPU budget per request, dropping the connection.
   * Each field is now visited once per character across the whole request.
   */
  private stringScans: Map<string, { valueStart: number; pos: number; value: string; escaped: boolean }> = new Map()

  /** Same idea as {@link stringScans}, for array fields. */
  private arrayScans: Map<string, { arrayStart: number; pos: number; depth: number; inString: boolean; escaped: boolean }> = new Map()

  /**
   * How much of the buffer has already been confirmed to not contain a given
   * field's key, so the next search only looks at newly arrived characters
   * (plus a small overlap in case the key straddles the boundary) instead of
   * re-scanning from position 0 for every field that hasn't started yet.
   */
  private keySearchProgress: Map<string, number> = new Map()

  /**
   * Finds `"fieldName":` style openers without re-scanning already-searched
   * buffer content. Returns the absolute index just past [pattern]'s match,
   * or null if it is not present yet.
   */
  private findKeyEnd(fieldName: string, pattern: RegExp): number | null {
    const already = this.keySearchProgress.get(fieldName) ?? 0
    // Long enough to cover the pattern re-matching across the old/new boundary.
    const overlap = fieldName.length + 8
    const searchFrom = Math.max(0, already - overlap)

    const match = pattern.exec(this.buffer.slice(searchFrom))
    if (match) return searchFrom + match.index + match[0].length

    this.keySearchProgress.set(fieldName, this.buffer.length)
    return null
  }

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
        ;(this.parsedData as Record<string, unknown>)[sectionType] = extracted

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
      'prayerPoints'
    ].includes(sectionType)

    if (isArrayType) {
      // First try to extract as array
      const arrayResult = this.tryExtractArray(sectionType)
      if (arrayResult !== null) {
        return arrayResult
      }

      // FALLBACK: If array extraction fails, try extracting as string
      // This handles cases where LLM generates a string instead of array
      // (e.g., prayerPoints as a single prayer text)
      const stringResult = this.tryExtractString(sectionType)
      if (stringResult !== null) {
        console.log(`[Parser] ⚠️  Extracted ${sectionType} as string, converting to array`)
        // Convert string to single-element array
        return [stringResult]
      }

      return null
    } else {
      return this.tryExtractString(sectionType)
    }
  }

  /**
   * Extracts a string field value from the buffer using a state machine.
   *
   * Pattern: "fieldName": "value"
   * Handles escaped quotes AND unescaped quotes inside string values
   * (LLMs sometimes emit The word "faith" without escaping the inner quotes).
   * A quote is treated as the field's closing quote only when immediately followed
   * by a structural JSON token (comma, closing brace/bracket, or next key name).
   */
  private tryExtractString(fieldName: string): string | null {
    let scan = this.stringScans.get(fieldName)

    if (!scan) {
      // Find the field key followed by opening quote. Only needed once per
      // field: its position never changes once found.
      const keyPattern = new RegExp(`"${fieldName}"\\s*:\\s*"`)
      const valueStart = this.findKeyEnd(fieldName, keyPattern)
      if (valueStart === null) return null

      scan = { valueStart, pos: valueStart, value: '', escaped: false }
      this.stringScans.set(fieldName, scan)
    }

    // Resume from where the last call left off — only the newly arrived
    // characters are visited, not the whole value again.
    let pos = scan.pos
    let escaped = scan.escaped
    let value = scan.value

    while (pos < this.buffer.length) {
      const char = this.buffer[pos]

      if (escaped) {
        value += char
        escaped = false
      } else if (char === '\\') {
        value += char
        escaped = true
      } else if (char === '"') {
        // A quote closes the string only if followed by a structural token.
        // The lookahead only needs a handful of characters, never the rest of
        // the buffer — later passes' data can already be sitting beyond this
        // point once several sections have streamed in.
        const remaining = this.buffer.slice(pos + 1, pos + 21)
        if (/^\s*$/.test(remaining)) {
          // No lookahead yet — this quote could still turn out to be the
          // closer once more of the stream arrives. Stop here without
          // consuming it, so the next call re-examines this same position
          // instead of permanently committing it as literal content.
          scan.pos = pos
          scan.value = value
          scan.escaped = escaped
          return null
        }
        const isClosing =
          /^\s*[,}\]]/.test(remaining) ||
          /^\s*"[a-zA-Z_]/.test(remaining)
        if (isClosing) {
          this.stringScans.delete(fieldName)
          return this.unescapeJsonString(value)
        } else {
          // Unescaped quote inside the value — treat as literal content
          value += '"'
        }
      } else {
        value += char
      }

      pos++
    }

    // Reached end of buffer without a structural closing quote — still
    // streaming. Save progress so the next call resumes here.
    scan.pos = pos
    scan.value = value
    scan.escaped = escaped
    return null
  }

  /**
   * Extracts an array field value from the buffer
   * 
   * Pattern: "fieldName": ["value1", "value2", ...]
   */
  private tryExtractArray(fieldName: string): string[] | null {
    let scan = this.arrayScans.get(fieldName)

    if (!scan) {
      const startPattern = new RegExp(`"${fieldName}"\\s*:\\s*\\[`)
      const arrayStart = this.findKeyEnd(fieldName, startPattern)
      if (arrayStart === null) return null

      scan = { arrayStart, pos: arrayStart, depth: 1, inString: false, escaped: false }
      this.arrayScans.set(fieldName, scan)
    }

    // Resume the bracket-depth scan from the last visited position rather
    // than re-walking the array from its start on every chunk.
    let pos = scan.pos
    let depth = scan.depth
    let inString = scan.inString
    let escaped = scan.escaped

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
      const arrayContent = this.buffer.substring(scan.arrayStart, pos - 1)
      this.arrayScans.delete(fieldName)
      return this.parseArrayContent(arrayContent)
    }

    scan.pos = pos
    scan.depth = depth
    scan.inString = inString
    scan.escaped = escaped
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
   */
  isComplete(): boolean {
    const complete = REQUIRED_SECTIONS.every(section => this.emittedSections.has(section))

    if (!complete) {
      const missingSections = REQUIRED_SECTIONS.filter(section => !this.emittedSections.has(section))
      console.warn('[Parser] ⚠️  isComplete() = false. Missing required sections:', missingSections)
      console.log('[Parser] Emitted sections:', Array.from(this.emittedSections))
    }

    return complete
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
      passage: this.parsedData.passage || '',
      relatedVerses: this.parsedData.relatedVerses!,
      reflectionQuestions: this.parsedData.reflectionQuestions!,
      prayerPoints: this.parsedData.prayerPoints!
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

      // Sanitize literal control characters inside JSON string values.
      // LLMs (especially Anthropic) sometimes emit actual newlines/tabs inside string values,
      // which is invalid JSON. This state-machine sanitizer fixes only characters that are
      // inside strings, leaving structural JSON whitespace untouched.
      cleanBuffer = sanitizeJsonStringLiterals(cleanBuffer)

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
          passage: typeof parsed.passage === 'string' ? parsed.passage : '',
          relatedVerses: parsed.relatedVerses,
          reflectionQuestions: parsed.reflectionQuestions,
          prayerPoints: parsed.prayerPoints
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
    this.stringScans.clear()
    this.arrayScans.clear()
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
