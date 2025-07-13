# Authentication Fix Testing Guide

## Issue Fixed
POST requests to `/functions/v1/study-guides` were returning 401 Unauthorized due to inconsistent authentication across API services.

## Root Cause
Different API services were using different authentication methods:
- **Working services** used live Supabase session tokens
- **Failing services** used stale tokens from secure storage + incorrect anon key as Bearer token

## Solution Applied
Created unified `ApiAuthHelper` that all services now use, ensuring consistent authentication:
- **Authenticated users**: Live Supabase session JWT as Bearer token
- **Anonymous users**: `x-session-id` header (not Bearer token)

## Files Modified
1. ✅ `lib/core/services/api_auth_helper.dart` - NEW unified authentication helper
2. ✅ `lib/features/study_generation/data/services/save_guide_api_service.dart` - Fixed to use unified helper
3. ✅ `lib/features/daily_verse/data/services/daily_verse_api_service.dart` - Fixed to use unified helper  
4. ✅ `lib/features/study_generation/data/repositories/study_repository_impl.dart` - Fixed to use unified helper

## Testing Required

### 1. Test Authenticated User Flow (Google OAuth)
- [ ] Login with Google account
- [ ] Generate a study guide
- [ ] Try to save the study guide (should work now - was failing before)
- [ ] Verify in browser dev tools that request includes: `Authorization: Bearer <jwt_token>`
- [ ] Check that NO `x-session-id` header is sent for authenticated users

### 2. Test Anonymous User Flow  
- [ ] Use app without signing in
- [ ] Generate a study guide  
- [ ] Try to access daily verse (should work)
- [ ] Verify in browser dev tools that request includes: `x-session-id: <uuid>`
- [ ] Check that NO `Authorization: Bearer` header is sent (only `apikey` header)

### 3. Test Session Transitions
- [ ] Start as anonymous user → generate study guide
- [ ] Login with Google → verify study guides still work
- [ ] Logout → verify anonymous functionality restored

### 4. Backend Verification
- [ ] Check Supabase Edge Function logs for successful authentication
- [ ] Verify no more "Authentication required" errors in backend logs
- [ ] Confirm user context is properly extracted in backend

## Debug Tools Added

The `ApiAuthHelper` includes debug logging:
```dart
ApiAuthHelper.logAuthState(); // Call this to debug current auth state
```

## Expected Behavior

### Before Fix:
```
❌ POST /functions/v1/study-guides
   Headers: { Authorization: "Bearer <anon_key>" }  // WRONG!
   Response: 401 "Authentication required. Provide either Bearer token or x-session-id header"
```

### After Fix (Authenticated User):
```
✅ POST /functions/v1/study-guides  
   Headers: { Authorization: "Bearer <valid_jwt_token>" }
   Response: 200 { success: true, data: { ... } }
```

### After Fix (Anonymous User):
```
✅ POST /functions/v1/study-guides
   Headers: { "x-session-id": "<anonymous_session_uuid>" }
   Response: 200 { success: true, data: { ... } }
```

## Quick Test Commands

Start the frontend:
```bash
cd frontend && sh scripts/run_web_local.sh
```

Open browser dev tools → Network tab → Try to save a study guide → Check the request headers.

## Success Criteria
- [ ] No more 401 Unauthorized errors when saving study guides
- [ ] Authenticated users send valid JWT tokens
- [ ] Anonymous users send session ID headers  
- [ ] All API services use consistent authentication
- [ ] Backend logs show successful authentication for all requests