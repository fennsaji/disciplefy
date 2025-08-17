import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
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

serve(async (req) => {
  // Get CORS headers for this request
  const corsHeaders = handleCors(req);

  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
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

async function handleGetProfile(supabaseClient: any, userId: string, corsHeaders: Record<string, string>) {
  try {
    const { data: profile, error } = await supabaseClient
      .from('user_profiles')
      .select('*')
      .eq('id', userId)
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        // Profile not found, create default profile
        const defaultProfile = {
          id: userId,
          language_preference: 'en',
          theme_preference: 'light',
          is_admin: false,
        };

        const { data: newProfile, error: insertError } = await supabaseClient
          .from('user_profiles')
          .insert([defaultProfile])
          .select()
          .single();

        if (insertError) {
          console.error('Error creating profile:', insertError);
          return new Response(
            JSON.stringify({ error: 'Failed to create user profile' }),
            {
              status: 500,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            }
          );
        }

        return new Response(
          JSON.stringify({ data: newProfile }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }

      console.error('Error fetching profile:', error);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch user profile' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    return new Response(
      JSON.stringify({ data: profile }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error in handleGetProfile:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
}

async function handleUpdateProfile(supabaseClient: any, userId: string, req: Request, corsHeaders: Record<string, string>) {
  try {
    const body = await req.json();
    const updateData: UpdateProfileRequest = {};

    // Validate and sanitize input
    if (body.language_preference !== undefined) {
      const validLanguages = ['en', 'hi', 'ml'];
      if (!validLanguages.includes(body.language_preference)) {
        return new Response(
          JSON.stringify({ error: 'Invalid language preference' }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }
      updateData.language_preference = body.language_preference;
    }

    if (body.theme_preference !== undefined) {
      const validThemes = ['light', 'dark', 'system'];
      if (!validThemes.includes(body.theme_preference)) {
        return new Response(
          JSON.stringify({ error: 'Invalid theme preference' }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }
      updateData.theme_preference = body.theme_preference;
    }

    if (Object.keys(updateData).length === 0) {
      return new Response(
        JSON.stringify({ error: 'No valid fields to update' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Add updated_at timestamp
    const updateWithTimestamp = {
      ...updateData,
      updated_at: new Date().toISOString(),
    };

    // Try to update existing profile
    const { data: updatedProfile, error: updateError } = await supabaseClient
      .from('user_profiles')
      .update(updateWithTimestamp)
      .eq('id', userId)
      .select()
      .single();

    if (updateError) {
      if (updateError.code === 'PGRST116') {
        // Profile doesn't exist, create it with the update data
        const defaultProfile = {
          id: userId,
          language_preference: updateData.language_preference || 'en',
          theme_preference: updateData.theme_preference || 'light',
          is_admin: false,
        };

        const { data: newProfile, error: insertError } = await supabaseClient
          .from('user_profiles')
          .insert([defaultProfile])
          .select()
          .single();

        if (insertError) {
          console.error('Error creating profile:', insertError);
          return new Response(
            JSON.stringify({ error: 'Failed to create user profile' }),
            {
              status: 500,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            }
          );
        }

        return new Response(
          JSON.stringify({ data: newProfile }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }

      console.error('Error updating profile:', updateError);
      return new Response(
        JSON.stringify({ error: 'Failed to update user profile' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    return new Response(
      JSON.stringify({ data: updatedProfile }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error in handleUpdateProfile:', error);
    return new Response(
      JSON.stringify({ error: 'Invalid request body' }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
}