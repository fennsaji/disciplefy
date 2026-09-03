// ============================================================================
// Send Streak Notification Edge Function
// ============================================================================
// Two modes, selected by the `type` query parameter:
//   ?type=reminder (default) — nudge users who haven't viewed today's verse,
//                              at their preferred time (default 8 PM local)
//   ?type=lost               — "Streak Reset Motivation" for users whose streak
//                              has already broken, ~10 AM local
//
// Both are triggered hourly; the SQL selectors match on a local-time catch-up
// window so a delayed or dropped run is picked up by a later one.

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import {
  createNotificationHelper,
  NotificationUser,
  NotificationContentParams,
} from '../_shared/services/notification-helper-service.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { DEDUP_LOOKBACK_HOURS } from '../_shared/utils/notification-window.ts'

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

/** Messages for a streak that has already broken (Streak Reset Motivation). */
const STREAK_LOST_MESSAGES: Record<string, { title: string; body: (streak: number) => string }> = {
  en: {
    title: '💪 Start a New Streak',
    body: (streak: number) =>
      `Your ${streak}-day streak ended — every streak starts with one day. Read today's verse. 📖`
  },
  hi: {
    title: '💪 नई स्ट्रीक शुरू करें',
    body: (streak: number) =>
      `आपकी ${streak} दिन की स्ट्रीक समाप्त हो गई — हर स्ट्रीक एक दिन से शुरू होती है। आज का पद पढ़ें। 📖`
  },
  ml: {
    title: '💪 പുതിയ സ്ട്രീക് ആരംഭിക്കൂ',
    body: (streak: number) =>
      `നിങ്ങളുടെ ${streak} ദിവസത്തെ സ്ട്രീക് അവസാനിച്ചു — എല്ലാ സ്ട്രീക്കും ഒരു ദിവസത്തിൽ തുടങ്ങുന്നു. ഇന്നത്തെ വാക്യം വായിക്കൂ. 📖`
  },
}

/** Which of the two modes this invocation should run. */
type StreakMode = 'reminder' | 'lost'

interface ModeConfig {
  readonly rpc: string
  readonly notificationType: 'streak_reminder' | 'streak_lost'
  readonly messages: Record<string, { title: string; body: (streak: number) => string }>
}

const MODES: Record<StreakMode, ModeConfig> = {
  reminder: {
    rpc: 'get_streak_reminder_notification_users',
    notificationType: 'streak_reminder',
    messages: NOTIFICATION_MESSAGES,
  },
  lost: {
    rpc: 'get_streak_lost_notification_users',
    notificationType: 'streak_lost',
    messages: STREAK_LOST_MESSAGES,
  },
}

/**
 * Reads the mode from `?type=`. Anything unrecognised falls back to reminder,
 * matching the previous behaviour of this endpoint.
 */
function resolveMode(req: Request): StreakMode {
  const type = new URL(req.url).searchParams.get('type')
  return type === 'lost' ? 'lost' : 'reminder'
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

  const mode = resolveMode(req)
  const config = MODES[mode]

  console.log(`[Streak] Starting ${mode} notification process...`)

  const supabase = services.supabaseServiceClient

  // Step 1: Get current time in UTC
  const now = new Date()
  const currentHour = now.getUTCHours()
  const currentMinute = now.getUTCMinutes()
  console.log(`[Streak] Current UTC time: ${currentHour}:${String(currentMinute).padStart(2, '0')}`)

  // Step 2: Select eligible users.
  // The real clock minute is passed through as-is: the RPC matches everyone
  // whose local target time has already passed today (a catch-up window),
  // not a narrow slot, so a delayed or dropped cron no longer skips the day.
  // Rounding this to a 15-minute bucket previously made half-hour timezones
  // (IST, +05:30) unmatchable, since an on-time :00 cron always lands on :30
  // local while the window only covered :00–:14.
  const { data: eligibleUsers, error: usersError } = await supabase
    .rpc(config.rpc, {
      target_hour: currentHour,
      target_minute: currentMinute
    })

  if (usersError) {
    throw new AppError('DATABASE_ERROR', `Failed to fetch eligible users: ${usersError.message}`, 500)
  }

  if (!eligibleUsers || eligibleUsers.length === 0) {
    return notificationHelper.createSuccessResponse(`No eligible users for streak ${mode}`, { sentCount: 0 })
  }

  const mappedUsers: StreakReminderUser[] = eligibleUsers.map((u: { user_id: string; fcm_token: string; current_streak?: number }) => ({
    user_id: u.user_id,
    fcm_token: u.fcm_token,
    current_streak: u.current_streak,
  }))

  console.log(`[Streak] Found ${mappedUsers.length} eligible users`)

  // Step 3: Filter out anonymous users
  const authenticatedUsers = await notificationHelper.filterAnonymousUsers(supabase, mappedUsers)

  if (authenticatedUsers.length === 0) {
    return notificationHelper.createSuccessResponse('No authenticated users eligible', { sentCount: 0 })
  }

  // Step 4: Filter out users who already received streak reminder today
  const userIds = authenticatedUsers.map(u => u.user_id)
  const alreadySentUserIds = await notificationHelper.getAlreadySentUserIds(userIds, config.notificationType, DEDUP_LOOKBACK_HOURS)
  const dedupedUsers = authenticatedUsers.filter(u => !alreadySentUserIds.has(u.user_id))

  // Space out categories — a user notified by another category within the last
  // hour is deferred to a later run, still inside this window.
  const usersToNotify = await notificationHelper.excludeRecentlyNotified(dedupedUsers)

  console.log(`[Streak] ${usersToNotify.length} users need notification (${alreadySentUserIds.size} already received)`)

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
    config.notificationType,
    languageMap,
    ({ user, language }: NotificationContentParams<StreakReminderUser>) => {
      const currentStreak = user.current_streak || 0
      const messages = config.messages[language] || config.messages.en

      return {
        title: messages.title,
        body: messages.body(currentStreak),
        data: {
          current_streak: String(currentStreak),
        },
      }
    }
  )

  console.log(`[Streak] ${mode} complete: ${result.successCount} sent, ${result.failureCount} failed`)

  return notificationHelper.createSuccessResponse(`Streak ${mode} notifications sent`, {
    mode,
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
