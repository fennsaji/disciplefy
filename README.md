# 📖 Disciplefy Bible Study App

[![Flutter](https://img.shields.io/badge/Flutter-3.16.0+-02569B.svg?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Powered-3ECF8E.svg?logo=supabase)](https://supabase.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**AI-powered Bible study guide generator implementing 's 4-step methodology for transformational Scripture engagement.**

## ✨ **Key Features**

- **AI Study Generation**: OpenAI GPT-3.5 Turbo & Anthropic Claude integration with  methodology
- **Multi-Language**: English, Hindi (हिन्दी), Malayalam (മലയാളം) support
- **Flexible Auth**: Anonymous (3 guides/hour) or OAuth (30 guides/hour) with Google/Apple Sign-In
- **Cross-Platform**: Flutter app for iOS, Android, and Web with WCAG AA accessibility

## 🛠️ **Tech Stack**

**Frontend**: Flutter 3.16+ • Material 3 • BLoC Pattern • Clean Architecture • GoRouter  
**Backend**: Supabase • TypeScript Edge Functions • PostgreSQL • Row Level Security  
**AI/LLM**: OpenAI GPT-3.5 Turbo • Anthropic Claude Haiku • Prompt Engineering  
**DevOps**: GitHub Actions • Docker • Supabase Analytics

## 🚀 **Quick Start**

> ⚠️ **CRITICAL:** Local development requires **Supabase CLI v2.69.0** specifically. See [Local Development Setup](.github/LOCAL_DEVELOPMENT_SETUP.md) for installation instructions.

### Prerequisites
```bash
Flutter SDK >=3.16.0 • Node.js >=18.0.0 • Supabase CLI v2.69.0 • Docker Desktop
```

### Setup
1. **Clone & Configure**
   ```bash
   git clone https://github.com/fennsaji/disciplefy && cd disciplefy
   cp .env.example .env.local  # Edit with your SUPABASE_URL, API keys
   ```

2. **Backend**
   ```bash
   cd backend && sh scripts/run_local_server.sh
   ```

3. **Frontend**
   ```bash
   cd frontend && flutter pub get
   sh scripts/run_web_local.sh  # Run Web server
   ```

### Mock Mode (No API costs)
```bash
# Runs with pre-built study guides for John 3:16, Romans 8:28, Faith, Love, Forgiveness
cd backend && sh scripts/run_local_server.sh
```

## 🧪 **Testing & Development**

```bash
# Frontend                    # Backend                     # Security
flutter test                  supabase functions serve     4-layer input validation
flutter analyze              supabase db diff             Row Level Security (RLS)
flutter test --coverage      API endpoint testing         Rate limiting (3/30 per hour)
```

## 📊 **Core APIs**

- `POST /functions/v1/study-generate` - AI study guide generation with  methodology
- `GET /functions/v1/topics-recommended` - Predefined biblical topics
- `POST /functions/v1/auth-session` - Session management (anonymous/OAuth)
- `GET /functions/v1/daily-verse` - Daily Bible verse in multiple languages
- `GET /functions/v1/study-guides` - Retrieve saved study guides
- `POST /functions/v1/feedback` - User feedback collection
- `GET /functions/v1/auth-google-callback` - Google OAuth callback

**Security**: 4-layer validation pipeline (format → sanitization → injection detection → rate limiting)  
**Fallback**: OpenAI GPT-3.5 → Claude Haiku → Mock data when APIs unavailable  
**Cost Control**: $15 daily/$100 monthly limits with auto-scaling to mock mode

## 📁 **Project Structure**

```
disciplefy/
├── 📁 docs/                    # Complete technical documentation & specifications
├── 📱 frontend/                # Flutter app (iOS/Android/Web)
│   ├── lib/features/          # Clean Architecture modules (auth, study_generation, etc.)
│   └── test/                  # Unit, widget, and integration tests
├── 🗄️ backend/supabase/        # PostgreSQL DB, Edge Functions, RLS policies
│   ├── migrations/            # Database schema evolution
│   └── functions/             # TypeScript serverless APIs
└── 🌐 .github/workflows/      # CI/CD automation
```

## 🤝 **Contributing**

1. **Setup**: Follow Quick Start guide above
2. **Standards**: Dart Style Guide, Conventional Commits, Clean Architecture
3. **Testing**: `flutter test` must pass, include theological accuracy validation
4. **PRs**: Descriptive titles, link issues, ensure CI passes

**Maintainer**: [@fennsaji](https://github.com/fennsaji) | **License**: MIT | **Support**: GitHub Issues & Discussions


## 📜 Policies

- [Privacy Policy](https://policies.disciplefy.in/privacy-policy)
- [Terms of Service](https://policies.disciplefy.in/terms-of-service)
- [Refund Policy](https://policies.disciplefy.in/refund-policy)


---

*Built with ❤️ for transformational Bible study using modern technology and timeless wisdom.*
