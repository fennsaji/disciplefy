/**
 * Get Token Pricing Edge Function
 *
 * Returns current token pricing configuration and available packages.
 * This endpoint provides dynamic pricing that can be updated without
 * redeploying the frontend application.
 *
 * Query Parameters:
 * - region: Region code (default: IN)
 *
 * Returns:
 * - tokensPerRupee: Current exchange rate (e.g., 4)
 * - packages: Array of available token packages with pricing
 * - effectiveFrom: When current pricing became active
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/utils/cors.ts'

interface TokenPackage {
  id: number
  tokens: number
  rupees: number // Will be converted from DECIMAL to INTEGER
  discount_percentage: number
  is_popular: boolean
  sort_order: number
}

interface TokenPricingConfig {
  tokens_per_rupee: number
  effective_from: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Parse query parameters
    const url = new URL(req.url)
    const region = url.searchParams.get('region') || 'IN'

    console.log('[get-token-pricing] Request:', { region })

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Fetch current pricing configuration
    const { data: pricingData, error: pricingError } = await supabase
      .rpc('get_current_token_pricing', { p_region: region })
      .single()

    if (pricingError) {
      console.error('[get-token-pricing] Pricing fetch error:', pricingError)
      // Use fallback values if database query fails
      const fallbackResponse = {
        success: true,
        tokensPerRupee: 2,
        packages: [
          { tokens: 20, rupees: 10, discount: 0, isPopular: false },
          { tokens: 50, rupees: 22, discount: 10, isPopular: false },
          { tokens: 100, rupees: 40, discount: 20, isPopular: true },
          { tokens: 200, rupees: 75, discount: 25, isPopular: false },
          { tokens: 400, rupees: 140, discount: 30, isPopular: false },
          { tokens: 1000, rupees: 300, discount: 40, isPopular: false }
        ],
        effectiveFrom: new Date().toISOString(),
        source: 'fallback'
      }

      return new Response(
        JSON.stringify(fallbackResponse),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const pricing = pricingData as TokenPricingConfig

    // Fetch available token packages
    const { data: packagesData, error: packagesError } = await supabase
      .rpc('get_token_packages', { p_region: region })

    if (packagesError) {
      console.error('[get-token-pricing] Packages fetch error:', packagesError)
      throw new Error('Failed to fetch token packages')
    }

    const packages = (packagesData as TokenPackage[]).map(pkg => ({
      tokens: pkg.tokens,
      rupees: Math.round(pkg.rupees), // Convert DECIMAL to INTEGER for frontend
      discount: pkg.discount_percentage,
      isPopular: pkg.is_popular
    }))

    // Build response
    const response = {
      success: true,
      tokensPerRupee: pricing.tokens_per_rupee,
      packages: packages,
      effectiveFrom: pricing.effective_from,
      region: region
    }

    console.log('[get-token-pricing] Returning pricing:', {
      tokensPerRupee: pricing.tokens_per_rupee,
      packageCount: packages.length
    })

    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  } catch (error) {
    console.error('[get-token-pricing] Error:', error)

    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Internal server error'
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
