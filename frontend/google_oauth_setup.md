# Google OAuth Setup for Flutter App

This document provides setup instructions for implementing Google OAuth authentication with custom backend callback in the Disciplefy Bible Study Flutter app.

## Overview

The app uses a custom Google OAuth flow that:
1. Initiates Google OAuth via `supabase_flutter` or `google_sign_in`
2. Captures the authorization code from the OAuth redirect
3. Calls our custom backend API at `/functions/v1/auth-google-callback`
4. Sets the Supabase session based on the backend response

## Platform Configuration

### Android Setup

#### 1. Update `android/app/src/main/AndroidManifest.xml`

Add the OAuth redirect scheme handler:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">
    
    <!-- Standard Flutter activity metadata -->
    <meta-data
        android:name="io.flutter.embedding.android.NormalTheme"
        android:resource="@style/NormalTheme" />
    
    <!-- OAuth redirect intent filter -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="com.disciplefy.bible_study" android:host="auth" />
    </intent-filter>
    
    <!-- Alternative Supabase scheme -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="io.supabase.flutter" android:host="login-callback" />
    </intent-filter>
</activity>
```

#### 2. Configure Google Services

Ensure you have the `google-services.json` file in `android/app/` directory with the correct OAuth client configuration.

### iOS Setup

#### 1. Update `ios/Runner/Info.plist`

Add the URL scheme configuration:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.disciplefy.bible_study.oauth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.disciplefy.bible_study</string>
        </array>
    </dict>
    <dict>
        <key>CFBundleURLName</key>
        <string>io.supabase.flutter.oauth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>io.supabase.flutter</string>
        </array>
    </dict>
</array>
```

#### 2. Configure Google Sign-In

Add the Google client ID to `Info.plist`:

```xml
<key>GIDClientID</key>
<string>587108000155-af542dhgo9rmp5hvsm1vepgqsgil438d.apps.googleusercontent.com</string>
```

## Supabase Configuration

### Auth URL Configuration

In your Supabase Dashboard, go to **Authentication > URL Configuration** and add:

**Site URL:**
```
https://your-domain.com
```

**Redirect URLs:**
```
http://localhost:59641/auth/callback
https://your-domain.com/auth/callback
com.disciplefy.bible_study://auth/callback
io.supabase.flutter://login-callback
```

### OAuth Providers

Configure Google OAuth provider in **Authentication > Providers**:

1. Enable Google provider
2. Add your Google OAuth client ID and secret
3. Configure redirect URL: `https://your-supabase-project.supabase.co/auth/v1/callback`

## Backend API Configuration

The backend callback endpoint expects:

**Endpoint:** `POST /functions/v1/auth-google-callback`

**Headers:**
- `Content-Type: application/json`
- `Authorization: Bearer SUPABASE_ANON_KEY`
- `X-Anonymous-Session-ID: <session_id>` (optional)

**Request Body:**
```json
{
  "code": "authorization_code_from_google",
  "state": "csrf_state_token"
}
```

## Testing

### Android Testing

1. Run the app on an Android device/emulator
2. Tap "Continue with Google"
3. Complete Google OAuth flow
4. Verify the app receives the callback and authenticates

### iOS Testing

1. Run the app on an iOS device/simulator
2. Tap "Continue with Google"
3. Complete Google OAuth flow
4. Verify the app receives the callback and authenticates

### Web Testing

1. Run the app in a web browser
2. Tap "Continue with Google"
3. Complete Google OAuth flow
4. Verify the redirect URL is handled correctly

## Error Handling

The implementation handles these error scenarios:

1. **User cancellation**: Shows "Google login canceled" snackbar
2. **Rate limiting**: Shows "Too many login attempts. Please try again later."
3. **CSRF validation**: Shows "Security validation failed. Please try again."
4. **Invalid request**: Shows "Invalid login request. Please try again."
5. **Network errors**: Shows "Network error. Please check your connection"

## Security Considerations

1. **CSRF Protection**: The `state` parameter is used for CSRF protection
2. **Session Migration**: Anonymous sessions are migrated to authenticated sessions
3. **Rate Limiting**: Backend implements rate limiting for OAuth callbacks
4. **Input Validation**: All OAuth parameters are validated on the backend

## Dependencies

Make sure these packages are in your `pubspec.yaml`:

```yaml
dependencies:
  supabase_flutter: ^2.0.0
  google_sign_in: ^6.1.5
  http: ^1.1.0
  url_launcher: ^6.2.1
```

## Troubleshooting

### Common Issues

1. **OAuth not working on Android**: Check that `google-services.json` is correctly configured
2. **OAuth not working on iOS**: Verify `Info.plist` has correct URL schemes
3. **Redirect not handled**: Ensure `AndroidManifest.xml` and `Info.plist` have correct intent filters
4. **Backend callback fails**: Check that the backend endpoint is running and accessible
5. **Session not persisted**: Verify Supabase session is being set correctly

### Debug Steps

1. Check console logs for OAuth flow
2. Verify backend API is receiving callback requests
3. Test OAuth flow in web browser first
4. Ensure all environment variables are set correctly

## Production Checklist

- [ ] Configure production OAuth redirect URLs
- [ ] Set production Google OAuth client credentials
- [ ] Configure production Supabase project
- [ ] Test on physical devices
- [ ] Verify rate limiting is working
- [ ] Test anonymous session migration
- [ ] Validate error handling flows