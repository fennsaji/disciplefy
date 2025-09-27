import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

interface ServiceContainer {
  supabase: any;
}

interface UploadImageRequest {
  action: 'upload_image' | 'delete_image' | 'get_upload_url';
  file_name?: string;
  file_type?: string;
  image_data?: string; // Base64 encoded image data
}

interface UploadImageResponse {
  success: boolean;
  data?: any;
  error?: string;
}

// Configuration
const STORAGE_BUCKET = 'profile-images';
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

// Validation utilities
function validateImageUpload(fileName: string, fileType: string, imageData: string): string | null {
  if (!fileName || fileName.trim().length === 0) {
    return "File name is required";
  }
  
  if (!fileType || !ALLOWED_TYPES.includes(fileType)) {
    return `Invalid file type. Allowed types: ${ALLOWED_TYPES.join(', ')}`;
  }
  
  if (!imageData || imageData.trim().length === 0) {
    return "Image data is required";
  }
  
  // Validate base64 format
  if (!isValidBase64(imageData)) {
    return "Invalid image data format";
  }
  
  // Check file size (approximate from base64)
  const sizeInBytes = (imageData.length * 3) / 4;
  if (sizeInBytes > MAX_FILE_SIZE) {
    return `File size too large. Maximum size: ${MAX_FILE_SIZE / (1024 * 1024)}MB`;
  }
  
  // Validate file extension
  const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
  const hasValidExtension = allowedExtensions.some(ext => 
    fileName.toLowerCase().endsWith(ext)
  );
  
  if (!hasValidExtension) {
    return `Invalid file extension. Allowed extensions: ${allowedExtensions.join(', ')}`;
  }
  
  return null;
}

function isValidBase64(str: string): boolean {
  try {
    // Remove data URL prefix if present
    const base64Data = str.replace(/^data:image\/[a-z]+;base64,/, '');
    
    // Check if it's valid base64
    const decoded = atob(base64Data);
    return btoa(decoded) === base64Data;
  } catch {
    return false;
  }
}

function generateUniqueFileName(userId: string, originalFileName: string): string {
  const timestamp = Date.now();
  const extension = originalFileName.substring(originalFileName.lastIndexOf('.'));
  return `${userId}_${timestamp}${extension}`;
}

function base64ToUint8Array(base64: string): Uint8Array {
  // Remove data URL prefix if present
  const base64Data = base64.replace(/^data:image\/[a-z]+;base64,/, '');
  const binaryString = atob(base64Data);
  const bytes = new Uint8Array(binaryString.length);
  
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  
  return bytes;
}

// Core functions
async function uploadImage(fileName: string, fileType: string, imageData: string, services: ServiceContainer, authToken?: string): Promise<UploadImageResponse> {
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
      console.error('Auth error:', authError);
      return {
        success: false,
        error: 'Authentication required'
      };
    }

    // Validate upload
    const validationError = validateImageUpload(fileName, fileType, imageData);
    if (validationError) {
      return {
        success: false,
        error: validationError
      };
    }

    // Generate unique file name
    const uniqueFileName = generateUniqueFileName(user.id, fileName);
    
    // Convert base64 to Uint8Array
    const imageBytes = base64ToUint8Array(imageData);
    
    // Delete old profile image if exists
    const { data: profileData } = await services.supabase
      .from('user_profiles')
      .select('profile_image_url')
      .eq('id', user.id)
      .single();
    
    if (profileData?.profile_image_url) {
      // Extract file name from URL and delete
      const oldFileName = profileData.profile_image_url.split('/').pop();
      if (oldFileName) {
        await services.supabase.storage
          .from(STORAGE_BUCKET)
          .remove([oldFileName]);
      }
    }

    // Upload new image
    const { data: uploadData, error: uploadError } = await services.supabase.storage
      .from(STORAGE_BUCKET)
      .upload(uniqueFileName, imageBytes, {
        contentType: fileType,
        cacheControl: '3600',
        upsert: true
      });

    if (uploadError) {
      console.error('Upload error:', uploadError);
      return {
        success: false,
        error: 'Failed to upload image'
      };
    }

    // Get public URL
    const { data: urlData } = services.supabase.storage
      .from(STORAGE_BUCKET)
      .getPublicUrl(uniqueFileName);

    if (!urlData?.publicUrl) {
      return {
        success: false,
        error: 'Failed to get public URL'
      };
    }

    // Update user profile with new image URL
    const { data: updateData, error: updateError } = await services.supabase
      .from('user_profiles')
      .update({
        profile_image_url: urlData.publicUrl,
        updated_at: new Date().toISOString()
      })
      .eq('id', user.id)
      .select('*')
      .single();

    if (updateError) {
      console.error('Profile update error:', updateError);
      // Try to clean up uploaded file
      await services.supabase.storage
        .from(STORAGE_BUCKET)
        .remove([uniqueFileName]);
      
      return {
        success: false,
        error: 'Failed to update profile'
      };
    }

    return {
      success: true,
      data: {
        image_url: urlData.publicUrl,
        file_name: uniqueFileName,
        profile: updateData
      }
    };

  } catch (error) {
    console.error('Upload image error:', error);
    return {
      success: false,
      error: 'Internal server error'
    };
  }
}

async function deleteImage(services: ServiceContainer, authToken?: string): Promise<UploadImageResponse> {
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

    // Get current profile image URL
    const { data: profileData, error: profileError } = await services.supabase
      .from('user_profiles')
      .select('profile_image_url')
      .eq('id', user.id)
      .single();

    if (profileError) {
      return {
        success: false,
        error: 'Failed to get profile data'
      };
    }

    if (!profileData?.profile_image_url) {
      return {
        success: false,
        error: 'No profile image to delete'
      };
    }

    // Extract file name from URL
    const fileName = profileData.profile_image_url.split('/').pop();
    if (!fileName) {
      return {
        success: false,
        error: 'Invalid image URL'
      };
    }

    // Delete from storage
    const { error: deleteError } = await services.supabase.storage
      .from(STORAGE_BUCKET)
      .remove([fileName]);

    if (deleteError) {
      console.error('Delete error:', deleteError);
      return {
        success: false,
        error: 'Failed to delete image'
      };
    }

    // Update profile to remove image URL
    const { data: updateData, error: updateError } = await services.supabase
      .from('user_profiles')
      .update({
        profile_image_url: null,
        updated_at: new Date().toISOString()
      })
      .eq('id', user.id)
      .select('*')
      .single();

    if (updateError) {
      console.error('Profile update error:', updateError);
      return {
        success: false,
        error: 'Failed to update profile'
      };
    }

    return {
      success: true,
      data: {
        message: 'Image deleted successfully',
        profile: updateData
      }
    };

  } catch (error) {
    console.error('Delete image error:', error);
    return {
      success: false,
      error: 'Internal server error'
    };
  }
}

async function getUploadUrl(fileName: string, fileType: string, services: ServiceContainer, authToken?: string): Promise<UploadImageResponse> {
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

    // Basic validation
    if (!fileName || !fileType) {
      return {
        success: false,
        error: 'File name and type are required'
      };
    }

    if (!ALLOWED_TYPES.includes(fileType)) {
      return {
        success: false,
        error: `Invalid file type. Allowed types: ${ALLOWED_TYPES.join(', ')}`
      };
    }

    // Generate unique file name
    const uniqueFileName = generateUniqueFileName(user.id, fileName);

    // Create signed upload URL (valid for 1 hour)
    const { data, error } = await services.supabase.storage
      .from(STORAGE_BUCKET)
      .createSignedUploadUrl(uniqueFileName, {
        expiresIn: 3600 // 1 hour
      });

    if (error) {
      console.error('Signed URL error:', error);
      return {
        success: false,
        error: 'Failed to create upload URL'
      };
    }

    return {
      success: true,
      data: {
        upload_url: data.signedUrl,
        file_name: uniqueFileName,
        expires_in: 3600
      }
    };

  } catch (error) {
    console.error('Get upload URL error:', error);
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
    // Parse request body
    const body: UploadImageRequest = await request.json();

    if (!body.action) {
      return new Response(
        JSON.stringify({ error: 'Action is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Extract auth token from request headers
    const authHeader = request.headers.get('authorization');
    const authToken = authHeader?.replace('Bearer ', '');

    // Create services
    const services = createServices();

    let result: UploadImageResponse;

    // Route to appropriate handler
    switch (body.action) {
      case 'upload_image':
        if (!body.file_name || !body.file_type || !body.image_data) {
          return new Response(
            JSON.stringify({ error: 'File name, file type, and image data are required for upload_image action' }),
            { 
              status: 400, 
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          );
        }
        result = await uploadImage(body.file_name, body.file_type, body.image_data, services, authToken);
        break;
        
      case 'delete_image':
        result = await deleteImage(services, authToken);
        break;

      case 'get_upload_url':
        if (!body.file_name || !body.file_type) {
          return new Response(
            JSON.stringify({ error: 'File name and file type are required for get_upload_url action' }),
            {
              status: 400,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          );
        }
        result = await getUploadUrl(body.file_name, body.file_type, services, authToken);
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