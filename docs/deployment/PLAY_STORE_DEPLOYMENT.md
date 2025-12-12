# Play Store Deployment Guide

## Overview

This guide covers the automated CI/CD pipeline for publishing the Disciplefy app to Google Play Store using GitHub Actions.

## Quick Start

**Only 1 new secret needed:** `PLAY_STORE_SERVICE_ACCOUNT_JSON`

All other secrets are already configured from existing workflows.

### To Deploy Beta (Before Jan 1st):
```bash
git push origin main  # Auto-deploys to Internal Testing track
```

### To Deploy Production (Jan 1st onwards):
```bash
# Create a GitHub Release with tag v1.0.0
# Or manually trigger the production workflow
```

---

## Workflow Files

| Workflow | File | Purpose |
|----------|------|---------|
| Beta | `.github/workflows/android-deploy-playstore-beta.yml` | Deploy to Internal Testing track |
| Production | `.github/workflows/android-deploy-playstore-production.yml` | Deploy to Production with staged rollout |
| Firebase Testers | `.github/workflows/android-deploy-testers.yml` | Deploy APK to Firebase App Distribution (dev) |

---

## Deployment Tracks

### 1. Internal Testing (Beta) - `android-deploy-playstore-beta.yml`

**Trigger:**
- Push to `main` branch (frontend changes)
- Manual workflow dispatch

**What it does:**
1. Builds release AAB with production config
2. Signs with upload keystore
3. Uploads to Play Store **Internal Testing** track
4. Creates GitHub pre-release tag

**Configuration:**
```yaml
track: internal
status: completed
```

### 2. Production - `android-deploy-playstore-production.yml`

**Trigger:**
- GitHub Release published
- Manual workflow dispatch with options

**What it does:**
1. Builds release AAB with production config
2. Signs with upload keystore
3. Uploads to Play Store **Production** track
4. Uses staged rollout (10% → 25% → 50% → 100%)

**Configuration:**
```yaml
track: production
status: inProgress
userFraction: 0.1  # 10% initial rollout
```

**Manual Trigger Options:**
- `version_name`: Version string (e.g., "1.0.0")
- `release_notes`: What's new text
- `rollout_percentage`: 10, 25, 50, or 100

---

## Required GitHub Secrets

### Android Signing (Already configured ✅)
| Secret | Description |
|--------|-------------|
| `ANDROID_KEYSTORE_BASE64` | Base64 encoded upload keystore (.jks file) |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_KEY_ALIAS` | Key alias name |

### Google Play Store (⚠️ NEW - Must configure)
| Secret | Description |
|--------|-------------|
| `PLAY_STORE_SERVICE_ACCOUNT_JSON` | Service account JSON for Play Console API |

### Firebase/Google Services (Already configured ✅)
| Secret | Description |
|--------|-------------|
| `GOOGLE_SERVICES_JSON` | google-services.json for Firebase |

### App Configuration (Already configured ✅)
| Secret | Description |
|--------|-------------|
| `SUPABASE_PROJECT_REF` | Supabase project reference ID |
| `SUPABASE_ANON_KEY` | Supabase anonymous key |
| `RAZORPAY_KEY_ID` | Razorpay key ID |
| `GOOGLE_OAUTH_CLIENT_ID_ANDROID` | Google OAuth client ID for Android |
| `GOOGLE_CLOUD_TTS_API_KEY` | Google Cloud TTS API key |

---

## Setting Up Google Play Service Account

### Step 1: Create Service Account in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project (or create one linked to Play Console)
3. Navigate to **IAM & Admin → Service Accounts**
4. Click **Create Service Account**
5. Name: `play-store-publisher`
6. Description: "GitHub Actions Play Store deployment"
7. Click **Create and Continue**
8. Skip role assignment (will configure in Play Console)
9. Click **Done**
10. Click on the created service account
11. Go to **Keys** tab
12. Click **Add Key → Create new key → JSON**
13. Download the JSON file (keep it secure!)

### Step 2: Link Service Account to Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Click **Settings** (gear icon) → **API access**
3. If prompted, click **Link** to link your Google Cloud project
4. Find your service account (`play-store-publisher@...`)
5. Click **Grant access**
6. Configure permissions:

**App permissions:**
- Select "Disciplefy Bible Study" app
- Or select "All apps" for broader access

**Account permissions (required):**
- ✅ **Release to production, exclude devices, and use Play App Signing**
- ✅ **Release apps to testing tracks**
- ✅ **Manage testing tracks and edit tester lists**

7. Click **Invite user**
8. Accept the invitation (check email if needed)

### Step 3: Add to GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings → Secrets and variables → Actions**
3. Click **New repository secret**
4. Name: `PLAY_STORE_SERVICE_ACCOUNT_JSON`
5. Value: Paste the entire contents of the downloaded JSON file
6. Click **Add secret**

---

## Build Configuration

### App Bundle Output
- Path: `frontend/build/app/outputs/bundle/release/app-release.aab`
- Format: Android App Bundle (AAB) - required by Play Store

### Version Numbering

**Beta builds:**
```yaml
--build-name=1.0.${{ github.run_number }}
--build-number=${{ github.run_number }}
```
Example: `1.0.42` (build 42)

**Production builds:**
```yaml
--build-name=${{ steps.version.outputs.version_name }}
--build-number=${{ steps.version.outputs.build_number }}
```
Example: `1.0.0` (build 202501011200)

### Environment Variables
```yaml
SUPABASE_URL: https://{PROJECT_REF}.supabase.co
SUPABASE_ANON_KEY: {from secrets}
GOOGLE_CLIENT_ID: {ANDROID client ID}
APP_URL: https://www.disciplefy.in
FLUTTER_ENV: production
RAZORPAY_KEY_ID: {from secrets}
GOOGLE_CLOUD_TTS_API_KEY: {from secrets}
```

---

## Deployment Workflow

### Before Jan 1st (Beta Testing)

```bash
# Option 1: Automatic deployment on push to main
git checkout main
git merge feature/your-feature
git push origin main
# → Automatically deploys to Internal Testing track
# → Beta testers get update via Play Store

# Option 2: Manual trigger
# 1. Go to GitHub → Actions
# 2. Select "Deploy Android to Play Store (Beta)"
# 3. Click "Run workflow"
# 4. Select branch: main
# 5. Click "Run workflow"
```

### Jan 1st Onwards (Production)

```bash
# Option 1: Create a GitHub Release (recommended)
# 1. Go to GitHub → Releases → Create new release
# 2. Tag: v1.0.0 (creates new tag)
# 3. Title: v1.0.0 - Public Launch
# 4. Description: Release notes
# 5. Click "Publish release"
# → Automatically deploys to Production with 10% rollout

# Option 2: Manual trigger with options
# 1. Go to GitHub → Actions
# 2. Select "Deploy Android to Play Store (Production)"
# 3. Click "Run workflow"
# 4. Fill in:
#    - Version: 1.0.0
#    - Release notes: What's new
#    - Rollout: 10 (start with 10%)
# 5. Click "Run workflow"
```

---

## Staged Rollout Strategy

For production releases, use staged rollout to minimize risk:

| Stage | Percentage | Duration | Actions |
|-------|------------|----------|---------|
| 1 | 10% | 2-3 days | Monitor crash rates, ANRs, reviews |
| 2 | 25% | 2-3 days | Check metrics, fix critical bugs |
| 3 | 50% | 2-3 days | Broader user testing |
| 4 | 100% | - | Full release to all users |

### Increasing Rollout

**Via Play Console:**
1. Go to Play Console → Release → Production
2. Click on the release
3. Click "Increase rollout percentage"
4. Select new percentage
5. Click "Update"

**Via GitHub Actions:**
1. Go to Actions → "Deploy Android to Play Store (Production)"
2. Run workflow with higher `rollout_percentage`

### Halting a Rollout

If critical issues are found:
1. Go to Play Console → Release → Production
2. Click "Halt rollout"
3. Fix issues and create new release

---

## Release Notes

### Location
Update release notes in: `distribution/whatsnew/`

### File Structure
```
distribution/
  whatsnew/
    en-US     # English (US) - default
    en-IN     # English (India)
    hi-IN     # Hindi
    ml-IN     # Malayalam
```

### Format
- Plain text, max 500 characters
- No HTML or markdown
- Use emoji sparingly

### Example (en-US)
```
🙏 Disciplefy Bible Study App

✨ What's New:
• AI-powered Bible study guides
• Voice Discipler conversations
• Memory verse memorization
• Multi-language support

🛠️ Improvements:
• Performance optimizations
• Bug fixes

📖 Start your discipleship journey!
```

---

## Troubleshooting

### Common Issues

**1. "Package name mismatch"**
```
Error: Package name in APK does not match the package name in Play Console
```
- Ensure `packageName` in workflow matches `applicationId` in `build.gradle.kts`
- Current package: `com.disciplefy.bible_study`

**2. "Version code already used"**
```
Error: Version code X has already been used
```
- Build number must always increase
- Beta uses `github.run_number` (always increases)
- Production uses timestamp-based build number

**3. "Service account doesn't have permission"**
```
Error: The caller does not have permission
```
- Re-check Play Console → Settings → API access
- Ensure app-level permissions are granted
- Verify the service account invitation was accepted

**4. "Keystore signature mismatch"**
```
Error: The signature does not match the previously uploaded APK
```
- Use the same keystore used for initial upload
- If using Play App Signing, upload the AAB (not APK)
- If keystore is lost, use Play App Signing key upgrade

**5. "AAB contains native code but no deobfuscation file"**
```
Warning: This App Bundle contains native code...
```
- This is a warning, not an error
- Can be ignored for Flutter apps
- Or add `--obfuscate --split-debug-info=build/debug-info` to build

### Checking Logs

1. **GitHub Actions:** Repository → Actions → Select workflow run → Click job
2. **Play Console:** Release → Track history → Click release → View details
3. **Firebase Crashlytics:** For runtime crash reports

---

## Pre-Launch Checklist

### First-Time Setup (One-time)
- [ ] Create app in Play Console
- [ ] Upload first AAB manually to create listing
- [ ] Complete store listing (title, description, screenshots)
- [ ] Add privacy policy URL
- [ ] Complete content rating questionnaire
- [ ] Set up pricing (Free)
- [ ] Enable Play App Signing
- [ ] Create and link service account
- [ ] Add `PLAY_STORE_SERVICE_ACCOUNT_JSON` secret to GitHub

### Before Each Release
- [ ] Update version in workflows if needed
- [ ] Update release notes in `distribution/whatsnew/`
- [ ] Test build locally: `flutter build appbundle --release`
- [ ] Verify all secrets are configured
- [ ] Check Play Console for any policy issues

### After Release
- [ ] Monitor crash rates in Firebase Crashlytics
- [ ] Check Play Console vitals (ANRs, crashes)
- [ ] Review user feedback and ratings
- [ ] Gradually increase rollout percentage

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub Repository                        │
│                                                              │
│  Push to main ──────────┬──────────── Create Release        │
│         │               │                    │               │
│         ▼               │                    ▼               │
│  ┌─────────────┐        │          ┌─────────────────┐      │
│  │ Beta Deploy │        │          │ Production Deploy│      │
│  │  Workflow   │        │          │    Workflow      │      │
│  └──────┬──────┘        │          └────────┬────────┘      │
│         │               │                    │               │
└─────────┼───────────────┼────────────────────┼───────────────┘
          │               │                    │
          ▼               │                    ▼
    ┌───────────┐         │            ┌───────────────┐
    │  Build    │         │            │    Build      │
    │   AAB     │         │            │     AAB       │
    └─────┬─────┘         │            └───────┬───────┘
          │               │                    │
          ▼               │                    ▼
┌─────────────────────────┴─────────────────────────────────┐
│                    Google Play Store                       │
│                                                            │
│   ┌────────────┐    ┌────────────┐    ┌────────────┐     │
│   │  Internal  │    │   Closed   │    │ Production │     │
│   │  Testing   │───►│   Testing  │───►│            │     │
│   │  (Beta)    │    │            │    │  (Public)  │     │
│   └────────────┘    └────────────┘    └────────────┘     │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## Timeline

| Date | Action | Track |
|------|--------|-------|
| Now - Dec 31 | Beta testing | Internal Testing |
| Jan 1, 2025 | Public launch | Production (10%) |
| Jan 3-4 | Monitor & increase | Production (25%) |
| Jan 6-7 | Monitor & increase | Production (50%) |
| Jan 10+ | Full rollout | Production (100%) |

---

## Support

For deployment issues:
1. Check GitHub Actions logs first
2. Review Play Console release details
3. Check Firebase Crashlytics for app crashes
4. Refer to [Play Console Help](https://support.google.com/googleplay/android-developer)
