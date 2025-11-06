/**
 * Get Token Pricing Packages Endpoint
 *
 * Public endpoint that returns all active token pricing packages
 * with discount information for display in frontend.
 *
 * Security: Public endpoint (no authentication required)
 * Rate Limiting: Applied via standard middleware
 *
 * @returns Array of pricing packages with token amounts and prices
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/utils/cors.ts'

interface PricingPackage {
  token_amount: number
  base_price_rupees: number
  discounted_price_rupees: number
  discount_percentage: number
  is_popular: boolean
}

/**
 * Main request handler
 */
Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders })
  }

  try {
    // Only allow GET requests
    if (req.method !== 'GET') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        {
          status: 405,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // Validate required environment variables
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')

    if (!supabaseUrl || !supabaseAnonKey) {
      const missingVars = []
      if (!supabaseUrl) missingVars.push('SUPABASE_URL')
      if (!supabaseAnonKey) missingVars.push('SUPABASE_ANON_KEY')

      console.error(`[GetTokenPricing] Missing required environment variables: ${missingVars.join(', ')}`)
      throw new Error(`Configuration error: Missing required environment variables: ${missingVars.join(', ')}`)
    }

    // Create Supabase client (anonymous access is fine for public pricing)
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey)

    // Fetch all active pricing packages
    const { data, error } = await supabaseClient
      .rpc('get_all_token_pricing_packages')
      .returns<PricingPackage[]>()

    if (error) {
      console.error('[GetTokenPricing] Error fetching pricing packages:', error)
      return new Response(
        JSON.stringify({
          error: 'Failed to fetch pricing packages',
          details: error.message
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // Return pricing packages
    return new Response(
      JSON.stringify({
        success: true,
        packages: data || []
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )

  } catch (error) {
    console.error('[GetTokenPricing] Unexpected error:', error)
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})
