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

interface AppleOAuthMetadata {
  name?: {
    firstName?: string;
    lastName?: string;
  };
  picture?: string;
  email?: string;
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
function validateName(name: unknown): string | undefined {
  if (typeof name !== 'string') return undefined;
  
  const trimmed = name.trim();
  if (trimmed.length === 0) return undefined;
  
  // Truncate to 50 characters if needed
  const sanitized = trimmed.length > 50 ? trimmed.substring(0, 50) : trimmed;
  
  // Unicode-aware regex: allow letters, combining marks, spaces, hyphens, and apostrophes
  const nameRegex = /^[\p{L}\p{M}\s\-']+$/u;
  if (!nameRegex.test(sanitized)) return undefined;
  
  return sanitized;
}

/**
 * Checks if a URL is from a common image hosting domain
 * @param url - URL to check
 * @returns True if from common image host, false otherwise
 */
function isCommonImageHost(url: string): boolean {
  const commonImageHosts = [
    'googleusercontent.com',
    'fbcdn.net',
    'twimg.com',
    'apple.com',
    'icloud.com',
    'gravatar.com'
  ];
  
  return commonImageHosts.some(host => url.includes(host));
}

/**
 * Validates profile picture URL
 * @param url - Profile picture URL
 * @returns Validated URL or undefined if invalid
 */
function validateProfilePicture(url: unknown): string | undefined {
  if (typeof url !== 'string') return undefined;
  
  const trimmed = url.trim();
  if (trimmed.length === 0) return undefined;
  if (!isValidUrl(trimmed)) return undefined;
  
  // Check if URL looks like an image (extension or common host)
  const imageUrlRegex = /\.(jpg|jpeg|png|gif|webp)(\?.*)?$/i;
  const hasImageExtension = imageUrlRegex.test(trimmed);
  const isFromImageHost = isCommonImageHost(trimmed);
  
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
function extractGoogleProfileData(userMetadata: Record<string, unknown>): ExtractedProfileData {
  const data: ExtractedProfileData = {};
  
  // Extract names with type checking
  if (typeof userMetadata.given_name === 'string') {
    const givenName: string = userMetadata.given_name;
    data.firstName = validateName(givenName);
  }
  
  if (typeof userMetadata.family_name === 'string') {
    const familyName: string = userMetadata.family_name;
    data.lastName = validateName(familyName);
  }
  
  // Fallback to parsing full name if individual names not available
  if (!data.firstName && !data.lastName && typeof userMetadata.name === 'string') {
    const nameValue: string = userMetadata.name;
    const fullName = validateName(nameValue);
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
  
  // Extract profile picture with type checking
  if (typeof userMetadata.picture === 'string') {
    const pictureUrl: string = userMetadata.picture;
    data.profilePicture = validateProfilePicture(pictureUrl);
  }
  
  // Store full name for reference with type checking
  if (typeof userMetadata.name === 'string') {
    const nameValue: string = userMetadata.name;
    data.fullName = validateName(nameValue);
  }
  
  // Email and phone are typically in the main user object, not metadata
  // But include them if present in metadata with type checking
  if (typeof userMetadata.email === 'string') {
    const emailValue: string = userMetadata.email;
    data.email = emailValue;
  }
  
  return data;
}

/**
 * Extracts profile data from Apple OAuth user metadata
 * @param userMetadata - User metadata from Apple OAuth
 * @returns Extracted profile data
 */
function extractAppleProfileData(userMetadata: AppleOAuthMetadata): ExtractedProfileData {
  const data: ExtractedProfileData = {};
  const { name, picture, email } = userMetadata;
  
  // Apple OAuth typically provides less data due to privacy settings
  if (name?.firstName) {
    data.firstName = validateName(name.firstName);
  }
  
  if (name?.lastName) {
    data.lastName = validateName(name.lastName);
  }
  
  // Apple OAuth rarely provides profile pictures
  if (picture) {
    data.profilePicture = validateProfilePicture(picture);
  }
  
  // Email is typically in the main user object for Apple OAuth
  if (email) {
    data.email = email;
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
 * Extracts provider-specific profile data from user metadata
 * @param provider - OAuth provider name
 * @param userMetadata - User metadata object from OAuth
 * @returns Extracted profile data
 */
function getProviderProfileData(provider: string, userMetadata: Record<string, unknown>): ExtractedProfileData {
  switch (provider) {
    case 'google':
      return extractGoogleProfileData(userMetadata);
    case 'apple':
      // Convert Record<string, unknown> to AppleOAuthMetadata safely
      const appleMetadata: AppleOAuthMetadata = {
        name: typeof userMetadata.name === 'object' && userMetadata.name !== null 
          ? userMetadata.name as { firstName?: string; lastName?: string }
          : undefined,
        picture: typeof userMetadata.picture === 'string' ? userMetadata.picture : undefined,
        email: typeof userMetadata.email === 'string' ? userMetadata.email : undefined
      };
      return extractAppleProfileData(appleMetadata);
    default:
      // Try generic extraction for unknown providers
      return extractGoogleProfileData(userMetadata);
  }
}

/**
 * Applies email and phone fallbacks from user object if not present in extracted data
 * @param extractedData - Profile data extracted from metadata
 * @param user - Supabase user object
 * @returns Updated extracted data with contact fallbacks applied
 */
function applyContactFallbacks(extractedData: ExtractedProfileData, user: User): ExtractedProfileData {
  const updatedData = { ...extractedData };
  
  // Always include email and phone from main user object if available
  if (user.email && !updatedData.email) {
    updatedData.email = user.email;
  }
  
  if (user.phone && !updatedData.phone) {
    updatedData.phone = user.phone;
  }
  
  return updatedData;
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
  
  try {
    // Extract provider-specific data
    let extractedData = getProviderProfileData(provider, user.user_metadata || {});
    
    // Apply contact fallbacks
    extractedData = applyContactFallbacks(extractedData, user);
    
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
  const updateData: {
    first_name?: string;
    last_name?: string;
    profile_picture?: string;
  } = {};
  
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