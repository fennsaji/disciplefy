import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface PlanPricing {
  amount: number
  currency: string
  formatted: string
}

interface ProviderPricing {
  [planCode: string]: PlanPricing
}

interface PricingResponse {
  success: boolean
  data: {
    [provider: string]: ProviderPricing
  }
  error?: string
}

/**
 * GET /subscription-pricing
 *
 * Fetches subscription pricing for all plans and providers from database.
 * Returns formatted pricing data for frontend consumption.
 *
 * Response format:
 * {
 *   "success": true,
 *   "data": {
 *     "razorpay": {
 *       "standard": {"amount": 7900, "currency": "INR", "formatted": "₹79"},
 *       "plus": {"amount": 14900, "currency": "INR", "formatted": "₹149"},
 *       "premium": {"amount": 49900, "currency": "INR", "formatted": "₹499"}
 *     },
 *     "google_play": {...},
 *     "apple_appstore": {...}
 *   }
 * }
 */
Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Fetch all pricing data from subscription_plan_providers
    const { data: pricingData, error: pricingError } = await supabase
      .from('subscription_plan_providers')
      .select(`
        provider,
        base_price_minor,
        currency,
        region,
        subscription_plans!inner (
          plan_code,
          plan_name
        )
      `)
      .eq('is_active', true)
      .order('provider')

    if (pricingError) {
      console.error('Error fetching pricing data:', pricingError)
      throw pricingError
    }

    if (!pricingData || pricingData.length === 0) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'No pricing data found',
        } as PricingResponse),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // Format pricing data by provider
    const formattedPricing: { [provider: string]: ProviderPricing } = {}

    for (const row of pricingData) {
      const provider = row.provider
      const planCode = (row.subscription_plans as any).plan_code
      const amount = row.base_price_minor
      const currency = row.currency

      // Initialize provider object if not exists
      if (!formattedPricing[provider]) {
        formattedPricing[provider] = {}
      }

      // Format price based on currency
      const formatted = formatPrice(amount, currency)

      formattedPricing[provider][planCode] = {
        amount,
        currency,
        formatted,
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: formattedPricing,
      } as PricingResponse),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    console.error('Error in subscription-pricing endpoint:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Internal server error',
      } as PricingResponse),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})

/**
 * Format price from minor units (paise/cents) to display string
 * @param amountMinor - Price in smallest currency unit (paise for INR, cents for USD)
 * @param currency - Currency code (INR, USD, etc.)
 * @returns Formatted price string (e.g., "₹79", "$9.99")
 */
function formatPrice(amountMinor: number, currency: string): string {
  const amountMajor = amountMinor / 100

  switch (currency) {
    case 'INR':
      return `₹${Math.floor(amountMajor)}`
    case 'USD':
      return `$${amountMajor.toFixed(2)}`
    case 'EUR':
      return `€${amountMajor.toFixed(2)}`
    case 'GBP':
      return `£${amountMajor.toFixed(2)}`
    default:
      return `${currency} ${amountMajor.toFixed(2)}`
  }
}
