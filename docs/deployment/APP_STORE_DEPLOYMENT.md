# iOS App Store & TestFlight Deployment

Guide for shipping the Disciplefy iOS app to **TestFlight** (beta) and the **App Store** (production), plus the CI/CD automation that mirrors the existing Android Play Store workflows.

> Companion to [`PLAY_STORE_DEPLOYMENT.md`](./PLAY_STORE_DEPLOYMENT.md). The iOS pipeline intentionally mirrors the Android one: push to `main` → TestFlight (= Play internal/beta), `v*.*.*` tag → App Store (= Play production).

## Project facts

| Item | Value |
|------|-------|
| Bundle ID | `com.disciplefy.biblestudy` |
| Apple Team ID | `3M43UY7L33` |
| Version source | `frontend/pubspec.yaml` (`version: <name>+<build>`) → `CFBundleShortVersionString`/`CFBundleVersion` |
| Signing tool (CI) | **fastlane** `match` (certs/profiles) + `pilot`/`deliver` (upload) |
| Encryption | `ITSAppUsesNonExemptEncryption=false` set in `Info.plist` (app uses only HTTPS + standard hashing) |

---

## Phase 1 — One-time Apple setup (manual, requires Apple account login)

1. **Create the app record** — App Store Connect → My Apps → **+** → New App
   - Platform: iOS · Bundle ID: `com.disciplefy.biblestudy` (create in Developer portal → Identifiers first if missing)
   - Name: *Disciplefy* · SKU: `disciplefy-ios` · Primary language: English
2. **App Store Connect API key** (used by fastlane in CI — generate now) — Users & Access → Integrations → App Store Connect API → generate key with **App Manager** role → download `.p8` **once** → record **Key ID** + **Issuer ID**
3. **App Privacy questionnaire** — My Apps → App Privacy. ⚠️ The app sends user study text to OpenAI/Anthropic: declare **"User Content / Other Data"** used for app functionality. Required before review.
4. **Encryption compliance** — already handled in code via `ITSAppUsesNonExemptEncryption=false`. Revisit only if proprietary (non-standard) cryptography is ever added.
5. **Subscriptions/IAP** — if Apple IAP is used, create the subscription products in App Store Connect and ensure they match backend plan codes.

---

## Phase 2 — First TestFlight build (manual — validate before automating)

Build a signed IPA with production config:

```bash
cd frontend
flutter build ipa --release \
  --dart-define=SUPABASE_URL=https://<PROD_REF>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<prod_anon_key> \
  --dart-define=GOOGLE_CLIENT_ID=<ios_oauth_client_id> \
  --dart-define=APP_URL=https://www.disciplefy.in \
  --dart-define=FLUTTER_ENV=production \
  --dart-define=GOOGLE_CLOUD_TTS_API_KEY=<key> \
  --dart-define=RAZORPAY_KEY_ID=<key> \
  --build-name=1.0.0 --build-number=1
```

Upload via **either**:
- **Xcode**: open `build/ios/archive/Runner.xcarchive` → Distribute App → App Store Connect → Upload (Xcode auto-signs with team `3M43UY7L33`), **or**
- **Transporter** app: open the generated `.ipa` → Deliver.

Build appears in App Store Connect → **TestFlight** in ~5–15 min. Add an internal tester, install via the TestFlight app, and confirm sign-in/core flows. This validates the app record + signing before automating.

---

## Phase 3 — App Store production submission (manual, first release)

App Store Connect → your app → complete metadata:
- Screenshots (current required device sizes), description, keywords, support URL, **privacy policy URL**
- Select the TestFlight build, set pricing/availability, age rating
- **Submit for Review**

---

## Phase 4 — CI/CD automation (mirrors Android)

Uses **fastlane match + pilot** on a `macos-latest` runner.

### Workflows to add (`.github/workflows/`)
| Workflow | Trigger | Action | Android equivalent |
|----------|---------|--------|--------------------|
| `ios-deploy-testflight.yml` | push to `main` (paths: `frontend/**`) + `workflow_dispatch` | fastlane build + `pilot upload` to TestFlight | `android-deploy-playstore-beta.yml` |
| `ios-deploy-appstore.yml` | push tag `v[0-9]*.[0-9]*.[0-9]*` + `workflow_dispatch` | `deliver` submit to App Store | `android-deploy-playstore-production.yml` |

Build-number convention to match Android: TestFlight uses `github.run_number`; production offsets (`+10000`) so prod builds always exceed beta.

### Files to add
- `frontend/ios/fastlane/Fastfile` — `beta` lane (build + pilot) and `release` lane (deliver)
- `frontend/ios/fastlane/Appfile` — bundle ID, Apple ID, team ID
- `frontend/ios/fastlane/Matchfile` — cert repo URL + type `appstore`
- `frontend/ios/Gemfile` — pins fastlane
- `frontend/ios/ExportOptions.plist` — `method=app-store`, team `3M43UY7L33`

### One-time `match` init (run locally)
Create a **private** git repo for certificates, then:
```bash
cd frontend/ios
fastlane match appstore   # generates + stores distribution cert + provisioning profile
```

### GitHub Secrets required
Collect during Phases 1–2:

| Secret | Source |
|--------|--------|
| `APP_STORE_CONNECT_API_KEY_ID` | Phase 1 step 2 (Key ID) |
| `APP_STORE_CONNECT_ISSUER_ID` | Phase 1 step 2 (Issuer ID) |
| `APP_STORE_CONNECT_API_KEY_P8` | the `.p8` contents, base64-encoded |
| `MATCH_GIT_URL` | private cert repo URL |
| `MATCH_PASSWORD` | match encryption passphrase |
| `MATCH_GIT_BASIC_AUTH` | base64 `user:token` for the cert repo |
| `GOOGLE_SERVICE_INFO_PLIST` | `GoogleService-Info.plist`, base64-encoded |

Reuse existing dart-define secrets: `SUPABASE_PROJECT_REF`, `SUPABASE_ANON_KEY`, `GOOGLE_OAUTH_CLIENT_ID_*`, `GOOGLE_CLOUD_TTS_API_KEY`, `RAZORPAY_KEY_ID`.

---

## Release process (once CI is live)

- **TestFlight build**: merge to `main` → `ios-deploy-testflight.yml` auto-builds and uploads. (Same trigger as Android beta.)
- **Production release**:
  1. Bump `version:` in `frontend/pubspec.yaml`
  2. Tag: `git tag v1.0.0 && git push origin v1.0.0`
  3. Both `ios-deploy-appstore.yml` and `android-deploy-playstore-production.yml` fire from the same tag.

---

## Gotchas

- iOS CI **must** run on macOS runners (more GH minutes than Android's ubuntu).
- The Supabase **production** dashboard must include the redirect URL `com.disciplefy.biblestudy://auth/callback` (Authentication → URL Configuration) for OAuth deep-links.
- First App Store review is manual and can take 24–48h; TestFlight external testers also require a (lighter) Beta App Review.
- Keep `CFBundleVersion` (build number) strictly increasing per upload, or App Store Connect rejects the binary.
