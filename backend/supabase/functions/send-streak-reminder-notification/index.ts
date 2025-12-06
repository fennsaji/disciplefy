// ============================================================================
// Send Streak Reminder Notification Edge Function
// ============================================================================
// Sends streak reminder push notifications to users who haven't viewed today's verse
// Triggered by GitHub Actions workflow at user's preferred reminder time (default 8 PM)

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import {
  createNotificationHelper,
  NotificationUser,
  NotificationContentParams,
} from '../_shared/services/notification-helper-service.ts'
import { AppError } from '../_shared/utils/error-handler.ts'

// ============================================================================
// Types
// ============================================================================

interface StreakReminderUser extends NotificationUser {
  readonly current_streak?: number
}

// ============================================================================
// Notification Messages by Language
// ============================================================================

const NOTIFICATION_MESSAGES: Record<string, { title: string; body: (streak: number) => string }> = {
  en: {
    title: '⚡ Streak Reminder',
    body: (streak: number) => streak > 0
      ? `Don't break your ${streak}-day streak! 🔥 Read today's verse now.`
      : `Start building your daily verse streak today! 📖`
  },
  hi: {
    title: '⚡ स्ट्रीक रिमाइंडर',
    body: (streak: number) => streak > 0
      ? `अपनी ${streak} दिन की स्ट्रीक मत तोड़ें! 🔥 आज का पद अभी पढ़ें।`
      : `आज अपनी दैनिक पद स्ट्रीक शुरू करें! 📖`
  },
  ml: {
    title: '⚡ സ്ട്രീക് ഓർമ്മപ്പെടുത്തൽ',
    body: (streak: number) => streak > 0
      ? `നിങ്ങളുടെ ${streak} ദിവസത്തെ സ്ട്രീക് തകർക്കരുത്! 🔥 ഇന്നത്തെ വാക്യം ഇപ്പോൾ വായിക്കൂ.`
      : `ഇന്ന് നിങ്ങളുടെ ദൈനംദിന വാക്യ സ്ട്രീക് ആരംഭിക്കൂ! 📖`
  },
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleStreakReminderNotification(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  const notificationHelper = createNotificationHelper()

  // Verify cron authentication
  notificationHelper.verifyCronSecret(req)

  console.log('[StreakReminder] Starting notification process...')

  const supabase = services.supabaseServiceClient

  // Step 1: Get current time in UTC
  const now = new Date()
  const currentHour = now.getUTCHours()
  const currentMinute = now.getUTCMinutes()
  console.log(`[StreakReminder] Current UTC time: ${currentHour}:${String(currentMinute).padStart(2, '0')}`)

  // Step 2: Use the helper function to get users who need streak reminders
  const { data: eligibleUsers, error: usersError } = await supabase
    .rpc('get_streak_reminder_notification_users', {
      target_hour: currentHour,
      target_minute: Math.floor(currentMinute / 15) * 15
    })

  if (usersError) {
    throw new AppError('DATABASE_ERROR', `Failed to fetch eligible users: ${usersError.message}`, 500)
  }

  if (!eligibleUsers || eligibleUsers.length === 0) {
    return notificationHelper.createSuccessResponse('No eligible users for streak reminders', { sentCount: 0 })
  }

  const mappedUsers: StreakReminderUser[] = eligibleUsers.map((u: { user_id: string; fcm_token: string; current_streak?: number }) => ({
    user_id: u.user_id,
    fcm_token: u.fcm_token,
    current_streak: u.current_streak,
  }))

  console.log(`[StreakReminder] Found ${mappedUsers.length} eligible users`)

  // Step 3: Filter out anonymous users
  const authenticatedUsers = await notificationHelper.filterAnonymousUsers(supabase, mappedUsers)

  if (authenticatedUsers.length === 0) {
    return notificationHelper.createSuccessResponse('No authenticated users eligible', { sentCount: 0 })
  }

  // Step 4: Filter out users who already received streak reminder today
  const userIds = authenticatedUsers.map(u => u.user_id)
  const alreadySentUserIds = await notificationHelper.getAlreadySentUserIds(userIds, 'streak_reminder')
  const usersToNotify = authenticatedUsers.filter(u => !alreadySentUserIds.has(u.user_id))

  console.log(`[StreakReminder] ${usersToNotify.length} users need notification (${alreadySentUserIds.size} already received)`)

  if (usersToNotify.length === 0) {
    return notificationHelper.createSuccessResponse('All users already received notification today', { sentCount: 0 })
  }

  // Step 5: Get user language preferences
  const languageMap = await notificationHelper.getUserLanguagePreferences(
    supabase,
    usersToNotify.map(u => u.user_id)
  )

  // Step 6: Send notifications using helper
  const result = await notificationHelper.sendNotificationBatch(
    usersToNotify,
    'streak_reminder',
    languageMap,
    ({ user, language }: NotificationContentParams<StreakReminderUser>) => {
      const currentStreak = user.current_streak || 0
      const messages = NOTIFICATION_MESSAGES[language] || NOTIFICATION_MESSAGES.en

      return {
        title: messages.title,
        body: messages.body(currentStreak),
        data: {
          current_streak: String(currentStreak),
        },
      }
    }
  )

  console.log(`[StreakReminder] Complete: ${result.successCount} sent, ${result.failureCount} failed`)

  return notificationHelper.createSuccessResponse('Streak reminder notifications sent', {
    totalEligible: usersToNotify.length,
    successCount: result.successCount,
    failureCount: result.failureCount,
  })
}

// ============================================================================
// Start Server
// ============================================================================

createSimpleFunction(handleStreakReminderNotification, {
  allowedMethods: ['POST'],
  enableAnalytics: false,
})
