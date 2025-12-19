/**
 * Get Daily Goal Edge Function
 * 
 * Retrieves or creates today's daily goal for the user.
 * 
 * Features:
 * - Gets or creates today's daily goal record
 * - Returns target reviews and new verses
 * - Shows current progress (completed reviews and added verses)
 * - Indicates if goal is achieved
 * - Includes bonus XP awarded
 * 
 * Query Parameters:
 * - date (optional): Get goal for specific date (YYYY-MM-DD), defaults to today
 * 
 * Version: 2.4.0 - Memory Verses Enhancement (Sprint 3)
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'

/**
 * Daily goal structure
 */
interface DailyGoal {
  readonly id: string
  readonly user_id: string
  readonly goal_date: string
  readonly target_reviews: number
  readonly completed_reviews: number
  readonly target_new_verses: number
  readonly added_new_verses: number
  readonly goal_achieved: boolean
  readonly bonus_xp_awarded: number
  readonly created_at: string
}

/**
 * API response structure
 */
interface GetDailyGoalResponse extends ApiSuccessResponse<DailyGoal> {}

/**
 * Validate date string format (YYYY-MM-DD)
 */
function isValidDateFormat(dateString: string): boolean {
  const regex = /^\d{4}-\d{2}-\d{2}$/
  if (!regex.test(dateString)) {
    return false
  }
  
  const date = new Date(dateString)
  return date instanceof Date && !isNaN(date.getTime())
}

/**
 * Main handler for fetching daily goal
 */
async function handleGetDailyGoal(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  
  // Validate authentication
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError('AUTHENTICATION_ERROR', 'Authentication required to access daily goal', 401)
  }

  // Parse query parameters
  const url = new URL(req.url)
  const dateParam = url.searchParams.get('date')
  
  // Get today's date or validate provided date
  let goalDate: string
  if (dateParam) {
    if (!isValidDateFormat(dateParam)) {
      throw new AppError('VALIDATION_ERROR', 'Invalid date format. Use YYYY-MM-DD', 400)
    }
    goalDate = dateParam
  } else {
    // Default to today in UTC
    const today = new Date()
    goalDate = today.toISOString().split('T')[0]
  }

  // Try to fetch existing goal
  const { data: existingGoal, error: fetchError } = await services.supabaseServiceClient
    .from('memory_daily_goals')
    .select('*')
    .eq('user_id', userContext.userId)
    .eq('goal_date', goalDate)
    .maybeSingle()

  if (fetchError) {
    console.error('[GetDailyGoal] Fetch error:', fetchError)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch daily goal', 500)
  }

  // If goal exists, return it
  if (existingGoal) {
    const response: GetDailyGoalResponse = {
      success: true,
      data: existingGoal
    }

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store, no-cache, must-revalidate' // Don't cache goal data
      }
    })
  }

  // Create new goal with default targets
  const newGoalData = {
    user_id: userContext.userId,
    goal_date: goalDate,
    target_reviews: 5,
    completed_reviews: 0,
    target_new_verses: 1,
    added_new_verses: 0,
    goal_achieved: false,
    bonus_xp_awarded: 0
  }

  const { data: createdGoal, error: createError } = await services.supabaseServiceClient
    .from('memory_daily_goals')
    .insert(newGoalData)
    .select()
    .single()

  if (createError) {
    console.error('[GetDailyGoal] Create error:', createError)
    throw new AppError('DATABASE_ERROR', 'Failed to create daily goal', 500)
  }

  if (!createdGoal) {
    throw new AppError('DATABASE_ERROR', 'No goal data returned after creation', 500)
  }

  // Log analytics event
  await services.analyticsLogger.logEvent('daily_goal_fetched', {
    user_id: userContext.userId,
    goal_date: goalDate,
    is_new_goal: true,
    target_reviews: createdGoal.target_reviews,
    target_new_verses: createdGoal.target_new_verses
  }, req.headers.get('x-forwarded-for'))

  const response: GetDailyGoalResponse = {
    success: true,
    data: createdGoal
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store, no-cache, must-revalidate' // Don't cache goal data
    }
  })
}

// Create the authenticated function
createAuthenticatedFunction(handleGetDailyGoal, {
  allowedMethods: ['GET'],
  enableAnalytics: true,
  timeout: 10000 // 10 seconds
})
