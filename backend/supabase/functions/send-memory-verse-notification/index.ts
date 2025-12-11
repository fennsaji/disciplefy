// ============================================================================
// Send Memory Verse Notification Edge Function
// ============================================================================
// Sends push notifications for memory verse review reminders and overdue alerts
// Triggered by GitHub Actions workflow at 9 AM across different timezones

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import {
  createNotificationHelper,
  NotificationUser,
  NotificationContentParams,
  NotificationType,
} from '../_shared/services/notification-helper-service.ts'
import { AppError } from '../_shared/utils/error-handler.ts'

// ============================================================================
// Types
// ============================================================================

interface MemoryVerseUser extends NotificationUser {
  readonly due_verse_count?: number
  readonly overdue_verse_count?: number
  readonly max_days_overdue?: number
}

type MemoryVerseNotificationType = 'reminder' | 'overdue'

// ============================================================================
// Notification Content by Language
// ============================================================================

const REMINDER_TITLES: Record<string, string> = {
  en: '📚 Time to Review!',
  hi: '📚 समीक्षा का समय!',
  ml: '📚 അവലോകന സമയം!',
}

const REMINDER_BODIES: Record<string, (count: number) => string> = {
  en: (count) => count === 1
    ? 'You have 1 verse ready for review. Keep building your scripture memory! 💪'
    : `You have ${count} verses ready for review. Strengthen your faith through God's Word! 💪`,
  hi: (count) => count === 1
    ? '1 वचन दोहराने के लिए तैयार है। वचन याद करते रहें! 💪'
    : `${count} वचन दोहराने के लिए तैयार हैं। परमेश्वर के वचन से विश्वास मजबूत करें! 💪`,
  ml: (count) => count === 1
    ? '1 വാക്യം ഓർമ്മിക്കാൻ തയ്യാറാണ്. വചനം മനഃപാഠമാക്കുന്നത് തുടരൂ! 💪'
    : `${count} വാക്യങ്ങൾ ഓർമ്മിക്കാൻ തയ്യാറാണ്. ദൈവവചനത്തിലൂടെ വിശ്വാസം ശക്തമാക്കൂ! 💪`,
}

const OVERDUE_TITLES: Record<string, string> = {
  en: "⏰ Don't Let Your Progress Slip!",
  hi: '⏰ अपनी प्रगति को न गंवाएं!',
  ml: '⏰ നിങ്ങളുടെ പുരോഗതി നഷ്ടപ്പെടുത്തരുത്!',
}

const OVERDUE_BODIES: Record<string, (count: number, days: number) => string> = {
  en: (count, days) => {
    const daysText = days === 1 ? '1 day' : `${days} days`
    return count === 1
      ? `1 verse is ${daysText} overdue. Review now to maintain your memory strength! 🙏`
      : `${count} verses are overdue (up to ${daysText}). Your effort is worth it - review now! 🙏`
  },
  hi: (count, days) => {
    const daysText = days === 1 ? '1 दिन' : `${days} दिन`
    return count === 1
      ? `1 वचन ${daysText} से छूट गया है। याद बनाए रखने के लिए अभी दोहराएं! 🙏`
      : `${count} वचन छूट गए हैं (${daysText} तक)। अभी दोहराएं! 🙏`
  },
  ml: (count, days) => {
    const daysText = days === 1 ? '1 ദിവസം' : `${days} ദിവസം`
    return count === 1
      ? `1 വാക്യം ${daysText} ആയി വൈകി. ഓർമ്മ നിലനിർത്താൻ ഇപ്പോൾ അവലോകനം ചെയ്യൂ! 🙏`
      : `${count} വാക്യങ്ങൾ വൈകിയിരിക്കുന്നു (${daysText} വരെ). ഇപ്പോൾ അവലോകനം ചെയ്യൂ! 🙏`
  },
}

// ============================================================================
// Helper Functions
// ============================================================================

function getNotificationTypeFromQuery(url: URL): MemoryVerseNotificationType {
  const rawType = url.searchParams.get('type')
  const validTypes: MemoryVerseNotificationType[] = ['reminder', 'overdue']

  if (!rawType) return 'reminder'
  if (validTypes.includes(rawType as MemoryVerseNotificationType)) {
    return rawType as MemoryVerseNotificationType
  }

  throw new AppError('VALIDATION_ERROR', `Invalid notification type: ${rawType}. Must be 'reminder' or 'overdue'.`, 400)
}

function getNotificationKey(type: MemoryVerseNotificationType): NotificationType {
  return type === 'reminder' ? 'memory_verse_reminder' : 'memory_verse_overdue'
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

  // Get notification type from query params
  const url = new URL(req.url)
  const notificationType = getNotificationTypeFromQuery(url)
  const notificationKey = getNotificationKey(notificationType)

  console.log(`[MemoryVerse] Starting ${notificationType} notification process...`)

  const supabase = services.supabaseServiceClient

  // Step 1: Fetch eligible users based on notification type
  let eligibleUsers: MemoryVerseUser[] = []

  if (notificationType === 'reminder') {
    const currentHour = new Date().getUTCHours()
    const currentMinute = new Date().getUTCMinutes()

    const { data: users, error } = await supabase.rpc(
      'get_memory_verse_reminder_notification_users',
      { target_hour: currentHour, target_minute: currentMinute }
    )

    if (error) {
      throw new AppError('DATABASE_ERROR', `Failed to fetch reminder users: ${error.message}`, 500)
    }

    eligibleUsers = (users || []).map((u: { user_id: string; fcm_token: string; due_verse_count?: number }) => ({
      user_id: u.user_id,
      fcm_token: u.fcm_token,
      due_verse_count: u.due_verse_count,
    }))
  } else {
    const { data: users, error } = await supabase.rpc('get_memory_verse_overdue_notification_users')

    if (error) {
      throw new AppError('DATABASE_ERROR', `Failed to fetch overdue users: ${error.message}`, 500)
    }

    eligibleUsers = (users || []).map((u: { user_id: string; fcm_token: string; overdue_verse_count?: number; max_days_overdue?: number }) => ({
      user_id: u.user_id,
      fcm_token: u.fcm_token,
      overdue_verse_count: u.overdue_verse_count,
      max_days_overdue: u.max_days_overdue,
    }))
  }

  if (eligibleUsers.length === 0) {
    return notificationHelper.createSuccessResponse(`No eligible users for ${notificationType}`, {
      type: notificationType,
      sentCount: 0,
    })
  }

  console.log(`[MemoryVerse] Found ${eligibleUsers.length} eligible users`)

  // Step 2: Filter out anonymous users
  const authenticatedUsers = await notificationHelper.filterAnonymousUsers(supabase, eligibleUsers)

  if (authenticatedUsers.length === 0) {
    return notificationHelper.createSuccessResponse('No authenticated users eligible', {
      type: notificationType,
      sentCount: 0,
    })
  }

  // Step 3: Filter out users who already received notification today
  const userIds = authenticatedUsers.map(u => u.user_id)
  const alreadySentUserIds = await notificationHelper.getAlreadySentUserIds(userIds, notificationKey)
  const usersToNotify = authenticatedUsers.filter(u => !alreadySentUserIds.has(u.user_id))

  console.log(`[MemoryVerse] ${usersToNotify.length} users need notification (${alreadySentUserIds.size} already received)`)

  if (usersToNotify.length === 0) {
    return notificationHelper.createSuccessResponse('All users already received notification today', {
      type: notificationType,
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
    notificationKey,
    languageMap,
    ({ user, language }: NotificationContentParams<MemoryVerseUser>) => {
      const dueVerseCount = Number(user.due_verse_count ?? 0)
      const overdueVerseCount = Number(user.overdue_verse_count ?? 0)
      const maxDaysOverdue = Number(user.max_days_overdue ?? 0)

      let title: string
      let body: string

      if (notificationType === 'reminder') {
        title = REMINDER_TITLES[language] || REMINDER_TITLES.en
        const bodyFn = REMINDER_BODIES[language] || REMINDER_BODIES.en
        body = bodyFn(dueVerseCount)
      } else {
        title = OVERDUE_TITLES[language] || OVERDUE_TITLES.en
        const bodyFn = OVERDUE_BODIES[language] || OVERDUE_BODIES.en
        body = bodyFn(overdueVerseCount, maxDaysOverdue)
      }

      const dueCount = notificationType === 'reminder' ? dueVerseCount : overdueVerseCount

      return {
        title,
        body,
        data: {
          dueCount: String(dueCount),
        },
      }
    }
  )

  console.log(`[MemoryVerse] Complete: ${result.successCount} sent, ${result.failureCount} failed`)

  return notificationHelper.createSuccessResponse(`Memory verse ${notificationType} notifications sent`, {
    type: notificationType,
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
