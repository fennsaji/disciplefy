/**
 * Fetch Verse Edge Function
 *
 * Returns Bible verse text from the self-hosted Bible text service
 * (rs-backend, see _shared/services/bible-text-service.ts) for manual verse
 * addition and the scripture sheet. Supports single verses, ranges, whole
 * chapters and cross-chapter passages in English, Hindi and Malayalam.
 *
 * Versions: English BSB (default) or KJV, Hindi IRV, Malayalam IRV (default)
 * or Sathyavedapusthakam 1910 — pick with the optional `version` field.
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'
import { isBibleContentEnabled, isBibleApiCallsEnabled } from '../_shared/services/bible-availability.ts'
import { parseCrossChapterRange, parseVerseNumbers } from './passage.ts'
import { lookupVerses, VerseLookupError, type VerseLookupData, type VerseLookupRequest } from './verse-lookup.ts'

/**
 * Request payload structure
 */
interface FetchVerseRequest {
  readonly book: string      // Book name (e.g., "John", "1 Corinthians")
  readonly chapter: number   // Chapter number
  readonly verse_start: number // Starting verse number
  readonly verse_end?: number  // Optional ending verse for ranges (in end_chapter when given)
  readonly end_chapter?: number // Optional, for cross-chapter passages (e.g. 10:23-11:1)
  readonly language: 'en' | 'hi' | 'ml'
  readonly version?: string  // Optional: bsb | kjv | irv-hi | irv-ml | sv-ml (must match language)
}

type FetchVerseResponse = ApiSuccessResponse<VerseLookupData>

/**
 * Main handler for fetching verse
 */
async function handleFetchVerse(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  // Check maintenance mode FIRST
  await checkMaintenanceMode(req, services)

  // Admin kill switches: content blocked entirely, or lookups paused.
  if (!(await isBibleContentEnabled())) {
    throw new AppError('BIBLE_CONTENT_DISABLED', 'Bible content is currently unavailable.', 503)
  }
  if (!(await isBibleApiCallsEnabled())) {
    throw new AppError('BIBLE_API_DISABLED', 'Bible lookups are temporarily unavailable.', 503)
  }

  // Parse and validate request body
  const rawBody = await req.json() as FetchVerseRequest

  if (!rawBody.book || !rawBody.chapter || !rawBody.verse_start || !rawBody.language) {
    throw new AppError('VALIDATION_ERROR', 'book, chapter, verse_start, and language are required', 400)
  }

  // Accept only positive integers (numeric strings coerced) and use the
  // coerced numbers from here on.
  const numbers = parseVerseNumbers(rawBody)
  if ('error' in numbers) {
    throw new AppError('VALIDATION_ERROR', numbers.error, 400)
  }
  const body: FetchVerseRequest = { ...rawBody, ...numbers }

  if (!['en', 'hi', 'ml'].includes(body.language)) {
    throw new AppError('VALIDATION_ERROR', 'Invalid language. Must be en, hi, or ml', 400)
  }
  if (typeof body.book !== 'string' || body.book.length > 64) {
    throw new AppError('VALIDATION_ERROR', 'Invalid book name', 400)
  }

  // Optional cross-chapter end (older clients never send it)
  const crossChapter = parseCrossChapterRange(body)
  if (crossChapter && 'error' in crossChapter) {
    throw new AppError('VALIDATION_ERROR', crossChapter.error, 400)
  }

  let data: VerseLookupData
  try {
    data = await lookupVerses(body as VerseLookupRequest, crossChapter)
  } catch (error) {
    if (error instanceof VerseLookupError) throw new AppError(error.code, error.message, error.status)
    console.error('[FetchVerse] Bible text lookup failed:', error instanceof Error ? error.message : String(error))
    throw new AppError('SERVICE_UNAVAILABLE', 'Bible lookups are temporarily unavailable.', 503)
  }

  const responseData: FetchVerseResponse = { success: true, data }

  return new Response(JSON.stringify(responseData), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

// Create the simple function (no auth required for fetching verses)
createSimpleFunction(handleFetchVerse, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 30000
})
