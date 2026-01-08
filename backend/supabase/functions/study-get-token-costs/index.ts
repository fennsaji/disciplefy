import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { TokenService } from '../_shared/services/token-service.ts'
import type { StudyMode } from '../_shared/services/llm-types.ts'
import type { SupportedLanguage } from '../_shared/types/token-types.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    const url = new URL(req.url)
    const language = url.searchParams.get('language') as SupportedLanguage
    const mode = url.searchParams.get('mode') as StudyMode

    if (!language || !mode) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing required parameters: language and mode',
        }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Validate language
    if (!['en', 'hi', 'ml'].includes(language)) {
      return new Response(
        JSON.stringify({
          success: false,
          error: `Invalid language: ${language}. Must be en, hi, or ml.`,
        }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Validate mode
    const validModes = ['quick', 'standard', 'deep', 'lectio', 'sermon']
    if (!validModes.includes(mode)) {
      return new Response(
        JSON.stringify({
          success: false,
          error: `Invalid mode: ${mode}. Must be one of: ${validModes.join(', ')}`,
        }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client (needed for TokenService constructor)
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )

    // Create token service instance
    const tokenService = new TokenService(supabaseClient)

    // Calculate token cost
    const tokenCost = tokenService.calculateTokenCost(language, mode)

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          language,
          mode,
          tokenCost,
          calculatedAt: new Date().toISOString(),
        },
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (error) {
    console.error('Error calculating token cost:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Internal server error',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
