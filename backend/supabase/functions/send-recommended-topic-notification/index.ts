// ============================================================================
// Send Recommended Topic Notification Edge Function
// ============================================================================
// Sends recommended Bible study topic push notifications to all eligible users
// Triggered by GitHub Actions workflow at 8 AM across different timezones

import { createSimpleFunction } from '../_shared/core/function-factory.ts';
import { ServiceContainer } from '../_shared/core/services.ts';
import { FCMService, logNotification, hasReceivedNotificationToday } from '../_shared/fcm-service.ts';
import { selectTopicForUser, getLocalizedTopicContent } from '../_shared/topic-selector.ts';
import { AppError } from '../_shared/utils/error-handler.ts';

// ============================================================================
// Notification Titles by Language
// ============================================================================

const NOTIFICATION_TITLES: Record<string, string> = {
  en: '💡 Recommended Topic',
  hi: '💡 अनुशंसित विषय',
  ml: '💡 ശുപാർശിത വിഷയം',
};

const NOTIFICATION_INTROS: Record<string, string> = {
  en: 'Explore today:',
  hi: 'आज जानें:',
  ml: 'ഇന്ന് പര്യവേക്ഷണം ചെയ്യുക:',
};

// ============================================================================
// Main Handler
// ============================================================================

async function handleRecommendedTopicNotification(
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

  console.log('Starting recommended topic notification process...');

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
  // targetOffsetMinutes represents minutes to add to UTC to reach 8 AM local time
  // Example: If UTC hour is 2, we want users with timezone offset +360 minutes (UTC+6)
  // because for them, localTime = UTC + offset = 2 + 6 hours = 8:00 AM
  let targetOffsetMinutes = (8 - currentHour) * 60; // 8 AM target

  // Normalize targetOffsetMinutes to valid timezone range: -720 (UTC-12) to +840 (UTC+14)
  if (targetOffsetMinutes < -720) {
    targetOffsetMinutes += 1440; // Add 24 hours
  } else if (targetOffsetMinutes > 840) {
    targetOffsetMinutes -= 1440; // Subtract 24 hours
  }

  // Calculate ±3 hour window (180 minutes) without clamping
  const unclamped_offsetRangeMin = targetOffsetMinutes - 180;
  const unclamped_offsetRangeMax = targetOffsetMinutes + 180;

  // Clamp to valid timezone range
  const offsetRangeMin = Math.max(-720, unclamped_offsetRangeMin);
  const offsetRangeMax = Math.min(840, unclamped_offsetRangeMax);

  console.log(`Targeting users with timezone offset: ${targetOffsetMinutes} minutes (±3 hours, range: ${offsetRangeMin} to ${offsetRangeMax})`);

  // Step 3: Fetch eligible users with valid FCM tokens (join preferences with tokens)
  // Handle wrap-around case: if min > max, query requires two ranges
  let allUsers;
  let usersError;

  if (offsetRangeMin > offsetRangeMax) {
    // Wrap-around case: split into two ranges
    // Range 1: offsetRangeMin to 840 (max valid)
    // Range 2: -720 (min valid) to offsetRangeMax
    console.log(`Wrap-around detected: querying ranges [${offsetRangeMin}, 840] and [-720, ${offsetRangeMax}]`);

    const [result1, result2] = await Promise.all([
      supabase
        .from('user_notification_preferences')
        .select(`
          user_id,
          timezone_offset_minutes,
          user_notification_tokens!inner(
            fcm_token
          )
        `)
        .eq('recommended_topic_enabled', true)
        .gte('timezone_offset_minutes', offsetRangeMin)
        .lte('timezone_offset_minutes', 840),
      
      supabase
        .from('user_notification_preferences')
        .select(`
          user_id,
          timezone_offset_minutes,
          user_notification_tokens!inner(
            fcm_token
          )
        `)
        .eq('recommended_topic_enabled', true)
        .gte('timezone_offset_minutes', -720)
        .lte('timezone_offset_minutes', offsetRangeMax)
    ]);

    if (result1.error || result2.error) {
      usersError = result1.error || result2.error;
      allUsers = null;
    } else {
      // Combine results from both ranges
      allUsers = [...(result1.data || []), ...(result2.data || [])];
    }
  } else {
    // Normal case: single range query
    const result = await supabase
      .from('user_notification_preferences')
      .select(`
        user_id,
        timezone_offset_minutes,
        user_notification_tokens!inner(
          fcm_token
        )
      `)
      .eq('recommended_topic_enabled', true)
      .gte('timezone_offset_minutes', offsetRangeMin)
      .lte('timezone_offset_minutes', offsetRangeMax);
    
    allUsers = result.data;
    usersError = result.error;
  }

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

  // Flatten the joined data structure (user can have multiple tokens)
  const usersWithTokens: Array<{ user_id: string; fcm_token: string; timezone_offset_minutes: number }> = [];
  for (const user of allUsers) {
    if (user.user_notification_tokens && Array.isArray(user.user_notification_tokens)) {
      for (const tokenData of user.user_notification_tokens) {
        if (tokenData.fcm_token) {
          usersWithTokens.push({
            user_id: user.user_id,
            fcm_token: tokenData.fcm_token,
            timezone_offset_minutes: user.timezone_offset_minutes,
          });
        }
      }
    }
  }

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
      'recommended_topic'
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

  // Step 5: Get user language preferences
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

  // Step 6: Select personalized topics for each user
  let successCount = 0;
  let failureCount = 0;
  let topicSelectionFailures = 0;
  const uniqueTopicIds = new Set<string>();

  for (const user of eligibleUsers) {
    try {
      const language = languageMap[user.user_id] || 'en';
      
      // Select best topic for this user (avoiding recently sent topics)
      const topicResult = await selectTopicForUser(
        SUPABASE_URL,
        SUPABASE_SERVICE_ROLE_KEY,
        user.user_id,
        language
      );

      if (!topicResult.success || !topicResult.topic) {
        topicSelectionFailures++;
        console.error(`Failed to select topic for user ${user.user_id}:`, topicResult.error);
        continue;
      }

      // Get localized content
      const localizedContent = getLocalizedTopicContent(topicResult.topic, language);

      const title = NOTIFICATION_TITLES[language] || NOTIFICATION_TITLES.en;
      const intro = NOTIFICATION_INTROS[language] || NOTIFICATION_INTROS.en;
      const body = `${intro} ${localizedContent.title}`;

      // Track unique topics
      uniqueTopicIds.add(topicResult.topic.id);

      const result = await fcmService.sendNotification({
        token: user.fcm_token,
        notification: { title, body },
        data: {
          type: 'recommended_topic',
          topic_id: topicResult.topic.id,
          topic_title: localizedContent.title,
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
          notificationType: 'recommended_topic',
          title,
          body,
          topicId: topicResult.topic.id,
          language,
          deliveryStatus: 'sent',
          fcmMessageId: result.messageId,
        });
      } else {
        failureCount++;
        // Log failure
        await logNotification(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
          userId: user.user_id,
          notificationType: 'recommended_topic',
          title,
          body,
          topicId: topicResult.topic.id,
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
      message: 'Recommended topic notifications sent',
      totalEligible: eligibleUsers.length,
      successCount,
      failureCount,
      topicSelectionFailures,
      uniqueTopicsSent: uniqueTopicIds.size,
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

createSimpleFunction(handleRecommendedTopicNotification, {
  allowedMethods: ['POST'],
  enableAnalytics: false,
});
