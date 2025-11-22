// ============================================================================
// Send Streak Reminder Notification Edge Function
// ============================================================================
// Sends streak reminder push notifications to users who haven't viewed today's verse
// Triggered by GitHub Actions workflow at user's preferred reminder time (default 8 PM)

import { createSimpleFunction } from '../_shared/core/function-factory.ts';
import { ServiceContainer } from '../_shared/core/services.ts';
import { FCMService, logNotification, getBatchNotificationStatus } from '../_shared/fcm-service.ts';
import { AppError } from '../_shared/utils/error-handler.ts';

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
};

// ============================================================================
// Main Handler
// ============================================================================

async function handleStreakReminderNotification(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  // Verify cron authentication
  const cronHeader = req.headers.get('X-Cron-Secret');
  const cronSecret = Deno.env.get('CRON_SECRET');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!cronHeader || cronHeader !== cronSecret) {
    throw new AppError('UNAUTHORIZED', 'Cron secret authentication required', 401);
  }

  console.log('Starting streak reminder notification process...');

  const supabase = services.supabaseServiceClient;
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
  const SUPABASE_SERVICE_ROLE_KEY = serviceRoleKey!;

  // Initialize FCM service
  const fcmService = new FCMService();

  // Step 1: Get current time in UTC
  const now = new Date();
  const currentHour = now.getUTCHours();
  const currentMinute = now.getUTCMinutes();
  console.log(`Current UTC time: ${currentHour}:${String(currentMinute).padStart(2, '0')}`);

  // Step 2: Use the helper function to get users who need streak reminders
  // The function handles timezone conversion and filters users who haven't viewed today's verse
  const { data: eligibleUsers, error: usersError } = await supabase
    .rpc('get_streak_reminder_notification_users', {
      target_hour: currentHour,
      target_minute: Math.floor(currentMinute / 15) * 15 // Round to nearest 15 minutes
    });

  if (usersError) {
    throw new AppError('DATABASE_ERROR', `Failed to fetch eligible users: ${usersError.message}`, 500);
  }

  if (!eligibleUsers || eligibleUsers.length === 0) {
    console.log('No eligible users found for this time window');
    return new Response(
      JSON.stringify({
        success: true,
        message: 'No eligible users for streak reminders',
        sentCount: 0,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }

  console.log(`Found ${eligibleUsers.length} users eligible for streak reminders`);

  // Step 3: Filter out anonymous users (batched)
  const CONCURRENCY_LIMIT = 10;
  const anonymousUserIds = new Set<string>();
  let authCheckErrors = 0;

  const uniqueUserIds = [...new Set<string>(eligibleUsers.map((u: any) => u.user_id))];

  for (let i = 0; i < uniqueUserIds.length; i += CONCURRENCY_LIMIT) {
    const batch = uniqueUserIds.slice(i, i + CONCURRENCY_LIMIT);

    const results = await Promise.allSettled(
      batch.map(async (userId) => {
        const { data, error } = await supabase.auth.admin.getUserById(userId);
        if (error) {
          console.warn(`Failed to fetch auth user ${userId}:`, error.message);
          authCheckErrors++;
          return null;
        }
        return data.user;
      })
    );

    // Collect anonymous user IDs
    for (const result of results) {
      if (result.status === 'fulfilled' && result.value && result.value.is_anonymous) {
        anonymousUserIds.add(result.value.id);
      }
    }
  }

  // Filter out anonymous users
  const authenticatedUsers = eligibleUsers.filter((u: any) => !anonymousUserIds.has(u.user_id));

  console.log(`${authenticatedUsers.length} authenticated users (${anonymousUserIds.size} anonymous excluded, ${authCheckErrors} auth check errors)`);

  if (!authenticatedUsers || authenticatedUsers.length === 0) {
    return new Response(
      JSON.stringify({
        success: true,
        message: 'No authenticated users eligible for streak reminders',
        sentCount: 0,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }

  // Step 4: Filter out users who already received streak reminder today
  const allUserIds = authenticatedUsers.map((u: any) => u.user_id);
  const alreadySentUserIds = await getBatchNotificationStatus(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
    allUserIds,
    'streak_reminder'
  );

  const finalEligibleUsers = authenticatedUsers.filter((u: any) => !alreadySentUserIds.has(u.user_id));

  console.log(`${finalEligibleUsers.length} users need notification (${alreadySentUserIds.size} already received today)`);

  if (finalEligibleUsers.length === 0) {
    return new Response(
      JSON.stringify({
        success: true,
        message: 'All users already received streak reminder today',
        sentCount: 0,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }

  // Step 5: Get user language preferences
  const userIds = finalEligibleUsers.map((u: any) => u.user_id);
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

  // Step 6: Send notifications (batch processing)
  let successCount = 0;
  let failureCount = 0;
  const NOTIFICATION_BATCH_SIZE = 10;

  for (let i = 0; i < finalEligibleUsers.length; i += NOTIFICATION_BATCH_SIZE) {
    const batch = finalEligibleUsers.slice(i, i + NOTIFICATION_BATCH_SIZE);

    const results = await Promise.allSettled(
      batch.map(async (user: any) => {
        try {
          const language = languageMap[user.user_id] || 'en';
          const currentStreak = user.current_streak || 0;

          const messages = NOTIFICATION_MESSAGES[language] || NOTIFICATION_MESSAGES.en;
          const title = messages.title;
          const body = messages.body(currentStreak);

          const result = await fcmService.sendNotification({
            token: user.fcm_token,
            notification: { title, body },
            data: {
              type: 'streak_reminder',
              current_streak: String(currentStreak),
              language,
            },
            android: { priority: 'high' },
            apns: {
              headers: { 'apns-priority': '10' },
              payload: { aps: { sound: 'default', badge: 1 } },
            },
          });

          if (result.success) {
            // Log successful send
            await logNotification(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
              userId: user.user_id,
              notificationType: 'streak_reminder',
              title,
              body,
              language,
              deliveryStatus: 'sent',
              fcmMessageId: result.messageId,
            });
            return { success: true, userId: user.user_id };
          } else {
            // Log failure
            await logNotification(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
              userId: user.user_id,
              notificationType: 'streak_reminder',
              title,
              body,
              language,
              deliveryStatus: 'failed',
              errorMessage: result.error,
            });
            return { success: false, userId: user.user_id, error: result.error };
          }
        } catch (error) {
          console.error(`Error sending to user ${user.user_id}:`, error);
          return { success: false, userId: user.user_id, error: String(error) };
        }
      })
    );

    // Count successes and failures
    results.forEach((result) => {
      if (result.status === 'fulfilled' && result.value.success) {
        successCount++;
      } else {
        failureCount++;
      }
    });

    console.log(`Batch ${Math.floor(i / NOTIFICATION_BATCH_SIZE) + 1} complete: ${successCount} sent, ${failureCount} failed so far`);
  }

  console.log(`Streak reminder process complete: ${successCount} sent, ${failureCount} failed`);

  return new Response(
    JSON.stringify({
      success: true,
      message: 'Streak reminder notifications sent',
      totalEligible: finalEligibleUsers.length,
      successCount,
      failureCount,
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

createSimpleFunction(handleStreakReminderNotification, {
  allowedMethods: ['POST'],
  enableAnalytics: false,
});
