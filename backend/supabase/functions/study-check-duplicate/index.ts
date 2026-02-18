/**
 * Lightweight duplicate check endpoint
 *
 * This function checks if a study is already being generated WITHOUT
 * creating a worker for the main study-generate-v2 function.
 *
 * If duplicate found, returns polling instructions.
 * If no duplicate, client should call study-generate-v2.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { crypto } from 'https://deno.land/std@0.177.0/crypto/mod.ts'

// Hash function for consistent duplicate detection
async function generateInputHash(
  inputValue: string,
  inputType: string,
  language: string,
  studyMode: string
): Promise<string> {
  const combined = `${inputValue.toLowerCase().trim()}|${inputType}|${language}|${studyMode}`
  const encoder = new TextEncoder()
  const data = encoder.encode(combined)
  const hashBuffer = await crypto.subtle.digest('SHA-256', data)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
}

Deno.serve(async (req) => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const inputValue = url.searchParams.get('input_value')
    const inputType = url.searchParams.get('input_type') || 'question'
    const language = url.searchParams.get('language') || 'en'
    const studyMode = url.searchParams.get('study_mode') || 'standard'

    if (!inputValue) {
      return new Response(
        JSON.stringify({ error: 'Missing input_value parameter' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Generate hash
    const inputHash = await generateInputHash(inputValue, inputType, language, studyMode)

    // Check for existing in-progress or recently completed record
    const { data: inProgressStudy } = await supabase
      .from('study_guides_in_progress')
      .select('*')
      .eq('input_type', inputType)
      .eq('input_value_hash', inputHash)
      .eq('language', language)
      .eq('study_mode', studyMode)
      .in('status', ['generating', 'completed'])
      .maybeSingle()

    if (!inProgressStudy) {
      // No duplicate, client should proceed with generation
      return new Response(
        JSON.stringify({
          isDuplicate: false,
          action: 'generate'
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Check if stale (>5 minutes without updates)
    const recordAge = Date.now() - new Date(inProgressStudy.last_updated_at).getTime()
    const MAX_RECORD_AGE = 5 * 60 * 1000

    if (recordAge >= MAX_RECORD_AGE && inProgressStudy.status === 'generating') {
      // Stale record, mark as failed and allow new generation
      await supabase
        .from('study_guides_in_progress')
        .update({ status: 'failed', error_code: 'TIMEOUT', error_message: 'Stale record detected' })
        .eq('id', inProgressStudy.id)

      return new Response(
        JSON.stringify({
          isDuplicate: false,
          action: 'generate',
          note: 'Stale record cleaned'
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Active duplicate found
    if (inProgressStudy.status === 'completed') {
      // Check if in main table
      const { data: completedStudy } = await supabase
        .from('study_guides')
        .select('id')
        .eq('input_type', inputType)
        .eq('input_value_hash', inputHash)
        .eq('language', language)
        .eq('study_mode', studyMode)
        .maybeSingle()

      if (completedStudy) {
        return new Response(
          JSON.stringify({
            isDuplicate: true,
            action: 'fetch_completed',
            studyGuideId: completedStudy.id
          }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
    }

    // Generation in progress
    return new Response(
      JSON.stringify({
        isDuplicate: true,
        action: 'poll',
        inProgressId: inProgressStudy.id,
        ageSeconds: Math.floor(recordAge / 1000)
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('[CHECK-DUPLICATE] Error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error instanceof Error ? error.message : 'Unknown error' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
