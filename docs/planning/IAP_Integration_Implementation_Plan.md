# In-App Purchase (IAP) Integration Implementation Plan

**Version:** 1.0
**Date:** February 11, 2026
**Status:** Planning Phase
**Scope:** Google Play Billing & Apple App Store In-App Purchases

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Architecture Overview](#architecture-overview)
4. [Database Schema Updates](#database-schema-updates)
5. [Backend Implementation](#backend-implementation)
6. [Frontend Implementation](#frontend-implementation)
7. [Admin Web Implementation](#admin-web-implementation)
8. [Configuration Management](#configuration-management)
9. [Security & Compliance](#security--compliance)
10. [Testing Strategy](#testing-strategy)
11. [Deployment Plan](#deployment-plan)
12. [Task Breakdown](#task-breakdown)
13. [Risk Assessment](#risk-assessment)
14. [Success Criteria](#success-criteria)

---

## Executive Summary

### Objective
Integrate native in-app purchase capabilities for Android (Google Play) and iOS (Apple App Store) to enable platform-specific subscription payments while maintaining existing Razorpay web payment functionality.

### Current Limitations
- All platforms (web, Android, iOS) currently use Razorpay for payments
- Google Play and Apple App Store pricing exists in database but is unused
- No receipt validation or IAP verification implemented
- Platform-specific payment flows not implemented

### Deliverables
1. **Frontend**: Flutter in-app purchase integration with platform detection
2. **Backend**: Receipt validation services for Google Play and Apple App Store
3. **Admin Web**: IAP configuration management and receipt verification tools
4. **Database**: IAP-specific tables for receipt storage and verification tracking
5. **Documentation**: Complete API documentation and testing procedures

### Timeline Estimate
- **Phase 1 (Database & Config)**: 1 week
- **Phase 2 (Backend Services)**: 2 weeks
- **Phase 3 (Frontend Integration)**: 2 weeks
- **Phase 4 (Admin Tools)**: 1 week
- **Phase 5 (Testing & QA)**: 1 week
- **Total Duration**: 7 weeks

---

## Current State Analysis

### What We Have

#### ✅ Database Infrastructure
```sql
-- subscription_plan_providers table exists with all 3 providers
SELECT provider, plan_id, base_price_minor, currency, is_active
FROM subscription_plan_providers
WHERE provider IN ('razorpay', 'google_play', 'apple_appstore');
```

**Current Data:**
- `razorpay`: Standard (₹79), Plus (₹149), Premium (₹499)
- `google_play`: Standard (₹79), Plus (₹149), Premium (₹499)
- `apple_appstore`: Standard (₹79), Plus (₹149), Premium (₹499)

#### ✅ Backend V2 API Support
```typescript
// backend/supabase/functions/_shared/repositories/subscription_repository.ts
async createSubscriptionV2({
  planCode,
  provider,  // Supports 'google_play' and 'apple_appstore'
  receipt,   // IAP receipt parameter exists but unused
  region,
  promoCode
})
```

#### ✅ Frontend V2 API Client
```dart
// frontend/lib/features/subscription/domain/repositories/subscription_repository.dart
Future<CreateSubscriptionV2Result> createSubscriptionV2({
  required String planCode,
  required String provider,  // Multi-provider support
  String? region,
  String? promoCode,
  String? receipt,  // Receipt parameter exists
});
```

### What We're Missing

#### ❌ Receipt Validation Services
- No Google Play Developer API integration
- No Apple App Store receipt verification
- No receipt signature validation
- No fraud prevention mechanisms

#### ❌ IAP Client Implementation
- No `in_app_purchase` Flutter package integration
- No Google Play Billing client configuration
- No StoreKit integration for iOS
- No purchase flow UI for native IAP

#### ❌ Database Tables for IAP
- No `iap_receipts` table for receipt storage
- No `iap_verification_logs` for audit trail
- No `iap_webhook_events` for store notifications

#### ❌ Admin Tools
- No receipt verification UI
- No IAP transaction monitoring
- No refund management interface

#### ❌ Configuration Management
- Google Play service account credentials hardcoded or missing
- Apple App Store shared secret not in database
- No dynamic configuration for sandbox vs production

---

## Architecture Overview

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Devices                             │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐        │
│  │   Web App    │   │  Android App │   │   iOS App    │        │
│  │  (Flutter)   │   │  (Flutter)   │   │  (Flutter)   │        │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘        │
│         │                  │                  │                 │
│    Razorpay          Google Play         App Store             │
│         │                  │                  │                 │
└─────────┼──────────────────┼──────────────────┼─────────────────┘
          │                  │                  │
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────┐
│              Supabase Edge Functions (Backend)                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Platform Router Service                                  │  │
│  │  - Detects provider from request                         │  │
│  │  - Routes to appropriate payment handler                 │  │
│  └───────┬────────────────────┬───────────────────┬──────────┘  │
│          │                    │                   │             │
│  ┌───────▼────────┐  ┌────────▼────────┐  ┌──────▼──────────┐  │
│  │   Razorpay     │  │  Google Play    │  │  Apple Store   │  │
│  │    Handler     │  │    Handler      │  │    Handler     │  │
│  │                │  │                 │  │                │  │
│  │ - Create sub   │  │ - Verify receipt│  │ - Verify rcpt  │  │
│  │ - Auth URL     │  │ - Validate sig  │  │ - Validate sig │  │
│  └────────────────┘  └─────────┬───────┘  └────────┬────────┘  │
│                                 │                   │           │
│                          ┌──────▼───────────────────▼────────┐  │
│                          │  Receipt Validation Service      │  │
│                          │  - Google Play Developer API     │  │
│                          │  - Apple App Store API           │  │
│                          │  - Fraud detection               │  │
│                          └──────┬───────────────────────────┘  │
└─────────────────────────────────┼─────────────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────────┐
                    │  Supabase PostgreSQL        │
                    │                             │
                    │  - subscription_plans       │
                    │  - subscription_plan_providers│
                    │  - subscriptions            │
                    │  - iap_receipts (NEW)       │
                    │  - iap_verification_logs    │
                    │  - iap_config (NEW)         │
                    └─────────────────────────────┘
```

### Component Responsibilities

#### 1. Frontend (Flutter)
- **Platform Detection**: Automatically detect web/Android/iOS
- **IAP Client**: Initialize Google Play Billing or StoreKit
- **Purchase Flow**: Present native purchase dialogs
- **Receipt Handling**: Extract and send purchase receipts to backend
- **State Management**: Handle pending, successful, failed purchases
- **Error Handling**: User-friendly error messages for IAP failures

#### 2. Backend (Supabase Edge Functions)
- **Receipt Validation**: Verify receipts with Google/Apple servers
- **Subscription Activation**: Create/update subscription records
- **Fraud Detection**: Validate receipt signatures and transaction IDs
- **Webhook Handling**: Process server notifications from stores
- **Audit Logging**: Track all IAP transactions and verifications

#### 3. Admin Web (Next.js)
- **IAP Configuration**: Manage API credentials and settings
- **Receipt Verification**: Manual receipt verification tools
- **Transaction Monitoring**: View all IAP transactions
- **Refund Management**: Handle refund requests and tracking

#### 4. Database (PostgreSQL)
- **Receipt Storage**: Store encrypted purchase receipts
- **Verification Logs**: Audit trail for all verifications
- **Configuration**: Store API credentials and secrets
- **Webhooks**: Track store notification events

---

## Database Schema Updates

### 1. IAP Configuration Table

```sql
-- Store IAP configuration (credentials, secrets, environment)
CREATE TABLE iap_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL CHECK (provider IN ('google_play', 'apple_appstore')),
  environment TEXT NOT NULL CHECK (environment IN ('sandbox', 'production')),
  config_key TEXT NOT NULL,
  config_value TEXT NOT NULL,  -- Encrypted using Supabase Vault
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(provider, environment, config_key)
);

-- Example entries:
-- Google Play Production: service_account_email, service_account_key
-- Apple Production: shared_secret, bundle_id
-- Google Play Sandbox: service_account_email, service_account_key
-- Apple Sandbox: shared_secret, bundle_id

COMMENT ON TABLE iap_config IS 'IAP provider configuration (credentials encrypted via Supabase Vault)';
COMMENT ON COLUMN iap_config.config_value IS 'Encrypted credential stored in Supabase Vault';
```

### 2. IAP Receipts Table

```sql
-- Store purchase receipts for verification and audit
CREATE TABLE iap_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
  provider TEXT NOT NULL CHECK (provider IN ('google_play', 'apple_appstore')),

  -- Receipt data
  receipt_data TEXT NOT NULL,  -- Encrypted raw receipt
  product_id TEXT NOT NULL,    -- e.g., 'com.disciplefy.premium_monthly'
  transaction_id TEXT NOT NULL UNIQUE,  -- Unique transaction ID from store

  -- Validation status
  validation_status TEXT NOT NULL DEFAULT 'pending' CHECK (
    validation_status IN ('pending', 'valid', 'invalid', 'expired', 'refunded', 'cancelled')
  ),
  validation_response JSONB,  -- Full response from Google/Apple
  validated_at TIMESTAMPTZ,

  -- Purchase details
  purchase_date TIMESTAMPTZ NOT NULL,
  expiry_date TIMESTAMPTZ,  -- For subscriptions
  is_trial BOOLEAN DEFAULT false,
  is_intro_offer BOOLEAN DEFAULT false,

  -- Metadata
  environment TEXT NOT NULL DEFAULT 'production' CHECK (environment IN ('sandbox', 'production')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Indexes
  INDEX idx_iap_receipts_user_id ON iap_receipts(user_id),
  INDEX idx_iap_receipts_subscription_id ON iap_receipts(subscription_id),
  INDEX idx_iap_receipts_transaction_id ON iap_receipts(transaction_id),
  INDEX idx_iap_receipts_validation_status ON iap_receipts(validation_status),
  INDEX idx_iap_receipts_expiry_date ON iap_receipts(expiry_date)
);

COMMENT ON TABLE iap_receipts IS 'Purchase receipts from Google Play and Apple App Store';
COMMENT ON COLUMN iap_receipts.receipt_data IS 'Encrypted receipt data from store';
COMMENT ON COLUMN iap_receipts.validation_response IS 'Full JSON response from receipt validation';
```

### 3. IAP Verification Logs Table

```sql
-- Audit trail for all receipt verification attempts
CREATE TABLE iap_verification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id UUID NOT NULL REFERENCES iap_receipts(id) ON DELETE CASCADE,
  provider TEXT NOT NULL CHECK (provider IN ('google_play', 'apple_appstore')),

  -- Verification details
  verification_method TEXT NOT NULL CHECK (
    verification_method IN ('api', 'webhook', 'manual')
  ),
  verification_result TEXT NOT NULL CHECK (
    verification_result IN ('success', 'failure', 'error')
  ),

  -- Request/Response
  request_payload JSONB,
  response_payload JSONB,
  error_message TEXT,
  http_status_code INTEGER,

  -- Metadata
  verified_by UUID REFERENCES auth.users(id),  -- NULL for automatic verifications
  verified_at TIMESTAMPTZ DEFAULT NOW(),

  INDEX idx_iap_verification_logs_receipt_id ON iap_verification_logs(receipt_id),
  INDEX idx_iap_verification_logs_verified_at ON iap_verification_logs(verified_at)
);

COMMENT ON TABLE iap_verification_logs IS 'Audit trail for all IAP receipt verification attempts';
```

### 4. IAP Webhook Events Table

```sql
-- Store webhook notifications from Google Play and Apple App Store
CREATE TABLE iap_webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL CHECK (provider IN ('google_play', 'apple_appstore')),

  -- Event details
  event_type TEXT NOT NULL,  -- e.g., 'SUBSCRIPTION_PURCHASED', 'SUBSCRIPTION_RENEWED'
  notification_id TEXT,  -- Unique ID from store (for deduplication)

  -- Payload
  raw_payload JSONB NOT NULL,
  parsed_data JSONB,

  -- Processing status
  processing_status TEXT NOT NULL DEFAULT 'pending' CHECK (
    processing_status IN ('pending', 'processing', 'processed', 'failed')
  ),
  processed_at TIMESTAMPTZ,
  error_message TEXT,

  -- Related records
  transaction_id TEXT,
  receipt_id UUID REFERENCES iap_receipts(id),
  subscription_id UUID REFERENCES subscriptions(id),

  -- Metadata
  received_at TIMESTAMPTZ DEFAULT NOW(),

  -- Indexes and constraints
  UNIQUE(provider, notification_id),  -- Prevent duplicate processing
  INDEX idx_iap_webhook_events_transaction_id ON iap_webhook_events(transaction_id),
  INDEX idx_iap_webhook_events_processing_status ON iap_webhook_events(processing_status),
  INDEX idx_iap_webhook_events_received_at ON iap_webhook_events(received_at)
);

COMMENT ON TABLE iap_webhook_events IS 'Webhook notifications from Google Play and Apple App Store';
COMMENT ON COLUMN iap_webhook_events.notification_id IS 'Unique notification ID for deduplication';
```

### 5. Update Subscriptions Table

```sql
-- Add IAP-specific columns to existing subscriptions table
ALTER TABLE subscriptions
  ADD COLUMN iap_receipt_id UUID REFERENCES iap_receipts(id),
  ADD COLUMN iap_product_id TEXT,  -- e.g., 'com.disciplefy.premium_monthly'
  ADD COLUMN iap_original_transaction_id TEXT,  -- For subscription renewals
  ADD COLUMN is_iap_subscription BOOLEAN DEFAULT false,
  ADD INDEX idx_subscriptions_iap_receipt_id ON subscriptions(iap_receipt_id),
  ADD INDEX idx_subscriptions_iap_original_transaction_id ON subscriptions(iap_original_transaction_id);

COMMENT ON COLUMN subscriptions.iap_receipt_id IS 'Link to IAP receipt if purchased via Google Play or App Store';
COMMENT ON COLUMN subscriptions.iap_original_transaction_id IS 'Original transaction ID for tracking subscription renewals';
```

### 6. RLS Policies

```sql
-- IAP Receipts: Users can only read their own receipts
CREATE POLICY "Users can view own IAP receipts"
  ON iap_receipts FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage IAP receipts"
  ON iap_receipts FOR ALL
  USING (auth.role() = 'service_role');

-- IAP Config: Only service role can access
CREATE POLICY "Only service role can access IAP config"
  ON iap_config FOR ALL
  USING (auth.role() = 'service_role');

-- IAP Verification Logs: Users can view logs for their receipts
CREATE POLICY "Users can view verification logs for their receipts"
  ON iap_verification_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM iap_receipts
      WHERE iap_receipts.id = iap_verification_logs.receipt_id
        AND iap_receipts.user_id = auth.uid()
    )
  );

-- IAP Webhook Events: Only service role can access
CREATE POLICY "Only service role can access webhook events"
  ON iap_webhook_events FOR ALL
  USING (auth.role() = 'service_role');
```

### 7. Database Functions

```sql
-- Function to get decrypted IAP config
CREATE OR REPLACE FUNCTION get_iap_config(
  p_provider TEXT,
  p_environment TEXT,
  p_config_key TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_config_value TEXT;
BEGIN
  SELECT config_value INTO v_config_value
  FROM iap_config
  WHERE provider = p_provider
    AND environment = p_environment
    AND config_key = p_config_key
    AND is_active = true;

  -- Decrypt using Supabase Vault (implementation depends on Supabase version)
  -- RETURN pgsodium.decrypt(v_config_value::bytea, vault_key);

  RETURN v_config_value;  -- Placeholder until Vault integration
END;
$$;

-- Function to validate IAP receipt ownership
CREATE OR REPLACE FUNCTION validate_iap_receipt_ownership(
  p_receipt_id UUID,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_owner_id UUID;
BEGIN
  SELECT user_id INTO v_owner_id
  FROM iap_receipts
  WHERE id = p_receipt_id;

  RETURN v_owner_id = p_user_id;
END;
$$;

-- Function to get active IAP subscription for user
CREATE OR REPLACE FUNCTION get_active_iap_subscription(p_user_id UUID)
RETURNS TABLE (
  subscription_id UUID,
  plan_code TEXT,
  provider TEXT,
  expiry_date TIMESTAMPTZ,
  auto_renew BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id,
    s.plan_type,
    ir.provider,
    ir.expiry_date,
    s.cancel_at_cycle_end = false AS auto_renew
  FROM subscriptions s
  INNER JOIN iap_receipts ir ON ir.id = s.iap_receipt_id
  WHERE s.user_id = p_user_id
    AND s.status IN ('active', 'authenticated')
    AND s.is_iap_subscription = true
    AND ir.validation_status = 'valid'
    AND (ir.expiry_date IS NULL OR ir.expiry_date > NOW())
  ORDER BY s.created_at DESC
  LIMIT 1;
END;
$$;
```

---

## Backend Implementation

### Phase 1: Configuration Service

#### File: `backend/supabase/functions/_shared/services/iap-config-service.ts`

```typescript
/**
 * IAP Configuration Service
 *
 * Manages In-App Purchase configuration for Google Play and Apple App Store.
 * Credentials are stored encrypted in the database and cached for performance.
 */

import { SupabaseClient } from '@supabase/supabase-js'

export type IAPProvider = 'google_play' | 'apple_appstore'
export type IAPEnvironment = 'sandbox' | 'production'

interface IAPConfig {
  provider: IAPProvider
  environment: IAPEnvironment
  serviceAccountEmail?: string  // Google Play
  serviceAccountKey?: string    // Google Play (encrypted)
  sharedSecret?: string         // Apple App Store (encrypted)
  bundleId?: string            // Apple App Store
  packageName?: string         // Google Play
}

interface CachedConfig {
  config: IAPConfig
  fetchedAt: number
}

// Cache for 5 minutes (same pattern as subscription-config.ts)
const CONFIG_CACHE_TTL = 5 * 60 * 1000
const configCache = new Map<string, CachedConfig>()

/**
 * Get IAP configuration from database with caching
 */
export async function getIAPConfig(
  supabase: SupabaseClient,
  provider: IAPProvider,
  environment: IAPEnvironment
): Promise<IAPConfig> {
  const cacheKey = `${provider}_${environment}`
  const now = Date.now()

  // Check cache
  const cached = configCache.get(cacheKey)
  if (cached && (now - cached.fetchedAt < CONFIG_CACHE_TTL)) {
    console.log(`[IAP_CONFIG] Cache hit for ${cacheKey}`)
    return cached.config
  }

  console.log(`[IAP_CONFIG] Fetching config for ${provider} (${environment})`)

  // Fetch all config keys for this provider/environment
  const { data: configRows, error } = await supabase
    .from('iap_config')
    .select('config_key, config_value')
    .eq('provider', provider)
    .eq('environment', environment)
    .eq('is_active', true)

  if (error) {
    throw new Error(`Failed to fetch IAP config: ${error.message}`)
  }

  if (!configRows || configRows.length === 0) {
    throw new Error(`No IAP configuration found for ${provider} (${environment})`)
  }

  // Build config object
  const config: IAPConfig = {
    provider,
    environment
  }

  for (const row of configRows) {
    switch (row.config_key) {
      case 'service_account_email':
        config.serviceAccountEmail = row.config_value
        break
      case 'service_account_key':
        config.serviceAccountKey = row.config_value  // Already encrypted
        break
      case 'shared_secret':
        config.sharedSecret = row.config_value  // Already encrypted
        break
      case 'bundle_id':
        config.bundleId = row.config_value
        break
      case 'package_name':
        config.packageName = row.config_value
        break
    }
  }

  // Validate required fields
  if (provider === 'google_play') {
    if (!config.serviceAccountEmail || !config.serviceAccountKey || !config.packageName) {
      throw new Error('Missing required Google Play configuration')
    }
  } else if (provider === 'apple_appstore') {
    if (!config.sharedSecret || !config.bundleId) {
      throw new Error('Missing required Apple App Store configuration')
    }
  }

  // Cache the config
  configCache.set(cacheKey, {
    config,
    fetchedAt: now
  })

  return config
}

/**
 * Clear configuration cache
 */
export function clearIAPConfigCache(provider?: IAPProvider, environment?: IAPEnvironment): void {
  if (provider && environment) {
    configCache.delete(`${provider}_${environment}`)
  } else {
    configCache.clear()
  }
  console.log('[IAP_CONFIG] Cache cleared')
}

/**
 * Detect environment from receipt or default to production
 */
export function detectEnvironment(receipt: string): IAPEnvironment {
  // Apple receipts have environment in the response
  // Google Play receipts don't indicate environment, use configuration
  // Default to production for safety
  return 'production'
}
```

### Phase 2: Google Play Receipt Validation Service

#### File: `backend/supabase/functions/_shared/services/google-play-validator.ts`

```typescript
/**
 * Google Play Receipt Validation Service
 *
 * Validates purchase receipts using Google Play Developer API.
 * Documentation: https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2
 */

import { SupabaseClient } from '@supabase/supabase-js'
import { getIAPConfig } from './iap-config-service.ts'

interface GooglePlayReceipt {
  packageName: string
  productId: string
  purchaseToken: string
}

interface GooglePlayValidationResult {
  isValid: boolean
  transactionId: string
  purchaseDate: Date
  expiryDate?: Date
  isTrial: boolean
  isIntroOffer: boolean
  autoRenewing: boolean
  validationResponse: any
  error?: string
}

/**
 * Validate Google Play purchase receipt
 */
export async function validateGooglePlayReceipt(
  supabase: SupabaseClient,
  receipt: GooglePlayReceipt,
  environment: 'sandbox' | 'production'
): Promise<GooglePlayValidationResult> {
  console.log('[GOOGLE_PLAY] Validating receipt for product:', receipt.productId)

  try {
    // Get Google Play configuration
    const config = await getIAPConfig(supabase, 'google_play', environment)

    // Get access token using service account
    const accessToken = await getGoogleAccessToken(
      config.serviceAccountEmail!,
      config.serviceAccountKey!
    )

    // Call Google Play Developer API
    const apiUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${receipt.packageName}/purchases/subscriptionsv2/tokens/${receipt.purchaseToken}`

    const response = await fetch(apiUrl, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      }
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error('[GOOGLE_PLAY] API Error:', response.status, errorText)

      return {
        isValid: false,
        transactionId: '',
        purchaseDate: new Date(),
        isTrial: false,
        isIntroOffer: false,
        autoRenewing: false,
        validationResponse: null,
        error: `Google Play API error: ${response.status}`
      }
    }

    const validationData = await response.json()

    // Parse subscription state
    const subscriptionState = validationData.subscriptionState
    const lineItems = validationData.lineItems || []
    const latestOrderId = validationData.latestOrderId

    // Check if subscription is active
    const isActive = subscriptionState === 'SUBSCRIPTION_STATE_ACTIVE' ||
                     subscriptionState === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'

    // Extract dates
    const startTime = lineItems[0]?.expiryTime?.seconds
      ? new Date(parseInt(lineItems[0].expiryTime.seconds) * 1000)
      : new Date()

    const expiryTime = lineItems[0]?.expiryTime?.seconds
      ? new Date(parseInt(lineItems[0].expiryTime.seconds) * 1000)
      : undefined

    // Check for trial or intro offer
    const offerDetails = lineItems[0]?.offerDetails
    const isTrial = offerDetails?.basePlanId?.includes('trial') || false
    const isIntroOffer = offerDetails?.offerType === 'INTRODUCTORY_OFFER' || false

    // Auto-renewing status
    const autoRenewing = validationData.canceledStateContext === null

    console.log('[GOOGLE_PLAY] Validation result:', {
      isValid: isActive,
      transactionId: latestOrderId,
      expiryDate: expiryTime,
      autoRenewing
    })

    return {
      isValid: isActive,
      transactionId: latestOrderId || receipt.purchaseToken,
      purchaseDate: startTime,
      expiryDate: expiryTime,
      isTrial,
      isIntroOffer,
      autoRenewing,
      validationResponse: validationData
    }
  } catch (error) {
    console.error('[GOOGLE_PLAY] Validation error:', error)

    return {
      isValid: false,
      transactionId: '',
      purchaseDate: new Date(),
      isTrial: false,
      isIntroOffer: false,
      autoRenewing: false,
      validationResponse: null,
      error: error instanceof Error ? error.message : 'Unknown error'
    }
  }
}

/**
 * Get Google Cloud access token using service account
 */
async function getGoogleAccessToken(
  serviceAccountEmail: string,
  serviceAccountKeyJson: string
): Promise<string> {
  // Parse service account key
  const serviceAccount = JSON.parse(serviceAccountKeyJson)

  // Create JWT for Google OAuth 2.0
  const now = Math.floor(Date.now() / 1000)
  const claims = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now
  }

  // Sign JWT (using jose library or similar)
  // This is a simplified example - actual implementation needs proper JWT signing
  const jwt = await signJWT(claims, serviceAccount.private_key)

  // Exchange JWT for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt
    })
  })

  if (!tokenResponse.ok) {
    throw new Error('Failed to get Google access token')
  }

  const tokenData = await tokenResponse.json()
  return tokenData.access_token
}

/**
 * Sign JWT using RS256 algorithm
 * Implementation would use jose or similar library
 */
async function signJWT(claims: any, privateKey: string): Promise<string> {
  // TODO: Implement using jose library
  // import * as jose from 'jose'
  // const key = await jose.importPKCS8(privateKey, 'RS256')
  // const jwt = await new jose.SignJWT(claims)
  //   .setProtectedHeader({ alg: 'RS256' })
  //   .sign(key)
  // return jwt

  throw new Error('JWT signing not implemented')
}

/**
 * Acknowledge Google Play purchase
 */
export async function acknowledgeGooglePlayPurchase(
  supabase: SupabaseClient,
  receipt: GooglePlayReceipt,
  environment: 'sandbox' | 'production'
): Promise<boolean> {
  console.log('[GOOGLE_PLAY] Acknowledging purchase:', receipt.productId)

  try {
    const config = await getIAPConfig(supabase, 'google_play', environment)
    const accessToken = await getGoogleAccessToken(
      config.serviceAccountEmail!,
      config.serviceAccountKey!
    )

    const apiUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${receipt.packageName}/purchases/subscriptions/${receipt.productId}/tokens/${receipt.purchaseToken}:acknowledge`

    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      }
    })

    return response.ok
  } catch (error) {
    console.error('[GOOGLE_PLAY] Acknowledge error:', error)
    return false
  }
}
```

### Phase 3: Apple App Store Receipt Validation Service

#### File: `backend/supabase/functions/_shared/services/apple-appstore-validator.ts`

```typescript
/**
 * Apple App Store Receipt Validation Service
 *
 * Validates purchase receipts using Apple App Store Server API.
 * Documentation: https://developer.apple.com/documentation/appstorereceipts/verifyreceipt
 */

import { SupabaseClient } from '@supabase/supabase-js'
import { getIAPConfig } from './iap-config-service.ts'

interface AppleReceiptData {
  receiptData: string  // Base64 encoded receipt
}

interface AppleValidationResult {
  isValid: boolean
  transactionId: string
  originalTransactionId: string
  purchaseDate: Date
  expiryDate?: Date
  isTrial: boolean
  isIntroOffer: boolean
  autoRenewing: boolean
  validationResponse: any
  error?: string
}

/**
 * Validate Apple App Store purchase receipt
 */
export async function validateAppleReceipt(
  supabase: SupabaseClient,
  receipt: AppleReceiptData,
  environment: 'sandbox' | 'production'
): Promise<AppleValidationResult> {
  console.log('[APPLE] Validating receipt for environment:', environment)

  try {
    // Get Apple configuration
    const config = await getIAPConfig(supabase, 'apple_appstore', environment)

    // Choose verification endpoint based on environment
    const verifyUrl = environment === 'production'
      ? 'https://buy.itunes.apple.com/verifyReceipt'
      : 'https://sandbox.itunes.apple.com/verifyReceipt'

    // Verify receipt with Apple
    const response = await fetch(verifyUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        'receipt-data': receipt.receiptData,
        'password': config.sharedSecret,
        'exclude-old-transactions': true
      })
    })

    if (!response.ok) {
      console.error('[APPLE] API Error:', response.status)
      return {
        isValid: false,
        transactionId: '',
        originalTransactionId: '',
        purchaseDate: new Date(),
        isTrial: false,
        isIntroOffer: false,
        autoRenewing: false,
        validationResponse: null,
        error: `Apple API error: ${response.status}`
      }
    }

    const validationData = await response.json()

    // Check status code
    // 0: Valid receipt
    // 21007: Sandbox receipt sent to production
    // 21008: Production receipt sent to sandbox
    if (validationData.status === 21007 && environment === 'production') {
      // Retry with sandbox endpoint
      console.log('[APPLE] Retrying with sandbox endpoint')
      return validateAppleReceipt(supabase, receipt, 'sandbox')
    }

    if (validationData.status === 21008 && environment === 'sandbox') {
      // Retry with production endpoint
      console.log('[APPLE] Retrying with production endpoint')
      return validateAppleReceipt(supabase, receipt, 'production')
    }

    if (validationData.status !== 0) {
      return {
        isValid: false,
        transactionId: '',
        originalTransactionId: '',
        purchaseDate: new Date(),
        isTrial: false,
        isIntroOffer: false,
        autoRenewing: false,
        validationResponse: validationData,
        error: `Apple receipt validation failed: ${validationData.status}`
      }
    }

    // Extract latest receipt info
    const latestReceipt = validationData.latest_receipt_info?.[0]
    const pendingRenewal = validationData.pending_renewal_info?.[0]

    if (!latestReceipt) {
      return {
        isValid: false,
        transactionId: '',
        originalTransactionId: '',
        purchaseDate: new Date(),
        isTrial: false,
        isIntroOffer: false,
        autoRenewing: false,
        validationResponse: validationData,
        error: 'No receipt info found'
      }
    }

    // Parse dates (Apple uses milliseconds)
    const purchaseDate = new Date(parseInt(latestReceipt.purchase_date_ms))
    const expiryDate = latestReceipt.expires_date_ms
      ? new Date(parseInt(latestReceipt.expires_date_ms))
      : undefined

    // Check if subscription is active
    const now = new Date()
    const isActive = expiryDate ? expiryDate > now : false

    // Check for trial or intro offer
    const isTrial = latestReceipt.is_trial_period === 'true'
    const isIntroOffer = latestReceipt.is_in_intro_offer_period === 'true'

    // Auto-renewing status
    const autoRenewing = pendingRenewal?.auto_renew_status === '1'

    console.log('[APPLE] Validation result:', {
      isValid: isActive,
      transactionId: latestReceipt.transaction_id,
      expiryDate,
      autoRenewing
    })

    return {
      isValid: isActive,
      transactionId: latestReceipt.transaction_id,
      originalTransactionId: latestReceipt.original_transaction_id,
      purchaseDate,
      expiryDate,
      isTrial,
      isIntroOffer,
      autoRenewing,
      validationResponse: validationData
    }
  } catch (error) {
    console.error('[APPLE] Validation error:', error)

    return {
      isValid: false,
      transactionId: '',
      originalTransactionId: '',
      purchaseDate: new Date(),
      isTrial: false,
      isIntroOffer: false,
      autoRenewing: false,
      validationResponse: null,
      error: error instanceof Error ? error.message : 'Unknown error'
    }
  }
}
```

### Phase 4: Unified Receipt Validation Service

#### File: `backend/supabase/functions/_shared/services/receipt-validation-service.ts`

```typescript
/**
 * Unified Receipt Validation Service
 *
 * Routes receipt validation to appropriate provider (Google Play or Apple App Store).
 * Stores receipts and validation results in database.
 */

import { SupabaseClient } from '@supabase/supabase-js'
import { validateGooglePlayReceipt, acknowledgeGooglePlayPurchase } from './google-play-validator.ts'
import { validateAppleReceipt } from './apple-appstore-validator.ts'
import { IAPProvider, IAPEnvironment } from './iap-config-service.ts'

interface ReceiptValidationRequest {
  provider: IAPProvider
  receiptData: string
  productId: string
  userId: string
  planCode: string
  environment?: IAPEnvironment
}

interface ReceiptValidationResponse {
  success: boolean
  receiptId: string
  subscriptionId?: string
  transactionId: string
  isValid: boolean
  expiryDate?: Date
  autoRenewing: boolean
  error?: string
}

/**
 * Validate and process IAP receipt
 */
export async function validateAndProcessReceipt(
  supabase: SupabaseClient,
  request: ReceiptValidationRequest
): Promise<ReceiptValidationResponse> {
  console.log(`[RECEIPT_VALIDATION] Processing ${request.provider} receipt for user ${request.userId}`)

  const environment = request.environment || 'production'

  // Step 1: Validate receipt with provider
  let validationResult

  if (request.provider === 'google_play') {
    const receiptData = JSON.parse(request.receiptData)
    validationResult = await validateGooglePlayReceipt(supabase, receiptData, environment)
  } else {
    validationResult = await validateAppleReceipt(
      supabase,
      { receiptData: request.receiptData },
      environment
    )
  }

  // Step 2: Store receipt in database
  const { data: receiptRecord, error: receiptError } = await supabase
    .from('iap_receipts')
    .insert({
      user_id: request.userId,
      provider: request.provider,
      receipt_data: request.receiptData,  // TODO: Encrypt
      product_id: request.productId,
      transaction_id: validationResult.transactionId,
      validation_status: validationResult.isValid ? 'valid' : 'invalid',
      validation_response: validationResult.validationResponse,
      validated_at: new Date().toISOString(),
      purchase_date: validationResult.purchaseDate.toISOString(),
      expiry_date: validationResult.expiryDate?.toISOString(),
      is_trial: validationResult.isTrial,
      is_intro_offer: validationResult.isIntroOffer,
      environment
    })
    .select()
    .single()

  if (receiptError) {
    console.error('[RECEIPT_VALIDATION] Failed to store receipt:', receiptError)
    throw new Error('Failed to store receipt in database')
  }

  // Step 3: Log validation attempt
  await supabase
    .from('iap_verification_logs')
    .insert({
      receipt_id: receiptRecord.id,
      provider: request.provider,
      verification_method: 'api',
      verification_result: validationResult.isValid ? 'success' : 'failure',
      request_payload: {
        productId: request.productId,
        environment
      },
      response_payload: validationResult.validationResponse,
      error_message: validationResult.error,
      http_status_code: validationResult.isValid ? 200 : 400
    })

  // Step 4: If valid, create/update subscription
  let subscriptionId: string | undefined

  if (validationResult.isValid) {
    const { data: subscription, error: subError } = await supabase
      .from('subscriptions')
      .insert({
        user_id: request.userId,
        plan_type: request.planCode,
        provider: request.provider,
        provider_subscription_id: validationResult.transactionId,
        status: 'active',
        current_period_start: validationResult.purchaseDate.toISOString(),
        current_period_end: validationResult.expiryDate?.toISOString(),
        cancel_at_cycle_end: !validationResult.autoRenewing,
        is_iap_subscription: true,
        iap_receipt_id: receiptRecord.id,
        iap_product_id: request.productId,
        iap_original_transaction_id: 'originalTransactionId' in validationResult
          ? validationResult.originalTransactionId
          : validationResult.transactionId
      })
      .select()
      .single()

    if (subError) {
      console.error('[RECEIPT_VALIDATION] Failed to create subscription:', subError)
    } else {
      subscriptionId = subscription.id

      // Update receipt with subscription ID
      await supabase
        .from('iap_receipts')
        .update({ subscription_id: subscriptionId })
        .eq('id', receiptRecord.id)
    }

    // Step 5: Acknowledge purchase (Google Play only)
    if (request.provider === 'google_play') {
      const receiptData = JSON.parse(request.receiptData)
      await acknowledgeGooglePlayPurchase(supabase, receiptData, environment)
    }
  }

  return {
    success: validationResult.isValid,
    receiptId: receiptRecord.id,
    subscriptionId,
    transactionId: validationResult.transactionId,
    isValid: validationResult.isValid,
    expiryDate: validationResult.expiryDate,
    autoRenewing: validationResult.autoRenewing,
    error: validationResult.error
  }
}

/**
 * Re-validate existing receipt (for renewals and status checks)
 */
export async function revalidateReceipt(
  supabase: SupabaseClient,
  receiptId: string
): Promise<ReceiptValidationResponse> {
  // Fetch existing receipt
  const { data: receipt, error } = await supabase
    .from('iap_receipts')
    .select('*')
    .eq('id', receiptId)
    .single()

  if (error || !receipt) {
    throw new Error('Receipt not found')
  }

  // Re-validate with provider
  return validateAndProcessReceipt(supabase, {
    provider: receipt.provider as IAPProvider,
    receiptData: receipt.receipt_data,
    productId: receipt.product_id,
    userId: receipt.user_id,
    planCode: receipt.product_id.split('.').pop() || 'standard',  // Extract plan from product ID
    environment: receipt.environment as IAPEnvironment
  })
}
```

(Continued in next section...)

---

## Frontend Implementation

### Phase 1: Platform Detection Service

#### File: `frontend/lib/core/services/platform_payment_provider_service.dart`

```dart
/// Platform-Aware Payment Provider Service
///
/// Automatically detects the current platform and returns the appropriate
/// payment provider ('razorpay', 'google_play', 'apple_appstore').
///
/// NO HARDCODING: Provider selection is based solely on runtime platform detection.

import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformPaymentProviderService {
  /// Get the payment provider for the current platform
  ///
  /// Returns:
  /// - 'razorpay' for web
  /// - 'google_play' for Android
  /// - 'apple_appstore' for iOS
  static String getProvider() {
    if (kIsWeb) {
      return 'razorpay';
    } else if (Platform.isAndroid) {
      return 'google_play';
    } else if (Platform.isIOS) {
      return 'apple_appstore';
    } else {
      // Fallback for unsupported platforms
      return 'razorpay';
    }
  }

  /// Check if current platform uses In-App Purchases
  static bool isIAPPlatform() {
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Check if current platform uses web payments
  static bool isWebPaymentPlatform() {
    return kIsWeb;
  }

  /// Get user-friendly provider name
  static String getProviderDisplayName() {
    final provider = getProvider();
    switch (provider) {
      case 'google_play':
        return 'Google Play';
      case 'apple_appstore':
        return 'App Store';
      case 'razorpay':
        return 'Razorpay';
      default:
        return 'Payment Provider';
    }
  }
}
```

### Phase 2: In-App Purchase Service

#### File: `frontend/lib/core/services/iap_service.dart`

```dart
/// In-App Purchase Service
///
/// Handles Google Play and Apple App Store in-app purchases.
/// Manages purchase flow, receipt extraction, and restoration.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

class IAPService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Callbacks
  Function(PurchaseDetails)? onPurchaseUpdate;
  Function(String)? onPurchaseError;

  /// Initialize IAP service
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('🛒 [IAP] Web platform - IAP not available');
      return;
    }

    // Check if IAP is available
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('🛒 [IAP] Store not available on this device');
      return;
    }

    // iOS-specific setup
    if (Platform.isIOS) {
      final iosPlatform = _iap.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosPlatform.setDelegate(PaymentQueueDelegate());
    }

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdate,
      onDone: () => debugPrint('🛒 [IAP] Purchase stream closed'),
      onError: (error) {
        debugPrint('🛒 [IAP] Purchase stream error: $error');
        onPurchaseError?.call(error.toString());
      },
    );

    debugPrint('🛒 [IAP] Service initialized');
  }

  /// Dispose IAP service
  void dispose() {
    _subscription?.cancel();
    debugPrint('🛒 [IAP] Service disposed');
  }

  /// Fetch available products from store
  Future<List<ProductDetails>> getProducts(Set<String> productIds) async {
    debugPrint('🛒 [IAP] Fetching products: $productIds');

    final response = await _iap.queryProductDetails(productIds);

    if (response.error != null) {
      debugPrint('🛒 [IAP] Error fetching products: ${response.error}');
      throw Exception('Failed to fetch products: ${response.error?.message}');
    }

    if (response.productDetails.isEmpty) {
      debugPrint('🛒 [IAP] No products found');
      throw Exception('No products found for the given IDs');
    }

    debugPrint('🛒 [IAP] Found ${response.productDetails.length} products');
    return response.productDetails;
  }

  /// Purchase a product
  Future<void> purchaseProduct(ProductDetails product) async {
    debugPrint('🛒 [IAP] Initiating purchase: ${product.id}');

    final purchaseParam = PurchaseParam(productDetails: product);

    try {
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        debugPrint('🛒 [IAP] Purchase initiation failed');
        onPurchaseError?.call('Failed to initiate purchase');
      }
    } catch (e) {
      debugPrint('🛒 [IAP] Purchase error: $e');
      onPurchaseError?.call(e.toString());
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    debugPrint('🛒 [IAP] Restoring purchases');

    try {
      await _iap.restorePurchases();
      debugPrint('🛒 [IAP] Restore completed');
    } catch (e) {
      debugPrint('🛒 [IAP] Restore error: $e');
      onPurchaseError?.call('Failed to restore purchases: $e');
    }
  }

  /// Handle purchase updates from store
  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      debugPrint('🛒 [IAP] Purchase update: ${purchase.productID}, status: ${purchase.status}');

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Notify callback with successful purchase
        onPurchaseUpdate?.call(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('🛒 [IAP] Purchase error: ${purchase.error}');
        onPurchaseError?.call(purchase.error?.message ?? 'Purchase failed');
      } else if (purchase.status == PurchaseStatus.canceled) {
        debugPrint('🛒 [IAP] Purchase cancelled by user');
        onPurchaseError?.call('Purchase cancelled');
      }

      // Complete pending transactions
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  /// Extract receipt data for backend validation
  String getReceiptData(PurchaseDetails purchase) {
    if (Platform.isAndroid) {
      // Google Play receipt
      final androidPurchase = purchase as GooglePlayPurchaseDetails;
      return androidPurchase.billingClientPurchase.originalJson;
    } else if (Platform.isIOS) {
      // Apple App Store receipt
      final iosPurchase = purchase as AppStorePurchaseDetails;
      return iosPurchase.verificationData.serverVerificationData;
    }

    return '';
  }

  /// Get product ID from purchase
  String getProductId(PurchaseDetails purchase) {
    return purchase.productID;
  }

  /// Get transaction ID from purchase
  String getTransactionId(PurchaseDetails purchase) {
    if (Platform.isAndroid) {
      final androidPurchase = purchase as GooglePlayPurchaseDetails;
      return androidPurchase.billingClientPurchase.orderId;
    } else if (Platform.isIOS) {
      final iosPurchase = purchase as AppStorePurchaseDetails;
      return iosPurchase.verificationData.transactionId ?? '';
    }

    return '';
  }
}

/// iOS Payment Queue Delegate
class PaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
    SKPaymentTransactionWrapper transaction,
    SKStorefrontWrapper storefront,
  ) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}
```

### Phase 3: Update Subscription BLoC

#### File: `frontend/lib/features/subscription/presentation/bloc/subscription_bloc.dart`

```dart
// Add to existing file - UPDATE existing methods

import '../../core/services/platform_payment_provider_service.dart';
import '../../core/services/iap_service.dart';

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final IAPService _iapService;

  SubscriptionBloc({
    // ... existing parameters
    required IAPService iapService,
  }) : _iapService = iapService,
       // ... existing initialization
  {
    // Initialize IAP service
    _iapService.initialize();

    // Set purchase callbacks
    _iapService.onPurchaseUpdate = _handleIAPPurchaseUpdate;
    _iapService.onPurchaseError = _handleIAPPurchaseError;

    // ... existing event handlers
  }

  // UPDATED: Create subscription with dynamic provider
  Future<void> _onCreateSubscription(
    CreateSubscriptionEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoading(operation: 'creating'));

    // Get provider based on platform (NO HARDCODING)
    final provider = PlatformPaymentProviderService.getProvider();

    // Check if IAP platform
    if (PlatformPaymentProviderService.isIAPPlatform()) {
      // Use IAP flow
      await _handleIAPSubscription(event.planCode, emit);
    } else {
      // Use web payment flow (Razorpay)
      await _handleWebSubscription(event.planCode, provider, emit);
    }
  }

  /// Handle IAP subscription (Google Play / App Store)
  Future<void> _handleIAPSubscription(
    String planCode,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      // Construct product ID based on bundle/package name
      final productId = await _getProductId(planCode);

      // Fetch product from store
      final products = await _iapService.getProducts({productId});

      if (products.isEmpty) {
        emit(const SubscriptionError(
          message: 'Product not available in store',
          code: 'PRODUCT_NOT_FOUND',
        ));
        return;
      }

      // Initiate purchase
      await _iapService.purchaseProduct(products.first);

      // Purchase callback will handle the rest
    } catch (e) {
      emit(SubscriptionError(
        message: 'Failed to initiate purchase: $e',
        code: 'IAP_PURCHASE_FAILED',
      ));
    }
  }

  /// Handle web subscription (Razorpay)
  Future<void> _handleWebSubscription(
    String planCode,
    String provider,
    Emitter<SubscriptionState> emit,
  ) async {
    // Use V2 API with dynamic provider (existing logic)
    final result = await _subscriptionRepository.createSubscriptionV2(
      planCode: planCode,
      provider: provider,  // ← DYNAMIC, not hardcoded
      region: 'IN',
      promoCode: state.selectedPromoCode,
    );

    // ... rest of existing logic
  }

  /// IAP purchase update callback
  void _handleIAPPurchaseUpdate(PurchaseDetails purchase) async {
    debugPrint('🛒 [BLOC] IAP Purchase successful: ${purchase.productID}');

    // Extract receipt data
    final receiptData = _iapService.getReceiptData(purchase);
    final productId = _iapService.getProductId(purchase);
    final provider = PlatformPaymentProviderService.getProvider();

    // Determine plan code from product ID
    final planCode = _extractPlanCodeFromProductId(productId);

    // Send receipt to backend for validation
    final result = await _subscriptionRepository.createSubscriptionV2(
      planCode: planCode,
      provider: provider,
      region: 'IN',
      receipt: receiptData,  // ← Send receipt for validation
    );

    result.fold(
      (failure) {
        add(SubscriptionErrorOccurred(
          message: failure.message,
          code: failure.code,
        ));
      },
      (subscriptionResult) {
        // Success - subscription activated
        add(const SubscriptionStatusRequested());
      },
    );
  }

  /// IAP purchase error callback
  void _handleIAPPurchaseError(String error) {
    add(SubscriptionErrorOccurred(
      message: error,
      code: 'IAP_ERROR',
    ));
  }

  /// Get product ID for plan code
  Future<String> _getProductId(String planCode) async {
    // Fetch from pricing service to avoid hardcoding
    final pricingService = sl<PricingService>();
    final provider = PlatformPaymentProviderService.getProvider();

    // Get product ID from database pricing
    final pricing = await pricingService.fetchPricing();
    final providerPricing = pricing.providers[provider];

    if (providerPricing == null) {
      throw Exception('Provider pricing not found: $provider');
    }

    final planPricing = providerPricing.plans[planCode];

    if (planPricing == null) {
      throw Exception('Plan pricing not found: $planCode');
    }

    // Return product ID from database
    return planPricing.productId;  // NEW: Add productId to PlanPrice model
  }

  /// Extract plan code from product ID
  String _extractPlanCodeFromProductId(String productId) {
    // Example: com.disciplefy.premium_monthly → premium
    final parts = productId.split('.');
    final planPart = parts.last.split('_').first;
    return planPart;
  }

  @override
  Future<void> close() {
    _iapService.dispose();
    return super.close();
  }
}
```

(Continued...)

---

## Admin Web Implementation

### Admin IAP Configuration Page

#### File: `admin-web/app/(dashboard)/iap-config/page.tsx`

```typescript
'use client'

import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'

interface IAPConfig {
  id: string
  provider: 'google_play' | 'apple_appstore'
  environment: 'sandbox' | 'production'
  configKey: string
  configValue: string
  isActive: boolean
}

export default function IAPConfigPage() {
  const [selectedProvider, setSelectedProvider] = useState<'google_play' | 'apple_appstore'>('google_play')
  const [selectedEnvironment, setSelectedEnvironment] = useState<'sandbox' | 'production'>('production')
  const [isEditing, setIsEditing] = useState(false)
  const queryClient = useQueryClient()

  // Fetch IAP configuration
  const { data: configs, isLoading } = useQuery({
    queryKey: ['iap-config', selectedProvider, selectedEnvironment],
    queryFn: async () => {
      const res = await fetch(
        `/api/admin/iap/config?provider=${selectedProvider}&environment=${selectedEnvironment}`,
        { credentials: 'include' }
      )
      if (!res.ok) throw new Error('Failed to fetch IAP config')
      return res.json()
    }
  })

  // Update IAP configuration
  const updateMutation = useMutation({
    mutationFn: async (updates: Partial<IAPConfig>[]) => {
      const res = await fetch('/api/admin/iap/config', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ updates })
      })
      if (!res.ok) throw new Error('Failed to update IAP config')
      return res.json()
    },
    onSuccess: () => {
      toast.success('IAP configuration updated')
      queryClient.invalidateQueries({ queryKey: ['iap-config'] })
      setIsEditing(false)
    },
    onError: (error) => {
      toast.error(`Failed to update: ${error.message}`)
    }
  })

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-6">In-App Purchase Configuration</h1>

      {/* Provider and Environment Selector */}
      <div className="flex gap-4 mb-6">
        <select
          value={selectedProvider}
          onChange={(e) => setSelectedProvider(e.target.value as any)}
          className="px-4 py-2 border rounded"
        >
          <option value="google_play">Google Play</option>
          <option value="apple_appstore">Apple App Store</option>
        </select>

        <select
          value={selectedEnvironment}
          onChange={(e) => setSelectedEnvironment(e.target.value as any)}
          className="px-4 py-2 border rounded"
        >
          <option value="production">Production</option>
          <option value="sandbox">Sandbox</option>
        </select>
      </div>

      {/* Configuration Form */}
      <div className="bg-white rounded-lg shadow p-6">
        <h2 className="text-lg font-semibold mb-4">
          {selectedProvider === 'google_play' ? 'Google Play' : 'Apple App Store'} - {selectedEnvironment}
        </h2>

        {isLoading ? (
          <p>Loading...</p>
        ) : (
          <div className="space-y-4">
            {selectedProvider === 'google_play' && (
              <>
                <ConfigField
                  label="Service Account Email"
                  value={configs?.service_account_email || ''}
                  configKey="service_account_email"
                  isEditing={isEditing}
                />
                <ConfigField
                  label="Service Account Key (JSON)"
                  value={configs?.service_account_key ? '[ENCRYPTED]' : ''}
                  configKey="service_account_key"
                  isEditing={isEditing}
                  isSecret
                />
                <ConfigField
                  label="Package Name"
                  value={configs?.package_name || 'com.disciplefy.app'}
                  configKey="package_name"
                  isEditing={isEditing}
                />
              </>
            )}

            {selectedProvider === 'apple_appstore' && (
              <>
                <ConfigField
                  label="Shared Secret"
                  value={configs?.shared_secret ? '[ENCRYPTED]' : ''}
                  configKey="shared_secret"
                  isEditing={isEditing}
                  isSecret
                />
                <ConfigField
                  label="Bundle ID"
                  value={configs?.bundle_id || 'com.disciplefy.app'}
                  configKey="bundle_id"
                  isEditing={isEditing}
                />
              </>
            )}
          </div>
        )}

        <div className="mt-6 flex gap-3">
          {!isEditing ? (
            <button
              onClick={() => setIsEditing(true)}
              className="px-4 py-2 bg-primary text-white rounded hover:bg-primary/90"
            >
              Edit Configuration
            </button>
          ) : (
            <>
              <button
                onClick={() => updateMutation.mutate([])}  // Implement actual save logic
                className="px-4 py-2 bg-primary text-white rounded hover:bg-primary/90"
                disabled={updateMutation.isPending}
              >
                {updateMutation.isPending ? 'Saving...' : 'Save Changes'}
              </button>
              <button
                onClick={() => setIsEditing(false)}
                className="px-4 py-2 bg-gray-200 text-gray-800 rounded hover:bg-gray-300"
              >
                Cancel
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  )
}

function ConfigField({
  label,
  value,
  configKey,
  isEditing,
  isSecret = false
}: {
  label: string
  value: string
  configKey: string
  isEditing: boolean
  isSecret?: boolean
}) {
  return (
    <div>
      <label className="block text-sm font-medium mb-1">{label}</label>
      {isEditing ? (
        isSecret ? (
          <textarea
            defaultValue={value === '[ENCRYPTED]' ? '' : value}
            placeholder="Paste new value to update"
            className="w-full px-3 py-2 border rounded font-mono text-xs"
            rows={3}
          />
        ) : (
          <input
            type="text"
            defaultValue={value}
            className="w-full px-3 py-2 border rounded"
          />
        )
      ) : (
        <div className="px-3 py-2 bg-gray-50 rounded border">
          {isSecret ? '[ENCRYPTED]' : value || '(Not configured)'}
        </div>
      )}
    </div>
  )
}
```

---

## Configuration Management

### No Hardcoding Strategy

#### 1. Product IDs from Database

```sql
-- Add product_id column to subscription_plan_providers
ALTER TABLE subscription_plan_providers
  ADD COLUMN product_id TEXT;

-- Example data:
-- provider='razorpay', product_id='plan_xyz123'  (Razorpay plan ID)
-- provider='google_play', product_id='com.disciplefy.premium_monthly'
-- provider='apple_appstore', product_id='com.disciplefy.premium_monthly'

UPDATE subscription_plan_providers
SET product_id = CASE
  WHEN provider = 'razorpay' AND plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'standard')
    THEN 'plan_standard_razorpay_id'
  WHEN provider = 'google_play' AND plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'standard')
    THEN 'com.disciplefy.standard_monthly'
  WHEN provider = 'apple_appstore' AND plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'standard')
    THEN 'com.disciplefy.standard_monthly'
  -- ... repeat for plus and premium
END;
```

#### 2. Environment Detection

```typescript
// Backend: Detect environment from request headers or database flag
export function getIAPEnvironment(): 'sandbox' | 'production' {
  const env = Deno.env.get('IAP_ENVIRONMENT') || 'production'
  return env as 'sandbox' | 'production'
}
```

```dart
// Frontend: Detect from build configuration
class IAPEnvironment {
  static String get environment {
    // Use --dart-define for build-time configuration
    const environment = String.fromEnvironment('IAP_ENVIRONMENT', defaultValue: 'production');
    return environment;
  }

  static bool get isSandbox => environment == 'sandbox';
  static bool get isProduction => environment == 'production';
}
```

#### 3. API Credentials from Database

```sql
-- Store credentials in iap_config table
INSERT INTO iap_config (provider, environment, config_key, config_value, is_active) VALUES
  -- Google Play Production
  ('google_play', 'production', 'service_account_email', 'service@project.iam.gserviceaccount.com', true),
  ('google_play', 'production', 'service_account_key', '[ENCRYPTED_JSON]', true),
  ('google_play', 'production', 'package_name', 'com.disciplefy.app', true),

  -- Apple Production
  ('apple_appstore', 'production', 'shared_secret', '[ENCRYPTED]', true),
  ('apple_appstore', 'production', 'bundle_id', 'com.disciplefy.app', true),

  -- Sandbox configs...
  ('google_play', 'sandbox', 'service_account_email', 'sandbox-service@project.iam.gserviceaccount.com', true),
  ('google_play', 'sandbox', 'service_account_key', '[ENCRYPTED_JSON]', true);
```

---

## Task Breakdown

### Phase 1: Database Foundation (Week 1)

**1.1 Create IAP Tables Migration**
- File: `backend/supabase/migrations/20260214000001_iap_integration_schema.sql`
- Tasks:
  - [ ] Create `iap_config` table with encryption support
  - [ ] Create `iap_receipts` table with proper indexes
  - [ ] Create `iap_verification_logs` table
  - [ ] Create `iap_webhook_events` table
  - [ ] Alter `subscriptions` table to add IAP columns
  - [ ] Add RLS policies for all tables
  - [ ] Create database functions for config retrieval
- Estimated: 2 days

**1.2 Seed IAP Configuration**
- File: `backend/supabase/migrations/20260214000002_seed_iap_config.sql`
- Tasks:
  - [ ] Insert Google Play configuration placeholders
  - [ ] Insert Apple App Store configuration placeholders
  - [ ] Update `subscription_plan_providers` with product IDs
- Estimated: 1 day

**1.3 Test Database Schema**
- Tasks:
  - [ ] Verify all tables created successfully
  - [ ] Test RLS policies with different user roles
  - [ ] Validate database functions return expected data
  - [ ] Performance test indexes on large datasets
- Estimated: 1 day

---

### Phase 2: Backend Services (Weeks 2-3)

**2.1 IAP Configuration Service**
- File: `backend/supabase/functions/_shared/services/iap-config-service.ts`
- Tasks:
  - [ ] Implement `getIAPConfig()` with 5-minute caching
  - [ ] Implement `clearIAPConfigCache()`
  - [ ] Add environment detection logic
  - [ ] Add configuration validation
- Estimated: 1 day

**2.2 Google Play Validator**
- File: `backend/supabase/functions/_shared/services/google-play-validator.ts`
- Tasks:
  - [ ] Add `jose` library for JWT signing
  - [ ] Implement `validateGooglePlayReceipt()`
  - [ ] Implement `getGoogleAccessToken()` using service account
  - [ ] Implement `signJWT()` using RS256
  - [ ] Implement `acknowledgeGooglePlayPurchase()`
  - [ ] Add comprehensive error handling
  - [ ] Add unit tests with mock responses
- Estimated: 3 days

**2.3 Apple App Store Validator**
- File: `backend/supabase/functions/_shared/services/apple-appstore-validator.ts`
- Tasks:
  - [ ] Implement `validateAppleReceipt()`
  - [ ] Handle sandbox/production auto-retry
  - [ ] Parse Apple receipt response correctly
  - [ ] Add comprehensive error handling
  - [ ] Add unit tests with mock responses
- Estimated: 2 days

**2.4 Unified Receipt Validation Service**
- File: `backend/supabase/functions/_shared/services/receipt-validation-service.ts`
- Tasks:
  - [ ] Implement `validateAndProcessReceipt()`
  - [ ] Implement `revalidateReceipt()` for renewals
  - [ ] Store receipts with encryption
  - [ ] Create/update subscription records
  - [ ] Log all validation attempts
  - [ ] Add comprehensive error handling
- Estimated: 2 days

**2.5 Update Subscription V2 Edge Function**
- File: `backend/supabase/functions/create-subscription-v2/index.ts`
- Tasks:
  - [ ] Add receipt parameter handling
  - [ ] Route to IAP validation for Google/Apple
  - [ ] Route to Razorpay for web
  - [ ] Return appropriate response for each provider
  - [ ] Add integration tests
- Estimated: 2 days

**2.6 Webhook Handlers**
- Files:
  - `backend/supabase/functions/google-play-webhook/index.ts` (NEW)
  - `backend/supabase/functions/apple-appstore-webhook/index.ts` (NEW)
- Tasks:
  - [ ] Create Google Play webhook endpoint
  - [ ] Create Apple App Store webhook endpoint
  - [ ] Verify webhook signatures
  - [ ] Process subscription events (renewed, cancelled, refunded)
  - [ ] Store events in `iap_webhook_events` table
  - [ ] Update subscription status accordingly
  - [ ] Add deduplication logic
- Estimated: 3 days

---

### Phase 3: Frontend Integration (Weeks 4-5)

**3.1 Add Dependencies**
- File: `frontend/pubspec.yaml`
- Tasks:
  - [ ] Add `in_app_purchase: ^3.1.0`
  - [ ] Add `in_app_purchase_android`
  - [ ] Add `in_app_purchase_storekit`
  - [ ] Run `flutter pub get`
- Estimated: 0.5 days

**3.2 Platform Payment Provider Service**
- File: `frontend/lib/core/services/platform_payment_provider_service.dart`
- Tasks:
  - [ ] Implement `getProvider()` with platform detection
  - [ ] Implement `isIAPPlatform()`
  - [ ] Implement `getProviderDisplayName()`
  - [ ] Add unit tests
- Estimated: 0.5 days

**3.3 IAP Service**
- File: `frontend/lib/core/services/iap_service.dart`
- Tasks:
  - [ ] Implement `initialize()`
  - [ ] Implement `getProducts()`
  - [ ] Implement `purchaseProduct()`
  - [ ] Implement `restorePurchases()`
  - [ ] Implement purchase stream listener
  - [ ] Implement receipt extraction (Android & iOS)
  - [ ] Add error handling for all scenarios
  - [ ] Add unit tests with mock purchases
- Estimated: 3 days

**3.4 Update Pricing Service**
- File: `frontend/lib/core/services/pricing_service.dart`
- Tasks:
  - [ ] Add `productId` field to `PlanPrice` model
  - [ ] Fetch product IDs from backend API
  - [ ] Add `getProductId(planCode, provider)` method
  - [ ] Update caching to include product IDs
- Estimated: 1 day

**3.5 Update Subscription Models**
- File: `frontend/lib/features/subscription/data/models/subscription_v2_models.dart`
- Tasks:
  - [ ] Add `receipt` field to `CreateSubscriptionV2Request`
  - [ ] Update serialization/deserialization
- Estimated: 0.5 days

**3.6 Update Subscription BLoC**
- File: `frontend/lib/features/subscription/presentation/bloc/subscription_bloc.dart`
- Tasks:
  - [ ] Inject `IAPService` dependency
  - [ ] Update `_onCreateSubscription()` to use dynamic provider
  - [ ] Implement `_handleIAPSubscription()`
  - [ ] Implement `_handleWebSubscription()`
  - [ ] Implement IAP purchase callbacks
  - [ ] Add receipt data to V2 API calls
  - [ ] Update all subscription creation methods (standard, plus, premium)
  - [ ] Add restore purchases event handler
  - [ ] Add integration tests
- Estimated: 3 days

**3.7 Update Subscription UI**
- Files:
  - `frontend/lib/features/subscription/presentation/pages/my_plan_page.dart`
  - `frontend/lib/features/subscription/presentation/widgets/plan_card.dart`
- Tasks:
  - [ ] Update purchase button to show platform-specific text
  - [ ] Add "Restore Purchases" button for iOS
  - [ ] Update loading states for IAP flow
  - [ ] Add IAP-specific error messages
  - [ ] Test on both Android and iOS devices
- Estimated: 2 days

**3.8 Register Services in DI**
- File: `frontend/lib/core/di/injection_container.dart`
- Tasks:
  - [ ] Register `IAPService`
  - [ ] Register `PlatformPaymentProviderService`
  - [ ] Update `SubscriptionBloc` injection
- Estimated: 0.5 days

---

### Phase 4: Admin Web Tools (Week 6)

**4.1 IAP Configuration API**
- File: `admin-web/app/api/admin/iap/config/route.ts`
- Tasks:
  - [ ] GET endpoint to fetch IAP configuration
  - [ ] PATCH endpoint to update configuration
  - [ ] Encrypt sensitive values before storing
  - [ ] Add admin-only access control
  - [ ] Add validation for required fields
- Estimated: 1 day

**4.2 IAP Configuration Page**
- File: `admin-web/app/(dashboard)/iap-config/page.tsx`
- Tasks:
  - [ ] Create provider/environment selector
  - [ ] Display Google Play configuration fields
  - [ ] Display Apple App Store configuration fields
  - [ ] Implement edit mode
  - [ ] Implement save functionality with encryption
  - [ ] Add validation and error handling
- Estimated: 2 days

**4.3 Receipt Verification Tool**
- File: `admin-web/app/(dashboard)/iap-receipts/page.tsx`
- Tasks:
  - [ ] List all IAP receipts with filters
  - [ ] Show validation status and details
  - [ ] Add manual re-validation button
  - [ ] Display verification logs
  - [ ] Add search by transaction ID or user
- Estimated: 2 days

**4.4 Product ID Management**
- File: `admin-web/app/(dashboard)/system-config/page.tsx` (Update existing)
- Tasks:
  - [ ] Add product ID field to pricing editor
  - [ ] Allow editing product IDs per provider/plan
  - [ ] Validate product ID format
  - [ ] Update pricing API to handle product IDs
- Estimated: 1 day

---

### Phase 5: Testing & QA (Week 7)

**5.1 Unit Tests**
- Tasks:
  - [ ] Backend: Test all IAP validation services
  - [ ] Backend: Test configuration service
  - [ ] Frontend: Test IAP service with mocks
  - [ ] Frontend: Test subscription BLoC IAP flow
- Estimated: 2 days

**5.2 Integration Tests**
- Tasks:
  - [ ] Test Google Play sandbox purchases
  - [ ] Test Apple App Store sandbox purchases
  - [ ] Test receipt validation end-to-end
  - [ ] Test subscription activation after IAP
  - [ ] Test webhook event processing
- Estimated: 2 days

**5.3 Platform Testing**
- Tasks:
  - [ ] Test on Android physical device
  - [ ] Test on iOS physical device
  - [ ] Test on web browser
  - [ ] Test restore purchases on iOS
  - [ ] Test subscription renewals
- Estimated: 1 day

---

## Security & Compliance

### 1. Receipt Encryption

```typescript
// Backend: Encrypt receipts before storing
import { encrypt, decrypt } from './encryption-service.ts'

async function storeReceipt(receiptData: string): Promise<string> {
  const encrypted = await encrypt(receiptData, process.env.ENCRYPTION_KEY!)
  return encrypted
}
```

### 2. API Credentials Security

- Store Google Play service account keys encrypted in database
- Store Apple shared secret encrypted in database
- Use Supabase Vault for encryption keys
- Never log sensitive credentials

### 3. Receipt Validation Security

- Always validate receipt signature
- Check transaction ID uniqueness to prevent replay attacks
- Verify bundle ID / package name matches app
- Validate expiry dates server-side

### 4. Webhook Security

```typescript
// Verify Google Play webhook signature
function verifyGooglePlayWebhook(signature: string, payload: string): boolean {
  // Implement signature verification using Google's public key
  return true
}

// Verify Apple App Store webhook signature
function verifyAppleWebhook(signature: string, payload: string): boolean {
  // Implement signature verification
  return true
}
```

---

## Risk Assessment

### High Risk

1. **Receipt Fraud**
   - **Mitigation**: Always validate with Google/Apple servers, never trust client
   - **Mitigation**: Check transaction ID uniqueness
   - **Mitigation**: Implement rate limiting on validation endpoint

2. **Credential Exposure**
   - **Mitigation**: Encrypt all credentials in database
   - **Mitigation**: Use environment variables for encryption keys
   - **Mitigation**: Restrict admin access to IAP config

### Medium Risk

3. **Webhook Replay Attacks**
   - **Mitigation**: Use notification_id for deduplication
   - **Mitigation**: Verify webhook signatures
   - **Mitigation**: Implement idempotent processing

4. **Subscription State Mismatch**
   - **Mitigation**: Regularly re-validate active subscriptions
   - **Mitigation**: Process webhooks for renewals/cancellations
   - **Mitigation**: Add reconciliation job

### Low Risk

5. **Cache Staleness**
   - **Mitigation**: Use 5-minute cache TTL
   - **Mitigation**: Manual cache clear in admin tools

---

## Success Criteria

### Functional Requirements

✅ **Google Play Integration**
- [ ] Users can purchase subscriptions via Google Play
- [ ] Receipts are validated with Google API
- [ ] Subscriptions are activated upon validation
- [ ] Renewals are processed automatically via webhooks

✅ **Apple App Store Integration**
- [ ] Users can purchase subscriptions via App Store
- [ ] Receipts are validated with Apple API
- [ ] Subscriptions are activated upon validation
- [ ] Users can restore previous purchases

✅ **Multi-Platform Support**
- [ ] Web users continue using Razorpay
- [ ] Android users use Google Play
- [ ] iOS users use App Store
- [ ] Platform detection is automatic

✅ **Admin Tools**
- [ ] Admins can configure IAP credentials
- [ ] Admins can view all IAP transactions
- [ ] Admins can manually verify receipts
- [ ] Product IDs are managed in database

### Non-Functional Requirements

✅ **Security**
- [ ] All receipts encrypted at rest
- [ ] API credentials encrypted in database
- [ ] Webhook signatures verified
- [ ] No hardcoded secrets in code

✅ **Performance**
- [ ] Receipt validation < 3 seconds
- [ ] Configuration cached for 5 minutes
- [ ] Webhook processing < 1 second
- [ ] No database queries in hot path

✅ **Maintainability**
- [ ] Zero hardcoded configuration
- [ ] All providers managed via database
- [ ] Comprehensive logging and monitoring
- [ ] Clear error messages

---

## Deployment Plan

### Pre-Deployment

1. **Google Play Console Setup**
   - Create subscription products
   - Configure service account
   - Set up real-time developer notifications
   - Test with sandbox accounts

2. **Apple App Store Connect Setup**
   - Create subscription products
   - Configure shared secret
   - Set up App Store Server Notifications
   - Test with sandbox accounts

3. **Database Preparation**
   - Run IAP migrations on production
   - Seed IAP configuration with production credentials
   - Verify RLS policies are active

### Deployment Steps

1. **Backend Deployment (Week 7)**
   - Deploy Edge Functions with IAP services
   - Deploy webhook endpoints
   - Configure webhook URLs in Google/Apple consoles
   - Monitor logs for errors

2. **Frontend Deployment (Week 7)**
   - Deploy Flutter web with no changes (continues using Razorpay)
   - Release Android app with IAP integration
   - Release iOS app with IAP integration
   - Monitor purchase success rate

3. **Post-Deployment Monitoring (Week 8)**
   - Monitor IAP transaction volume
   - Check receipt validation success rate
   - Verify webhook processing
   - Address any user-reported issues

---

## Appendix

### Product ID Naming Convention

```
Format: com.disciplefy.{plan_code}_{interval}

Examples:
- com.disciplefy.standard_monthly
- com.disciplefy.plus_monthly
- com.disciplefy.premium_monthly
```

### Error Codes

```
IAP_001: Receipt validation failed
IAP_002: Product not found
IAP_003: Invalid receipt format
IAP_004: Google Play API error
IAP_005: Apple API error
IAP_006: Purchase already processed
IAP_007: Subscription already active
IAP_008: Configuration missing
```

### Monitoring Queries

```sql
-- Daily IAP transaction volume
SELECT
  provider,
  DATE(created_at) as date,
  COUNT(*) as transactions,
  COUNT(CASE WHEN validation_status = 'valid' THEN 1 END) as valid,
  COUNT(CASE WHEN validation_status = 'invalid' THEN 1 END) as invalid
FROM iap_receipts
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY provider, DATE(created_at)
ORDER BY date DESC;

-- Webhook processing status
SELECT
  provider,
  processing_status,
  COUNT(*) as count
FROM iap_webhook_events
WHERE received_at >= NOW() - INTERVAL '7 days'
GROUP BY provider, processing_status;
```

---

**End of Implementation Plan**

This comprehensive plan provides a complete roadmap for integrating Google Play and Apple App Store In-App Purchases into the Disciplefy Bible Study application with zero hardcoding and full database-driven configuration.
