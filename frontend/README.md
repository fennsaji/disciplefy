# Disciplefy — Frontend

AI-powered Bible study app built with Flutter (mobile + web), supporting English, Hindi, and Malayalam.

---

## Tech Stack

- **Framework**: Flutter (Android, iOS, Web)
- **State Management**: BLoC + GetIt dependency injection
- **Architecture**: Clean Architecture (Presentation → Domain ← Data)
- **Backend**: Supabase (auth, database, edge functions)
- **Navigation**: go_router
- **Payments**: Razorpay (web) + Google Play / App Store IAP (mobile)

---

## Features

- AI-powered Bible study guide generation (English, Hindi, Malayalam)
- Daily verse with multi-language support
- Memory verse practice
- Voice buddy (TTS narration)
- Community fellowship — scheduling Google Meet sessions
- Subscription plans: Standard, Plus, Premium (Razorpay + IAP)
- Anonymous and authenticated usage
- Offline-capable with local caching

---

## Prerequisites

- Flutter SDK `>=3.16.0` (stable channel)
- Dart SDK `>=3.0.0 <4.0.0`

---

## Quick Start (Web)

1. **Install dependencies**
   ```bash
   flutter pub get
   ```

2. **Start Supabase locally** (from `backend/` directory)
   ```bash
   cd ../backend && supabase start
   ```

3. **Configure environment**
   ```bash
   cp ../.env.example .env.local
   # Fill in SUPABASE_URL and SUPABASE_ANON_KEY
   ```

4. **Run the app**
   ```bash
   sh scripts/run_web_local.sh
   # or manually:
   flutter run -d chrome --dart-define-from-file=.env.local
   ```

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `SUPABASE_URL` | ✅ | Supabase project URL |
| `SUPABASE_ANON_KEY` | ✅ | Supabase anon key |
| `GOOGLE_CLIENT_ID` | ✅ | Google OAuth client ID (web) |
| `APPLE_CLIENT_ID` | ✅ | Apple OAuth client ID |
| `FLUTTER_ENV` | ✅ | `development` or `production` |

Never commit `.env.local` or `.env.production` — they are git-ignored.

---

## Project Structure

```
lib/
├── core/
│   ├── config/          # App config, environment
│   ├── constants/       # Bible books, app constants
│   ├── di/              # GetIt dependency injection
│   ├── i18n/            # Translations (EN/HI/ML)
│   ├── router/          # go_router routes
│   ├── services/        # Notifications, version checker
│   └── theme/           # AppTheme, AppColors, fonts
│
└── features/
    ├── auth/            # Google, Apple, email sign-in
    ├── community/       # Fellowship, meetings, Google Calendar
    ├── daily_verse/     # Daily verse with language tabs
    ├── memory_verses/   # Memory verse practice
    ├── settings/        # Settings, privacy, terms, refund
    ├── study_generation/# AI study guide generation + TTS
    ├── subscription/    # Plans, upgrade pages, IAP
    ├── tokens/          # Token balance, purchases
    ├── user_profile/    # Profile management
    ├── voice_buddy/     # Cloud TTS narration
    └── walkthrough/     # Onboarding walkthrough
```

---

## Running on Other Platforms

```bash
# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios

# Web (manual)
flutter run -d chrome --dart-define-from-file=.env.local
```

---

## Build for Release

```bash
# Android App Bundle (Play Store)
flutter build appbundle --release --dart-define-from-file=.env.production

# iOS (App Store)
flutter build ios --release --dart-define-from-file=.env.production

# Web
flutter build web --release --dart-define-from-file=.env.production
```

---

## Code Quality

```bash
flutter analyze
dart format lib/
flutter test
flutter test --coverage
```

---

## Troubleshooting

**Supabase not running:**
```bash
cd ../backend && supabase status
```

**Dependencies missing:**
```bash
flutter clean && flutter pub get
```

**Web CORS issues:**
```bash
flutter run -d chrome --web-renderer html --dart-define-from-file=.env.local
```

---

## Legal

- Privacy Policy: https://www.disciplefy.in/privacy
- Terms of Service: https://www.disciplefy.in/terms
- Refund Policy: https://www.disciplefy.in/refund
- Delete Account: https://app.disciplefy.in/delete-account
