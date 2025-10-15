// ============================================================================
// Firebase Cloud Messaging Service
// ============================================================================
// Handles all FCM operations including token management and notification sending
// Uses Firebase Admin SDK with service account credentials from Supabase secrets

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { formatError, formatFCMError } from './utils/error-formatter.ts';

// ============================================================================
// Configuration Constants
// ============================================================================

const FCM_CONFIG = {
  // Token refresh buffer: 5 minutes before expiry
  TOKEN_REFRESH_BUFFER_MS: 5 * 60 * 1000,
  
  // Batch processing: 10 notifications per batch (rate limiting)
  BATCH_SIZE: 10,
  
  // JWT expiry: 1 hour (Google OAuth requirement)
  JWT_EXPIRY_SECONDS: 3600,
  
  // OAuth scope for Firebase Cloud Messaging
  OAUTH_SCOPE: 'https://www.googleapis.com/auth/firebase.messaging',
} as const;

// Firebase Admin SDK types
interface FirebaseCredentials {
  projectId: string;
  privateKey: string;
  clientEmail: string;
}

interface FCMMessage {
  token: string;
  notification: {
    title: string;
    body: string;
  };
  data?: Record<string, string>;
  android?: {
    priority: 'high' | 'normal';
  };
  apns?: {
    headers: Record<string, string>;
    payload: {
      aps: {
        sound: string;
        badge?: number;
      };
    };
  };
  validateOnly?: boolean;
}

interface FCMResponse {
  success: boolean;
  messageId?: string;
  error?: string;
}

// FCM API v1 request body structure
interface FCMRequestBody {
  message: Omit<FCMMessage, 'validateOnly'>;
  validate_only?: boolean;
}

// ============================================================================
// FCM Service Class
// ============================================================================

export class FCMService {
  private credentials: FirebaseCredentials;
  private accessToken: string | null = null;
  private tokenExpiry: number = 0;

  constructor() {
    // Load Firebase credentials from Supabase secrets
    this.credentials = {
      projectId: Deno.env.get('FIREBASE_PROJECT_ID') || '',
      privateKey: (Deno.env.get('FIREBASE_PRIVATE_KEY') || '').replace(/\\n/g, '\n'),
      clientEmail: Deno.env.get('FIREBASE_CLIENT_EMAIL') || '',
    };

    // Validate credentials
    if (!this.credentials.projectId || !this.credentials.privateKey || !this.credentials.clientEmail) {
      throw new Error('Missing Firebase credentials in environment variables');
    }
  }

  // ==========================================================================
  // Access Token Management
  // ==========================================================================

  /**
   * Get a valid OAuth2 access token for Firebase Admin SDK
   * Uses service account credentials to generate JWT and exchange for access token
   */
  private async getAccessToken(): Promise<string> {
    // Return cached token if still valid (with buffer before expiry)
    const now = Date.now();
    if (this.accessToken && this.tokenExpiry > now + FCM_CONFIG.TOKEN_REFRESH_BUFFER_MS) {
      return this.accessToken;
    }

    try {
      // Create JWT for Google OAuth2
      const jwt = await this.createServiceAccountJWT();

      // Exchange JWT for access token
      const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          assertion: jwt,
        }),
      });

      if (!tokenResponse.ok) {
        const errorText = await tokenResponse.text();
        throw new Error(`Failed to get access token: ${errorText}`);
      }

      const tokenData = await tokenResponse.json();
      this.accessToken = tokenData.access_token;
      this.tokenExpiry = now + (tokenData.expires_in * 1000);

      if (!this.accessToken) {
        throw new Error('Failed to get access token from Firebase');
      }

      return this.accessToken;
    } catch (error) {
      console.error('Error getting access token:', error);
      throw new Error(`Failed to authenticate with Firebase: ${formatError(error)}`);
    }
  }

  /**
   * Create a signed JWT for service account authentication
   */
  private async createServiceAccountJWT(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    const expiry = now + FCM_CONFIG.JWT_EXPIRY_SECONDS;

    // JWT header
    const header = {
      alg: 'RS256',
      typ: 'JWT',
    };

    // JWT payload
    const payload = {
      iss: this.credentials.clientEmail,
      sub: this.credentials.clientEmail,
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: expiry,
      scope: FCM_CONFIG.OAUTH_SCOPE,
    };

    // Encode header and payload
    const encodedHeader = this.base64UrlEncode(JSON.stringify(header));
    const encodedPayload = this.base64UrlEncode(JSON.stringify(payload));
    const unsignedToken = `${encodedHeader}.${encodedPayload}`;

    // Sign the token
    const signature = await this.signJWT(unsignedToken, this.credentials.privateKey);
    
    return `${unsignedToken}.${signature}`;
  }

  /**
   * Sign JWT using RS256 algorithm with private key
   */
  private async signJWT(data: string, privateKey: string): Promise<string> {
    // Import private key
    const pemKey = privateKey
      .replace(/-----BEGIN PRIVATE KEY-----/, '')
      .replace(/-----END PRIVATE KEY-----/, '')
      .replace(/\s/g, '');
    
    const binaryKey = Uint8Array.from(atob(pemKey), c => c.charCodeAt(0));
    
    const cryptoKey = await crypto.subtle.importKey(
      'pkcs8',
      binaryKey,
      {
        name: 'RSASSA-PKCS1-v1_5',
        hash: 'SHA-256',
      },
      false,
      ['sign']
    );

    // Sign the data
    const encoder = new TextEncoder();
    const dataBuffer = encoder.encode(data);
    const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', cryptoKey, dataBuffer);

    // Encode signature as base64url
    return this.base64UrlEncode(String.fromCharCode(...new Uint8Array(signature)));
  }

  /**
   * Base64 URL encode helper
   */
  private base64UrlEncode(str: string): string {
    return btoa(str)
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
  }

  // ==========================================================================
  // Notification Sending
  // ==========================================================================

  /**
   * Send push notification via FCM to a single device
   */
  async sendNotification(message: FCMMessage): Promise<FCMResponse> {
    try {
      const accessToken = await this.getAccessToken();

      // Construct FCM v1 API request
      const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${this.credentials.projectId}/messages:send`;

      // Extract validateOnly flag and remove it from message
      const { validateOnly, ...messageWithoutValidateOnly } = message;

      // Build request body with validate_only at top level (FCM v1 API requirement)
      const requestBody: FCMRequestBody = {
        message: messageWithoutValidateOnly,
      };
      
      if (validateOnly) {
        requestBody.validate_only = true;
      }

      const response = await fetch(fcmEndpoint, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody),
      });

      if (!response.ok) {
        const error = await response.json();
        console.error('FCM API error:', error);
        return {
          success: false,
          error: formatFCMError(error),
        };
      }

      const data = await response.json();
      return {
        success: true,
        messageId: data.name,
      };
    } catch (error) {
      console.error('Error sending notification:', error);
      return {
        success: false,
        error: formatError(error),
      };
    }
  }

  /**
   * Send push notifications to multiple devices in batch
   */
  async sendBatchNotifications(
    tokens: string[],
    notification: { title: string; body: string },
    data?: Record<string, string>
  ): Promise<{ successCount: number; failureCount: number; results: FCMResponse[] }> {
    const results: FCMResponse[] = [];
    let successCount = 0;
    let failureCount = 0;

    // Send notifications in parallel (with rate limiting)
    for (let i = 0; i < tokens.length; i += FCM_CONFIG.BATCH_SIZE) {
      const batch = tokens.slice(i, i + FCM_CONFIG.BATCH_SIZE);
      const batchPromises = batch.map(token =>
        this.sendNotification({
          token,
          notification,
          data,
          android: { priority: 'high' },
          apns: {
            headers: { 'apns-priority': '10' },
            payload: { aps: { sound: 'default' } },
          },
        })
      );

      const batchResults = await Promise.all(batchPromises);
      results.push(...batchResults);

      // Count successes and failures
      batchResults.forEach(result => {
        if (result.success) successCount++;
        else failureCount++;
      });
    }

    return { successCount, failureCount, results };
  }

  // ==========================================================================
  // Token Validation
  // ==========================================================================

  /**
   * Check if FCM token is valid using validate-only mode (no notification sent)
   */
  async validateToken(token: string): Promise<boolean> {
    try {
      const result = await this.sendNotification({
        token,
        notification: {
          title: 'Validation',
          body: 'Token validation',
        },
        validateOnly: true,
      });
      return result.success;
    } catch {
      return false;
    }
  }
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Log notification event to database
 */
export async function logNotification(
  supabaseUrl: string,
  supabaseKey: string,
  log: {
    userId: string;
    notificationType: 'daily_verse' | 'recommended_topic';
    title: string;
    body: string;
    topicId?: string;
    verseReference?: string;
    language: string;
    deliveryStatus: 'sent' | 'delivered' | 'failed';
    fcmMessageId?: string;
    errorMessage?: string;
  }
): Promise<void> {
  const supabase = createClient(supabaseUrl, supabaseKey);

  const { error } = await supabase.from('notification_logs').insert({
    user_id: log.userId,
    notification_type: log.notificationType,
    title: log.title,
    body: log.body,
    topic_id: log.topicId,
    verse_reference: log.verseReference,
    language: log.language,
    delivery_status: log.deliveryStatus,
    fcm_message_id: log.fcmMessageId,
    error_message: log.errorMessage,
  });

  if (error) {
    console.error('Failed to log notification:', error);
  }
}

/**
 * Check if user already received a notification today
 */
export async function hasReceivedNotificationToday(
  supabaseUrl: string,
  supabaseKey: string,
  userId: string,
  notificationType: 'daily_verse' | 'recommended_topic'
): Promise<boolean> {
  const supabase = createClient(supabaseUrl, supabaseKey);

  // Calculate today and tomorrow in UTC
  const now = new Date();
  const today = now.toISOString().split('T')[0]; // YYYY-MM-DD
  const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString().split('T')[0]; // YYYY-MM-DD

  const { data, error } = await supabase
    .from('notification_logs')
    .select('id')
    .eq('user_id', userId)
    .eq('notification_type', notificationType)
    .gte('sent_at', `${today}T00:00:00`)
    .lt('sent_at', `${tomorrow}T00:00:00`) // Fixed: Use tomorrow 00:00:00 instead of today 23:59:59
    .limit(1);

  if (error) {
    console.error('Error checking notification log:', error);
    return false; // Assume not sent if error
  }

  return (data?.length || 0) > 0;
}

/**
 * Batch check if multiple users have already received a notification today
 * Returns a Set of user IDs who have already received the notification
 * This is much more efficient than checking each user individually (avoids N+1 queries)
 */
export async function getBatchNotificationStatus(
  supabaseUrl: string,
  supabaseKey: string,
  userIds: string[],
  notificationType: 'daily_verse' | 'recommended_topic'
): Promise<Set<string>> {
  const supabase = createClient(supabaseUrl, supabaseKey);

  // Calculate today and tomorrow in UTC
  const now = new Date();
  const today = now.toISOString().split('T')[0]; // YYYY-MM-DD
  const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString().split('T')[0]; // YYYY-MM-DD

  const { data, error } = await supabase
    .from('notification_logs')
    .select('user_id')
    .eq('notification_type', notificationType)
    .gte('sent_at', `${today}T00:00:00`)
    .lt('sent_at', `${tomorrow}T00:00:00`) // Fixed: Use tomorrow 00:00:00 instead of today 23:59:59
    .in('user_id', userIds);

  if (error) {
    console.error('Error checking batch notification logs:', error);
    return new Set(); // Return empty set if error (assume no one received)
  }

  // Return Set of user IDs who already received notification today
  return new Set(data?.map(row => row.user_id) || []);
}
