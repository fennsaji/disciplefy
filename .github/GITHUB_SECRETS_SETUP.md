# GitHub Secrets Setup for Production Deployment

This document provides instructions for setting up GitHub Secrets required for automated production deployment of the Disciplefy Bible Study app.

## 🔒 Security Overview

All production credentials are stored as GitHub Secrets to ensure:
- ✅ **Zero local production access** - Your local environment never touches production
- ✅ **Secure CI/CD** - Only GitHub Actions can deploy to production
- ✅ **Audit trail** - All deployments are logged and traceable
- ✅ **Team safety** - No production credentials in code or local machines

## 📋 Required GitHub Secrets

Navigate to your GitHub repository → Settings → Secrets and Variables → Actions

### 🗄️ Supabase Configuration

#### Production Environment
| Secret Name | Description | How to Get | Example |
|-------------|-------------|------------|---------|
| `SUPABASE_PROJECT_REF` | Production project reference | [Supabase Dashboard](https://app.supabase.com/projects) → Your project → General settings | `wzdcwxvyjuxjgzpnukvm` |
| `SUPABASE_ACCESS_TOKEN` | Personal access token | [Supabase Account](https://app.supabase.com/account/tokens) → Create new token | `sbp_xxx...` |
| `SUPABASE_ANON_KEY` | Production anonymous key | Supabase Dashboard → Project API → anon/public | `eyJhbGciOiJIUzI1...` |
| `SUPABASE_SERVICE_ROLE_KEY` | Production service role key | Supabase Dashboard → Project API → service_role | `eyJhbGciOiJIUzI1...` |

#### Development Environment
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `SUPABASE_DEV_PROJECT_REF` | Development project reference | Create separate dev project in Supabase | ✅ Yes |
| `SUPABASE_DEV_ANON_KEY` | Development anonymous key | Dev project → API settings | ✅ Yes |
| `SUPABASE_DEV_SERVICE_ROLE_KEY` | Development service role key | Dev project → API settings | ✅ Yes |
| `SUPABASE_STAGING_PROJECT_REF` | Staging project reference (optional) | Create staging project in Supabase | 🔶 Optional |

### 🤖 LLM Provider Configuration

#### Production Environment
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `OPENAI_API_KEY` | OpenAI API key (production) | [OpenAI Platform](https://platform.openai.com/api-keys) | ✅ Primary |
| `ANTHROPIC_API_KEY` | Anthropic Claude API key (production) | [Anthropic Console](https://console.anthropic.com/) | 🔶 Backup |
| `LLM_PROVIDER` | Which LLM to use | Set to `openai` or `anthropic` | 🔶 Optional |

#### Development Environment (Optional - can reuse production keys)
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `OPENAI_API_KEY_DEV` | OpenAI API key (development) | Create separate key for dev/testing | 🔶 Optional |
| `ANTHROPIC_API_KEY_DEV` | Anthropic Claude API key (development) | Create separate key for dev/testing | 🔶 Optional |

### 🔐 Authentication Configuration

#### Production Environment
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `GOOGLE_OAUTH_CLIENT_ID` | Google OAuth client ID (production) | [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials | ✅ Yes |
| `GOOGLE_OAUTH_CLIENT_SECRET` | Google OAuth client secret (production) | Same as above | ✅ Yes |
| `JWT_SECRET` | JWT signing secret (production) | Generate: `openssl rand -base64 32` | ✅ Yes |

#### Development Environment (Optional - can reuse production)
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `GOOGLE_OAUTH_CLIENT_ID_DEV` | Google OAuth client ID (development) | Create separate OAuth app for dev | 🔶 Optional |
| `GOOGLE_OAUTH_CLIENT_SECRET_DEV` | Google OAuth client secret (development) | Same as above | 🔶 Optional |
| `JWT_SECRET_DEV` | JWT signing secret (development) | Generate separate secret for dev | 🔶 Optional |

### 🌐 Frontend Deployment (Vercel)

#### Production Environment
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `VERCEL_TOKEN` | Vercel production deployment token | [Vercel Account](https://vercel.com/account/tokens) → Create token | ✅ Yes |
| `VERCEL_ORG_ID` | Vercel organization ID (production) | Vercel Dashboard → Team Settings → General | ✅ Yes |
| `VERCEL_PROJECT_ID` | Vercel production project ID | Production Vercel project → Settings → General | ✅ Yes |

#### Development Environment (Separate Vercel App)
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `VERCEL_DEV_TOKEN` | Vercel development deployment token | [Vercel Account](https://vercel.com/account/tokens) → Create separate token | ✅ Yes |
| `VERCEL_DEV_ORG_ID` | Vercel organization ID (can be same as production) | Vercel Dashboard → Team Settings → General | ✅ Yes |
| `VERCEL_DEV_PROJECT_ID` | Vercel development project ID | **Create separate development Vercel project** → Settings → General | ✅ Yes |

> **Important**: The development deployment uses a completely separate Vercel project to ensure isolation from production.


## 🛠️ Detailed Setup Instructions

### 1. Supabase Configuration

#### Get Project Reference
1. Go to [Supabase Dashboard](https://app.supabase.com/projects)
2. Click on your production project
3. Go to **Settings** → **General**
4. Copy the **Reference ID** (e.g., `wzdcwxvyjuxjgzpnukvm`)

#### Get Access Token
1. Go to [Supabase Account](https://app.supabase.com/account/tokens)
2. Click **Generate new token**
3. Give it a name like "GitHub Actions Production"
4. Copy the token (starts with `sbp_`)

#### Get API Keys
1. In your Supabase project, go to **Settings** → **API**
2. Copy both:
   - **anon/public** key (for frontend)
   - **service_role** key (for backend admin operations)

### 2. OpenAI API Key

1. Go to [OpenAI Platform](https://platform.openai.com/api-keys)
2. Click **Create new secret key**
3. Name it "Disciplefy Production"
4. Copy the key (starts with `sk-proj-` or `sk-`)

### 3. Google OAuth Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create one)
3. Enable the **Google+ API**
4. Go to **APIs & Services** → **Credentials**
5. Create **OAuth 2.0 Client ID** for web application
6. Add authorized redirect URIs:
   - `https://your-project.supabase.co/auth/v1/callback`
   - `https://disciplefy.vercel.app/auth/callback`
7. Copy the **Client ID** and **Client Secret**

### 4. Vercel Configuration

#### Production Vercel App Setup
1. Go to [Vercel Account Settings](https://vercel.com/account/tokens)
2. Click **Create Token**
3. Name it "GitHub Actions Production"
4. Select appropriate scope
5. Copy the token
6. In your production Vercel project:
   - Go to **Settings** → **General**
   - Copy **Project ID** and **Team ID**

#### Development Vercel App Setup (Separate App)
1. **Create a new Vercel project** specifically for development:
   - Name it something like "disciplefy-dev" or "disciplefy-development"
   - This should be completely separate from your production app
2. Create a separate token or reuse the same token:
   - Go to [Vercel Account Settings](https://vercel.com/account/tokens)
   - Create a new token named "GitHub Actions Development" (recommended)
   - Or reuse the production token (less secure but simpler)
3. Get the development project details:
   - Go to your **development** Vercel project
   - Go to **Settings** → **General**
   - Copy the **Project ID** (this will be different from production)
   - Copy the **Team ID** (may be same as production if using same organization)

> **Important**: The development Vercel app should be completely separate from production to ensure isolation and prevent accidental production deployments.

### 5. Generate JWT Secret

Run this command locally to generate a secure JWT secret:
```bash
openssl rand -base64 32
```

---

## 🔧 Setting Up GitHub Secrets

### Method 1: GitHub Web Interface

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret one by one

### Method 2: GitHub CLI (if you have it)

```bash
# Supabase secrets
gh secret set SUPABASE_PROJECT_REF -b "your-project-ref"
gh secret set SUPABASE_ACCESS_TOKEN -b "your-access-token"
gh secret set SUPABASE_ANON_KEY -b "your-anon-key"
gh secret set SUPABASE_SERVICE_ROLE_KEY -b "your-service-key"

# LLM secrets
gh secret set OPENAI_API_KEY -b "your-openai-key"
gh secret set LLM_PROVIDER -b "openai"

# OAuth secrets
gh secret set GOOGLE_OAUTH_CLIENT_ID -b "your-client-id"
gh secret set GOOGLE_OAUTH_CLIENT_SECRET -b "your-client-secret"
gh secret set JWT_SECRET -b "your-jwt-secret"

# Vercel production secrets
gh secret set VERCEL_TOKEN -b "your-production-vercel-token"
gh secret set VERCEL_ORG_ID -b "your-org-id"
gh secret set VERCEL_PROJECT_ID -b "your-production-project-id"

# Vercel development secrets (separate app)
gh secret set VERCEL_DEV_TOKEN -b "your-development-vercel-token"
gh secret set VERCEL_DEV_ORG_ID -b "your-org-id"  # May be same as production
gh secret set VERCEL_DEV_PROJECT_ID -b "your-development-project-id"

# Development Supabase secrets (if using separate dev project)
gh secret set SUPABASE_DEV_PROJECT_REF -b "your-dev-project-ref"
gh secret set SUPABASE_DEV_ANON_KEY -b "your-dev-anon-key"
```

---

## 🚀 Deployment Workflows

### Backend Deployment

#### Production Deployment
- **Trigger**: Push to `main` branch with changes in `backend/` folder
- **Manual**: Repository → Actions → "Backend Deployment - Supabase Functions" → Run workflow
- **What it deploys**:
  - ✅ Database migrations
  - ✅ Row Level Security policies
  - ✅ Edge Functions
  - ✅ Function secrets

#### Development Deployment
- **Trigger**: Push to `develop`/`dev`/`staging` branches OR Pull Requests to `main`
- **Manual**: Repository → Actions → "Backend Development Deployment" → Run workflow
- **Environments**: `development` (default) or `staging`
- **What it deploys**:
  - ✅ Edge Functions (with development settings)
  - ✅ Database migrations (optional)
  - ✅ RLS Policies (optional)
  - ✅ Function secrets (with development config)
- **Features**:
  - 🔍 Automatic PR comments with deployment URLs
  - 🧪 Comprehensive testing and validation
  - 🔒 Security scanning and checks
  - 🧹 Automatic cleanup of sensitive files

### Frontend Deployment

#### Production Deployment
- **Trigger**: Push to `main` branch with changes in `frontend/` folder
- **Manual**: Repository → Actions → "Deploy Frontend to Production" → Run workflow
- **What it deploys**:
  - ✅ Flutter web build
  - ✅ Vercel deployment
  - ✅ Route testing

#### Development Deployment (Separate Vercel App)
- **Trigger**: Push to `develop`/`dev`/`development` branches OR Pull Requests to `main`
- **Manual**: Repository → Actions → "Frontend Development Deployment" → Run workflow
- **Environments**: `development` (default) or `staging`
- **What it deploys**:
  - ✅ Flutter web build (with development configuration and logging)
  - ✅ **Separate Vercel development app** (completely isolated from production)
  - ✅ Development Supabase backend integration
  - ✅ Route testing and validation
  - ✅ PR preview deployments on development app
- **Features**:
  - 🔒 **Zero production dependencies** - Uses only development secrets
  - 🧪 Enhanced debugging and logging enabled
  - 📊 Source maps preserved for debugging
  - 🔍 Automatic PR comments with development app URLs
  - 🛡️ Security scanning and best practices checking
  - 🧹 Automatic cleanup of sensitive files
  - 📊 Source map preservation for development environments

---

## 🔍 Verification

### Test Backend Deployment
After setting up secrets, test the backend deployment:

1. Go to **Actions** tab in your GitHub repository
2. Click **Backend Deployment - Supabase Functions**
3. Click **Run workflow** → **Run workflow**
4. Monitor the deployment progress

### Test Frontend Deployment

#### Production Deployment
1. Go to **Actions** tab in your GitHub repository
2. Click **Deploy Frontend to Production**
3. Click **Run workflow** → **Run workflow**
4. Check that https://disciplefy.vercel.app loads correctly

#### Development Deployment
1. Go to **Actions** tab in your GitHub repository
2. Click **Frontend Development Deployment**
3. Click **Run workflow** → Select environment (`preview`, `development`, or `staging`) → **Run workflow**
4. Check the deployment URL provided in the workflow output

---

## 🛡️ Security Best Practices

### ✅ Do's
- ✅ **Rotate secrets regularly** (every 3-6 months)
- ✅ **Use least privilege** (minimal required permissions)
- ✅ **Monitor access logs** (check Supabase and Vercel logs)
- ✅ **Test in staging first** (if you have a staging environment)
- ✅ **Document secret rotation** (when and why you changed them)

### ❌ Don'ts
- ❌ **Never commit secrets** to code
- ❌ **Don't share secrets** via insecure channels
- ❌ **Don't use personal accounts** for production services
- ❌ **Don't skip environment separation** (prod vs dev)

---

## 🚨 Troubleshooting

### Common Issues

#### "Invalid project reference"
- ✅ Verify `SUPABASE_PROJECT_REF` is correct
- ✅ Ensure `SUPABASE_ACCESS_TOKEN` has proper permissions

#### "Authentication failed"
- ✅ Check if access token is expired
- ✅ Verify token has project access permissions

#### "Function deployment failed"
- ✅ Check function TypeScript syntax
- ✅ Verify all dependencies are properly imported

#### "Vercel deployment failed"
- ✅ Verify `VERCEL_TOKEN` has deployment permissions
- ✅ Check `VERCEL_PROJECT_ID` is correct
- ✅ Ensure Flutter build completed successfully

### Getting Help

1. **Check GitHub Actions logs** for detailed error messages
2. **Review Supabase logs** in dashboard
3. **Check Vercel deployment logs** in dashboard
4. **Verify all secrets are set** in repository settings

---

## 📞 Support Checklist

Before asking for help, ensure:

- [ ] All required secrets are set in GitHub
- [ ] Supabase project exists and is accessible
- [ ] Vercel project is properly configured
- [ ] OAuth providers are set up correctly
- [ ] GitHub Actions have proper permissions
- [ ] Latest workflow files are in repository

---

**Last Updated**: August 2025  
**Version**: 1.0.0  
**Maintained by**: Disciplefy Development Team