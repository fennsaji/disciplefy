/**
 * Send Alert Notification
 * Sends email or Slack notifications for triggered usage alerts
 * Called by check-usage-alerts function or can be invoked manually by admins
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import type { AlertTrigger, AlertType, NotificationChannel } from '../_shared/types/usage-types.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Verify authentication (service role or admin user)
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    );

    const {
      data: { user },
      error: authError,
    } = await supabaseClient.auth.getUser();

    // Allow service role without user
    const isServiceRole = req.headers.get('Authorization')?.includes('service_role');

    if (!isServiceRole && (authError || !user)) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // If user-based auth, verify admin
    if (user && !isServiceRole) {
      const { data: profile, error: profileError } = await supabaseClient
        .from('user_profiles')
        .select('is_admin')
        .eq('id', user.id)
        .single();

      if (profileError || !profile?.is_admin) {
        return new Response(
          JSON.stringify({ error: 'Forbidden - Admin access required' }),
          {
            status: 403,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }
    }

    // Parse request body
    const body = await req.json();
    const alert: AlertTrigger = body.alert;
    const channel: NotificationChannel = body.channel || 'database';

    if (!alert) {
      return new Response(
        JSON.stringify({ error: 'Missing alert object in request body' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Send notification based on channel
    let notificationResult;

    switch (channel) {
      case 'email':
        notificationResult = await sendEmailNotification(alert);
        break;

      case 'slack':
        notificationResult = await sendSlackNotification(alert);
        break;

      case 'database':
      default:
        notificationResult = await sendDatabaseNotification(supabaseClient, alert);
        break;
    }

    return new Response(
      JSON.stringify({
        success: true,
        channel,
        alert_type: alert.alert_type,
        notification_result: notificationResult,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error: unknown) {
    console.error('Send notification error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Internal server error';
    return new Response(
      JSON.stringify({ error: errorMessage }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});

/**
 * Send email notification (requires SMTP configuration)
 */
async function sendEmailNotification(alert: AlertTrigger): Promise<any> {
  const adminEmail = Deno.env.get('ADMIN_EMAIL');

  if (!adminEmail) {
    console.warn('ADMIN_EMAIL not configured, skipping email notification');
    return { sent: false, reason: 'No admin email configured' };
  }

  // Email configuration
  const emailSubject = getEmailSubject(alert.alert_type);
  const emailBody = formatEmailBody(alert);

  console.log('Would send email to:', adminEmail);
  console.log('Subject:', emailSubject);
  console.log('Body:', emailBody);

  // TODO: Implement actual email sending via SMTP or email service
  // For now, just log
  // Example using Resend or SendGrid:
  /*
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${Deno.env.get('RESEND_API_KEY')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: 'alerts@disciplefy.com',
      to: adminEmail,
      subject: emailSubject,
      html: emailBody,
    }),
  });
  */

  return {
    sent: false,
    placeholder: true,
    message: 'Email notification logged (SMTP not configured)',
  };
}

/**
 * Send Slack notification (requires Slack webhook URL)
 */
async function sendSlackNotification(alert: AlertTrigger): Promise<any> {
  const slackWebhookUrl = Deno.env.get('SLACK_WEBHOOK_URL');

  if (!slackWebhookUrl) {
    console.warn('SLACK_WEBHOOK_URL not configured, skipping Slack notification');
    return { sent: false, reason: 'No Slack webhook configured' };
  }

  const slackMessage = formatSlackMessage(alert);

  try {
    const response = await fetch(slackWebhookUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(slackMessage),
    });

    if (!response.ok) {
      throw new Error(`Slack API error: ${response.status} ${response.statusText}`);
    }

    return { sent: true, channel: 'slack' };
  } catch (error: unknown) {
    console.error('Slack notification failed:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return { sent: false, error: errorMessage };
  }
}

/**
 * Store notification in database (for admin dashboard)
 */
async function sendDatabaseNotification(
  supabaseClient: any,
  alert: AlertTrigger
): Promise<any> {
  const { data, error } = await supabaseClient.from('analytics_events').insert({
    event_type: `alert_${alert.alert_type}`,
    event_data: {
      ...alert,
      notification_sent_at: new Date().toISOString(),
    },
    created_at: new Date().toISOString(),
  });

  if (error) {
    console.error('Database notification failed:', error);
    return { sent: false, error: error.message };
  }

  return { sent: true, channel: 'database' };
}

// Helper functions for formatting

function getEmailSubject(alertType: AlertType): string {
  const subjects: Record<AlertType, string> = {
    cost_spike: '🚨 Usage Alert: Cost Spike Detected',
    usage_anomaly: '⚠️ Usage Alert: Unusual Activity Detected',
    rate_limit_exceeded: '⏱️ Usage Alert: Rate Limit Exceeded',
    negative_profitability: '📉 Usage Alert: Negative Profitability',
  };
  return subjects[alertType] || 'Usage Alert';
}

function formatEmailBody(alert: AlertTrigger): string {
  return `
    <html>
      <body style="font-family: Arial, sans-serif; padding: 20px;">
        <h2>${getEmailSubject(alert.alert_type)}</h2>
        <p><strong>Alert Type:</strong> ${alert.alert_type}</p>
        <p><strong>Time:</strong> ${alert.timestamp.toLocaleString()}</p>
        ${alert.user_id ? `<p><strong>User ID:</strong> ${alert.user_id}</p>` : ''}
        ${alert.feature_name ? `<p><strong>Feature:</strong> ${alert.feature_name}</p>` : ''}
        <p><strong>Current Value:</strong> ${alert.current_value.toFixed(2)}</p>
        <p><strong>Threshold:</strong> ${alert.threshold_value.toFixed(2)}</p>
        <hr />
        <p>${alert.message}</p>
        <hr />
        <p><small>This is an automated alert from Disciplefy Usage Tracking System</small></p>
      </body>
    </html>
  `;
}

function formatSlackMessage(alert: AlertTrigger): any {
  const emoji = getAlertEmoji(alert.alert_type);
  const color = getAlertColor(alert.alert_type);

  return {
    text: `${emoji} Usage Alert: ${alert.alert_type}`,
    attachments: [
      {
        color,
        fields: [
          {
            title: 'Alert Type',
            value: alert.alert_type,
            short: true,
          },
          {
            title: 'Time',
            value: alert.timestamp.toLocaleString(),
            short: true,
          },
          ...(alert.user_id
            ? [
                {
                  title: 'User ID',
                  value: alert.user_id,
                  short: true,
                },
              ]
            : []),
          ...(alert.feature_name
            ? [
                {
                  title: 'Feature',
                  value: alert.feature_name,
                  short: true,
                },
              ]
            : []),
          {
            title: 'Current Value',
            value: alert.current_value.toFixed(2),
            short: true,
          },
          {
            title: 'Threshold',
            value: alert.threshold_value.toFixed(2),
            short: true,
          },
          {
            title: 'Details',
            value: alert.message,
            short: false,
          },
        ],
      },
    ],
  };
}

function getAlertEmoji(alertType: AlertType): string {
  const emojis: Record<AlertType, string> = {
    cost_spike: '🚨',
    usage_anomaly: '⚠️',
    rate_limit_exceeded: '⏱️',
    negative_profitability: '📉',
  };
  return emojis[alertType] || '🔔';
}

function getAlertColor(alertType: AlertType): string {
  const colors: Record<AlertType, string> = {
    cost_spike: '#ff0000', // Red
    usage_anomaly: '#ff9900', // Orange
    rate_limit_exceeded: '#ffcc00', // Yellow
    negative_profitability: '#cc0000', // Dark red
  };
  return colors[alertType] || '#808080';
}
