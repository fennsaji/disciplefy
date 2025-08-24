/**
 * OAuth Profile Data Extraction Utility
 * 
 * Extracts and validates user profile information from OAuth provider metadata
 * Supports Google OAuth and Apple OAuth with consistent data structure
 */

import { User } from "https://esm.sh/@supabase/supabase-js@2";

export interface ExtractedProfileData {
  firstName?: string;
  lastName?: string;
  profilePicture?: string;
  email?: string;
  phone?: string;
  fullName?: string;
}

export interface ProfileExtractionResult {
  success: boolean;
  data?: ExtractedProfileData;
  error?: string;
  source: 'google' | 'apple' | 'unknown';
}

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
 * Validates and sanitizes a name field
 * @param name - Name string to validate
 * @returns Sanitized name or undefined if invalid
 */
function validateName(name: any): string | undefined {
  if (typeof name !== 'string') return undefined;
  
  const sanitized = name.trim();
  if (sanitized.length === 0) return undefined;
  if (sanitized.length > 50) return sanitized.substring(0, 50);
  
  // Only allow letters, spaces, hyphens, apostrophes, and common accented characters
  const nameRegex = /^[a-zA-Z\u00C0-\u017F\s\-']+$/;
  if (!nameRegex.test(sanitized)) return undefined;
  
  return sanitized;
}

/**
 * Validates profile picture URL
 * @param url - Profile picture URL
 * @returns Validated URL or undefined if invalid
 */
function validateProfilePicture(url: any): string | undefined {
  if (typeof url !== 'string') return undefined;
  
  const trimmed = url.trim();
  if (trimmed.length === 0) return undefined;
  if (!isValidUrl(trimmed)) return undefined;
  
  // Check if URL looks like an image (common image hosting domains or image extensions)
  const imageUrlRegex = /\.(jpg|jpeg|png|gif|webp)(\?.*)?$/i;
  const commonImageHosts = [
    'googleusercontent.com',
    'fbcdn.net',
    'twimg.com',
    'apple.com',
    'icloud.com',
    'gravatar.com'
  ];
  
  const hasImageExtension = imageUrlRegex.test(trimmed);
  const isFromImageHost = commonImageHosts.some(host => trimmed.includes(host));
  
  if (!hasImageExtension && !isFromImageHost) {
    console.warn(`⚠️ Profile picture URL may not be an image: ${trimmed}`);
  }
  
  return trimmed;
}

/**
 * Extracts profile data from Google OAuth user metadata
 * @param userMetadata - User metadata from Google OAuth
 * @returns Extracted profile data
 */
function extractGoogleProfileData(userMetadata: any): ExtractedProfileData {
  const data: ExtractedProfileData = {};
  
  // Extract names
  if (userMetadata.given_name) {
    data.firstName = validateName(userMetadata.given_name);
  }
  
  if (userMetadata.family_name) {
    data.lastName = validateName(userMetadata.family_name);
  }
  
  // Fallback to parsing full name if individual names not available
  if (!data.firstName && !data.lastName && userMetadata.name) {
    const fullName = validateName(userMetadata.name);
    if (fullName) {
      const nameParts = fullName.split(' ');
      if (nameParts.length >= 2) {
        data.firstName = nameParts[0];
        data.lastName = nameParts.slice(1).join(' ');
      } else {
        data.firstName = fullName;
      }
    }
  }
  
  // Extract profile picture
  if (userMetadata.picture) {
    data.profilePicture = validateProfilePicture(userMetadata.picture);
  }
  
  // Store full name for reference
  if (userMetadata.name) {
    data.fullName = validateName(userMetadata.name);
  }
  
  // Email and phone are typically in the main user object, not metadata
  // But include them if present in metadata
  if (userMetadata.email) {
    data.email = userMetadata.email;
  }
  
  return data;
}

/**
 * Extracts profile data from Apple OAuth user metadata
 * @param userMetadata - User metadata from Apple OAuth
 * @returns Extracted profile data
 */
function extractAppleProfileData(userMetadata: any): ExtractedProfileData {
  const data: ExtractedProfileData = {};
  
  // Apple OAuth typically provides less data due to privacy settings
  if (userMetadata.name) {
    if (userMetadata.name.firstName) {
      data.firstName = validateName(userMetadata.name.firstName);
    }
    if (userMetadata.name.lastName) {
      data.lastName = validateName(userMetadata.name.lastName);
    }
  }
  
  // Apple OAuth rarely provides profile pictures
  if (userMetadata.picture) {
    data.profilePicture = validateProfilePicture(userMetadata.picture);
  }
  
  // Email is typically in the main user object for Apple OAuth
  if (userMetadata.email) {
    data.email = userMetadata.email;
  }
  
  return data;
}

/**
 * Determines OAuth provider based on user metadata structure
 * @param user - Supabase user object
 * @returns Detected OAuth provider
 */
function detectOAuthProvider(user: User): 'google' | 'apple' | 'unknown' {
  // Check app_metadata for provider information
  if (user.app_metadata?.provider === 'google') return 'google';
  if (user.app_metadata?.provider === 'apple') return 'apple';
  
  // Check user_metadata for provider-specific fields
  const metadata = user.user_metadata || {};
  
  // Google OAuth typically has these fields
  if (metadata.provider === 'google' || 
      metadata.aud === 'authenticated' && (metadata.picture && metadata.picture.includes('googleusercontent.com'))) {
    return 'google';
  }
  
  // Apple OAuth detection
  if (metadata.provider === 'apple' || 
      (metadata.iss && metadata.iss.includes('apple'))) {
    return 'apple';
  }
  
  return 'unknown';
}

/**
 * Main function to extract profile data from OAuth user
 * @param user - Supabase user object from OAuth authentication
 * @returns Profile extraction result with data and metadata
 */
export function extractOAuthProfileData(user: User): ProfileExtractionResult {
  if (!user) {
    return {
      success: false,
      error: 'No user provided',
      source: 'unknown'
    };
  }
  
  const provider = detectOAuthProvider(user);
  let extractedData: ExtractedProfileData = {};
  
  try {
    // Extract based on provider
    switch (provider) {
      case 'google':
        extractedData = extractGoogleProfileData(user.user_metadata || {});
        break;
      case 'apple':
        extractedData = extractAppleProfileData(user.user_metadata || {});
        break;
      default:
        // Try generic extraction for unknown providers
        extractedData = extractGoogleProfileData(user.user_metadata || {});
        break;
    }
    
    // Always include email and phone from main user object if available
    if (user.email && !extractedData.email) {
      extractedData.email = user.email;
    }
    
    if (user.phone && !extractedData.phone) {
      extractedData.phone = user.phone;
    }
    
    // Log extraction results for debugging
    console.log(`📊 [PROFILE_EXTRACTOR] Provider: ${provider}`);
    console.log(`📊 [PROFILE_EXTRACTOR] Extracted: firstName=${!!extractedData.firstName}, lastName=${!!extractedData.lastName}, profilePicture=${!!extractedData.profilePicture}`);
    
    return {
      success: true,
      data: extractedData,
      source: provider
    };
    
  } catch (error) {
    console.error('❌ [PROFILE_EXTRACTOR] Error extracting profile data:', error);
    return {
      success: false,
      error: `Failed to extract profile data: ${error}`,
      source: provider
    };
  }
}

/**
 * Creates a profile update object suitable for database operations
 * @param extractedData - Extracted profile data
 * @returns Database-ready profile update object
 */
export function createProfileUpdateData(extractedData: ExtractedProfileData): {
  first_name?: string;
  last_name?: string;
  profile_picture?: string;
} {
  const updateData: any = {};
  
  if (extractedData.firstName) {
    updateData.first_name = extractedData.firstName;
  }
  
  if (extractedData.lastName) {
    updateData.last_name = extractedData.lastName;
  }
  
  if (extractedData.profilePicture) {
    updateData.profile_picture = extractedData.profilePicture;
  }
  
  return updateData;
}

/**
 * Utility function to log profile extraction for debugging
 * @param user - Supabase user object
 * @param result - Profile extraction result
 */
export function logProfileExtraction(user: User, result: ProfileExtractionResult): void {
  console.log(`🔍 [PROFILE_EXTRACTOR] User ID: ${user.id}`);
  console.log(`🔍 [PROFILE_EXTRACTOR] Provider: ${result.source}`);
  console.log(`🔍 [PROFILE_EXTRACTOR] Success: ${result.success}`);
  
  if (result.success && result.data) {
    console.log(`🔍 [PROFILE_EXTRACTOR] Data extracted:`);
    console.log(`  - First Name: ${result.data.firstName ? '[PRESENT]' : '[MISSING]'}`);
    console.log(`  - Last Name: ${result.data.lastName ? '[PRESENT]' : '[MISSING]'}`);
    console.log(`  - Profile Picture: ${result.data.profilePicture ? '[PRESENT]' : '[MISSING]'}`);
    console.log(`  - Email: ${result.data.email ? '[PRESENT]' : '[MISSING]'}`);
    console.log(`  - Phone: ${result.data.phone ? '[PRESENT]' : '[MISSING]'}`);
  } else if (result.error) {
    console.log(`❌ [PROFILE_EXTRACTOR] Error: ${result.error}`);
  }
}