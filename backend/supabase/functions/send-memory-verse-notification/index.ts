// ============================================================================
// Send Memory Verse Notification Edge Function
// ============================================================================
// Sends push notifications for memory verse review reminders and overdue alerts
// Triggered by GitHub Actions workflow at 9 AM across different timezones

import { createSimpleFunction } from '../_shared/core/function-factory.ts';
import { ServiceContainer } from '../_shared/core/services.ts';
import { FCMService, logNotification, getBatchNotificationStatus } from '../_shared/fcm-service.ts';
import { AppError } from '../_shared/utils/error-handler.ts';

// ============================================================================
// Notification Content by Language - Motivational Messages
// ============================================================================

const REMINDER_TITLES: Record<string, string> = {
  en: '📚 Time to Review!',
  hi: '📚 समीक्षा का समय!',
  ml: '📚 അവലോകന സമയം!',
};

const REMINDER_BODIES: Record<string, (count: number) => string> = {
  en: (count) => count === 1
    ? `You have 1 verse ready for review. Keep building your scripture memory! 💪`
    : `You have ${count} verses ready for review. Strengthen your faith through God's Word! 💪`,
  hi: (count) => count === 1
    ? `आपके पास समीक्षा के लिए 1 आयत तैयार है। अपनी पवित्रशास्त्र स्मृति बनाते रहें! 💪`
    : `आपके पास समीक्षा के लिए ${count} आयतें तैयार हैं। परमेश्वर के वचन से अपने विश्वास को मजबूत करें! 💪`,
  ml: (count) => count === 1
    ? `നിങ്ങൾക്ക് അവലോകനത്തിന് 1 വാക്യം തയ്യാറാണ്. നിങ്ങളുടെ തിരുവെഴുത്ത് ഓർമ്മ വളർത്തുക! 💪`
    : `നിങ്ങൾക്ക് അവലോകനത്തിന് ${count} വാക്യങ്ങൾ തയ്യാറാണ്. ദൈവവചനത്തിലൂടെ നിങ്ങളുടെ വിശ്വാസം ശക്തിപ്പെടുത്തുക! 💪`,
};

const OVERDUE_TITLES: Record<string, string> = {
  en: '⏰ Don\'t Let Your Progress Slip!',
  hi: '⏰ अपनी प्रगति को न गंवाएं!',
  ml: '⏰ നിങ്ങളുടെ പുരോഗതി നഷ്ടപ്പെടുത്തരുത്!',
};

const OVERDUE_BODIES: Record<string, (count: number, days: number) => string> = {
  en: (count, days) => {
    const daysText = days === 1 ? '1 day' : `${days} days`;
    return count === 1
      ? `1 verse is ${daysText} overdue. Review now to maintain your memory strength! 🙏`
      : `${count} verses are overdue (up to ${daysText}). Your effort is worth it - review now! 🙏`;
  },
  hi: (count, days) => {
    const daysText = days === 1 ? '1 दिन' : `${days} दिन`;
    return count === 1
      ? `1 आयत ${daysText} देर से है। अपनी स्मृति शक्ति बनाए रखने के लिए अभी समीक्षा करें! 🙏`
      : `${count} आयतें देर से हैं (${daysText} तक)। आपकी मेहनत सार्थक है - अभी समीक्षा करें! 🙏`;
  },
  ml: (count, days) => {
    const daysText = days === 1 ? '1 ദിവസം' : `${days} ദിവസം`;
    return count === 1
      ? `1 വാക്യം ${daysText} കഴിഞ്ഞു. നിങ്ങളുടെ ഓർമ്മശക്തി നിലനിർത്താൻ ഇപ്പോൾ അവലോകനം ചെയ്യുക! 🙏`
      : `${count} വാക്യങ്ങൾ കഴിഞ്ഞു (${daysText} വരെ). നിങ്ങളുടെ പരിശ്രമം വിലമതിക്കുന്നു - ഇപ്പോൾ അവലോകനം ചെയ്യുക! 🙏`;
  },
};

// ============================================================================
// Main Handler
// ============================================================================

async function handleMemoryVerseNotification(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  // Verify cron authentication using dedicated secret
  const cronHeader = req.headers.get('X-Cron-Secret');
  const cronSecret = Deno.env.get('CRON_SECRET');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!cronHeader || cronHeader !== cronSecret) {
    throw new AppError('UNAUTHORIZED', 'Cron secret authentication required', 401);
  }

  // Get notification type from query params (reminder or overdue)
  const url = new URL(req.url);
  const notificationType = url.searchParams.get('type') || 'reminder';

  console.log(`Starting memory verse ${notificationType} notification process...`);

  const supabase = services.supabaseServiceClient;
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
  const SUPABASE_SERVICE_ROLE_KEY = serviceRoleKey!;

  // Initialize FCM service
  const fcmService = new FCMService();

  let eligibleUsers: any[] = [];

  if (notificationType === 'reminder') {
    // Get current hour in UTC for reminder notifications
    const currentHour = new Date().getUTCHours();
    const currentMinute = new Date().getUTCMinutes();
    console.log(`Current UTC time: ${currentHour}:${currentMinute}`);

    // Call the helper function to get eligible users
    const { data: users, error } = await supabase.rpc(
      'get_memory_verse_reminder_notification_users',
      { target_hour: currentHour, target_minute: currentMinute }
    );

    if (error) {
      throw new AppError('DATABASE_ERROR', `Failed to fetch reminder users: ${error.message}`, 500);
    }

    eligibleUsers = users || [];
  } else if (notificationType === 'overdue') {
    // Call the helper function to get users with overdue verses
    const { data: users, error } = await supabase.rpc(
      'get_memory_verse_overdue_notification_users'
    );

    if (error) {
      throw new AppError('DATABASE_ERROR', `Failed to fetch overdue users: ${error.message}`, 500);
    }

    eligibleUsers = users || [];
  }

  if (!eligibleUsers || eligibleUsers.length === 0) {
    console.log(`No eligible users found for ${notificationType} notifications`);
    return new Response(
      JSON.stringify({
        success: true,
        message: 'No eligible users',
        type: notificationType,
        sentCount: 0,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }

  console.log(`Found ${eligibleUsers.length} eligible users for ${notificationType} notifications`);

  // Filter out anonymous users
  const CONCURRENCY_LIMIT = 10;
  const anonymousUserIds = new Set<string>();
  const uniqueUserIds = [...new Set(eligibleUsers.map(u => u.user_id))];

  for (let i = 0; i < uniqueUserIds.length; i += CONCURRENCY_LIMIT) {
    const batch = uniqueUserIds.slice(i, i + CONCURRENCY_LIMIT);
    const results = await Promise.allSettled(
      batch.map(async (userId: string) => {
        const { data, error } = await supabase.auth.admin.getUserById(userId);
        if (error) {
          console.warn(`Failed to fetch auth user ${userId}:`, error.message);
          return null;
        }
        return data.user;
      })
    );

    for (const result of results) {
      if (result.status === 'fulfilled' && result.value && result.value.is_anonymous) {
        anonymousUserIds.add(result.value.id);
      }
    }
  }

  const authenticatedUsers = eligibleUsers.filter(u => !anonymousUserIds.has(u.user_id));
  console.log(`${authenticatedUsers.length} authenticated users (${anonymousUserIds.size} anonymous excluded)`);

  if (authenticatedUsers.length === 0) {
    return new Response(
      JSON.stringify({
        success: true,
        message: 'No authenticated users eligible',
        type: notificationType,
        sentCount: 0,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }

  // Filter out users who already received this notification today
  const allUserIds = authenticatedUsers.map((u: any) => u.user_id);
  const notificationKey = notificationType === 'reminder'
    ? 'memory_verse_reminder'
    : 'memory_verse_overdue';

  const alreadySentUserIds = await getBatchNotificationStatus(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
    allUserIds,
    notificationKey
  );

  const usersToNotify = authenticatedUsers.filter((u: any) => !alreadySentUserIds.has(u.user_id));
  console.log(`${usersToNotify.length} users need notification (${alreadySentUserIds.size} already received today)`);

  if (usersToNotify.length === 0) {
    return new Response(
      JSON.stringify({
        success: true,
        message: 'All users already received notification today',
        type: notificationType,
        sentCount: 0,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }

  // Get user language preferences
  const userIds = usersToNotify.map(u => u.user_id);
  const { data: profiles, error: profilesError } = await supabase
    .from('user_profiles')
    .select('id, language_preference')
    .in('id', userIds);

  if (profilesError) {
    throw new AppError('DATABASE_ERROR', `Failed to fetch user profiles: ${profilesError.message}`, 500);
  }

  const languageMap: Record<string, string> = {};
  profiles?.forEach(profile => {
    languageMap[profile.id] = profile.language_preference || 'en';
  });

  // Send notifications
  let successCount = 0;
  let failureCount = 0;
  const NOTIFICATION_BATCH_SIZE = 10;

  for (let i = 0; i < usersToNotify.length; i += NOTIFICATION_BATCH_SIZE) {
    const batch = usersToNotify.slice(i, i + NOTIFICATION_BATCH_SIZE);

    const results = await Promise.allSettled(
      batch.map(async (user: any) => {
        try {
          const language = languageMap[user.user_id] || 'en';

          let title: string;
          let body: string;

          if (notificationType === 'reminder') {
            title = REMINDER_TITLES[language] || REMINDER_TITLES.en;
            const bodyFn = REMINDER_BODIES[language] || REMINDER_BODIES.en;
            body = bodyFn(user.due_verse_count);
          } else {
            title = OVERDUE_TITLES[language] || OVERDUE_TITLES.en;
            const bodyFn = OVERDUE_BODIES[language] || OVERDUE_BODIES.en;
            body = bodyFn(user.overdue_verse_count, user.max_days_overdue);
          }

          const result = await fcmService.sendNotification({
            token: user.fcm_token,
            notification: { title, body },
            data: {
              type: notificationKey,
              dueCount: String(user.due_verse_count || user.overdue_verse_count),
              language,
            },
            android: { priority: 'high' },
            apns: {
              headers: { 'apns-priority': '10' },
              payload: { aps: { sound: 'default', badge: 1 } },
            },
          });

          if (result.success) {
            await logNotification(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
              userId: user.user_id,
              notificationType: notificationKey,
              title,
              body,
              language,
              deliveryStatus: 'sent',
              fcmMessageId: result.messageId,
            });
            return { success: true, userId: user.user_id };
          } else {
            await logNotification(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
              userId: user.user_id,
              notificationType: notificationKey,
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

    results.forEach((result) => {
      if (result.status === 'fulfilled' && result.value.success) {
        successCount++;
      } else {
        failureCount++;
      }
    });

    console.log(`Batch ${Math.floor(i / NOTIFICATION_BATCH_SIZE) + 1} complete: ${successCount} sent, ${failureCount} failed`);
  }

  console.log(`Notification process complete: ${successCount} sent, ${failureCount} failed`);

  return new Response(
    JSON.stringify({
      success: true,
      message: `Memory verse ${notificationType} notifications sent`,
      type: notificationType,
      totalEligible: usersToNotify.length,
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

createSimpleFunction(handleMemoryVerseNotification, {
  allowedMethods: ['POST'],
  enableAnalytics: false,
});
