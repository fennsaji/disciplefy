/**
 * LLM Response Parser Module
 * 
 * Handles parsing, validation, and sanitization of LLM responses.
 * Provides retry mechanisms for malformed JSON and text sanitization.
 */

import type { LLMResponse, DailyVerseResponse } from '../llm-types.ts'

/**
 * Verse reference response structure (used when fetching from Bible API)
 */
export interface VerseReferenceResponse {
  reference: string
  referenceTranslations: {
    en: string
    hi: string
    ml: string
  }
}

/**
 * Fixes unescaped quote characters inside JSON string values using a state-machine
 * with lookahead.  When we are already inside a string and encounter a `"` that is
 * NOT followed (after optional whitespace) by `:`, `,`, `}`, or `]` we treat it as
 * an interior quote and escape it.  This covers the common case where an LLM embeds
 * theological inline quotes like `"only begotten"` inside a prose value field.
 *
 * @param json - JSON string that may contain unescaped interior quotes
 * @returns JSON string with interior quotes escaped
 */
export function fixUnescapedQuotesInJSON(json: string): string {
  let result = ''
  let i = 0
  let inString = false

  while (i < json.length) {
    const char = json[i]

    // Propagate already-escaped sequences unchanged
    if (inString && char === '\\' && i + 1 < json.length) {
      result += char + json[i + 1]
      i += 2
      continue
    }

    if (char === '"') {
      if (!inString) {
        // Opening quote of a key or value
        inString = true
        result += char
        i++
      } else {
        // Determine whether this `"` is the closing quote of the current string or
        // an interior unescaped quote.  We do a lookahead: after skipping whitespace,
        // if the next structural character is `:`, `,`, `}`, or `]` then it is a
        // valid closing quote; otherwise we escape it.
        const trimmedRest = json.slice(i + 1).trimStart()
        const isClosing =
          trimmedRest.startsWith(':') ||
          trimmedRest.startsWith(',') ||
          trimmedRest.startsWith('}') ||
          trimmedRest.startsWith(']') ||
          trimmedRest.length === 0

        if (isClosing) {
          inString = false
          result += char
        } else {
          result += '\\"'
        }
        i++
      }
    } else {
      result += char
      i++
    }
  }

  return result
}

/**
 * Cleans JSON response to handle common formatting issues with multilingual content.
 *
 * @param response - Raw JSON response from LLM
 * @returns Cleaned JSON string
 */
export function cleanJSONResponse(response: string): string {
  let cleaned = response.trim()

  // Remove any markdown code block markers
  cleaned = cleaned.replace(/^```json\s*/i, '').replace(/\s*```$/, '')

  try {
    JSON.parse(cleaned)
    return cleaned
  } catch {
    console.log('[ResponseParser] Attempting to repair malformed JSON response')

    // Try to extract JSON from response if there's additional text
    const jsonMatch = cleaned.match(/\{[\s\S]*\}/)
    if (jsonMatch) {
      cleaned = jsonMatch[0]
    }

    // Try parsing again after extraction
    try {
      JSON.parse(cleaned)
      return cleaned
    } catch (error) {
      // Handle truncated JSON (Unterminated string)
      if (error instanceof Error && error.message.includes('Unterminated string')) {
        console.log('[ResponseParser] Detected truncated JSON, attempting repair')
        cleaned = repairTruncatedJSON(cleaned)
      } else {
        // Mid-value parse error (e.g., unescaped " inside a string value)
        console.log('[ResponseParser] Detected mid-value parse error, attempting to fix unescaped quotes')
        const fixed = fixUnescapedQuotesInJSON(cleaned)
        try {
          JSON.parse(fixed)
          console.log('[ResponseParser] Unescaped-quote fix succeeded')
          return fixed
        } catch {
          // Fix did not fully resolve the issue; fall back to truncation repair
          console.log('[ResponseParser] Unescaped-quote fix insufficient, falling back to truncation repair')
          cleaned = repairTruncatedJSON(cleaned)
        }
      }
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
export function repairTruncatedJSON(json: string): string {
  let repaired = json
  
  // Count unclosed braces and brackets
  const openBraces = (repaired.match(/\{/g) || []).length
  const closeBraces = (repaired.match(/\}/g) || []).length
  const openBrackets = (repaired.match(/\[/g) || []).length
  const closeBrackets = (repaired.match(/\]/g) || []).length
  
  // Check if we're in the middle of a string
  const lines = repaired.split('\n')
  const lastLine = lines[lines.length - 1]
  const quotesInLastLine = (lastLine.match(/"/g) || []).length
  
  // If we're in an unterminated string, close it
  if (quotesInLastLine % 2 === 1) {
    repaired += '"'
  }
  
  // Remove trailing commas
  repaired = repaired.replace(/,\s*$/, '')
  
  // Close unclosed arrays
  for (let i = 0; i < openBrackets - closeBrackets; i++) {
    repaired += ']'
  }
  
  // Close unclosed objects
  for (let i = 0; i < openBraces - closeBraces; i++) {
    repaired += '}'
  }
  
  console.log('[ResponseParser] JSON repair attempted')
  return repaired
}

/**
 * Validates LLM response structure for study guides.
 * Ensures all 14 required fields are present and valid.
 * 
 * @param response - Parsed LLM response
 * @returns True if valid, false otherwise
 */
export function validateStudyGuideResponse(response: unknown): response is LLMResponse {
  if (!response || typeof response !== 'object') {
    console.error('[ResponseParser] Response is not an object')
    return false
  }

  const resp = response as Record<string, unknown>
  
  // Validate all 14 required fields are present
  const requiredFields = [
    'summary',
    'interpretation',
    'context',
    'relatedVerses',
    'reflectionQuestions',
    'prayerPoints',
    'summaryInsights',
    'interpretationInsights',
    'reflectionAnswers',
    'contextQuestion',
    'summaryQuestion',
    'relatedVersesQuestion',
    'reflectionQuestion',
    'prayerQuestion'
  ]
  
  for (const field of requiredFields) {
    if (!(field in resp)) {
      console.error(`[ResponseParser] Missing required field: ${field}`)
      return false
    }
  }

  // Validate base array fields
  const baseArrayFields = ['relatedVerses', 'reflectionQuestions', 'prayerPoints']
  for (const field of baseArrayFields) {
    if (!Array.isArray(resp[field])) {
      console.error(`[ResponseParser] Field ${field} is not an array`)
      return false
    }
    if ((resp[field] as unknown[]).length === 0) {
      console.error(`[ResponseParser] Field ${field} is empty`)
      return false
    }
  }

  // Validate insights array fields (should have 2-5 items)
  const insightArrayFields = ['summaryInsights', 'interpretationInsights', 'reflectionAnswers']
  for (const field of insightArrayFields) {
    if (!Array.isArray(resp[field])) {
      console.error(`[ResponseParser] Field ${field} is not an array`)
      return false
    }
    const arr = resp[field] as unknown[]
    if (!arr.every((item) => typeof item === 'string')) {
      console.error(`[ResponseParser] Field ${field} contains non-string elements`)
      return false
    }
    if (arr.length < 2 || arr.length > 5) {
      console.error(`[ResponseParser] Field ${field} should have 2-5 items, got ${arr.length}`)
      return false
    }
  }

  // Validate base string fields
  const baseStringFields = ['summary', 'context', 'interpretation']
  for (const field of baseStringFields) {
    if (typeof resp[field] !== 'string' || (resp[field] as string).trim().length === 0) {
      console.error(`[ResponseParser] Field ${field} is not a valid string`)
      return false
    }
  }

  // Validate question string fields
  const questionFields = [
    'contextQuestion',
    'summaryQuestion',
    'relatedVersesQuestion',
    'reflectionQuestion',
    'prayerQuestion'
  ]

  for (const field of questionFields) {
    if (typeof resp[field] !== 'string') {
      console.error(`[ResponseParser] ${field} is not a string`)
      return false
    }
    if ((resp[field] as string).trim().length === 0) {
      console.error(`[ResponseParser] ${field} is empty`)
      return false
    }
  }

  return true
}

/**
 * Sanitizes text content to prevent XSS and ensure data quality.
 * Used for short text fields like titles and references.
 * 
 * @param text - Text to sanitize
 * @returns Sanitized text
 */
export function sanitizeText(text: string): string {
  if (typeof text !== 'string') {
    return ''
  }

  return text
    .trim()
    .replace(/\s+/g, ' ')
    .replace(/[<>]/g, '')
    .substring(0, 2000)
}

/**
 * Sanitizes Markdown text while preserving formatting structure.
 * Used for follow-up responses and Markdown content.
 * 
 * @param text - Markdown text to sanitize
 * @returns Sanitized Markdown with preserved structure
 */
export function sanitizeMarkdownText(text: string): string {
  if (typeof text !== 'string') {
    return ''
  }

  return text
    .replace(/[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]/g, '')
    .replace(/[<>]/g, '')
    .split('\n')
    .map(line => line.trimEnd())
    .join('\n')
    .replace(/^\n+/, '')
    .replace(/\n+$/, '')
    .substring(0, 10000)
}

/**
 * Sanitizes study guide response for security and consistency.
 * All 14 fields are required and will be sanitized.
 * 
 * @param response - Raw LLM response
 * @returns Sanitized response
 */
export function sanitizeStudyGuideResponse(response: Record<string, unknown>): LLMResponse {
  return {
    summary: sanitizeText(response.summary as string),
    interpretation: sanitizeText(response.interpretation as string),
    context: sanitizeText(response.context as string),
    passage: sanitizeText((response.passage as string) || ''),
    relatedVerses: (response.relatedVerses as string[]).map(verse => sanitizeText(verse)),
    reflectionQuestions: (response.reflectionQuestions as string[]).map(q => sanitizeText(q)),
    prayerPoints: (response.prayerPoints as string[]).map(point => sanitizeText(point)),
    interpretationInsights: (response.interpretationInsights as string[])
      .map(sanitizeText)
      .filter(insight => insight.length > 0 && insight.length <= 150)
      .slice(0, 5),
    summaryInsights: (response.summaryInsights as string[])
      .map(sanitizeText)
      .slice(0, 5),
    reflectionAnswers: (response.reflectionAnswers as string[])
      .map(sanitizeText)
      .slice(0, 5),
    contextQuestion: sanitizeText(response.contextQuestion as string),
    summaryQuestion: sanitizeText(response.summaryQuestion as string),
    relatedVersesQuestion: sanitizeText(response.relatedVersesQuestion as string),
    reflectionQuestion: sanitizeText(response.reflectionQuestion as string),
    prayerQuestion: sanitizeText(response.prayerQuestion as string)
  }
}

/**
 * Parses verse reference response from LLM.
 * 
 * @param rawResponse - Raw response from LLM
 * @returns Parsed reference data
 */
export function parseVerseReferenceResponse(rawResponse: string): VerseReferenceResponse {
  const cleaned = cleanJSONResponse(rawResponse)
  const parsed = JSON.parse(cleaned)

  if (!parsed.reference || typeof parsed.reference !== 'string') {
    throw new Error('Missing or invalid reference field')
  }

  if (!parsed.referenceTranslations || typeof parsed.referenceTranslations !== 'object') {
    throw new Error('Missing or invalid referenceTranslations field')
  }

  const { en, hi, ml } = parsed.referenceTranslations

  if (!en || typeof en !== 'string') {
    throw new Error('Missing or invalid English reference translation')
  }

  if (!hi || typeof hi !== 'string') {
    throw new Error('Missing or invalid Hindi reference translation')
  }

  if (!ml || typeof ml !== 'string') {
    throw new Error('Missing or invalid Malayalam reference translation')
  }

  return {
    reference: sanitizeText(parsed.reference),
    referenceTranslations: {
      en: sanitizeText(en),
      hi: sanitizeText(hi),
      ml: sanitizeText(ml)
    }
  }
}

/**
 * Parses and validates full verse response from LLM.
 * 
 * @param rawResponse - Raw response from LLM
 * @returns Parsed and validated verse response
 */
export function parseFullVerseResponse(rawResponse: string): DailyVerseResponse {
  const cleaned = cleanJSONResponse(rawResponse)
  console.log('[ResponseParser] Cleaned LLM response:', cleaned.substring(0, 500))
  
  const parsed = JSON.parse(cleaned)
  console.log('[ResponseParser] Parsed LLM response structure:', {
    hasReference: !!parsed.reference,
    hasReferenceTranslations: !!parsed.referenceTranslations,
    hasTranslations: !!parsed.translations,
    translationKeys: parsed.translations ? Object.keys(parsed.translations) : []
  })
  
  // Validate structure
  if (!parsed.reference || typeof parsed.reference !== 'string') {
    throw new Error('Missing or invalid reference field')
  }
  
  if (!parsed.referenceTranslations || typeof parsed.referenceTranslations !== 'object') {
    throw new Error('Missing or invalid referenceTranslations field')
  }
  
  const { en, hi, ml } = parsed.referenceTranslations
  
  if (!en || typeof en !== 'string') {
    throw new Error('Missing or invalid English reference translation')
  }
  
  if (!hi || typeof hi !== 'string') {
    console.warn('[ResponseParser] Missing Hindi reference translation, using fallback')
  }
  
  if (!ml || typeof ml !== 'string') {
    console.warn('[ResponseParser] Missing Malayalam reference translation, using fallback')
  }
  
  if (!parsed.translations || typeof parsed.translations !== 'object') {
    throw new Error('Missing or invalid translations field')
  }
  
  // Support both 'hindi'/'malayalam' (LLM output) and 'hi'/'ml' (standard) keys
  const esv = parsed.translations.esv
  const hindiTranslation = parsed.translations.hi || parsed.translations.hindi
  const malayalamTranslation = parsed.translations.ml || parsed.translations.malayalam

  if (!esv || typeof esv !== 'string') {
    throw new Error('Missing or invalid ESV translation')
  }

  if (!hindiTranslation || typeof hindiTranslation !== 'string') {
    console.warn('[ResponseParser] LLM did not return Hindi translation')
  }

  if (!malayalamTranslation || typeof malayalamTranslation !== 'string') {
    console.warn('[ResponseParser] LLM did not return Malayalam translation')
  }

  return {
    reference: sanitizeText(parsed.reference),
    referenceTranslations: {
      en: sanitizeText(en),
      hi: sanitizeText(hi),
      ml: sanitizeText(ml)
    },
    translations: {
      esv: sanitizeText(esv),
      hi: sanitizeText(hindiTranslation),
      ml: sanitizeText(malayalamTranslation)
    }
  }
}

/**
 * Attempts to parse JSON with cleaning and repair.
 * 
 * @param rawResponse - Raw response string
 * @returns Parsed JSON object
 */
export function parseJSONSafely(rawResponse: string): unknown {
  const cleaned = cleanJSONResponse(rawResponse)
  
  try {
    return JSON.parse(cleaned)
  } catch (error) {
    // Try repair as last resort
    const repaired = repairTruncatedJSON(cleaned)
    return JSON.parse(repaired)
  }
}
