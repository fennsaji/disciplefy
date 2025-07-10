import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { ErrorHandler } from '../_shared/error-handler.ts'
import { RequestValidator } from '../_shared/request-validator.ts'
import { AnalyticsLogger } from '../_shared/analytics-logger.ts'
import { DailyVerseService } from './daily-verse-service.ts'

/**
 * Supabase Edge Function: Daily Verse
 * 
 * Provides daily Bible verses in multiple translations (ESV, Hindi, Malayalam)
 * with caching to minimize external API calls and ensure offline support.
 * 
 * Endpoints:
 * - GET /daily-verse - Returns today's verse in all translations
 * - GET /daily-verse?date=YYYY-MM-DD - Returns verse for specific date
 * 
 * Features:
 * - Multi-language support (ESV, Hindi, Malayalam)
 * - Daily caching to reduce API calls
 * - Fallback verses for API failures
 * - Analytics tracking for usage metrics
 */

serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('Daily verse function called with method:', req.method)
    console.log('Request URL:', req.url)
    
    // Validate HTTP method
    RequestValidator.validateHttpMethod(req.method, ['GET'])

    // Parse query parameters
    const url = new URL(req.url)
    const requestDate = url.searchParams.get('date')
    const userAgent = req.headers.get('user-agent') || 'unknown'

    // Initialize services
    const dailyVerseService = new DailyVerseService()
    const analyticsLogger = new AnalyticsLogger(dailyVerseService.getSupabaseClient())

    // Get daily verse data
    console.log('Getting daily verse for date:', requestDate || 'today')
    const verseData = await dailyVerseService.getDailyVerse(requestDate)
    console.log('Successfully retrieved verse:', verseData.reference)

    // Log analytics event
    await analyticsLogger.logEvent(
      'daily_verse_fetched',
      {
        date: verseData.date,
        hasCustomDate: !!requestDate,
        userAgent: userAgent.substring(0, 100), // Limit length
      },
      req.headers.get('x-forwarded-for')
    )

    // Return successful response
    return new Response(
      JSON.stringify({
        success: true,
        data: verseData,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=3600', // Cache for 1 hour
        },
      }
    )

  } catch (error) {
    // Log error event
    await analyticsLogger.logEvent(
      'daily_verse_error',
      { error: error.message },
      req.headers.get('x-forwarded-for')
    )

    return ErrorHandler.handleError(error, corsHeaders)
  }
})