/**
 * Upload Profile Image Edge Function
 * 
 * Refactored to use clean architecture with function factory
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { UserContext } from '../_shared/types/index.ts'
import { AppError } from '../_shared/utils/error-handler.ts'

interface UploadImageRequest {
  action: 'upload_image' | 'delete_image' | 'get_upload_url'
  file_name?: string
  file_type?: string
  image_data?: string // Base64 encoded
}

// Configuration
const STORAGE_BUCKET = 'profile-images'
const MAX_FILE_SIZE = 5 * 1024 * 1024 // 5MB
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp']

// ============================================================================
// Validation Utilities
// ============================================================================

function validateImageUpload(fileName: string, fileType: string, imageData: string): void {
  if (!fileName || fileName.trim().length === 0) {
    throw new AppError('VALIDATION_ERROR', 'File name is required', 400)
  }
  
  if (!fileType || !ALLOWED_TYPES.includes(fileType)) {
    throw new AppError('VALIDATION_ERROR', `Invalid file type. Allowed: ${ALLOWED_TYPES.join(', ')}`, 400)
  }
  
  if (!imageData || imageData.trim().length === 0) {
    throw new AppError('VALIDATION_ERROR', 'Image data is required', 400)
  }
  
  if (!isValidBase64(imageData)) {
    throw new AppError('VALIDATION_ERROR', 'Invalid image data format', 400)
  }

  // Strip data URI prefix (e.g., "data:image/png;base64,") to get only base64 payload
  const base64Payload = imageData.includes(',')
    ? imageData.split(',')[1]
    : imageData;

  // Calculate actual byte size: count padding characters ('=')
  const paddingCount = (base64Payload.match(/=/g) || []).length;
  const sizeInBytes = (base64Payload.length * 3) / 4 - paddingCount;

  if (sizeInBytes > MAX_FILE_SIZE) {
    throw new AppError('VALIDATION_ERROR', `File too large. Max: ${MAX_FILE_SIZE / (1024 * 1024)}MB`, 400)
  }
  
  const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp']
  const hasValidExtension = allowedExtensions.some(ext => 
    fileName.toLowerCase().endsWith(ext)
  )
  
  if (!hasValidExtension) {
    throw new AppError('VALIDATION_ERROR', `Invalid extension. Allowed: ${allowedExtensions.join(', ')}`, 400)
  }
}

function isValidBase64(str: string): boolean {
  try {
    const base64Data = str.replace(/^data:image\/[a-z]+;base64,/, '')
    const decoded = atob(base64Data)
    return btoa(decoded) === base64Data
  } catch {
    return false
  }
}

function generateUniqueFileName(userId: string, originalFileName: string): string {
  const timestamp = Date.now()
  const extension = originalFileName.substring(originalFileName.lastIndexOf('.'))
  return `${userId}_${timestamp}${extension}`
}

function base64ToUint8Array(base64: string): Uint8Array {
  const base64Data = base64.replace(/^data:image\/[a-z]+;base64,/, '')
  const binaryString = atob(base64Data)
  const bytes = new Uint8Array(binaryString.length)
  
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i)
  }
  
  return bytes
}

// ============================================================================
// Core Functions
// ============================================================================

async function uploadImage(
  fileName: string,
  fileType: string,
  imageData: string,
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  validateImageUpload(fileName, fileType, imageData)

  const uniqueFileName = generateUniqueFileName(userId, fileName)
  const imageBytes = base64ToUint8Array(imageData)
  
  // Delete old image if exists
  const { data: profileData } = await services.supabaseServiceClient
    .from('user_profiles')
    .select('profile_image_url')
    .eq('id', userId)
    .single()
  
  if (profileData?.profile_image_url) {
    const oldFileName = profileData.profile_image_url.split('/').pop()
    if (oldFileName) {
      await services.supabaseServiceClient.storage
        .from(STORAGE_BUCKET)
        .remove([oldFileName])
    }
  }

  // Upload new image
  const { error: uploadError } = await services.supabaseServiceClient.storage
    .from(STORAGE_BUCKET)
    .upload(uniqueFileName, imageBytes, {
      contentType: fileType,
      cacheControl: '3600',
      upsert: true
    })

  if (uploadError) {
    throw new AppError('UPLOAD_ERROR', 'Failed to upload image', 500)
  }

  // Get public URL
  const { data: urlData } = services.supabaseServiceClient.storage
    .from(STORAGE_BUCKET)
    .getPublicUrl(uniqueFileName)

  if (!urlData?.publicUrl) {
    throw new AppError('UPLOAD_ERROR', 'Failed to get public URL', 500)
  }

  // Update profile
  const { data: updateData, error: updateError } = await services.supabaseServiceClient
    .from('user_profiles')
    .update({
      profile_image_url: urlData.publicUrl,
      updated_at: new Date().toISOString()
    })
    .eq('id', userId)
    .select('*')
    .single()

  if (updateError) {
    await services.supabaseServiceClient.storage
      .from(STORAGE_BUCKET)
      .remove([uniqueFileName])
    throw new AppError('DATABASE_ERROR', 'Failed to update profile', 500)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        image_url: urlData.publicUrl,
        file_name: uniqueFileName,
        profile: updateData
      }
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

async function deleteImage(
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  const { data: profileData, error: profileError } = await services.supabaseServiceClient
    .from('user_profiles')
    .select('profile_image_url')
    .eq('id', userId)
    .single()

  if (profileError) {
    throw new AppError('DATABASE_ERROR', 'Failed to get profile data', 500)
  }

  if (!profileData?.profile_image_url) {
    throw new AppError('VALIDATION_ERROR', 'No profile image to delete', 400)
  }

  const fileName = profileData.profile_image_url.split('/').pop()
  if (!fileName) {
    throw new AppError('VALIDATION_ERROR', 'Invalid image URL', 400)
  }

  const { error: deleteError } = await services.supabaseServiceClient.storage
    .from(STORAGE_BUCKET)
    .remove([fileName])

  if (deleteError) {
    throw new AppError('DELETE_ERROR', 'Failed to delete image', 500)
  }

  const { data: updateData, error: updateError } = await services.supabaseServiceClient
    .from('user_profiles')
    .update({
      profile_image_url: null,
      updated_at: new Date().toISOString()
    })
    .eq('id', userId)
    .select('*')
    .single()

  if (updateError) {
    throw new AppError('DATABASE_ERROR', 'Failed to update profile', 500)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        message: 'Image deleted successfully',
        profile: updateData
      }
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

async function getUploadUrl(
  fileName: string,
  fileType: string,
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  if (!fileName || !fileType) {
    throw new AppError('VALIDATION_ERROR', 'File name and type are required', 400)
  }

  if (!ALLOWED_TYPES.includes(fileType)) {
    throw new AppError('VALIDATION_ERROR', `Invalid file type. Allowed: ${ALLOWED_TYPES.join(', ')}`, 400)
  }

  const uniqueFileName = generateUniqueFileName(userId, fileName)

  const { data, error } = await services.supabaseServiceClient.storage
    .from(STORAGE_BUCKET)
    .createSignedUploadUrl(uniqueFileName, {
      upsert: true
    })

  if (error) {
    throw new AppError('UPLOAD_ERROR', 'Failed to create upload URL', 500)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        upload_url: data.signedUrl,
        file_name: uniqueFileName,
        expires_in: 3600
      }
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleUploadProfileImage(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  if (!userContext || userContext.type !== 'authenticated') {
    throw new AppError('UNAUTHORIZED', 'Authentication required', 401)
  }

  const userId = userContext.userId!
  const body: UploadImageRequest = await req.json()

  if (!body.action) {
    throw new AppError('VALIDATION_ERROR', 'Action is required', 400)
  }

  switch (body.action) {
    case 'upload_image':
      if (!body.file_name || !body.file_type || !body.image_data) {
        throw new AppError('VALIDATION_ERROR', 'File name, type, and data required for upload', 400)
      }
      return uploadImage(body.file_name, body.file_type, body.image_data, services, userId)
      
    case 'delete_image':
      return deleteImage(services, userId)

    case 'get_upload_url':
      if (!body.file_name || !body.file_type) {
        throw new AppError('VALIDATION_ERROR', 'File name and type required for upload URL', 400)
      }
      return getUploadUrl(body.file_name, body.file_type, services, userId)
      
    default:
      throw new AppError('VALIDATION_ERROR', 'Invalid action', 400)
  }
}

// ============================================================================
// Create Function with Factory
// ============================================================================

createAuthenticatedFunction(handleUploadProfileImage, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 30000 // 30s for image uploads
})
