# 📖 Disciplefy Bible Study App

[![Build Status](https://github.com/TODO-org-name/disciplefy-bible-study/workflows/CI/badge.svg)](https://github.com/TODO-org-name/disciplefy-bible-study/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/TODO-org-name/disciplefy-bible-study/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.16.0+-02569B.svg?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Powered-3ECF8E.svg?logo=supabase)](https://supabase.com)

**AI-powered Bible study guide generator implementing Jeff Reed's 4-step methodology for transformational Scripture engagement.**

---

## 🧠 **Core Features**

### **🤖 AI-Powered Study Generation**
- Generate comprehensive Bible study guides from any verse or biblical topic
- **Jeff Reed Methodology**: Context → Scholar's Guide → Group Discussion → Application
- **Multi-LLM Support**: OpenAI GPT-3.5 Turbo and Anthropic Claude Haiku integration
- **Offline Mode**: Mock study guides for development and testing

### **🌍 Multi-Language & Accessibility**
- **3 Languages**: English, Hindi (हिन्दी), Malayalam (മലയാളം)
- **WCAG AA Compliance**: Font scaling, color contrast, screen reader support
- **Cross-Platform**: iOS, Android, and Web with responsive design

### **🔐 Flexible Authentication & Security**
- **Anonymous Access**: Generate 3 study guides per hour without signup
- **Authenticated Users**: 30 guides per hour with cloud sync and history
- **OAuth Integration**: Google and Apple Sign-In
- **Security-First**: Multi-layer input validation and prompt injection protection

### **💰 Cost-Effective & Sustainable**
- **Rate Limiting**: Prevents API abuse and controls LLM costs
- **Usage Tiers**: Freemium model with optional donations via Razorpay
- **Budget Controls**: $15 daily / $100 monthly LLM spending limits

---

## ⚙️ **Technology Stack**

### **Frontend**
- **Flutter 3.16+** - Cross-platform mobile and web development
- **Material 3** - Modern design system with accessibility features
- **BLoC Pattern** - Predictable state management
- **Clean Architecture** - Scalable, testable code organization
- **GoRouter** - Type-safe navigation and deep linking

### **Backend**
- **Supabase** - Backend-as-a-Service with PostgreSQL, Auth, and Edge Functions
- **TypeScript Edge Functions** - Serverless API endpoints with Deno runtime
- **Row Level Security (RLS)** - Database-level security and privacy
- **Real-time Subscriptions** - Live data synchronization

### **AI & ML**
- **OpenAI GPT-3.5 Turbo** - Primary LLM for study guide generation
- **Anthropic Claude Haiku** - Alternative LLM provider with fallback
- **Prompt Engineering** - Jeff Reed methodology implementation
- **Content Moderation** - Input validation and safety filtering

### **DevOps & Monitoring**
- **GitHub Actions** - CI/CD pipelines for testing and deployment
- **Docker** - Containerized development environment
- **Supabase Analytics** - Usage tracking and performance monitoring

---

## 🚀 **Getting Started**

### **📋 Prerequisites**

```bash
# Required
Flutter SDK >=3.16.0 (stable channel)
Dart SDK >=3.0.0 <4.0.0
Node.js >=18.0.0
Supabase CLI (latest)
Docker Desktop

# Optional
Android Studio (for Android development)
Xcode 15+ (for iOS development, macOS only)
VS Code with Flutter extension
```

### **⚡ Quick Setup**

1. **Clone the repository**
   ```bash
   git clone https://github.com/TODO-org-name/disciplefy-bible-study.git
   cd disciplefy-bible-study
   ```

2. **Environment configuration**
   ```bash
   # Copy environment template
   cp .env.example .env.local
   
   # Edit .env.local with your configuration
   # Required: SUPABASE_URL, SUPABASE_ANON_KEY
   # Optional: OPENAI_API_KEY, ANTHROPIC_API_KEY
   ```

3. **Backend setup**
   ```bash
   cd backend
   
   # Start local Supabase stack (PostgreSQL, Auth, Edge Functions)
   supabase start
   
   # Apply database schema and seed data
   supabase db reset
   
   # Start Edge Functions with environment variables
   supabase functions serve --env-file ../.env.local
   ```

4. **Frontend setup**
   ```bash
   cd frontend
   
   # Install Flutter dependencies
   flutter pub get
   
   # Run the app (iOS Simulator, Android Emulator, or Chrome)
   flutter run
   ```

### **🔑 Environment Variables**

Create `.env.local` from `.env.example` and configure:

```bash
# Supabase Configuration (Required)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# LLM Configuration (Choose one or both)
OPENAI_API_KEY=sk-your-openai-api-key-here
ANTHROPIC_API_KEY=sk-ant-your-anthropic-api-key-here
LLM_PROVIDER=openai  # 'openai' or 'anthropic'

# Authentication (Optional)
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret
APPLE_CLIENT_ID=your.app.bundle.id
APPLE_CLIENT_SECRET=your-apple-client-secret

# Payment Integration (Optional)
RAZORPAY_KEY_ID=rzp_test_your-key-id
RAZORPAY_KEY_SECRET=your-razorpay-secret

# Application Settings
SITE_URL=http://localhost:3000
JWT_SECRET=your-very-secure-jwt-secret-minimum-32-chars
```

### **🎭 Running in Mock Mode**

For development without LLM API costs:

```bash
# Backend will automatically use mock data when API keys are not configured
cd backend
supabase functions serve --env-file ../.env.local

# Test mock study generation
curl -X POST 'http://localhost:54321/functions/v1/study-generate' \
  -H 'Content-Type: application/json' \
  -d '{
    "input_type": "scripture",
    "input_value": "John 3:16",
    "language": "en"
  }'
```

**Mock Study Guides Available:**
- **John 3:16** - God's love and eternal life
- **Romans 8:28** - God's sovereignty in trials
- **Faith** - Biblical foundation of trust in God
- **Love** - Agape love and relationships
- **Forgiveness** - Grace and reconciliation

---

## 🧪 **Testing**

### **Frontend Testing**
```bash
cd frontend

# Unit and widget tests
flutter test

# Integration tests
flutter test integration_test/

# Code analysis and formatting
flutter analyze
dart format --set-exit-if-changed .

# Test coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### **Backend Testing**
```bash
cd backend

# Test Edge Functions locally
supabase functions serve --env-file ../.env.local

# API endpoint testing
npm run test:api  # If configured

# Database schema validation
supabase db diff
```

### **LLM Validation Suite**
```bash
cd tests  # TODO: Create tests directory

# TODO: Test LLM prompts and responses
python validate_llm_responses.py

# TODO: Theology accuracy validation  
python theology_check.py

# TODO: Performance and cost analysis
python cost_analysis.py
```

---

## 🛡️ **Security & Authentication**

### **Multi-Tier Security Architecture**

**🔐 Authentication Levels:**
- **Anonymous Users**: Session-based with device fingerprinting
- **OAuth Users**: Google and Apple Sign-In integration
- **Admin Users**: Enhanced permissions for content moderation

**🛡️ Input Validation Pipeline:**
1. **Format Validation**: Bible verse patterns and topic validation
2. **Content Sanitization**: XSS and injection prevention
3. **Prompt Injection Detection**: Multi-layer AI safety filtering
4. **Rate Limiting**: 3/hour anonymous, 30/hour authenticated

**🗄️ Database Security:**
- **Row Level Security (RLS)**: User data isolation at PostgreSQL level
- **Encrypted Storage**: Sensitive data protected with industry standards
- **Audit Logging**: All security events tracked for analysis

### **Cost Management & Usage Controls**

```typescript
// Rate limiting configuration
const RATE_LIMITS = {
  anonymous: { guides: 3, requests: 10 },      // per hour
  authenticated: { guides: 30, requests: 100 }, // per hour
  daily_cost_limit: 15.00,                     // USD
  monthly_cost_limit: 100.00                   // USD
};
```

---

## 💰 **Cost Management Strategy**

### **📊 Usage Tiers**
- **Free Tier**: 3 study guides/hour (anonymous)
- **Registered Tier**: 30 study guides/hour + cloud sync
- **Donation Supporters**: Priority access during peak times

### **💸 Budget Controls**
- **Daily Limit**: $15 LLM spending cap
- **Monthly Limit**: $100 total budget
- **Per-User Limit**: $0.15 daily for free tier users
- **Auto-Scaling**: Switches to mock mode when limits reached

### **💝 Sustainable Funding**
- **Razorpay Integration**: Voluntary donations in INR
- **Transparent Usage**: Real-time cost tracking in admin dashboard
- **Community Supported**: No paywalls, donation-driven sustainability

---

## 📊 **API Endpoints**

### **🤖 LLM & Study Generation**
- `POST /functions/v1/study-generate` - Generate AI-powered study guides
- `GET /functions/v1/topics-jeffreed` - Get predefined biblical topics with Jeff Reed methodology
- `POST /functions/v1/feedback` - Submit user feedback and ratings

### **🔐 Authentication & Session Management**
- `POST /functions/v1/auth-session` - Create and manage user sessions (anonymous/authenticated)
- **Google OAuth** - Social login integration via Supabase Auth
- **Apple Sign In** - iOS/macOS authentication via Supabase Auth
- **Anonymous Sessions** - Guest access with device fingerprinting

### **⚡ LLM Runtime Behavior**

**📚 Documentation Loading**: Each LLM request automatically loads required documentation from the `/docs/` folder via CLAUDE.md initialization, ensuring theological accuracy and Jeff Reed methodology compliance.

**🎭 Fallback Strategy**:
- **Primary**: OpenAI GPT-3.5 Turbo for study guide generation
- **Secondary**: Anthropic Claude Haiku as backup provider
- **Offline**: Comprehensive mock data with 5 pre-built study guides when API keys unavailable

**🛡️ Security Pipeline**: All inputs pass through 4-layer validation (format → sanitization → injection detection → rate limiting) before reaching LLM providers.

---

## 📦 **Monorepo Structure**

```
disciplefy-bible-study/
├── 📁 docs/                          # Technical documentation
│   ├── Product Requirements Document.md
│   ├── Technical Architecture Document.md
│   ├── API Contract Documentation.md
│   ├── Security Design Plan.md
│   ├── Version 1.0.md                # Sprint planning baseline
│   ├── Error Handling Strategy.md
│   ├── LLM Input Validation Specification.md
│   ├── DevOps & Deployment Plan.md
│   └── Accessibility_Checklist.md    # WCAG AA compliance checklist
│
├── 📱 frontend/                       # Flutter mobile + web app
│   ├── lib/
│   │   ├── core/                     # Configuration, DI, navigation
│   │   └── features/                 # Clean Architecture modules
│   │       ├── auth/                 # Authentication flows
│   │       ├── study_generation/     # Study guide creation
│   │       ├── onboarding/          # User introduction
│   │       └── home/                # Dashboard and navigation
│   ├── test/                        # Unit and widget tests
│   ├── integration_test/            # E2E testing
│   └── pubspec.yaml                 # Dependencies and metadata
│
├── 🗄️ backend/                        # Supabase backend services
│   └── supabase/
│       ├── config.toml              # Supabase configuration
│       ├── migrations/              # Database schema evolution
│       └── functions/               # TypeScript Edge Functions
│           ├── _shared/             # Common utilities
│           ├── study-generate/      # LLM study guide API
│           ├── topics-jeffreed/     # Predefined biblical topics
│           ├── feedback/            # User feedback collection
│           └── auth-session/        # Session management
│
├── 🌐 .github/                        # CI/CD and automation
│   └── workflows/
│       └── flutter.yml             # Frontend testing and deployment
│
├── 📄 .env.example                    # Environment configuration template
├── 📋 README.md                       # This file
└── 📜 LICENSE                         # MIT License
│
├── 🔧 scripts/                        # TODO: DevOps and deployment utilities
└── 🧪 tests/                          # TODO: Integration and validation suites
```

---

## 📈 **Roadmap Summary**

### **✅ v1.0 - Foundation (Sprint 1-3: Aug 1 - Sept 12)**
- **Sprint 1**: Complete Flutter scaffold + Supabase backend ✅ **COMPLETED**
- **Sprint 2**: LLM integration + study guide generation 🔄 **IN PROGRESS**
- **Sprint 3**: UI polish + accessibility + internal testing ⏳ **PLANNED**

### **🔄 v1.1 - Enhancement (Sept 13 - Oct 15)**
- Jeff Reed sessions (multi-step guided studies)
- Advanced study guide customization
- Offline sync and conflict resolution

### **⏳ v1.2 - Community (Oct 16 - Nov 30)**
- Study group sharing and collaboration
- Enhanced multi-language support
- Performance optimizations

### **🎯 v2.0 - Scale (Dec 1 - Feb 28)**
- Advanced AI features and personalization
- Mobile app store deployment
- Community-driven content expansion

**📚 Planning Baseline**: All roadmap items derived from `docs/Version 1.0.md` and related v1.0-docs-stable specifications.

---

## 🤝 **Contributing**

### **🔄 Development Workflow**

1. **Fork and Clone**
   ```bash
   git clone https://github.com/TODO-username/disciplefy-bible-study.git
   cd disciplefy-bible-study
   git checkout -b feature/your-feature-name
   ```

2. **Setup Development Environment**
   ```bash
   # Follow Getting Started instructions above
   # Ensure all tests pass before making changes
   ```

3. **Code Standards**
   - **Flutter**: Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
   - **TypeScript**: Use ESLint with Deno configuration
   - **Commits**: Use [Conventional Commits](https://conventionalcommits.org/) format
   - **Architecture**: Maintain Clean Architecture patterns

4. **Testing Requirements**
   ```bash
   # Frontend tests must pass
   cd frontend && flutter test
   
   # Backend functions must be validated
   cd backend && supabase functions serve
   
   # TODO: Integration tests for new features
   cd tests && python -m pytest integration/
   ```

5. **Pull Request Process**
   - Create descriptive PR title and detailed description
   - Link related issues and provide testing instructions
   - Ensure CI/CD pipeline passes
   - Request review from maintainers

### **🐛 Issue Reporting**

**Bug Reports**: Include Flutter doctor output, device info, and reproduction steps
**Feature Requests**: Reference theological accuracy and Jeff Reed methodology alignment
**Security Issues**: Report privately to TODO-security-email@yourorg.com

### **📚 Documentation Contributions**

- Update relevant README files for new features
- Maintain theological accuracy in study content
- Follow markdown formatting standards
- Include code examples and usage instructions

---

## 🧑‍💼 **License and Maintainers**

### **📜 License**
This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

**Key Permissions:**
- ✅ Commercial use
- ✅ Distribution and modification
- ✅ Private use
- ⚠️ Includes copyright notice and license text

### **👥 Core Maintainers**

- **Project Lead**: [@TODO-username](https://github.com/TODO-username)
- **Backend Lead**: [@TODO-backend-maintainer](https://github.com/TODO-backend-maintainer)
- **Frontend Lead**: [@TODO-frontend-maintainer](https://github.com/TODO-frontend-maintainer)
- **Theology Advisor**: [@TODO-theology-reviewer](https://github.com/TODO-theology-reviewer)

### **🙏 Acknowledgments**

- **Jeff Reed** - Bible study methodology and spiritual inspiration
- **Supabase Team** - Backend infrastructure and developer experience
- **Flutter Team** - Cross-platform framework and Material Design
- **OpenAI & Anthropic** - Large language model providers
- **Open Source Community** - Dependencies and contributions

### **📞 Support & Community**

- **Documentation**: Comprehensive guides in `/docs/` directory
- **Discussions**: GitHub Discussions for questions and ideas
- **Issues**: GitHub Issues for bugs and feature requests
- **Discord**: [TODO: Add Discord server link](https://discord.gg/TODO-server) for real-time support

---

**🌟 Star this repository if Disciplefy Bible Study App helps deepen your faith journey!**

*Built with ❤️ for transformational Bible study using modern technology and timeless wisdom.*


## LLM Prompt Templates
Analyse [File or Folder path]  and check if it is implemented and mark completed stuff as Completed. Also check if correctly implemented, if any bugs or logical errors update the respective document. Also if not completed mark as Pending. Update the same document with status


Analyse [File or Folder path] and find out any bugs, logical errors, not complying Coding principles like DRY, SOLID and Clean Code Principles, and/or Compilation issues. And document in @[path]/docs and no coding 

```
act -W .github/workflows/frontend-deploy-dev.yml --container-daemon-socket /var/run/docker.sock
```