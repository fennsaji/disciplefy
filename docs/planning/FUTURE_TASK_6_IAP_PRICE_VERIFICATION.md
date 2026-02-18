# Task #6: IAP Price Synchronization Verification

**Status**: Deferred to Post-Launch
**Priority**: Low (implement when managing 100+ active subscriptions)
**Estimated Effort**: 12-16 hours

---

## Overview

Automated verification system to check if prices in the database match actual prices configured in Google Play Console and Apple App Store Connect.

## Implementation Plan

### 1. Google Play Integration

**API Setup:**
```typescript
// Use Google Play Developer API v3
import { google } from 'googleapis';

const androidpublisher = google.androidpublisher('v3');

async function verifyGooglePlayPrice(productId: string, dbPrice: number) {
  const auth = new google.auth.GoogleAuth({
    keyFile: 'path/to/service-account.json',
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });

  const response = await androidpublisher.monetization.subscriptions.get({
    auth,
    packageName: 'com.disciplefy.app',
    productId,
  });

  const actualPrice = response.data.basePlans[0].regionalConfigs.find(
    r => r.regionCode === 'IN'
  ).price.priceMicros;

  return {
    dbPrice,
    actualPrice: actualPrice / 10000, // Convert micros to minor units
    match: dbPrice === actualPrice / 10000,
  };
}
```

### 2. Apple App Store Integration

**API Setup:**
```typescript
// Use App Store Connect API
import { AppStoreConnectAPI } from '@app-store-connect/api';

async function verifyApplePrice(productId: string, dbPrice: number) {
  const api = new AppStoreConnectAPI({
    issuerId: process.env.APPLE_ISSUER_ID,
    keyId: process.env.APPLE_KEY_ID,
    privateKey: process.env.APPLE_PRIVATE_KEY,
  });

  const subscription = await api.inAppPurchases.getSubscriptionPrice({
    id: productId,
    territory: 'IND',
  });

  const actualPrice = subscription.data.attributes.price;

  return {
    dbPrice,
    actualPrice: actualPrice * 100, // Convert to minor units
    match: dbPrice === actualPrice * 100,
  };
}
```

### 3. Edge Function: verify-iap-prices

**File:** `backend/supabase/functions/verify-iap-prices/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  // Fetch all IAP providers
  const { data: iapProviders } = await supabase
    .from('subscription_plan_providers')
    .select('*')
    .in('provider', ['google_play', 'apple_appstore']);

  const results = [];

  for (const provider of iapProviders) {
    let verification;

    if (provider.provider === 'google_play') {
      verification = await verifyGooglePlayPrice(
        provider.product_id,
        provider.base_price_minor
      );
    } else {
      verification = await verifyApplePrice(
        provider.product_id,
        provider.base_price_minor
      );
    }

    // Update database
    await supabase
      .from('subscription_plan_providers')
      .update({
        provider_price_minor: verification.actualPrice,
        sync_status: verification.match ? 'synced' : 'mismatch',
        last_verified_at: new Date().toISOString(),
      })
      .eq('id', provider.id);

    results.push({
      provider: provider.provider,
      productId: provider.product_id,
      match: verification.match,
      dbPrice: verification.dbPrice,
      actualPrice: verification.actualPrice,
    });
  }

  // Send alert if any mismatches
  const mismatches = results.filter(r => !r.match);
  if (mismatches.length > 0) {
    await sendAdminAlert(mismatches);
  }

  return new Response(JSON.stringify({ results }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
```

### 4. Scheduled Cron Job

**File:** `backend/supabase/functions/verify-iap-prices/cron.yml`

```yaml
# Run verification daily at 2 AM UTC
- name: "verify-iap-prices"
  schedule: "0 2 * * *"
  function: "verify-iap-prices"
```

### 5. Admin UI Alert

**File:** `admin-web/components/system-config/price-mismatch-alert.tsx`

```tsx
export function PriceMismatchAlert() {
  const { data: mismatches } = useQuery(['price-mismatches'], async () => {
    const res = await fetch('/api/admin/system/pricing');
    const data = await res.json();
    return data.filter((p: any) => p.syncStatus === 'mismatch');
  });

  if (!mismatches || mismatches.length === 0) return null;

  return (
    <Alert severity="error">
      <AlertTitle>⚠️ Price Mismatches Detected</AlertTitle>
      <ul>
        {mismatches.map((m: any) => (
          <li key={m.id}>
            {m.planCode} ({m.provider}): Database shows ₹{m.basePrice},
            but {m.provider} shows ₹{m.providerPrice}
          </li>
        ))}
      </ul>
      <Button onClick={() => window.open('https://play.google.com/console')}>
        Fix in Console
      </Button>
    </Alert>
  );
}
```

### 6. Database Migration

**Already have the columns (added in 20260217000001_simplified_price_updates.sql):**
- ✅ `provider_price_minor` - Stores actual price from provider
- ✅ `sync_status` - 'synced' | 'mismatch' | etc.
- ✅ `last_verified_at` - Timestamp of last verification

---

## Required API Credentials

### Google Play Developer API

1. **Create Service Account:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create service account with Android Publisher permissions
   - Download JSON key file

2. **Environment Variables:**
   ```bash
   GOOGLE_PLAY_SERVICE_ACCOUNT_KEY="path/to/key.json"
   GOOGLE_PLAY_PACKAGE_NAME="com.disciplefy.app"
   ```

### Apple App Store Connect API

1. **Create API Key:**
   - Go to [App Store Connect](https://appstoreconnect.apple.com/)
   - Users and Access → Keys → App Store Connect API
   - Generate new key with Admin access

2. **Environment Variables:**
   ```bash
   APPLE_ISSUER_ID="your-issuer-id"
   APPLE_KEY_ID="your-key-id"
   APPLE_PRIVATE_KEY="your-private-key.p8"
   ```

---

## Testing Plan

1. **Manual Test:**
   - Update Google Play price to ₹200
   - Keep database at ₹149
   - Run verification Edge Function
   - Verify `sync_status` = 'mismatch'
   - Verify alert shows in admin UI

2. **Cron Test:**
   - Wait for scheduled run
   - Check logs for execution
   - Verify database updates

3. **Integration Test:**
   - Test with all 3 plans
   - Test both Google and Apple
   - Test when prices match
   - Test when prices mismatch

---

## Deployment Checklist

- [ ] Google Play API credentials configured
- [ ] Apple App Store API credentials configured
- [ ] Edge Function deployed
- [ ] Cron job scheduled
- [ ] Admin UI alert added
- [ ] Tested in staging
- [ ] Documented in runbook

---

## When to Implement

**Trigger Criteria (any of these):**
- Managing 100+ active subscriptions
- Frequent price changes (monthly or more)
- Multiple admins managing prices
- History of price sync errors
- Compliance requirements for price accuracy

**Current Status:** NOT NEEDED for first release. Manual verification is sufficient.

---

## Estimated Effort

- **Development**: 8-12 hours
- **API Setup**: 2-3 hours
- **Testing**: 4-6 hours
- **Documentation**: 2-3 hours
- **Total**: 16-24 hours

---

## Alternative: Simple Manual Check

Instead of full automation, you could add a simple manual "Verify Prices" button:

```typescript
// admin-web/components/system-config/verify-prices-button.tsx
export function VerifyPricesButton() {
  const handleVerify = async () => {
    // Just fetch current prices and display comparison
    const dbPrices = await fetchDatabasePrices();

    alert(`
      Manual Verification Needed:
      1. Check Google Play Console: https://play.google.com/console
      2. Check Apple App Store Connect: https://appstoreconnect.apple.com
      3. Compare with database prices:
         - Standard: ₹${dbPrices.standard}
         - Plus: ₹${dbPrices.plus}
         - Premium: ₹${dbPrices.premium}
    `);
  };

  return <Button onClick={handleVerify}>Verify Prices Manually</Button>;
}
```

This is **much simpler** and good enough for first release.
