import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleCors } from "../_shared/utils/cors.ts";
import { extractOAuthProfileData, createProfileUpdateData, logProfileExtraction } from "../_shared/utils/profile-extractor.ts";

interface UserProfile {
  id: string;
  language_preference: string;
  theme_preference: string;
  first_name?: string;
  last_name?: string;
  profile_picture?: string;
  email?: string;
  phone?: string;
  is_admin: boolean;
  created_at: string;
  updated_at: string;
}

interface UpdateProfileRequest {
  language_preference?: string;
  theme_preference?: string;
  first_name?: string;
  last_name?: string;
  profile_picture?: string;
}

interface ValidationResult {
  isValid: boolean;
  updateData?: UpdateProfileRequest;
  error?: string;
}

// Helper Functions

/**
 * Validates if a string is a valid URL
 * @param url - URL string to validate
 * @returns True if valid URL, false otherwise
 */
function isValidUrl(url: string): boolean {
  try {
    const urlObj = new URL(url);
    return urlObj.protocol === 'http:' || urlObj.protocol === 'https:';
  } catch {
    return false;
  }
}

/**
 * Validates a name field (first_name or last_name)
 * @param name - Name to validate
 * @returns True if valid, false otherwise
 */
function isValidName(name: string): boolean {
  if (typeof name !== 'string') return false;
  const trimmed = name.trim();
  if (trimmed.length === 0 || trimmed.length > 50) return false;
  
  // Only allow letters, spaces, hyphens, apostrophes, and common accented characters
  const nameRegex = /^[a-zA-Z\u00C0-\u017F\s\-']+$/;
  return nameRegex.test(trimmed);
}

/**
 * Parses and validates profile update request body
 * @param body - Request body to validate
 * @returns Validation result with parsed data or error
 */
function parseAndValidateUpdate(body: any): ValidationResult {
  const updateData: UpdateProfileRequest = {};

  // Validate language preference
  if (body.language_preference !== undefined) {
    const validLanguages = ['en', 'hi', 'ml'];
    if (!validLanguages.includes(body.language_preference)) {
      return { isValid: false, error: 'Invalid language preference' };
    }
    updateData.language_preference = body.language_preference;
  }

  // Validate theme preference
  if (body.theme_preference !== undefined) {
    const validThemes = ['light', 'dark', 'system'];
    if (!validThemes.includes(body.theme_preference)) {
      return { isValid: false, error: 'Invalid theme preference' };
    }
    updateData.theme_preference = body.theme_preference;
  }

  // Validate first name
  if (body.first_name !== undefined) {
    if (body.first_name === undefined || body.first_name === '') {
      updateData.first_name = undefined; // Allow clearing the field
    } else if (!isValidName(body.first_name)) {
      return { isValid: false, error: 'Invalid first name format' };
    } else {
      updateData.first_name = body.first_name.trim();
    }
  }

  // Validate last name
  if (body.last_name !== undefined) {
    if (body.last_name === undefined || body.last_name === '') {
      updateData.last_name = undefined; // Allow clearing the field
    } else if (!isValidName(body.last_name)) {
      return { isValid: false, error: 'Invalid last name format' };
    } else {
      updateData.last_name = body.last_name.trim();
    }
  }

  // Validate profile picture URL
  if (body.profile_picture !== undefined) {
    if (body.profile_picture === undefined || body.profile_picture === '') {
      updateData.profile_picture = undefined; // Allow clearing the field
    } else if (!isValidUrl(body.profile_picture)) {
      return { isValid: false, error: 'Invalid profile picture URL format' };
    } else {
      updateData.profile_picture = body.profile_picture.trim();
    }
  }

  if (Object.keys(updateData).length === 0) {
    return { isValid: false, error: 'No valid fields to update' };
  }

  return { isValid: true, updateData };
}

/**
 * Creates a default user profile with OAuth data if available
 * @param client - Supabase client instance
 * @param userId - User ID for the profile
 * @param updateData - Optional initial data for the profile
 * @returns Default profile object with extracted OAuth data
 */
async function createDefaultProfile(
  client: SupabaseClient,
  userId: string,
  updateData?: UpdateProfileRequest
): Promise<UserProfile> {
  // Try to extract OAuth profile data
  let oauthData: any = {};
  
  try {
    // Get the current user to extract OAuth data
    const { data: { user }, error: userError } = await client.auth.getUser();
    
    if (!userError && user && user.id === userId) {
      // Extract OAuth profile data
      const extractionResult = extractOAuthProfileData(user);
      
      if (extractionResult.success && extractionResult.data) {
        const profileUpdateData = createProfileUpdateData(extractionResult.data);
        oauthData = profileUpdateData;
        
        // Log the extraction for debugging
        logProfileExtraction(user, extractionResult);
        console.log('✅ [USER_PROFILE] OAuth data extracted for new profile');
      } else {
        console.log('⚠️ [USER_PROFILE] No OAuth data available for profile creation');
      }
    }
  } catch (error) {
    console.warn('⚠️ [USER_PROFILE] Failed to extract OAuth data:', error);
  }

  return {
    id: userId,
    language_preference: updateData?.language_preference || 'en',
    theme_preference: updateData?.theme_preference || 'light',
    first_name: updateData?.first_name || oauthData.first_name || null,
    last_name: updateData?.last_name || oauthData.last_name || null,
    profile_picture: updateData?.profile_picture || oauthData.profile_picture || null,
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
    const defaultProfile = createDefaultProfile(client, userId, updateData);
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
      case 'POST':
        // Handle profile sync from OAuth providers
        return await handleSyncProfile(supabaseClient, userId, corsHeaders);
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
 * Handles GET requests to retrieve user profile with email/phone data
 * @param supabaseClient - Authenticated Supabase client
 * @param userId - User ID from JWT token
 * @param corsHeaders - CORS headers for response
 * @returns Promise resolving to HTTP response with complete user profile data
 */
async function handleGetProfile(
  supabaseClient: SupabaseClient,
  userId: string,
  corsHeaders: Record<string, string>
): Promise<Response> {
  try {
    // Get profile data from user_profiles table
    const { data: profile, error } = await supabaseClient
      .from('user_profiles')
      .select('*')
      .eq('id', userId)
      .single();

    let userProfile: UserProfile;

    if (error?.code === 'PGRST116') {
      // Profile not found, create default profile with OAuth data
      const defaultProfile = await createDefaultProfile(supabaseClient, userId);
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
      userProfile = newProfile;
    } else if (error) {
      console.error('Error fetching profile:', error);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch user profile' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    } else {
      userProfile = profile;
    }

    // Get email and phone from auth.users table
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    
    if (!userError && user) {
      userProfile.email = user.email || undefined;
      userProfile.phone = user.phone || undefined;
    }

    return new Response(
      JSON.stringify({ data: userProfile }),
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

/**
 * Handles POST requests to sync OAuth profile data
 * @param supabaseClient - Authenticated Supabase client
 * @param userId - User ID from JWT token
 * @param corsHeaders - CORS headers for response
 * @returns Promise resolving to HTTP response with sync result
 */
async function handleSyncProfile(
  supabaseClient: SupabaseClient,
  userId: string,
  corsHeaders: Record<string, string>
): Promise<Response> {
  try {
    // Get the current user to extract OAuth data
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    
    if (userError || !user || user.id !== userId) {
      return new Response(
        JSON.stringify({ error: 'Failed to get user data for sync' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Extract OAuth profile data
    const extractionResult = extractOAuthProfileData(user);
    
    if (!extractionResult.success || !extractionResult.data) {
      return new Response(
        JSON.stringify({ 
          error: 'No OAuth profile data available to sync',
          source: extractionResult.source
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Convert extracted data to database format
    const profileUpdateData = createProfileUpdateData(extractionResult.data);
    
    if (Object.keys(profileUpdateData).length === 0) {
      return new Response(
        JSON.stringify({ 
          message: 'No profile data to sync',
          source: extractionResult.source
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Add timestamp for update
    const updateWithTimestamp = {
      ...profileUpdateData,
      updated_at: new Date().toISOString(),
    };

    // Upsert the profile data
    const { data: profile, error } = await upsertProfile(
      supabaseClient,
      userId,
      updateWithTimestamp
    );

    if (error) {
      console.error('Error syncing profile:', error);
      return new Response(
        JSON.stringify({ error: 'Failed to sync profile data' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Log successful sync
    logProfileExtraction(user, extractionResult);
    console.log(`✅ [USER_PROFILE] Profile synced successfully for user ${userId}`);

    return new Response(
      JSON.stringify({ 
        message: 'Profile synced successfully',
        data: profile,
        source: extractionResult.source,
        synced_fields: Object.keys(profileUpdateData)
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error in handleSyncProfile:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error during profile sync' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}