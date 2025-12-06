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

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
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

// ============================================================================
// Helper Functions
// ============================================================================

function createSuccessResponse(data: Record<string, unknown>, corsHeaders: Record<string, string>): Response {
  return new Response(
    JSON.stringify({ success: true, ...data }),
    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

function createErrorResponse(message: string, status: number, corsHeaders: Record<string, string>): Response {
  return new Response(
    JSON.stringify({ success: false, error: message }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

function escapeHtml(unsafe: string): string {
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')
    .replace(/\//g, '&#x2F;')
}

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

// ============================================================================
// Email Functions
// ============================================================================

async function sendEmailWithResend(
  to: string | string[],
  subject: string,
  htmlContent: string
): Promise<{ success: boolean; error?: string }> {
  const resendApiKey = Deno.env.get('RESEND_API_KEY')
  
  if (!resendApiKey) {
    console.log('[REPORT ISSUE] RESEND_API_KEY not configured - LOCAL DEV MODE')
    console.log('[REPORT ISSUE] Email would be sent to:', to)
    console.log('[REPORT ISSUE] Subject:', subject)
    return { success: true }
  }

  try {
    const recipients = Array.isArray(to) ? to : [to]
    
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
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
  } catch (error) {
    console.error('[REPORT ISSUE] Error sending email:', error)
    return { success: false, error: 'Failed to send email' }
  }
}

function generateAdminEmailHtml(report: {
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
}): string {
  const safeDescription = escapeHtml(report.description).slice(0, 1000)
  const issueLabel = getIssueTypeLabel(report.issueType)
  const purchaseDate = new Date(report.purchasedAt).toLocaleString('en-IN', {
    timeZone: 'Asia/Kolkata',
    dateStyle: 'medium',
    timeStyle: 'short'
  })

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>New Purchase Issue Report - Disciplefy</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="text-align: center; margin-bottom: 30px;">
    <h1 style="color: #DC2626; margin: 0;">⚠️ Purchase Issue Report</h1>
    <p style="color: #666; margin-top: 5px;">Disciplefy Admin Notification</p>
  </div>
  
  <div style="background: #FEF2F2; border: 1px solid #FECACA; border-radius: 12px; padding: 20px; margin-bottom: 20px;">
    <h2 style="margin-top: 0; color: #DC2626; font-size: 18px;">Issue Type: ${issueLabel}</h2>
    <p style="margin-bottom: 0;"><strong>Report ID:</strong> ${report.reportId}</p>
  </div>

  <div style="background: #f9f9f9; border-radius: 12px; padding: 20px; margin-bottom: 20px;">
    <h3 style="margin-top: 0; color: #333;">User Details</h3>
    <p><strong>Email:</strong> ${escapeHtml(report.userEmail)}</p>
    
    <h3 style="color: #333;">Transaction Details</h3>
    <table style="width: 100%; border-collapse: collapse;">
      <tr>
        <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Payment ID:</strong></td>
        <td style="padding: 8px 0; border-bottom: 1px solid #eee; font-family: monospace;">${escapeHtml(report.paymentId)}</td>
      </tr>
      <tr>
        <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Order ID:</strong></td>
        <td style="padding: 8px 0; border-bottom: 1px solid #eee; font-family: monospace;">${escapeHtml(report.orderId)}</td>
      </tr>
      <tr>
        <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Tokens:</strong></td>
        <td style="padding: 8px 0; border-bottom: 1px solid #eee;">${report.tokenAmount}</td>
      </tr>
      <tr>
        <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>Amount:</strong></td>
        <td style="padding: 8px 0; border-bottom: 1px solid #eee;">₹${report.costRupees.toFixed(2)}</td>
      </tr>
      <tr>
        <td style="padding: 8px 0;"><strong>Purchase Date:</strong></td>
        <td style="padding: 8px 0;">${purchaseDate}</td>
      </tr>
    </table>
    
    <h3 style="color: #333;">Issue Description</h3>
    <div style="background: white; border: 1px solid #ddd; border-radius: 8px; padding: 16px;">
      <p style="margin: 0; white-space: pre-wrap;">${safeDescription}</p>
    </div>
    
    ${report.screenshotCount > 0 ? `
    <p style="margin-top: 16px; color: #666;">
      <strong>📎 Attachments:</strong> ${report.screenshotCount} screenshot(s) uploaded
    </p>
    ` : ''}
  </div>
  
  <div style="text-align: center; color: #999; font-size: 12px;">
    <p>Please review this issue in the Disciplefy Admin Panel.</p>
    <p style="margin-top: 20px;">&copy; ${new Date().getFullYear()} Disciplefy. All rights reserved.</p>
  </div>
</body>
</html>
`
}

function generateUserConfirmationEmailHtml(report: {
  userName?: string
  issueType: string
  paymentId: string
  reportId: string
}): string {
  const safeName = report.userName ? escapeHtml(report.userName.slice(0, 50)) : null
  const greeting = safeName ? `Hi ${safeName}` : 'Hi there'
  const issueLabel = getIssueTypeLabel(report.issueType)

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Issue Report Received - Disciplefy</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="text-align: center; margin-bottom: 30px;">
    <h1 style="color: #6A4FB6; margin: 0;">Disciplefy</h1>
    <p style="color: #666; margin-top: 5px;">Your Bible Study Companion</p>
  </div>
  
  <div style="background: #f9f9f9; border-radius: 12px; padding: 30px; margin-bottom: 20px;">
    <h2 style="margin-top: 0; color: #333;">${greeting}!</h2>
    <p>We've received your purchase issue report and our team will review it shortly.</p>
    
    <div style="background: #E8F5E9; border-radius: 8px; padding: 16px; margin: 20px 0;">
      <p style="margin: 0; color: #2E7D32;">
        <strong>✓ Report Submitted Successfully</strong>
      </p>
    </div>
    
    <h3 style="color: #333;">Report Details</h3>
    <table style="width: 100%;">
      <tr>
        <td style="padding: 4px 0;"><strong>Report ID:</strong></td>
        <td style="padding: 4px 0; font-family: monospace;">${report.reportId.slice(0, 8)}...</td>
      </tr>
      <tr>
        <td style="padding: 4px 0;"><strong>Issue Type:</strong></td>
        <td style="padding: 4px 0;">${issueLabel}</td>
      </tr>
      <tr>
        <td style="padding: 4px 0;"><strong>Payment ID:</strong></td>
        <td style="padding: 4px 0; font-family: monospace;">${escapeHtml(report.paymentId)}</td>
      </tr>
    </table>
    
    <p style="color: #666; margin-top: 20px;">
      We typically respond within 24-48 hours. If your issue is urgent, please reply to this email.
    </p>
  </div>
  
  <div style="text-align: center; color: #999; font-size: 12px;">
    <p>Thank you for your patience and for using Disciplefy.</p>
    <p style="margin-top: 20px;">&copy; ${new Date().getFullYear()} Disciplefy. All rights reserved.</p>
  </div>
</body>
</html>
`
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
    if (req.method !== 'POST') {
      return createErrorResponse('Method not allowed', 405, corsHeaders)
    }

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return createErrorResponse('Missing authorization header', 401, corsHeaders)
    }

    // Create Supabase clients
    const supabaseAdmin = createClient(
      config.supabaseUrl,
      config.supabaseServiceKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    const supabaseUser = createClient(
      config.supabaseUrl,
      config.supabaseAnonKey,
      {
        global: {
          headers: { Authorization: authHeader }
        }
      }
    )

    // Get current user
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()
    
    if (userError || !user) {
      console.error('[REPORT ISSUE] Auth error:', userError)
      return createErrorResponse('Unauthorized', 401, corsHeaders)
    }

    const body: RequestBody = await req.json()

    // ========================================================================
    // Action: Upload Screenshot
    // ========================================================================
    if (body.action === 'upload_screenshot') {
      const { fileName, fileBase64, mimeType } = body as UploadScreenshotRequest

      // Validate mime type
      const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp']
      if (!allowedMimeTypes.includes(mimeType)) {
        return createErrorResponse('Invalid file type. Only JPEG, PNG, and WebP are allowed.', 400, corsHeaders)
      }

      // Decode base64
      const fileData = Uint8Array.from(atob(fileBase64), c => c.charCodeAt(0))
      
      // Check file size (5MB max)
      if (fileData.length > 5 * 1024 * 1024) {
        return createErrorResponse('File too large. Maximum size is 5MB.', 400, corsHeaders)
      }

      // Generate unique file path
      const timestamp = Date.now()
      const sanitizedFileName = fileName.replace(/[^a-zA-Z0-9.-]/g, '_')
      const filePath = `${user.id}/${timestamp}_${sanitizedFileName}`

      // Upload to storage
      const { error: uploadError } = await supabaseAdmin.storage
        .from('issue-screenshots')
        .upload(filePath, fileData, {
          contentType: mimeType,
          upsert: false
        })

      if (uploadError) {
        console.error('[REPORT ISSUE] Upload error:', uploadError)
        return createErrorResponse('Failed to upload screenshot', 500, corsHeaders)
      }

      // Get public URL (signed URL for private bucket)
      const { data: urlData } = await supabaseAdmin.storage
        .from('issue-screenshots')
        .createSignedUrl(filePath, 60 * 60 * 24 * 365) // 1 year expiry

      console.log(`[REPORT ISSUE] Screenshot uploaded: ${filePath}`)

      return createSuccessResponse({
        message: 'Screenshot uploaded successfully',
        url: urlData?.signedUrl || filePath
      }, corsHeaders)
    }

    // ========================================================================
    // Action: Submit Report
    // ========================================================================
    if (body.action === 'submit_report') {
      const reportData = body as SubmitReportRequest

      // Validate required fields
      if (!reportData.purchaseId || !reportData.paymentId || !reportData.orderId) {
        return createErrorResponse('Missing required transaction details', 400, corsHeaders)
      }

      if (!reportData.issueType || !reportData.description) {
        return createErrorResponse('Missing issue type or description', 400, corsHeaders)
      }

      // Validate description length
      if (reportData.description.trim().length < 10) {
        return createErrorResponse('Please provide a more detailed description (at least 10 characters)', 400, corsHeaders)
      }

      if (reportData.description.length > 2000) {
        return createErrorResponse('Description is too long (maximum 2000 characters)', 400, corsHeaders)
      }

      // Validate screenshot URLs (max 3)
      const screenshotUrls = reportData.screenshotUrls?.slice(0, 3) || []

      // Get user email
      const userEmail = user.email || ''
      if (!userEmail) {
        return createErrorResponse('User email not available', 400, corsHeaders)
      }

      // Get user profile for name
      const { data: profile } = await supabaseAdmin
        .from('user_profiles')
        .select('first_name')
        .eq('id', user.id)
        .single()

      // Insert report into database
      const { data: report, error: insertError } = await supabaseAdmin
        .from('purchase_issue_reports')
        .insert({
          user_id: user.id,
          user_email: userEmail,
          purchase_id: reportData.purchaseId,
          payment_id: reportData.paymentId,
          order_id: reportData.orderId,
          token_amount: reportData.tokenAmount,
          cost_rupees: reportData.costRupees,
          purchased_at: reportData.purchasedAt,
          issue_type: reportData.issueType,
          description: reportData.description.trim(),
          screenshot_urls: screenshotUrls,
          status: 'pending'
        })
        .select('id')
        .single()

      if (insertError) {
        console.error('[REPORT ISSUE] Insert error:', insertError)
        return createErrorResponse('Failed to submit report', 500, corsHeaders)
      }

      const reportId = report.id as string
      console.log(`[REPORT ISSUE] Report created: ${reportId} for user ${user.id}`)

      // Get admin emails
      const { data: admins, error: adminsError } = await supabaseAdmin
        .from('user_profiles')
        .select('id')
        .eq('is_admin', true)

      if (adminsError) {
        console.error('[REPORT ISSUE] Failed to fetch admins:', adminsError)
      }

      const adminIds = admins?.map(a => a.id) || []
      
      // Get admin emails from auth.users
      let adminEmails: string[] = []
      if (adminIds.length > 0) {
        const { data: adminUsers } = await supabaseAdmin.auth.admin.listUsers()
        adminEmails = adminUsers?.users
          ?.filter(u => adminIds.includes(u.id) && u.email)
          ?.map(u => u.email!) || []
      }

      // Send admin notification email
      if (adminEmails.length > 0) {
        const adminHtml = generateAdminEmailHtml({
          userEmail,
          issueType: reportData.issueType,
          description: reportData.description,
          paymentId: reportData.paymentId,
          orderId: reportData.orderId,
          tokenAmount: reportData.tokenAmount,
          costRupees: reportData.costRupees,
          purchasedAt: reportData.purchasedAt,
          screenshotCount: screenshotUrls.length,
          reportId
        })

        await sendEmailWithResend(
          adminEmails,
          `[Disciplefy] Purchase Issue Report: ${getIssueTypeLabel(reportData.issueType)}`,
          adminHtml
        )
      }

      // Send user confirmation email
      const userHtml = generateUserConfirmationEmailHtml({
        userName: profile?.first_name,
        issueType: reportData.issueType,
        paymentId: reportData.paymentId,
        reportId
      })

      await sendEmailWithResend(
        userEmail,
        'We received your purchase issue report - Disciplefy',
        userHtml
      )

      return createSuccessResponse({
        message: 'Report submitted successfully. You will receive a confirmation email shortly.',
        reportId
      }, corsHeaders)
    }

    return createErrorResponse('Invalid action', 400, corsHeaders)

  } catch (error) {
    console.error('[REPORT ISSUE] Unexpected error:', error)
    return createErrorResponse('Internal server error', 500, corsHeaders)
  }
})
