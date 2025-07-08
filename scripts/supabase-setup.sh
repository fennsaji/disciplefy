#!/bin/bash

# 🚀 Supabase Development Environment Setup Script
# Disciplefy: Bible Study App
# 
# This script sets up a complete Supabase development environment
# with database schema, Edge Functions, and security policies.

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="disciplefy-bible-study"
DEFAULT_REGION="us-east-1"

# Utility functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_header() {
    echo -e "${BLUE}📋 $1${NC}"
    echo "----------------------------------------"
}

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"
    
    # Check if Supabase CLI is installed
    if ! command -v supabase &> /dev/null; then
        log_error "Supabase CLI is not installed"
        log_info "Install it with: npm install -g @supabase/cli"
        exit 1
    fi
    
    # Check if Docker is running (required for local development)
    if ! docker info &> /dev/null; then
        log_error "Docker is not running"
        log_info "Please start Docker Desktop or Docker daemon"
        exit 1
    fi
    
    # Check if Flutter is installed (optional, for mobile development)
    if command -v flutter &> /dev/null; then
        FLUTTER_VERSION=$(flutter --version | head -n1 | cut -d' ' -f2)
        log_success "Flutter $FLUTTER_VERSION detected"
    else
        log_warning "Flutter not detected - install it for mobile development"
    fi
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed"
        log_info "Install it from: https://nodejs.org/"
        exit 1
    fi
    
    NODE_VERSION=$(node --version)
    log_success "Node.js $NODE_VERSION detected"
    
    log_success "All prerequisites satisfied"
}

# Initialize Supabase project
init_supabase_project() {
    log_header "Initializing Supabase Project"
    
    # Check if already initialized
    if [ -f "supabase/config.toml" ]; then
        log_warning "Supabase project already initialized"
        read -p "Do you want to reinitialize? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping initialization"
            return 0
        fi
        rm -rf supabase/
    fi
    
    # Initialize new Supabase project
    log_info "Initializing new Supabase project..."
    supabase init
    
    # Move to backend directory structure
    if [ ! -d "backend" ]; then
        mkdir -p backend
        mv supabase backend/
        log_info "Moved Supabase configuration to backend/supabase/"
    fi
    
    log_success "Supabase project initialized"
}

# Start local Supabase services
start_local_services() {
    log_header "Starting Local Supabase Services"
    
    cd backend/supabase
    
    log_info "Starting Supabase local development stack..."
    log_info "This will start PostgreSQL, PostgREST, GoTrue, Realtime, and Storage"
    
    supabase start
    
    # Display connection details
    echo
    log_success "🎉 Supabase is running locally!"
    echo
    echo "📋 Connection Details:"
    echo "----------------------------------------"
    supabase status
    
    cd ../..
    log_success "Local services started successfully"
}

# Create database schema
create_database_schema() {
    log_header "Creating Database Schema"
    
    cd backend/supabase
    
    # Create initial migration file if it doesn't exist
    if [ ! -f "migrations/20241201000001_initial_schema.sql" ]; then
        log_info "Creating initial database migration..."
        
        cat > migrations/20241201000001_initial_schema.sql << 'EOF'
-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- User profiles extension table
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

-- Study guides table
CREATE TABLE IF NOT EXISTS public.study_guides (
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

-- User feedback table
CREATE TABLE IF NOT EXISTS public.user_feedback (
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

-- API usage logging
CREATE TABLE IF NOT EXISTS public.api_usage_log (
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

-- LLM monitoring table
CREATE TABLE IF NOT EXISTS public.llm_monitoring (
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

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_user_profiles_tier ON user_profiles(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_jeff_reed_sessions_user_status ON jeff_reed_sessions(user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_study_guides_user_created ON study_guides(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_study_guides_favorited ON study_guides(user_id, is_favorited) WHERE is_favorited = true;
CREATE INDEX IF NOT EXISTS idx_study_guides_tags ON study_guides USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_api_usage_log_created ON api_usage_log(created_at);
CREATE INDEX IF NOT EXISTS idx_api_usage_log_endpoint ON api_usage_log(endpoint, created_at);
CREATE INDEX IF NOT EXISTS idx_llm_monitoring_created ON llm_monitoring(created_at);
CREATE INDEX IF NOT EXISTS idx_llm_monitoring_model ON llm_monitoring(model_used, created_at);

-- Full-text search index
CREATE INDEX IF NOT EXISTS idx_study_guides_search ON study_guides USING GIN(
  to_tsvector('english', title || ' ' || scripture_reference || ' ' || summary)
);

-- Updated at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at triggers
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_jeff_reed_sessions_updated_at BEFORE UPDATE ON jeff_reed_sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_study_guides_updated_at BEFORE UPDATE ON study_guides
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EOF
        
        log_success "Initial migration file created"
    fi
    
    # Apply migrations
    log_info "Applying database migrations..."
    supabase db reset
    
    cd ../..
    log_success "Database schema created and applied"
}

# Set up Row Level Security policies
setup_rls_policies() {
    log_header "Setting Up Row Level Security"
    
    cd backend/supabase
    
    # Create RLS migration if it doesn't exist
    if [ ! -f "migrations/20241201000002_rls_policies.sql" ]; then
        log_info "Creating RLS policies migration..."
        
        cat > migrations/20241201000002_rls_policies.sql << 'EOF'
-- Enable Row Level Security on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE jeff_reed_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_guides ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_feedback ENABLE ROW LEVEL SECURITY;

-- User profiles policies
CREATE POLICY "Users can view and edit their own profile"
  ON user_profiles FOR ALL
  USING (auth.uid() = id);

-- Jeff Reed sessions policies
CREATE POLICY "Users can manage their own sessions"
  ON jeff_reed_sessions FOR ALL
  USING (auth.uid() = user_id);

-- Study guides policies
CREATE POLICY "Users can manage their own study guides"
  ON study_guides FOR ALL
  USING (auth.uid() = user_id);

-- User feedback policies
CREATE POLICY "Users can create feedback"
  ON user_feedback FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own feedback"
  ON user_feedback FOR SELECT
  USING (auth.uid() = user_id);

-- Admin access for monitoring tables (service role only)
CREATE POLICY "Service role can access api usage logs"
  ON api_usage_log FOR ALL
  USING (auth.role() = 'service_role');

CREATE POLICY "Service role can access llm monitoring"
  ON llm_monitoring FOR ALL
  USING (auth.role() = 'service_role');

-- Enable realtime for specific tables
ALTER PUBLICATION supabase_realtime ADD TABLE study_guides;
ALTER PUBLICATION supabase_realtime ADD TABLE jeff_reed_sessions;
EOF
        
        log_success "RLS policies migration file created"
    fi
    
    # Apply RLS migration
    log_info "Applying RLS policies..."
    supabase db push
    
    cd ../..
    log_success "Row Level Security policies configured"
}

# Create Edge Functions
create_edge_functions() {
    log_header "Creating Edge Functions"
    
    cd backend/supabase
    
    # Create functions directory structure
    mkdir -p functions/_shared
    
    # Create shared CORS utility
    if [ ! -f "functions/_shared/cors.ts" ]; then
        log_info "Creating CORS utility..."
        
        cat > functions/_shared/cors.ts << 'EOF'
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
};

export function handleCors(req: Request) {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  
  return null;
}
EOF
        
        log_success "CORS utility created"
    fi
    
    # Create shared error handler
    if [ ! -f "functions/_shared/error-handler.ts" ]; then
        log_info "Creating error handler utility..."
        
        cat > functions/_shared/error-handler.ts << 'EOF'
import { corsHeaders } from './cors.ts';

export interface ErrorResponse {
  success: false;
  error: string;
  code?: string;
  details?: any;
}

export function createErrorResponse(
  error: string,
  status: number = 400,
  code?: string,
  details?: any
): Response {
  const errorResponse: ErrorResponse = {
    success: false,
    error,
    code,
    details,
  };
  
  return new Response(JSON.stringify(errorResponse), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export function handleError(error: any): Response {
  console.error('Function error:', error);
  
  if (error.message?.includes('Authentication required')) {
    return createErrorResponse('Authentication required', 401, 'AUTH_REQUIRED');
  }
  
  if (error.message?.includes('Rate limit exceeded')) {
    return createErrorResponse('Rate limit exceeded', 429, 'RATE_LIMIT_EXCEEDED');
  }
  
  return createErrorResponse(
    'Internal server error',
    500,
    'INTERNAL_ERROR',
    process.env.NODE_ENV === 'development' ? error.message : undefined
  );
}
EOF
        
        log_success "Error handler utility created"
    fi
    
    # Create study generation function
    if [ ! -f "functions/study-generate/index.ts" ]; then
        log_info "Creating study generation function..."
        
        mkdir -p functions/study-generate
        
        cat > functions/study-generate/index.ts << 'EOF'
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { createErrorResponse, handleError } from '../_shared/error-handler.ts';

interface StudyGenerationRequest {
  input_type: 'scripture' | 'topic' | 'question';
  input_value: string;
  jeff_reed_step: 'observation' | 'interpretation' | 'correlation' | 'application';
  session_id?: string;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // Validate request method
    if (req.method !== 'POST') {
      return createErrorResponse('Method not allowed', 405);
    }

    // Get authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return createErrorResponse('Authentication required', 401, 'AUTH_REQUIRED');
    }

    // Initialize Supabase client
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Verify user authentication
    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );

    if (authError || !user) {
      return createErrorResponse('Invalid authentication', 401, 'INVALID_AUTH');
    }

    // Parse request body
    const requestData: StudyGenerationRequest = await req.json();

    // Validate input
    if (!requestData.input_value || !requestData.jeff_reed_step) {
      return createErrorResponse('Missing required fields', 400, 'VALIDATION_ERROR');
    }

    // For development, return mock data
    const mockStudyContent = generateMockStudy(requestData);

    // Store the generated study
    const { data: studyGuide, error: insertError } = await supabase
      .from('study_guides')
      .insert({
        user_id: user.id,
        session_id: requestData.session_id,
        title: mockStudyContent.title,
        scripture_reference: requestData.input_value,
        jeff_reed_step: requestData.jeff_reed_step,
        summary: mockStudyContent.summary,
        detailed_content: mockStudyContent.content,
        llm_model_used: 'mock-development',
        generation_time_ms: 1500,
      })
      .select()
      .single();

    if (insertError) {
      throw insertError;
    }

    return new Response(JSON.stringify({
      success: true,
      study_guide: studyGuide,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    return handleError(error);
  }
});

function generateMockStudy(request: StudyGenerationRequest) {
  const stepDescriptions = {
    observation: 'examining what the text actually says',
    interpretation: 'understanding what the text means',
    correlation: 'connecting the text with other Biblical passages',
    application: 'applying the truth to our daily lives',
  };

  return {
    title: `${request.jeff_reed_step.charAt(0).toUpperCase() + request.jeff_reed_step.slice(1)} Study: ${request.input_value}`,
    summary: `This study focuses on ${stepDescriptions[request.jeff_reed_step]} in ${request.input_value}.`,
    content: {
      main_points: [
        `Key point 1 about ${request.input_value}`,
        `Key point 2 about ${request.input_value}`,
        `Key point 3 about ${request.input_value}`,
      ],
      key_insights: [
        `Important insight for ${request.jeff_reed_step} step`,
        `Additional understanding from this passage`,
      ],
      reflection_questions: [
        'What stands out to you most in this passage?',
        'How does this truth apply to your current situation?',
      ],
      practical_application: `Practical ways to apply the truth from ${request.input_value} in your daily life.`,
    },
  };
}
EOF
        
        log_success "Study generation function created"
    fi
    
    # Create health check function
    if [ ! -f "functions/health-check/index.ts" ]; then
        log_info "Creating health check function..."
        
        mkdir -p functions/health-check
        
        cat > functions/health-check/index.ts << 'EOF'
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  version: string;
  timestamp: string;
  services: {
    database: 'up' | 'down';
    functions: 'up' | 'down';
  };
}

serve(async (req: Request) => {
  const startTime = Date.now();
  
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Test database connectivity
    let dbStatus: 'up' | 'down' = 'up';
    try {
      await supabase.from('user_profiles').select('count').limit(1);
    } catch {
      dbStatus = 'down';
    }

    const responseTime = Date.now() - startTime;
    const overallStatus = dbStatus === 'up' ? 'healthy' : 'unhealthy';

    const healthStatus: HealthStatus = {
      status: overallStatus,
      version: Deno.env.get('APP_VERSION') ?? 'development',
      timestamp: new Date().toISOString(),
      services: {
        database: dbStatus,
        functions: 'up',
      },
    };

    const statusCode = overallStatus === 'healthy' ? 200 : 503;
    
    return new Response(JSON.stringify(healthStatus, null, 2), {
      status: statusCode,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
    
  } catch (error) {
    return new Response(JSON.stringify({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString(),
    }), {
      status: 503,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
EOF
        
        log_success "Health check function created"
    fi
    
    cd ../..
    log_success "Edge Functions created"
}

# Deploy Edge Functions locally
deploy_edge_functions() {
    log_header "Deploying Edge Functions"
    
    cd backend/supabase
    
    log_info "Deploying Edge Functions to local environment..."
    supabase functions deploy
    
    cd ../..
    log_success "Edge Functions deployed successfully"
}

# Create sample data
create_sample_data() {
    log_header "Creating Sample Data"
    
    cd backend/supabase
    
    # Create sample data script
    if [ ! -f "seed.sql" ]; then
        log_info "Creating sample data script..."
        
        cat > seed.sql << 'EOF'
-- Insert sample user profile
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'f47ac10b-58cc-4372-a567-0e02b2c3d479',
  'authenticated',
  'authenticated',
  'demo@disciplefy.app',
  crypt('password123', gen_salt('bf')),
  NOW(),
  NOW(),
  NOW(),
  '{"provider": "email", "providers": ["email"]}',
  '{}',
  FALSE,
  '',
  '',
  '',
  ''
) ON CONFLICT (id) DO NOTHING;

-- Insert user profile
INSERT INTO user_profiles (id, display_name, preferences) 
VALUES (
  'f47ac10b-58cc-4372-a567-0e02b2c3d479',
  'Demo User',
  '{"theme": "light", "notifications": true}'
) ON CONFLICT (id) DO NOTHING;

-- Insert sample Jeff Reed session
INSERT INTO jeff_reed_sessions (
  id,
  user_id,
  scripture_reference,
  current_step,
  status,
  session_data
) VALUES (
  'a47ac10b-58cc-4372-a567-0e02b2c3d471',
  'f47ac10b-58cc-4372-a567-0e02b2c3d479',
  'John 3:16',
  'observation',
  'in_progress',
  '{"notes": "God loved the world so much..."}'
) ON CONFLICT (id) DO NOTHING;

-- Insert sample study guide
INSERT INTO study_guides (
  user_id,
  session_id,
  title,
  scripture_reference,
  jeff_reed_step,
  summary,
  detailed_content,
  llm_model_used,
  generation_time_ms,
  tags
) VALUES (
  'f47ac10b-58cc-4372-a567-0e02b2c3d479',
  'a47ac10b-58cc-4372-a567-0e02b2c3d471',
  'Observation Study: John 3:16',
  'John 3:16',
  'observation',
  'An observation study focusing on the key elements of God''s love and salvation.',
  '{
    "main_points": [
      "God loved the world",
      "He gave His only Son",
      "Whoever believes will not perish",
      "But have eternal life"
    ],
    "key_insights": [
      "Universal scope of God''s love",
      "Sacrificial nature of divine love",
      "Simple requirement: belief",
      "Eternal consequences"
    ],
    "reflection_questions": [
      "What does it mean that God loved the world?",
      "How does believing translate to eternal life?"
    ],
    "practical_application": "Consider the depth of God''s love in your daily decisions and relationships."
  }',
  'mock-development',
  1234,
  ARRAY['salvation', 'love', 'eternal life']
) ON CONFLICT DO NOTHING;
EOF
        
        log_success "Sample data script created"
    fi
    
    # Apply sample data
    log_info "Inserting sample data..."
    psql postgresql://postgres:postgres@localhost:54322/postgres -f seed.sql
    
    cd ../..
    log_success "Sample data created"
}

# Set up environment configuration
setup_environment() {
    log_header "Setting Up Environment Configuration"
    
    # Create .env file for local development
    if [ ! -f ".env.local" ]; then
        log_info "Creating local environment configuration..."
        
        # Get Supabase connection details
        cd backend/supabase
        SUPABASE_STATUS=$(supabase status --output json)
        SUPABASE_URL=$(echo $SUPABASE_STATUS | jq -r '.API_URL')
        SUPABASE_ANON_KEY=$(echo $SUPABASE_STATUS | jq -r '.ANON_KEY')
        SUPABASE_SERVICE_KEY=$(echo $SUPABASE_STATUS | jq -r '.SERVICE_ROLE_KEY')
        cd ../..
        
        cat > .env.local << EOF
# Disciplefy Development Environment Configuration
# Generated on $(date)

# Environment
ENVIRONMENT=development
DEBUG_MODE=true
LOG_LEVEL=debug

# Supabase Configuration
SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_KEY

# LLM API Keys (Add your actual keys here)
OPENAI_API_KEY=your_openai_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# App Configuration
APP_NAME=Disciplefy
APP_VERSION=1.0.0-dev
CACHE_TTL=300

# Rate Limiting
RATE_LIMIT_REQUESTS_PER_HOUR=100
RATE_LIMIT_ANONYMOUS_PER_HOUR=10

# Feature Flags
ENABLE_ANALYTICS=false
ENABLE_ERROR_REPORTING=false
ENABLE_PERFORMANCE_MONITORING=false
EOF
        
        log_success "Local environment configuration created (.env.local)"
        log_warning "Remember to add your actual API keys to .env.local"
    else
        log_info "Environment configuration already exists"
    fi
    
    # Create gitignore entry
    if [ ! -f ".gitignore" ]; then
        cat > .gitignore << 'EOF'
# Environment files
.env
.env.local
.env.staging
.env.production
*.env

# Supabase
.branches
.temp

# Dependencies
node_modules/
.pnp
.pnp.js

# Testing
coverage/

# Production builds
build/
dist/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Flutter
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/
EOF
        log_success "Created .gitignore file"
    fi
}

# Test the setup
test_setup() {
    log_header "Testing Setup"
    
    cd backend/supabase
    
    # Test database connection
    log_info "Testing database connection..."
    if psql postgresql://postgres:postgres@localhost:54322/postgres -c "SELECT 1;" > /dev/null 2>&1; then
        log_success "Database connection successful"
    else
        log_error "Database connection failed"
        return 1
    fi
    
    # Test Edge Functions
    log_info "Testing Edge Functions..."
    
    # Test health check endpoint
    HEALTH_RESPONSE=$(curl -s "http://localhost:54321/functions/v1/health-check" || echo "ERROR")
    if [[ $HEALTH_RESPONSE == *"healthy"* ]]; then
        log_success "Health check endpoint working"
    else
        log_warning "Health check endpoint may not be responding correctly"
    fi
    
    # Test study generation endpoint (should require auth)
    STUDY_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:54321/functions/v1/study-generate")
    if [ "$STUDY_RESPONSE" = "401" ]; then
        log_success "Study generation endpoint responding (authentication required)"
    else
        log_warning "Study generation endpoint response: $STUDY_RESPONSE"
    fi
    
    cd ../..
    log_success "Setup testing completed"
}

# Display success information
show_success_info() {
    log_header "🎉 Setup Complete!"
    
    echo "Your Disciplefy development environment is ready!"
    echo
    echo "📋 What's been set up:"
    echo "  ✅ Supabase local development stack"
    echo "  ✅ Database schema with sample data"
    echo "  ✅ Row Level Security policies"
    echo "  ✅ Edge Functions (study-generate, health-check)"
    echo "  ✅ Environment configuration"
    echo
    echo "🔗 Connection Details:"
    echo "  📊 Supabase Studio: http://localhost:54323"
    echo "  🗄️  Database: postgresql://postgres:postgres@localhost:54322/postgres"
    echo "  🌐 API: http://localhost:54321"
    echo "  ⚡ Functions: http://localhost:54321/functions/v1/"
    echo
    echo "📁 Important Files:"
    echo "  🔧 Configuration: backend/supabase/config.toml"
    echo "  🗃️  Migrations: backend/supabase/migrations/"
    echo "  ⚡ Functions: backend/supabase/functions/"
    echo "  🌍 Environment: .env.local"
    echo
    echo "🚀 Next Steps:"
    echo "  1. Add your LLM API keys to .env.local"
    echo "  2. Open Supabase Studio at http://localhost:54323"
    echo "  3. Start developing your Flutter app!"
    echo "  4. Test the API endpoints with the sample user:"
    echo "     Email: demo@disciplefy.app"
    echo "     Password: password123"
    echo
    echo "📚 Useful Commands:"
    echo "  supabase status      # Check service status"
    echo "  supabase stop        # Stop all services"
    echo "  supabase start       # Start all services"
    echo "  supabase db reset    # Reset database"
    echo
    log_warning "Remember to keep Docker running for the local environment"
}

# Main execution
main() {
    log_header "🚀 Disciplefy: Bible Study App - Development Setup"
    echo "This script will set up your complete Supabase development environment"
    echo
    
    # Run setup steps
    check_prerequisites
    init_supabase_project
    start_local_services
    create_database_schema
    setup_rls_policies
    create_edge_functions
    deploy_edge_functions
    create_sample_data
    setup_environment
    test_setup
    show_success_info
    
    echo
    log_success "🎉 Development environment setup completed successfully!"
}

# Handle script interruption
trap 'echo -e "\n${YELLOW}⚠️  Setup interrupted. You may need to run: supabase stop${NC}"; exit 1' INT

# Run main function
main "$@"