import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleCors } from "../_shared/utils/cors.ts";

interface UserProfile {
  id: string;
  language_preference: string;
  theme_preference: string;
  is_admin: boolean;
  created_at: string;
  updated_at: string;
}

interface UpdateProfileRequest {
  language_preference?: string;
  theme_preference?: string;
}

interface ValidationResult {
  isValid: boolean;
  updateData?: UpdateProfileRequest;
  error?: string;
}

// Helper Functions

/**
 * Parses and validates profile update request body
 * @param body - Request body to validate
 * @returns Validation result with parsed data or error
 */
function parseAndValidateUpdate(body: any): ValidationResult {
  const updateData: UpdateProfileRequest = {};

  if (body.language_preference !== undefined) {
    const validLanguages = ['en', 'hi', 'ml'];
    if (!validLanguages.includes(body.language_preference)) {
      return { isValid: false, error: 'Invalid language preference' };
    }
    updateData.language_preference = body.language_preference;
  }

  if (body.theme_preference !== undefined) {
    const validThemes = ['light', 'dark', 'system'];
    if (!validThemes.includes(body.theme_preference)) {
      return { isValid: false, error: 'Invalid theme preference' };
    }
    updateData.theme_preference = body.theme_preference;
  }

  if (Object.keys(updateData).length === 0) {
    return { isValid: false, error: 'No valid fields to update' };
  }

  return { isValid: true, updateData };
}

/**
 * Creates a default user profile
 * @param userId - User ID for the profile
 * @param updateData - Optional initial data for the profile
 * @returns Default profile object
 */
function createDefaultProfile(userId: string, updateData?: UpdateProfileRequest): UserProfile {
  return {
    id: userId,
    language_preference: updateData?.language_preference || 'en',
    theme_preference: updateData?.theme_preference || 'light',
    is_admin: false,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
}

/**
 * Upserts a user profile (update if exists, create if not)
 * @param client - Supabase client instance
 * @param userId - User ID
 * @param updateData - Data to update
 * @returns Promise resolving to the upserted profile
 */
async function upsertProfile(
  client: SupabaseClient,
  userId: string,
  updateData: UpdateProfileRequest
): Promise<{ data: UserProfile | null; error: any }> {
  const updateWithTimestamp = {
    ...updateData,
    updated_at: new Date().toISOString(),
  };

  // Try to update existing profile
  const { data: updatedProfile, error: updateError } = await client
    .from('user_profiles')
    .update(updateWithTimestamp)
    .eq('id', userId)
    .select()
    .single();

  if (updateError?.code === 'PGRST116') {
    // Profile doesn't exist, create it
    const defaultProfile = createDefaultProfile(userId, updateData);
    return await client
      .from('user_profiles')
      .insert([defaultProfile])
      .select()
      .single();
  }

  return { data: updatedProfile, error: updateError };
}

serve(async (req) => {
  // Get CORS headers for this request
  const corsHeaders = handleCors(req);

  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Validate Supabase configuration
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');

    if (!supabaseUrl || supabaseUrl.trim() === '') {
      console.error('Missing SUPABASE_URL environment variable');
      return new Response(
        JSON.stringify({ error: 'Supabase configuration missing: SUPABASE_URL' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    if (!supabaseAnonKey || supabaseAnonKey.trim() === '') {
      console.error('Missing SUPABASE_ANON_KEY environment variable');
      return new Response(
        JSON.stringify({ error: 'Supabase configuration missing: SUPABASE_ANON_KEY' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Initialize Supabase client
    const supabaseClient = createClient(
      supabaseUrl,
      supabaseAnonKey,
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    );

    // Get user from JWT token
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const userId = user.id;

    switch (req.method) {
      case 'GET':
        return await handleGetProfile(supabaseClient, userId, corsHeaders);
      case 'PUT':
        return await handleUpdateProfile(supabaseClient, userId, req, corsHeaders);
      default:
        return new Response(
          JSON.stringify({ error: 'Method not allowed' }),
          {
            status: 405,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
    }
  } catch (error) {
    console.error('Error in user-profile function:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});

/**
 * Handles GET requests to retrieve user profile
 * @param supabaseClient - Authenticated Supabase client
 * @param userId - User ID from JWT token
 * @param corsHeaders - CORS headers for response
 * @returns Promise resolving to HTTP response with user profile data
 */
async function handleGetProfile(
  supabaseClient: SupabaseClient,
  userId: string,
  corsHeaders: Record<string, string>
): Promise<Response> {
  try {
    const { data: profile, error } = await supabaseClient
      .from('user_profiles')
      .select('*')
      .eq('id', userId)
      .single();

    if (error?.code === 'PGRST116') {
      // Profile not found, create default profile
      const defaultProfile = createDefaultProfile(userId);
      const { data: newProfile, error: insertError } = await supabaseClient
        .from('user_profiles')
        .insert([defaultProfile])
        .select()
        .single();

      if (insertError) {
        console.error('Error creating profile:', insertError);
        return new Response(
          JSON.stringify({ error: 'Failed to create user profile' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      return new Response(
        JSON.stringify({ data: newProfile }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (error) {
      console.error('Error fetching profile:', error);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch user profile' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ data: profile }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error in handleGetProfile:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}

/**
 * Handles PUT requests to update user profile
 * @param supabaseClient - Authenticated Supabase client
 * @param userId - User ID from JWT token
 * @param req - HTTP request object
 * @param corsHeaders - CORS headers for response
 * @returns Promise resolving to HTTP response with updated profile data
 */
async function handleUpdateProfile(
  supabaseClient: SupabaseClient,
  userId: string,
  req: Request,
  corsHeaders: Record<string, string>
): Promise<Response> {
  try {
    const body = await req.json();
    const validation = parseAndValidateUpdate(body);

    if (!validation.isValid) {
      return new Response(
        JSON.stringify({ error: validation.error }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { data: profile, error } = await upsertProfile(
      supabaseClient,
      userId,
      validation.updateData!
    );

    if (error) {
      console.error('Error upserting profile:', error);
      return new Response(
        JSON.stringify({ error: 'Failed to update user profile' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ data: profile }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error in handleUpdateProfile:', error);
    return new Response(
      JSON.stringify({ error: 'Invalid request body' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}