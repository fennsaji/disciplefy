# 🚀 DevOps & Deployment Plan
**Disciplefy: Bible Study App**

*Production-ready deployment strategy and infrastructure management*

---

## 📋 **Deployment Overview**

### **Deployment Architecture**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │───►│  GitHub Actions │───►│    Supabase     │
│                 │    │      CI/CD      │    │   Production    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       ▼                       │
         │              ┌─────────────────┐              │
         │              │   App Stores    │              │
         │              │  (iOS/Android)  │              │
         │              └─────────────────┘              │
         │                                               │
         ▼                                               ▼
┌─────────────────┐                           ┌─────────────────┐
│   Local Dev     │                           │   Monitoring    │
│   Environment   │                           │   & Analytics   │
└─────────────────┘                           └─────────────────┘
```

### **Environment Strategy**

| **Environment** | **Purpose** | **Infrastructure** | **Data** | **Access** |
|-----------------|-------------|-------------------|----------|------------|
| **Development** | Local development and testing | Local Supabase | Synthetic test data | Developers |
| **Staging** | Pre-production testing | Supabase project | Production-like data | Dev team, QA |
| **Production** | Live user environment | Supabase Pro/Team | Real user data | Authorized personnel |

---

## 🏗️ **Infrastructure Setup**

### **Supabase Project Configuration**

**Development Environment:**
```bash
# Initialize local Supabase development
supabase init
supabase start

# Apply database migrations
supabase db reset

# Deploy functions locally
supabase functions serve
```

**Staging Environment:**
```bash
# Create staging project
supabase projects create disciplefy-staging --org-id <org-id>

# Link to staging project
supabase link --project-ref <staging-project-ref>

# Apply migrations to staging
supabase db push

# Deploy functions to staging
supabase functions deploy --project-ref <staging-project-ref>
```

**Production Environment:**
```bash
# Create production project
supabase projects create disciplefy-production --org-id <org-id>

# Configure production settings
supabase projects update <production-project-ref> \
  --tier pro \
  --compute-limit 5GB \
  --storage-limit 100GB

# Set up custom domain
supabase vanity-subdomains activate \
  --project-ref <production-project-ref> \
  --desired-subdomain api-disciplefy

# Configure SSL and security settings
supabase ssl-certificates create \
  --project-ref <production-project-ref> \
  --domain api.disciplefy.app
```

### **Environment Variables Management**

```yaml
# environments/development.env
ENVIRONMENT=development
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=<dev-anon-key>
SUPABASE_SERVICE_ROLE_KEY=<dev-service-key>
OPENAI_API_KEY=<dev-openai-key>
ANTHROPIC_API_KEY=<dev-claude-key>
DEBUG_MODE=true
LOG_LEVEL=debug
CACHE_TTL=300  # 5 minutes for development

# environments/staging.env
ENVIRONMENT=staging
SUPABASE_URL=https://<staging-project>.supabase.co
SUPABASE_ANON_KEY=<staging-anon-key>
SUPABASE_SERVICE_ROLE_KEY=<staging-service-key>
OPENAI_API_KEY=<staging-openai-key>
ANTHROPIC_API_KEY=<staging-claude-key>
DEBUG_MODE=true
LOG_LEVEL=info
CACHE_TTL=3600  # 1 hour for staging

# environments/production.env
ENVIRONMENT=production
SUPABASE_URL=https://<production-project>.supabase.co
SUPABASE_ANON_KEY=<production-anon-key>
SUPABASE_SERVICE_ROLE_KEY=<production-service-key>
OPENAI_API_KEY=<production-openai-key>
ANTHROPIC_API_KEY=<production-claude-key>
DEBUG_MODE=false
LOG_LEVEL=warn
CACHE_TTL=86400  # 24 hours for production
```

### **Database Migration Strategy**

```sql
-- migrations/20241201000001_initial_schema.sql
-- Create core tables with proper constraints and indexes

-- User profiles extension
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  display_name TEXT,
  preferences JSONB DEFAULT '{}',
  subscription_tier VARCHAR(20) DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Jeff Reed study sessions
CREATE TABLE IF NOT EXISTS public.jeff_reed_sessions (
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

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_tier ON user_profiles(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_jeff_reed_sessions_user_status ON jeff_reed_sessions(user_id, status, created_at DESC);

-- Enable Row Level Security
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE jeff_reed_sessions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY user_profiles_policy ON user_profiles FOR ALL USING (auth.uid() = id);
CREATE POLICY jeff_reed_sessions_policy ON jeff_reed_sessions FOR ALL USING (auth.uid() = user_id);
```

```bash
# Migration deployment script
#!/bin/bash
# scripts/deploy-migrations.sh

set -e

ENVIRONMENT=${1:-staging}
PROJECT_REF=${2}

if [ -z "$PROJECT_REF" ]; then
  echo "Usage: $0 <environment> <project-ref>"
  exit 1
fi

echo "Deploying migrations to $ENVIRONMENT environment..."

# Backup database before migration (production only)
if [ "$ENVIRONMENT" = "production" ]; then
  echo "Creating backup before migration..."
  supabase db dump --project-ref $PROJECT_REF > "backups/pre-migration-$(date +%Y%m%d_%H%M%S).sql"
fi

# Run migrations
supabase db push --project-ref $PROJECT_REF

# Verify migration success
echo "Verifying migration..."
supabase db reset --project-ref $PROJECT_REF --dry-run

echo "Migration completed successfully for $ENVIRONMENT"
```

---

## 🔄 **CI/CD Pipeline**

### **GitHub Actions Workflow**

```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  FLUTTER_VERSION: '3.16.0'
  NODE_VERSION: '18'

jobs:
  test:
    name: Test and Quality Checks
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
        ports:
          - 5432:5432

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: 'backend/supabase/package-lock.json'

      - name: Install Supabase CLI
        run: npm install -g @supabase/cli

      - name: Get Flutter dependencies
        run: flutter pub get
        working-directory: frontend

      - name: Install backend dependencies
        run: npm install
        working-directory: backend/supabase

      - name: Start local Supabase
        run: supabase start
        working-directory: backend/supabase

      - name: Run database migrations
        run: supabase db reset
        working-directory: backend/supabase

      - name: Deploy Edge Functions locally
        run: supabase functions deploy
        working-directory: backend/supabase

      - name: Run Flutter tests
        run: flutter test --coverage
        working-directory: frontend

      - name: Run integration tests
        run: flutter test integration_test/
        working-directory: frontend

      - name: Test Edge Functions
        run: npm test
        working-directory: backend/supabase

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: frontend/coverage/lcov.info

      - name: Stop Supabase
        run: supabase stop
        working-directory: backend/supabase

  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}

      - name: Run Flutter security audit
        run: |
          flutter pub get
          flutter pub deps --json | jq '.packages[] | select(.kind == "direct")' > dependencies.json
          # Custom security scanning logic here

      - name: Scan for secrets
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: main
          head: HEAD

      - name: SAST Scan
        uses: github/super-linter@v4
        env:
          DEFAULT_BRANCH: main
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: [test, security-scan]
    if: github.ref == 'refs/heads/develop'
    
    environment:
      name: staging
      url: https://staging.disciplefy.app

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Supabase CLI
        run: npm install -g @supabase/cli

      - name: Deploy to Staging
        run: |
          # Deploy database migrations
          supabase db push --project-ref ${{ secrets.STAGING_PROJECT_REF }}
          
          # Deploy Edge Functions
          supabase functions deploy --project-ref ${{ secrets.STAGING_PROJECT_REF }}
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

      - name: Run staging tests
        run: |
          # Run end-to-end tests against staging
          npm run test:e2e:staging
        working-directory: backend/supabase

      - name: Notify staging deployment
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          channel: '#deployments'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [test, security-scan]
    if: github.ref == 'refs/heads/main'
    
    environment:
      name: production
      url: https://api.disciplefy.app

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Supabase CLI
        run: npm install -g @supabase/cli

      - name: Create database backup
        run: |
          supabase db dump --project-ref ${{ secrets.PRODUCTION_PROJECT_REF }} \
            > backups/pre-deploy-$(date +%Y%m%d_%H%M%S).sql
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

      - name: Deploy to Production
        run: |
          # Deploy database migrations
          supabase db push --project-ref ${{ secrets.PRODUCTION_PROJECT_REF }}
          
          # Deploy Edge Functions
          supabase functions deploy --project-ref ${{ secrets.PRODUCTION_PROJECT_REF }}
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

      - name: Run production smoke tests
        run: |
          npm run test:smoke:production
        working-directory: backend/supabase

      - name: Notify production deployment
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          channel: '#alerts'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}

  build-mobile:
    name: Build Mobile Apps
    runs-on: macos-latest
    needs: [test, security-scan]
    if: github.ref == 'refs/heads/main'

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}

      - name: Setup iOS signing
        uses: apple-actions/import-codesign-certs@v1
        with:
          p12-file-base64: ${{ secrets.IOS_CERT_BASE64 }}
          p12-password: ${{ secrets.IOS_CERT_PASSWORD }}

      - name: Setup provisioning profile
        uses: apple-actions/download-provisioning-profiles@v1
        with:
          bundle-id: com.disciplefy.biblestudy
          profile-type: ios-app-store
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_PRIVATE_KEY }}

      - name: Get dependencies
        run: flutter pub get
        working-directory: frontend

      - name: Build iOS
        run: |
          flutter build ios --release --no-codesign
          flutter build ipa --release
        working-directory: frontend

      - name: Build Android
        run: |
          flutter build appbundle --release
          flutter build apk --release
        working-directory: frontend

      - name: Upload to App Store Connect
        uses: apple-actions/upload-testflight-build@v1
        with:
          app-path: frontend/build/ios/ipa/disciplefy.ipa
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_PRIVATE_KEY }}

      - name: Upload to Google Play Console
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: com.disciplefy.biblestudy
          releaseFiles: frontend/build/app/outputs/bundle/release/app-release.aab
          track: internal
```

### **Deployment Scripts**

```bash
#!/bin/bash
# scripts/deploy.sh

set -e

ENVIRONMENT=${1:-staging}
VERSION=${2:-$(date +%Y%m%d_%H%M%S)}

echo "🚀 Deploying Disciplefy v$VERSION to $ENVIRONMENT"

# Load environment-specific configuration
source "environments/${ENVIRONMENT}.env"

# Validate prerequisites
echo "📋 Validating prerequisites..."
command -v supabase >/dev/null 2>&1 || { echo "Supabase CLI is required"; exit 1; }
command -v flutter >/dev/null 2>&1 || { echo "Flutter is required"; exit 1; }

# Set project reference based on environment
case $ENVIRONMENT in
  "production")
    PROJECT_REF=$PRODUCTION_PROJECT_REF
    ;;
  "staging")
    PROJECT_REF=$STAGING_PROJECT_REF
    ;;
  *)
    echo "Unknown environment: $ENVIRONMENT"
    exit 1
    ;;
esac

if [ -z "$PROJECT_REF" ]; then
  echo "Project reference not set for environment: $ENVIRONMENT"
  exit 1
fi

# Create backup for production
if [ "$ENVIRONMENT" = "production" ]; then
  echo "💾 Creating database backup..."
  mkdir -p backups
  supabase db dump --project-ref $PROJECT_REF > "backups/pre-deploy-${VERSION}.sql"
  echo "✅ Backup created: backups/pre-deploy-${VERSION}.sql"
fi

# Deploy database migrations
echo "🗄️ Deploying database migrations..."
supabase db push --project-ref $PROJECT_REF
echo "✅ Database migrations deployed"

# Deploy Edge Functions
echo "⚡ Deploying Edge Functions..."
cd backend/supabase
supabase functions deploy --project-ref $PROJECT_REF
cd ../..
echo "✅ Edge Functions deployed"

# Run post-deployment verification
echo "🔍 Running post-deployment verification..."
npm run test:smoke:$ENVIRONMENT
echo "✅ Verification complete"

# Update version tracking
echo "📝 Updating deployment log..."
echo "$(date): Deployed version $VERSION to $ENVIRONMENT" >> deployments.log

echo "🎉 Deployment complete!"
echo "Environment: $ENVIRONMENT"
echo "Version: $VERSION"
echo "Project: $PROJECT_REF"
```

```bash
#!/bin/bash
# scripts/rollback.sh

set -e

ENVIRONMENT=${1}
BACKUP_FILE=${2}

if [ -z "$ENVIRONMENT" ] || [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 <environment> <backup-file>"
  echo "Example: $0 production backups/pre-deploy-20241201_143022.sql"
  exit 1
fi

echo "🔄 Rolling back $ENVIRONMENT to backup: $BACKUP_FILE"

# Confirm rollback
read -p "Are you sure you want to rollback $ENVIRONMENT? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Rollback cancelled"
  exit 1
fi

# Load environment configuration
source "environments/${ENVIRONMENT}.env"

case $ENVIRONMENT in
  "production")
    PROJECT_REF=$PRODUCTION_PROJECT_REF
    ;;
  "staging")
    PROJECT_REF=$STAGING_PROJECT_REF
    ;;
  *)
    echo "Unknown environment: $ENVIRONMENT"
    exit 1
    ;;
esac

# Create emergency backup before rollback
echo "💾 Creating emergency backup before rollback..."
EMERGENCY_BACKUP="backups/emergency-$(date +%Y%m%d_%H%M%S).sql"
supabase db dump --project-ref $PROJECT_REF > $EMERGENCY_BACKUP
echo "✅ Emergency backup created: $EMERGENCY_BACKUP"

# Restore from backup
echo "📤 Restoring database from backup..."
psql $DATABASE_URL < $BACKUP_FILE
echo "✅ Database restored"

# Redeploy previous version of functions
echo "⚡ Redeploying previous Edge Functions..."
git checkout HEAD~1 -- backend/supabase/functions/
cd backend/supabase
supabase functions deploy --project-ref $PROJECT_REF
cd ../..
git checkout HEAD -- backend/supabase/functions/
echo "✅ Previous Edge Functions deployed"

# Verify rollback
echo "🔍 Verifying rollback..."
npm run test:smoke:$ENVIRONMENT
echo "✅ Rollback verification complete"

# Log rollback
echo "📝 Logging rollback..."
echo "$(date): Rolled back $ENVIRONMENT to $BACKUP_FILE" >> rollbacks.log

echo "✅ Rollback complete!"
```

---

## 📊 **Monitoring & Observability**

### **Health Check Endpoints**

```typescript
// backend/supabase/functions/health-check/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  version: string;
  timestamp: string;
  services: {
    database: ServiceStatus;
    llm_integration: ServiceStatus;
    authentication: ServiceStatus;
  };
  metrics: {
    response_time_ms: number;
    memory_usage_mb: number;
    active_connections: number;
  };
}

interface ServiceStatus {
  status: 'up' | 'down' | 'degraded';
  response_time_ms?: number;
  last_error?: string;
}

serve(async (req: Request) => {
  const startTime = Date.now();
  
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Check database connectivity
    const dbCheck = await checkDatabase(supabase);
    
    // Check LLM integration
    const llmCheck = await checkLLMIntegration();
    
    // Check authentication service
    const authCheck = await checkAuthentication(supabase);
    
    // Gather system metrics
    const metrics = await gatherMetrics(supabase);
    
    const responseTime = Date.now() - startTime;
    
    const healthStatus: HealthStatus = {
      status: determineOverallStatus([dbCheck, llmCheck, authCheck]),
      version: Deno.env.get('APP_VERSION') ?? 'unknown',
      timestamp: new Date().toISOString(),
      services: {
        database: dbCheck,
        llm_integration: llmCheck,
        authentication: authCheck,
      },
      metrics: {
        response_time_ms: responseTime,
        memory_usage_mb: metrics.memoryUsage,
        active_connections: metrics.activeConnections,
      },
    };

    const statusCode = healthStatus.status === 'healthy' ? 200 : 503;
    
    return new Response(JSON.stringify(healthStatus, null, 2), {
      status: statusCode,
      headers: { 'Content-Type': 'application/json' },
    });
    
  } catch (error) {
    return new Response(JSON.stringify({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString(),
    }), {
      status: 503,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});

async function checkDatabase(supabase: any): Promise<ServiceStatus> {
  const start = Date.now();
  
  try {
    await supabase.from('user_profiles').select('count').limit(1);
    return {
      status: 'up',
      response_time_ms: Date.now() - start,
    };
  } catch (error) {
    return {
      status: 'down',
      response_time_ms: Date.now() - start,
      last_error: error.message,
    };
  }
}

async function checkLLMIntegration(): Promise<ServiceStatus> {
  const start = Date.now();
  
  try {
    // Simple test to OpenAI API
    const response = await fetch('https://api.openai.com/v1/models', {
      headers: {
        'Authorization': `Bearer ${Deno.env.get('OPENAI_API_KEY')}`,
      },
    });
    
    if (response.ok) {
      return {
        status: 'up',
        response_time_ms: Date.now() - start,
      };
    } else {
      return {
        status: 'degraded',
        response_time_ms: Date.now() - start,
        last_error: `HTTP ${response.status}`,
      };
    }
  } catch (error) {
    return {
      status: 'down',
      response_time_ms: Date.now() - start,
      last_error: error.message,
    };
  }
}
```

### **Monitoring Dashboard Setup**

```bash
#!/bin/bash
# scripts/setup-monitoring.sh

echo "🔧 Setting up monitoring infrastructure..."

# Install monitoring tools
npm install -g @supabase/cli
pip install -r monitoring/requirements.txt

# Create monitoring database tables
psql $DATABASE_URL << EOF
CREATE TABLE IF NOT EXISTS system_metrics (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  metric_type VARCHAR(50) NOT NULL,
  metric_value DECIMAL NOT NULL,
  metadata JSONB DEFAULT '{}',
  recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_system_metrics_type_time ON system_metrics(metric_type, recorded_at DESC);

CREATE TABLE IF NOT EXISTS error_logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  error_type VARCHAR(100) NOT NULL,
  error_message TEXT NOT NULL,
  stack_trace TEXT,
  user_id UUID,
  request_id VARCHAR(100),
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_error_logs_type_time ON error_logs(error_type, created_at DESC);
EOF

# Set up Grafana dashboard (if using)
if command -v grafana-cli &> /dev/null; then
  grafana-cli plugins install grafana-postgresql-datasource
  cp monitoring/grafana-dashboard.json /var/lib/grafana/dashboards/
fi

# Configure alerting rules
cp monitoring/alert-rules.yml /etc/prometheus/rules/
systemctl reload prometheus

echo "✅ Monitoring setup complete"
```

---

## 🔒 **Security & Compliance**

### **Security Deployment Checklist**

```yaml
# Security checklist for deployments
security_checklist:
  pre_deployment:
    - [ ] Code security scan completed
    - [ ] Dependency vulnerability scan passed
    - [ ] API security testing completed
    - [ ] Database migration security review
    - [ ] Environment variable security audit
    
  deployment:
    - [ ] SSL/TLS certificates validated
    - [ ] Database encryption at rest enabled
    - [ ] Row Level Security policies active
    - [ ] API rate limiting configured
    - [ ] CORS policies properly set
    
  post_deployment:
    - [ ] Penetration testing scheduled
    - [ ] Security monitoring alerts active
    - [ ] Backup encryption verified
    - [ ] Access control audit completed
    - [ ] Compliance documentation updated
```

### **Secrets Management**

```bash
#!/bin/bash
# scripts/manage-secrets.sh

ENVIRONMENT=${1}
ACTION=${2}

case $ACTION in
  "rotate")
    echo "🔄 Rotating secrets for $ENVIRONMENT"
    
    # Generate new API keys
    NEW_JWT_SECRET=$(openssl rand -base64 64)
    NEW_API_KEY=$(openssl rand -base64 32)
    
    # Update in Supabase
    supabase secrets set JWT_SECRET="$NEW_JWT_SECRET" --project-ref $PROJECT_REF
    supabase secrets set API_KEY="$NEW_API_KEY" --project-ref $PROJECT_REF
    
    echo "✅ Secrets rotated"
    ;;
    
  "backup")
    echo "💾 Backing up secrets configuration"
    
    # Export current secret names (not values)
    supabase secrets list --project-ref $PROJECT_REF > "secrets-backup-$(date +%Y%m%d).txt"
    
    echo "✅ Secrets configuration backed up"
    ;;
    
  "audit")
    echo "🔍 Auditing secrets usage"
    
    # Check for unused secrets
    # Check for secrets in code (should not exist)
    grep -r "sk-" . --exclude-dir=node_modules || echo "No API keys found in code ✅"
    
    echo "✅ Secrets audit complete"
    ;;
esac
```

---

## 📈 **Performance Optimization**

### **Database Performance Tuning**

```sql
-- Performance optimization queries
-- Run these during deployment to optimize database performance

-- Update table statistics
ANALYZE;

-- Optimize query planner
SET random_page_cost = 1.1;
SET effective_cache_size = '1GB';
SET shared_buffers = '256MB';
SET work_mem = '4MB';

-- Create performance monitoring view
CREATE OR REPLACE VIEW performance_dashboard AS
SELECT 
  schemaname,
  tablename,
  seq_scan,
  seq_tup_read,
  idx_scan,
  idx_tup_fetch,
  n_tup_ins,
  n_tup_upd,
  n_tup_del,
  n_live_tup,
  n_dead_tup,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
ORDER BY seq_scan DESC;

-- Set up automatic vacuuming
ALTER SYSTEM SET autovacuum = on;
ALTER SYSTEM SET autovacuum_max_workers = 3;
ALTER SYSTEM SET autovacuum_naptime = '1min';
SELECT pg_reload_conf();
```

### **Edge Function Optimization**

```typescript
// Optimize Edge Functions for production
// backend/supabase/functions/_shared/performance.ts

export class PerformanceOptimizer {
  private static cache = new Map<string, { data: any; expires: number }>();
  
  static async withCache<T>(
    key: string,
    fetcher: () => Promise<T>,
    ttlSeconds: number = 300
  ): Promise<T> {
    const cached = this.cache.get(key);
    
    if (cached && Date.now() < cached.expires) {
      return cached.data;
    }
    
    const data = await fetcher();
    
    this.cache.set(key, {
      data,
      expires: Date.now() + (ttlSeconds * 1000)
    });
    
    return data;
  }
  
  static clearCache(pattern?: string) {
    if (pattern) {
      for (const key of this.cache.keys()) {
        if (key.includes(pattern)) {
          this.cache.delete(key);
        }
      }
    } else {
      this.cache.clear();
    }
  }
  
  static async withRetry<T>(
    operation: () => Promise<T>,
    maxRetries: number = 3,
    delayMs: number = 1000
  ): Promise<T> {
    let lastError: Error;
    
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error) {
        lastError = error as Error;
        
        if (attempt < maxRetries) {
          await new Promise(resolve => setTimeout(resolve, delayMs * Math.pow(2, attempt)));
        }
      }
    }
    
    throw lastError!;
  }
}
```

---

## 🚨 **Incident Response**

### **Deployment Rollback Procedures**

```bash
#!/bin/bash
# scripts/emergency-rollback.sh

echo "🚨 EMERGENCY ROLLBACK INITIATED"

ENVIRONMENT=${1:-production}
REASON=${2:-"Emergency rollback"}

echo "Environment: $ENVIRONMENT"
echo "Reason: $REASON"
echo "Time: $(date)"

# Immediate actions
echo "1. Stopping new deployments..."
# Disable GitHub Actions workflows temporarily
gh workflow disable "CI/CD Pipeline"

echo "2. Rolling back database..."
LATEST_BACKUP=$(ls -t backups/*.sql | head -n1)
if [ -n "$LATEST_BACKUP" ]; then
  echo "Using backup: $LATEST_BACKUP"
  psql $DATABASE_URL < "$LATEST_BACKUP"
else
  echo "⚠️  No backup found!"
fi

echo "3. Rolling back Edge Functions..."
git checkout HEAD~1 -- backend/supabase/functions/
cd backend/supabase
supabase functions deploy --project-ref $PROJECT_REF
cd ../..

echo "4. Notifying team..."
curl -X POST $SLACK_WEBHOOK_URL \
  -H 'Content-type: application/json' \
  --data "{\"text\":\"🚨 EMERGENCY ROLLBACK: $ENVIRONMENT - $REASON\"}"

echo "5. Running health checks..."
npm run test:smoke:$ENVIRONMENT

echo "✅ Emergency rollback complete"
echo "Please investigate the issue and create an incident report"
```

### **Deployment Validation**

```bash
#!/bin/bash
# scripts/validate-deployment.sh

ENVIRONMENT=${1}
PROJECT_REF=${2}

echo "🔍 Validating deployment to $ENVIRONMENT"

# Health check
echo "1. Checking application health..."
HEALTH_RESPONSE=$(curl -s "https://$PROJECT_REF.supabase.co/functions/v1/health-check")
HEALTH_STATUS=$(echo $HEALTH_RESPONSE | jq -r '.status')

if [ "$HEALTH_STATUS" != "healthy" ]; then
  echo "❌ Health check failed: $HEALTH_STATUS"
  exit 1
fi

# Database connectivity
echo "2. Checking database connectivity..."
DB_CHECK=$(psql $DATABASE_URL -c "SELECT 1" -t)
if [ "$DB_CHECK" != " 1" ]; then
  echo "❌ Database connectivity failed"
  exit 1
fi

# API functionality
echo "3. Testing critical API endpoints..."
API_TEST=$(curl -s -o /dev/null -w "%{http_code}" "https://$PROJECT_REF.supabase.co/rest/v1/study_guides?limit=1")
if [ "$API_TEST" != "200" ]; then
  echo "❌ API test failed: HTTP $API_TEST"
  exit 1
fi

# LLM integration
echo "4. Testing LLM integration..."
LLM_TEST=$(curl -s -X POST "https://$PROJECT_REF.supabase.co/functions/v1/study-generate" \
  -H "Content-Type: application/json" \
  -d '{"input_type":"test","input_value":"test","jeff_reed_step":"observation"}' \
  -w "%{http_code}")

if [[ "$LLM_TEST" != *"200"* && "$LLM_TEST" != *"401"* ]]; then
  echo "❌ LLM integration test failed"
  exit 1
fi

echo "✅ All deployment validations passed"
```

---

This DevOps & Deployment Plan provides a comprehensive framework for managing the deployment lifecycle of the Disciplefy app with proper CI/CD practices, monitoring, security, and incident response procedures.