// Using built-in Web Crypto API for better stability

export interface SecurityValidationResult {
  isValid: boolean
  eventType: string
  riskScore: number
  message: string
  details: any
}

export class SecurityValidator {
  private readonly maxInputLength = 500
  private readonly suspiciousPatterns = [
    // Prompt injection patterns
    /ignore\s+(previous|above|all)\s+(instructions?|prompts?)/i,
    /forget\s+(everything|all|previous)/i,
    /new\s+(instructions?|prompts?|rules?)/i,
    /system\s*:/i,
    /assistant\s*:/i,
    /\[INST\]/i,
    /\[\/INST\]/i,
    /<\|im_start\|>/i,
    /<\|im_end\|>/i,
    
    // Code injection attempts
    /<script>/i,
    /javascript:/i,
    /eval\s*\(/i,
    /function\s*\(/i,
    
    // SQL injection patterns
    /union\s+select/i,
    /drop\s+table/i,
    /delete\s+from/i,
    
    // XSS patterns
    /<[^>]*on\w+\s*=/i,
    /<iframe/i,
    /<object/i,
    /<embed/i,
  ]

  async validateInput(input: string, inputType: string): Promise<SecurityValidationResult> {
    const result: SecurityValidationResult = {
      isValid: true,
      eventType: 'INPUT_VALIDATION',
      riskScore: 0,
      message: '',
      details: {}
    }

    // Length validation
    if (input.length > this.maxInputLength) {
      result.isValid = false
      result.eventType = 'INPUT_TOO_LONG'
      result.riskScore = 0.8
      result.message = `Input exceeds maximum length of ${this.maxInputLength} characters`
      result.details = { inputLength: input.length, maxLength: this.maxInputLength }
      return result
    }

    // Empty input validation
    if (!input.trim()) {
      result.isValid = false
      result.eventType = 'EMPTY_INPUT'
      result.riskScore = 0.3
      result.message = 'Input cannot be empty'
      return result
    }

    // Pattern matching for suspicious content
    for (const pattern of this.suspiciousPatterns) {
      if (pattern.test(input)) {
        result.isValid = false
        result.eventType = 'PROMPT_INJECTION_DETECTED'
        result.riskScore = 0.9
        result.message = 'Suspicious pattern detected in input'
        result.details = { 
          pattern: pattern.source,
          matchedText: input.match(pattern)?.[0] 
        }
        return result
      }
    }

    // Content‑specific validation
    if (inputType === 'scripture') {
      const scriptureValidation = this.validateScriptureReference(input.trim())
      if (!scriptureValidation.isValid) {
        result.isValid = false
        result.eventType = 'INVALID_SCRIPTURE_FORMAT'
        result.riskScore = 0.5
        result.message = scriptureValidation.message
        result.details = scriptureValidation.details
        return result
      }
    }

    // Advanced risk scoring based on multiple factors
    let riskScore = 0
    
    // Check for excessive special characters (more lenient for non-English content)
    const specialCharCount = (input.match(/[^a-zA-Z0-9\s]/g) || []).length
    if (specialCharCount > input.length * 0.6) { // Increased from 0.3 to 0.6
      riskScore += 0.2 // Reduced from 0.3 to 0.2
    }

    // Check for excessive uppercase (more lenient for emphasis)
    const uppercaseCount = (input.match(/[A-Z]/g) || []).length
    if (uppercaseCount > input.length * 0.8) { // Increased from 0.5 to 0.8
      riskScore += 0.1 // Reduced from 0.2 to 0.1
    }

    // Check for repeated patterns (unchanged - legitimate security concern)
    const repeatedPattern = /(.{3,})\1{2,}/
    if (repeatedPattern.test(input)) {
      riskScore += 0.4
    }

    result.riskScore = Math.min(riskScore, 1.0)
    
    // If risk score is too high, block the request (raised threshold)
    if (result.riskScore > 0.8) { // Increased from 0.7 to 0.8
      result.isValid = false
      result.eventType = 'HIGH_RISK_INPUT'
      result.message = 'Input flagged as high risk'
      result.details = { riskScore: result.riskScore }
    }

    return result
  }

  async hashSensitiveData(data: string): Promise<string> {
    const encoder = new TextEncoder()
    const dataBuffer = encoder.encode(data)
    const hashBuffer = await crypto.subtle.digest('SHA-256', dataBuffer)
    const hashArray = Array.from(new Uint8Array(hashBuffer))
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
  }

  sanitizeInput(input: string): string {
    // Remove control characters by char code (keep tab (9), newline (10), carriage return (13))
    const filtered = Array.from(input)
      .filter(char => {
        const code = char.charCodeAt(0);
        // Remove: 0-8, 11, 12, 14-31, 127
        if (code <= 8) return false;
        if (code === 11 || code === 12) return false;
        if (code >= 14 && code <= 31) return false;
        if (code === 127) return false;
        return true;
      })
      .join('');

    return filtered
      // Normalize Unicode to prevent homograph attacks
      .normalize('NFKC')
      // Remove HTML tags
      .replace(/<[^>]*>/g, '')
      // Remove dangerous characters
      .replace(/[<>&"']/g, '')
      // Trim whitespace
      .trim()
      // Limit length
      .substring(0, this.maxInputLength)
  }

  /**
   * Validates scripture reference using a robust two-stage approach.
   * Stage 1: Parse components using simple regex
   * Stage 2: Validate each component programmatically
   * 
   * @param input - Scripture reference to validate
   * @returns Validation result with details
   */
  private validateScriptureReference(input: string): {
    isValid: boolean
    message: string
    details: any
  } {
    // Known Bible books and common abbreviations
    const bibleBooks = new Set([
      // Old Testament
      'genesis', 'gen', 'ge', 'gn',
      'exodus', 'exod', 'exo', 'ex',
      'leviticus', 'lev', 'le', 'lv',
      'numbers', 'num', 'nu', 'nm', 'nb',
      'deuteronomy', 'deut', 'dt',
      'joshua', 'josh', 'jos', 'jsh',
      'judges', 'judg', 'jdg', 'jg', 'jdgs',
      'ruth', 'rth', 'ru',
      '1 samuel', '1sam', '1 sam', '1 sa', '1sa', '1s',
      '2 samuel', '2sam', '2 sam', '2 sa', '2sa', '2s',
      '1 kings', '1kgs', '1 kgs', '1 ki', '1ki', '1k',
      '2 kings', '2kgs', '2 kgs', '2 ki', '2ki', '2k',
      '1 chronicles', '1chr', '1 chr', '1 ch', '1ch', '1c',
      '2 chronicles', '2chr', '2 chr', '2 ch', '2ch', '2c',
      'ezra', 'ezr', 'ez',
      'nehemiah', 'neh', 'ne',
      'esther', 'esth', 'es',
      'job', 'jb',
      'psalms', 'psalm', 'ps', 'psa', 'psm', 'pss',
      'proverbs', 'prov', 'pr', 'prv',
      'ecclesiastes', 'eccl', 'ec', 'ecc',
      'song of solomon', 'song', 'sos', 'so',
      'isaiah', 'isa', 'is',
      'jeremiah', 'jer', 'je', 'jr',
      'lamentations', 'lam', 'la',
      'ezekiel', 'ezek', 'eze', 'ezk',
      'daniel', 'dan', 'da', 'dn',
      'hosea', 'hos', 'ho',
      'joel', 'joe', 'jl',
      'amos', 'am',
      'obadiah', 'obad', 'ob',
      'jonah', 'jnh', 'jon',
      'micah', 'mic', 'mc',
      'nahum', 'nah', 'na',
      'habakkuk', 'hab', 'hb',
      'zephaniah', 'zeph', 'zep', 'zp',
      'haggai', 'hag', 'hg',
      'zechariah', 'zech', 'zec', 'zc',
      'malachi', 'mal', 'ml',
      
      // New Testament
      'matthew', 'matt', 'mt',
      'mark', 'mk', 'mr',
      'luke', 'lk', 'luk',
      'john', 'jn', 'joh',
      'acts', 'ac',
      'romans', 'rom', 'ro', 'rm',
      '1 corinthians', '1cor', '1 cor', '1 co', '1co', '1c',
      '2 corinthians', '2cor', '2 cor', '2 co', '2co', '2c',
      'galatians', 'gal', 'ga',
      'ephesians', 'eph', 'ep',
      'philippians', 'phil', 'php', 'pp',
      'colossians', 'col', 'co',
      '1 thessalonians', '1thess', '1 thess', '1 th', '1th', '1ts',
      '2 thessalonians', '2thess', '2 thess', '2 th', '2th', '2ts',
      '1 timothy', '1tim', '1 tim', '1 ti', '1ti', '1tm',
      '2 timothy', '2tim', '2 tim', '2 ti', '2ti', '2tm',
      'titus', 'tit', 'ti',
      'philemon', 'phlm', 'phm', 'pm',
      'hebrews', 'heb', 'he',
      'james', 'jas', 'jm',
      '1 peter', '1pet', '1 pet', '1 pe', '1pe', '1pt', '1p',
      '2 peter', '2pet', '2 pet', '2 pe', '2pe', '2pt', '2p',
      '1 john', '1jn', '1 jn', '1 jo', '1jo', '1j',
      '2 john', '2jn', '2 jn', '2 jo', '2jo', '2j',
      '3 john', '3jn', '3 jn', '3 jo', '3jo', '3j',
      'jude', 'jud', 'jd',
      'revelation', 'rev', 're', 'rv'
    ])

    // Stage 1: Simple parsing with basic regex
    const components = this.parseScriptureComponents(input)
    
    if (!components) {
      return {
        isValid: false,
        message: 'Invalid scripture reference format',
        details: {
          expectedFormat: 'Book Chapter[:Verse][-Verse] (e.g., "John 3:16", "Romans 8:28-30", "Ps 23")',
          input: input
        }
      }
    }

    // Stage 2: Validate each component
    const bookValidation = this.validateBookName(components.book, bibleBooks)
    if (!bookValidation.isValid) {
      return bookValidation
    }

    const chapterValidation = this.validateChapterVerse(components.chapter, components.startVerse, components.endVerse)
    if (!chapterValidation.isValid) {
      return chapterValidation
    }

    return {
      isValid: true,
      message: 'Valid scripture reference',
      details: {
        book: components.book,
        chapter: components.chapter,
        startVerse: components.startVerse,
        endVerse: components.endVerse
      }
    }
  }

  /**
   * Parses scripture reference into components using simple regex.
   * Supports Unicode book names (Malayalam, Hindi, etc.) using \p{L} and \p{M}.
   * 
   * @param input - Scripture reference string
   * @returns Parsed components or null if invalid
   */
  private parseScriptureComponents(input: string): {
    book: string
    chapter: number
    startVerse?: number
    endVerse?: number
  } | null {
    // Unicode-aware regex to extract basic components
    // Uses [\p{L}\p{M}]+ to match letters AND combining marks (for Malayalam, Hindi, etc.)
    const match = input.match(/^([1-3]?\s*[\p{L}\p{M}]+\.?)\s+(\d+)(?::(\d+))?(?:-(\d+))?$/iu)
    
    if (!match) {
      return null
    }

    const [, book, chapterStr, startVerseStr, endVerseStr] = match
    
    const chapter = parseInt(chapterStr, 10)
    const startVerse = startVerseStr ? parseInt(startVerseStr, 10) : undefined
    const endVerse = endVerseStr ? parseInt(endVerseStr, 10) : undefined

    if (isNaN(chapter) || chapter < 1 || chapter > 150) {
      return null
    }

    if (startVerse !== undefined && (isNaN(startVerse) || startVerse < 1)) {
      return null
    }

    if (endVerse !== undefined && (isNaN(endVerse) || endVerse < 1)) {
      return null
    }

    return {
      book: book.trim(),
      chapter,
      startVerse,
      endVerse
    }
  }

  /**
   * Validates book name against known Bible books.
   * For non-English book names (containing non-ASCII characters), validation is skipped
   * since the Bible API will validate the reference when fetching the actual text.
   * 
   * @param book - Book name to validate
   * @param bibleBooks - Set of known Bible books
   * @returns Validation result
   */
  private validateBookName(book: string, bibleBooks: Set<string>): {
    isValid: boolean
    message: string
    details: any
  } {
    // Check if book name contains non-ASCII characters (Malayalam, Hindi, etc.)
    // If so, skip English book name validation - the Bible API will validate
    const hasNonAscii = /[^\x00-\x7F]/.test(book)
    if (hasNonAscii) {
      return {
        isValid: true,
        message: 'Non-English book name accepted',
        details: { book: book, isNonEnglish: true }
      }
    }

    const normalizedBook = book.toLowerCase().replace(/\./g, '')
    
    if (bibleBooks.has(normalizedBook)) {
      return {
        isValid: true,
        message: 'Valid book name',
        details: { book: normalizedBook }
      }
    }

    return {
      isValid: false,
      message: 'Unknown Bible book',
      details: {
        book: book,
        suggestion: 'Use standard Bible book names or abbreviations (e.g., "John", "1 Cor", "Ps")'
      }
    }
  }

  /**
   * Validates chapter and verse numbers for reasonableness.
   * 
   * @param chapter - Chapter number
   * @param startVerse - Start verse number
   * @param endVerse - End verse number
   * @returns Validation result
   */
  private validateChapterVerse(chapter: number, startVerse?: number, endVerse?: number): {
    isValid: boolean
    message: string
    details: any
  } {
    // Basic sanity checks
    if (chapter < 1 || chapter > 150) {
      return {
        isValid: false,
        message: 'Chapter number out of reasonable range',
        details: { chapter, validRange: '1-150' }
      }
    }

    if (startVerse !== undefined && (startVerse < 1 || startVerse > 176)) {
      return {
        isValid: false,
        message: 'Verse number out of reasonable range',
        details: { verse: startVerse, validRange: '1-176' }
      }
    }

    if (endVerse !== undefined && (endVerse < 1 || endVerse > 176)) {
      return {
        isValid: false,
        message: 'End verse number out of reasonable range',
        details: { verse: endVerse, validRange: '1-176' }
      }
    }

    if (startVerse !== undefined && endVerse !== undefined && endVerse <= startVerse) {
      return {
        isValid: false,
        message: 'End verse must be greater than start verse',
        details: { startVerse, endVerse }
      }
    }

    return {
      isValid: true,
      message: 'Valid chapter and verse numbers',
      details: { chapter, startVerse, endVerse }
    }
  }
}