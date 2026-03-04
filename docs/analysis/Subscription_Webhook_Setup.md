# Subscription Webhook Setup Guide

External configuration steps required to connect Google Play and Apple App Store billing
events to the Disciplefy backend Edge Functions.

---

## Google Play Real-Time Developer Notifications (RTDN)

Google Play sends subscription lifecycle events via Cloud Pub/Sub push subscriptions.

### Step 1 — Create Pub/Sub Topic

1. Open [Google Cloud Console](https://console.cloud.google.com/) for your Firebase/GCP project.
2. Navigate to **Pub/Sub → Topics**.
3. Click **Create Topic**.
4. Set Topic ID to `app-billing`.
5. Click **Create**.

### Step 2 — Create Push Subscription

1. On the topic list, click `app-billing`.
2. Click **Create Subscription**.
3. Set:
   - **Subscription ID**: `app-billing-push`
   - **Delivery type**: Push
   - **Endpoint URL**:
     ```
     https://[SUPABASE_PROJECT_REF].supabase.co/functions/v1/google-play-webhook
     ```
   - **Enable authentication**: Toggle on
   - **Service account**: Select or create a service account with `Pub/Sub Subscriber` role
   - **Audience**: `https://[SUPABASE_PROJECT_REF].supabase.co/functions/v1/google-play-webhook`
4. Click **Create**.

### Step 3 — Configure Play Console

1. Open [Google Play Console](https://play.google.com/console/).
2. Select your app.
3. Navigate to **Monetize → Subscriptions**.
4. Click **Real-time developer notifications**.
5. Set **Topic name**:
   ```
   projects/[GCP_PROJECT_ID]/topics/app-billing
   ```
6. Click **Save**.
7. Click **Send test notification** to verify connectivity.

### Step 4 — Grant Pub/Sub Publish Permission

Google Play needs permission to publish to your topic:

1. In Cloud Console → Pub/Sub → Topics → `app-billing` → **Permissions**.
2. Add member: `google-play-developer-notifications@system.gserviceaccount.com`
3. Assign role: **Pub/Sub Publisher**
4. Save.

### Supabase Secrets (Google Play)

Set the Pub/Sub audience secret so the Edge Function can validate OIDC tokens from Google:

```bash
supabase secrets set PUBSUB_AUDIENCE="https://[SUPABASE_PROJECT_REF].supabase.co/functions/v1/google-play-webhook"
```

---

## Apple App Store Server Notifications

Apple sends subscription lifecycle events directly via HTTPS POST to a registered URL.

### Step 1 — Register Notification URLs

1. Open [App Store Connect](https://appstoreconnect.apple.com/).
2. Select your app.
3. Navigate to **App Information**.
4. Scroll to **App Store Server Notifications**.
5. Set **Production Server URL**:
   ```
   https://[SUPABASE_PROJECT_REF].supabase.co/functions/v1/apple-appstore-webhook
   ```
6. Set **Sandbox Server URL** (same endpoint — the function detects environment from payload):
   ```
   https://[SUPABASE_PROJECT_REF].supabase.co/functions/v1/apple-appstore-webhook
   ```
7. Click **Save**.

### Step 2 — Verify Connectivity

Use the App Store Connect API or the **Send Test Notification** button (if available) to
confirm Apple can reach your endpoint. The Edge Function logs all incoming notifications —
check Supabase Edge Function logs to verify receipt.

### Apple JWT Verification

Apple signs all notification payloads with ES256 using keys published at:
```
https://appleid.apple.com/auth/keys
```

The `apple-appstore-webhook` Edge Function fetches these keys and verifies the signature
before processing any event. No additional configuration is required — the keys are fetched
automatically and cached for 1 hour.

---

## Supabase Edge Function Deployment

Ensure both webhook functions are deployed and accessible:

```bash
# Deploy Google Play webhook
supabase functions deploy google-play-webhook --no-verify-jwt

# Deploy Apple App Store webhook
supabase functions deploy apple-appstore-webhook --no-verify-jwt
```

> **Note**: `--no-verify-jwt` is required because these endpoints receive unauthenticated
> requests from Google/Apple. Security is instead enforced by:
> - Google Play: OIDC token verification via Pub/Sub service account
> - Apple: JWT signature verification with Apple's public ES256 keys

---

## Verification Checklist

| Check | Google Play | Apple |
|-------|-------------|-------|
| Topic/URL configured in console | Pub/Sub topic name in Play Console | URL in App Store Connect |
| Push delivery reachable | Test notification from Play Console | Check Edge Function logs |
| Signature verification | OIDC token from service account | Apple ES256 JWT verified |
| Events appear in `iap_webhook_events` table | Yes | Yes |
| Subscription status updated in `subscriptions` table | Yes | Yes |

---

## Troubleshooting

### Google Play — No events received
- Verify the Pub/Sub topic name matches exactly (including project ID).
- Confirm `google-play-developer-notifications@system.gserviceaccount.com` has Publisher role.
- Check that the push subscription endpoint URL is correct and the function is deployed.

### Apple — Notifications not arriving
- Confirm the URL is saved in App Store Connect (both Production and Sandbox).
- The URL must be publicly reachable (Supabase Edge Functions are public by default).
- Check Edge Function logs for any 4xx/5xx responses.

### Duplicate events
Both webhooks implement idempotency via the `iap_webhook_events` table. Duplicate
`notification_id` / `notificationUUID` values are detected and skipped automatically.
