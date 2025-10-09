// ============================================================================
// Send Daily Verse Notification Edge Function
// ============================================================================
// Sends daily Bible verse push notifications to all eligible users
// Triggered by GitHub Actions workflow at 6 AM across different timezones

import { createSimpleFunction } from '../_shared/core/function-factory.ts';
import { ServiceContainer } from '../_shared/core/services.ts';
import { FCMService, logNotification, hasReceivedNotificationToday } from '../_shared/fcm-service.ts';
import { AppError } from '../_shared/utils/error-handler.ts';
import { formatError } from '../_shared/utils/error-formatter.ts';

// ============================================================================
// Notification Titles by Language
// ============================================================================

const NOTIFICATION_TITLES: Record<string, string> = {
  en: '📖 Daily Verse',
  hi: '📖 दैनिक पद',
  ml: '📖 ദിവസത്തെ വാക്യം',
};

// ============================================================================
// Main Handler
// ============================================================================

async function handleDailyVerseNotification(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  // Verify cron authentication using dedicated secret
  const cronHeader = req.headers.get('X-Cron-Secret');
  const cronSecret = Deno.env.get('CRON_SECRET');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'); // still used later for Supabase client helpers

  if (!cronHeader || cronHeader !== cronSecret) {
    throw new AppError('UNAUTHORIZED', 'Cron secret authentication required', 401);
  }

  console.log('Starting daily verse notification process...');

  const supabase = services.supabaseServiceClient;

  // Get Supabase URL and service role key for FCM service
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
  const SUPABASE_SERVICE_ROLE_KEY = serviceRoleKey!;

  // Initialize FCM service
  const fcmService = new FCMService();

  // Step 1: Get current hour in UTC
  const currentHour = new Date().getUTCHours();
  console.log(`Current UTC hour: ${currentHour}`);

  // Step 2: Calculate timezone offset range for users who should receive notification now
  // targetOffsetMinutes represents minutes to add to UTC to reach 6 AM local time
  // Example: If UTC hour is 0, we want users with timezone offset +360 minutes (UTC+6)
  // because for them, localTime = UTC + offset = 0 + 6 hours = 6:00 AM
  const targetOffsetMinutes = (6 - currentHour) * 60; // 6 AM target
  const unclamped_offsetRangeMin = targetOffsetMinutes - 180; // ±3 hours buffer
  const unclamped_offsetRangeMax = targetOffsetMinutes + 180;

  // Clamp timezone offsets to valid range: -720 (UTC-12) to +840 (UTC+14)
  const offsetRangeMin = Math.max(-720, unclamped_offsetRangeMin);
  const offsetRangeMax = Math.min(840, unclamped_offsetRangeMax);

  console.log(`Targeting users with timezone offset: ${targetOffsetMinutes} minutes (±3 hours, clamped to ${offsetRangeMin}-${offsetRangeMax})`);

  // Step 3: Fetch eligible users with valid FCM tokens using direct query
  // Query tokens table and manually join with preferences
  const { data: tokens, error: tokensError } = await supabase
    .from('user_notification_tokens')
    .select('user_id, fcm_token');

  if (tokensError) {
    throw new AppError('DATABASE_ERROR', `Failed to fetch tokens: ${tokensError.message}`, 500);
  }

  const { data: preferences, error: prefsError } = await supabase
    .from('user_notification_preferences')
    .select('user_id, timezone_offset_minutes, daily_verse_enabled')
    .eq('daily_verse_enabled', true)
    .gte('timezone_offset_minutes', offsetRangeMin)
    .lte('timezone_offset_minutes', offsetRangeMax);

  if (prefsError) {
    throw new AppError('DATABASE_ERROR', `Failed to fetch preferences: ${prefsError.message}`, 500);
  }

  // Manual join: match tokens with preferences
  const prefsMap = new Map(preferences?.map(p => [p.user_id, p]) || []);
  const allUsers = tokens?.filter(t => prefsMap.has(t.user_id))
    .map(t => ({
      user_id: t.user_id,
      fcm_token: t.fcm_token,
      timezone_offset_minutes: prefsMap.get(t.user_id)!.timezone_offset_minutes
    })) || [];

  const usersError = null;

  if (!allUsers || allUsers.length === 0) {
    console.log('No eligible users found for this time window');
    return new Response(
      JSON.stringify({
        success: true,
        message: 'No eligible users',
        sentCount: 0,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }

  // Data is already in the correct format from SQL query
  const usersWithTokens = allUsers || [];

  // Step 4: Filter out anonymous/guest users using batched concurrent getUserById calls
  const CONCURRENCY_LIMIT = 10;
  const anonymousUserIds = new Set<string>();
  let authCheckErrors = 0;

  // Process user IDs in concurrent batches (get unique user IDs)
  const uniqueUserIds = [...new Set(usersWithTokens.map(u => u.user_id))];
  const eligibleUserIds = uniqueUserIds;
  for (let i = 0; i < eligibleUserIds.length; i += CONCURRENCY_LIMIT) {
    const batch = eligibleUserIds.slice(i, i + CONCURRENCY_LIMIT);

    const results = await Promise.allSettled(
      batch.map(async (userId: string) => {
        const { data, error } = await supabase.auth.admin.getUserById(userId);
        if (error) {
          console.warn(`Failed to fetch auth user ${userId}:`, error.message);
          authCheckErrors++;
          return null;
        }
        return data.user;
      })
    );

    // Collect anonymous user IDs from successful fetches
    for (const result of results) {
      if (result.status === 'fulfilled' && result.value && result.value.is_anonymous) {
        anonymousUserIds.add(result.value.id);
      }
    }
  }

  // Filter out anonymous users from tokens list
  const users = usersWithTokens.filter(u => !anonymousUserIds.has(u.user_id));

  console.log(`Found ${uniqueUserIds.length} unique users with ${usersWithTokens.length} total tokens (${anonymousUserIds.size} anonymous users excluded, ${users.length} authenticated user tokens, ${authCheckErrors} auth check errors)`);

  if (!users || users.length === 0) {
    console.log('No authenticated users found for this time window');
    return new Response(
      JSON.stringify({
        success: true,
        message: 'No authenticated users eligible',
        sentCount: 0,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }

  // Step 5: Filter out users who already received notification today
  const eligibleUsers: typeof users = [];
  for (const user of users) {
    const alreadySent = await hasReceivedNotificationToday(
      SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY,
      user.user_id,
      'daily_verse'
    );

    if (!alreadySent) {
      eligibleUsers.push(user);
    } else {
      console.log(`User ${user.user_id} already received notification today`);
    }
  }

  console.log(`${eligibleUsers.length} users need notification (${users.length - eligibleUsers.length} already received today)`);

  if (eligibleUsers.length === 0) {
    return new Response(
      JSON.stringify({
        success: true,
        message: 'All users already received notification today',
        sentCount: 0,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }

  // Step 5: Get today's daily verse (generate if doesn't exist)
  const today = new Date().toISOString().split('T')[0];
  console.log(`Fetching daily verse for date: ${today}`);

  // Use the daily verse service to get or generate the verse
  // This service handles caching and generation automatically
  let dailyVerse;
  try {
    const verseData = await services.dailyVerseService.getDailyVerse(today, 'en');
    console.log(`Daily verse obtained: ${verseData.reference}`);

    // Convert service response to expected format
    dailyVerse = {
      reference: verseData.reference,
      verse_text_en: verseData.translations.esv,
      verse_text_hi: verseData.translations.hi,
      verse_text_ml: verseData.translations.ml,
      date: today,
    };
  } catch (error) {
    console.error('Failed to get daily verse:', error);
    throw new AppError('INTERNAL_ERROR', `Failed to get daily verse: ${formatError(error)}`, 500);
  }

  // Step 6: Get user language preferences
  const userIds = eligibleUsers.map(u => u.user_id);
  const { data: profiles, error: profilesError } = await supabase
    .from('user_profiles')
    .select('id, language_preference')
    .in('id', userIds);

  if (profilesError) {
    throw new AppError('DATABASE_ERROR', `Failed to fetch user profiles: ${profilesError.message}`, 500);
  }

  // Map user IDs to language preferences
  const languageMap: Record<string, string> = {};
  profiles?.forEach(profile => {
    languageMap[profile.id] = profile.language_preference || 'en';
  });

  // Step 7: Send notifications
  let successCount = 0;
  let failureCount = 0;

  for (const user of eligibleUsers) {
    try {
      const language = languageMap[user.user_id] || 'en';
      
      // Select verse text based on language
      let verseText = dailyVerse.verse_text_en;
      if (language === 'hi' && dailyVerse.verse_text_hi) {
        verseText = dailyVerse.verse_text_hi;
      } else if (language === 'ml' && dailyVerse.verse_text_ml) {
        verseText = dailyVerse.verse_text_ml;
      }

      const title = NOTIFICATION_TITLES[language] || NOTIFICATION_TITLES.en;
      const body = `${dailyVerse.reference}\n\n${verseText.substring(0, 100)}${verseText.length > 100 ? '...' : ''}`;

      const result = await fcmService.sendNotification({
        token: user.fcm_token,
        notification: { title, body },
        data: {
          type: 'daily_verse',
          reference: dailyVerse.reference,
          language,
        },
        android: { priority: 'high' },
        apns: {
          headers: { 'apns-priority': '10' },
          payload: { aps: { sound: 'default', badge: 1 } },
        },
      });

      if (result.success) {
        successCount++;
        // Log successful send
        await logNotification(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
          userId: user.user_id,
          notificationType: 'daily_verse',
          title,
          body,
          verseReference: dailyVerse.reference,
          language,
          deliveryStatus: 'sent',
          fcmMessageId: result.messageId,
        });
      } else {
        failureCount++;
        // Log failure
        await logNotification(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
          userId: user.user_id,
          notificationType: 'daily_verse',
          title,
          body,
          verseReference: dailyVerse.reference,
          language,
          deliveryStatus: 'failed',
          errorMessage: result.error,
        });
      }
    } catch (error) {
      failureCount++;
      console.error(`Error sending to user ${user.user_id}:`, error);
    }
  }

  console.log(`Notification process complete: ${successCount} sent, ${failureCount} failed`);

  return new Response(
    JSON.stringify({
      success: true,
      message: 'Daily verse notifications sent',
      totalEligible: eligibleUsers.length,
      successCount,
      failureCount,
      verseReference: dailyVerse.reference,
    }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    }
  );
}

// ============================================================================
// Start Server
// ============================================================================

createSimpleFunction(handleDailyVerseNotification, {
  allowedMethods: ['POST'],
  enableAnalytics: false,
});
