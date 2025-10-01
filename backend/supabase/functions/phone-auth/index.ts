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

function formatPhoneNumber(phoneNumber: string): string {
  let formatted = phoneNumber.replace(/[^\d+]/g, '');

  if (!formatted.startsWith('+')) {
    formatted = '+1' + formatted;
  }

  return formatted;
}

/**
 * Extracts country calling code from formatted phone number
 * Uses ITU E.164 format rules to identify country codes (1-3 digits)
 *
 * @param formattedPhone - Phone number with leading '+' (e.g., '+919876543210')
 * @returns Country code including '+' (e.g., '+91') or '+1' as fallback
 */
function extractCountryCode(formattedPhone: string): string {
  if (!formattedPhone.startsWith('+')) {
    return '+1';
  }

  // Remove the '+' prefix for easier matching
  const digits = formattedPhone.substring(1);

  // Common country codes by length (most specific to least specific)
  // Try 3-digit codes first, then 2-digit, then 1-digit

  // 3-digit codes (less common, but exist)
  // No need to check these exhaustively - if first digit is 1-9 and length >= 3, try it

  // 2-digit codes (most common internationally)
  // Check if first 2 digits form a valid pattern
  if (digits.length >= 2) {
    const twoDigit = digits.substring(0, 2);
    const firstDigit = parseInt(twoDigit[0]);

    // Country codes 20-99 are 2 digits
    if (firstDigit >= 2 && firstDigit <= 9) {
      return '+' + twoDigit;
    }
  }

  // 1-digit codes (only North America uses country code 1)
  if (digits.length >= 1 && digits[0] === '1') {
    return '+1';
  }

  // Fallback
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