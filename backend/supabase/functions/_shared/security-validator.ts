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
      // Validate scripture reference format:
      // - Book Chapter[:Verse][-ChapterOrVerseRange][, more]
      // - Chapter[:Verse][-ChapterOrVerseRange][, more]
      const scripturePattern = /^([1-3]?\s?[A-Za-z]+\s+\d+(?::\d+)?(?:-\d+(?::\d+)?)?(?:\s*,\s*\d+(?::\d+)?(?:-\d+(?::\d+)?)*)*|\d+(?::\d+)?(?:-\d+(?::\d+)?)?(?:\s*,\s*\d+(?::\d+)?(?:-\d+(?::\d+)?)*)*)$/;

      if (!scripturePattern.test(input.trim())) {
        result.isValid = false;
        result.eventType = 'INVALID_SCRIPTURE_FORMAT';
        result.riskScore = 0.5;
        result.message = 'Invalid scripture reference format';
        result.details = {
          expectedFormat: 'Book Chapter[:Verse][-ChapterOrVerse] or Chapter[:Verse][-ChapterOrVerse], with optional comma-separated items'
        };
        return result;
      }
    }

    // Advanced risk scoring based on multiple factors
    let riskScore = 0
    
    // Check for excessive special characters
    const specialCharCount = (input.match(/[^a-zA-Z0-9\s]/g) || []).length
    if (specialCharCount > input.length * 0.3) {
      riskScore += 0.3
    }

    // Check for excessive uppercase
    const uppercaseCount = (input.match(/[A-Z]/g) || []).length
    if (uppercaseCount > input.length * 0.5) {
      riskScore += 0.2
    }

    // Check for repeated patterns
    const repeatedPattern = /(.{3,})\1{2,}/
    if (repeatedPattern.test(input)) {
      riskScore += 0.4
    }

    result.riskScore = Math.min(riskScore, 1.0)
    
    // If risk score is too high, block the request
    if (result.riskScore > 0.7) {
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
    return input
      .replace(/<[^>]*>/g, '') // Remove HTML tags
      .replace(/[<>&"']/g, '') // Remove dangerous characters
      .trim()
      .substring(0, this.maxInputLength)
  }
}