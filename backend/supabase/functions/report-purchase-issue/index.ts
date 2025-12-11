/**
 * Report Purchase Issue Edge Function
 *
 * Allows users to report issues with their token purchases.
 * Features:
 * - Submit issue reports with transaction details
 * - Upload screenshot evidence (max 3)
 * - Send notification emails to admins
 * - Send confirmation email to user
 */

import { createClient, SupabaseClient, User } from 'https://esm.sh/@supabase/supabase-js@2'
import { handleCors } from '../_shared/utils/cors.ts'
import { config } from '../_shared/core/config.ts'

// ============================================================================
// Types
// ============================================================================

interface SubmitReportRequest {
  action: 'submit_report'
  purchaseId: string
  paymentId: string
  orderId: string
  tokenAmount: number
  costRupees: number
  purchasedAt: string
  issueType: 'wrong_amount' | 'payment_failed' | 'tokens_not_credited' | 'duplicate_charge' | 'refund_request' | 'other'
  description: string
  screenshotUrls?: string[]
}

interface UploadScreenshotRequest {
  action: 'upload_screenshot'
  fileName: string
  fileBase64: string
  mimeType: string
}

type RequestBody = SubmitReportRequest | UploadScreenshotRequest

/** Data for admin notification email */
interface AdminReportData {
  userEmail: string
  issueType: string
  description: string
  paymentId: string
  orderId: string
  tokenAmount: number
  costRupees: number
  purchasedAt: string
  screenshotCount: number
  reportId: string
}

/** Data for user confirmation email */
interface UserConfirmationData {
  userName?: string
  issueType: string
  paymentId: string
  reportId: string
}

/** Auth result with user and admin client */
interface AuthResult {
  user: User
  supabaseAdmin: SupabaseClient
}

// ============================================================================
// Response Helpers
// ============================================================================

/**
 * Creates a success response with JSON body.
 */
function createSuccessResponse(data: Record<string, unknown>, corsHeaders: Record<string, string>): Response {
  return new Response(
    JSON.stringify({ success: true, ...data }),
    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

/**
 * Creates an error response with JSON body.
 */
function createErrorResponse(message: string, status: number, corsHeaders: Record<string, string>): Response {
  return new Response(
    JSON.stringify({ success: false, error: message }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

// ============================================================================
// Utility Helpers
// ============================================================================

/**
 * Escapes HTML special characters to prevent XSS.
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
 * Converts issue type code to human-readable label.
 */
function getIssueTypeLabel(issueType: string): string {
  const labels: Record<string, string> = {
    'wrong_amount': 'Wrong Amount Charged',
    'payment_failed': 'Payment Failed',
    'tokens_not_credited': 'Tokens Not Credited',
    'duplicate_charge': 'Duplicate Charge',
    'refund_request': 'Refund Request',
    'other': 'Other Issue'
  }
  return labels[issueType] || issueType
}

/**
 * Formats date to IST locale string.
 */
function formatDateIST(dateStr: string): string {
  return new Date(dateStr).toLocaleString('en-IN', {
    timeZone: 'Asia/Kolkata',
    dateStyle: 'medium',
    timeStyle: 'short'
  })
}

// ============================================================================
// Email Functions - Send via Resend
// ============================================================================

/**
 * Handles local dev mode when RESEND_API_KEY is not set.
 */
function handleDevMode(to: string | string[], subject: string): { success: boolean } {
  console.log('[REPORT ISSUE] RESEND_API_KEY not configured - LOCAL DEV MODE')
  console.log('[REPORT ISSUE] Email would be sent to:', to)
  console.log('[REPORT ISSUE] Subject:', subject)
  return { success: true }
}

/**
 * Sends email via Resend API.
 */
async function sendViaResendApi(
  to: string | string[],
  subject: string,
  htmlContent: string,
  apiKey: string
): Promise<{ success: boolean; error?: string }> {
  const recipients = Array.isArray(to) ? to : [to]

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: 'Disciplefy Support <support@disciplefy.in>',
      to: recipients,
      subject,
      html: htmlContent,
    }),
  })

  if (!response.ok) {
    const errorData = await response.json()
    console.error('[REPORT ISSUE] Resend API error:', errorData)
    return { success: false, error: errorData.message || 'Failed to send email' }
  }

  const data = await response.json()
  console.log('[REPORT ISSUE] Email sent successfully:', data.id)
  return { success: true }
}

/**
 * Sends an email using Resend API or logs in dev mode.
 *
 * @param to - Email recipient(s)
 * @param subject - Email subject line
 * @param htmlContent - HTML email body content
 * @returns Object with success boolean and optional error message
 */
async function sendEmailWithResend(
  to: string | string[],
  subject: string,
  htmlContent: string
): Promise<{ success: boolean; error?: string }> {
  const resendApiKey = Deno.env.get('RESEND_API_KEY')
  if (!resendApiKey) return handleDevMode(to, subject)

  try {
    return await sendViaResendApi(to, subject, htmlContent, resendApiKey)
  } catch (error) {
    console.error('[REPORT ISSUE] Error sending email:', error)
    return { success: false, error: 'Failed to send email' }
  }
}

// ============================================================================
// Admin Email Template Builders
// ============================================================================

/**
 * Builds the admin email header section.
 */
function buildAdminHeader(): string {
  return `<div style="text-align: center; margin-bottom: 30px;">
    <h1 style="color: #DC2626; margin: 0;">⚠️ Purchase Issue Report</h1>
    <p style="color: #666; margin-top: 5px;">Disciplefy Admin Notification</p>
  </div>`
}

/**
 * Builds the issue type alert box section.
 */
function buildIssueAlertSection(issueLabel: string, reportId: string): string {
  return `<div style="background: #FEF2F2; border: 1px solid #FECACA; border-radius: 12px; padding: 20px; margin-bottom: 20px;">
    <h2 style="margin-top: 0; color: #DC2626; font-size: 18px;">Issue Type: ${issueLabel}</h2>
    <p style="margin-bottom: 0;"><strong>Report ID:</strong> ${reportId}</p>
  </div>`
}

/**
 * Builds the user details section header.
 */
function buildUserDetailsHeader(userEmail: string): string {
  return `<h3 style="margin-top: 0; color: #333;">User Details</h3>
    <p><strong>Email:</strong> ${escapeHtml(userEmail)}</p>`
}

/**
 * Builds the transaction details table.
 */
function buildTransactionTable(data: AdminReportData): string {
  const purchaseDate = formatDateIST(data.purchasedAt)
  return `<h3 style="color: #333;">Transaction Details</h3>
    <table style="width: 100%; border-collapse: collapse;">
      <tr><td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Payment ID:</strong></td>
          <td style="padding: 8px 0; border-bottom: 1px solid #eee; font-family: monospace;">${escapeHtml(data.paymentId)}</td></tr>
      <tr><td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Order ID:</strong></td>
          <td style="padding: 8px 0; border-bottom: 1px solid #eee; font-family: monospace;">${escapeHtml(data.orderId)}</td></tr>
      <tr><td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Tokens:</strong></td>
          <td style="padding: 8px 0; border-bottom: 1px solid #eee;">${data.tokenAmount}</td></tr>
      <tr><td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Amount:</strong></td>
          <td style="padding: 8px 0; border-bottom: 1px solid #eee;">₹${data.costRupees.toFixed(2)}</td></tr>
      <tr><td style="padding: 8px 0;"><strong>Purchase Date:</strong></td>
          <td style="padding: 8px 0;">${purchaseDate}</td></tr>
    </table>`
}

/**
 * Builds the issue description section.
 */
function buildIssueDescriptionSection(description: string, screenshotCount: number): string {
  const attachmentNote = screenshotCount > 0
    ? `<p style="margin-top: 16px; color: #666;"><strong>📎 Attachments:</strong> ${screenshotCount} screenshot(s) uploaded</p>`
    : ''
  return `<h3 style="color: #333;">Issue Description</h3>
    <div style="background: white; border: 1px solid #ddd; border-radius: 8px; padding: 16px;">
      <p style="margin: 0; white-space: pre-wrap;">${description.slice(0, 1000)}</p>
    </div>
    ${attachmentNote}`
}

/**
 * Builds the admin email footer section.
 */
function buildAdminFooter(): string {
  return `<div style="text-align: center; color: #999; font-size: 12px;">
    <p>Please review this issue in the Disciplefy Admin Panel.</p>
    <p style="margin-top: 20px;">&copy; ${new Date().getFullYear()} Disciplefy. All rights reserved.</p>
  </div>`
}

/**
 * Generates the complete admin notification email HTML.
 *
 * @param report - Admin report data with transaction and issue details
 * @returns Complete HTML email string for admin notification
 */
function generateAdminEmailHtml(report: AdminReportData): string {
  const issueLabel = getIssueTypeLabel(report.issueType)
  const header = buildAdminHeader()
  const issueAlert = buildIssueAlertSection(issueLabel, report.reportId)
  const userDetails = buildUserDetailsHeader(report.userEmail)
  const transactionTable = buildTransactionTable(report)
  const issueSection = buildIssueDescriptionSection(report.description, report.screenshotCount)
  const footer = buildAdminFooter()

  return `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>New Purchase Issue Report - Disciplefy</title></head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  ${header}
  ${issueAlert}
  <div style="background: #f9f9f9; border-radius: 12px; padding: 20px; margin-bottom: 20px;">
    ${userDetails}
    ${transactionTable}
    ${issueSection}
  </div>
  ${footer}
</body></html>`
}

// ============================================================================
// User Confirmation Email Template Builders
// ============================================================================

/**
 * Builds the user email header section.
 */
function buildUserHeader(): string {
  return `<div style="text-align: center; margin-bottom: 30px;">
    <h1 style="color: #6A4FB6; margin: 0;">Disciplefy</h1>
    <p style="color: #666; margin-top: 5px;">Your Bible Study Companion</p>
  </div>`
}

/**
 * Builds the success message box.
 */
function buildSuccessMessageBox(): string {
  return `<div style="background: #E8F5E9; border-radius: 8px; padding: 16px; margin: 20px 0;">
    <p style="margin: 0; color: #2E7D32;"><strong>✓ Report Submitted Successfully</strong></p>
  </div>`
}

/**
 * Builds the user report details table.
 */
function buildUserReportTable(reportId: string, issueLabel: string, paymentId: string): string {
  return `<h3 style="color: #333;">Report Details</h3>
    <table style="width: 100%;">
      <tr><td style="padding: 4px 0;"><strong>Report ID:</strong></td>
          <td style="padding: 4px 0; font-family: monospace;">${reportId.slice(0, 8)}...</td></tr>
      <tr><td style="padding: 4px 0;"><strong>Issue Type:</strong></td>
          <td style="padding: 4px 0;">${issueLabel}</td></tr>
      <tr><td style="padding: 4px 0;"><strong>Payment ID:</strong></td>
          <td style="padding: 4px 0; font-family: monospace;">${escapeHtml(paymentId)}</td></tr>
    </table>`
}

/**
 * Builds the user email footer section.
 */
function buildUserFooter(): string {
  return `<div style="text-align: center; color: #999; font-size: 12px;">
    <p>Thank you for your patience and for using Disciplefy.</p>
    <p style="margin-top: 20px;">&copy; ${new Date().getFullYear()} Disciplefy. All rights reserved.</p>
  </div>`
}

/**
 * Generates the complete user confirmation email HTML.
 *
 * @param report - User confirmation data with report details
 * @returns Complete HTML email string for user confirmation
 */
function generateUserConfirmationEmailHtml(report: UserConfirmationData): string {
  const safeName = report.userName ? escapeHtml(report.userName.slice(0, 50)) : null
  const greeting = safeName ? `Hi ${safeName}` : 'Hi there'
  const issueLabel = getIssueTypeLabel(report.issueType)

  const header = buildUserHeader()
  const successBox = buildSuccessMessageBox()
  const reportTable = buildUserReportTable(report.reportId, issueLabel, report.paymentId)
  const footer = buildUserFooter()

  return `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Issue Report Received - Disciplefy</title></head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  ${header}
  <div style="background: #f9f9f9; border-radius: 12px; padding: 30px; margin-bottom: 20px;">
    <h2 style="margin-top: 0; color: #333;">${greeting}!</h2>
    <p>We've received your purchase issue report and our team will review it shortly.</p>
    ${successBox}
    ${reportTable}
    <p style="color: #666; margin-top: 20px;">We typically respond within 24-48 hours. If your issue is urgent, please reply to this email.</p>
  </div>
  ${footer}
</body></html>`
}

// ============================================================================
// Request Authentication
// ============================================================================

/**
 * Authenticates the request and returns user with admin client.
 *
 * @param req - The incoming request
 * @param corsHeaders - CORS headers for error responses
 * @returns Auth result with user and admin client, or error response
 */
async function authenticateRequest(
  req: Request,
  corsHeaders: Record<string, string>
): Promise<AuthResult | Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return createErrorResponse('Missing authorization header', 401, corsHeaders)
  }

  const supabaseAdmin = createClient(config.supabaseUrl, config.supabaseServiceKey, {
    auth: { autoRefreshToken: false, persistSession: false }
  })

  const supabaseUser = createClient(config.supabaseUrl, config.supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } }
  })

  const { data: { user }, error: userError } = await supabaseUser.auth.getUser()

  if (userError || !user) {
    console.error('[REPORT ISSUE] Auth error:', userError)
    return createErrorResponse('Unauthorized', 401, corsHeaders)
  }

  return { user, supabaseAdmin }
}

// ============================================================================
// Screenshot Upload Handler
// ============================================================================

/**
 * Validates screenshot file type and size.
 */
function validateScreenshotFile(mimeType: string, fileData: Uint8Array, corsHeaders: Record<string, string>): Response | null {
  const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp']
  if (!allowedMimeTypes.includes(mimeType)) {
    return createErrorResponse('Invalid file type. Only JPEG, PNG, and WebP are allowed.', 400, corsHeaders)
  }
  if (fileData.length > 5 * 1024 * 1024) {
    return createErrorResponse('File too large. Maximum size is 5MB.', 400, corsHeaders)
  }
  return null
}

/**
 * Uploads screenshot to storage and returns signed URL.
 */
async function uploadScreenshotToStorage(
  supabaseAdmin: SupabaseClient,
  userId: string,
  fileName: string,
  fileData: Uint8Array,
  mimeType: string
): Promise<{ url?: string; error?: string }> {
  const timestamp = Date.now()
  const sanitizedFileName = fileName.replace(/[^a-zA-Z0-9.-]/g, '_')
  const filePath = `${userId}/${timestamp}_${sanitizedFileName}`

  const { error: uploadError } = await supabaseAdmin.storage
    .from('issue-screenshots')
    .upload(filePath, fileData, { contentType: mimeType, upsert: false })

  if (uploadError) {
    console.error('[REPORT ISSUE] Upload error:', uploadError)
    return { error: 'Failed to upload screenshot' }
  }

  const { data: urlData } = await supabaseAdmin.storage
    .from('issue-screenshots')
    .createSignedUrl(filePath, 60 * 60 * 24 * 365)

  console.log(`[REPORT ISSUE] Screenshot uploaded: ${filePath}`)
  return { url: urlData?.signedUrl || filePath }
}

/**
 * Handles screenshot upload action.
 *
 * @param body - Upload request body
 * @param user - Authenticated user
 * @param supabaseAdmin - Admin Supabase client
 * @param corsHeaders - CORS headers
 * @returns Response with upload result
 */
async function handleScreenshotUpload(
  body: UploadScreenshotRequest,
  user: User,
  supabaseAdmin: SupabaseClient,
  corsHeaders: Record<string, string>
): Promise<Response> {
  const { fileName, fileBase64, mimeType } = body

  let fileData: Uint8Array
  try {
    fileData = Uint8Array.from(atob(fileBase64), c => c.charCodeAt(0))
  } catch {
    return createErrorResponse('Invalid file data. Not valid base64.', 400, corsHeaders)
  }

  const validationError = validateScreenshotFile(mimeType, fileData, corsHeaders)
  if (validationError) return validationError

  const result = await uploadScreenshotToStorage(supabaseAdmin, user.id, fileName, fileData, mimeType)
  if (result.error) return createErrorResponse(result.error, 500, corsHeaders)

  return createSuccessResponse({ message: 'Screenshot uploaded successfully', url: result.url }, corsHeaders)
}

// ============================================================================
// Report Submission Handler
// ============================================================================

/**
 * Validates report submission fields.
 */
function validateReportFields(data: SubmitReportRequest, corsHeaders: Record<string, string>): Response | null {
  if (!data.purchaseId || !data.paymentId || !data.orderId) {
    return createErrorResponse('Missing required transaction details', 400, corsHeaders)
  }
  if (!data.issueType || !data.description) {
    return createErrorResponse('Missing issue type or description', 400, corsHeaders)
  }
  if (data.description.trim().length < 10) {
    return createErrorResponse('Please provide a more detailed description (at least 10 characters)', 400, corsHeaders)
  }
  if (data.description.length > 2000) {
    return createErrorResponse('Description is too long (maximum 2000 characters)', 400, corsHeaders)
  }
  return null
}

/**
 * Inserts report into database.
 */
async function insertReport(
  supabaseAdmin: SupabaseClient,
  userId: string,
  userEmail: string,
  data: SubmitReportRequest,
  sanitizedDescription: string,
  screenshotUrls: string[]
): Promise<{ reportId?: string; error?: string }> {
  const { data: report, error: insertError } = await supabaseAdmin
    .from('purchase_issue_reports')
    .insert({
      user_id: userId,
      user_email: userEmail,
      purchase_id: data.purchaseId,
      payment_id: data.paymentId,
      order_id: data.orderId,
      token_amount: data.tokenAmount,
      cost_rupees: data.costRupees,
      purchased_at: data.purchasedAt,
      issue_type: data.issueType,
      description: sanitizedDescription,
      screenshot_urls: screenshotUrls,
      status: 'pending'
    })
    .select('id')
    .single()

  if (insertError) {
    console.error('[REPORT ISSUE] Insert error:', insertError)
    return { error: 'Failed to submit report' }
  }

  return { reportId: report.id as string }
}

/**
 * Fetches admin email addresses.
 */
async function fetchAdminEmails(supabaseAdmin: SupabaseClient): Promise<string[]> {
  const { data: admins, error: adminsError } = await supabaseAdmin
    .from('user_profiles')
    .select('id')
    .eq('is_admin', true)

  if (adminsError) {
    console.error('[REPORT ISSUE] Failed to fetch admins:', adminsError)
    return []
  }

  const adminIds = admins?.map(a => a.id) || []
  if (adminIds.length === 0) return []

  const { data: adminUsers } = await supabaseAdmin.auth.admin.listUsers()
  return adminUsers?.users
    ?.filter(u => adminIds.includes(u.id) && u.email)
    ?.map(u => u.email!) || []
}

/**
 * Sends admin and user notification emails.
 */
async function sendNotificationEmails(
  adminEmails: string[],
  userEmail: string,
  userName: string | undefined,
  reportData: SubmitReportRequest,
  sanitizedDescription: string,
  screenshotCount: number,
  reportId: string
): Promise<void> {
  if (adminEmails.length > 0) {
    const adminHtml = generateAdminEmailHtml({
      userEmail,
      issueType: reportData.issueType,
      description: sanitizedDescription,
      paymentId: reportData.paymentId,
      orderId: reportData.orderId,
      tokenAmount: reportData.tokenAmount,
      costRupees: reportData.costRupees,
      purchasedAt: reportData.purchasedAt,
      screenshotCount,
      reportId
    })
    await sendEmailWithResend(
      adminEmails,
      `[Disciplefy] Purchase Issue Report: ${getIssueTypeLabel(reportData.issueType)}`,
      adminHtml
    )
  }

  const userHtml = generateUserConfirmationEmailHtml({
    userName,
    issueType: reportData.issueType,
    paymentId: reportData.paymentId,
    reportId
  })
  await sendEmailWithResend(userEmail, 'We received your purchase issue report - Disciplefy', userHtml)
}

/**
 * Handles report submission action.
 *
 * @param body - Submit report request body
 * @param user - Authenticated user
 * @param supabaseAdmin - Admin Supabase client
 * @param corsHeaders - CORS headers
 * @returns Response with submission result
 */
async function handleReportSubmission(
  body: SubmitReportRequest,
  user: User,
  supabaseAdmin: SupabaseClient,
  corsHeaders: Record<string, string>
): Promise<Response> {
  const validationError = validateReportFields(body, corsHeaders)
  if (validationError) return validationError

  const userEmail = user.email || ''
  if (!userEmail) return createErrorResponse('User email not available', 400, corsHeaders)

  const screenshotUrls = body.screenshotUrls?.slice(0, 3) || []
  const sanitizedDescription = escapeHtml(body.description.trim())

  const { data: profile } = await supabaseAdmin
    .from('user_profiles')
    .select('first_name')
    .eq('id', user.id)
    .single()

  const insertResult = await insertReport(supabaseAdmin, user.id, userEmail, body, sanitizedDescription, screenshotUrls)
  if (insertResult.error) return createErrorResponse(insertResult.error, 500, corsHeaders)

  const reportId = insertResult.reportId!
  console.log(`[REPORT ISSUE] Report created: ${reportId} for user ${user.id}`)

  const adminEmails = await fetchAdminEmails(supabaseAdmin)
  await sendNotificationEmails(adminEmails, userEmail, profile?.first_name, body, sanitizedDescription, screenshotUrls.length, reportId)

  return createSuccessResponse({
    message: 'Report submitted successfully. You will receive a confirmation email shortly.',
    reportId
  }, corsHeaders)
}

// ============================================================================
// Request Handler
// ============================================================================

/**
 * Handles the main request dispatch based on action.
 *
 * @param req - The incoming request
 * @param corsHeaders - CORS headers
 * @returns Response for the request
 */
async function handleRequest(req: Request, corsHeaders: Record<string, string>): Promise<Response> {
  if (req.method !== 'POST') {
    return createErrorResponse('Method not allowed', 405, corsHeaders)
  }

  const authResult = await authenticateRequest(req, corsHeaders)
  if (authResult instanceof Response) return authResult

  const { user, supabaseAdmin } = authResult
  const body: RequestBody = await req.json()

  if (body.action === 'upload_screenshot') {
    return handleScreenshotUpload(body as UploadScreenshotRequest, user, supabaseAdmin, corsHeaders)
  }

  if (body.action === 'submit_report') {
    return handleReportSubmission(body as SubmitReportRequest, user, supabaseAdmin, corsHeaders)
  }

  return createErrorResponse('Invalid action', 400, corsHeaders)
}

// ============================================================================
// Main Handler
// ============================================================================

Deno.serve(async (req) => {
  const corsHeaders = handleCors(req)

  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    return await handleRequest(req, corsHeaders)
  } catch (error) {
    console.error('[REPORT ISSUE] Unexpected error:', error)
    return createErrorResponse('Internal server error', 500, corsHeaders)
  }
})
