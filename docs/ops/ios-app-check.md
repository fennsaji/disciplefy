# iOS App Check (Google Sign-In + Firebase)

Why: Google Cloud console warns that the iOS OAuth client is not using App
Check. This adds App Check so enforcement can be turned on for that client
later. Enforcement is **off**; every App Check failure is logged and sign-in
continues without a token.

## What was added

| Where | Change |
|---|---|
| `frontend/ios/Runner/AppDelegate.swift` | `configureGoogleSignInAppCheck()` runs right after `FirebaseApp.configure()`. Release/Profile on device: `GIDSignIn.sharedInstance.configure(completion:)` (App Attest). Debug builds and the simulator: `GIDSignIn.sharedInstance.configureDebugProvider(withAPIKey:)` with the iOS API key from `GoogleService-Info.plist`. Errors are logged (`[AppCheck]`, domain + code only). |
| `frontend/ios/Runner/Info.plist` | `GIDClientID` = iOS OAuth client ID. Google Sign-In names its App Check resource `oauthClients/<GIDClientID>`, so without it no valid token is produced. Same value as `CLIENT_ID` in `GoogleService-Info.plist`. |
| `frontend/ios/Runner/Runner.entitlements` | `com.apple.developer.devicecheck.appattest-environment` = `production`. App Check rejects sandbox tokens. (TestFlight/App Store builds always use production anyway.) |
| `frontend/ios/Runner.xcodeproj/project.pbxproj` | `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG` on the Runner **Debug** config only, so `#if DEBUG` works in Swift. |
| `frontend/pubspec.yaml` | `firebase_app_check: 0.3.2+10` (last release on the `firebase_core` 3.x line; 0.4.x needs `firebase_core` 4). |
| `frontend/lib/main.dart` | `_activateAppCheck()` after `Firebase.initializeApp()`, **iOS only**: `AppleProvider.appAttestWithDeviceCheckFallback` in release, `AppleProvider.debug` in debug. Failures logged with `Logger.warning` (error type only). |
| `frontend/web/index.html` | `window.flutterfire_ignore_scripts = ['app_check']` so web does not download the unused App Check JS SDK. |

Not changed: Android (no activation, no Play Integrity), web behaviour, the
Dart Google Sign-In / Supabase `signInWithIdToken` flow.

Two separate App Check clients run on iOS:
- **Google Sign-In** (native, AppCheckCore) attaches a limited-use token to the
  OAuth request. This is what the OAuth client enforcement checks.
- **Firebase App Check** (Flutter plugin) covers Firebase services. It is only
  reporting metrics today.

The `google_sign_in` 7.x Flutter plugin does not expose App Check, so the
native `GIDSignIn` call in `AppDelegate.swift` is required. It must run before
the first sign-in, which it does (launch).

## Before the next App Store / TestFlight build (required)

CI signs with a fastlane **match** App Store profile (`readonly: true`). The
new entitlement must be in that profile, or the archive fails with "profile
doesn't include the com.apple.developer.devicecheck.appattest-environment
entitlement".

1. Apple Developer → Certificates, IDs & Profiles → Identifiers →
   `com.disciplefy.biblestudy` → enable **App Attest** → Save.
2. Regenerate the match App Store profile so it picks up the capability, e.g.
   `fastlane match appstore --force` (not readonly) from `frontend/ios`, which
   updates the profile in the match git repo.
3. Local development builds with automatic signing pick it up on their own.

## Console steps for the owner

### 1. Register the iOS app in Firebase App Check (done)
Firebase console → App Check → Apps → iOS app → **App Attest** (DeviceCheck
can be registered too, as the Firebase fallback). Every OAuth client must be
linked to an app; unlinked clients are flagged on that page.

### 2. Debug tokens for simulators / debug builds
1. Run a debug build. Xcode console prints a line after
   `App Check debug token:` (one from Google Sign-In, one from Firebase App
   Check; they may be the same or different).
2. Firebase console → App Check → Apps → overflow menu → **Manage debug
   tokens** → add each token.
3. The debug provider uses the iOS API key from `GoogleService-Info.plist`; if
   that key has API restrictions, allow **Firebase App Check API**.
4. Never commit debug tokens; revoke any leaked token.

### 3. Monitor
Firebase console → App Check → APIs → Google Identity for iOS (and Firebase
services). Watch the share of **verified** vs **unverified/outdated client**
requests after the new build ships.

### 4. Enforce (only later)
Turn on enforcement for the iOS OAuth client (Google Cloud console → APIs &
Services → Credentials → iOS client, or Firebase App Check → Enforce) only
once nearly all sign-in traffic is verified, i.e. the new build is widely
adopted. Older app versions without App Check will fail Google Sign-In after
enforcement. Enforcement adds a little sign-in latency.

## Android OAuth clients: verify ownership

Google Cloud console → APIs & Services → Credentials:
1. Open each **Android** OAuth client → **Verify ownership** → follow the Play
   Console flow (the app must be published in Play Console under the same
   account; the client's package name and SHA-1 must match Play App Signing or
   the upload key).
2. Delete the unused Android client that was created with the **debug** key
   SHA-1 (keep the Play App Signing / upload key clients and the Web client
   used as `serverClientId`). Check its client ID is not referenced in
   `google-services.json` or env files before deleting.

## Sources
- https://developers.google.com/identity/sign-in/ios/appcheck (+ get-started, debug-provider)
- GoogleSignIn-iOS 9.2.0 `GIDSignIn.h` / `GIDAppCheck.m`
- https://firebase.google.com/docs/app-check/flutter/default-providers
- Apple: App Attest Environment entitlement
