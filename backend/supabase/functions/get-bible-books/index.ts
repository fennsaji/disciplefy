import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface BibleBooksData {
  english: string[]
  hindi: string[]
  malayalam: string[]
  englishAbbreviations: string[]
  hindiAlternates: string[]
  malayalamAlternates: string[]
}

interface BibleBooksResponse {
  success: boolean
  data?: {
    version: number
    updated_at: string
    data: BibleBooksData
  }
  error?: string
}

/**
 * GET /get-bible-books
 *
 * Returns all canonical Bible book names and alternates for all supported languages.
 * Data is sourced from the bible_book_config table (single-row, id = 1).
 *
 * This endpoint is public (no auth required) and CDN-cacheable.
 * Frontend caches the response locally for 30 days.
 *
 * Response format:
 * {
 *   "success": true,
 *   "data": {
 *     "version": 1,
 *     "updated_at": "2026-02-22T00:00:00Z",
 *     "data": {
 *       "english": [...],
 *       "hindi": [...],
 *       "malayalam": [...],
 *       "englishAbbreviations": [...],
 *       "hindiAlternates": [...],
 *       "malayalamAlternates": [...]
 *     }
 *   }
 * }
 */
Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  if (req.method !== 'GET') {
    return new Response(
      JSON.stringify({ success: false, error: 'Method not allowed' } as BibleBooksResponse),
      {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { data, error } = await supabase
      .from('bible_book_config')
      .select('version, data, updated_at')
      .eq('id', 1)
      .single()

    if (error) {
      console.error('[get-bible-books] DB error:', error.message)
      throw error
    }

    if (!data) {
      return new Response(
        JSON.stringify({ success: false, error: 'Bible book config not found' } as BibleBooksResponse),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          version: data.version,
          updated_at: data.updated_at,
          data: data.data as BibleBooksData,
        },
      } as BibleBooksResponse),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          // CDN caches for 1 day; clients apply their own 30-day TTL on top
          'Cache-Control': 'public, max-age=86400',
        },
      }
    )
  } catch (error) {
    console.error('[get-bible-books] Unexpected error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Internal server error',
      } as BibleBooksResponse),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})
