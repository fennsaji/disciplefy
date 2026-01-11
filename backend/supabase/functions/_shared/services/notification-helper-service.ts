/**
 * Notification Helper Service
 *
 * Provides common functionality for notification handlers:
 * - Cron secret authentication
 * - Anonymous user filtering
 * - Language preference fetching
 * - Batch notification processing
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { FCMService, logNotification, getBatchNotificationStatus } from '../fcm-service.ts'
import { AppError } from '../utils/error-handler.ts'

/**
 * Valid notification types matching fcm-service.ts
 */
export type NotificationType =
  | 'daily_verse'
  | 'recommended_topic'
  | 'continue_learning'
  | 'streak_reminder'
  | 'streak_milestone'
  | 'streak_lost'
  | 'memory_verse_reminder'
  | 'memory_verse_overdue'

/**
 * Configuration for notification helper
 */
interface NotificationHelperConfig {
  readonly supabaseUrl: string
  readonly serviceRoleKey: string
  readonly batchSize?: number
  readonly concurrencyLimit?: number
}

/**
 * User with FCM token for notification
 */
export interface NotificationUser {
  readonly user_id: string
  readonly fcm_token: string
  readonly [key: string]: unknown
}

/**
 * Notification payload for sending
 */
export interface NotificationPayload {
  readonly title: string
  readonly body: string
  readonly data?: Record<string, string>
}

/**
 * Result of batch notification sending
 */
export interface NotificationResult {
  readonly successCount: number
  readonly failureCount: number
  readonly totalProcessed: number
}

/**
 * Parameters for building notification content
 */
export interface NotificationContentParams<T extends NotificationUser> {
  readonly user: T
  readonly language: string
}

/**
 * Content builder function type
 */
export type ContentBuilder<T extends NotificationUser> = (
  params: NotificationContentParams<T>
) => NotificationPayload

/**
 * Helper service for common notification patterns
 */
export class NotificationHelperService {
  private readonly config: Required<NotificationHelperConfig>
  private readonly fcmService: FCMService

  constructor(config: NotificationHelperConfig) {
    this.config = {
      supabaseUrl: config.supabaseUrl,
      serviceRoleKey: config.serviceRoleKey,
      batchSize: config.batchSize ?? 10,
      concurrencyLimit: config.concurrencyLimit ?? 10,
    }
    this.fcmService = new FCMService()
  }

  /**
   * Verify cron secret authentication
   *
   * @param req - Incoming request
   * @throws AppError if authentication fails
   */
  verifyCronSecret(req: Request): void {
    const cronHeader = req.headers.get('X-Cron-Secret')
    const cronSecret = Deno.env.get('CRON_SECRET')

    if (!cronSecret) {
      throw new AppError('CONFIGURATION_ERROR', 'Missing CRON_SECRET environment variable', 500)
    }

    if (!cronHeader || cronHeader !== cronSecret) {
      throw new AppError('UNAUTHORIZED', 'Cron secret authentication required', 401)
    }
  }

  /**
   * Filter out anonymous users from a list
   *
   * @param supabase - Supabase client with service role
   * @param users - Users with user_id to filter
   * @returns Filtered list of non-anonymous users
   */
  async filterAnonymousUsers<T extends NotificationUser>(
    supabase: SupabaseClient,
    users: readonly T[]
  ): Promise<T[]> {
    if (users.length === 0) return []

    const anonymousUserIds = new Set<string>()
    const uniqueUserIds = [...new Set(users.map(u => u.user_id))]
    let authCheckErrors = 0

    // Process in concurrent batches
    for (let i = 0; i < uniqueUserIds.length; i += this.config.concurrencyLimit) {
      const batch = uniqueUserIds.slice(i, i + this.config.concurrencyLimit)

      const results = await Promise.allSettled(
        batch.map(async (userId: string) => {
          const { data, error } = await supabase.auth.admin.getUserById(userId)
          if (error) {
            console.warn(`[NotificationHelper] Failed to fetch auth user ${userId}:`, error.message)
            authCheckErrors++
            return null
          }
          return data.user
        })
      )

      for (const result of results) {
        if (result.status === 'fulfilled' && result.value?.is_anonymous) {
          anonymousUserIds.add(result.value.id)
        }
      }
    }

    const filtered = users.filter(u => !anonymousUserIds.has(u.user_id))
    console.log(
      `[NotificationHelper] Filtered ${anonymousUserIds.size} anonymous users, ` +
      `${authCheckErrors} auth errors, ${filtered.length} authenticated users remaining`
    )

    return filtered as T[]
  }

  /**
   * Get user IDs that have already received this notification today
   *
   * @param userIds - User IDs to check
   * @param notificationType - Type of notification
   * @returns Set of user IDs that already received notification
   */
  async getAlreadySentUserIds(
    userIds: readonly string[],
    notificationType: NotificationType
  ): Promise<Set<string>> {
    return getBatchNotificationStatus(
      this.config.supabaseUrl,
      this.config.serviceRoleKey,
      userIds as string[],
      notificationType
    )
  }

  /**
   * Get language preferences for users
   *
   * @param supabase - Supabase client
   * @param userIds - User IDs to fetch preferences for
   * @returns Map of user_id to language code
   */
  async getUserLanguagePreferences(
    supabase: SupabaseClient,
    userIds: readonly string[]
  ): Promise<Map<string, string>> {
    const { data: profiles, error } = await supabase
      .from('user_profiles')
      .select('id, language_preference')
      .in('id', userIds as string[])

    if (error) {
      throw new AppError('DATABASE_ERROR', `Failed to fetch user profiles: ${error.message}`, 500)
    }

    const languageMap = new Map<string, string>()
    profiles?.forEach(profile => {
      languageMap.set(profile.id, profile.language_preference || 'en')
    })

    return languageMap
  }

  /**
   * Send notifications to users in batches
   *
   * @param users - Users to send notifications to
   * @param notificationType - Type for logging
   * @param languageMap - User language preferences
   * @param contentBuilder - Function to build notification content
   * @returns Result with success/failure counts
   */
  async sendNotificationBatch<T extends NotificationUser>(
    users: readonly T[],
    notificationType: NotificationType,
    languageMap: Map<string, string>,
    contentBuilder: ContentBuilder<T>
  ): Promise<NotificationResult> {
    let successCount = 0
    let failureCount = 0

    for (let i = 0; i < users.length; i += this.config.batchSize) {
      const batch = users.slice(i, i + this.config.batchSize)

      const results = await Promise.allSettled(
        batch.map(async (user) => {
          try {
            const language = languageMap.get(user.user_id) || 'en'
            const payload = contentBuilder({ user, language })

            const result = await this.fcmService.sendNotification({
              token: user.fcm_token,
              notification: { title: payload.title, body: payload.body },
              data: {
                type: notificationType,
                language,
                ...payload.data,
              },
              android: { priority: 'high' },
              apns: {
                headers: { 'apns-priority': '10' },
                payload: { aps: { sound: 'default', badge: 1 } },
              },
            })

            // Log the notification
            await logNotification(this.config.supabaseUrl, this.config.serviceRoleKey, {
              userId: user.user_id,
              notificationType,
              title: payload.title,
              body: payload.body,
              language,
              deliveryStatus: result.success ? 'sent' : 'failed',
              fcmMessageId: result.messageId,
              errorMessage: result.error,
            })

            return { success: result.success, userId: user.user_id }
          } catch (error) {
            console.error(`[NotificationHelper] Error sending to user ${user.user_id}:`, error)
            return { success: false, userId: user.user_id, error: String(error) }
          }
        })
      )

      results.forEach((result) => {
        if (result.status === 'fulfilled' && result.value.success) {
          successCount++
        } else {
          failureCount++
        }
      })

      const batchNum = Math.floor(i / this.config.batchSize) + 1
      console.log(`[NotificationHelper] Batch ${batchNum} complete: ${successCount} sent, ${failureCount} failed`)
    }

    return {
      successCount,
      failureCount,
      totalProcessed: successCount + failureCount,
    }
  }

  /**
   * Create a standard success response
   */
  createSuccessResponse(
    message: string,
    data: Record<string, unknown> = {}
  ): Response {
    return new Response(
      JSON.stringify({
        success: true,
        message,
        ...data,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  }
}

/**
 * Factory function to create NotificationHelperService
 */
export function createNotificationHelper(): NotificationHelperService {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

  if (!supabaseUrl || !serviceRoleKey) {
    throw new AppError(
      'CONFIGURATION_ERROR',
      'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY',
      500
    )
  }

  return new NotificationHelperService({
    supabaseUrl,
    serviceRoleKey,
  })
}
