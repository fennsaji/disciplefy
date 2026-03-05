# Google Play Billing — End-to-End Setup Guide

**Status:** Pending — test track purchases work but backend validation is not yet active
**Last updated:** 2026-03-03

---

## Overview

The Flutter app purchases subscriptions via Google Play Billing Library 5+. After purchase, the app sends the purchase token to the `create-subscription-v2` Supabase edge function, which validates the token against the Google Play Developer API and creates a subscription row in the database.

For this flow to work, the backend needs Google Play service account credentials stored in the `iap_config` table.

---

## Architecture

```
User taps Subscribe (Android)
  └─ Google Play Billing sheet appears
       └─ Purchase completes → purchaseToken returned
            └─ iap_service.dart calls create-subscription-v2
                 └─ validateAndProcessReceipt()
                      └─ validateGooglePlayReceipt()
                           └─ getIAPConfig() → reads iap_config table
                                └─ Google Play Developer API call
                                     └─ expiryTime stored as current_period_end in DB
                                          └─ Subscription activated
```

---

## Environments

| Environment | Supabase Project | APK Built By |
|-------------|-----------------|--------------|
| Development | `wzdcwxvyjuxjgzpnukvm` (Disciplefy) | `android-deploy-testers.yml` using `SUPABASE_DEV_URL` |
| Production  | `wzdcwxvyjuxjgzpnukvm` (same project) | `android-deploy-playstore-beta.yml` / `production.yml` |

> Both environments currently point to the same Supabase project. DEV uses the same DB but separate edge function secrets.

---

## What Needs To Be Done

### Step 1 — Seed `iap_config` credentials (DEV + Production)

The `iap_config` table stores Google Play service account credentials used by the edge function to call the Google Play Developer API. Without this, receipt validation fails silently and `current_period_end` is never set.

**Run the following SQL in Supabase Dashboard → SQL Editor:**

> The service account JSON is in `frontend/android/play-billing-key.json` (gitignored — do NOT commit).
> Replace `<SERVICE_ACCOUNT_JSON>` with the full contents of that file.

```sql
INSERT INTO iap_config (provider, environment, config_key, config_value, is_active)
VALUES
  ('google_play', 'production', 'package_name',          'com.disciplefy.bible_study', true),
  ('google_play', 'production', 'service_account_email', 'play-billing@disciplefy---bible-study.iam.gserviceaccount.com', true),
  ('google_play', 'production', 'service_account_key',   '<SERVICE_ACCOUNT_JSON>', true)
ON CONFLICT (provider, environment, config_key) DO UPDATE
  SET config_value = EXCLUDED.config_value,
      is_active    = true,
      updated_at   = NOW();
```

The service account JSON is the full contents of `play-billing-key.json`. This file is gitignored and must never be committed.

---

### Step 2 — Push pending migrations

Two migrations are ready and must be deployed:

**`20260301000001_fix_subscriptions_unique_index.sql`**
Fixes the unique constraint on `subscriptions` so users can create a new subscription after cancelling. Without this, re-subscribing throws a DB constraint error.

**`20260301000002_fix_google_play_product_ids.sql`**
Corrects Google Play product IDs in `subscription_plan_providers` to match the Play Console:
- `com.disciplefy.standard_monthly`
- `com.disciplefy.plus_monthly`
- `com.disciplefy.premium_monthly`

```bash
cd backend
supabase db push --project-ref wzdcwxvyjuxjgzpnukvm
```

---

### Step 3 — Deploy edge functions

The following edge functions have been modified and need to be deployed:

| Function | Change |
|----------|--------|
| `google-play-validator.ts` | Fixed `expiryTime` parsing from `lineItems[0]` |
| `receipt-validation-service.ts` | Correctly stores `current_period_end` from `expiryDate` |
| `create-subscription-v2` | IAP flow improvements |
| `google-play-webhook` | Renewal / cancellation event handling |
| `subscription-pricing` | Pricing API used by "My Plan" page |

```bash
cd backend
supabase functions deploy --project-ref wzdcwxvyjuxjgzpnukvm
```

---

### Step 4 — Verify Play Console setup

Before testing, confirm the following in [Google Play Console](https://play.google.com/console):

- [ ] Internal Testing track has an APK/AAB uploaded
- [ ] Testers are added under Internal Testing → Testers
- [ ] Subscription products exist under Monetize → Subscriptions:
  - `com.disciplefy.standard_monthly`
  - `com.disciplefy.plus_monthly`
  - `com.disciplefy.premium_monthly`
- [ ] Service account (`play-billing@disciplefy---bible-study.iam.gserviceaccount.com`) is linked under Setup → API access with Android Publisher API permissions

---

### Step 5 — Test on internal test track

Use a **license tester account** (added in Play Console → Setup → License testing) so purchases are free and billing periods are compressed.

**Test track timing:**
| Real duration | Test track duration |
|---------------|-------------------|
| 1 month       | 5 minutes         |
| 1 year        | 30 minutes        |

**Expected behaviour after setup:**

1. Tap subscribe → Google Play billing sheet appears
2. Purchase completes → receipt sent to backend
3. Backend validates with Google Play API → `current_period_end` = now + 5 min stored in DB
4. "My Plan" page shows:
   - Correct plan name and status (Active)
   - Amount: ₹X/month (fetched from pricing API)
   - Next Billing: correct date (~5 min from purchase)
5. After 5 minutes → subscription renews automatically, `google-play-webhook` fires `SUBSCRIPTION_RENEWED` and updates `current_period_end`

---

## Known Behaviour

### `USE_MOCK=false` (current setting)
Real Google Play API is called. Requires Step 1 (credentials) to be complete.

### `USE_MOCK=true` (bypass for local dev without credentials)
Skips the API call and returns a mock result with `expiryDate = now + 30 days`. Set this in Supabase edge function secrets for local development without a real service account.

---

## `iap_config` Table Schema

```
iap_config
├── provider         TEXT  ('google_play' | 'apple_appstore')
├── environment      TEXT  ('sandbox' | 'production')
├── config_key       TEXT  ('package_name' | 'service_account_email' | 'service_account_key')
├── config_value     TEXT  (plain text — encryption via Vault planned but not yet active)
├── is_active        BOOL
└── UNIQUE(provider, environment, config_key)
```

---

## Files Changed (this sprint)

| File | What changed |
|------|-------------|
| `backend/supabase/functions/_shared/services/google-play-validator.ts` | Fixed `expiryTime` parsing from `lineItems[0]` |
| `backend/supabase/functions/_shared/services/iap-config-service.ts` | Config service reading credentials |
| `backend/supabase/functions/_shared/services/receipt-validation-service.ts` | Stores `current_period_end` from expiry |
| `backend/supabase/migrations/20260301000001_fix_subscriptions_unique_index.sql` | Partial unique index fix |
| `backend/supabase/migrations/20260301000002_fix_google_play_product_ids.sql` | Correct Play Console product IDs |
| `frontend/lib/core/services/iap_service.dart` | `GooglePlayPurchaseParam` with offer token |
| `frontend/lib/features/subscription/presentation/pages/my_plan_page.dart` | Billing date + amount display fixes |
| `frontend/lib/features/subscription/presentation/pages/subscription_management_page.dart` | Cancel dialog date fix |
| `frontend/lib/core/router/app_router.dart` | `UniqueKey()` fix for pricing page crash |
