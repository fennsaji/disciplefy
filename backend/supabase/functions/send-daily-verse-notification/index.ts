// ============================================================================
// Send Daily Verse Notification Edge Function
// ============================================================================
// Sends daily Bible verse push notifications to all eligible users
// Triggered by GitHub Actions workflow at 6 AM across different timezones

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import {
  createNotificationHelper,
  NotificationUser,
  NotificationContentParams,
} from '../_shared/services/notification-helper-service.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { formatError } from '../_shared/utils/error-formatter.ts'

// ============================================================================
// Types
// ============================================================================

interface DailyVerseUser extends NotificationUser {
  readonly timezone_offset_minutes: number
}

interface DailyVerseData {
  readonly reference: string
  readonly referenceTranslations: {
    readonly en: string
    readonly hi?: string
    readonly ml?: string
  }
  readonly translations: {
    readonly esv: string
    readonly hi?: string
    readonly ml?: string
  }
}

// ============================================================================
// Notification Titles by Language
// ============================================================================

const NOTIFICATION_TITLES: Record<string, string> = {
  en: '📖 Daily Verse',
  hi: '📖 दैनिक पद',
  ml: '📖 ദിവസത്തെ വാക്യം',
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleDailyVerseNotification(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  const notificationHelper = createNotificationHelper()

  // Verify cron authentication
  notificationHelper.verifyCronSecret(req)

  console.log('[DailyVerse] Starting notification process...')

  const supabase = services.supabaseServiceClient

  // Step 1: Calculate timezone offset range for users who should receive notification
  const currentHour = new Date().getUTCHours()
  const targetOffsetMinutes = (6 - currentHour) * 60 // 6 AM target
  const offsetRangeMin = Math.max(-720, targetOffsetMinutes - 180)
  const offsetRangeMax = Math.min(840, targetOffsetMinutes + 180)

  console.log(`[DailyVerse] UTC hour: ${currentHour}, targeting offset: ${targetOffsetMinutes} (±3 hours)`)

  // Step 2: Fetch eligible users with valid FCM tokens
  const { data: tokens, error: tokensError } = await supabase
    .from('user_notification_tokens')
    .select('user_id, fcm_token')

  if (tokensError) {
    throw new AppError('DATABASE_ERROR', `Failed to fetch tokens: ${tokensError.message}`, 500)
  }

  const { data: preferences, error: prefsError } = await supabase
    .from('user_notification_preferences')
    .select('user_id, timezone_offset_minutes, daily_verse_enabled')
    .eq('daily_verse_enabled', true)
    .gte('timezone_offset_minutes', offsetRangeMin)
    .lte('timezone_offset_minutes', offsetRangeMax)

  if (prefsError) {
    throw new AppError('DATABASE_ERROR', `Failed to fetch preferences: ${prefsError.message}`, 500)
  }

  // Manual join: match tokens with preferences
  const prefsMap = new Map(preferences?.map(p => [p.user_id, p]) || [])
  const allUsers: DailyVerseUser[] = tokens
    ?.filter(t => prefsMap.has(t.user_id))
    .map(t => ({
      user_id: t.user_id,
      fcm_token: t.fcm_token,
      timezone_offset_minutes: prefsMap.get(t.user_id)!.timezone_offset_minutes,
    })) || []

  if (allUsers.length === 0) {
    return notificationHelper.createSuccessResponse('No eligible users', { sentCount: 0 })
  }

  // Step 3: Filter out anonymous users
  const authenticatedUsers = await notificationHelper.filterAnonymousUsers(supabase, allUsers)

  if (authenticatedUsers.length === 0) {
    return notificationHelper.createSuccessResponse('No authenticated users eligible', { sentCount: 0 })
  }

  // Step 4: Filter out users who already received notification today
  const userIds = authenticatedUsers.map(u => u.user_id)
  const alreadySentUserIds = await notificationHelper.getAlreadySentUserIds(userIds, 'daily_verse')
  const eligibleUsers = authenticatedUsers.filter(u => !alreadySentUserIds.has(u.user_id))

  console.log(`[DailyVerse] ${eligibleUsers.length} users need notification (${alreadySentUserIds.size} already received)`)

  if (eligibleUsers.length === 0) {
    return notificationHelper.createSuccessResponse('All users already received notification today', { sentCount: 0 })
  }

  // Step 5: Get today's daily verse
  const today = new Date().toISOString().split('T')[0]
  let dailyVerse: DailyVerseData

  try {
    const verseData = await services.dailyVerseService.getDailyVerse(today, 'en')
    dailyVerse = {
      reference: verseData.reference,
      referenceTranslations: verseData.referenceTranslations,
      translations: verseData.translations,
    }
    console.log(`[DailyVerse] Verse: ${dailyVerse.reference}`)
  } catch (error) {
    throw new AppError('INTERNAL_ERROR', `Failed to get daily verse: ${formatError(error)}`, 500)
  }

  // Step 6: Get user language preferences
  const languageMap = await notificationHelper.getUserLanguagePreferences(
    supabase,
    eligibleUsers.map(u => u.user_id)
  )

  // Step 7: Send notifications using helper
  const result = await notificationHelper.sendNotificationBatch(
    eligibleUsers,
    'daily_verse',
    languageMap,
    ({ language }: NotificationContentParams<DailyVerseUser>) => {
      // Select localized content
      const localizedReference = language === 'hi' && dailyVerse.referenceTranslations.hi
        ? dailyVerse.referenceTranslations.hi
        : language === 'ml' && dailyVerse.referenceTranslations.ml
          ? dailyVerse.referenceTranslations.ml
          : dailyVerse.referenceTranslations.en

      const verseText = language === 'hi' && dailyVerse.translations.hi
        ? dailyVerse.translations.hi
        : language === 'ml' && dailyVerse.translations.ml
          ? dailyVerse.translations.ml
          : dailyVerse.translations.esv

      const title = NOTIFICATION_TITLES[language] || NOTIFICATION_TITLES.en
      const truncatedVerse = verseText.length > 100 ? `${verseText.substring(0, 100)}...` : verseText
      const body = `${localizedReference}\n\n${truncatedVerse}`

      return {
        title,
        body,
        data: {
          reference: dailyVerse.reference,
        },
      }
    }
  )

  console.log(`[DailyVerse] Complete: ${result.successCount} sent, ${result.failureCount} failed`)

  return notificationHelper.createSuccessResponse('Daily verse notifications sent', {
    totalEligible: eligibleUsers.length,
    successCount: result.successCount,
    failureCount: result.failureCount,
    verseReference: dailyVerse.reference,
  })
}

// ============================================================================
// Start Server
// ============================================================================

createSimpleFunction(handleDailyVerseNotification, {
  allowedMethods: ['POST'],
  enableAnalytics: false,
})
