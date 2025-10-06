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
  // Verify service role authentication
  const authHeader = req.headers.get('Authorization');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!authHeader || !authHeader.startsWith('Bearer ') || authHeader.replace('Bearer ', '') !== serviceRoleKey) {
    throw new AppError('UNAUTHORIZED', 'Service role authentication required', 401);
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
  // Example: If UTC hour is 0, we want users with timezone offset +360 minutes (UTC+6)
  // because for them, it's 6:00 AM local time
  const targetOffsetMinutes = (currentHour - 6) * 60; // 6 AM target
  const offsetRangeMin = targetOffsetMinutes - 180; // ±3 hours buffer
  const offsetRangeMax = targetOffsetMinutes + 180;

  console.log(`Targeting users with timezone offset: ${targetOffsetMinutes} minutes (±3 hours)`);

  // Step 3: Fetch eligible users
  const { data: allUsers, error: usersError } = await supabase
    .from('user_notification_preferences')
    .select('user_id, fcm_token, timezone_offset_minutes')
    .eq('daily_verse_enabled', true)
    .gte('timezone_offset_minutes', offsetRangeMin)
    .lte('timezone_offset_minutes', offsetRangeMax);

  if (usersError) {
    throw new AppError('DATABASE_ERROR', `Failed to fetch users: ${usersError.message}`, 500);
  }

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

  // Step 4: Filter out anonymous/guest users
  const { data: authUsers, error: authError } = await supabase.auth.admin.listUsers();

  if (authError) {
    throw new AppError('DATABASE_ERROR', `Failed to fetch auth users: ${authError.message}`, 500);
  }

  // Create set of anonymous user IDs
  const anonymousUserIds = new Set(
    authUsers.users.filter(u => u.is_anonymous).map(u => u.id)
  );

  // Filter out anonymous users
  const users = allUsers.filter(u => !anonymousUserIds.has(u.user_id));

  console.log(`Found ${allUsers.length} eligible users (${anonymousUserIds.size} anonymous users excluded, ${users.length} authenticated users)`);

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
