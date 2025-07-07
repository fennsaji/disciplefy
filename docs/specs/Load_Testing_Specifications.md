# 🚀 Load Testing Specifications
**Disciplefy: Bible Study App**

*Performance testing procedures and benchmarks for production readiness*

---

## 📊 **Testing Overview**

### **Performance Objectives**
- **Concurrent Users:** Support 1,000 simultaneous active users
- **API Response Time:** < 2 seconds for 95% of requests
- **LLM Response Time:** < 30 seconds for study guide generation
- **Database Performance:** < 500ms for read operations, < 1s for writes
- **System Availability:** 99.9% uptime during normal operations

### **Load Testing Categories**
1. **API Endpoint Testing** - REST API performance under load
2. **Database Stress Testing** - Supabase PostgreSQL performance limits
3. **LLM Integration Testing** - AI service response under concurrent requests
4. **Real-time Features Testing** - WebSocket connections and real-time updates
5. **Mobile App Performance** - Flutter app responsiveness under data load

---

## 🎯 **Test Scenarios**

### **Scenario 1: Normal Load Testing**

**Objective:** Validate system performance under expected production load

**Test Parameters:**
- **Concurrent Users:** 100-500 users
- **Test Duration:** 30 minutes
- **Ramp-up Time:** 5 minutes
- **User Actions:** Typical usage patterns

**User Journey Simulation:**
```yaml
# Load Test Configuration
scenarios:
  normal_usage:
    users: 500
    duration: 30m
    ramp_up: 5m
    actions:
      - login: 20%
      - browse_studies: 30%
      - generate_study: 25%
      - save_study: 15%
      - logout: 10%
```

**Performance Thresholds:**
- API Response Time: < 2 seconds (95th percentile)
- Database Query Time: < 500ms (average)
- Memory Usage: < 80% of available
- CPU Usage: < 70% sustained

### **Scenario 2: Peak Load Testing**

**Objective:** Test system behavior at maximum expected capacity

**Test Parameters:**
- **Concurrent Users:** 1,000-2,000 users
- **Test Duration:** 15 minutes
- **Ramp-up Time:** 3 minutes
- **Load Pattern:** Sustained peak usage

**Critical Endpoints:**
```bash
# Authentication endpoints
POST /auth/v1/signup
POST /auth/v1/signin
POST /auth/v1/signout

# Study generation endpoints  
POST /functions/v1/study-generate
GET /rest/v1/study_guides
POST /rest/v1/study_guides

# Real-time endpoints
WebSocket connections to /realtime/v1/
```

**Performance Thresholds:**
- API Response Time: < 5 seconds (95th percentile)
- Error Rate: < 2%
- Database Connections: < 80% of pool limit
- Queue Depth: < 100 pending requests

### **Scenario 3: Stress Testing**

**Objective:** Determine system breaking point and failure modes

**Test Parameters:**
- **Concurrent Users:** 2,000+ users (until failure)
- **Test Duration:** Until system degradation
- **Ramp-up Pattern:** Exponential increase
- **Monitoring:** Resource exhaustion points

**Failure Point Identification:**
- Database connection pool exhaustion
- Memory overflow conditions
- API gateway rate limiting activation
- LLM service timeout thresholds

### **Scenario 4: Spike Testing**

**Objective:** Test system recovery from sudden traffic spikes

**Test Parameters:**
- **Baseline Load:** 100 users
- **Spike Load:** 1,500 users instantly
- **Spike Duration:** 5 minutes
- **Recovery Monitoring:** 15 minutes post-spike

**Recovery Metrics:**
- Time to handle spike without errors
- System recovery time after spike
- Data consistency during high load
- User experience degradation level

---

## 🛠️ **Testing Tools & Setup**

### **Primary Testing Tools**

### **Production Environment Configuration**
```yaml
testing_environments:
  staging:
    supabase_url: "https://[STAGING-PROJECT].supabase.co"
    purpose: "Pre-production testing"
    max_concurrent_users: 500
    
  development:
    supabase_url: "http://localhost:54321"
    purpose: "Local development"
    max_concurrent_users: 50
    
  load_testing:
    tools: ["Artillery", "K6"]
    targets: "staging environment"
    monitoring_tools: "[MONITORING SERVICE]"
```

```yaml
production_config:
  supabase_project:
    url: "https://[PROJECT-ID].supabase.co"
    plan: "Pro/Team"
    backup_frequency: "6 hours"
    
  domain_setup:
    primary: "disciplefy.app"
    api: "api.disciplefy.app"
    admin: "admin.disciplefy.app"
    
  ssl_certificates:
    provider: "Let's Encrypt / CloudFlare"
    auto_renewal: "enabled"
```

⚠️ **[REQUIRES HUMAN INPUT: Update production Supabase project details and testing environment URLs]**

**Artillery.js Configuration:**
```yaml
# artillery-config.yml
config:
  target: 'https://[PROJECT-URL].supabase.co'
  phases:
    - duration: 300  # 5 minutes ramp-up
      arrivalRate: 10
      rampTo: 100
    - duration: 1800 # 30 minutes sustained
      arrivalRate: 100
    - duration: 300  # 5 minutes ramp-down
      arrivalRate: 100
      rampTo: 10
  http:
    timeout: 30
  defaults:
    headers:
      apikey: '{{ $env.SUPABASE_ANON_KEY }}'
      Authorization: 'Bearer {{ $env.SUPABASE_ANON_KEY }}'
      Content-Type: 'application/json'

scenarios:
  - name: "Study Generation Workflow"
    weight: 60
    flow:
      - post:
          url: "/auth/v1/signup"
          json:
            email: "loadtest+{{ $randomString() }}@example.com"
            password: "TestPassword123!"
      - post:
          url: "/functions/v1/study-generate"
          json:
            input_type: "scripture"
            input_value: "John 3:16"
            jeff_reed_step: "observation"
      - get:
          url: "/rest/v1/study_guides"
          qs:
            select: "*"
            limit: "10"
```

**K6 Load Testing Script:**
```javascript
// k6-load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '5m', target: 100 },   // Ramp up
    { duration: '30m', target: 500 },  // Stay at 500 users
    { duration: '5m', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests under 2s
    http_req_failed: ['rate<0.02'],    // Error rate under 2%
  },
};

const BASE_URL = 'https://[PROJECT-URL].supabase.co';
const API_KEY = __ENV.SUPABASE_ANON_KEY;

export default function() {
  // Test study guide generation
  let response = http.post(`${BASE_URL}/functions/v1/study-generate`, 
    JSON.stringify({
      input_type: 'scripture',
      input_value: 'Philippians 4:13',
      jeff_reed_step: 'observation'
    }), 
    {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_KEY}`,
      },
    }
  );

  check(response, {
    'study generation successful': (r) => r.status === 200,
    'response time < 30s': (r) => r.timings.duration < 30000,
  });

  sleep(Math.random() * 3 + 1); // Random wait 1-4 seconds
}
```

### **Database Load Testing**

**Supabase PostgreSQL Performance Testing:**
```sql
-- Database connection stress test
SELECT 
  pg_stat_get_backend_pid(s.backendid) AS pid,
  pg_stat_get_backend_activity(s.backendid) AS query,
  pg_stat_get_backend_activity_start(s.backendid) AS query_start
FROM (SELECT pg_stat_get_backend_idset() AS backendid) AS s;

-- Table performance under load
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM study_guides 
WHERE user_id = $1 
ORDER BY created_at DESC 
LIMIT 20;

-- Index usage monitoring
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes 
ORDER BY idx_scan DESC;
```

**Connection Pool Testing:**
```bash
# Test connection pool limits
for i in {1..100}; do
  psql "postgresql://[CONNECTION-STRING]" -c "SELECT pg_sleep(10);" &
done

# Monitor active connections
psql "postgresql://[CONNECTION-STRING]" -c "
  SELECT 
    count(*) as active_connections,
    max_conn,
    count(*) * 100.0 / max_conn as percent_used
  FROM pg_stat_activity, 
       (SELECT setting::int as max_conn FROM pg_settings WHERE name = 'max_connections') mc;
"
```

### **LLM Integration Load Testing**

**AI Service Stress Testing:**
```javascript
// llm-load-test.js
export default function() {
  const payload = {
    input_type: 'scripture',
    input_value: `Matthew ${Math.floor(Math.random() * 28) + 1}:${Math.floor(Math.random() * 20) + 1}`,
    jeff_reed_step: ['observation', 'interpretation', 'correlation', 'application'][Math.floor(Math.random() * 4)]
  };

  let response = http.post(`${BASE_URL}/functions/v1/study-generate`, 
    JSON.stringify(payload),
    {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_KEY}`,
      },
      timeout: '60s',
    }
  );

  check(response, {
    'LLM response successful': (r) => r.status === 200,
    'LLM response time < 60s': (r) => r.timings.duration < 60000,
    'response contains study content': (r) => r.body.includes('summary'),
  });
}
```

**Rate Limiting Validation:**
```bash
# Test API rate limits
for i in {1..100}; do
  curl -w "%{http_code}\n" -o /dev/null -s \
    -X POST "https://[PROJECT-URL].supabase.co/functions/v1/study-generate" \
    -H "Authorization: Bearer [API-KEY]" \
    -H "Content-Type: application/json" \
    -d '{"input_type": "test", "input_value": "test"}' &
done
```

---

## 📈 **Performance Monitoring**

### **Real-time Metrics Collection**

**Supabase Dashboard Monitoring:**
- Database CPU and memory usage
- Connection pool utilization
- Query performance statistics
- Edge Function execution metrics

**Custom Monitoring Scripts:**
```bash
#!/bin/bash
# performance-monitor.sh

# API response time monitoring
while true; do
  RESPONSE_TIME=$(curl -w "%{time_total}" -o /dev/null -s \
    "https://[PROJECT-URL].supabase.co/rest/v1/study_guides?limit=1")
  echo "$(date): API Response Time: ${RESPONSE_TIME}s"
  
  if (( $(echo "$RESPONSE_TIME > 2.0" | bc -l) )); then
    echo "WARNING: API response time exceeded 2 seconds"
    # ⚠️ [REQUIRES HUMAN INPUT: Alert notification system]
  fi
  
  sleep 30
done
```

**Database Performance Monitoring:**
```sql
-- Create monitoring view
CREATE OR REPLACE VIEW performance_metrics AS
SELECT 
  NOW() as timestamp,
  (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') as active_connections,
  (SELECT ROUND(avg(mean_exec_time), 2) FROM pg_stat_statements WHERE calls > 100) as avg_query_time,
  (SELECT count(*) FROM pg_locks WHERE granted = false) as waiting_queries,
  pg_size_pretty(pg_database_size(current_database())) as db_size;

-- Monitor during load test
SELECT * FROM performance_metrics;
```

### **Alert Thresholds**

**Performance Alerts:**
```yaml
# monitoring-alerts.yml
alerts:
  api_response_time:
    threshold: 2000ms
    severity: warning
    action: scale_up_resources
    
  error_rate:
    threshold: 2%
    severity: critical
    action: investigate_errors
    
  database_connections:
    threshold: 80%
    severity: warning
    action: connection_pool_scaling
    
  memory_usage:
    threshold: 85%
    severity: critical
    action: resource_scaling
```

---

## 🎯 **Test Execution Procedures**

### **Pre-Test Checklist**
- [ ] Test environment configured and isolated
- [ ] Monitoring tools active and recording
- [ ] Baseline performance metrics captured
- [ ] Test data prepared and validated
- [ ] Rollback plan prepared in case of issues
- [ ] Team notified of testing schedule

### **Test Execution Steps**

**1. Environment Preparation:**
```bash
# Set up test environment variables
export SUPABASE_URL="https://[PROJECT-URL].supabase.co"
export SUPABASE_ANON_KEY="[ANON-KEY]"
export TEST_DURATION="30m"
export MAX_USERS="1000"

# Verify system baseline
curl -w "@curl-format.txt" -s -o /dev/null "$SUPABASE_URL/rest/v1/study_guides?limit=1"
```

**2. Load Test Execution:**
```bash
# Execute Artillery load test
artillery run artillery-config.yml --output test-results.json

# Execute K6 load test  
k6 run --vus 500 --duration 30m k6-load-test.js

# Execute database stress test
pgbench -h [HOST] -U [USER] -d [DATABASE] -c 50 -j 2 -T 300
```

**3. Results Analysis:**
```bash
# Generate Artillery report
artillery report test-results.json --output report.html

# Analyze K6 results
k6 run --summary-trend-stats="avg,min,max,p(95),p(99)" k6-load-test.js

# Database performance analysis
psql -c "SELECT * FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"
```

### **Post-Test Analysis**

**Performance Report Template:**
```markdown
# Load Test Report - [DATE]

## Test Configuration
- **Test Type:** [Normal/Peak/Stress/Spike]
- **Duration:** [Duration]
- **Max Concurrent Users:** [Number]
- **Test Environment:** [Environment Details]

## Results Summary
- **Total Requests:** [Number]
- **Success Rate:** [Percentage]
- **Average Response Time:** [Milliseconds]
- **95th Percentile Response Time:** [Milliseconds]
- **Peak Throughput:** [Requests/second]

## Performance Metrics
- **API Endpoints:** [Performance breakdown by endpoint]
- **Database Queries:** [Top slow queries identified]
- **Resource Usage:** [CPU, Memory, Storage utilization]
- **Error Analysis:** [Types and frequency of errors]

## Recommendations
- **Performance Optimizations:** [Specific recommendations]
- **Capacity Planning:** [Scaling recommendations]
- **Issue Resolution:** [Critical issues to address]
```

---

## 🔧 **Performance Optimization**

### **Database Optimization**

**Query Optimization:**
```sql
-- Add missing indexes identified during testing
CREATE INDEX CONCURRENTLY idx_study_guides_user_created 
ON study_guides(user_id, created_at DESC);

CREATE INDEX CONCURRENTLY idx_jeff_reed_sessions_status 
ON jeff_reed_sessions(status, created_at);

-- Optimize frequently used queries
EXPLAIN (ANALYZE, BUFFERS) 
SELECT sg.*, jrs.status 
FROM study_guides sg 
LEFT JOIN jeff_reed_sessions jrs ON sg.session_id = jrs.id 
WHERE sg.user_id = $1 
ORDER BY sg.created_at DESC 
LIMIT 20;
```

**Connection Pool Tuning:**
```sql
-- Optimize connection settings
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
SELECT pg_reload_conf();
```

### **API Performance Optimization**

**Edge Function Optimization:**
```typescript
// Optimize study generation function
import { createClient } from '@supabase/supabase-js';

// Connection pooling
const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  {
    db: {
      schema: 'public',
    },
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  }
);

// Implement request caching
const cache = new Map();
const CACHE_TTL = 1000 * 60 * 60; // 1 hour

export default async function studyGenerate(req: Request) {
  const cacheKey = await hashRequest(req);
  
  if (cache.has(cacheKey)) {
    const cached = cache.get(cacheKey);
    if (Date.now() - cached.timestamp < CACHE_TTL) {
      return new Response(JSON.stringify(cached.data), {
        headers: { 'Content-Type': 'application/json' }
      });
    }
  }
  
  // Process request and cache result
  const result = await processStudyGeneration(req);
  cache.set(cacheKey, { data: result, timestamp: Date.now() });
  
  return new Response(JSON.stringify(result), {
    headers: { 'Content-Type': 'application/json' }
  });
}
```

---

## 📋 **Test Schedule & Maintenance**

### **Regular Testing Schedule**
- **Weekly:** Basic load testing (100-500 users, 15 minutes)
- **Monthly:** Full load testing (up to 1,000 users, 30 minutes)
- **Quarterly:** Stress testing and capacity planning
- **Pre-Release:** Complete performance regression testing

### **Continuous Monitoring**
- **Real-time:** API response times and error rates
- **Daily:** Database performance metrics
- **Weekly:** Resource utilization trends
- **Monthly:** Performance baseline updates

### **Performance Baseline Updates**
```bash
#!/bin/bash
# baseline-update.sh - Monthly performance baseline capture

# Capture current performance metrics
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "performance_baselines/$TIMESTAMP"

# API performance baseline
artillery quick --count 100 --num 10 "https://[PROJECT-URL].supabase.co/rest/v1/study_guides" \
  > "performance_baselines/$TIMESTAMP/api_baseline.json"

# Database performance baseline
psql -c "COPY (SELECT * FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 20) 
         TO STDOUT WITH CSV HEADER" \
  > "performance_baselines/$TIMESTAMP/db_baseline.csv"

echo "Performance baseline captured: $TIMESTAMP"
```

---

## 📞 **Vendor Support & Emergency Contacts**

### **Infrastructure Support**
```yaml
vendor_contacts:
  supabase_support:
    plan: "Pro/Team/Enterprise"
    contact: "support@supabase.com"
    emergency_escalation: "[ENTERPRISE SUPPORT CONTACT]"
    response_time: "4 hours (Pro), 1 hour (Enterprise)"
    dashboard_access: "[SUPABASE DASHBOARD LOGIN]"
    
  openai_support:
    plan: "[API PLAN LEVEL]"
    contact: "support@openai.com"
    rate_limits: "[YOUR RATE LIMITS]"
    quota_monitoring: "[USAGE DASHBOARD]"
    
  infrastructure_providers:
    primary: "Supabase"
    backup: "[BACKUP PROVIDER IF ANY]"
    monitoring: "[MONITORING SERVICE]"
    cdn: "Let's Encrypt / CloudFlare"
```

### **Monitoring & Alerting Setup**
```yaml
monitoring_stack:
  uptime_monitoring:
    tool: "UptimeRobot / Pingdom"
    alerts: "SMS + Email"
    contacts: "[MONITORING ALERT CONTACTS]"
    
  application_monitoring:
    tool: "Sentry / LogRocket"
    error_tracking: "enabled"
    integration: "[SLACK/DISCORD WEBHOOK]"
    
  infrastructure_monitoring:
    tool: "Supabase Dashboard + External"
    metrics: "Response time, Error rate, Database performance"
    alert_thresholds: "Defined in monitoring-alerts.yml"
```

⚠️ **[REQUIRES HUMAN INPUT: Complete vendor support plan levels, monitoring tool configurations, and emergency contact information]**

---

**⚠️ [REQUIRES HUMAN INPUT: Specific Supabase project URLs, API keys, monitoring dashboard access credentials, and vendor support details need to be configured for actual testing implementation]**

**This document should be updated after each major system change and performance optimization implementation.**