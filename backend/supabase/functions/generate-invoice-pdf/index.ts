/**
 * Generate Invoice PDF Edge Function
 *
 * Generates professional PDF invoices for subscription payments
 * Features:
 * - Brand-styled PDF with company logo and colors
 * - Complete billing details (plan, dates, amounts, tax)
 * - Secure (users can only download their own invoices)
 * - Rate limited (10 downloads/minute per user)
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { UserContext } from '../_shared/types/index.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { PDFDocument, rgb, StandardFonts } from 'https://cdn.skypack.dev/pdf-lib@^1.17.1?dts'

// ============================================================================
// Types
// ============================================================================

interface GenerateInvoicePDFRequest {
  invoice_id: string
}

interface InvoiceData {
  id: string
  user_id: string
  subscription_id: string
  invoice_number: string
  invoice_date: string
  amount: number
  currency: string
  tax_amount: number | null
  status: string
  payment_method: string | null
  razorpay_invoice_id: string | null
  billing_period_start: string
  billing_period_end: string
  line_items: Array<{
    description: string
    amount: number
  }> | null
  created_at: string
}

interface UserData {
  id: string
  email: string
  full_name: string | null
}

// ============================================================================
// Configuration
// ============================================================================

const RATE_LIMIT_MAX_REQUESTS = 10 // per minute
const RATE_LIMIT_WINDOW_MS = 60 * 1000 // 1 minute

// Company information (TODO: Move to environment variables)
const COMPANY_INFO = {
  name: 'Disciplefy Bible Study App',
  address: '[Company Address]', // TODO: Add actual address
  gstin: '[GST Number]', // TODO: Add actual GSTIN
  email: 'support@disciplefy.com',
  website: 'https://disciplefy.com',
}

// Brand colors
const PRIMARY_PURPLE = rgb(0.42, 0.31, 0.71) // #6A4FB6
const SUCCESS_GREEN = rgb(0, 0.5, 0)
const ERROR_RED = rgb(0.7, 0, 0)
const TEXT_BLACK = rgb(0, 0, 0)
const TEXT_GRAY = rgb(0.4, 0.4, 0.4)

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Format date to readable string
 */
function formatDate(isoDate: string): string {
  const date = new Date(isoDate)
  return date.toLocaleDateString('en-IN', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
}

/**
 * Get plan name from subscription tier
 */
function getPlanDisplayName(tier: string): string {
  const planNames: Record<string, string> = {
    free: 'Free Plan',
    standard: 'Standard Plan (₹79/month)',
    plus: 'Plus Plan (₹149/month)',
    premium: 'Premium Plan (₹499/month)',
  }
  return planNames[tier] || 'Subscription Plan'
}

/**
 * Check rate limit for user
 */
async function checkRateLimit(
  services: ServiceContainer,
  userId: string
): Promise<void> {
  const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_MS).toISOString()

  // Count recent PDF generation requests
  const { count, error } = await services.supabaseServiceClient
    .from('usage_logs')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('feature_name', 'invoice_pdf_generation')
    .gte('created_at', windowStart)

  if (error) {
    console.error('[InvoicePDF] Rate limit check failed:', error)
    // Fail-open: allow request if rate limit check fails
    return
  }

  if (count !== null && count >= RATE_LIMIT_MAX_REQUESTS) {
    throw new AppError(
      'RATE_LIMIT_EXCEEDED',
      `Too many PDF download requests. Please wait a minute and try again. (${count}/${RATE_LIMIT_MAX_REQUESTS})`,
      429
    )
  }
}

/**
 * Fetch invoice data from database
 */
async function fetchInvoiceData(
  services: ServiceContainer,
  invoiceId: string,
  userId: string
): Promise<InvoiceData> {
  const { data: invoice, error } = await services.supabaseServiceClient
    .from('subscription_invoices')
    .select('*')
    .eq('id', invoiceId)
    .single()

  if (error || !invoice) {
    throw new AppError(
      'INVOICE_NOT_FOUND',
      'Invoice not found or access denied',
      404
    )
  }

  // Verify user owns this invoice
  if (invoice.user_id !== userId) {
    throw new AppError(
      'UNAUTHORIZED',
      'You do not have permission to access this invoice',
      403
    )
  }

  return invoice as InvoiceData
}

/**
 * Fetch user data from database
 */
async function fetchUserData(
  services: ServiceContainer,
  userId: string
): Promise<UserData> {
  const { data: user, error } = await services.supabaseServiceClient
    .from('user_profiles')
    .select('id, email, full_name')
    .eq('id', userId)
    .single()

  if (error || !user) {
    // Fallback: try auth.users table
    const { data: authUser } = await services.supabaseServiceClient.auth.admin.getUserById(
      userId
    )

    if (authUser?.user) {
      return {
        id: authUser.user.id,
        email: authUser.user.email || 'No email',
        full_name: authUser.user.user_metadata?.full_name || null,
      }
    }

    throw new AppError('USER_NOT_FOUND', 'User not found', 404)
  }

  return user as UserData
}

/**
 * Generate PDF document
 */
async function generateInvoicePDF(
  invoiceData: InvoiceData,
  userData: UserData,
  planName: string
): Promise<Uint8Array> {
  const pdfDoc = await PDFDocument.create()
  const page = pdfDoc.addPage([595, 842]) // A4 size (portrait)
  const font = await pdfDoc.embedFont(StandardFonts.Helvetica)
  const boldFont = await pdfDoc.embedFont(StandardFonts.HelveticaBold)

  const { width, height } = page.getSize()
  const margin = 50
  let yPosition = height - 50

  // ===== HEADER: "INVOICE" Title =====
  page.drawText('INVOICE', {
    x: width - 200,
    y: yPosition,
    size: 28,
    font: boldFont,
    color: PRIMARY_PURPLE,
  })

  // Company name (left side)
  page.drawText(COMPANY_INFO.name, {
    x: margin,
    y: yPosition,
    size: 14,
    font: boldFont,
    color: TEXT_BLACK,
  })

  yPosition -= 40

  // ===== Invoice Metadata =====
  page.drawText(`Invoice #: ${invoiceData.invoice_number}`, {
    x: margin,
    y: yPosition,
    size: 12,
    font: font,
    color: TEXT_BLACK,
  })

  yPosition -= 20

  page.drawText(`Date: ${formatDate(invoiceData.invoice_date)}`, {
    x: margin,
    y: yPosition,
    size: 12,
    font: font,
    color: TEXT_BLACK,
  })

  yPosition -= 20

  // Status with color coding
  const statusColor =
    invoiceData.status === 'paid'
      ? SUCCESS_GREEN
      : invoiceData.status === 'failed'
      ? ERROR_RED
      : TEXT_GRAY

  page.drawText(`Status: ${invoiceData.status.toUpperCase()}`, {
    x: margin,
    y: yPosition,
    size: 12,
    font: boldFont,
    color: statusColor,
  })

  yPosition -= 40

  // ===== Horizontal Line =====
  page.drawLine({
    start: { x: margin, y: yPosition },
    end: { x: width - margin, y: yPosition },
    thickness: 1,
    color: TEXT_GRAY,
  })

  yPosition -= 30

  // ===== BILL TO Section =====
  page.drawText('BILL TO:', {
    x: margin,
    y: yPosition,
    size: 14,
    font: boldFont,
    color: TEXT_BLACK,
  })

  yPosition -= 20

  page.drawText(userData.full_name || 'User', {
    x: margin,
    y: yPosition,
    size: 12,
    font: font,
    color: TEXT_BLACK,
  })

  yPosition -= 18

  page.drawText(userData.email, {
    x: margin,
    y: yPosition,
    size: 11,
    font: font,
    color: TEXT_GRAY,
  })

  yPosition -= 18

  page.drawText(`User ID: ${userData.id.substring(0, 16)}...`, {
    x: margin,
    y: yPosition,
    size: 10,
    font: font,
    color: TEXT_GRAY,
  })

  yPosition -= 35

  // ===== Horizontal Line =====
  page.drawLine({
    start: { x: margin, y: yPosition },
    end: { x: width - margin, y: yPosition },
    thickness: 1,
    color: TEXT_GRAY,
  })

  yPosition -= 30

  // ===== SUBSCRIPTION DETAILS =====
  page.drawText('SUBSCRIPTION DETAILS', {
    x: margin,
    y: yPosition,
    size: 14,
    font: boldFont,
    color: TEXT_BLACK,
  })

  yPosition -= 20

  page.drawText(`Plan: ${planName}`, {
    x: margin,
    y: yPosition,
    size: 12,
    font: font,
    color: TEXT_BLACK,
  })

  yPosition -= 18

  page.drawText(
    `Billing Period: ${formatDate(invoiceData.billing_period_start)} - ${formatDate(
      invoiceData.billing_period_end
    )}`,
    {
      x: margin,
      y: yPosition,
      size: 11,
      font: font,
      color: TEXT_GRAY,
    }
  )

  yPosition -= 35

  // ===== Horizontal Line =====
  page.drawLine({
    start: { x: margin, y: yPosition },
    end: { x: width - margin, y: yPosition },
    thickness: 1,
    color: TEXT_GRAY,
  })

  yPosition -= 30

  // ===== LINE ITEMS Table =====
  page.drawText('LINE ITEMS', {
    x: margin,
    y: yPosition,
    size: 14,
    font: boldFont,
    color: TEXT_BLACK,
  })

  page.drawText('AMOUNT', {
    x: width - 150,
    y: yPosition,
    size: 14,
    font: boldFont,
    color: TEXT_BLACK,
  })

  yPosition -= 25

  // Parse line items
  const lineItems = invoiceData.line_items || [
    { description: `${planName} Subscription`, amount: invoiceData.amount },
  ]

  lineItems.forEach((item) => {
    page.drawText(item.description, {
      x: margin,
      y: yPosition,
      size: 12,
      font: font,
      color: TEXT_BLACK,
    })

    page.drawText(`₹${item.amount.toFixed(2)}`, {
      x: width - 150,
      y: yPosition,
      size: 12,
      font: font,
      color: TEXT_BLACK,
    })

    yPosition -= 22
  })

  // Tax line (if applicable)
  if (invoiceData.tax_amount && invoiceData.tax_amount > 0) {
    page.drawText('Tax (18% GST)', {
      x: margin,
      y: yPosition,
      size: 12,
      font: font,
      color: TEXT_GRAY,
    })

    page.drawText(`₹${invoiceData.tax_amount.toFixed(2)}`, {
      x: width - 150,
      y: yPosition,
      size: 12,
      font: font,
      color: TEXT_GRAY,
    })

    yPosition -= 30
  }

  // ===== Horizontal Line =====
  page.drawLine({
    start: { x: margin, y: yPosition },
    end: { x: width - margin, y: yPosition },
    thickness: 2,
    color: PRIMARY_PURPLE,
  })

  yPosition -= 25

  // ===== TOTAL =====
  page.drawText('TOTAL', {
    x: margin,
    y: yPosition,
    size: 16,
    font: boldFont,
    color: TEXT_BLACK,
  })

  page.drawText(`₹${invoiceData.amount.toFixed(2)}`, {
    x: width - 150,
    y: yPosition,
    size: 18,
    font: boldFont,
    color: PRIMARY_PURPLE,
  })

  yPosition -= 40

  // ===== Horizontal Line =====
  page.drawLine({
    start: { x: margin, y: yPosition },
    end: { x: width - margin, y: yPosition },
    thickness: 1,
    color: TEXT_GRAY,
  })

  yPosition -= 30

  // ===== PAYMENT DETAILS =====
  page.drawText('PAYMENT DETAILS', {
    x: margin,
    y: yPosition,
    size: 14,
    font: boldFont,
    color: TEXT_BLACK,
  })

  yPosition -= 20

  page.drawText(`Method: ${invoiceData.payment_method || 'Razorpay'}`, {
    x: margin,
    y: yPosition,
    size: 12,
    font: font,
    color: TEXT_BLACK,
  })

  yPosition -= 18

  if (invoiceData.razorpay_invoice_id) {
    page.drawText(`Transaction ID: ${invoiceData.razorpay_invoice_id}`, {
      x: margin,
      y: yPosition,
      size: 11,
      font: font,
      color: TEXT_GRAY,
    })
    yPosition -= 18
  }

  page.drawText(`Payment Date: ${formatDate(invoiceData.invoice_date)}`, {
    x: margin,
    y: yPosition,
    size: 11,
    font: font,
    color: TEXT_GRAY,
  })

  yPosition -= 18

  const paymentStatusText =
    invoiceData.status === 'paid' ? 'Successful' : 'Pending'
  const paymentStatusColor = invoiceData.status === 'paid' ? SUCCESS_GREEN : TEXT_GRAY

  page.drawText(`Status: ${paymentStatusText}`, {
    x: margin,
    y: yPosition,
    size: 11,
    font: font,
    color: paymentStatusColor,
  })

  // ===== FOOTER: Company Information =====
  const footerY = 100

  page.drawText(COMPANY_INFO.name, {
    x: margin,
    y: footerY,
    size: 12,
    font: boldFont,
    color: TEXT_BLACK,
  })

  page.drawText(COMPANY_INFO.address, {
    x: margin,
    y: footerY - 18,
    size: 10,
    font: font,
    color: TEXT_GRAY,
  })

  page.drawText(`GSTIN: ${COMPANY_INFO.gstin}`, {
    x: margin,
    y: footerY - 33,
    size: 10,
    font: font,
    color: TEXT_GRAY,
  })

  page.drawText(`Email: ${COMPANY_INFO.email} | Website: ${COMPANY_INFO.website}`, {
    x: margin,
    y: footerY - 48,
    size: 9,
    font: font,
    color: TEXT_GRAY,
  })

  page.drawText('Thank you for your subscription!', {
    x: margin,
    y: footerY - 70,
    size: 12,
    font: font,
    color: PRIMARY_PURPLE,
  })

  // Generate PDF bytes
  const pdfBytes = await pdfDoc.save()
  return pdfBytes
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleGenerateInvoicePDF(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  const startTime = Date.now()

  // Require authentication
  if (!userContext || userContext.type !== 'authenticated') {
    throw new AppError('UNAUTHORIZED', 'Authentication required', 401)
  }

  const userId = userContext.userId!

  // Parse request body
  const body: GenerateInvoicePDFRequest = await req.json()

  if (!body.invoice_id || typeof body.invoice_id !== 'string') {
    throw new AppError(
      'INVALID_REQUEST',
      'Missing or invalid invoice_id in request body',
      400
    )
  }

  const { invoice_id } = body

  // Validate UUID format
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  if (!uuidRegex.test(invoice_id)) {
    throw new AppError(
      'INVALID_REQUEST',
      'Invalid invoice_id format (must be UUID)',
      400
    )
  }

  // Check rate limit
  await checkRateLimit(services, userId)

  // Fetch invoice data (with ownership verification)
  const invoiceData = await fetchInvoiceData(services, invoice_id, userId)

  // Fetch user data
  const userData = await fetchUserData(services, userId)

  // Determine plan name from subscription
  let planName = 'Subscription Plan'
  try {
    const { data: subscription } = await services.supabaseServiceClient
      .from('subscriptions')
      .select('tier')
      .eq('id', invoiceData.subscription_id)
      .single()

    if (subscription?.tier) {
      planName = getPlanDisplayName(subscription.tier)
    }
  } catch (error) {
    console.error('[InvoicePDF] Failed to fetch subscription tier:', error)
    // Continue with default plan name
  }

  // Generate PDF
  const pdfBytes = await generateInvoicePDF(invoiceData, userData, planName)

  const latencyMs = Date.now() - startTime

  // Log usage for analytics
  try {
    await services.usageLoggingService.logUsage({
      userId,
      tier: await services.authService.getUserPlan(req),
      featureName: 'invoice_pdf_generation',
      operationType: 'read',
      tokensConsumed: 0,
      llmProvider: null,
      llmModel: null,
      llmInputTokens: null,
      llmOutputTokens: null,
      llmCostUsd: null,
      requestMetadata: {
        invoice_id,
        invoice_number: invoiceData.invoice_number,
        invoice_amount: invoiceData.amount,
      },
      responseMetadata: {
        success: true,
        latency_ms: latencyMs,
        pdf_size_bytes: pdfBytes.length,
      },
    })
  } catch (usageLogError) {
    console.error('[InvoicePDF] Usage logging failed:', usageLogError)
    // Don't fail request if logging fails
  }

  // Return PDF with proper headers
  return new Response(pdfBytes, {
    status: 200,
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="Invoice_${invoiceData.invoice_number}.pdf"`,
      'Content-Length': pdfBytes.length.toString(),
    },
  })
}

// ============================================================================
// Create Function with Factory
// ============================================================================

createAuthenticatedFunction(handleGenerateInvoicePDF, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 15000, // 15 seconds
})
