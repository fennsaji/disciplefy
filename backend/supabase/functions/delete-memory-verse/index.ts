/**
 * Delete Memory Verse Edge Function
 *
 * Deletes a memory verse from the user's deck.
 * Also cleans up associated review sessions and history.
 *
 * Features:
 * - Removes memory verse from database
 * - Cleans up associated review sessions
 * - Cleans up associated review history
 * - Only allows users to delete their own verses
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'

/**
 * Response data structure
 */
interface DeleteVerseData {
  readonly success: boolean
  readonly deleted_verse_id: string
}

/**
 * API response structure
 */
interface DeleteVerseResponse extends ApiSuccessResponse<DeleteVerseData> {}

/**
 * Main handler for deleting memory verse
 */
async function handleDeleteMemoryVerse(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {

  // Validate authentication
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError('AUTHENTICATION_ERROR', 'Authentication required to delete memory verses', 401)
  }

  // Get memory_verse_id from query parameter
  const url = new URL(req.url)
  const memoryVerseId = url.searchParams.get('memory_verse_id')

  // Validate required field
  if (!memoryVerseId) {
    throw new AppError('VALIDATION_ERROR', 'memory_verse_id is required', 400)
  }

  // Validate UUID format
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  if (!uuidRegex.test(memoryVerseId)) {
    throw new AppError('VALIDATION_ERROR', 'Invalid memory_verse_id format', 400)
  }

  // First verify the verse exists and belongs to the user
  const { data: existingVerse, error: fetchError } = await services.supabaseServiceClient
    .from('memory_verses')
    .select('id')
    .eq('id', memoryVerseId)
    .eq('user_id', userContext.userId)
    .single()

  if (fetchError || !existingVerse) {
    console.error('[DeleteMemoryVerse] Verse not found:', fetchError)
    throw new AppError('NOT_FOUND', 'Memory verse not found or does not belong to user', 404)
  }

  // Delete associated review sessions first (foreign key constraint)
  const { error: sessionsError } = await services.supabaseServiceClient
    .from('review_sessions')
    .delete()
    .eq('memory_verse_id', memoryVerseId)
    .eq('user_id', userContext.userId)

  if (sessionsError) {
    console.error('[DeleteMemoryVerse] Error deleting review sessions:', sessionsError)
    // Continue anyway - verse deletion is more important
  }

  // Delete associated review history (foreign key constraint)
  const { error: historyError } = await services.supabaseServiceClient
    .from('review_history')
    .delete()
    .eq('memory_verse_id', memoryVerseId)
    .eq('user_id', userContext.userId)

  if (historyError) {
    console.error('[DeleteMemoryVerse] Error deleting review history:', historyError)
    // Continue anyway - verse deletion is more important
  }

  // Delete the memory verse
  const { error: deleteError } = await services.supabaseServiceClient
    .from('memory_verses')
    .delete()
    .eq('id', memoryVerseId)
    .eq('user_id', userContext.userId)

  if (deleteError) {
    console.error('[DeleteMemoryVerse] Delete error:', deleteError)
    throw new AppError('DATABASE_ERROR', 'Failed to delete memory verse', 500)
  }

  // Log analytics event (non-fatal)
  try {
    await services.analyticsLogger.logEvent('memory_verse_deleted', {
      user_id: userContext.userId,
      memory_verse_id: memoryVerseId
    }, req.headers.get('x-forwarded-for'))
  } catch (analyticsError) {
    console.error('[DeleteMemoryVerse] Analytics logging failed:', {
      error: analyticsError,
      user_id: userContext.userId,
      memory_verse_id: memoryVerseId
    })
    // Don't rethrow - analytics failures should not block deletion
  }

  // Build response data
  const responseData: DeleteVerseData = {
    success: true,
    deleted_verse_id: memoryVerseId
  }

  const response: DeleteVerseResponse = {
    success: true,
    data: responseData
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: {
      'Content-Type': 'application/json'
    }
  })
}

// Create the authenticated function
createAuthenticatedFunction(handleDeleteMemoryVerse, {
  allowedMethods: ['DELETE'],
  enableAnalytics: true,
  timeout: 10000 // 10 seconds
})
