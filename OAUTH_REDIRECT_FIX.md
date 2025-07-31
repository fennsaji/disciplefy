# OAuth Redirect Fix - Final Steps

## Problem Fixed
- Google OAuth was redirecting to Flutter app (`localhost:59641/auth/callback`) instead of Supabase (`127.0.0.1:54321/auth/v1/callback`)
- This prevented proper PKCE token exchange and session establishment

## Changes Made

### 1. Fixed Supabase Configuration
Updated `backend/supabase/config.toml`:
```toml
redirect_uri = "http://127.0.0.1:54321/auth/v1/callback"
```

### 2. Added Router Refresh Mechanism
- Created `AuthNotifier` to listen to Supabase auth state changes
- Added `refreshListenable: _authNotifier` to GoRouter
- Router now automatically refreshes when OAuth session is established

## Required Actions

### 1. Restart Supabase Server
```bash
cd backend
supabase stop
supabase start
```

### 2. Update Google Cloud Console
Go to [Google Cloud Console](https://console.cloud.google.com/) and:

1. Navigate to **APIs & Services > Credentials**
2. Find your OAuth 2.0 Client ID
3. Update **Authorized redirect URIs** to include:
   ```
   http://127.0.0.1:54321/auth/v1/callback
   ```
4. Remove any old URIs like:
   ```
   http://localhost:59641/auth/callback
   http://127.0.0.1:3000/?code=...
   ```
5. Save changes

### 3. Test OAuth Flow
1. Start Flutter web app: `cd frontend && sh scripts/run_web_local.sh`
2. Go to login page
3. Click "Sign in with Google"
4. Complete OAuth flow
5. Should redirect to home page automatically

## Expected Behavior
1. User clicks "Sign in with Google"
2. Google redirects to `127.0.0.1:54321/auth/v1/callback`
3. Supabase handles PKCE token exchange
4. Session is established in Supabase
5. AuthNotifier detects auth state change
6. Router refreshes and redirects to home page

## Troubleshooting
If OAuth still fails:
1. Check console logs for redirect URI mismatch errors
2. Verify Supabase server is running on `127.0.0.1:54321`
3. Confirm Google Console has the correct redirect URI
4. Clear browser cache and cookies for the app