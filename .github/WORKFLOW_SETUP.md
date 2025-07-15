# GitHub Workflows Setup Guide

This document provides setup instructions for the GitHub Actions workflows in this repository.

## 🔐 How to Get SUPABASE_ACCESS_TOKEN

### Step-by-Step Instructions:

1. **Visit Supabase Dashboard**: Go to [https://app.supabase.com](https://app.supabase.com)
2. **Access Tokens Page**: Click your profile → "Access Tokens" or visit [https://app.supabase.com/account/tokens](https://app.supabase.com/account/tokens)
3. **Generate Token**: 
   - Click "Generate new token"
   - Name: `GitHub Actions CI/CD`
   - **Required Scopes**:
     - ✅ `functions:write` (deploy Edge Functions)
     - ✅ `projects:read` (project operations)  
     - ✅ `database:write` (apply migrations)
     - ✅ Select "All scopes" for simplicity
4. **Copy Token**: Starts with `sbp_` - copy immediately (you won't see it again!)
5. **Add to GitHub**: Repository Settings > Secrets and variables > Actions > New secret

## 🏗️ Environment Setup

### Create Production Environment:
1. Go to **Repository Settings > Environments**
2. Click **"New environment"**
3. Name: `production`
4. **Protection rules** (recommended):
   - ✅ Required reviewers: 1+ team members
   - ✅ Wait timer: 5 minutes
   - ✅ Deployment branches: Selected branches (`main`)

## 📋 Required GitHub Secrets

Configure the following secrets in your GitHub repository settings (`Settings > Secrets and variables > Actions`):

### 🔧 Supabase Configuration
| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `SUPABASE_ACCESS_TOKEN` | Supabase CLI access token | `sbp_xxx...` |
| `SUPABASE_PROJECT_REF` | Supabase project reference ID | `wzdcwxvyjuxjgzpnukvm` |
| `SUPABASE_URL` | Supabase project URL | `https://wzdcwxvyjuxjgzpnukvm.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anonymous key | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` |

### 🔐 How to Get These Values

1. **SUPABASE_ACCESS_TOKEN**: 
   - Go to [Supabase Dashboard](https://app.supabase.com)
   - Settings > Access Tokens
   - Generate new token with necessary permissions

2. **SUPABASE_PROJECT_REF**: 
   - Found in your project URL: `https://app.supabase.com/project/[PROJECT_REF]`
   - Or in project settings

3. **SUPABASE_URL** & **SUPABASE_ANON_KEY**:
   - Project Settings > API
   - Copy URL and anon/public key

## 🔄 Workflow Overview

### 1. Flutter CI (`flutter-ci.yml`)
**Triggers**: Push/PR to `main`/`develop` with frontend changes
- ✅ Code quality checks (formatting, analysis)
- 🧪 Run tests with coverage reporting
- 🔍 Security scanning for hardcoded secrets
- 📊 Coverage threshold validation (70% minimum)

### 2. Backend Deployment (`backend-deploy.yml`)
**Triggers**: Push to `main` with backend changes, manual dispatch
- ✅ Validate Edge Function structure
- 🚀 Deploy to Supabase production
- 🔍 Verify deployment success
- 📈 Function health checks

### 3. Frontend Deployment (`frontend-deploy.yml`)
**Triggers**: Push to `main` with frontend changes, manual dispatch
- 📱 Build web, Android, iOS apps
- ⚡ Optimize builds with compression
- 📦 Upload build artifacts
- 🌐 Deploy web app (configurable hosting)

### 4. Pull Request Checks (`pr-checks.yml`)
**Triggers**: PR opened/updated to `main`/`develop`
- 📝 PR metadata validation
- 🔍 Changed files analysis
- 🛡️ Security vulnerability scanning
- 📋 Code quality enforcement

### 5. Database Migration (`database-migration.yml`)
**Triggers**: Push to `main` with migration changes, manual dispatch
- ✅ Migration validation and syntax checking
- 💾 Automatic database backup
- 🗄️ Apply migrations to production
- ⏪ Rollback capabilities

## 🚀 Workflow Dependencies

### Matrix of Workflow Interactions
```
flutter-ci.yml          -> (Required for) -> frontend-deploy.yml
                        -> (Required for) -> backend-deploy.yml

pr-checks.yml           -> (Parallel to)  -> flutter-ci.yml
                        -> (Gates)        -> All deployment workflows

database-migration.yml  -> (Independent)  -> Can run standalone
                        -> (Dependency)   -> backend-deploy.yml (optional)
```

### Environment Protection Rules
Configure these in `Settings > Environments`:

1. **Production Environment**:
   - Required reviewers: 1+ team members
   - Deployment protection rules
   - Environment secrets (same as above)

## 📊 Workflow Efficiency Optimizations

### 1. Caching Strategy
- ✅ Flutter SDK caching (`cache: true`)
- ✅ Pub dependencies caching
- ✅ Node.js modules caching
- ✅ Build artifact sharing between jobs

### 2. Parallel Execution
- ✅ Frontend/Backend checks run in parallel
- ✅ Multi-platform builds (Web/Android/iOS) in parallel
- ✅ Independent validation jobs

### 3. Smart Triggering
- ✅ Path-based triggering (only run when relevant files change)
- ✅ Concurrency control to prevent resource conflicts
- ✅ Draft PR handling

### 4. Resource Optimization
- ✅ Timeout limits on all jobs (5-45 minutes)
- ✅ Conditional job execution based on changes
- ✅ Artifact retention policies (30 days)

## 🛠️ Customization Options

### Flutter Version Updates
Update `FLUTTER_VERSION` in `frontend-deploy.yml`:
```yaml
env:
  FLUTTER_VERSION: '3.24.1'  # Update as needed
```

### Test Coverage Threshold
Modify in `flutter-ci.yml`:
```bash
if (( $(echo "$coverage < 70" | bc -l) )); then  # Change 70 to desired %
```

### Build Platforms
Modify `workflow_dispatch` inputs in `frontend-deploy.yml`:
```yaml
options:
- web
- android
- ios
- all  # or remove platforms you don't need
```

### Deployment Hosting
Update the web deployment section in `frontend-deploy.yml` based on your chosen hosting platform:
- Supabase Storage
- Vercel
- Netlify  
- Firebase Hosting
- GitHub Pages

## 🔧 Troubleshooting

### Common Issues

1. **Secret Not Found Error**:
   - Verify all required secrets are configured
   - Check secret names match exactly (case-sensitive)

2. **Supabase CLI Authentication Failed**:
   - Regenerate `SUPABASE_ACCESS_TOKEN`
   - Verify token has necessary permissions

3. **Flutter Build Failures**:
   - Check Flutter version compatibility
   - Verify dependencies in `pubspec.yaml`

4. **Migration Validation Failed**:
   - Ensure migration files follow naming convention
   - Check SQL syntax

### Debug Commands

```bash
# Test workflow locally (requires act CLI)
act -j flutter-ci --secret-file .secrets

# Validate workflow YAML
yamllint .github/workflows/*.yml

# Check workflow syntax
github-workflow-validator .github/workflows/
```

## 📈 Monitoring & Metrics

### Workflow Success Metrics
- ✅ Build success rate > 95%
- ⚡ Average build time < 15 minutes
- 🔍 Zero security vulnerabilities in deployments
- 📊 Test coverage maintained > 70%

### Alerts & Notifications
- 🚨 Failed deployments trigger immediate alerts
- 📧 Weekly summary of workflow performance
- 📊 Monthly review of build metrics

---

## 🚀 Next Steps

1. **Configure GitHub Secrets** (all 4 required secrets)
2. **Set up Environment Protection** for production
3. **Test Workflows** with a sample PR
4. **Configure Hosting Platform** for web deployment
5. **Set up Monitoring** for workflow performance

*Workflows are optimized for efficiency, security, and maintainability. Each workflow is focused on a specific concern and designed to run independently when possible.*