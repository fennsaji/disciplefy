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
| `SUPABASE_PROJECT_ID` | Production project ID | Supabase Dashboard → Project Settings → General | `wzdcwxvyjuxjgzpnukvm` |
| `SUPABASE_ACCESS_TOKEN` | Personal access token | [Supabase Account](https://app.supabase.com/account/tokens) → Create new token | `sbp_xxx...` |
| `SUPABASE_URL` | Production project URL | Supabase Dashboard → Project Settings → API | `https://xxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Production anonymous key | Supabase Dashboard → Project API → anon/public | `eyJhbGciOiJIUzI1...` |
| `SUPABASE_SERVICE_ROLE_KEY` | Production service role key | Supabase Dashboard → Project API → service_role | `eyJhbGciOiJIUzI1...` |
| `SUPABASE_DB_PASSWORD` | Production database password | Supabase Dashboard → Database Settings | `your-db-password` |

#### Development Environment
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `SUPABASE_DEV_PROJECT_REF` | Development project reference | Create separate dev project in Supabase | ✅ Yes |
| `SUPABASE_DEV_PROJECT_ID` | Development project ID | Dev project settings | ✅ Yes |
| `SUPABASE_DEV_URL` | Development project URL | Dev project API settings | ✅ Yes |
| `SUPABASE_DEV_ANON_KEY` | Development anonymous key | Dev project → API settings | ✅ Yes |
| `SUPABASE_DEV_SERVICE_ROLE_KEY` | Development service role key | Dev project → API settings | ✅ Yes |
| `SUPABASE_DEV_DB_PASSWORD` | Development database password | Dev project database settings | ✅ Yes |
| `SUPABASE_STAGING_PROJECT_REF` | Staging project reference (optional) | Create staging project in Supabase | 🔶 Optional |

### 🔔 Firebase/FCM Configuration (Push Notifications)

#### Production Environment
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `FIREBASE_PROJECT_ID` | Firebase project ID | [Firebase Console](https://console.firebase.google.com/) → Project Settings → General | ✅ Yes |
| `FIREBASE_PRIVATE_KEY` | Firebase service account private key | Firebase Console → Project Settings → Service Accounts → Generate new private key → Extract `private_key` from JSON | ✅ Yes |
| `FIREBASE_CLIENT_EMAIL` | Firebase service account email | Same service account JSON → Extract `client_email` | ✅ Yes |

#### Development Environment
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `FIREBASE_PROJECT_ID_DEV` | Firebase dev project ID | Create separate Firebase project for development | ✅ Yes |
| `FIREBASE_PRIVATE_KEY_DEV` | Firebase dev private key | Dev project service account JSON | ✅ Yes |
| `FIREBASE_CLIENT_EMAIL_DEV` | Firebase dev client email | Dev project service account JSON | ✅ Yes |

> **Note**: Firebase credentials are used for FCM (Firebase Cloud Messaging) to send push notifications. Create separate Firebase projects for production and development.

**How to Get Firebase Service Account JSON:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Project Settings** (gear icon) → **Service Accounts**
4. Click **Generate new private key**
5. Download the JSON file
6. Extract the following fields:
   - `project_id` → `FIREBASE_PROJECT_ID`
   - `private_key` → `FIREBASE_PRIVATE_KEY` (keep the `\n` characters as-is)
   - `client_email` → `FIREBASE_CLIENT_EMAIL`

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

### 📖 Bible API Configuration

| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `BIBLE_API` | API.Bible API key | [API.Bible Signup](https://scripture.api.bible/signup) → Create account → Copy API key | ✅ Yes |

> **Note**: The same API key can be used for both production and development environments. API.Bible offers 5,000 free queries per day for non-commercial use.

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

### 🔒 Security & Cron Job Configuration

#### Production Environment
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `CRON_SECRET` | Dedicated secret for cron job authentication | Generate: `openssl rand -base64 32` | ✅ Yes |

#### Development Environment
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `CRON_SECRET_DEV` | Cron secret for development | Generate separate secret for dev | ✅ Yes |

> **Security Note**: `CRON_SECRET` is used to authenticate scheduled cron jobs (notifications, cleanup tasks) without exposing the service role key in request headers. This provides better security isolation.

### 💳 Payment Configuration (Razorpay)

#### Production Environment
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `RAZORPAY_KEY_ID` | Razorpay production key ID | [Razorpay Dashboard](https://dashboard.razorpay.com/) → Settings → API Keys | ✅ Yes |
| `RAZORPAY_KEY_SECRET` | Razorpay production key secret | Same as above | ✅ Yes |
| `RAZORPAY_WEBHOOK_SECRET` | Razorpay webhook secret | Razorpay Dashboard → Webhooks → Create/Edit webhook → Secret | ✅ Yes |

#### Development Environment
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `RAZORPAY_KEY_ID_DEV` | Razorpay test key ID | Razorpay Dashboard → Toggle to Test Mode → API Keys | ✅ Yes |
| `RAZORPAY_KEY_SECRET_DEV` | Razorpay test key secret | Same as above | ✅ Yes |
| `RAZORPAY_WEBHOOK_SECRET_DEV` | Razorpay test webhook secret | Test mode webhooks → Secret | ✅ Yes |

> **Important**: Always use Razorpay Test Mode keys for development to avoid processing real payments.

### 📱 SMS Configuration (Twilio)

#### Production Environment
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `TWILIO_ACCOUNT_SID` | Twilio production account SID | [Twilio Console](https://www.twilio.com/console) → Account Info | 🔶 Optional |
| `TWILIO_AUTH_TOKEN` | Twilio production auth token | Same as above | 🔶 Optional |
| `TWILIO_MESSAGE_SERVICE_SID` | Twilio messaging service SID | Twilio Console → Messaging → Services | 🔶 Optional |

#### Development Environment
| Secret Name | Description | How to Get | Required |
|-------------|-------------|------------|----------|
| `TWILIO_ACCOUNT_SID_DEV` | Twilio test account SID | Create separate test account | 🔶 Optional |
| `TWILIO_AUTH_TOKEN_DEV` | Twilio test auth token | Test account credentials | 🔶 Optional |
| `TWILIO_MESSAGE_SERVICE_SID_DEV` | Twilio test messaging service | Test account services | 🔶 Optional |

> **Note**: Twilio is optional and only needed if SMS notifications are enabled.

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

---

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

### 2. Firebase/FCM Setup

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project**
3. Enter project name (e.g., "Disciplefy Production")
4. Enable Google Analytics (optional)
5. Create project

#### Get Service Account Credentials
1. In Firebase Console, click **Project Settings** (gear icon)
2. Go to **Service Accounts** tab
3. Click **Generate new private key**
4. Download the JSON file
5. Extract these fields from the JSON:
   ```json
   {
     "project_id": "your-project-id",           // → FIREBASE_PROJECT_ID
     "private_key": "-----BEGIN PRIVATE KEY-----\n...",  // → FIREBASE_PRIVATE_KEY
     "client_email": "firebase-adminsdk-xxx@xxx.iam.gserviceaccount.com"  // → FIREBASE_CLIENT_EMAIL
   }
   ```

#### Enable Firebase Cloud Messaging
1. In Firebase Console, go to **Project Settings** → **Cloud Messaging**
2. Note the **Server key** (not needed for GitHub secrets, but useful for reference)
3. Make sure Firebase Cloud Messaging API is enabled

### 3. OpenAI API Key

1. Go to [OpenAI Platform](https://platform.openai.com/api-keys)
2. Click **Create new secret key**
3. Name it "Disciplefy Production"
4. Copy the key (starts with `sk-proj-` or `sk-`)

### 4. Google OAuth Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create one)
3. Enable the **Google+ API**
4. Go to **APIs & Services** → **Credentials**
5. Create **OAuth 2.0 Client ID** for web application
6. Add authorized redirect URIs:
   - `https://your-project.supabase.co/auth/v1/callback`
   - `https://www.disciplefy.in/auth/callback`
7. Copy the **Client ID** and **Client Secret**

### 5. Razorpay Setup

#### Production Keys
1. Go to [Razorpay Dashboard](https://dashboard.razorpay.com/)
2. Ensure you're in **Live Mode** (toggle in top-left)
3. Go to **Settings** → **API Keys**
4. Click **Generate Key**
5. Copy both **Key ID** and **Key Secret**

#### Webhook Secret
1. Go to **Settings** → **Webhooks**
2. Create a new webhook or edit existing
3. Set webhook URL: `https://your-project.supabase.co/functions/v1/razorpay-webhook`
4. Copy the **Webhook Secret**

#### Development/Test Keys
1. Toggle to **Test Mode** in Razorpay Dashboard
2. Repeat the same process for test keys
3. Test mode keys allow testing without real transactions

### 6. Generate Security Secrets

#### JWT Secret
```bash
openssl rand -base64 32
```

#### CRON_SECRET (Production)
```bash
openssl rand -base64 32
```

#### CRON_SECRET_DEV (Development)
```bash
openssl rand -base64 32
```

> **Important**: Generate separate secrets for production and development.

### 7. Vercel Configuration

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

---

## 🔧 Setting Up GitHub Secrets

### Method 1: GitHub Web Interface

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret one by one

### Method 2: GitHub CLI (Recommended for Bulk Setup)

```bash
# ============================================================================
# Production Secrets
# ============================================================================

# Supabase Production
gh secret set SUPABASE_PROJECT_REF -b "your-project-ref"
gh secret set SUPABASE_PROJECT_ID -b "your-project-id"
gh secret set SUPABASE_ACCESS_TOKEN -b "your-access-token"
gh secret set SUPABASE_URL -b "https://your-project.supabase.co"
gh secret set SUPABASE_ANON_KEY -b "your-anon-key"
gh secret set SUPABASE_SERVICE_ROLE_KEY -b "your-service-key"
gh secret set SUPABASE_DB_PASSWORD -b "your-db-password"

# Firebase/FCM Production
gh secret set FIREBASE_PROJECT_ID -b "your-project-id"
gh secret set FIREBASE_PRIVATE_KEY -b "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
gh secret set FIREBASE_CLIENT_EMAIL -b "firebase-adminsdk-xxx@xxx.iam.gserviceaccount.com"

# LLM Production
gh secret set OPENAI_API_KEY -b "sk-proj-xxx"
gh secret set ANTHROPIC_API_KEY -b "sk-ant-xxx"
gh secret set LLM_PROVIDER -b "openai"

# Bible API
gh secret set BIBLE_API -b "your-bible-api-key"

# OAuth Production
gh secret set GOOGLE_OAUTH_CLIENT_ID -b "your-client-id"
gh secret set GOOGLE_OAUTH_CLIENT_SECRET -b "your-client-secret"
gh secret set JWT_SECRET -b "your-jwt-secret"

# Security Production
gh secret set CRON_SECRET -b "your-cron-secret"

# Razorpay Production
gh secret set RAZORPAY_KEY_ID -b "rzp_live_xxx"
gh secret set RAZORPAY_KEY_SECRET -b "your-secret"
gh secret set RAZORPAY_WEBHOOK_SECRET -b "your-webhook-secret"

# Twilio Production (Optional)
gh secret set TWILIO_ACCOUNT_SID -b "ACxxxxxxxxxxxx"
gh secret set TWILIO_AUTH_TOKEN -b "your-auth-token"
gh secret set TWILIO_MESSAGE_SERVICE_SID -b "MGxxxxxxxxxxxx"

# Vercel Production
gh secret set VERCEL_TOKEN -b "your-production-vercel-token"
gh secret set VERCEL_ORG_ID -b "your-org-id"
gh secret set VERCEL_PROJECT_ID -b "your-production-project-id"

# ============================================================================
# Development Secrets
# ============================================================================

# Supabase Development
gh secret set SUPABASE_DEV_PROJECT_REF -b "your-dev-project-ref"
gh secret set SUPABASE_DEV_PROJECT_ID -b "your-dev-project-id"
gh secret set SUPABASE_DEV_URL -b "https://your-dev-project.supabase.co"
gh secret set SUPABASE_DEV_ANON_KEY -b "your-dev-anon-key"
gh secret set SUPABASE_DEV_SERVICE_ROLE_KEY -b "your-dev-service-key"
gh secret set SUPABASE_DEV_DB_PASSWORD -b "your-dev-db-password"

# Firebase/FCM Development
gh secret set FIREBASE_PROJECT_ID_DEV -b "your-dev-project-id"
gh secret set FIREBASE_PRIVATE_KEY_DEV -b "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
gh secret set FIREBASE_CLIENT_EMAIL_DEV -b "firebase-adminsdk-xxx@xxx-dev.iam.gserviceaccount.com"

# LLM Development (Optional)
gh secret set OPENAI_API_KEY_DEV -b "sk-proj-xxx-dev"
gh secret set ANTHROPIC_API_KEY_DEV -b "sk-ant-xxx-dev"
gh secret set LLM_PROVIDER_DEV -b "openai"

# OAuth Development (Optional)
gh secret set GOOGLE_OAUTH_CLIENT_ID_DEV -b "your-dev-client-id"
gh secret set GOOGLE_OAUTH_CLIENT_SECRET_DEV -b "your-dev-client-secret"
gh secret set JWT_SECRET_DEV -b "your-dev-jwt-secret"

# Security Development
gh secret set CRON_SECRET_DEV -b "your-dev-cron-secret"

# Razorpay Development (Test Mode)
gh secret set RAZORPAY_KEY_ID_DEV -b "rzp_test_xxx"
gh secret set RAZORPAY_KEY_SECRET_DEV -b "your-test-secret"
gh secret set RAZORPAY_WEBHOOK_SECRET_DEV -b "your-test-webhook-secret"

# Twilio Development (Optional)
gh secret set TWILIO_ACCOUNT_SID_DEV -b "ACxxxxxxxxxxxx-dev"
gh secret set TWILIO_AUTH_TOKEN_DEV -b "your-dev-auth-token"
gh secret set TWILIO_MESSAGE_SERVICE_SID_DEV -b "MGxxxxxxxxxxxx-dev"

# Vercel Development
gh secret set VERCEL_DEV_TOKEN -b "your-development-vercel-token"
gh secret set VERCEL_DEV_ORG_ID -b "your-org-id"
gh secret set VERCEL_DEV_PROJECT_ID -b "your-development-project-id"
```

---

## 🚀 Deployment Workflows

### Backend Deployment

#### Production Deployment
- **Trigger**: Push to `main` branch with changes in `backend/` folder
- **Manual**: Repository → Actions → "Backend Production Deployment" → Run workflow
- **What it deploys**:
  - ✅ Database migrations
  - ✅ Row Level Security policies
  - ✅ Edge Functions
  - ✅ Function secrets (includes Firebase, CRON_SECRET, Razorpay, etc.)

#### Development Deployment
- **Trigger**: Push to `dev` branch with changes in `backend/` folder
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
- **Trigger**: Push to `dev` branch with changes in `frontend/` folder
- **Manual**: Repository → Actions → "Frontend Development Deployment" → Run workflow
- **Environments**: `development` (default) or `staging`
- **What it deploys**:
  - ✅ Flutter web build (with development configuration and logging)
  - ✅ **Separate Vercel development app** (completely isolated from production)
  - ✅ Development Supabase backend integration
  - ✅ Route testing and validation
  - ✅ PR preview deployments on development app

### Scheduled Cron Workflows

#### Production Cron Jobs
- **Send Push Notifications (Production)**
  - Daily Verse: 8 times/day across timezones (6 AM local time)
  - Recommended Topics: 8 times/day across timezones (8 AM local time)
  - Uses `CRON_SECRET` for authentication

- **Cleanup FCM Tokens (Production)**
  - Daily at 02:00 UTC
  - Removes tokens inactive for 90+ days
  - Uses `CRON_SECRET` for authentication

#### Development Cron Jobs
- **Send Push Notifications (Development)**
  - Daily Verse: 2 times/day (reduced frequency)
  - Recommended Topics: 2 times/day (reduced frequency)
  - Uses `CRON_SECRET_DEV` for authentication
  - Uses `SUPABASE_DEV_PROJECT_REF` and `SUPABASE_DEV_URL`

- **Cleanup FCM Tokens (Development)**
  - Daily at 03:00 UTC (offset from production)
  - Same 90-day retention policy
  - Uses `CRON_SECRET_DEV` for authentication

---

## 🔍 Verification

### Test Backend Deployment
After setting up secrets, test the backend deployment:

1. Go to **Actions** tab in your GitHub repository
2. Click **Backend Production Deployment**
3. Click **Run workflow** → **Run workflow**
4. Monitor the deployment progress
5. Check that Edge Functions are deployed successfully

### Test Push Notifications
1. Go to **Actions** tab
2. Click **Send Push Notifications (Development)**
3. Click **Run workflow** → Select notification type → **Run workflow**
4. Check Supabase logs for notification delivery

### Test Frontend Deployment

#### Production Deployment
1. Go to **Actions** tab in your GitHub repository
2. Click **Deploy Frontend to Production**
3. Click **Run workflow** → **Run workflow**
4. Check that https://www.disciplefy.in loads correctly

#### Development Deployment
1. Go to **Actions** tab in your GitHub repository
2. Click **Frontend Development Deployment**
3. Click **Run workflow** → Select environment (`development` or `staging`) → **Run workflow**
4. Check the deployment URL provided in the workflow output

---

## 🛡️ Security Best Practices

### ✅ Do's
- ✅ **Rotate secrets regularly** (every 3-6 months)
- ✅ **Use least privilege** (minimal required permissions)
- ✅ **Monitor access logs** (check Supabase, Firebase, and Vercel logs)
- ✅ **Test in development first** (always verify changes in dev before production)
- ✅ **Document secret rotation** (when and why you changed them)
- ✅ **Use separate Firebase projects** (production vs development)
- ✅ **Keep CRON_SECRET separate** (never expose service role key in cron jobs)

### ❌ Don'ts
- ❌ **Never commit secrets** to code
- ❌ **Don't share secrets** via insecure channels
- ❌ **Don't use personal accounts** for production services
- ❌ **Don't skip environment separation** (prod vs dev)
- ❌ **Don't expose service role key** in cron job headers

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
- ✅ Ensure Firebase credentials are correctly formatted

#### "FCM notification failed"
- ✅ Verify `FIREBASE_PROJECT_ID`, `FIREBASE_PRIVATE_KEY`, and `FIREBASE_CLIENT_EMAIL` are set
- ✅ Check that Firebase Cloud Messaging API is enabled
- ✅ Ensure `FIREBASE_PRIVATE_KEY` includes all `\n` characters

#### "Cron job unauthorized"
- ✅ Verify `CRON_SECRET` or `CRON_SECRET_DEV` is correctly set
- ✅ Check that Edge Functions are using the correct secret header

#### "Vercel deployment failed"
- ✅ Verify `VERCEL_TOKEN` has deployment permissions
- ✅ Check `VERCEL_PROJECT_ID` is correct
- ✅ Ensure Flutter build completed successfully

### Getting Help

1. **Check GitHub Actions logs** for detailed error messages
2. **Review Supabase logs** in dashboard
3. **Check Firebase console** for FCM-related issues
4. **Check Vercel deployment logs** in dashboard
5. **Verify all secrets are set** in repository settings

---

## 📞 Support Checklist

Before asking for help, ensure:

- [ ] All required secrets are set in GitHub
- [ ] Supabase project exists and is accessible
- [ ] Firebase project is created and FCM is enabled
- [ ] Vercel project is properly configured
- [ ] OAuth providers are set up correctly
- [ ] Razorpay webhooks are configured
- [ ] GitHub Actions have proper permissions
- [ ] Latest workflow files are in repository
- [ ] CRON_SECRET is properly configured for scheduled jobs

---

## 📊 Complete Secrets Checklist

### Production (Required)
- [ ] `SUPABASE_PROJECT_REF`
- [ ] `SUPABASE_PROJECT_ID`
- [ ] `SUPABASE_ACCESS_TOKEN`
- [ ] `SUPABASE_URL`
- [ ] `SUPABASE_ANON_KEY`
- [ ] `SUPABASE_SERVICE_ROLE_KEY`
- [ ] `SUPABASE_DB_PASSWORD`
- [ ] `FIREBASE_PROJECT_ID`
- [ ] `FIREBASE_PRIVATE_KEY`
- [ ] `FIREBASE_CLIENT_EMAIL`
- [ ] `OPENAI_API_KEY`
- [ ] `BIBLE_API`
- [ ] `GOOGLE_OAUTH_CLIENT_ID`
- [ ] `GOOGLE_OAUTH_CLIENT_SECRET`
- [ ] `JWT_SECRET`
- [ ] `CRON_SECRET`
- [ ] `RAZORPAY_KEY_ID`
- [ ] `RAZORPAY_KEY_SECRET`
- [ ] `RAZORPAY_WEBHOOK_SECRET`
- [ ] `VERCEL_TOKEN`
- [ ] `VERCEL_ORG_ID`
- [ ] `VERCEL_PROJECT_ID`

### Development (Required)
- [ ] `SUPABASE_DEV_PROJECT_REF`
- [ ] `SUPABASE_DEV_PROJECT_ID`
- [ ] `SUPABASE_DEV_URL`
- [ ] `SUPABASE_DEV_ANON_KEY`
- [ ] `SUPABASE_DEV_SERVICE_ROLE_KEY`
- [ ] `SUPABASE_DEV_DB_PASSWORD`
- [ ] `FIREBASE_PROJECT_ID_DEV`
- [ ] `FIREBASE_PRIVATE_KEY_DEV`
- [ ] `FIREBASE_CLIENT_EMAIL_DEV`
- [ ] `CRON_SECRET_DEV`
- [ ] `RAZORPAY_KEY_ID_DEV`
- [ ] `RAZORPAY_KEY_SECRET_DEV`
- [ ] `RAZORPAY_WEBHOOK_SECRET_DEV`
- [ ] `VERCEL_DEV_TOKEN`
- [ ] `VERCEL_DEV_ORG_ID`
- [ ] `VERCEL_DEV_PROJECT_ID`

### Optional (Production)
- [ ] `ANTHROPIC_API_KEY`
- [ ] `LLM_PROVIDER`
- [ ] `TWILIO_ACCOUNT_SID`
- [ ] `TWILIO_AUTH_TOKEN`
- [ ] `TWILIO_MESSAGE_SERVICE_SID`

### Optional (Development)
- [ ] `OPENAI_API_KEY_DEV`
- [ ] `ANTHROPIC_API_KEY_DEV`
- [ ] `LLM_PROVIDER_DEV`
- [ ] `GOOGLE_OAUTH_CLIENT_ID_DEV`
- [ ] `GOOGLE_OAUTH_CLIENT_SECRET_DEV`
- [ ] `JWT_SECRET_DEV`
- [ ] `TWILIO_ACCOUNT_SID_DEV`
- [ ] `TWILIO_AUTH_TOKEN_DEV`
- [ ] `TWILIO_MESSAGE_SERVICE_SID_DEV`
- [ ] `SUPABASE_STAGING_PROJECT_REF`

---

**Last Updated**: January 2025
**Version**: 2.0.0
**Maintained by**: Disciplefy Development Team
