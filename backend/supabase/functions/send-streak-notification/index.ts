// ============================================================================
// Send Streak Notification Edge Function
// ============================================================================
// Sends milestone achievement and streak lost notifications
// Called by client when user views verse and streak changes

import { createSimpleFunction } from '../_shared/core/function-factory.ts';
import { ServiceContainer } from '../_shared/core/services.ts';
import { FCMService, logNotification } from '../_shared/fcm-service.ts';
import { AppError } from '../_shared/utils/error-handler.ts';

// ============================================================================
// Notification Types and Messages
// ============================================================================

type NotificationType = 'milestone' | 'streak_lost';

interface MilestoneMessages {
  [key: number]: {
    en: { title: string; body: string };
    hi: { title: string; body: string };
    ml: { title: string; body: string };
  };
}

const MILESTONE_MESSAGES: MilestoneMessages = {
  7: {
    en: {
      title: '🔥 Week Warrior!',
      body: 'Amazing! You\'ve reached 7 days! Keep the fire burning!'
    },
    hi: {
      title: '🔥 सप्ताह योद्धा!',
      body: 'बढ़िया! आपने 7 दिन पूरे किए! इसी जोश को बनाए रखें!'
    },
    ml: {
      title: '🔥 വീക്ക് വാരിയർ!',
      body: 'അതിശയകരം! നിങ്ങൾ 7 ദിവസം പൂർത്തിയാക്കി! ഈ ഉത്സാഹം തുടരൂ!'
    }
  },
  30: {
    en: {
      title: '✨ Monthly Master!',
      body: 'Incredible! 30 days of dedication! You\'re a true champion!'
    },
    hi: {
      title: '✨ मासिक मास्टर!',
      body: 'अविश्वसनीय! 30 दिनों की समर्पण! आप एक सच्चे चैंपियन हैं!'
    },
    ml: {
      title: '✨ മാസിക മാസ്റ്റർ!',
      body: 'അവിശ്വസനീയം! 30 ദിവസത്തെ സമർപ്പണം! നിങ്ങൾ ഒരു യഥാർത്ഥ ചാമ്പ്യനാണ്!'
    }
  },
  100: {
    en: {
      title: '🏆 Century Scholar!',
      body: 'Outstanding! 100 days of consistency! You\'re unstoppable!'
    },
    hi: {
      title: '🏆 100 दिन पूरे!',
      body: 'शानदार! 100 दिनों की लगन! आप रुकने वाले नहीं हैं!'
    },
    ml: {
      title: '🏆 100 ദിവസം പൂർത്തിയായി!',
      body: 'അസാധാരണം! 100 ദിവസത്തെ സ്ഥിരത! നിങ്ങളെ തടയാൻ ആർക്കും കഴിയില്ല!'
    }
  },
  365: {
    en: {
      title: '🌟 Yearly Champion!',
      body: 'LEGENDARY! One full year of daily devotion! You\'re an inspiration!'
    },
    hi: {
      title: '🌟 एक साल पूरा!',
      body: 'अद्भुत! पूरे एक साल की मेहनत! आप सबके लिए प्रेरणा हैं!'
    },
    ml: {
      title: '🌟 ഒരു വർഷം പൂർത്തിയായി!',
      body: 'അത്ഭുതകരം! ഒരു വർഷത്തെ സ്ഥിരോത്സാഹം! നിങ്ങൾ എല്ലാവർക്കും പ്രചോദനമാണ്!'
    }
  }
};

const STREAK_LOST_MESSAGES = {
  en: {
    title: '💪 New Beginning',
    body: (days: number) => `Your ${days}-day streak ended, but every day is a new start! Begin your journey again today.`
  },
  hi: {
    title: '💪 नई शुरुआत',
    body: (days: number) => `आपकी ${days} दिन की स्ट्रीक समाप्त हो गई, लेकिन हर दिन एक नई शुरुआत है! आज अपनी यात्रा फिर से शुरू करें।`
  },
  ml: {
    title: '💪 പുതിയ തുടക്കം',
    body: (days: number) => `നിങ്ങളുടെ ${days} ദിവസത്തെ സ്ട്രീക് അവസാനിച്ചു, പക്ഷേ ഓരോ ദിവസവും ഒരു പുതിയ തുടക്കമാണ്! ഇന്ന് നിങ്ങളുടെ യാത്ര വീണ്ടും ആരംഭിക്കൂ.`
  }
};

// ============================================================================
// Request Body Interface
// ============================================================================

interface RequestBody {
  userId: string;
  notificationType: NotificationType;
  streakCount: number; // For milestone: new streak count; for lost: previous streak count
  language?: string;
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleStreakNotification(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  // SECURITY: Verify and validate JWT token, extract authenticated user
  const userContext = await services.authService.getUserContext(req);

  // SECURITY: Ensure user is authenticated (not anonymous)
  if (userContext.type === 'anonymous' || !userContext.userId) {
    throw new AppError('FORBIDDEN', 'Streak notifications require authentication', 403);
  }

  const authenticatedUserId = userContext.userId;

  // Parse request body
  let requestBody: RequestBody;
  try {
    requestBody = await req.json();
  } catch (error) {
    throw new AppError('INVALID_INPUT', 'Invalid JSON body', 400);
  }

  const { userId, notificationType, streakCount, language = 'en' } = requestBody;

  // Validate inputs
  if (!userId || !notificationType || typeof streakCount !== 'number') {
    throw new AppError('INVALID_INPUT', 'Missing required fields: userId, notificationType, streakCount', 400);
  }

  if (notificationType !== 'milestone' && notificationType !== 'streak_lost') {
    throw new AppError('INVALID_INPUT', 'notificationType must be either "milestone" or "streak_lost"', 400);
  }

  // SECURITY: Verify that the authenticated user matches the requested userId
  // This prevents users from triggering notifications for other users
  if (authenticatedUserId !== userId) {
    console.error(`[SECURITY] Authorization failed: authenticated user ${authenticatedUserId} attempted to trigger notification for user ${userId}`);
    throw new AppError('FORBIDDEN', 'You can only trigger notifications for your own account', 403);
  }

  console.log(`Processing ${notificationType} notification for user ${userId} (streak: ${streakCount})`);

  const supabase = services.supabaseServiceClient;

  // Validate required environment variables
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
  const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!SUPABASE_URL || SUPABASE_URL.trim() === '') {
    console.error('[ENV ERROR] SUPABASE_URL environment variable is missing or empty');
    throw new AppError('CONFIGURATION_ERROR', 'SUPABASE_URL environment variable is not configured', 500);
  }

  if (!SUPABASE_SERVICE_ROLE_KEY || SUPABASE_SERVICE_ROLE_KEY.trim() === '') {
    console.error('[ENV ERROR] SUPABASE_SERVICE_ROLE_KEY environment variable is missing or empty');
    throw new AppError('CONFIGURATION_ERROR', 'SUPABASE_SERVICE_ROLE_KEY environment variable is not configured', 500);
  }

  // Get user's notification preferences
  const { data: preferences, error: prefsError } = await supabase
    .from('user_notification_preferences')
    .select('streak_milestone_enabled, streak_lost_enabled')
    .eq('user_id', userId)
    .single();

  if (prefsError || !preferences) {
    // If preferences don't exist yet, assume defaults (enabled)
    console.log(`No preferences found for user ${userId}, using defaults`);
  }

  // Check if notification type is enabled for this user
  const isEnabled = notificationType === 'milestone'
    ? preferences?.streak_milestone_enabled !== false
    : preferences?.streak_lost_enabled !== false;

  if (!isEnabled) {
    console.log(`Notification type ${notificationType} is disabled for user ${userId}`);
    return new Response(
      JSON.stringify({
        success: true,
        message: `Notification type ${notificationType} is disabled`,
        sent: false,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }

  // Get user's FCM tokens
  const { data: tokens, error: tokensError } = await supabase
    .from('user_notification_tokens')
    .select('fcm_token, platform')
    .eq('user_id', userId);

  if (tokensError || !tokens || tokens.length === 0) {
    console.log(`No FCM tokens found for user ${userId}`);
    return new Response(
      JSON.stringify({
        success: true,
        message: 'No FCM tokens registered for user',
        sent: false,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }

  // Prepare notification content
  let title: string;
  let body: string;

  if (notificationType === 'milestone') {
    // Check if this is a recognized milestone
    const milestoneMessages = MILESTONE_MESSAGES[streakCount];
    if (!milestoneMessages) {
      console.log(`Streak count ${streakCount} is not a recognized milestone`);
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Not a recognized milestone',
          sent: false,
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    const messages = milestoneMessages[language as keyof typeof milestoneMessages] || milestoneMessages.en;
    title = messages.title;
    body = messages.body;
  } else {
    // Streak lost notification
    const messages = STREAK_LOST_MESSAGES[language as keyof typeof STREAK_LOST_MESSAGES] || STREAK_LOST_MESSAGES.en;
    title = messages.title;
    body = messages.body(streakCount);
  }

  // Send notification to all user's devices
  const fcmService = new FCMService();
  let successCount = 0;
  let failureCount = 0;

  for (const token of tokens) {
    try {
      const result = await fcmService.sendNotification({
        token: token.fcm_token,
        notification: { title, body },
        data: {
          type: `streak_${notificationType}`,
          streak_count: String(streakCount),
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
          userId,
          notificationType: notificationType === 'milestone' ? 'streak_milestone' : 'streak_lost',
          title,
          body,
          language,
          deliveryStatus: 'sent',
          fcmMessageId: result.messageId,
        });
      } else {
        failureCount++;
        // Log failure
        await logNotification(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
          userId,
          notificationType: notificationType === 'milestone' ? 'streak_milestone' : 'streak_lost',
          title,
          body,
          language,
          deliveryStatus: 'failed',
          errorMessage: result.error,
        });
      }
    } catch (error) {
      failureCount++;
      console.error(`Error sending notification to token:`, error);
    }
  }

  console.log(`Notification sent: ${successCount} success, ${failureCount} failed`);

  return new Response(
    JSON.stringify({
      success: true,
      message: `${notificationType} notification sent`,
      sent: successCount > 0,
      successCount,
      failureCount,
      totalDevices: tokens.length,
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

createSimpleFunction(handleStreakNotification, {
  allowedMethods: ['POST'],
  enableAnalytics: false,
});
