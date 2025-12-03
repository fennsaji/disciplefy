/**
 * Verify Email Edge Function
 * 
 * Handles email verification when user clicks the verification link.
 * Validates the token and updates the email_verified field in user_profiles.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { handleCors } from '../_shared/utils/cors.ts'
import { config } from '../_shared/core/config.ts'

Deno.serve(async (req) => {
  const corsHeaders = handleCors(req)
  
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    // Accept both GET (from email link) and POST
    const url = new URL(req.url)
    let token: string | null = null
    let email: string | null = null

    if (req.method === 'GET') {
      token = url.searchParams.get('token')
      email = url.searchParams.get('email')
    } else if (req.method === 'POST') {
      const body = await req.json()
      token = body.token
      email = body.email
    } else {
      return new Response(
        JSON.stringify({ success: false, error: 'Method not allowed' }),
        { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!token || !email) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing token or email' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create admin client
    const supabaseAdmin = createClient(
      config.supabaseUrl,
      config.supabaseServiceKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Find user profile by email directly (efficient single-row lookup)
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('user_profiles')
      .select('id, email_verification_token, email_verification_token_expires_at, email_verified')
      .eq('email', email)
      .single()
    
    if (profileError || !profile) {
      // Log without PII - use generic message
      console.error('[VERIFY EMAIL] User not found for provided identifier, error:', profileError?.code || 'no_profile')
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid verification link' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Use profile.id as the user identifier (non-PII)
    const userId = profile.id

    // Check if already verified
    if (profile.email_verified) {
      // Redirect to success page or return success
      const appUrl = Deno.env.get('APP_URL') || 'https://www.disciplefy.in'
      
      if (req.method === 'GET') {
        return Response.redirect(`${appUrl}/email-verified?status=already_verified`, 302)
      }
      
      return new Response(
        JSON.stringify({ success: true, message: 'Email already verified', already_verified: true }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate token
    if (profile.email_verification_token !== token) {
      console.error('[VERIFY EMAIL] Token mismatch')
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid verification link' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check expiry
    if (profile.email_verification_token_expires_at) {
      const expiryDate = new Date(profile.email_verification_token_expires_at)
      if (expiryDate < new Date()) {
        console.error('[VERIFY EMAIL] Token expired')
        return new Response(
          JSON.stringify({ success: false, error: 'Verification link has expired. Please request a new one.' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // Update profile to mark as verified and clear token
    const { error: updateError } = await supabaseAdmin
      .from('user_profiles')
      .update({
        email_verified: true,
        email_verification_token: null,
        email_verification_token_expires_at: null
      })
      .eq('id', userId)

    if (updateError) {
      console.error('[VERIFY EMAIL] Update error for user_id:', userId, 'error:', updateError.code)
      return new Response(
        JSON.stringify({ success: false, error: 'Verification failed' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[VERIFY EMAIL] Email verified successfully for user_id: ${userId}`)

    // For GET requests (from email link), redirect to success page
    if (req.method === 'GET') {
      const appUrl = Deno.env.get('APP_URL') || 'https://www.disciplefy.in'
      return Response.redirect(`${appUrl}/email-verified?status=success`, 302)
    }

    // For POST requests, return JSON
    return new Response(
      JSON.stringify({ success: true, message: 'Email verified successfully' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('[VERIFY EMAIL] Unexpected error:', error)
    return new Response(
      JSON.stringify({ success: false, error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
