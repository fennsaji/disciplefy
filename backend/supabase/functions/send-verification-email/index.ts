/**
 * Send Verification Email Edge Function
 * 
 * Sends a custom verification email to users who signed up with email/password.
 * This is separate from Supabase's built-in confirmation because we use
 * delayed verification (users can access app immediately, verify later).
 * 
 * The verification token is stored in user_profiles and validated when
 * the user clicks the verification link.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { handleCors } from '../_shared/utils/cors.ts'
import { config } from '../_shared/core/config.ts'

// Helper functions for responses
function createSuccessResponse(data: Record<string, unknown>, corsHeaders: Record<string, string>): Response {
  return new Response(
    JSON.stringify({ success: true, ...data }),
    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

function createErrorResponse(message: string, status: number, corsHeaders: Record<string, string>): Response {
  return new Response(
    JSON.stringify({ success: false, error: message }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

// HTML escape helper to prevent XSS/injection attacks
function escapeHtml(unsafe: string): string {
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')
    .replace(/\//g, '&#x2F;')
}

// Generate a secure random token
function generateVerificationToken(): string {
  const array = new Uint8Array(32)
  crypto.getRandomValues(array)
  return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('')
}

// Generate verification URL
function generateVerificationUrl(token: string, email: string): string {
  const baseUrl = Deno.env.get('APP_URL') || 'https://www.disciplefy.in'
  const params = new URLSearchParams({
    token,
    email,
    type: 'email_verification'
  })
  return `${baseUrl}/verify-email?${params.toString()}`
}

// Send email using Resend API (or log for local development)
async function sendEmailWithResend(
  to: string,
  subject: string,
  htmlContent: string,
  verificationUrl: string
): Promise<{ success: boolean; error?: string }> {
  const resendApiKey = Deno.env.get('RESEND_API_KEY')
  
  if (!resendApiKey) {
    // In local development, log the verification URL instead of sending email
    console.log('[VERIFY EMAIL] ==========================================')
    console.log('[VERIFY EMAIL] RESEND_API_KEY not configured - LOCAL DEV MODE')
    console.log('[VERIFY EMAIL] Email would be sent to:', to)
    console.log('[VERIFY EMAIL] Verification URL:', verificationUrl)
    console.log('[VERIFY EMAIL] ==========================================')
    // Return success for local testing
    return { success: true }
  }

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'Disciplefy <noreply@disciplefy.in>',
        to: [to],
        subject,
        html: htmlContent,
      }),
    })

    if (!response.ok) {
      const errorData = await response.json()
      console.error('[VERIFY EMAIL] Resend API error:', errorData)
      return { success: false, error: errorData.message || 'Failed to send email' }
    }

    const data = await response.json()
    console.log('[VERIFY EMAIL] Email sent successfully:', data.id)
    return { success: true }
  } catch (error) {
    console.error('[VERIFY EMAIL] Error sending email:', error)
    return { success: false, error: 'Failed to send email' }
  }
}

// Generate email HTML content
function generateEmailHtml(verificationUrl: string, userName?: string): string {
  // Sanitize userName: escape HTML entities and truncate to max 50 chars
  const MAX_NAME_LENGTH = 50
  let safeName = userName ? userName.trim().slice(0, MAX_NAME_LENGTH) : null
  if (safeName) {
    safeName = escapeHtml(safeName)
  }
  const greeting = safeName ? `Hi ${safeName}` : 'Hi there'
  
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Verify Your Email - Disciplefy</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="text-align: center; margin-bottom: 30px;">
    <h1 style="color: #6A4FB6; margin: 0;">Disciplefy</h1>
    <p style="color: #666; margin-top: 5px;">Your Bible Study Companion</p>
  </div>
  
  <div style="background: #f9f9f9; border-radius: 12px; padding: 30px; margin-bottom: 20px;">
    <h2 style="margin-top: 0; color: #333;">${greeting}!</h2>
    <p>Thank you for signing up for Disciplefy. Please verify your email address to secure your account and unlock all features.</p>
    
    <div style="text-align: center; margin: 30px 0;">
      <a href="${verificationUrl}" 
         style="display: inline-block; background: #6A4FB6; color: white; padding: 14px 32px; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px;">
        Verify Email Address
      </a>
    </div>
    
    <p style="color: #666; font-size: 14px;">
      If the button doesn't work, copy and paste this link into your browser:
      <br>
      <a href="${verificationUrl}" style="color: #6A4FB6; word-break: break-all;">${verificationUrl}</a>
    </p>
  </div>
  
  <div style="text-align: center; color: #999; font-size: 12px;">
    <p>This link will expire in 24 hours.</p>
    <p>If you didn't create an account with Disciplefy, you can safely ignore this email.</p>
    <p style="margin-top: 20px;">&copy; ${new Date().getFullYear()} Disciplefy. All rights reserved.</p>
  </div>
</body>
</html>
`
}

Deno.serve(async (req) => {
  const corsHeaders = handleCors(req)
  
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    // Only allow POST
    if (req.method !== 'POST') {
      return createErrorResponse('Method not allowed', 405, corsHeaders)
    }

    // Get authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return createErrorResponse('Missing authorization header', 401, corsHeaders)
    }

    // Create Supabase clients
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

    const supabaseUser = createClient(
      config.supabaseUrl,
      config.supabaseAnonKey,
      {
        global: {
          headers: { Authorization: authHeader }
        }
      }
    )

    // Get current user
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()
    
    if (userError || !user) {
      console.error('[VERIFY EMAIL] Auth error:', userError)
      return createErrorResponse('Unauthorized', 401, corsHeaders)
    }

    // Check if user is email provider
    const provider = user.app_metadata?.provider
    if (provider !== 'email') {
      return createErrorResponse('Verification only required for email signup users', 400, corsHeaders)
    }

    // Check if already verified in profile
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('user_profiles')
      .select('email_verified, first_name')
      .eq('id', user.id)
      .single()

    if (profileError) {
      console.error('[VERIFY EMAIL] Profile fetch error:', profileError)
      return createErrorResponse('Failed to fetch user profile', 500, corsHeaders)
    }

    if (profile?.email_verified) {
      return createSuccessResponse({ 
        message: 'Email already verified',
        already_verified: true 
      }, corsHeaders)
    }

    // Generate verification token
    const verificationToken = generateVerificationToken()
    const tokenExpiry = new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours

    // Store token in user_profiles
    const { error: updateError } = await supabaseAdmin
      .from('user_profiles')
      .update({
        email_verification_token: verificationToken,
        email_verification_token_expires_at: tokenExpiry.toISOString()
      })
      .eq('id', user.id)

    if (updateError) {
      console.error('[VERIFY EMAIL] Token storage error:', updateError)
      return createErrorResponse('Failed to generate verification token', 500, corsHeaders)
    }

    // Defensive check: ensure user has a valid email
    if (!user.email || typeof user.email !== 'string' || user.email.trim() === '') {
      console.error('[VERIFY EMAIL] User has no valid email address, user_id:', user.id)
      return createErrorResponse('User email not available', 400, corsHeaders)
    }

    const userEmail = user.email.trim()

    // Generate verification URL and email content
    const verificationUrl = generateVerificationUrl(verificationToken, userEmail)
    const emailHtml = generateEmailHtml(verificationUrl, profile?.first_name)

    // Send email (or log URL in local dev)
    const emailResult = await sendEmailWithResend(
      userEmail,
      'Verify Your Email - Disciplefy',
      emailHtml,
      verificationUrl
    )

    if (!emailResult.success) {
      return createErrorResponse(emailResult.error || 'Failed to send verification email', 500, corsHeaders)
    }

    console.log(`[VERIFY EMAIL] Verification email sent successfully for user_id: ${user.id}`)

    return createSuccessResponse({
      message: 'Verification email sent',
      email: user.email
    }, corsHeaders)

  } catch (error) {
    console.error('[VERIFY EMAIL] Unexpected error:', error)
    return createErrorResponse('Internal server error', 500, corsHeaders)
  }
})
