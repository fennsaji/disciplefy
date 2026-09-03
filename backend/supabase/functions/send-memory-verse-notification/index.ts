// ============================================================================
// Send Memory Verse Notification Edge Function
// ============================================================================
// Sends push notifications for memory verse reviews. Two modes, selected by the
// `type` query parameter:
//   ?type=reminder (default) — verses due today, at the user's preferred time
//   ?type=overdue            — verses more than a day past due, 6 PM local
//
// Both are triggered hourly by the GitHub Actions workflow; the SQL selectors
// match users on a local-time catch-up window, so a delayed or dropped run is
// picked up later instead of skipping the day.

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import {
  createNotificationHelper,
  NotificationUser,
  NotificationContentParams,
} from '../_shared/services/notification-helper-service.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { DEDUP_LOOKBACK_HOURS } from '../_shared/utils/notification-window.ts'
import { i18n, type SupportedLocale } from '../_shared/services/i18n-service.ts'
import { loadAllLocales } from '../_shared/locales/index.ts'

// ============================================================================
// Types
// ============================================================================

interface MemoryVerseUser extends NotificationUser {
  readonly due_verse_count?: number
  readonly overdue_verse_count?: number
}

/** Which of the two notification modes this invocation should run. */
type MemoryVerseMode = 'reminder' | 'overdue'

interface ModeConfig {
  readonly rpc: string
  readonly notificationType: 'memory_verse_reminder' | 'memory_verse_overdue'
  readonly i18nKey: string
  /** Which count from the selector drives the message. */
  readonly countOf: (user: MemoryVerseUser) => number
}

const MODES: Record<MemoryVerseMode, ModeConfig> = {
  reminder: {
    rpc: 'get_memory_verse_reminder_notification_users',
    notificationType: 'memory_verse_reminder',
    i18nKey: 'notification.memoryVerse.reminder',
    countOf: (u) => Number(u.due_verse_count ?? 0),
  },
  overdue: {
    rpc: 'get_memory_verse_overdue_notification_users',
    notificationType: 'memory_verse_overdue',
    i18nKey: 'notification.memoryVerse.overdue',
    countOf: (u) => Number(u.overdue_verse_count ?? 0),
  },
}

/**
 * Reads the mode from `?type=`. Anything unrecognised falls back to reminder,
 * matching the previous behaviour of this endpoint.
 */
function resolveMode(req: Request): MemoryVerseMode {
  const type = new URL(req.url).searchParams.get('type')
  return type === 'overdue' ? 'overdue' : 'reminder'
}

// ============================================================================
// Initialize i18n
// ============================================================================

// Load all translation files on module initialization
loadAllLocales()

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

  const mode = resolveMode(req)
  const config = MODES[mode]

  console.log(`[MemoryVerse] Starting ${mode} notification process...`)

  const supabase = services.supabaseServiceClient

  // Step 1: Fetch eligible users. The selector matches on a local-time
  // catch-up window, so the real clock minute is passed through unrounded.
  const now = new Date()

  const { data: users, error } = await supabase.rpc(
    config.rpc,
    { target_hour: now.getUTCHours(), target_minute: now.getUTCMinutes() }
  )

  if (error) {
    throw new AppError('DATABASE_ERROR', `Failed to fetch ${mode} users: ${error.message}`, 500)
  }

  const eligibleUsers: MemoryVerseUser[] = (users || []).map(
    (u: { user_id: string; fcm_token: string; due_verse_count?: number; overdue_verse_count?: number }) => ({
      user_id: u.user_id,
      fcm_token: u.fcm_token,
      due_verse_count: u.due_verse_count,
      overdue_verse_count: u.overdue_verse_count,
    })
  )

  if (eligibleUsers.length === 0) {
    return notificationHelper.createSuccessResponse(`No eligible users for ${mode}`, {
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
  const alreadySentUserIds = await notificationHelper.getAlreadySentUserIds(
    userIds,
    config.notificationType,
    DEDUP_LOOKBACK_HOURS
  )
  const dedupedUsers = authenticatedUsers.filter(u => !alreadySentUserIds.has(u.user_id))

  // Space out categories — a user notified by another category within the last
  // hour is deferred to a later run, still inside this window.
  const usersToNotify = await notificationHelper.excludeRecentlyNotified(dedupedUsers)

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
    config.notificationType,
    languageMap,
    ({ user, language }: NotificationContentParams<MemoryVerseUser>) => {
      const verseCount = config.countOf(user)

      // Normalize language to supported locale (fallback to 'en')
      const locale = (['en', 'hi', 'ml'].includes(language) ? language : 'en') as SupportedLocale

      // Use i18n service for proper pluralization in all languages
      const title = i18n.t('notification.memoryVerse.title', { locale })
      const body = i18n.t(config.i18nKey, { locale, count: verseCount })

      // Fallback to English if translation fails
      const finalTitle = title.startsWith('notification.')
        ? i18n.t('notification.memoryVerse.title', { locale: 'en' })
        : title
      const finalBody = body.startsWith('notification.')
        ? i18n.t(config.i18nKey, { locale: 'en', count: verseCount })
        : body

      return {
        title: finalTitle,
        body: finalBody,
        data: {
          dueCount: String(verseCount),
        },
      }
    }
  )

  console.log(`[MemoryVerse] ${mode} complete: ${result.successCount} sent, ${result.failureCount} failed`)

  return notificationHelper.createSuccessResponse(`Memory verse ${mode} notifications sent`, {
    mode,
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
