# 🏗️ Technical Architecture Document
**Disciplefy: Bible Study App**

*Comprehensive technical architecture for production-ready implementation*

---

## 📋 **Architecture Overview**

### **System Architecture**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │◄──►│  Supabase API   │◄──►│   PostgreSQL    │
│  (iOS/Android)  │    │  Edge Functions │    │   Database      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         └─────────────►│      LLM        │              │
                        │   Integration   │              │
                        │ (OpenAI/Claude) │              │
                        └─────────────────┘              │
                                 │                       │
                        ┌─────────────────┐              │
                        │   Real-time     │◄─────────────┘
                        │   WebSockets    │
                        └─────────────────┘
```

### **Technology Stack**

**Frontend**
- **Framework:** Flutter 3.16+
- **State Management:** Riverpod 2.0
- **HTTP Client:** Dio with retry logic
- **Local Storage:** Hive/SQLite
- **Offline Sync:** Custom sync service

**Backend**
- **Platform:** Supabase (PostgreSQL + Edge Functions)
- **Runtime:** Deno for Edge Functions
- **Authentication:** Supabase Auth (JWT-based)
- **Real-time:** WebSocket connections
- **File Storage:** Supabase Storage

**AI Integration**
- **Primary:** OpenAI GPT-3.5 Turbo
- **Secondary:** Anthropic Claude Haiku
- **Fallback:** Local caching with retry logic

**Infrastructure**
- **Database:** PostgreSQL 15+ with Row Level Security
- **CDN:** Supabase Edge Network
- **Monitoring:** Supabase Analytics + Custom dashboards
- **Deployment:** GitHub Actions CI/CD

---

## 🏛️ **Database Architecture**

### **Core Schema Design**

```sql
-- Users and Authentication (Managed by Supabase Auth)
-- auth.users table is provided by Supabase

-- User Profiles Extension
CREATE TABLE public.user_profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  display_name TEXT,
  preferences JSONB DEFAULT '{}',
  subscription_tier VARCHAR(20) DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

--  Study Sessions
CREATE TABLE public.jeff_reed_sessions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  scripture_reference TEXT NOT NULL,
  current_step VARCHAR(20) DEFAULT 'observation' 
    CHECK (current_step IN ('observation', 'interpretation', 'correlation', 'application')),
  status VARCHAR(20) DEFAULT 'in_progress' 
    CHECK (status IN ('in_progress', 'completed', 'abandoned')),
  session_data JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Study Guides
CREATE TABLE public.study_guides (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id UUID REFERENCES jeff_reed_sessions(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  scripture_reference TEXT NOT NULL,
  jeff_reed_step VARCHAR(20) NOT NULL 
    CHECK (jeff_reed_step IN ('observation', 'interpretation', 'correlation', 'application')),
  summary TEXT NOT NULL,
  detailed_content JSONB NOT NULL,
  llm_model_used VARCHAR(50),
  generation_time_ms INTEGER,
  is_favorited BOOLEAN DEFAULT FALSE,
  tags TEXT[] DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User Feedback and Bug Reports
CREATE TABLE public.user_feedback (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  feedback_type VARCHAR(50) NOT NULL 
    CHECK (feedback_type IN ('Feature Request', 'Bug', 'Praise', 'Complaint', 'Suggestion')),
  message TEXT NOT NULL,
  screen_context VARCHAR(100),
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  device_info JSONB,
  app_version VARCHAR(20),
  status VARCHAR(20) DEFAULT 'Open' 
    CHECK (status IN ('Open', 'In Review', 'Planned', 'Completed', 'Rejected')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- API Usage Tracking
CREATE TABLE public.api_usage_log (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  endpoint VARCHAR(100) NOT NULL,
  method VARCHAR(10) NOT NULL,
  status_code INTEGER NOT NULL,
  response_time_ms INTEGER,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- LLM Request Monitoring
CREATE TABLE public.llm_monitoring (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  request_type VARCHAR(50) NOT NULL,
  model_used VARCHAR(50) NOT NULL,
  input_tokens INTEGER,
  output_tokens INTEGER,
  response_time_ms INTEGER,
  success BOOLEAN NOT NULL,
  error_type VARCHAR(50),
  cost_estimate DECIMAL(10, 6),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### **Indexes for Performance**

```sql
-- User-based queries optimization
CREATE INDEX idx_jeff_reed_sessions_user_status ON jeff_reed_sessions(user_id, status, created_at DESC);
CREATE INDEX idx_study_guides_user_created ON study_guides(user_id, created_at DESC);
CREATE INDEX idx_study_guides_favorited ON study_guides(user_id, is_favorited) WHERE is_favorited = true;
CREATE INDEX idx_study_guides_tags ON study_guides USING GIN(tags);

-- API monitoring and analytics
CREATE INDEX idx_api_usage_log_created ON api_usage_log(created_at);
CREATE INDEX idx_api_usage_log_endpoint ON api_usage_log(endpoint, created_at);
CREATE INDEX idx_llm_monitoring_created ON llm_monitoring(created_at);
CREATE INDEX idx_llm_monitoring_model ON llm_monitoring(model_used, created_at);

-- Full-text search capability
CREATE INDEX idx_study_guides_search ON study_guides USING GIN(
  to_tsvector('english', title || ' ' || scripture_reference || ' ' || summary)
);
```

### **Row Level Security Policies**

```sql
-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE jeff_reed_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_guides ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_feedback ENABLE ROW LEVEL SECURITY;

-- User can only access their own data
CREATE POLICY user_profiles_policy ON user_profiles FOR ALL USING (auth.uid() = id);
CREATE POLICY jeff_reed_sessions_policy ON jeff_reed_sessions FOR ALL USING (auth.uid() = user_id);
CREATE POLICY study_guides_policy ON study_guides FOR ALL USING (auth.uid() = user_id);
CREATE POLICY user_feedback_policy ON user_feedback FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Admin access for monitoring tables (service role only)
CREATE POLICY api_usage_admin_policy ON api_usage_log FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY llm_monitoring_admin_policy ON llm_monitoring FOR ALL USING (auth.role() = 'service_role');
```

---

## 🔧 **API Architecture**

### **Edge Functions Structure**

```typescript
// /functions/study-generate/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { validateInput, SecurityValidator } from '../_shared/security-validator.ts';
import { LLMService } from '../_shared/llm-service.ts';
import { RateLimiter } from '../_shared/rate-limiter.ts';

interface StudyGenerationRequest {
  input_type: 'scripture' | 'topic' | 'question';
  input_value: string;
  jeff_reed_step: 'observation' | 'interpretation' | 'correlation' | 'application';
  session_id?: string;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return handleCors(req);

  try {
    // 1. Authentication & Rate Limiting
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Authentication required');

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );
    if (authError || !user) throw new Error('Invalid authentication');

    // 2. Rate limiting check
    const rateLimiter = new RateLimiter(supabase);
    await rateLimiter.checkLimit(user.id, 'study_generation');

    // 3. Input validation and security
    const requestData: StudyGenerationRequest = await req.json();
    const validator = new SecurityValidator();
    await validator.validateStudyRequest(requestData);

    // 4. LLM processing
    const llmService = new LLMService();
    const studyContent = await llmService.generateStudy(requestData);

    // 5. Store results
    const { data: studyGuide, error: insertError } = await supabase
      .from('study_guides')
      .insert({
        user_id: user.id,
        session_id: requestData.session_id,
        title: studyContent.title,
        scripture_reference: requestData.input_value,
        jeff_reed_step: requestData.jeff_reed_step,
        summary: studyContent.summary,
        detailed_content: studyContent.content,
        llm_model_used: studyContent.model_used,
        generation_time_ms: studyContent.generation_time
      })
      .select()
      .single();

    if (insertError) throw insertError;

    return new Response(JSON.stringify({
      success: true,
      study_guide: studyGuide
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
```

### **Shared Services Architecture**

```typescript
// /functions/_shared/llm-service.ts
export class LLMService {
  private openAIKey: string;
  private claudeKey: string;

  constructor() {
    this.openAIKey = Deno.env.get('OPENAI_API_KEY') ?? '';
    this.claudeKey = Deno.env.get('ANTHROPIC_API_KEY') ?? '';
  }

  async generateStudy(request: StudyGenerationRequest): Promise<StudyContent> {
    const startTime = Date.now();
    
    try {
      // Primary: OpenAI GPT-3.5 Turbo
      const result = await this.callOpenAI(request);
      return {
        ...result,
        model_used: 'gpt-3.5-turbo',
        generation_time: Date.now() - startTime
      };
    } catch (openAIError) {
      console.warn('OpenAI failed, trying Claude:', openAIError);
      
      try {
        // Fallback: Anthropic Claude
        const result = await this.callClaude(request);
        return {
          ...result,
          model_used: 'claude-haiku',
          generation_time: Date.now() - startTime
        };
      } catch (claudeError) {
        console.error('Both LLM providers failed:', { openAIError, claudeError });
        throw new Error('Study generation temporarily unavailable');
      }
    }
  }

  private async callOpenAI(request: StudyGenerationRequest): Promise<Partial<StudyContent>> {
    const prompt = this.buildJeffReedPrompt(request);
    
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.openAIKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'gpt-3.5-turbo',
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 1500,
        temperature: 0.7
      })
    });

    if (!response.ok) throw new Error(`OpenAI API error: ${response.status}`);
    
    const data = await response.json();
    return this.parseStudyContent(data.choices[0].message.content);
  }

  private buildJeffReedPrompt(request: StudyGenerationRequest): string {
    const stepInstructions = {
      observation: "Focus on what the text says. Identify key facts, people, places, and events.",
      interpretation: "Focus on what the text means. Explain the meaning in the original context.",
      correlation: "Connect this passage with other Biblical texts and themes.",
      application: "Provide practical ways to apply this truth to modern life."
    };

    return `
As a Biblical scholar, create a study guide for the ${request.jeff_reed_step} step of the  methodology.

Scripture: ${request.input_value}
Step: ${request.jeff_reed_step}

Instructions: ${stepInstructions[request.jeff_reed_step]}

Format your response as JSON:
{
  "title": "Brief descriptive title",
  "summary": "2-3 sentence overview",
  "content": {
    "main_points": ["point 1", "point 2", "point 3"],
    "key_insights": ["insight 1", "insight 2"],
    "reflection_questions": ["question 1", "question 2"],
    "practical_application": "Specific ways to apply this truth"
  }
}
    `.trim();
  }
}
```

---

## 📱 **Flutter Architecture**

### **Project Structure**

```
lib/
├── main.dart                    # App entry point
├── app/                         # App-level configuration
│   ├── app.dart                # App widget and theme
│   ├── router.dart             # Navigation routing
│   └── constants.dart          # App constants
├── core/                       # Core utilities and services
│   ├── api/                    # API clients and interceptors
│   ├── cache/                  # Local caching service
│   ├── network/                # Network connectivity
│   └── storage/                # Local storage service
├── features/                   # Feature-based organization
│   ├── auth/                   # Authentication feature
│   │   ├── data/              # Data layer (repositories, DTOs)
│   │   ├── domain/            # Domain layer (entities, use cases)
│   │   └── presentation/      # UI layer (pages, widgets, providers)
│   ├── study_generation/      # Study generation feature
│   └── profile/               # User profile feature
└── shared/                     # Shared widgets and utilities
    ├── widgets/               # Reusable UI components
    ├── models/                # Shared data models
    └── providers/             # Global state providers
```

### **State Management with Riverpod**

```dart
// lib/features/study_generation/presentation/providers/study_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/api/supabase_client.dart';
import '../../domain/entities/study_guide.dart';
import '../../domain/repositories/study_repository.dart';

part 'study_provider.g.dart';

@riverpod
StudyRepository studyRepository(StudyRepositoryRef ref) {
  return StudyRepository(ref.read(supabaseClientProvider));
}

@riverpod
class StudyGenerator extends _$StudyGenerator {
  @override
  FutureOr<StudyGuide?> build() => null;

  Future<StudyGuide> generateStudy({
    required String scriptureReference,
    required JeffReedStep step,
    String? sessionId,
  }) async {
    state = const AsyncLoading();
    
    try {
      final repository = ref.read(studyRepositoryProvider);
      final studyGuide = await repository.generateStudy(
        scriptureReference: scriptureReference,
        step: step,
        sessionId: sessionId,
      );
      
      state = AsyncData(studyGuide);
      
      // Update local cache
      ref.read(studyCacheProvider.notifier).addStudy(studyGuide);
      
      return studyGuide;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

@riverpod
class StudyCache extends _$StudyCache {
  @override
  List<StudyGuide> build() {
    _loadFromLocalStorage();
    return [];
  }

  void addStudy(StudyGuide study) {
    state = [...state, study];
    _saveToLocalStorage();
  }

  void _loadFromLocalStorage() async {
    // Load cached studies from Hive/SQLite
    final storage = ref.read(localStorageProvider);
    final cachedStudies = await storage.getCachedStudies();
    state = cachedStudies;
  }

  void _saveToLocalStorage() async {
    final storage = ref.read(localStorageProvider);
    await storage.saveCachedStudies(state);
  }
}
```

### **Repository Pattern Implementation**

```dart
// lib/features/study_generation/domain/repositories/study_repository.dart
abstract class StudyRepository {
  Future<StudyGuide> generateStudy({
    required String scriptureReference,
    required JeffReedStep step,
    String? sessionId,
  });
  
  Future<List<StudyGuide>> getUserStudies({
    int limit = 20,
    int offset = 0,
  });
  
  Future<void> favoriteStudy(String studyId);
  Future<void> deleteStudy(String studyId);
}

// lib/features/study_generation/data/repositories/study_repository_impl.dart
class StudyRepositoryImpl implements StudyRepository {
  final SupabaseClient _supabase;
  final NetworkService _networkService;
  final CacheService _cacheService;

  StudyRepositoryImpl(this._supabase, this._networkService, this._cacheService);

  @override
  Future<StudyGuide> generateStudy({
    required String scriptureReference,
    required JeffReedStep step,
    String? sessionId,
  }) async {
    // Check network connectivity
    if (!await _networkService.isConnected) {
      throw NetworkException('No internet connection');
    }

    try {
      final response = await _supabase.functions.invoke(
        'study-generate',
        body: {
          'input_type': 'scripture',
          'input_value': scriptureReference,
          'jeff_reed_step': step.name,
          'session_id': sessionId,
        },
      );

      if (response.status != 200) {
        throw ApiException('Study generation failed: ${response.status}');
      }

      final studyData = response.data['study_guide'];
      final studyGuide = StudyGuide.fromJson(studyData);
      
      // Cache the result
      await _cacheService.cacheStudy(studyGuide);
      
      return studyGuide;
    } catch (e) {
      if (e is NetworkException) rethrow;
      throw ApiException('Failed to generate study: $e');
    }
  }

  @override
  Future<List<StudyGuide>> getUserStudies({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('study_guides')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map((json) => StudyGuide.fromJson(json)).toList();
    } catch (e) {
      // Return cached studies if network fails
      if (!await _networkService.isConnected) {
        return await _cacheService.getCachedStudies(limit: limit, offset: offset);
      }
      throw ApiException('Failed to fetch studies: $e');
    }
  }
}
```

---

## 🔐 **Security Architecture**

### **Authentication Flow**

```dart
// lib/core/auth/auth_service.dart
class AuthService {
  final SupabaseClient _supabase;
  final SecureStorageService _secureStorage;

  AuthService(this._supabase, this._secureStorage);

  Future<AuthResponse> signInWithEmailPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _secureStorage.storeTokens(
          accessToken: response.session!.accessToken,
          refreshToken: response.session!.refreshToken!,
        );
      }

      return response;
    } catch (e) {
      throw AuthException('Authentication failed: $e');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        Provider.google,
        redirectTo: 'com.disciplefy.biblestudy://login-callback',
      );
    } catch (e) {
      throw AuthException('Google sign-in failed: $e');
    }
  }

  Future<void> signInAnonymously() async {
    try {
      final response = await _supabase.auth.signInAnonymously();
      
      if (response.user != null) {
        // Set anonymous user limitations
        await _setAnonymousUserLimitations(response.user!.id);
      }
    } catch (e) {
      throw AuthException('Anonymous sign-in failed: $e');
    }
  }

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await _secureStorage.clearTokens();
  }
}
```

### **Input Validation and Sanitization**

```dart
// lib/core/security/input_validator.dart
class InputValidator {
  static const int maxScriptureLength = 200;
  static const int maxTopicLength = 100;
  
  static ValidationResult validateScriptureReference(String input) {
    if (input.isEmpty) {
      return ValidationResult.error('Scripture reference cannot be empty');
    }
    
    if (input.length > maxScriptureLength) {
      return ValidationResult.error('Scripture reference too long');
    }
    
    // Check for potential injection patterns
    if (_containsSuspiciousPatterns(input)) {
      return ValidationResult.error('Invalid characters in scripture reference');
    }
    
    // Validate biblical reference format
    if (!_isValidBiblicalReference(input)) {
      return ValidationResult.error('Please enter a valid biblical reference');
    }
    
    return ValidationResult.success(input.trim());
  }
  
  static bool _containsSuspiciousPatterns(String input) {
    final suspiciousPatterns = [
      RegExp(r'<script[^>]*>', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'data:', caseSensitive: false),
      RegExp(r'vbscript:', caseSensitive: false),
      RegExp(r'on\w+\s*=', caseSensitive: false),
    ];
    
    return suspiciousPatterns.any((pattern) => pattern.hasMatch(input));
  }
  
  static bool _isValidBiblicalReference(String input) {
    // Validate format like "John 3:16", "Genesis 1:1-5", "Psalm 23"
    final biblicalRefPattern = RegExp(
      r'^[1-3]?\s*[A-Za-z]+\s+\d+(?::\d+(?:-\d+)?)?(?:,\s*\d+(?::\d+(?:-\d+)?)?)*$'
    );
    
    return biblicalRefPattern.hasMatch(input.trim());
  }
}

class ValidationResult {
  final bool isValid;
  final String? error;
  final String? sanitizedValue;
  
  ValidationResult._(this.isValid, this.error, this.sanitizedValue);
  
  factory ValidationResult.success(String value) => 
      ValidationResult._(true, null, value);
  
  factory ValidationResult.error(String error) => 
      ValidationResult._(false, error, null);
}
```

---

## 🔄 **Offline-First Architecture**

### **Sync Service Implementation**

```dart
// lib/core/sync/sync_service.dart
class SyncService {
  final SupabaseClient _supabase;
  final LocalStorageService _localStorage;
  final NetworkService _networkService;
  
  SyncService(this._supabase, this._localStorage, this._networkService);

  Future<void> syncData() async {
    if (!await _networkService.isConnected) return;

    try {
      await Future.wait([
        _syncStudyGuides(),
        _syncUserPreferences(),
        _uploadPendingFeedback(),
      ]);
    } catch (e) {
      print('Sync failed: $e');
    }
  }

  Future<void> _syncStudyGuides() async {
    // Get last sync timestamp
    final lastSync = await _localStorage.getLastSyncTime('study_guides');
    
    // Fetch updates from server
    final serverUpdates = await _supabase
        .from('study_guides')
        .select()
        .gte('updated_at', lastSync.toIso8601String())
        .order('updated_at');

    // Update local cache
    for (final update in serverUpdates) {
      await _localStorage.upsertStudyGuide(StudyGuide.fromJson(update));
    }

    // Upload local changes
    final localChanges = await _localStorage.getPendingChanges('study_guides');
    for (final change in localChanges) {
      await _uploadStudyGuide(change);
    }

    // Update sync timestamp
    await _localStorage.setLastSyncTime('study_guides', DateTime.now());
  }

  Future<void> _uploadStudyGuide(LocalChange change) async {
    try {
      switch (change.operation) {
        case 'INSERT':
          await _supabase.from('study_guides').insert(change.data);
          break;
        case 'UPDATE':
          await _supabase
              .from('study_guides')
              .update(change.data)
              .eq('id', change.id);
          break;
        case 'DELETE':
          await _supabase.from('study_guides').delete().eq('id', change.id);
          break;
      }
      
      // Mark as synced
      await _localStorage.markAsSynced(change.id);
    } catch (e) {
      print('Failed to upload change ${change.id}: $e');
    }
  }
}
```

---

## 📊 **Performance Optimization**

### **Caching Strategy**

```dart
// lib/core/cache/cache_service.dart
class CacheService {
  final Box<StudyGuide> _studyCache;
  final Box<CacheMetadata> _metadataCache;
  
  static const Duration defaultTTL = Duration(hours: 24);
  static const int maxCacheSize = 1000; // Maximum number of cached items

  CacheService(this._studyCache, this._metadataCache);

  Future<StudyGuide?> getStudy(String id) async {
    final metadata = _metadataCache.get(id);
    
    if (metadata == null || _isExpired(metadata)) {
      await _removeFromCache(id);
      return null;
    }
    
    return _studyCache.get(id);
  }

  Future<void> cacheStudy(StudyGuide study, {Duration? ttl}) async {
    // Implement LRU eviction if cache is full
    if (_studyCache.length >= maxCacheSize) {
      await _evictLeastRecentlyUsed();
    }
    
    await _studyCache.put(study.id, study);
    await _metadataCache.put(study.id, CacheMetadata(
      id: study.id,
      cachedAt: DateTime.now(),
      expiresAt: DateTime.now().add(ttl ?? defaultTTL),
      accessCount: 0,
    ));
  }

  Future<void> _evictLeastRecentlyUsed() async {
    final metadata = _metadataCache.values.toList()
      ..sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));
    
    final toRemove = metadata.take(maxCacheSize ~/ 10).toList(); // Remove 10%
    
    for (final item in toRemove) {
      await _removeFromCache(item.id);
    }
  }

  bool _isExpired(CacheMetadata metadata) {
    return DateTime.now().isAfter(metadata.expiresAt);
  }
}
```

### **Image and Asset Optimization**

```dart
// lib/core/assets/asset_optimizer.dart
class AssetOptimizer {
  static Widget optimizedImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          width: width,
          height: height,
          color: Colors.white,
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.error),
      ),
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 600,
    );
  }
}
```

---

## 🚀 **Deployment Architecture**

### **CI/CD Pipeline Configuration**

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          
      - name: Get dependencies
        run: flutter pub get
        
      - name: Run tests
        run: flutter test
        
      - name: Run integration tests
        run: flutter test integration_test/
        
  deploy-functions:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        
      - name: Deploy Edge Functions
        run: |
          supabase functions deploy --project-ref ${{ secrets.SUPABASE_PROJECT_REF }}
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          
  deploy-mobile:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          
      - name: Build Android APK
        run: flutter build apk --release
        
      - name: Build iOS (if on macOS)
        run: flutter build ios --release --no-codesign
        if: runner.os == 'macOS'
        
      - name: Deploy to App Store Connect
        # Implementation for app store deployment
        run: echo "Deploy to App Store"
```

### **Environment Configuration**

```dart
// lib/app/config/environment.dart
enum Environment { development, staging, production }

class EnvironmentConfig {
  static const _environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );
  
  static Environment get current {
    switch (_environment) {
      case 'production':
        return Environment.production;
      case 'staging':
        return Environment.staging;
      default:
        return Environment.development;
    }
  }
  
  static String get supabaseUrl {
    switch (current) {
      case Environment.production:
        return 'https://your-prod-project.supabase.co';
      case Environment.staging:
        return 'https://your-staging-project.supabase.co';
      case Environment.development:
        return 'http://localhost:54321';
    }
  }
  
  static String get supabaseAnonKey {
    switch (current) {
      case Environment.production:
        return const String.fromEnvironment('SUPABASE_ANON_KEY_PROD');
      case Environment.staging:
        return const String.fromEnvironment('SUPABASE_ANON_KEY_STAGING');
      case Environment.development:
        return const String.fromEnvironment('SUPABASE_ANON_KEY_DEV');
    }
  }
  
  static bool get enableDebugLogging {
    return current != Environment.production;
  }
  
  static int get cacheSize {
    switch (current) {
      case Environment.production:
        return 1000;
      case Environment.staging:
        return 500;
      case Environment.development:
        return 100;
    }
  }
}
```

---

## 📈 **Monitoring and Analytics**

### **Performance Monitoring Setup**

```dart
// lib/core/monitoring/performance_monitor.dart
class PerformanceMonitor {
  static final FirebasePerformance _performance = FirebasePerformance.instance;
  
  static Future<T> measureOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final trace = _performance.newTrace(operationName);
    trace.start();
    
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await operation();
      trace.setMetric('success', 1);
      return result;
    } catch (e) {
      trace.setMetric('error', 1);
      trace.putAttribute('error_type', e.runtimeType.toString());
      rethrow;
    } finally {
      stopwatch.stop();
      trace.setMetric('duration_ms', stopwatch.elapsedMilliseconds);
      trace.stop();
    }
  }
  
  static void trackUserAction(String action, Map<String, dynamic> parameters) {
    FirebaseAnalytics.instance.logEvent(
      name: action,
      parameters: parameters,
    );
  }
}
```

---

This technical architecture provides a comprehensive foundation for building and deploying the Disciplefy Bible Study app with production-ready standards, security best practices, and scalable infrastructure.