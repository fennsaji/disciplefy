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
  } catch (error) {
    console.log('[ResponseParser] Attempting to repair malformed JSON response')
    
    // Try to extract JSON from response if there's additional text
    const jsonMatch = cleaned.match(/\{[\s\S]*\}/)
    if (jsonMatch) {
      cleaned = jsonMatch[0]
    }
    
    // Handle truncated JSON
    if (error instanceof Error && error.message.includes('Unterminated string')) {
      console.log('[ResponseParser] Detected truncated JSON, attempting repair')
      cleaned = repairTruncatedJSON(cleaned)
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
 * 
 * @param response - Parsed LLM response
 * @returns True if valid, false otherwise
 */
export function validateStudyGuideResponse(response: unknown): response is LLMResponse {
  if (!response || typeof response !== 'object') {
    console.error('[ResponseParser] Response is not an object')
    return false
  }

  const requiredFields = ['summary', 'interpretation', 'context', 'relatedVerses', 'reflectionQuestions', 'prayerPoints']
  const resp = response as Record<string, unknown>
  
  for (const field of requiredFields) {
    if (!(field in resp)) {
      console.error(`[ResponseParser] Missing required field: ${field}`)
      return false
    }
  }

  // Validate array fields
  const arrayFields = ['relatedVerses', 'reflectionQuestions', 'prayerPoints']
  for (const field of arrayFields) {
    if (!Array.isArray(resp[field])) {
      console.error(`[ResponseParser] Field ${field} is not an array`)
      return false
    }
    if ((resp[field] as unknown[]).length === 0) {
      console.error(`[ResponseParser] Field ${field} is empty`)
      return false
    }
  }

  // Validate string fields
  const stringFields = ['summary', 'context', 'interpretation']
  for (const field of stringFields) {
    if (typeof resp[field] !== 'string' || (resp[field] as string).trim().length === 0) {
      console.error(`[ResponseParser] Field ${field} is not a valid string`)
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
 * 
 * @param response - Raw LLM response
 * @returns Sanitized response
 */
export function sanitizeStudyGuideResponse(response: Record<string, unknown>): LLMResponse {
  return {
    summary: sanitizeText(response.summary as string),
    interpretation: sanitizeText((response.interpretation as string) || ''),
    context: sanitizeText(response.context as string),
    relatedVerses: (response.relatedVerses as string[]).map(verse => sanitizeText(verse)),
    reflectionQuestions: (response.reflectionQuestions as string[]).map(q => sanitizeText(q)),
    prayerPoints: (response.prayerPoints as string[]).map(point => sanitizeText(point))
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
