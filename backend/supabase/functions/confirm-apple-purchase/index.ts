/**
 * Confirm Apple Consumable Purchase Edge Function
 *
 * Verifies a StoreKit 2 consumable transaction (token pack or developer tip)
 * against Apple's App Store Server API and fulfils it:
 *  - kind 'tokens': credits the purchased token pack to the user
 *  - kind 'tip':    records the tip (no fulfilment beyond a thank-you)
 *
 * Idempotent by store transaction_id — safe for StoreKit's redelivery of
 * unfinished transactions on every app launch.
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { validateAppleReceipt } from '../_shared/services/apple-appstore-validator.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'
import type { UserContext } from '../_shared/types/index.ts'

const TOKEN_PRODUCT_PREFIX = 'com.disciplefy.tokens_'
const TIP_PRODUCT_PREFIX = 'com.disciplefy.tip_'
const MAX_TOKENS_PER_PURCHASE = 10000 // mirrors pending_token_purchases CHECK

interface ConfirmApplePurchaseRequest {
  receipt: string // StoreKit 2 compact JWS transaction
  product_id: string
  kind: 'tokens' | 'tip'
}

async function handleConfirmApplePurchase(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const userContext: UserContext = await services.authService.getUserContext(req)
  if (!userContext.userId || userContext.type !== 'authenticated') {
    throw new AppError('UNAUTHORIZED', 'Sign in required to complete a purchase', 401)
  }
  const userId = userContext.userId

  const body = (await req.json()) as ConfirmApplePurchaseRequest
  const { receipt, product_id: productId, kind } = body

  if (!receipt || typeof receipt !== 'string') {
    throw new AppError('VALIDATION_ERROR', 'receipt (StoreKit 2 JWS) is required', 400)
  }
  if (kind !== 'tokens' && kind !== 'tip') {
    throw new AppError('VALIDATION_ERROR', "kind must be 'tokens' or 'tip'", 400)
  }
  const expectedPrefix = kind === 'tokens' ? TOKEN_PRODUCT_PREFIX : TIP_PRODUCT_PREFIX
  if (!productId?.startsWith(expectedPrefix)) {
    throw new AppError('VALIDATION_ERROR', `product_id must start with ${expectedPrefix}`, 400)
  }

  const supabase = services.supabaseServiceClient
  const environment = Deno.env.get('APP_ENVIRONMENT') === 'sandbox' ? 'sandbox' : 'production'

  console.log(`[APPLE_CONSUMABLE] Confirming ${kind} purchase of ${productId} for user ${userId}`)

  const validation = await validateAppleReceipt(supabase, { receiptData: receipt }, environment)
  if (!validation.isValid) {
    throw new AppError('RECEIPT_INVALID', validation.error ?? 'Apple transaction could not be verified', 400)
  }

  // The store-confirmed product must match what the client claims to have bought.
  if (validation.validatedProductId && validation.validatedProductId !== productId) {
    throw new AppError(
      'PRODUCT_MISMATCH',
      `Transaction is for '${validation.validatedProductId}', not '${productId}'`,
      400
    )
  }

  // Idempotency + cross-user guard on the store transaction id.
  const { data: existing } = await supabase
    .from('iap_receipts')
    .select('id, user_id, validation_status')
    .eq('transaction_id', validation.transactionId)
    .maybeSingle()

  if (existing && existing.user_id !== userId) {
    throw new AppError('RECEIPT_ALREADY_CLAIMED', 'This purchase belongs to a different account', 400)
  }
  if (existing && existing.validation_status === 'valid') {
    // Already fulfilled (StoreKit redelivery) — succeed without double-crediting.
    console.log(`[APPLE_CONSUMABLE] Transaction ${validation.transactionId} already fulfilled — idempotent success`)
    return successResponse(kind, 0, true)
  }

  let tokensCredited = 0
  if (kind === 'tokens') {
    tokensCredited = parseTokenCount(productId)
    await creditTokenPack(services, userId, tokensCredited, validation, supabase)
  }

  // Record the receipt only after fulfilment so a crash before crediting keeps
  // validation_status unset and the next redelivery retries the credit.
  const { error: receiptError } = await supabase
    .from('iap_receipts')
    .upsert({
      user_id: userId,
      provider: 'apple_appstore',
      receipt_data: receipt,
      product_id: productId,
      transaction_id: validation.transactionId,
      validation_status: 'valid',
      validation_response: validation.validationResponse,
      validated_at: new Date().toISOString(),
      purchase_date: validation.purchaseDate.toISOString(),
      environment,
    }, { onConflict: 'transaction_id' })

  if (receiptError) {
    // Tokens are already credited; log loudly but don't fail the purchase.
    console.error('[APPLE_CONSUMABLE] Failed to store receipt after fulfilment:', receiptError)
  }

  console.log(`[APPLE_CONSUMABLE] ✅ ${kind} purchase fulfilled — tx ${validation.transactionId}`)
  return successResponse(kind, tokensCredited, false)
}

function parseTokenCount(productId: string): number {
  const count = Number(productId.slice(TOKEN_PRODUCT_PREFIX.length))
  if (!Number.isInteger(count) || count <= 0 || count > MAX_TOKENS_PER_PURCHASE) {
    throw new AppError('VALIDATION_ERROR', `Unrecognized token pack product: ${productId}`, 400)
  }
  return count
}

async function creditTokenPack(
  services: ServiceContainer,
  userId: string,
  tokenAmount: number,
  validation: { transactionId: string; validationResponse: any },
  supabase: ServiceContainer['supabaseServiceClient']
): Promise<void> {
  // Ensure the pack actually exists in our catalog (defense against a
  // mistakenly-created store product like tokens_9999).
  const { data: pkg } = await supabase
    .from('token_packages')
    .select('tokens, base_price_rupees, discount_percentage')
    .eq('tokens', tokenAmount)
    .maybeSingle()
  if (!pkg) {
    throw new AppError('VALIDATION_ERROR', `No token package configured for ${tokenAmount} tokens`, 400)
  }

  const { data: planData } = await supabase
    .rpc('get_user_plan_with_subscription', { p_user_id: userId })
  const userPlan = (planData?.plan ?? planData?.[0]?.plan ?? 'free') as 'free' | 'standard' | 'plus' | 'premium'

  const addResult = await services.tokenService.addPurchasedTokens(
    userId,
    userPlan,
    tokenAmount,
    { userId, userPlan, operation: 'purchase', timestamp: new Date() }
  )
  if (!addResult.success) {
    throw new AppError('CREDIT_FAILED', 'Failed to credit purchased tokens', 500)
  }

  // Cost for history: prefer the store-reported price (milliunits), fall back
  // to the catalog's effective price.
  const decoded = validation.validationResponse ?? {}
  const storePriceRupees = typeof decoded.price === 'number' && decoded.currency === 'INR'
    ? decoded.price / 1000
    : null
  const effectiveCatalogPrice =
    Number(pkg.base_price_rupees) * (1 - Number(pkg.discount_percentage ?? 0) / 100)
  const costRupees = Math.max(storePriceRupees ?? effectiveCatalogPrice, 0.01)

  const { error: historyError } = await supabase.rpc('record_purchase_history', {
    p_user_id: userId,
    p_token_amount: tokenAmount,
    p_cost_rupees: Math.round(costRupees * 100) / 100,
    p_cost_paise: Math.round(costRupees * 100),
    p_payment_id: validation.transactionId,
    p_order_id: `apple_${validation.transactionId}`,
    p_payment_method: 'apple_appstore',
    p_status: 'completed',
  })
  if (historyError) {
    console.error('[APPLE_CONSUMABLE] Failed to record purchase history:', historyError)
    // Non-fatal: tokens are credited, receipt row is the source of truth.
  }
}

function successResponse(kind: string, tokensCredited: number, alreadyFulfilled: boolean): Response {
  return new Response(
    JSON.stringify({
      success: true,
      kind,
      tokens_credited: tokensCredited,
      already_fulfilled: alreadyFulfilled,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleConfirmApplePurchase, {
  allowedMethods: ['POST'],
  timeout: 30000,
})
