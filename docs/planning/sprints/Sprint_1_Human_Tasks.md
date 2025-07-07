# 📋 Sprint 1 Human Tasks - Disciplefy: Bible Study App

**Status**: Sprint 1 Alpha Build (Aug 1-14) - Backend Complete, Frontend Integration Required  
**Last Updated**: January 2025  
**Priority**: Complete before Sprint 2 begins

---

## 🎯 **Overview**

Sprint 1 has successfully completed the **backend infrastructure** and **frontend foundation**. The remaining tasks require human intervention for **integration**, **configuration**, and **testing** that cannot be automated.

### ✅ **Completed by AI/Automation**
- Complete Flutter project scaffold with Clean Architecture
- Full Supabase backend with Edge Functions and database schema
- Navigation system and UI components
- Security validation and rate limiting
- Mock data for offline development
- CI/CD pipeline foundation

### 🔄 **Requires Human Action**
The following tasks need manual completion to finalize Sprint 1 and begin user testing.

---

## 🔐 **1. Environment Configuration & API Keys**

### **1.1 Set Up Production Supabase Project**
- [ ] Create new Supabase project at https://supabase.com
- [ ] Configure project name: `disciplefy-bible-study-prod`
- [ ] Save project URL and anon key to team password manager
- [ ] Update `.env.local` with production Supabase credentials

### **1.2 Configure LLM API Keys** ⚠️ **CRITICAL**
- [ ] Set up OpenAI API account and obtain API key
- [ ] **OR** Set up Anthropic Claude API account (alternative)
- [ ] Test API key validity with a simple request
- [ ] Add API keys to `.env.local` (already has placeholder keys)
- [ ] Set monthly spending limits on API provider dashboards

### **1.3 OAuth Provider Setup**
- [ ] **Google Sign-In**: Create Google Cloud project and Sign-In credentials
  - Set authorized redirect URIs for local development
  - Configure OAuth consent screen
- [ ] **Apple Sign In**: Set up Apple Developer account and Sign in with Apple
  - Configure service IDs and key files
- [ ] Update `backend/supabase/config.toml` with OAuth credentials

### **1.4 Payment Integration** (Optional for MVP)
- [ ] Set up Razorpay account for donations
- [ ] Configure webhook endpoints
- [ ] Test payment flow in sandbox mode

---

## 🔧 **2. Technical Integration & Configuration**

### **2.1 Frontend-Backend Integration**
- [ ] **Connect Flutter app to Supabase**:
  - Update Supabase URL and keys in `frontend/lib/core/config/app_config.dart`
  - Test API connectivity from Flutter app
  - Verify Edge Functions are callable from frontend

- [ ] **Complete BLoC State Management**:
  - Implement missing BLoC classes referenced in dependency injection
  - Connect UI components to actual API calls
  - Add proper error handling for network requests

- [ ] **Authentication Flow Implementation**:
  - Connect Google/Apple OAuth buttons to Supabase Auth
  - Implement anonymous session creation and migration
  - Test authentication flows on real devices

### **2.2 Database Deployment**
- [ ] **Deploy Database Schema**:
  ```bash
  cd backend
  supabase db push --project-ref YOUR_PROJECT_REF
  ```
- [ ] **Deploy Edge Functions**:
  ```bash
  supabase functions deploy --project-ref YOUR_PROJECT_REF
  ```
- [ ] **Set Environment Variables**:
  ```bash
  supabase secrets set OPENAI_API_KEY=your_key --project-ref YOUR_PROJECT_REF
  supabase secrets set ANTHROPIC_API_KEY=your_key --project-ref YOUR_PROJECT_REF
  ```

### **2.3 Local Development Setup Verification**
- [ ] Follow README setup instructions on a fresh machine
- [ ] Verify mock mode works without API keys
- [ ] Test Edge Functions locally with real API keys
- [ ] Confirm database migrations apply correctly

---

## 🧪 **3. Testing & Quality Assurance**

### **3.1 Manual Testing Execution**
- [ ] **Run Accessibility Checklist** (see `docs/ui-ux/Accessibility_Checklist.md`):
  - Test font scaling on iOS (50% to 310%)
  - Test font scaling on Android (85% to 200%)
  - Test with VoiceOver (iOS) and TalkBack (Android)
  - Verify color contrast ratios meet WCAG AA standards
  - Test keyboard navigation on web platform

- [ ] **Cross-Platform Testing**:
  - Test on iOS physical device (not just simulator)
  - Test on Android physical device (not just emulator)
  - Test web version in Chrome, Safari, Firefox
  - Verify responsive design on tablet sizes

- [ ] **LLM Integration Testing**:
  - Generate study guides for different Bible verses
  - Test with biblical topics (faith, love, forgiveness)
  - Verify Jeff Reed methodology structure in responses
  - Test rate limiting (3/hour anonymous, 30/hour authenticated)
  - Verify fallback to mock data when API limits reached

### **3.2 User Experience Testing**
- [ ] **Onboarding Flow**:
  - Complete full onboarding with different language selections
  - Test skip options and navigation flow
  - Verify language preference persistence

- [ ] **Study Generation Flow**:
  - Test scripture input validation (John 3:16, Romans 8:28, etc.)
  - Test topic input validation with various inputs
  - Verify error handling for invalid inputs
  - Test loading states and progress indicators

### **3.3 Security Testing**
- [ ] **Input Validation Testing**:
  - Attempt prompt injection attacks
  - Test XSS prevention in input fields
  - Verify rate limiting works correctly
  - Test anonymous session security

- [ ] **Data Privacy Testing**:
  - Verify anonymous users can't access others' data
  - Test RLS policies in database
  - Confirm sensitive data is not logged

---

## 📱 **4. Platform-Specific Setup**

### **4.1 iOS Configuration**
- [ ] **Apple Developer Account Setup**:
  - Register app bundle ID: `com.disciplefy.biblestudy`
  - Configure signing certificates
  - Set up provisioning profiles

- [ ] **iOS-Specific Features**:
  - Test Sign in with Apple integration
  - Verify app launches and navigation works
  - Test on multiple iOS versions (iOS 15+)

### **4.2 Android Configuration**
- [ ] **Google Play Setup**:
  - Create app bundle ID: `com.disciplefy.biblestudy`
  - Configure app signing
  - Set up Google Sign-In for Android

- [ ] **Android-Specific Features**:
  - Test Google Sign In integration
  - Verify app permissions are minimal
  - Test on multiple Android versions (API 21+)

### **4.3 Web Configuration**
- [ ] **Domain Setup** (if deploying to custom domain):
  - Configure DNS settings
  - Set up SSL certificate
  - Update CORS settings in Supabase

---

## 🚀 **5. Deployment & DevOps**

### **5.1 CI/CD Pipeline Completion**
- [ ] **Configure GitHub Secrets**:
  ```
  SUPABASE_PROJECT_REF=your_project_ref
  SUPABASE_ACCESS_TOKEN=your_access_token
  SUPABASE_URL=your_supabase_url
  SUPABASE_ANON_KEY=your_anon_key
  OPENAI_API_KEY=your_openai_key
  ANTHROPIC_API_KEY=your_anthropic_key
  ```

- [ ] **Test Deployment Pipeline**:
  - Push to main branch and verify CI/CD runs
  - Confirm Edge Functions deploy successfully
  - Verify Android APK builds without errors
  - Test web deployment to Supabase Storage

### **5.2 Monitoring Setup**
- [ ] **Set Up Error Tracking**:
  - Configure Sentry or similar error tracking
  - Test error reporting from mobile apps
  - Set up alerts for critical errors

- [ ] **Usage Monitoring**:
  - Configure analytics tracking (if desired)
  - Set up LLM cost monitoring alerts
  - Monitor database performance metrics

---

## 📊 **6. Business & Content**

### **6.1 Content Review**
- [ ] **Theological Accuracy Review**:
  - Review sample LLM outputs for theological correctness
  - Verify Jeff Reed methodology implementation
  - Test with various Bible translations

- [ ] **Copy Writing & Localization**:
  - Finalize all user-facing text in English
  - Begin Hindi translation for key UI elements
  - Begin Malayalam translation for key UI elements

### **6.2 Legal & Compliance**
- [ ] **Privacy Policy & Terms**:
  - Draft privacy policy for data collection
  - Create terms of service
  - Add links to legal pages in app

- [ ] **App Store Preparation**:
  - Prepare app descriptions for iOS App Store
  - Prepare app descriptions for Google Play Store
  - Create app screenshots and promotional materials

---

## ⏰ **7. Timeline & Priorities**

### **🔥 Critical (Complete First)**
1. **Environment Configuration** - Without this, nothing else works
2. **Frontend-Backend Integration** - Core app functionality
3. **LLM API Setup** - Essential for study guide generation
4. **Basic Manual Testing** - Ensure core flows work

### **📋 High Priority (Complete Before Sprint 2)**
1. **Authentication Implementation** - User sign-in flows
2. **Cross-Platform Testing** - iOS, Android, Web verification
3. **Security Testing** - Input validation and data protection
4. **Accessibility Testing** - WCAG AA compliance verification

### **📝 Medium Priority (Can Overlap with Sprint 2)**
1. **Advanced Testing** - Edge cases and performance
2. **Platform Store Setup** - App registration and assets
3. **Monitoring & Analytics** - Tracking and error reporting
4. **Content Localization** - Multi-language support

---

## 🎯 **Sprint 1 Completion Criteria**

Sprint 1 is considered **COMPLETE** when:

✅ **Core Functionality Works**:
- [ ] User can open app and complete onboarding
- [ ] User can generate study guide for "John 3:16"
- [ ] Study guide displays with proper Jeff Reed methodology structure
- [ ] Authentication flow works (at least one method: Google/Apple/Anonymous)

✅ **Technical Requirements Met**:
- [ ] App runs on iOS, Android, and Web
- [ ] Edge Functions respond correctly to API calls
- [ ] Database operations work with proper security
- [ ] Rate limiting prevents API abuse

✅ **Quality Standards Achieved**:
- [ ] No critical accessibility violations
- [ ] No security vulnerabilities in basic testing
- [ ] Error handling works for network failures
- [ ] Performance is acceptable on mid-range devices

---

## 📞 **Getting Help**

### **Technical Issues**
- **Frontend/Flutter**: Check `frontend/README.md` troubleshooting section
- **Backend/Supabase**: Check `backend/README.md` troubleshooting section  
- **General Setup**: Follow main `README.md` quick start guide

### **External Services**
- **Supabase Support**: https://supabase.com/docs
- **OpenAI Support**: https://help.openai.com/
- **Flutter Support**: https://docs.flutter.dev/

### **Documentation References**
- **Sprint Planning**: `docs/planning/Version 1.0.md`
- **API Contracts**: `docs/specs/API Contract Documentation.md`
- **Security Guidelines**: `docs/security/Security Design Plan.md`
- **Error Handling**: `docs/architecture/Error Handling Strategy.md`

---

**🎯 Next Steps**: Start with Environment Configuration (#1) and work through the priorities systematically. Sprint 2 can begin once core functionality is verified working end-to-end.

*This document should be updated as tasks are completed and new requirements discovered during implementation.*