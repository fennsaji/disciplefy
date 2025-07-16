# 🗄️ Disciplefy Bible Study - Backend

Supabase-powered backend with Edge Functions for AI-driven Bible study guide generation using Jeff Reed methodology.

## 🚀 Quick Start

### Prerequisites

- **Supabase CLI**: Latest version
- **Node.js**: `>=18.0.0`
- **npm**: `>=8.0.0`
- **Docker**: For local Supabase development
- **Git**: Version control

### 🔧 Installation

1. **Install Supabase CLI**
   ```bash
   # macOS
   brew install supabase/tap/supabase
   
   # Windows
   scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
   scoop install supabase
   
   # Linux/WSL
   npm install -g supabase
   ```

2. **Clone and setup**
   ```bash
   git clone <repository-url>
   cd bible-study-app/backend
   ```

3. **Configure environment**
   ```bash
   # Copy environment template
   cp ../.env.example .env.local
   
   # Edit .env.local with your API keys
   # Required: OPENAI_API_KEY or ANTHROPIC_API_KEY
   ```

4. **Login to Supabase**
   ```bash
   supabase login
   ```

### 🏃‍♂️ Running Locally

#### Start Local Supabase Instance

```bash
# Initialize Supabase (first time only)
supabase init

# Start local development environment
supabase start

# This will start:
# - PostgreSQL database
# - PostgREST API server
# - Authentication server
# - Edge Functions runtime
# - Storage server
# - Dashboard UI
```

**Expected Output:**
```
Started supabase local development setup.

         API URL: http://localhost:54321
          DB URL: postgresql://postgres:postgres@localhost:54322/postgres
      Studio URL: http://localhost:54323
    Inbucket URL: http://localhost:54324
        anon key: eyJ0eXAiOiJKV1Q...
service_role key: eyJ0eXAiOiJKV1Q...
```

#### Apply Database Migrations

```bash
# Apply all migrations to local database
supabase db reset

# Or apply specific migration
supabase migration up
```

#### Serve Edge Functions Locally

```bash
# Serve all Edge Functions
supabase functions serve

# Serve specific function
supabase functions serve study-generate

# Serve with environment variables
supabase functions serve --env-file .env.local
```

### 🧪 Testing Edge Functions

#### Test Study Guide Generation

```bash
# Test scripture input
curl -X POST 'http://localhost:54321/functions/v1/study-generate' \
  -H 'Authorization: Bearer eyJ0eXAiOiJKV1Q...' \
  -H 'Content-Type: application/json' \
  -d '{
    "input_type": "scripture",
    "input_value": "John 3:16",
    "language": "en",
    "user_context": {
      "is_authenticated": false,
      "session_id": "test-session-123"
    }
  }'
```

#### Test Jeff Reed Topics

```bash
curl -X GET 'http://localhost:54321/functions/v1/topics-jeffreed?category=Spiritual%20Growth&limit=5' \
  -H 'Authorization: Bearer eyJ0eXAiOiJKV1Q...'
```

#### Test Feedback Submission

```bash
curl -X POST 'http://localhost:54321/functions/v1/feedback' \
  -H 'Authorization: Bearer eyJ0eXAiOiJKV1Q...' \
  -H 'Content-Type: application/json' \
  -d '{
    "study_guide_id": "guide-123",
    "was_helpful": true,
    "message": "This was very insightful!",
    "category": "general"
  }'
```

## 📁 Project Structure

```
backend/
├── supabase/
│   ├── config.toml                     # Supabase configuration
│   │
│   ├── migrations/                     # Database migrations
│   │   ├── 20250705000001_initial_schema.sql
│   │   └── 20250705000002_rls_policies.sql
│   │
│   └── functions/                      # Edge Functions
│       ├── _shared/                    # Shared utilities
│       │   ├── cors.ts                 # CORS headers
│       │   ├── error-handler.ts        # Error handling
│       │   ├── security-validator.ts   # Input validation
│       │   ├── rate-limiter.ts         # Rate limiting
│       │   ├── llm-service.ts          # LLM integration
│       │   └── mock-data.ts            # Offline fallback data
│       │
│       ├── study-generate/             # Study guide generation
│       │   └── index.ts
│       │
│       ├── topics-jeffreed/            # Jeff Reed topics
│       │   └── index.ts
│       │
│       ├── feedback/                   # User feedback
│       │   └── index.ts
│       │
│       └── auth-session/               # Session management
│           └── index.ts
│
└── README.md                           # This file
```

## 🗃️ Database Schema

### Core Tables

**Users (auth.users extended):**
- `language_preference`: User's preferred language
- `theme_preference`: Light/dark theme choice
- `is_admin`: Admin access flag

**Study Guides:**
- `id`, `user_id`, `input_type`, `input_value`
- `summary`, `context`, `related_verses`
- `reflection_questions`, `prayer_points`
- `language`, `is_saved`, `created_at`

**Jeff Reed Sessions:**
- Multi-step study sessions following Jeff Reed methodology
- Tracks progress through 4 steps: Context, Scholar, Discussion, Application

**Security & Analytics:**
- `llm_security_events`: Input validation and security monitoring
- `analytics_events`: User behavior and feature usage
- `admin_logs`: Administrative actions and system events

### Row Level Security (RLS)

All tables have RLS enabled with policies:
- Users can only access their own data
- Anonymous users have limited access
- Admins can access all data for support purposes

## 🔐 Authentication & Security

### Authentication Methods
- **Google OAuth**: Social login
- **Apple Sign In**: iOS/macOS integration
- **Anonymous**: Guest access with session tracking

### Security Features
- **Input Validation**: Multi-layer prompt injection protection
- **Rate Limiting**: 3/hour anonymous, 30/hour authenticated
- **SQL Injection Prevention**: Parameterized queries
- **XSS Protection**: Content sanitization
- **CORS Configuration**: Secure cross-origin requests

### API Security
```typescript
// Example security validation
const securityResult = await securityValidator.validateInput(
  requestBody.input_value,
  requestBody.input_type
);

if (!securityResult.isValid) {
  // Log security event and block request
  await logSecurityEvent(securityResult);
  throw new AppError('SECURITY_VIOLATION', securityResult.message);
}
```

## 🤖 LLM Integration

### Supported Providers
- **OpenAI GPT-3.5 Turbo**: Primary LLM provider
- **Anthropic Claude Haiku**: Alternative provider
- **Mock Data**: Offline development mode

### Jeff Reed Methodology Implementation

The LLM service implements Jeff Reed's 4-step Bible study method:

1. **Context**: Historical and cultural background
2. **Scholar's Guide**: Original meaning and interpretation
3. **Group Discussion**: Contemporary application questions
4. **Application**: Personal life transformation steps

### Usage Monitoring
- **Cost Tracking**: Daily and monthly LLM usage limits
- **Rate Limiting**: Prevents API abuse
- **Error Handling**: Graceful fallbacks for API failures

## 📊 Edge Functions

### `/study-generate` - Study Guide Generation
- **Method**: POST
- **Auth**: Optional (anonymous supported)
- **Features**: Input validation, rate limiting, LLM integration
- **Response**: Complete study guide with Jeff Reed structure

### `/topics-jeffreed` - Predefined Topics
- **Method**: GET
- **Auth**: None required
- **Features**: Filtered topic lists, pagination
- **Response**: Curated biblical topics with metadata

### `/feedback` - User Feedback
- **Method**: POST
- **Auth**: Optional
- **Features**: Sentiment analysis, content moderation
- **Response**: Feedback confirmation and analytics

### `/auth-session` - Session Management
- **Method**: POST
- **Auth**: Varies by action
- **Features**: Anonymous sessions, data migration
- **Response**: Session data and authentication status

## 🔄 Development Workflow

### 1. Local Development Setup
```bash
# Start local Supabase
supabase start

# Apply latest migrations
supabase db reset

# Start Edge Functions
supabase functions serve --env-file .env.local
```

### 🔄 **Restarting Supabase After Code Updates**

When you make changes to your backend code, follow this restart workflow to ensure all changes are properly applied:

#### **Quick Restart (Function Changes Only)**
```bash
# For Edge Function changes only
supabase functions serve --env-file .env.local

# Or restart specific function
supabase functions serve study-generate --env-file .env.local
```

#### **Full Restart (Database + Functions)**
```bash
# 1. Stop all Supabase services
supabase stop

# 2. Start Supabase with fresh state
supabase start

# 3. Apply all migrations (resets database)
supabase db reset

# 4. Serve Edge Functions with environment variables
supabase functions serve --env-file .env.local
```

#### **Migration-Only Restart**
```bash
# For database schema changes
supabase db reset

# Or apply migrations incrementally
supabase migration up
```

#### **Configuration Changes Restart**
```bash
# When config.toml is modified
supabase stop
supabase start

# Verify new configuration
supabase status
```

#### **Environment Variables Update**
```bash
# Kill existing function processes
pkill -f "supabase functions serve"

# Restart with updated .env.local
supabase functions serve --env-file .env.local
```

#### **Complete Clean Restart**
```bash
# When facing persistent issues
supabase stop
docker system prune -f  # Clean Docker containers/networks
supabase start
supabase db reset
supabase functions serve --env-file .env.local
```

#### **Restart Verification Checklist**
```bash
# 1. Check all services are running
supabase status

# 2. Verify database connection
psql postgresql://postgres:postgres@localhost:54322/postgres -c "SELECT 1;"

# 3. Test Edge Function endpoint
curl -X GET 'http://localhost:54321/functions/v1/topics-jeffreed' \
  -H 'Authorization: Bearer eyJ0eXAiOiJKV1Q...'

# 4. Check function logs for errors
supabase functions logs
```

#### **Common Restart Scenarios**

**After TypeScript Changes:**
```bash
# Functions auto-reload, but restart if issues persist
supabase functions serve --env-file .env.local
```

**After Database Schema Changes:**
```bash
supabase db reset  # Applies all migrations fresh
```

**After Adding New Dependencies:**
```bash
# Stop and restart to load new packages
supabase stop
supabase start
supabase functions serve --env-file .env.local
```

**After config.toml Changes:**
```bash
supabase stop
supabase start  # Reads updated configuration
```

**When Edge Functions Won't Start:**
```bash
# Check Docker is running
docker ps

# Clean restart
supabase stop
docker system prune -f
supabase start
```

#### **Development Hot Reload**

For faster development iteration:
```bash
# Terminal 1: Keep Supabase running
supabase start

# Terminal 2: Serve functions with auto-reload
supabase functions serve --env-file .env.local

# Functions will automatically reload on TypeScript changes
# Database changes still require: supabase db reset
```

#### **Troubleshooting Restart Issues**

**Services Won't Stop:**
```bash
# Force kill all Supabase processes
pkill -f supabase
docker stop $(docker ps -q)  # Stop all containers
supabase start
```

**Port Conflicts:**
```bash
# Check what's using Supabase ports
lsof -i :54321  # API
lsof -i :54322  # Database
lsof -i :54323  # Studio

# Kill conflicting processes
kill -9 <PID>
supabase start
```

**Database Reset Fails:**
```bash
# Force database reset
supabase db reset --force

# Or manually drop and recreate
psql postgresql://postgres:postgres@localhost:54322/postgres
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
\q
supabase db reset
```

**Environment Variables Not Loading:**
```bash
# Verify .env.local exists and is readable
cat .env.local

# Restart functions with explicit env file
supabase functions serve --env-file $(pwd)/.env.local
```

### 2. Database Changes
```bash
# Create new migration
supabase migration new add_new_feature

# Edit the migration file
# Apply migration
supabase db reset

# Or apply incrementally
supabase migration up 
supabase db push # For production
```

### 3. Edge Function Development
```bash
# Create new function
supabase functions new my-function

# Deploy function locally
supabase functions serve my-function

# Test function
curl -X POST 'http://localhost:54321/functions/v1/my-function'
```

### 4. Testing
```bash
# Test database schema
supabase db reset

# Test Edge Functions
npm test  # If test framework is set up

# Manual testing with curl or Postman
```

## 🚀 Deployment

### Production Deployment

1. **Deploy Edge Functions**
   ```bash
   # Deploy all functions
   supabase functions deploy --project-ref your-project-ref
   
   # Deploy specific function
   supabase functions deploy study-generate --project-ref your-project-ref
   ```

2. **Apply Migrations**
   ```bash
   supabase db push --project-ref your-project-ref
   ```

3. **Set Environment Variables**
   ```bash
   # Set secrets for Edge Functions
   supabase secrets set OPENAI_API_KEY=your-key --project-ref your-project-ref
   supabase secrets set ANTHROPIC_API_KEY=your-key --project-ref your-project-ref
   ```

### CI/CD Integration

The GitHub Actions workflow automatically:
- Deploys Edge Functions on main branch push
- Runs database migrations
- Sets up environment variables from secrets

## 🔧 Configuration

### Supabase Configuration (`config.toml`)

```toml
[api]
enabled = true
port = 54321

[auth]
enabled = true
# OAuth providers configuration
[auth.external.google]
enabled = true
[auth.external.apple]
enabled = true

[db]
enabled = true
port = 54322

[edge_functions]
enabled = true
port = 54323
```

### Environment Variables

**Required:**
```bash
OPENAI_API_KEY=sk-your-openai-key
# OR
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key

# LLM Provider Selection
LLM_PROVIDER=openai  # or 'anthropic'
```

**Optional:**
```bash
# Rate Limiting
ANONYMOUS_RATE_LIMIT=3
AUTHENTICATED_RATE_LIMIT=30

# Security
JWT_SECRET=your-jwt-secret

# Features
ENABLE_MOCK_MODE=true
LOG_LEVEL=debug
```

## 📈 Monitoring & Analytics

### Database Monitoring
```sql
-- Check active connections
SELECT count(*) FROM pg_stat_activity;

-- Monitor query performance
SELECT query, mean_exec_time, calls 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC;
```

### Edge Function Monitoring
- **Supabase Dashboard**: Function invocations and errors
- **Custom Logging**: Application-level monitoring
- **Performance Metrics**: Response times and throughput

### Security Monitoring
- **Security Events**: Tracked in `llm_security_events` table
- **Rate Limiting**: Monitored per user/session
- **Authentication**: Login attempts and patterns

## 🐛 Troubleshooting

### Common Issues

**1. Edge Functions not starting:**
```bash
# Check Docker is running
docker ps

# Restart Supabase
supabase stop
supabase start
```

**2. Database connection issues:**
```bash
# Check database status
supabase status

# Reset database
supabase db reset
```

**3. Migration errors:**
```bash
# Check migration status
supabase migration list

# Manually apply migration
supabase migration up --file migration_file.sql
```

**4. LLM API errors:**
```bash
# Check environment variables
supabase secrets list --project-ref your-project-ref

# Test API key validity
curl -H "Authorization: Bearer $OPENAI_API_KEY" https://api.openai.com/v1/models
```

### Debug Commands

```bash
# View function logs
supabase functions logs study-generate

# Check database logs
supabase logs db

# Monitor real-time database changes
supabase db changes

# Test database connection
psql postgresql://postgres:postgres@localhost:54322/postgres
```

## 🔒 Security Best Practices

1. **Never commit API keys** to version control
2. **Use environment variables** for all secrets
3. **Enable RLS** on all tables with user data
4. **Validate all inputs** before processing
5. **Monitor security events** regularly
6. **Use HTTPS** in production
7. **Regular security updates** for dependencies

## 📚 Resources

- **Supabase Documentation**: https://supabase.com/docs
- **Edge Functions Guide**: https://supabase.com/docs/guides/functions
- **Database Management**: https://supabase.com/docs/guides/database
- **Authentication**: https://supabase.com/docs/guides/auth
- **Row Level Security**: https://supabase.com/docs/guides/auth/row-level-security

## 📞 Support

For backend issues:
1. Check Supabase status page
2. Review function logs in dashboard
3. Test with provided curl commands
4. Create issue with error logs and configuration

---

Built with 🔥 using Supabase and Edge Functions