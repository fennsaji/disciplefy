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
  // Verify service role authentication
  const authHeader = req.headers.get('Authorization');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!authHeader || !authHeader.startsWith('Bearer ') || authHeader.replace('Bearer ', '') !== serviceRoleKey) {
    throw new AppError('UNAUTHORIZED', 'Service role authentication required', 401);
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
  // Example: If UTC hour is 2, we want users with timezone offset +360 minutes (UTC+6)
  // because for them, it's 8:00 AM local time
  const targetOffsetMinutes = (currentHour - 8) * 60; // 8 AM target
  const offsetRangeMin = targetOffsetMinutes - 180; // ±3 hours buffer
  const offsetRangeMax = targetOffsetMinutes + 180;

  console.log(`Targeting users with timezone offset: ${targetOffsetMinutes} minutes (±3 hours)`);

  // Step 3: Fetch eligible users
  const { data: allUsers, error: usersError } = await supabase
    .from('user_notification_preferences')
    .select('user_id, fcm_token, timezone_offset_minutes')
    .eq('recommended_topic_enabled', true)
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
  const { data: authUsers, error: authError} = await supabase.auth.admin.listUsers();

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
