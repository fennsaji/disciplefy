# Google OAuth Redirect Fix

## Problem Fixed

**Issue**: Google OAuth was redirecting to `https://disciplefy.vercel.app/` (production URL) instead of staying on the localhost domain during development.

**Root Cause**: The OAuth redirect URL was using a static configuration that didn't dynamically detect the current domain and port.

## Solution Implemented

### 1. Dynamic Origin Detection (`app_config.dart`)

Updated `AppConfig.authRedirectUrl` to dynamically detect the current browser origin:

```dart
static String get authRedirectUrl {
  if (kIsWeb) {
    // DYNAMIC FIX: Use current origin for OAuth redirects to handle localhost correctly
    final currentOrigin = _getCurrentWebOrigin();
    return '$currentOrigin/auth/callback';
  }
  // Use deep link scheme for mobile apps (both development and production)
  return 'com.disciplefy.bible_study_app://auth/callback';
}

static String _getCurrentWebOrigin() {
  if (kIsWeb) {
    try {
      // Get current origin from browser
      final origin = html.window.location.origin;
      if (kDebugMode) {
        print('🔧 [AppConfig] Dynamic web origin detected: $origin');
      }
      return origin;
    } catch (e) {
      if (kDebugMode) {
        print('🔧 [AppConfig] ⚠️ Failed to get dynamic origin, falling back to appUrl: $e');
      }
      // Fallback to configured appUrl if dynamic detection fails
      return appUrl;
    }
  }
  return appUrl;
}
```

### 2. Enhanced Debugging (`oauth_service.dart`)

Added comprehensive debugging logs to show:
- Current window location and origin
- Dynamic vs static redirect URLs
- Parsed redirect URI components
- URL validation

### 3. Environment Configuration

Updated environment files and launch script to include `APP_URL` for fallback scenarios.

## How It Works

1. **Dynamic Detection**: When user initiates Google OAuth, the app now detects the current browser origin (e.g., `http://localhost:59641`) dynamically
2. **Fallback Safety**: If dynamic detection fails, it falls back to the configured `APP_URL` environment variable
3. **Debugging**: Extensive logging helps identify any configuration issues

## Testing Instructions

### 1. Start Development Server

```bash
cd frontend
sh scripts/run_web_local.sh
```

This will:
- Load environment variables from `.env.local`
- Start Flutter web on `http://localhost:59641`
- Pass `APP_URL=http://localhost:59641` as dart-define

### 2. Test OAuth Flow

1. Navigate to login screen
2. Click "Continue with Google"
3. Complete Google OAuth flow
4. **Expected Result**: Should redirect back to `http://localhost:59641/auth/callback`
5. **Previous Issue**: Was redirecting to `https://disciplefy.vercel.app/`

### 3. Verify Debug Logs

Check browser console for logs like:
```
🔧 [AppConfig] Dynamic web origin detected: http://localhost:59641
🔐 [OAUTH SERVICE] 🚀 Starting Google OAuth flow...
🔐 [OAUTH SERVICE] - Dynamic Redirect URL: http://localhost:59641/auth/callback
🔐 [OAUTH SERVICE] - Current origin: http://localhost:59641
```

## Configuration Requirements

### Supabase Dashboard

Ensure these redirect URLs are configured in **Authentication > URL Configuration**:

```
http://localhost:59641/auth/callback
https://disciplefy.vercel.app/auth/callback
```

### Google OAuth Console

Ensure these are in your Google OAuth authorized redirect URIs:

```
http://localhost:59641/auth/callback
https://disciplefy.vercel.app/auth/callback
https://wzdcwxvyjuxjgzpnukvm.supabase.co/auth/v1/callback
```

## Files Modified

1. `/lib/core/config/app_config.dart` - Dynamic origin detection
2. `/lib/features/auth/data/services/oauth_service.dart` - Enhanced debugging
3. `/.env.local` - Added `APP_URL` environment variable
4. `/.env.dev` - Added `APP_URL` environment variable
5. `/scripts/run_web_local.sh` - Pass `APP_URL` as dart-define

## Benefits

✅ **Automatic Environment Detection**: Works on any localhost port
✅ **Development Friendly**: No more manual URL configuration
✅ **Production Safe**: Fallback mechanisms ensure production works
✅ **Debug Friendly**: Comprehensive logging for troubleshooting
✅ **Future Proof**: Works with any development port configuration

## Troubleshooting

If OAuth still redirects incorrectly:

1. Check browser console for origin detection logs
2. Verify environment variables are loaded: `flutter run` should show dart-defines
3. Ensure Supabase and Google OAuth have correct redirect URLs configured
4. Clear browser cache and restart development server

## Testing Checklist

- [ ] OAuth redirects to correct localhost URL during development
- [ ] OAuth still works in production environment
- [ ] Debug logs show correct origin detection
- [ ] Fallback works if dynamic detection fails
- [ ] Mobile OAuth (deep links) still work correctly