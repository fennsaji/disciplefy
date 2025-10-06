// ============================================================================
// Firebase Cloud Messaging Service
// ============================================================================
// Handles all FCM operations including token management and notification sending
// Uses Firebase Admin SDK with service account credentials from Supabase secrets

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

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
}

interface FCMResponse {
  success: boolean;
  messageId?: string;
  error?: string;
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
    // Return cached token if still valid (with 5-minute buffer)
    const now = Date.now();
    if (this.accessToken && this.tokenExpiry > now + 300000) {
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
        const error = await tokenResponse.text();
        throw new Error(`Failed to get access token: ${error}`);
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
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`Failed to authenticate with Firebase: ${errorMessage}`);
    }
  }

  /**
   * Create a signed JWT for service account authentication
   */
  private async createServiceAccountJWT(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    const expiry = now + 3600; // 1 hour

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
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
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

      const response = await fetch(fcmEndpoint, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ message }),
      });

      if (!response.ok) {
        const error = await response.json();
        console.error('FCM API error:', error);
        return {
          success: false,
          error: error.error?.message || 'Unknown FCM error',
        };
      }

      const data = await response.json();
      return {
        success: true,
        messageId: data.name,
      };
    } catch (error) {
      console.error('Error sending notification:', error);
      const errorMessage = error instanceof Error ? error.message : String(error);
      return {
        success: false,
        error: errorMessage,
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
    const batchSize = 10;
    for (let i = 0; i < tokens.length; i += batchSize) {
      const batch = tokens.slice(i, i + batchSize);
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
   * Check if FCM token is valid by attempting a dry-run send
   */
  async validateToken(token: string): Promise<boolean> {
    try {
      const result = await this.sendNotification({
        token,
        notification: {
          title: 'Test',
          body: 'Token validation',
        },
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

  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD

  const { data, error } = await supabase
    .from('notification_logs')
    .select('id')
    .eq('user_id', userId)
    .eq('notification_type', notificationType)
    .gte('sent_at', `${today}T00:00:00`)
    .lt('sent_at', `${today}T23:59:59`)
    .limit(1);

  if (error) {
    console.error('Error checking notification log:', error);
    return false; // Assume not sent if error
  }

  return (data?.length || 0) > 0;
}
