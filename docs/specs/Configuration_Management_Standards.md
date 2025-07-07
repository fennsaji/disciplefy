# ⚙️ Configuration Management Standards
**Disciplefy: Bible Study App**

*Standardized configuration values and management procedures*

---

## 📋 **Overview**

### **Purpose**
This document establishes standardized configuration values across all project documentation and code to eliminate inconsistencies and ensure reliable system behavior.

### **Scope**
- API rate limiting configurations
- Storage allocation limits
- Performance thresholds
- Security parameters
- Error code standards
- Environment-specific settings

---

## 🔧 **Standardized Configuration Values**

### **Rate Limiting Standards**

**API Rate Limits (Per Hour):**
```yaml
rate_limits:
  anonymous_users:
    api_requests: 10
    study_generation: 3
    window: 3600  # seconds
    
  authenticated_users:
    api_requests: 100
    study_generation: 30
    window: 3600  # seconds
    
  admin_users:
    api_requests: 5000
    study_generation: 1000
    window: 3600  # seconds
```

**LLM-Specific Rate Limits:**
```yaml
llm_rate_limits:
  anonymous:
    requests_per_hour: 3
    requests_per_day: 10
    
  authenticated:
    requests_per_hour: 30
    requests_per_day: 100
    
  admin:
    requests_per_hour: 1000
    requests_per_day: 5000
```

### **Storage Allocation Standards**

**Offline Storage (Mobile App):**
```yaml
storage_limits:
  total_offline_storage: "2GB"
  cache_allocation: "1GB"
  user_data_allocation: "1GB"
  cleanup_threshold: "80%"  # Trigger cleanup at 1.6GB
  
cache_breakdown:
  study_guides: "500MB"     # Recently generated guides
  bible_verses: "300MB"     # Frequently accessed verses
  user_preferences: "100MB" # Settings and customizations
  system_cache: "100MB"     # App assets and metadata
```

**Database Storage (Supabase):**
```yaml
database_limits:
  free_tier: "500MB"
  pro_tier: "8GB" 
  team_tier: "100GB"
  cost_per_gb_overage: "$0.125"
  
retention_policies:
  study_guides: "user_lifetime"  # Until user deletion
  audit_logs: "7_years"         # Legal compliance
  analytics: "1_year"           # Business intelligence
  error_logs: "90_days"         # Debugging purposes
  feedback: "2_years"           # Product improvement
```

### **Performance Thresholds**

**API Response Time Targets:**
```yaml
response_time_targets:
  api_endpoints:
    target_p95: "2000ms"      # 95th percentile
    target_p99: "5000ms"      # 99th percentile
    timeout: "30000ms"        # Hard timeout
    
  llm_endpoints:
    target_mean: "15000ms"    # 15 seconds average
    target_p95: "30000ms"     # 30 seconds 95th percentile
    timeout: "60000ms"        # 1 minute hard timeout
    
  database_queries:
    target_mean: "500ms"      # 500ms average
    target_p95: "2000ms"      # 2 seconds 95th percentile
    slow_query_threshold: "5000ms"  # Log queries > 5s
```

**Concurrency Limits:**
```yaml
concurrency_limits:
  max_concurrent_users: 1000
  max_concurrent_llm_requests: 50
  database_connection_pool: 200
  api_gateway_connections: 500
```

### **Security Parameters**

**Authentication & Session Management:**
```yaml
auth_config:
  jwt_expiry: "24h"              # 24 hours
  refresh_token_expiry: "30d"    # 30 days
  anonymous_session_expiry: "24h" # 24 hours
  max_login_attempts: 5
  lockout_duration: "15m"        # 15 minutes
  
password_policy:
  min_length: 8
  require_uppercase: true
  require_lowercase: true
  require_numbers: true
  require_special_chars: false    # For user convenience
  max_age_days: 365              # Annual password change recommendation
```

**Input Validation:**
```yaml
input_validation:
  max_input_length:
    scripture_reference: 100     # "Book Chapter:Verse-Verse"
    topic_input: 200            # Topic description
    feedback_text: 1000         # User feedback
    study_title: 100            # Custom study guide title
    
  allowed_patterns:
    scripture: "^[1-3]?\\s*[A-Za-z]+\\s+\\d{1,3}(:\\d{1,3})?(-\\d{1,3})?$"
    topic: "^[A-Za-z0-9\\s\\-',.!?]{2,200}$"
    
  blocked_patterns:
    - "system\\s*:|admin\\s*:|ignore\\s+instructions"
    - "javascript:|<script|eval\\("
    - "forget\\s+everything|new\\s+instructions"
```

---

## 📊 **Error Code Standards**

### **Error Code Format**
All error codes follow the pattern: `{CATEGORY}-E-{NUMBER}`

**Categories:**
- `UI` - User Interface errors
- `AU` - Authentication errors  
- `RL` - Rate Limiting errors
- `LM` - LLM/AI processing errors
- `DB` - Database errors
- `PM` - Payment processing errors
- `SC` - Security/Compliance errors
- `SY` - System/Infrastructure errors

### **Standard Error Codes**

**Authentication Errors (AU-E-xxx):**
```yaml
auth_errors:
  AU-E-001:
    code: "AU-E-001"
    message: "Authentication required"
    description: "User must be logged in to access this resource"
    
  AU-E-002:
    code: "AU-E-002" 
    message: "Invalid or expired token"
    description: "JWT token is malformed or expired"
    
  AU-E-003:
    code: "AU-E-003"
    message: "Account suspended"
    description: "User account has been temporarily suspended"
    
  AU-E-004:
    code: "AU-E-004"
    message: "Insufficient permissions"
    description: "User lacks required permissions for this action"
    
  AU-E-005:
    code: "AU-E-005"
    message: "Admin access required"
    description: "This feature requires administrator privileges"
```

**Rate Limiting Errors (RL-E-xxx):**
```yaml
rate_limit_errors:
  RL-E-001:
    code: "RL-E-001"
    message: "Rate limit exceeded"
    description: "Too many requests in the specified time window"
    retry_after: 3600  # seconds
    
  RL-E-002:
    code: "RL-E-002"
    message: "Daily limit reached"
    description: "Daily request quota has been exceeded"
    
  RL-E-003:
    code: "RL-E-003"
    message: "Concurrent request limit exceeded"
    description: "Too many simultaneous requests"
```

**LLM Processing Errors (LM-E-xxx):**
```yaml
llm_errors:
  LM-E-001:
    code: "LM-E-001"
    message: "LLM service timeout"
    description: "AI service took too long to respond"
    
  LM-E-002:
    code: "LM-E-002"
    message: "LLM rate limit exceeded"
    description: "AI service rate limit reached"
    
  LM-E-003:
    code: "LM-E-003"
    message: "Invalid LLM response"
    description: "AI service returned malformed response"
    
  LM-E-004:
    code: "LM-E-004"
    message: "Content policy violation"
    description: "Generated content violates content policies"
    
  LM-E-005:
    code: "LM-E-005"
    message: "Prompt injection detected"
    description: "Input contains potential prompt injection attempt"
```

---

## 🌍 **Environment-Specific Configurations**

### **Development Environment**
```yaml
development:
  api_base_url: "http://localhost:54321"
  supabase_url: "http://localhost:54321"
  log_level: "DEBUG"
  
  rate_limits:
    # Relaxed for development
    api_requests: 1000
    llm_requests: 100
    
  storage:
    cache_size: "100MB"  # Smaller for dev
    
  security:
    jwt_expiry: "7d"     # Longer for dev convenience
    cors_origins: ["http://localhost:3000", "http://localhost:8080"]
```

### **Staging Environment**
```yaml
staging:
  api_base_url: "https://staging-api.disciplefy.app"
  supabase_url: "https://staging-project.supabase.co"
  log_level: "INFO"
  
  rate_limits:
    # Production-like but slightly relaxed
    api_requests: 150
    llm_requests: 45
    
  storage:
    cache_size: "1GB"
    
  security:
    jwt_expiry: "24h"
    cors_origins: ["https://staging.disciplefy.app"]
```

### **Production Environment**
```yaml
production:
  api_base_url: "https://api.disciplefy.app"
  supabase_url: "https://prod-project.supabase.co"
  log_level: "WARN"
  
  rate_limits:
    # Standard production limits
    api_requests: 100
    llm_requests: 30
    
  storage:
    cache_size: "2GB"
    
  security:
    jwt_expiry: "24h"
    cors_origins: ["https://disciplefy.app", "https://www.disciplefy.app"]
    
  monitoring:
    error_reporting: true
    performance_monitoring: true
    analytics: true
```

---

## 📁 **Configuration File Standards**

### **Environment Variables Naming**
```bash
# Naming Convention: DISCIPLEFY_{CATEGORY}_{SETTING}
DISCIPLEFY_API_BASE_URL="https://api.disciplefy.app"
DISCIPLEFY_SUPABASE_URL="https://prod-project.supabase.co"
DISCIPLEFY_SUPABASE_ANON_KEY="eyJ..."
DISCIPLEFY_SUPABASE_SERVICE_KEY="eyJ..."

# Third-party services
DISCIPLEFY_OPENAI_API_KEY="sk-..."
DISCIPLEFY_ANTHROPIC_API_KEY="sk-ant-..."

# Feature flags
DISCIPLEFY_FEATURE_LLM_ENABLED="true"
DISCIPLEFY_FEATURE_OFFLINE_MODE="true"
DISCIPLEFY_FEATURE_ANALYTICS="true"

# Performance settings
DISCIPLEFY_RATE_LIMIT_AUTHENTICATED="100"
DISCIPLEFY_RATE_LIMIT_ANONYMOUS="10"
DISCIPLEFY_CACHE_SIZE_MB="1024"
```

### **Configuration File Structure**

**`config/default.yaml`:**
```yaml
app:
  name: "Disciplefy: Bible Study"
  version: "1.0.0"
  environment: "development"

api:
  timeout: 30000
  retry_attempts: 3
  rate_limits: !include rate_limits.yaml

storage:
  limits: !include storage_limits.yaml
  
security:
  parameters: !include security_config.yaml
  
features:
  llm_enabled: true
  offline_mode: true
  analytics: false  # Disabled in development
```

**`config/production.yaml`:**
```yaml
# Override development defaults
app:
  environment: "production"
  
api:
  base_url: "https://api.disciplefy.app"
  
features:
  analytics: true   # Enabled in production
  
logging:
  level: "WARN"
  structured: true
```

### **Secrets Management**

**Development Secrets (`.env.local`):**
```bash
# ⚠️ Never commit to version control
SUPABASE_SERVICE_ROLE_KEY="eyJ..."
OPENAI_API_KEY="sk-..."
ANTHROPIC_API_KEY="sk-ant-..."

# Development-specific
DEBUG_MODE="true"
MOCK_LLM_RESPONSES="false"
```

**Production Secrets Management:**
```yaml
# Using environment-specific secret management
production_secrets:
  storage: "Azure Key Vault / AWS Secrets Manager"
  access_control: "Role-based with audit logging"
  rotation_policy: "90 days for API keys"
  
secrets_mapping:
  SUPABASE_SERVICE_KEY: 
    source: "azure_key_vault"
    key: "disciplefy-prod-supabase-service-key"
    
  OPENAI_API_KEY:
    source: "azure_key_vault" 
    key: "disciplefy-prod-openai-api-key"
```

---

## 🔄 **Configuration Management Process**

### **Change Management Workflow**

**1. Configuration Change Request:**
```markdown
## Configuration Change Request

**Type:** [Rate Limit / Storage / Security / Performance]
**Environment:** [Development / Staging / Production / All]
**Urgency:** [Low / Medium / High / Emergency]

**Current Value:**
```yaml
rate_limits:
  authenticated_users: 100
```

**Proposed Value:**
```yaml
rate_limits:
  authenticated_users: 150
```

**Justification:**
Current rate limits are causing legitimate users to be blocked during peak usage hours. Analytics show 95th percentile users make 120 requests/hour.

**Impact Assessment:**
- Increased server load: ~15% 
- Improved user experience
- No security implications
- Cost impact: Minimal

**Testing Plan:**
- Deploy to staging environment
- Load test with new limits
- Monitor for 48 hours
- Measure user satisfaction improvement

**Rollback Plan:**
Revert to previous value if server resources exceed 80% utilization.
```

**2. Review and Approval Process:**
- **Technical Review:** Infrastructure team validates impact
- **Security Review:** Security team approves security-related changes  
- **Business Review:** Product team approves user-facing changes
- **Final Approval:** Technical lead or CTO for production changes

**3. Implementation Steps:**
1. Update configuration files in version control
2. Update documentation to reflect changes
3. Deploy to staging environment first
4. Validate changes work as expected
5. Deploy to production during maintenance window
6. Monitor system metrics for 24 hours
7. Update monitoring alerts if needed

### **Configuration Validation**

**Automated Validation:**
```yaml
# Configuration validation rules
validation_rules:
  rate_limits:
    authenticated_users:
      min: 50        # Minimum viable rate limit
      max: 1000      # Maximum reasonable rate limit
      type: integer
      
  storage_limits:
    cache_size:
      pattern: "^\\d+[KMGT]B$"  # Must include unit
      max_value: "10GB"         # Reasonable maximum
      
  timeouts:
    api_timeout:
      min: 5000      # Minimum 5 seconds
      max: 300000    # Maximum 5 minutes
      type: integer
      unit: "milliseconds"
```

**Pre-deployment Checks:**
```bash
#!/bin/bash
# config-validation.sh

echo "Validating configuration files..."

# Check YAML syntax
for file in config/*.yaml; do
  if ! yaml-lint "$file"; then
    echo "❌ Invalid YAML syntax in $file"
    exit 1
  fi
done

# Validate rate limits are within bounds
api_limit=$(yq '.api.rate_limits.authenticated_users' config/production.yaml)
if [ "$api_limit" -lt 50 ] || [ "$api_limit" -gt 1000 ]; then
  echo "❌ API rate limit out of bounds: $api_limit"
  exit 1
fi

# Check required environment variables
required_vars=("SUPABASE_URL" "SUPABASE_ANON_KEY" "OPENAI_API_KEY")
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "❌ Missing required environment variable: $var"
    exit 1
  fi
done

echo "✅ Configuration validation passed"
```

---

## 📈 **Monitoring & Maintenance**

### **Configuration Drift Detection**

**Automated Monitoring:**
```sql
-- Track configuration changes
CREATE TABLE config_audit_log (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  environment VARCHAR(50) NOT NULL,
  config_key VARCHAR(200) NOT NULL,
  old_value TEXT,
  new_value TEXT NOT NULL,
  changed_by VARCHAR(100) NOT NULL,
  change_reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Monitor for unexpected configuration drift
SELECT 
  environment,
  config_key,
  COUNT(*) as change_count,
  MAX(created_at) as last_change
FROM config_audit_log 
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY environment, config_key
HAVING COUNT(*) > 5  -- Alert if more than 5 changes in a week
ORDER BY change_count DESC;
```

**Regular Configuration Reviews:**
- **Weekly:** Review rate limiting effectiveness
- **Monthly:** Analyze storage utilization and adjust limits
- **Quarterly:** Comprehensive security parameter review
- **Annually:** Full configuration audit and optimization

### **Performance Impact Monitoring**

**Rate Limiting Effectiveness:**
```sql
-- Monitor rate limiting impact
SELECT 
  DATE_TRUNC('hour', created_at) as hour,
  COUNT(*) FILTER (WHERE error_code = 'RL-E-001') as rate_limit_hits,
  COUNT(*) as total_requests,
  ROUND(
    COUNT(*) FILTER (WHERE error_code = 'RL-E-001') * 100.0 / COUNT(*), 
    2
  ) as rate_limit_percentage
FROM api_request_logs 
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', created_at)
ORDER BY hour DESC;
```

**Storage Utilization Tracking:**
```sql
-- Monitor storage usage patterns
SELECT 
  user_type,
  AVG(storage_used_mb) as avg_storage_mb,
  MAX(storage_used_mb) as max_storage_mb,
  COUNT(*) FILTER (WHERE storage_used_mb > 1024) as users_over_1gb,
  COUNT(*) as total_users
FROM user_storage_metrics 
WHERE measured_at > NOW() - INTERVAL '7 days'
GROUP BY user_type;
```

---

## 📋 **Configuration Checklist Templates**

### **New Feature Configuration Checklist**
- [ ] Rate limits defined for new endpoints
- [ ] Storage requirements estimated and allocated
- [ ] Security parameters configured
- [ ] Error codes assigned and documented
- [ ] Environment-specific values set
- [ ] Monitoring and alerting configured
- [ ] Documentation updated
- [ ] Validation rules added

### **Configuration Change Checklist**
- [ ] Change request documented with justification
- [ ] Impact assessment completed
- [ ] Security review conducted (if applicable)
- [ ] Staging environment testing completed
- [ ] Rollback plan prepared
- [ ] Monitoring adjusted for new values
- [ ] Documentation updated
- [ ] Team notified of changes

### **Environment Promotion Checklist**
- [ ] Configuration files validated
- [ ] Environment variables verified
- [ ] Secrets properly configured
- [ ] Rate limits appropriate for environment
- [ ] Storage limits configured
- [ ] Monitoring and alerting active
- [ ] Backup and recovery tested
- [ ] Performance baseline established

---

**⚠️ [REQUIRES HUMAN INPUT: Actual environment URLs, API keys, specific monitoring tool configurations, and team-specific approval workflows need to be configured for implementation]**

**This document should be the single source of truth for all configuration values and must be updated whenever configuration changes are made across the system.**