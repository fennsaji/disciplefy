import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

interface ServiceContainer {
  supabase: any;
}

interface ProfileData {
  first_name: string;
  last_name: string;
  age_group: string;
  interests: string[];
  profile_image_url?: string;
}

interface ProfileSetupRequest {
  action: 'update_profile' | 'get_profile';
  profile_data?: ProfileData;
}

interface ProfileSetupResponse {
  success: boolean;
  data?: any;
  error?: string;
}

// Validation utilities
function validateProfileData(data: ProfileData): string | null {
  if (!data.first_name || data.first_name.trim().length === 0) {
    return "First name is required";
  }
  
  if (!data.last_name || data.last_name.trim().length === 0) {
    return "Last name is required";
  }
  
  if (!data.age_group || !['13-17', '18-25', '26-35', '36-50', '51+'].includes(data.age_group)) {
    return "Valid age group is required";
  }
  
  if (!Array.isArray(data.interests) || data.interests.length === 0) {
    return "At least one interest must be selected";
  }
  
  // Validate interests against allowed values
  const validInterests = [
    'prayer', 'worship', 'community', 'bible_study', 'theology',
    'missions', 'youth_ministry', 'family', 'leadership', 'evangelism'
  ];
  
  for (const interest of data.interests) {
    if (!validInterests.includes(interest)) {
      return `Invalid interest: ${interest}`;
    }
  }
  
  if (data.profile_image_url && !isValidUrl(data.profile_image_url)) {
    return "Invalid profile image URL";
  }
  
  return null;
}

function isValidUrl(string: string): boolean {
  try {
    new URL(string);
    return true;
  } catch (_) {
    return false;
  }
}

function sanitizeProfileData(data: ProfileData): ProfileData {
  return {
    first_name: data.first_name.trim(),
    last_name: data.last_name.trim(),
    age_group: data.age_group,
    interests: data.interests.filter(i => i.trim().length > 0),
    profile_image_url: data.profile_image_url?.trim() || undefined
  };
}

// Core functions
async function updateProfile(profileData: ProfileData, services: ServiceContainer, authToken?: string): Promise<ProfileSetupResponse> {
  try {
    // Create a client with the user's auth token for user operations
    let userSupabaseClient = services.supabase;
    if (authToken) {
      userSupabaseClient = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_ANON_KEY')!,
        {
          global: {
            headers: {
              Authorization: `Bearer ${authToken}`,
            },
          },
        }
      );
    }

    // Get current user using the user token
    const { data: { user }, error: authError } = await userSupabaseClient.auth.getUser();
    
    if (authError || !user) {
      return {
        success: false,
        error: 'Authentication required'
      };
    }

    // Validate profile data
    const validationError = validateProfileData(profileData);
    if (validationError) {
      return {
        success: false,
        error: validationError
      };
    }

    // Sanitize data
    const sanitizedData = sanitizeProfileData(profileData);

    // Update user profile using the user-scoped client
    const { data, error } = await userSupabaseClient
      .from('user_profiles')
      .update({
        first_name: sanitizedData.first_name,
        last_name: sanitizedData.last_name,
        age_group: sanitizedData.age_group,
        interests: sanitizedData.interests,
        profile_image_url: sanitizedData.profile_image_url,
        onboarding_status: 'language_selection', // Move to next step
        updated_at: new Date().toISOString()
      })
      .eq('id', user.id)
      .select('*')
      .single();

    if (error) {
      console.error('Profile update error:', error);
      return {
        success: false,
        error: 'Failed to update profile'
      };
    }

    return {
      success: true,
      data: {
        profile: data,
        next_step: 'language_selection'
      }
    };

  } catch (error) {
    console.error('Update profile error:', error);
    return {
      success: false,
      error: 'Internal server error'
    };
  }
}

async function getProfile(services: ServiceContainer, authToken?: string): Promise<ProfileSetupResponse> {
  try {
    // Create a client with the user's auth token for user operations
    let userSupabaseClient = services.supabase;
    if (authToken) {
      userSupabaseClient = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_ANON_KEY')!,
        {
          global: {
            headers: {
              Authorization: `Bearer ${authToken}`,
            },
          },
        }
      );
    }

    // Get current user using the user token
    const { data: { user }, error: authError } = await userSupabaseClient.auth.getUser();
    
    if (authError || !user) {
      return {
        success: false,
        error: 'Authentication required'
      };
    }

    // Get user profile using the user-scoped client
    const { data, error } = await userSupabaseClient
      .from('user_profiles')
      .select('*')
      .eq('id', user.id)
      .single();

    if (error) {
      console.error('Get profile error:', error);
      return {
        success: false,
        error: 'Failed to retrieve profile'
      };
    }

    return {
      success: true,
      data: {
        profile: data
      }
    };

  } catch (error) {
    console.error('Get profile error:', error);
    return {
      success: false,
      error: 'Internal server error'
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
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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
    // Extract auth token from request headers
    const authHeader = request.headers.get('authorization');
    const authToken = authHeader?.replace('Bearer ', '');

    // Parse request body
    const body: ProfileSetupRequest = await request.json();

    if (!body.action) {
      return new Response(
        JSON.stringify({ error: 'Action is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Create services
    const services = createServices();

    let result: ProfileSetupResponse;

    // Route to appropriate handler
    switch (body.action) {
      case 'update_profile':
        if (!body.profile_data) {
          return new Response(
            JSON.stringify({ error: 'Profile data is required for update_profile action' }),
            {
              status: 400,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          );
        }
        result = await updateProfile(body.profile_data, services, authToken);
        break;

      case 'get_profile':
        result = await getProfile(services, authToken);
        break;
        
      default:
        return new Response(
          JSON.stringify({ error: 'Invalid action' }),
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