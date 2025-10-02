import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2"

interface ServiceContainer {
  supabase: SupabaseClient;
}

interface PhoneAuthRequest {
  action: 'send_otp' | 'verify_otp';
  phone_number: string;
  otp_code?: string;
}

interface PhoneAuthResponse {
  success: boolean;
  data?: any;
  error?: string;
}

// Validation utilities
function validatePhoneNumber(phoneNumber: string): boolean {
  const phoneRegex = /^\+[1-9]\d{1,14}$/;
  return phoneRegex.test(phoneNumber);
}

/**
 * Normalizes phone number by stripping non-numeric characters and converting international prefixes
 * Does NOT guess country codes - returns cleaned value for subsequent validation
 *
 * @param phoneNumber - Raw phone number input (e.g., "00971501234567", "+91 98765 43210", "9876543210")
 * @returns Normalized phone number (e.g., "+971501234567", "+919876543210", "9876543210")
 */
function formatPhoneNumber(phoneNumber: string): string {
  // Strip all characters except digits and leading '+'
  let cleaned = phoneNumber.replace(/[^\d+]/g, '');

  // Convert "00" international prefix to "+"
  if (cleaned.startsWith('00')) {
    cleaned = '+' + cleaned.substring(2);
  }

  // Return as-is - do NOT default to +1 if no prefix exists
  // Let validation handle ambiguous numbers without guessing country codes
  return cleaned;
}

/**
 * Extracts country calling code from formatted phone number
 * Uses robust regex to correctly parse 1, 2, and 3-digit country codes
 *
 * @param formattedPhone - Phone number with leading '+' (e.g., '+919876543210', '+971501234567')
 * @returns Country code including '+' (e.g., '+91', '+971') or '+1' as fallback
 */
function extractCountryCode(formattedPhone: string): string {
  if (!formattedPhone.startsWith('+')) {
    return '+1';
  }

  // Robust regex: tries 3-digit codes ([2-9]\d{2}), then 2-digit ([2-9]\d?), then 1-digit (1)
  // Special case: +1 must be handled explicitly to avoid matching +1X as +1
  // Pattern matches: +971 (3-digit), +91 (2-digit), +1 (1-digit)
  const countryCodePattern = /^\+((?:[2-9]\d{2})|(?:[2-9]\d?)|1)/;
  const match = formattedPhone.match(countryCodePattern);

  if (match && match[1]) {
    return '+' + match[1];
  }

  // Fallback to +1 if no valid pattern matched
  return '+1';
}

// Core functions
async function sendOTP(phoneNumber: string, services: ServiceContainer): Promise<PhoneAuthResponse> {
  try {
    const formattedPhone = formatPhoneNumber(phoneNumber);
    
    if (!validatePhoneNumber(formattedPhone)) {
      return {
        success: false,
        error: 'Invalid phone number format'
      };
    }

    const { error } = await services.supabase.auth.signInWithOtp({
      phone: formattedPhone,
    });

    if (error) {
      return {
        success: false,
        error: `Failed to send OTP: ${error.message}`
      };
    }

    return {
      success: true,
      data: {
        message: 'OTP sent successfully',
        phone_number: formattedPhone,
        expires_in: 60
      }
    };

  } catch (error) {
    console.error('Send OTP error:', error);
    return {
      success: false,
      error: 'Failed to send OTP'
    };
  }
}

async function verifyOTP(phoneNumber: string, otpCode: string, services: ServiceContainer): Promise<PhoneAuthResponse> {
  try {
    const formattedPhone = formatPhoneNumber(phoneNumber);
    
    if (!validatePhoneNumber(formattedPhone)) {
      return {
        success: false,
        error: 'Invalid phone number format'
      };
    }

    if (!otpCode || otpCode.length !== 6) {
      return {
        success: false,
        error: 'OTP must be 6 digits'
      };
    }

    // Verify OTP using Supabase Auth
    const { data, error } = await services.supabase.auth.verifyOtp({
      phone: formattedPhone,
      token: otpCode,
      type: 'sms',
    });

    if (error) {
      return {
        success: false,
        error: `Failed to verify OTP: ${error.message}`
      };
    }

    if (!data.user) {
      return {
        success: false,
        error: 'OTP verification failed'
      };
    }

    const user = data.user;
    const session = data.session;

    // Check if user profile exists
    const { data: existingProfile, error: profileError } = await services.supabase
      .from('user_profiles')
      .select('*')
      .eq('id', user.id)
      .single();

    let onboardingStatus = 'completed';
    let requiresOnboarding = false;

    if (profileError || !existingProfile) {
      // Create new user profile for phone auth user
      const countryCode = extractCountryCode(formattedPhone);

      const { error: insertError } = await services.supabase
        .from('user_profiles')
        .insert({
          id: user.id,
          phone_number: formattedPhone,
          phone_verified: true,
          phone_country_code: countryCode,
          onboarding_status: 'profile_setup',
          language_preference: 'en',
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        });

      if (insertError) {
        console.error('Failed to create user profile:', insertError);
        return {
          success: false,
          error: `Failed to create user profile: ${insertError.message}`
        };
      }

      onboardingStatus = 'profile_setup';
      requiresOnboarding = true;
    } else {
      // Update existing profile with phone number if not set
      if (!existingProfile.phone_number) {
        const countryCode = extractCountryCode(formattedPhone);

        const { error: updateError } = await services.supabase
          .from('user_profiles')
          .update({
            phone_number: formattedPhone,
            phone_verified: true,
            phone_country_code: countryCode,
            updated_at: new Date().toISOString()
          })
          .eq('id', user.id);

        if (updateError) {
          console.error('Failed to update user profile:', updateError);
          return {
            success: false,
            error: `Failed to update user profile: ${updateError.message}`
          };
        }
      }

      onboardingStatus = existingProfile.onboarding_status || 'completed';
      requiresOnboarding = onboardingStatus !== 'completed';
    }

    return {
      success: true,
      data: {
        message: 'Phone verification successful',
        user,
        session,
        requires_onboarding: requiresOnboarding,
        onboarding_status: onboardingStatus
      }
    };

  } catch (error) {
    console.error('Verify OTP error:', error);
    return {
      success: false,
      error: 'Failed to verify OTP'
    };
  }
}

// Factory function
function createServices(): ServiceContainer {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  
  return {
    supabase: createClient(supabaseUrl, supabaseServiceKey)
  };
}

// Request handler
async function handleRequest(request: Request): Promise<Response> {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-session-id',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  // Handle preflight requests
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  // Only allow POST requests
  if (request.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { 
        status: 405, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }

  try {
    // Parse request body
    const body: PhoneAuthRequest = await request.json();
    
    if (!body.action || !body.phone_number) {
      return new Response(
        JSON.stringify({ error: 'Action and phone_number are required' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Create services
    const services = createServices();

    let result: PhoneAuthResponse;

    // Route to appropriate handler
    switch (body.action) {
      case 'send_otp':
        result = await sendOTP(body.phone_number, services);
        break;
        
      case 'verify_otp':
        if (!body.otp_code) {
          return new Response(
            JSON.stringify({ error: 'OTP code is required for verify_otp action' }),
            { 
              status: 400, 
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          );
        }
        result = await verifyOTP(body.phone_number, body.otp_code, services);
        break;
        
      default:
        return new Response(
          JSON.stringify({ error: 'Invalid action. Must be send_otp or verify_otp' }),
          { 
            status: 400, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        );
    }

    const status = result.success ? 200 : 400;
    
    return new Response(
      JSON.stringify(result),
      { 
        status, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );

  } catch (error) {
    console.error('Request handling error:', error);
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: 'Invalid request format' 
      }),
      { 
        status: 400, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
}

// Start the server
serve(handleRequest)