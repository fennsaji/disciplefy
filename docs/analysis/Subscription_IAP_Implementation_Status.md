# Subscription & In-App Purchase — Implementation Status

**Date:** February 28, 2026
**Scope:** Android Google Play IAP, Apple App Store IAP, Razorpay web payments
**Status:** Code complete — external setup required before Android/iOS IAP goes live

---

## Summary

The subscription and payment system is architecturally complete across all three providers (Razorpay, Google Play, Apple App Store). Nine code bugs were fixed on Feb 28, 2026. What remains is **external configuration** — no further code changes are needed to make IAP functional, but the following setup steps must be completed before a production Android/iOS release.

---

## Code Fixes Applied (Feb 28, 2026)

| # | File | Fix |
|---|------|-----|
| 1 | `android/app/src/main/AndroidManifest.xml` | Added `com.android.vending.BILLING` permission |
| 2 | `frontend/lib/main.dart` | Added `IAPService.initialize()` at mobile startup |
| 3 | `subscription_management_page.dart` | Android/iOS shows "Manage in Play Store / App Store" instead of broken cancel buttons |
| 4 | `razorpay-webhook/index.ts` | `.single()` → `.maybeSingle()` for idempotent webhook processing |
| 5 | `create-subscription-v2/index.ts` | Percentage promo discount clamped to 0–100 |
| 6 | `iap_service.dart` | `getReceiptData()` throws on empty receipt instead of silent empty string |
| 7 | `subscription-pricing/index.ts` | Added `product_id` to response so IAP SKUs are available to frontend |
| 8 | `create-subscription-v2/index.ts` + `iap-config-service.ts` | Replaced hardcoded `'production'` environment with `APP_ENVIRONMENT` secret |
| 9 | `google-play-provider.ts` | Clarified stub — actual JWT OAuth2 validation is already in `google-play-validator.ts` |

---

## Required External Setup

### 🔴 CRITICAL — Must complete before Android IAP release

---

#### 1. Create Google Play Subscription Products

**Where:** [Google Play Console](https://play.google.com/console) → Your App → Monetize → Subscriptions

Create three subscription products with these **exact** Product IDs (must match the database):

| Product ID | Price | Plan |
|------------|-------|------|
| `com.disciplefy.standard_monthly` | ₹79 / month | Standard |
| `com.disciplefy.plus_monthly` | ₹149 / month | Plus |
| `com.disciplefy.premium_monthly` | ₹499 / month | Premium |

**Settings for each product:**
- Billing period: Monthly
- Grace period: 3 days (recommended)
- Account hold: Enable
- Pause: Enable

**After creating products:**
- Set status to **Active** (not draft)
- Add a base plan with the INR price

---

#### 2. Configure Google Play API Credentials in Database

**Note:** The JWT OAuth2 service account token flow is **already fully implemented** in:
`backend/supabase/functions/_shared/services/google-play-validator.ts`

It uses the `jose` npm library to sign JWTs and calls the Google Play `subscriptionsv2` API. No code changes are needed. You only need to create the service account and insert the credentials into the `iap_config` database table.

**Steps:**

**Step 2a — Create a Google Cloud Service Account**
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select or create project linked to your Play Console app
3. Navigate to IAM & Admin → Service Accounts → Create Service Account
4. Name it: `disciplefy-play-billing`
5. Grant role: **No role** (permissions come from Play Console)
6. Create and download the **JSON key file**

**Step 2b — Link service account to Play Console**
1. Go to Play Console → Setup → API access
2. Link to your Google Cloud project
3. Find the service account you created → Grant access
4. Role: **Finance** (minimum needed for subscription validation)

**Step 2c — Enable the API**
1. In Google Cloud Console → APIs & Services → Library
2. Enable: **Google Play Android Developer API**

**Step 2d — Insert credentials into the `iap_config` database table**

Run this SQL in your Supabase SQL editor (replace values with your real credentials):

```sql
-- Insert or update Google Play production credentials
INSERT INTO iap_config (provider, environment, config_key, config_value, is_active)
VALUES
  ('google_play', 'production', 'service_account_email',
   'disciplefy-play-billing@your-project.iam.gserviceaccount.com', true),
  ('google_play', 'production', 'service_account_key',
   '{"type":"service_account","project_id":"...","private_key":"-----BEGIN RSA PRIVATE KEY-----\n..."}',
   true),
  ('google_play', 'production', 'package_name',
   'com.disciplefy.bible_study_app', true)
ON CONFLICT (provider, environment, config_key) DO UPDATE
  SET config_value = EXCLUDED.config_value, is_active = true;
```

> **Note:** The `service_account_key` field accepts either the raw PEM private key string or the full JSON key file content. The validator reads `private_key` from the JSON if it detects a JSON object.

---

#### 3. Add App as Licence Tester (for testing IAP in debug builds)

Google Play IAP does **not** work on local debug builds unless your account is a licence tester.

**Steps:**
1. Play Console → Setup → Licence testing
2. Add your Google account email(s) to the list
3. Set response to: **RESPOND_NORMALLY**

This allows testing real IAP flows without being charged.

---

### 🟡 HIGH — Required before iOS IAP release

---

#### 4. Create Apple App Store Subscription Products

**Where:** [App Store Connect](https://appstoreconnect.apple.com) → Your App → Subscriptions

Create a subscription group (e.g., "Disciplefy Premium") and add:

| Product ID | Price | Plan |
|------------|-------|------|
| `com.disciplefy.standard_monthly` | ₹79 / month | Standard |
| `com.disciplefy.plus_monthly` | ₹149 / month | Plus |
| `com.disciplefy.premium_monthly` | ₹499 / month | Premium |

**Required localization:** Add at minimum English (India) description for each product.

**Add a sandbox tester:**
- App Store Connect → Users and Access → Sandbox Testers
- Add a test Apple ID to test purchases without real charges

---

#### 5. Add Apple Shared Secret to Supabase

The Apple receipt validation in `apple-appstore-provider.ts` requires your app's shared secret.

**Get the shared secret:**
1. App Store Connect → Your App → Subscriptions → Manage
2. Click "App-Specific Shared Secret" → Generate

**Add to Supabase:**
```bash
supabase secrets set APPLE_SHARED_SECRET="your_shared_secret_here"
```

> **Note:** The current implementation uses the legacy `verifyReceipt` API. This still works but Apple is deprecating it. Plan a future migration to the [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi) (JWT-based). Not urgent but put it on the roadmap.

---

### 🟡 MEDIUM — Should complete before any IAP release

---

#### 6. Set Environment Flag for IAP Sandbox Testing

**Code fix already applied** — `create-subscription-v2/index.ts` and `iap-config-service.ts` now both read the `APP_ENVIRONMENT` secret to determine sandbox vs production.

You only need to set the Supabase secret:

```bash
# For development/staging:
supabase secrets set APP_ENVIRONMENT="sandbox"

# For production:
supabase secrets set APP_ENVIRONMENT="production"
```

> **Default behavior:** If `APP_ENVIRONMENT` is not set, the system defaults to `'production'`. Always set this secret explicitly for dev/staging environments.

---

#### 7. Upload App to Play Store (at least Internal Testing track)

Google Play IAP requires the app to be uploaded and have a valid Play Store listing. It does not work on APKs sideloaded outside Play.

**Steps:**
1. Build a release APK/AAB: `flutter build appbundle --release`
2. Play Console → Testing → Internal testing → Create new release
3. Upload the `.aab` file
4. Add tester email(s)
5. Once published to internal track, IAP will work for testers

---

## Architecture Reference

### Product IDs in Database

Configured in migration `20260214000003_iap_integration_schema.sql` (`product_id` column of `subscription_plan_providers`):

```sql
-- Google Play (must match Play Console exactly)
'com.disciplefy.standard_monthly'  → ₹79
'com.disciplefy.plus_monthly'      → ₹149
'com.disciplefy.premium_monthly'   → ₹499

-- Apple App Store (must match App Store Connect exactly)
'com.disciplefy.standard_monthly'  → ₹79
'com.disciplefy.plus_monthly'      → ₹149
'com.disciplefy.premium_monthly'   → ₹499
```

If you ever change these SKUs, update **both** the Play/App Store Console **and** the `subscription_plan_providers` table rows.

### Payment Flow (Android)

```
User taps Subscribe (Android)
  → SubscriptionBloc._initiateIAPPurchase()
  → PricingService.getProductId() → fetches SKU from DB via subscription-pricing Edge Function
  → IAPService.getProducts({sku}) → queries Google Play Billing
  → IAPService.purchaseProduct() → opens Google Play checkout
  → User completes purchase
  → IAPService._handlePurchaseUpdate() → fires onPurchaseUpdate callback
  → SubscriptionBloc adds IAPPurchaseCompleted event
  → IAPService.getReceiptData() extracts originalJson receipt
  → SubscriptionRepository.createSubscriptionV2(provider: 'google_play', receipt: ...)
  → create-subscription-v2 Edge Function
  → GooglePlayValidator.validate() (google-play-validator.ts)  ← REQUIRES SETUP #2 (credentials in DB)
  → Subscription inserted with status='active'
  → User has premium access
```

### Key Files

| File | Purpose |
|------|---------|
| `frontend/lib/core/services/iap_service.dart` | Google Play / App Store IAP interface |
| `frontend/lib/core/services/platform_payment_provider_service.dart` | Platform detection (razorpay / google_play / apple_appstore) |
| `frontend/lib/core/services/pricing_service.dart` | Fetches SKUs and pricing from backend |
| `backend/supabase/functions/_shared/services/google-play-validator.ts` | **Active** Google Play JWT OAuth2 validator (reads credentials from `iap_config` DB) |
| `backend/supabase/functions/_shared/services/payment-providers/google-play-provider.ts` | Provider wrapper (stub — delegates validation to google-play-validator.ts) |
| `backend/supabase/functions/_shared/services/payment-providers/apple-appstore-provider.ts` | Apple receipt validation |
| `backend/supabase/functions/create-subscription-v2/index.ts` | Creates subscription after payment |
| `backend/supabase/migrations/20260214000003_iap_integration_schema.sql` | `product_id` column + SKU seed data |

---

## Checklist

### Android IAP
- [x] `com.android.vending.BILLING` permission added to AndroidManifest.xml
- [x] `IAPService.initialize()` called at app startup
- [x] Subscription management page shows "Manage in Play Store" on Android
- [x] `getReceiptData()` throws on empty receipt
- [x] `subscription-pricing` endpoint returns `product_id` so frontend can find IAP SKUs
- [x] JWT OAuth2 validation implemented in `google-play-validator.ts` (uses `jose`, reads from `iap_config` DB)
- [ ] Google Play Console: subscription products created with correct SKUs (`com.disciplefy.standard_monthly` etc.)
- [ ] Google Play Console: app uploaded to at least Internal Testing track
- [ ] Google Play Console: licence testers added
- [ ] Google Cloud: service account created and linked to Play Console
- [ ] Google Play Developer API: enabled in Google Cloud
- [ ] Database: `iap_config` rows for `google_play` / `production` inserted with real credentials and `is_active = true`

### Apple IAP
- [x] Subscription management page shows "Manage in App Store" on iOS
- [ ] App Store Connect: subscription products created with correct SKUs (`com.disciplefy.standard_monthly` etc.)
- [ ] App Store Connect: sandbox tester added
- [ ] Database: `iap_config` rows for `apple_appstore` / `production` inserted with `shared_secret` and `bundle_id`, `is_active = true`
- [ ] Future: migrate from legacy `verifyReceipt` to App Store Server API v2

### Both Platforms
- [x] `create-subscription-v2/index.ts` and `iap-config-service.ts`: use `APP_ENVIRONMENT` secret (code fix applied)
- [ ] Supabase secret `APP_ENVIRONMENT` set (default: production — set to `sandbox` for dev/staging)

### Web (Razorpay) — Already Working
- [x] Payment flow complete
- [x] Webhook processing working
- [x] Cancel / resume subscription working
- [x] Promo code discount bounds validated
- [x] Webhook race condition fixed (maybeSingle)
