// ============================================================================
// Send Recommended Topic Notification Edge Function
// ============================================================================
// Sends recommended Bible study topic push notifications to all eligible users
// Triggered by GitHub Actions workflow at 8 AM across different timezones

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { FCMService, logNotification } from '../_shared/fcm-service.ts'
import { selectTopicForUser, getLocalizedTopicContent } from '../_shared/topic-selector.ts'
import {
  createNotificationHelper,
  NotificationUser,
} from '../_shared/services/notification-helper-service.ts'
import { AppError } from '../_shared/utils/error-handler.ts'

// ============================================================================
// Types
// ============================================================================

interface RecommendedTopicUser extends NotificationUser {
  readonly timezone_offset_minutes: number
}

// ============================================================================
// Notification Titles by Language
// ============================================================================

const NOTIFICATION_TITLES: Record<string, string> = {
  en: '💡 Recommended Topic',
  hi: '💡 अनुशंसित विषय',
  ml: '💡 ശുപാർശിത വിഷയം',
}

const NOTIFICATION_INTROS: Record<string, string> = {
  en: 'Explore today:',
  hi: 'आज जानें:',
  ml: 'ഇന്ന് പര്യവേക്ഷണം ചെയ്യുക:',
}

// ============================================================================
// Helper Functions
// ============================================================================

function calculateTimezoneOffsetRange(currentHour: number): { offsetRangeMin: number; offsetRangeMax: number } {
  let targetOffsetMinutes = (8 - currentHour) * 60 // 8 AM target

  // Normalize to valid timezone range: -720 (UTC-12) to +840 (UTC+14)
  if (targetOffsetMinutes < -720) {
    targetOffsetMinutes += 1440
  } else if (targetOffsetMinutes > 840) {
    targetOffsetMinutes -= 1440
  }

  const offsetRangeMin = Math.max(-720, targetOffsetMinutes - 180)
  const offsetRangeMax = Math.min(840, targetOffsetMinutes + 180)

  return { offsetRangeMin, offsetRangeMax }
}

async function fetchEligibleUsersWithTimezone(
  supabase: ServiceContainer['supabaseServiceClient'],
  offsetRangeMin: number,
  offsetRangeMax: number
): Promise<RecommendedTopicUser[]> {
  // Fetch all tokens
  const { data: tokens, error: tokensError } = await supabase
    .from('user_notification_tokens')
    .select('user_id, fcm_token')

  if (tokensError) {
    throw new AppError('DATABASE_ERROR', `Failed to fetch tokens: ${tokensError.message}`, 500)
  }

  // Handle wrap-around case
  let preferences: Array<{ user_id: string; timezone_offset_minutes: number }>

  if (offsetRangeMin > offsetRangeMax) {
    const [result1, result2] = await Promise.all([
      supabase
        .from('user_notification_preferences')
        .select('user_id, timezone_offset_minutes, recommended_topic_enabled')
        .eq('recommended_topic_enabled', true)
        .gte('timezone_offset_minutes', offsetRangeMin)
        .lte('timezone_offset_minutes', 840),

      supabase
        .from('user_notification_preferences')
        .select('user_id, timezone_offset_minutes, recommended_topic_enabled')
        .eq('recommended_topic_enabled', true)
        .gte('timezone_offset_minutes', -720)
        .lte('timezone_offset_minutes', offsetRangeMax)
    ])

    if (result1.error || result2.error) {
      throw new AppError('DATABASE_ERROR', `Failed to fetch preferences: ${(result1.error || result2.error)!.message}`, 500)
    }

    preferences = [...(result1.data || []), ...(result2.data || [])]
  } else {
    const { data, error } = await supabase
      .from('user_notification_preferences')
      .select('user_id, timezone_offset_minutes, recommended_topic_enabled')
      .eq('recommended_topic_enabled', true)
      .gte('timezone_offset_minutes', offsetRangeMin)
      .lte('timezone_offset_minutes', offsetRangeMax)

    if (error) {
      throw new AppError('DATABASE_ERROR', `Failed to fetch preferences: ${error.message}`, 500)
    }

    preferences = data || []
  }

  // Manual join: match tokens with preferences
  const prefsMap = new Map(preferences.map(p => [p.user_id, p]))
  return tokens?.filter((t: { user_id: string; fcm_token: string }) => prefsMap.has(t.user_id))
    .map((t: { user_id: string; fcm_token: string }) => ({
      user_id: t.user_id,
      fcm_token: t.fcm_token,
      timezone_offset_minutes: prefsMap.get(t.user_id)!.timezone_offset_minutes
    })) || []
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleRecommendedTopicNotification(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  const notificationHelper = createNotificationHelper()

  // Verify cron authentication
  notificationHelper.verifyCronSecret(req)

  console.log('[RecommendedTopic] Starting notification process...')

  const supabase = services.supabaseServiceClient
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
  const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // Step 1: Calculate timezone offset range
  const currentHour = new Date().getUTCHours()
  const { offsetRangeMin, offsetRangeMax } = calculateTimezoneOffsetRange(currentHour)
  console.log(`[RecommendedTopic] UTC hour: ${currentHour}, offset range: ${offsetRangeMin} to ${offsetRangeMax}`)

  // Step 2: Fetch eligible users
  const allUsers = await fetchEligibleUsersWithTimezone(supabase, offsetRangeMin, offsetRangeMax)

  if (allUsers.length === 0) {
    return notificationHelper.createSuccessResponse('No eligible users', { sentCount: 0 })
  }

  console.log(`[RecommendedTopic] Found ${allUsers.length} users with tokens`)

  // Step 3: Filter out anonymous users
  const authenticatedUsers = await notificationHelper.filterAnonymousUsers(supabase, allUsers)

  if (authenticatedUsers.length === 0) {
    return notificationHelper.createSuccessResponse('No authenticated users eligible', { sentCount: 0 })
  }

  // Step 4: Filter out users who already received notification today
  const userIds = authenticatedUsers.map(u => u.user_id)
  const alreadySentUserIds = await notificationHelper.getAlreadySentUserIds(userIds, 'recommended_topic')
  const usersToNotify = authenticatedUsers.filter(u => !alreadySentUserIds.has(u.user_id))

  console.log(`[RecommendedTopic] ${usersToNotify.length} users need notification (${alreadySentUserIds.size} already received)`)

  if (usersToNotify.length === 0) {
    return notificationHelper.createSuccessResponse('All users already received notification today', { sentCount: 0 })
  }

  // Step 5: Get user language preferences
  const languageMap = await notificationHelper.getUserLanguagePreferences(
    supabase,
    usersToNotify.map(u => u.user_id)
  )

  // Step 6: Send notifications with topic selection (custom batch logic due to per-user topic selection)
  const fcmService = new FCMService()
  let successCount = 0
  let failureCount = 0
  let topicSelectionFailures = 0
  const uniqueTopicIds = new Set<string>()
  const BATCH_SIZE = 10

  for (let i = 0; i < usersToNotify.length; i += BATCH_SIZE) {
    const batch = usersToNotify.slice(i, i + BATCH_SIZE)

    const results = await Promise.allSettled(
      batch.map(async (user) => {
        try {
          const language = languageMap.get(user.user_id) || 'en'

          // Select topic for this user
          const topicResult = await selectTopicForUser(
            SUPABASE_URL,
            SUPABASE_SERVICE_ROLE_KEY,
            user.user_id,
            language
          )

          if (!topicResult.success || !topicResult.topic) {
            console.error(`[RecommendedTopic] Topic selection failed for user ${user.user_id}:`, topicResult.error)
            return { success: false, topicSelectionFailed: true }
          }

          const localizedContent = await getLocalizedTopicContent(
            SUPABASE_URL,
            SUPABASE_SERVICE_ROLE_KEY,
            topicResult.topic,
            language
          )

          const title = NOTIFICATION_TITLES[language] || NOTIFICATION_TITLES.en
          const intro = NOTIFICATION_INTROS[language] || NOTIFICATION_INTROS.en
          const body = `${intro} ${localizedContent.title}`

          const result = await fcmService.sendNotification({
            token: user.fcm_token,
            notification: { title, body },
            data: {
              type: 'recommended_topic',
              topic_id: topicResult.topic.id,
              topic_title: localizedContent.title,
              topic_description: localizedContent.description,
              language,
            },
            android: { priority: 'high' },
            apns: {
              headers: { 'apns-priority': '10' },
              payload: { aps: { sound: 'default', badge: 1 } },
            },
          })

          await logNotification(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
            userId: user.user_id,
            notificationType: 'recommended_topic',
            title,
            body,
            topicId: topicResult.topic.id,
            language,
            deliveryStatus: result.success ? 'sent' : 'failed',
            fcmMessageId: result.messageId,
            errorMessage: result.error,
          })

          return { success: result.success, topicId: topicResult.topic.id }
        } catch (error) {
          console.error(`[RecommendedTopic] Error for user ${user.user_id}:`, error)
          return { success: false }
        }
      })
    )

    results.forEach((result) => {
      if (result.status === 'fulfilled') {
        const value = result.value as { success: boolean; topicSelectionFailed?: boolean; topicId?: string }
        if (value.topicSelectionFailed) {
          topicSelectionFailures++
          failureCount++
        } else if (value.success) {
          successCount++
          if (value.topicId) uniqueTopicIds.add(value.topicId)
        } else {
          failureCount++
        }
      } else {
        failureCount++
      }
    })

    console.log(`[RecommendedTopic] Batch ${Math.floor(i / BATCH_SIZE) + 1} complete: ${successCount} sent, ${failureCount} failed`)
  }

  console.log(`[RecommendedTopic] Complete: ${successCount} sent, ${failureCount} failed`)

  return notificationHelper.createSuccessResponse('Recommended topic notifications sent', {
    totalEligible: usersToNotify.length,
    successCount,
    failureCount,
    topicSelectionFailures,
    uniqueTopicsSent: uniqueTopicIds.size,
  })
}

// ============================================================================
// Start Server
// ============================================================================

createSimpleFunction(handleRecommendedTopicNotification, {
  allowedMethods: ['POST'],
  enableAnalytics: false,
})
