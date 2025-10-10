/**
 * Feedback Edge Function
 * 
 * Refactored to use clean architecture with function factory
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'

interface FeedbackRequest {
  readonly study_guide_id?: string
  readonly was_helpful: boolean
  readonly message?: string
  readonly category?: string
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleFeedback(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  const requestBody = await req.json() as FeedbackRequest

  // Validate required fields
  if (typeof requestBody.was_helpful !== 'boolean') {
    throw new AppError('VALIDATION_ERROR', 'was_helpful field is required and must be a boolean', 400)
  }

  // Optional validation for study_guide_id
  if (requestBody.study_guide_id && typeof requestBody.study_guide_id !== 'string') {
    throw new AppError('VALIDATION_ERROR', 'study_guide_id must be a string', 400)
  }

  // Insert feedback
  const { data, error } = await services.supabaseServiceClient
    .from('feedback')
    .insert({
      study_guide_id: requestBody.study_guide_id || null,
      was_helpful: requestBody.was_helpful,
      message: requestBody.message || null,
      category: requestBody.category || 'general',
      user_id: null, // Anonymous feedback
      created_at: new Date().toISOString()
    })
    .select()
    .single()

  if (error) {
    console.error('Database error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to save feedback', 500)
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        id: data.id,
        was_helpful: data.was_helpful,
        message: data.message,
        category: data.category,
        created_at: data.created_at
      },
      message: 'Thank you for your feedback!'
    }),
    { status: 201, headers: { 'Content-Type': 'application/json' } }
  )
}

// ============================================================================
// Create Function with Factory
// ============================================================================

createSimpleFunction(handleFeedback, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 15000
})
