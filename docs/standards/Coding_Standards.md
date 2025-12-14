# 📋 Coding Standards
**Disciplefy Bible Study App**

*Enforcing clean, maintainable, and testable code across Flutter and JavaScript*

---

## 🎯 **Philosophy**

This document establishes **non-negotiable** coding standards for the Disciplefy development team. Every line of code must adhere to:

- **Clean Code** principles (Robert Martin)
- **DRY** (Don't Repeat Yourself)
- **SOLID** principles (especially SRP, OCP, DIP)
- **Separation of Concerns**
- **Test-Driven Development**

**Zero tolerance for:** Magic numbers, copy-paste code, untested logic, unclear naming, or architectural violations.

---

## ✨ **Naming Conventions**

### 📱 **Flutter/Dart**

**Classes:** PascalCase with descriptive, single-responsibility names
```dart
// ✅ Good
class StudyGenerationBloc
class BiblicalQuoteValidator
class UserAuthenticationService

// ❌ Bad
class Manager
class Helper
class Utils
class Data
```

**Variables & Functions:** camelCase with intention-revealing names
```dart
// ✅ Good
final String biblicalReference = 'John 3:16';
bool isUserAuthenticated = false;
Future<StudyGuide> generateBibleStudy(String verse) async { }

// ❌ Bad
final String ref = 'John 3:16';
bool flag = false;
Future<dynamic> generate(String s) async { }
```

**Constants:** SCREAMING_SNAKE_CASE
```dart
// ✅ Good
static const int MAX_VERSE_LENGTH = 500;
static const String DEFAULT_BIBLE_VERSION = 'ESV';

// ❌ Bad
static const int maxLength = 500;
static const String version = 'ESV';
```

**Files & Folders:** snake_case
```
✅ Good: study_generation_bloc.dart, user_authentication_service.dart
❌ Bad: StudyGenerationBloc.dart, userService.dart
```

### 🌐 **JavaScript/TypeScript**

**Functions:** camelCase with verb-noun pattern
```javascript
// ✅ Good
async function validateScriptureReference(reference) { }
function sanitizeUserInput(input) { }
function generateSecurityHash(data) { }

// ❌ Bad
async function validate(ref) { }
function sanitize(input) { }
function hash(data) { }
```

**Constants:** SCREAMING_SNAKE_CASE
```javascript
// ✅ Good
const MAX_PROMPT_LENGTH = 2000;
const SUPPORTED_BIBLE_VERSIONS = ['ESV', 'NIV', 'NASB'];

// ❌ Bad
const maxLength = 2000;
const versions = ['ESV', 'NIV', 'NASB'];
```

**Interfaces/Types:** PascalCase with descriptive suffixes
```typescript
// ✅ Good
interface StudyGenerationRequest {
  verse: string;
  difficulty: DifficultyLevel;
}

type ValidationResult = {
  isValid: boolean;
  errors: string[];
};

// ❌ Bad
interface Request { }
type Result = any;
```

---

## 📦 **Folder Structure**

### 📱 **Flutter Architecture**

**Mandatory Clean Architecture structure:**
```
lib/
├── core/
│   ├── di/                    # Dependency Injection
│   ├── error/                 # Error handling
│   ├── network/               # API clients
│   ├── storage/               # Local storage
│   └── utils/                 # Pure utility functions
├── features/
│   └── study_generation/
│       ├── data/
│       │   ├── datasources/   # Remote/Local data sources
│       │   ├── models/        # Data transfer objects
│       │   └── repositories/  # Repository implementations
│       ├── domain/
│       │   ├── entities/      # Business objects
│       │   ├── repositories/  # Repository interfaces
│       │   └── usecases/      # Business logic
│       └── presentation/
│           ├── bloc/          # State management
│           ├── pages/         # UI screens
│           └── widgets/       # Reusable components
└── shared/
    ├── constants/             # App-wide constants
    ├── extensions/            # Dart extensions
    └── theme/                 # UI theming
```

### 🌐 **Supabase Edge Functions**

**Mandatory modular structure:**
```
supabase/functions/
├── _shared/
│   ├── auth/                  # Authentication utilities
│   ├── security/              # Security validation
│   ├── types/                 # TypeScript type definitions
│   └── utils/                 # Pure utility functions
├── study-generate/
│   ├── index.ts              # Entry point
│   ├── handlers/             # Request handlers
│   ├── services/             # Business logic
│   └── validators/           # Input validation
└── user-profile/
    ├── index.ts
    ├── handlers/
    ├── services/
    └── validators/
```

---

## 💡 **Flutter/Dart Guidelines**

### 🏗️ **Architecture Enforcement**

**Dependency Direction:** Presentation → Domain ← Data
```dart
// ✅ Good: Repository interface in domain
abstract class StudyRepository {
  Future<Either<Failure, StudyGuide>> generateStudy(String verse);
}

// ✅ Good: Implementation in data layer
class StudyRepositoryImpl implements StudyRepository {
  final StudyRemoteDataSource remoteDataSource;
  final StudyLocalDataSource localDataSource;
  
  StudyRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });
}

// ❌ Bad: Direct API call in presentation
class StudyPage extends StatelessWidget {
  void _generateStudy() {
    // Direct HTTP call - violates clean architecture
    http.post('api/generate-study');
  }
}
```

### 🎭 **State Management with BLoC**

**Event-driven architecture with clear separation:**
```dart
// ✅ Good: Clear event definition
abstract class StudyGenerationEvent extends Equatable {}

class GenerateStudyRequested extends StudyGenerationEvent {
  final String verse;
  final DifficultyLevel difficulty;
  
  const GenerateStudyRequested({
    required this.verse,
    required this.difficulty,
  });
  
  @override
  List<Object> get props => [verse, difficulty];
}

// ✅ Good: Immutable state with copyWith
class StudyGenerationState extends Equatable {
  final StudyGuide? studyGuide;
  final bool isLoading;
  final String? error;
  
  const StudyGenerationState({
    this.studyGuide,
    this.isLoading = false,
    this.error,
  });
  
  StudyGenerationState copyWith({
    StudyGuide? studyGuide,
    bool? isLoading,
    String? error,
  }) {
    return StudyGenerationState(
      studyGuide: studyGuide ?? this.studyGuide,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
  
  @override
  List<Object?> get props => [studyGuide, isLoading, error];
}

// ❌ Bad: Mutable state
class BadState {
  StudyGuide? studyGuide;
  bool isLoading = false;
  // No props, no immutability
}
```

### 🔧 **Dependency Injection**

**Use GetIt with proper registration:**
```dart
// ✅ Good: Clear dependency registration
void registerDependencies() {
  // External
  sl.registerLazySingleton<http.Client>(() => http.Client());
  
  // Data sources
  sl.registerLazySingleton<StudyRemoteDataSource>(
    () => StudyRemoteDataSourceImpl(client: sl()),
  );
  
  // Repositories
  sl.registerLazySingleton<StudyRepository>(
    () => StudyRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );
  
  // Use cases
  sl.registerLazySingleton(() => GenerateStudy(sl()));
  
  // BLoCs
  sl.registerFactory(() => StudyGenerationBloc(generateStudy: sl()));
}

// ❌ Bad: Direct instantiation
class BadPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Tight coupling, untestable
    final bloc = StudyGenerationBloc(
      generateStudy: GenerateStudy(
        StudyRepositoryImpl(
          remoteDataSource: StudyRemoteDataSourceImpl(
            client: http.Client(),
          ),
        ),
      ),
    );
  }
}
```

### 📝 **Documentation Standards**

**Every public member must have Dartdoc:**
```dart
/// Generates a comprehensive Bible study guide for a given verse or passage.
/// 
/// This use case implements the  methodology for biblical study,
/// ensuring theological accuracy and educational value.
/// 
/// Throws [ServerException] when the API is unavailable.
/// Throws [ValidationException] when the verse format is invalid.
/// 
/// Example:
/// ```dart
/// final result = await generateStudy('John 3:16');
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (studyGuide) => print('Generated: ${studyGuide.title}'),
/// );
/// ```
class GenerateStudy {
  final StudyRepository repository;
  
  const GenerateStudy(this.repository);
  
  /// Executes the study generation with the provided [params].
  Future<Either<Failure, StudyGuide>> call(StudyParams params) async {
    // Implementation
  }
}

// ❌ Bad: No documentation
class GenerateStudy {
  final StudyRepository repository;
  GenerateStudy(this.repository);
  Future<Either<Failure, StudyGuide>> call(StudyParams params) async { }
}
```

---

## 🧠 **JavaScript/TypeScript Guidelines**

### 🏗️ **Modular Architecture**

**Single Responsibility Functions:**
```typescript
// ✅ Good: Single responsibility, pure functions
interface ValidationResult {
  isValid: boolean;
  errors: string[];
}

function validateScriptureReference(reference: string): ValidationResult {
  const errors: string[] = [];
  
  if (!reference.trim()) {
    errors.push('Scripture reference cannot be empty');
  }
  
  if (!SCRIPTURE_PATTERN.test(reference)) {
    errors.push('Invalid scripture format');
  }
  
  return {
    isValid: errors.length === 0,
    errors,
  };
}

function sanitizeInput(input: string): string {
  return input
    .trim()
    .replace(/[<>\"']/g, '')
    .substring(0, MAX_INPUT_LENGTH);
}

// ❌ Bad: Multiple responsibilities
function validateAndSanitize(reference: string): any {
  // Validation AND sanitization in one function
  const clean = reference.trim().replace(/[<>\"']/g, '');
  const isValid = SCRIPTURE_PATTERN.test(clean);
  // Returns unclear type
  return { clean, isValid };
}
```

### 🔄 **Async/Await Best Practices**

**Proper error handling and resource management:**
```typescript
// ✅ Good: Comprehensive error handling
async function generateStudyGuide(
  request: StudyGenerationRequest
): Promise<StudyGuideResponse> {
  const { verse, difficulty, userId } = request;
  
  try {
    // Validate input
    const validationResult = validateScriptureReference(verse);
    if (!validationResult.isValid) {
      throw new ValidationError(validationResult.errors.join(', '));
    }
    
    // Check rate limits
    await checkRateLimit(userId);
    
    // Generate study with timeout
    const studyGuide = await Promise.race([
      callLLMService(verse, difficulty),
      timeoutPromise(30000), // 30 second timeout
    ]);
    
    // Log success (no sensitive data)
    logger.info('Study generated successfully', {
      userId,
      verseLength: verse.length,
      difficulty,
    });
    
    return {
      success: true,
      data: studyGuide,
    };
    
  } catch (error) {
    // Categorize and handle errors
    if (error instanceof ValidationError) {
      logger.warn('Validation failed', { userId, error: error.message });
      throw new APIError('Invalid input', 400);
    }
    
    if (error instanceof RateLimitError) {
      logger.warn('Rate limit exceeded', { userId });
      throw new APIError('Too many requests', 429);
    }
    
    // Log unexpected errors (no sensitive data)
    logger.error('Study generation failed', {
      userId,
      errorType: error.constructor.name,
    });
    
    throw new APIError('Internal server error', 500);
  }
}

// ❌ Bad: Poor error handling
async function badGenerate(verse: string): Promise<any> {
  try {
    const result = await fetch('/api/generate', {
      body: JSON.stringify({ verse }), // No validation
    });
    return result.json(); // No error checking
  } catch (error) {
    console.log(error); // Logs sensitive data
    return null; // Unclear return type
  }
}
```

### 🔒 **Security Patterns**

**Input validation and sanitization:**
```typescript
// ✅ Good: Comprehensive security validation
interface SecurityValidationResult {
  isValid: boolean;
  riskScore: number;
  violations: string[];
}

function validateSecurityInput(input: string): SecurityValidationResult {
  const violations: string[] = [];
  let riskScore = 0;
  
  // Check for prompt injection patterns
  const suspiciousPatterns = [
    /ignore\s+previous\s+instructions/i,
    /system\s*:?\s*you\s+are/i,
    /\[INST\]/i,
    /<\|system\|>/i,
  ];
  
  for (const pattern of suspiciousPatterns) {
    if (pattern.test(input)) {
      violations.push(`Suspicious pattern detected: ${pattern.source}`);
      riskScore += 5;
    }
  }
  
  // Check input length
  if (input.length > MAX_PROMPT_LENGTH) {
    violations.push('Input exceeds maximum length');
    riskScore += 2;
  }
  
  // Check for excessive special characters
  const specialCharCount = (input.match(/[^\w\s]/g) || []).length;
  if (specialCharCount > input.length * 0.1) {
    violations.push('Excessive special characters');
    riskScore += 3;
  }
  
  return {
    isValid: riskScore < 5,
    riskScore,
    violations,
  };
}

// ❌ Bad: No security validation
function badValidate(input: string): boolean {
  return input.length > 0; // Minimal validation
}
```

---

## 🧼 **Linting & Formatting**

### 📱 **Flutter/Dart**

**analysis_options.yaml (mandatory):**
```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  strong-mode:
    implicit-casts: false
    implicit-dynamic: false
  errors:
    missing_required_param: error
    missing_return: error
    todo: ignore

linter:
  rules:
    # Style
    prefer_const_constructors: true
    prefer_const_declarations: true
    prefer_final_fields: true
    prefer_final_locals: true
    prefer_final_in_for_each: true
    
    # Documentation
    public_member_api_docs: true
    
    # Design
    avoid_function_literals_in_foreach_calls: true
    avoid_redundant_argument_values: true
    prefer_expression_function_bodies: true
    
    # Errors
    avoid_slow_async_io: true
    cancel_subscriptions: true
    close_sinks: true
    
    # Pub
    sort_pub_dependencies: true
```

### 🌐 **JavaScript/TypeScript**

**ESLint configuration (.eslintrc.js):**
```javascript
module.exports = {
  extends: [
    '@typescript-eslint/recommended',
    'prettier',
  ],
  rules: {
    // Enforce explicit return types
    '@typescript-eslint/explicit-function-return-type': 'error',
    
    // Prevent any usage
    '@typescript-eslint/no-explicit-any': 'error',
    
    // Enforce naming conventions
    '@typescript-eslint/naming-convention': [
      'error',
      {
        selector: 'function',
        format: ['camelCase'],
        leadingUnderscore: 'forbid',
      },
      {
        selector: 'variable',
        modifiers: ['const'],
        format: ['UPPER_CASE', 'camelCase'],
      },
    ],
    
    // Enforce consistent code style
    'prefer-const': 'error',
    'no-var': 'error',
    'prefer-arrow-callback': 'error',
    'arrow-spacing': 'error',
    
    // Security
    'no-eval': 'error',
    'no-implied-eval': 'error',
    'no-new-func': 'error',
  },
};
```

**Prettier configuration (.prettierrc):**
```json
{
  "singleQuote": true,
  "trailingComma": "es5",
  "tabWidth": 2,
  "semi": true,
  "printWidth": 80,
  "bracketSpacing": true,
  "arrowParens": "avoid"
}
```

---

## 🔍 **Testing Practices**

### 📱 **Flutter Unit Tests**

**Comprehensive test coverage with clear naming:**
```dart
// ✅ Good: Descriptive test names, proper setup
void main() {
  group('StudyGenerationBloc', () {
    late StudyGenerationBloc bloc;
    late MockGenerateStudy mockGenerateStudy;
    
    setUp(() {
      mockGenerateStudy = MockGenerateStudy();
      bloc = StudyGenerationBloc(generateStudy: mockGenerateStudy);
    });
    
    tearDown(() {
      bloc.close();
    });
    
    group('GenerateStudyRequested', () {
      const testVerse = 'John 3:16';
      const testStudyGuide = StudyGuide(
        title: 'Test Study',
        content: 'Test content',
      );
      
      blocTest<StudyGenerationBloc, StudyGenerationState>(
        'should emit loading then success when study generation succeeds',
        build: () {
          when(() => mockGenerateStudy(any()))
              .thenAnswer((_) async => const Right(testStudyGuide));
          return bloc;
        },
        act: (bloc) => bloc.add(
          const GenerateStudyRequested(verse: testVerse),
        ),
        expect: () => [
          const StudyGenerationState(isLoading: true),
          const StudyGenerationState(
            isLoading: false,
            studyGuide: testStudyGuide,
          ),
        ],
        verify: (_) {
          verify(() => mockGenerateStudy(
            const StudyParams(verse: testVerse),
          )).called(1);
        },
      );
      
      blocTest<StudyGenerationBloc, StudyGenerationState>(
        'should emit loading then error when study generation fails',
        build: () {
          when(() => mockGenerateStudy(any()))
              .thenAnswer((_) async => const Left(ServerFailure()));
          return bloc;
        },
        act: (bloc) => bloc.add(
          const GenerateStudyRequested(verse: testVerse),
        ),
        expect: () => [
          const StudyGenerationState(isLoading: true),
          const StudyGenerationState(
            isLoading: false,
            error: 'Server error occurred',
          ),
        ],
      );
    });
  });
}

// ❌ Bad: Poor test structure
void main() {
  test('test bloc', () {
    final bloc = StudyGenerationBloc(generateStudy: MockGenerateStudy());
    // No proper setup, unclear expectations
    expect(bloc.state, isA<StudyGenerationState>());
  });
}
```

### 🌐 **JavaScript/TypeScript Tests**

**Jest with comprehensive coverage:**
```typescript
// ✅ Good: Comprehensive test coverage
describe('validateScriptureReference', () => {
  describe('when given valid scripture references', () => {
    const validReferences = [
      'John 3:16',
      'Romans 8:28-30',
      'Psalm 23:1-6',
      '1 Corinthians 13:4-8',
    ];
    
    test.each(validReferences)(
      'should return valid result for "%s"',
      (reference) => {
        const result = validateScriptureReference(reference);
        
        expect(result.isValid).toBe(true);
        expect(result.errors).toHaveLength(0);
      }
    );
  });
  
  describe('when given invalid scripture references', () => {
    const invalidCases = [
      {
        input: '',
        expectedError: 'Scripture reference cannot be empty',
      },
      {
        input: 'Invalid reference format',
        expectedError: 'Invalid scripture format',
      },
      {
        input: 'John 3:999',
        expectedError: 'Verse number out of range',
      },
    ];
    
    test.each(invalidCases)(
      'should return invalid result for "$input"',
      ({ input, expectedError }) => {
        const result = validateScriptureReference(input);
        
        expect(result.isValid).toBe(false);
        expect(result.errors).toContain(expectedError);
      }
    );
  });
});

describe('generateStudyGuide', () => {
  const mockRequest: StudyGenerationRequest = {
    verse: 'John 3:16',
    difficulty: 'intermediate',
    userId: 'test-user-id',
  };
  
  beforeEach(() => {
    jest.clearAllMocks();
  });
  
  it('should successfully generate study guide for valid input', async () => {
    // Arrange
    const expectedStudy = {
      title: 'Study on John 3:16',
      content: 'Test content',
    };
    
    mockLLMService.mockResolvedValue(expectedStudy);
    mockRateLimit.mockResolvedValue(undefined);
    
    // Act
    const result = await generateStudyGuide(mockRequest);
    
    // Assert
    expect(result.success).toBe(true);
    expect(result.data).toEqual(expectedStudy);
    expect(mockRateLimit).toHaveBeenCalledWith('test-user-id');
    expect(mockLLMService).toHaveBeenCalledWith('John 3:16', 'intermediate');
  });
  
  it('should throw ValidationError for invalid verse format', async () => {
    // Arrange
    const invalidRequest = {
      ...mockRequest,
      verse: '',
    };
    
    // Act & Assert
    await expect(generateStudyGuide(invalidRequest))
      .rejects
      .toThrow(APIError);
    
    expect(mockLLMService).not.toHaveBeenCalled();
  });
});

// ❌ Bad: Minimal test coverage
describe('bad tests', () => {
  it('works', () => {
    const result = validateScriptureReference('John 3:16');
    expect(result).toBeTruthy(); // Unclear expectation
  });
});
```

---

## 🚫 **Anti-Patterns to Avoid**

### ❌ **Flutter Anti-Patterns**

**God Objects:**
```dart
// ❌ Bad: God object with multiple responsibilities
class AppManager {
  void authenticateUser() { }
  void generateStudy() { }
  void manageStorage() { }
  void handleNetworking() { }
  void processPayments() { }
  // 500+ lines of mixed responsibilities
}

// ✅ Good: Single responsibility classes
class AuthenticationService { }
class StudyGenerationService { }
class StorageService { }
class NetworkService { }
class PaymentService { }
```

**Stateful Widget Abuse:**
```dart
// ❌ Bad: Stateful widget for simple display
class StudyTitleWidget extends StatefulWidget {
  final String title;
  const StudyTitleWidget({required this.title});
  
  @override
  _StudyTitleWidgetState createState() => _StudyTitleWidgetState();
}

class _StudyTitleWidgetState extends State<StudyTitleWidget> {
  @override
  Widget build(BuildContext context) {
    return Text(widget.title); // No state needed!
  }
}

// ✅ Good: Stateless widget for static content
class StudyTitleWidget extends StatelessWidget {
  final String title;
  const StudyTitleWidget({required this.title});
  
  @override
  Widget build(BuildContext context) {
    return Text(title);
  }
}
```

### ❌ **JavaScript Anti-Patterns**

**Callback Hell:**
```javascript
// ❌ Bad: Nested callbacks
function badGenerateStudy(verse, callback) {
  validateInput(verse, (isValid) => {
    if (isValid) {
      checkRateLimit((canProceed) => {
        if (canProceed) {
          callLLM(verse, (result) => {
            saveToDatabase(result, (saved) => {
              callback(saved);
            });
          });
        }
      });
    }
  });
}

// ✅ Good: Async/await pattern
async function generateStudy(verse: string): Promise<StudyGuide> {
  const isValid = await validateInput(verse);
  if (!isValid) throw new ValidationError('Invalid verse');
  
  await checkRateLimit();
  const result = await callLLM(verse);
  await saveToDatabase(result);
  
  return result;
}
```

**Magic Numbers and Strings:**
```javascript
// ❌ Bad: Magic values
function validateInput(input) {
  if (input.length > 500) return false; // What is 500?
  if (input.includes('system:')) return false; // What does this check?
  return true;
}

// ✅ Good: Named constants
const MAX_INPUT_LENGTH = 500;
const SYSTEM_PROMPT_INJECTION = 'system:';

function validateInput(input: string): boolean {
  if (input.length > MAX_INPUT_LENGTH) return false;
  if (input.includes(SYSTEM_PROMPT_INJECTION)) return false;
  return true;
}
```

---

## 📊 **Code Quality Metrics**

### 🎯 **Required Standards**

- **Test Coverage:** Minimum 80% for critical paths, 100% for business logic
- **Cyclomatic Complexity:** Maximum 10 per function
- **Function Length:** Maximum 20 lines (excluding documentation)
- **File Length:** Maximum 300 lines
- **Documentation:** 100% public API coverage

### 🔍 **Pre-commit Hooks**

**Required checks before every commit:**
```bash
#!/bin/sh
# .git/hooks/pre-commit

# Flutter checks
cd frontend
flutter analyze --fatal-infos
flutter test
dart format --set-exit-if-changed .

# JavaScript checks
cd ../backend
npm run lint
npm run type-check
npm run test
npm run format:check

echo "✅ All quality checks passed"
```

---

## 🏆 **Code Review Checklist**

### ✅ **Mandatory Review Points**

**Architecture:**
- [ ] Follows Clean Architecture principles
- [ ] Single Responsibility Principle adhered to
- [ ] Dependencies point in correct direction
- [ ] No circular dependencies

**Code Quality:**
- [ ] Self-documenting code with clear naming
- [ ] No magic numbers or strings
- [ ] Proper error handling and logging
- [ ] Thread-safe and memory-efficient

**Testing:**
- [ ] Comprehensive unit test coverage
- [ ] Integration tests for critical flows
- [ ] Mock external dependencies properly
- [ ] Test edge cases and error scenarios

**Security:**
- [ ] Input validation and sanitization
- [ ] No hardcoded secrets or credentials
- [ ] Proper authentication and authorization
- [ ] SQL injection and XSS prevention

**Performance:**
- [ ] Efficient algorithms and data structures
- [ ] Proper async/await usage
- [ ] Memory leak prevention
- [ ] Database query optimization

---

## 🎯 **Enforcement**

**Zero tolerance policy:**
- PRs failing linting checks will be auto-rejected
- Code without tests will not be merged
- Architecture violations require immediate refactoring
- Security issues block all releases

**Continuous improvement:**
- Weekly code quality reviews
- Monthly refactoring sessions
- Quarterly architecture assessments
- Annual coding standards updates

This document is **mandatory** for all contributors. Adherence is **non-negotiable**.

---

*Last updated: $(date +%Y-%m-%d)*  
*Version: 1.0*  
*Status: Enforced*