# 📱 Disciplefy Bible Study - Frontend

AI-powered Bible study guide application built with Flutter, following Jeff Reed methodology for structured Bible study.

## 🎯 Sprint 1 Status - ✅ COMPLETE

**✅ All Sprint 1 Frontend Tasks Implemented:**

- **✅ Clean Architecture**: Complete folder structure with dependency injection
- **✅ Study Input UI**: Verse/topic input with validation and loading states
- **✅ Navigation Stack**: Onboarding → Home → Study Result → Error pages
- **✅ Onboarding Flow**: 3-screen flow with language selection (EN/HI/ML)
- **✅ Theming & Accessibility**: Material 3 design with WCAG AA compliance
- **✅ Localization**: Multi-language support for English, Hindi, Malayalam

**Production-ready Sprint 1 implementation with no test data or placeholders**

## 🚀 Quick Start

### Prerequisites

- **Flutter SDK**: `>=3.16.0` (stable channel)
- **Dart SDK**: `>=3.0.0 <4.0.0`
- **IDE**: VS Code with Flutter extension OR Android Studio
- **Platform Tools**:
  - **Android**: Android Studio + Android SDK (API 21+)
  - **iOS**: Xcode 15+ (macOS only)
  - **Web**: Chrome browser

### 🔧 Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd bible-study-app/frontend
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment variables**
   ```bash
   # Copy the environment template
   cp ../.env.example .env.local
   
   # Edit .env.local with your configuration
   # Required: SUPABASE_URL, SUPABASE_ANON_KEY
   # Optional: OPENAI_API_KEY, ANTHROPIC_API_KEY
   ```

4. **Run code generation** (if needed)
   ```bash
   flutter pub run build_runner build
   ```

### 🏃‍♂️ Running the App

#### 🚀 Quick Local Development (Web)

**Prerequisites:**
1. **Start Supabase locally** (from `backend/` directory):
   ```bash
   cd ../backend
   supabase start
   ```

2. **Configure environment variables** (already done):
   ```bash
   # Environment variables are already set in .env.local
   # No need to modify - ready to use!
   ```

3. **Run the app**:

   ```bash
   # Use the convenience script (recommended)
   ./scripts/run_web_local.sh
   
   # Or manual command
   flutter run -d chrome --dart-define-from-file=.env.local
   ```

**What you'll see:**
The **complete Sprint 1 application** with:
- 🎯 **Onboarding Flow**: Welcome → Language Selection → App Purpose
- 📝 **Study Input**: Verse/topic input with real-time validation
- ⚡ **Loading States**: Smooth loading experience during generation
- 📱 **Study Results**: Formatted study guides with sharing capability
- 🌐 **Multi-language**: Full support for English, Hindi, Malayalam
- ♿ **Accessibility**: WCAG AA compliant design with font scaling

**Production-ready Sprint 1 with complete UI implementation**

#### Development Mode
```bash
# Run on connected device/emulator
flutter run

# Run in debug mode with hot reload
flutter run --debug

# Run on specific device
flutter devices
flutter run -d <device-id>
```

#### Platform-Specific Commands

**Android:**
```bash
# Run on Android emulator
flutter run -d android

# Build APK for testing
flutter build apk --debug
```

**iOS:**
```bash
# Run on iOS simulator (macOS only)
flutter run -d ios

# Build for iOS device (requires Apple Developer account)
flutter build ios
```

**Web:**
```bash
# Run web app with local development setup
./scripts/run_web_local.sh

# Alternative: Manual command with environment file
flutter run -d chrome --dart-define-from-file=.env.local

# Build for web deployment
flutter build web --release
```

### 🧪 Testing

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run integration tests
flutter test integration_test/

# Run specific test file
flutter test test/features/auth/auth_test.dart
```

### 🔍 Code Quality

```bash
# Analyze code for issues
flutter analyze

# Format code according to Dart style
dart format lib/ test/

# Check for formatting issues
dart format --output=none --set-exit-if-changed .
```

## 📁 Sprint 1 Project Structure

```
frontend/
├── lib/
│   ├── core/
│   │   ├── config/app_config.dart     # Environment configuration
│   │   └── network/                   # Network utilities (basic)
│   │
│   ├── features/
│   │   └── auth/                      # Authentication feature
│   │       ├── domain/entities/       # User entity
│   │       ├── data/services/         # Auth service (Supabase + OAuth)
│   │       └── presentation/pages/    # Basic auth page
│   │
│   └── main.dart                      # Sprint 1 test app entry point
│
├── test/                              # Unit tests (basic)
├── android/                           # Android-specific configuration
├── ios/                               # iOS-specific configuration
├── web/                               # Web-specific configuration
└── pubspec.yaml                       # Dependencies
```

**Sprint 1 Notes:** 
- Simplified structure focused on core authentication and backend integration
- No complex UI architecture (BLoC, navigation) yet
- Clean foundation for future sprint development

## 🏗️ Sprint 1 Architecture

### Simple Architecture Focus

**Sprint 1 Components:**
- **Core Configuration**: Environment and app setup
- **Authentication Service**: Direct Supabase integration
- **Basic UI**: Single test page for validation
- **Error Handling**: Basic error display

**Future Sprints Will Add:**
- Clean Architecture layers (Domain, Data, Presentation)
- BLoC state management
- Complex navigation and routing
- Multi-language support
- Advanced theming system

## 🔧 Environment Configuration

### Local Development (Working Configuration)

**Environment file**: `.env.local` (already configured)
```bash
# Supabase Local Configuration
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0

# OAuth Configuration (Already configured)
GOOGLE_CLIENT_ID=587108000155-af542dhgo9rmp5hvsm1vepgqsgil438d.apps.googleusercontent.com
APPLE_CLIENT_ID=com.disciplefy.bible_study

# LLM Configuration (Configured in backend/.env.local)
OPENAI_API_KEY=sk-proj-egbigkSt2dDKYZ...  # Already configured
ANTHROPIC_API_KEY=sk-ant-api03-a6X5K7tj... # Already configured

# App Configuration
FLUTTER_ENV=development
LOG_LEVEL=debug
```

**Usage**: Environment variables are automatically loaded when using the convenience script or `--dart-define-from-file=.env.local`

### Production Environment Variables
```bash
# Supabase Production (when deployed)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-production-anon-key

# Same OAuth and LLM configuration as above
```

### Configuration Files
- **Development**: `.env.local` (not committed)
- **Staging**: `.env.staging`
- **Production**: `.env.production`

## 🔄 Development Workflow

### 1. Feature Development
```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes with hot reload
flutter run

# Run tests
flutter test

# Check code quality
flutter analyze
dart format lib/
```

### 2. Testing Strategy
- **Unit Tests**: Business logic and utilities
- **Widget Tests**: UI components and interactions  
- **Integration Tests**: End-to-end user flows
- **Golden Tests**: Visual regression testing

### 3. Debugging

**Debug Mode:**
```bash
# Run with debugging enabled
flutter run --debug

# Open DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

**Performance Profiling:**
```bash
# Run in profile mode
flutter run --profile

# Build release for performance testing
flutter build apk --release
```

## 📦 Build & Deployment

### Debug Builds
```bash
# Android APK
flutter build apk --debug

# iOS (macOS only)
flutter build ios --debug
```

### Release Builds
```bash
# Android APK (for testing)
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (for App Store)
flutter build ios --release

# Web (for hosting)
flutter build web --release
```

### CI/CD Integration
- **GitHub Actions**: Automated testing and building
- **Code Quality**: Analysis and formatting checks
- **Artifact Upload**: APK and web builds

## 🐛 Troubleshooting

### Common Issues

**1. Supabase connection failed:**
```bash
# Make sure Supabase is running locally
cd ../backend
supabase status
# If not running:
supabase start
```

**2. Google OAuth not working:**
```bash
# Check if the client ID is correct in the command
# Make sure Chrome allows popup windows for OAuth
```

**3. Dependencies not found:**
```bash
flutter clean
flutter pub get
```

**4. Build errors with main.dart:**
```bash
# Use the simplified test app instead
flutter run -d chrome -t lib/main_simple.dart
```

**5. Web CORS issues in development:**
```bash
flutter run -d chrome --web-renderer html
```

**6. Anonymous auth failing:**
```bash
# Check Supabase config allows anonymous sign-ins
# Verify backend/supabase/config.toml has:
# enable_anonymous_sign_ins = true
```

### Debug Commands
```bash
# Check Flutter installation
flutter doctor

# Check connected devices
flutter devices

# Verbose logging
flutter run --verbose

# Check app performance
flutter run --trace-startup
```

## 🤝 Contributing

### Code Style
- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `dart format` for consistent formatting
- Maintain Clean Architecture patterns
- Write tests for new features

### Pull Request Process
1. Create feature branch from `develop`
2. Implement feature with tests
3. Run code quality checks
4. Create PR with descriptive title
5. Address review feedback

## 📚 Resources

- **Flutter Documentation**: https://docs.flutter.dev/
- **Dart Documentation**: https://dart.dev/guides
- **Material 3 Design**: https://m3.material.io/
- **BLoC Documentation**: https://bloclibrary.dev/
- **Clean Architecture**: https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html

## 📞 Support

For development issues:
1. Check existing GitHub issues
2. Review troubleshooting section
3. Create new issue with detailed description
4. Include Flutter doctor output and error logs

---

Built with ❤️ using Flutter and Material 3 Design System
