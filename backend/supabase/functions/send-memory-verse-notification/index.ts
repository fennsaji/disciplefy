// ============================================================================
// Send Memory Verse Notification Edge Function
// ============================================================================
// Sends push notifications for memory verse review reminders
// Triggered by GitHub Actions workflow at 9 AM across different timezones

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

interface MemoryVerseUser extends NotificationUser {
  readonly due_verse_count?: number
}

// ============================================================================
// Notification Content by Language
// ============================================================================

const REMINDER_TITLES: Record<string, string> = {
  en: '📚 Review Time',
  hi: '📚 समीक्षा करें',
  ml: '📚 അവലോകനം',
}

const REMINDER_BODIES: Record<string, (count: number) => string> = {
  en: (count) => `${count} verse${count === 1 ? '' : 's'} due today for review`,
  hi: (count) => `${count} वचन आज याद करने के लिए`,
  ml: (count) => `${count} വാക്യം ഇന്ന് ഓർമ്മിക്കാൻ`,
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleMemoryVerseNotification(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  const notificationHelper = createNotificationHelper()

  // Verify cron authentication
  notificationHelper.verifyCronSecret(req)

  console.log('[MemoryVerse] Starting reminder notification process...')

  const supabase = services.supabaseServiceClient

  // Step 1: Fetch eligible users
  const currentHour = new Date().getUTCHours()
  const currentMinute = new Date().getUTCMinutes()

  const { data: users, error } = await supabase.rpc(
    'get_memory_verse_reminder_notification_users',
    { target_hour: currentHour, target_minute: currentMinute }
  )

  if (error) {
    throw new AppError('DATABASE_ERROR', `Failed to fetch reminder users: ${error.message}`, 500)
  }

  const eligibleUsers: MemoryVerseUser[] = (users || []).map((u: { user_id: string; fcm_token: string; due_verse_count?: number }) => ({
    user_id: u.user_id,
    fcm_token: u.fcm_token,
    due_verse_count: u.due_verse_count,
  }))

  if (eligibleUsers.length === 0) {
    return notificationHelper.createSuccessResponse('No eligible users for reminder', {
      sentCount: 0,
    })
  }

  console.log(`[MemoryVerse] Found ${eligibleUsers.length} eligible users`)

  // Step 2: Filter out anonymous users
  const authenticatedUsers = await notificationHelper.filterAnonymousUsers(supabase, eligibleUsers)

  if (authenticatedUsers.length === 0) {
    return notificationHelper.createSuccessResponse('No authenticated users eligible', {
      sentCount: 0,
    })
  }

  // Step 3: Filter out users who already received notification today
  const userIds = authenticatedUsers.map(u => u.user_id)
  const alreadySentUserIds = await notificationHelper.getAlreadySentUserIds(userIds, 'memory_verse_reminder')
  const usersToNotify = authenticatedUsers.filter(u => !alreadySentUserIds.has(u.user_id))

  console.log(`[MemoryVerse] ${usersToNotify.length} users need notification (${alreadySentUserIds.size} already received)`)

  if (usersToNotify.length === 0) {
    return notificationHelper.createSuccessResponse('All users already received notification today', {
      sentCount: 0,
    })
  }

  // Step 4: Get user language preferences
  const languageMap = await notificationHelper.getUserLanguagePreferences(
    supabase,
    usersToNotify.map(u => u.user_id)
  )

  // Step 5: Send notifications using helper
  const result = await notificationHelper.sendNotificationBatch(
    usersToNotify,
    'memory_verse_reminder',
    languageMap,
    ({ user, language }: NotificationContentParams<MemoryVerseUser>) => {
      const dueVerseCount = Number(user.due_verse_count ?? 0)

      const title = REMINDER_TITLES[language] || REMINDER_TITLES.en
      const bodyFn = REMINDER_BODIES[language] || REMINDER_BODIES.en
      const body = bodyFn(dueVerseCount)

      return {
        title,
        body,
        data: {
          dueCount: String(dueVerseCount),
        },
      }
    }
  )

  console.log(`[MemoryVerse] Complete: ${result.successCount} sent, ${result.failureCount} failed`)

  return notificationHelper.createSuccessResponse('Memory verse reminder notifications sent', {
    totalEligible: usersToNotify.length,
    successCount: result.successCount,
    failureCount: result.failureCount,
  })
}

// ============================================================================
// Start Server
// ============================================================================

createSimpleFunction(handleMemoryVerseNotification, {
  allowedMethods: ['POST'],
  enableAnalytics: false,
})
