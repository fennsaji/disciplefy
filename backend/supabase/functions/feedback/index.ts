/**
 * Feedback Edge Function
 *
 * Refactored to use clean architecture with function factory
 * Enhanced with email notification to contact@disciplefy.com
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'

interface FeedbackRequest {
  readonly study_guide_id?: string
  readonly was_helpful: boolean
  readonly message?: string
  readonly category?: string
  readonly user_context?: {
    is_authenticated?: boolean
    user_id?: string
    session_id?: string
  }
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Escapes HTML special characters to prevent XSS attacks.
 *
 * @param unsafe - The raw string that may contain HTML special characters
 * @returns The sanitized string with HTML entities escaped
 */
function escapeHtml(unsafe: string): string {
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')
    .replace(/\//g, '&#x2F;')
}

/**
 * Converts a category code to a human-readable label.
 *
 * @param category - The category code (e.g., 'general', 'content', 'technical')
 * @returns The human-readable category label
 */
function getCategoryLabel(category: string): string {
  const labels: Record<string, string> = {
    'general': 'General Feedback',
    'content': 'Content Quality',
    'usability': 'Usability/UX',
    'technical': 'Technical Issue',
    'suggestion': 'Feature Suggestion'
  }
  return labels[category] || category
}

// ============================================================================
// Email Helper Functions
// ============================================================================

interface UserContext {
  is_authenticated?: boolean
  user_id?: string
  session_id?: string
}

interface FeedbackEmailData {
  category: string
  wasHelpful: boolean
  message: string | null
  userContext?: UserContext
  createdAt: string
}

interface ResendPayload {
  from: string
  to: string[]
  subject: string
  html: string
}

/**
 * Formats user context into a human-readable string for email display.
 *
 * @param userContext - Optional user context with authentication details
 * @returns Formatted string describing the user (authenticated or anonymous)
 */
function formatUserInfo(userContext?: UserContext): string {
  if (userContext?.is_authenticated) {
    return `Authenticated User (ID: ${userContext.user_id || 'unknown'})`
  }
  return `Anonymous User (Session: ${userContext?.session_id || 'unknown'})`
}

/**
 * Formats a timestamp into IST (Indian Standard Time) for email display.
 *
 * @param createdAt - ISO 8601 timestamp string
 * @returns Formatted date string in 'en-IN' locale with IST timezone
 */
function formatSubmittedAt(createdAt: string): string {
  return new Date(createdAt).toLocaleString('en-IN', {
    timeZone: 'Asia/Kolkata',
    dateStyle: 'medium',
    timeStyle: 'short'
  })
}

// Email template with placeholder tokens for feedback notifications
const FEEDBACK_EMAIL_TEMPLATE = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #1E1E1E; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: linear-gradient(135deg, #6A4FB6 0%, #8B5CF6 100%); padding: 30px; border-radius: 12px 12px 0 0; text-align: center;">
    <h1 style="color: white; margin: 0; font-size: 24px;">📬 New Feedback Received</h1>
  </div>
  <div style="background: #f8f9fa; padding: 30px; border-radius: 0 0 12px 12px; border: 1px solid #e9ecef; border-top: none;">
    <table style="width: 100%; border-collapse: collapse;">
      <tr>
        <td style="padding: 12px 0; border-bottom: 1px solid #dee2e6; font-weight: 600; width: 140px; color: #6A4FB6;">Category</td>
        <td style="padding: 12px 0; border-bottom: 1px solid #dee2e6;">{{CATEGORY}}</td>
      </tr>
      <tr>
        <td style="padding: 12px 0; border-bottom: 1px solid #dee2e6; font-weight: 600; color: #6A4FB6;">Rating</td>
        <td style="padding: 12px 0; border-bottom: 1px solid #dee2e6;">{{HELPFUL_STATUS}}</td>
      </tr>
      <tr>
        <td style="padding: 12px 0; border-bottom: 1px solid #dee2e6; font-weight: 600; color: #6A4FB6;">User</td>
        <td style="padding: 12px 0; border-bottom: 1px solid #dee2e6; font-size: 13px; color: #666;">{{USER_INFO}}</td>
      </tr>
      <tr>
        <td style="padding: 12px 0; border-bottom: 1px solid #dee2e6; font-weight: 600; color: #6A4FB6;">Submitted</td>
        <td style="padding: 12px 0; border-bottom: 1px solid #dee2e6; font-size: 13px; color: #666;">{{SUBMITTED_AT}}</td>
      </tr>
    </table>
    <div style="margin-top: 24px;">
      <h3 style="color: #6A4FB6; margin: 0 0 12px 0; font-size: 16px;">Message</h3>
      <div style="background: white; padding: 16px; border-radius: 8px; border: 1px solid #dee2e6; white-space: pre-wrap; font-size: 14px;">{{MESSAGE}}</div>
    </div>
  </div>
  <div style="text-align: center; margin-top: 20px; color: #666; font-size: 12px;">
    <p>This email was sent from the Disciplefy app feedback system.</p>
  </div>
</body>
</html>`

/**
 * Builds the HTML email by filling placeholders in the template.
 *
 * @param wasHelpful - Whether the feedback was positive
 * @param categoryLabel - Human-readable category label
 * @param safeMessage - Sanitized feedback message (HTML-escaped)
 * @param submittedAt - Formatted submission timestamp
 * @param userInfo - Formatted user information string
 * @returns Complete HTML email string with placeholders replaced
 */
function buildFeedbackHtml(
  wasHelpful: boolean,
  categoryLabel: string,
  safeMessage: string,
  submittedAt: string,
  userInfo: string
): string {
  const helpfulStatus = wasHelpful ? '👍 Helpful' : '👎 Not Helpful'

  return FEEDBACK_EMAIL_TEMPLATE
    .replace('{{CATEGORY}}', categoryLabel)
    .replace('{{HELPFUL_STATUS}}', helpfulStatus)
    .replace('{{USER_INFO}}', userInfo)
    .replace('{{SUBMITTED_AT}}', submittedAt)
    .replace('{{MESSAGE}}', safeMessage)
}

/**
 * Sends an email using the Resend API.
 *
 * @param resendApiKey - The Resend API key for authentication
 * @param payload - Email payload containing from, to, subject, and html
 * @returns Object containing the email ID on success
 * @throws Error if the API request fails with error message
 */
async function sendResendEmail(
  resendApiKey: string,
  payload: ResendPayload
): Promise<{ id: string }> {
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${resendApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  })

  if (!response.ok) {
    const errorData = await response.json()
    throw new Error(errorData.message || 'Failed to send email')
  }

  return await response.json()
}

/**
 * Handles local dev mode when RESEND_API_KEY is not set.
 *
 * @param feedback - Feedback data to log
 * @returns Success result for dev mode
 */
function handleLocalDevMode(feedback: FeedbackEmailData): { success: boolean } {
  console.log('[FEEDBACK] RESEND_API_KEY not configured - LOCAL DEV MODE')
  console.log('[FEEDBACK] Email would be sent to: contact@disciplefy.com')
  console.log('[FEEDBACK] Category:', feedback.category)
  console.log('[FEEDBACK] Was Helpful:', feedback.wasHelpful)
  console.log('[FEEDBACK] Message:', feedback.message)
  return { success: true }
}

/**
 * Prepares the HTML content for the feedback email.
 *
 * @param feedback - Feedback data to format
 * @returns HTML content string
 */
function prepareFeedbackContent(feedback: FeedbackEmailData): string {
  const categoryLabel = getCategoryLabel(feedback.category)
  const safeMessage = feedback.message ? escapeHtml(feedback.message).slice(0, 2000) : 'No message provided'
  const userInfo = formatUserInfo(feedback.userContext)
  const submittedAt = formatSubmittedAt(feedback.createdAt)
  return buildFeedbackHtml(feedback.wasHelpful, categoryLabel, safeMessage, submittedAt, userInfo)
}

/**
 * Builds the Resend payload for the feedback email.
 *
 * @param feedback - Feedback data for subject line
 * @param htmlContent - Pre-rendered HTML content
 * @returns ResendPayload ready to send
 */
function buildFeedbackPayload(feedback: FeedbackEmailData, htmlContent: string): ResendPayload {
  const categoryLabel = getCategoryLabel(feedback.category)
  return {
    from: 'Disciplefy Feedback <feedback@disciplefy.in>',
    to: ['contact@disciplefy.com'],
    subject: `[Feedback] ${categoryLabel} - ${feedback.wasHelpful ? 'Positive' : 'Negative'}`,
    html: htmlContent,
  }
}

/**
 * Sends the email and logs the result.
 *
 * @param resendApiKey - API key for Resend
 * @param payload - Email payload
 * @returns Success result with optional error
 */
async function sendAndLogEmail(
  resendApiKey: string,
  payload: ResendPayload
): Promise<{ success: boolean; error?: string }> {
  try {
    const result = await sendResendEmail(resendApiKey, payload)
    console.log('[FEEDBACK] Email sent successfully:', result.id)
    return { success: true }
  } catch (error) {
    console.error('[FEEDBACK] Error sending email:', error)
    return { success: false, error: 'Failed to send email' }
  }
}

/**
 * Sends a feedback notification email to the contact address.
 *
 * @param feedback - Feedback data including category, rating, message, and context
 * @returns Object with success boolean and optional error message
 */
async function sendFeedbackEmail(
  feedback: FeedbackEmailData
): Promise<{ success: boolean; error?: string }> {
  const resendApiKey = Deno.env.get('RESEND_API_KEY')
  if (!resendApiKey) return handleLocalDevMode(feedback)

  const htmlContent = prepareFeedbackContent(feedback)
  const payload = buildFeedbackPayload(feedback, htmlContent)
  return sendAndLogEmail(resendApiKey, payload)
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleFeedback(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  const requestBody = await req.json() as FeedbackRequest

  // Validate required fields
  if (typeof requestBody.was_helpful !== 'boolean') {
    throw new AppError('VALIDATION_ERROR', 'was_helpful field is required and must be a boolean', 400)
  }

  // Optional validation for study_guide_id
  if (requestBody.study_guide_id && typeof requestBody.study_guide_id !== 'string') {
    throw new AppError('VALIDATION_ERROR', 'study_guide_id must be a string', 400)
  }

  const createdAt = new Date().toISOString()

  // Insert feedback
  const { data, error } = await services.supabaseServiceClient
    .from('feedback')
    .insert({
      study_guide_id: requestBody.study_guide_id || null,
      was_helpful: requestBody.was_helpful,
      message: requestBody.message || null,
      category: requestBody.category || 'general',
      user_id: null, // Anonymous feedback
      created_at: createdAt
    })
    .select()
    .single()

  if (error) {
    console.error('Database error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to save feedback', 500)
  }

  // Send email notification (non-blocking - don't fail if email fails)
  const emailResult = await sendFeedbackEmail({
    category: requestBody.category || 'general',
    wasHelpful: requestBody.was_helpful,
    message: requestBody.message || null,
    userContext: requestBody.user_context,
    createdAt
  })

  if (!emailResult.success) {
    console.warn('[FEEDBACK] Email notification failed:', emailResult.error)
    // Continue anyway - feedback was saved successfully
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        id: data.id,
        was_helpful: data.was_helpful,
        message: data.message,
        category: data.category,
        created_at: data.created_at
      },
      message: 'Thank you for your feedback!'
    }),
    { status: 201, headers: { 'Content-Type': 'application/json' } }
  )
}

// ============================================================================
// Create Function with Factory
// ============================================================================

createSimpleFunction(handleFeedback, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 15000
})
