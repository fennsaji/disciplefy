# 🚨 Disaster Recovery Playbook
**Disciplefy: Bible Study App**

*Critical system recovery procedures for catastrophic failures*

---

## 📋 **Overview**

### **Recovery Objectives**
- **RTO (Recovery Time Objective):** 4 hours maximum
- **RPO (Recovery Point Objective):** 1 hour maximum data loss
- **Service Level Target:** 99.9% uptime excluding planned maintenance

### **Disaster Categories**
1. **Database Failure** - Supabase PostgreSQL corruption or unavailability
2. **Application Failure** - Edge Functions or Flutter app deployment issues
3. **Security Breach** - Unauthorized access or data compromise
4. **Infrastructure Failure** - Supabase platform outage
5. **Data Corruption** - User data integrity issues

---

## 🔥 **Immediate Response Protocol**

### **Step 1: Incident Detection (0-15 minutes)**

**Automated Alerts:**
- Supabase monitoring dashboard alerts
- API response time > 5 seconds
- Error rate > 5%
- Database connection failures

**Manual Detection:**
- User reports of service unavailability
- Customer support ticket volume spike
- Internal team notifications

**Immediate Actions:**
1. **Assess Impact:** Determine affected systems and user count
2. **Notify Team:** Alert response team via emergency contacts
3. **Document Start Time:** Begin incident log with timestamp
4. **Activate War Room:** ⚠️ *[REQUIRES HUMAN INPUT: Emergency communication channel setup]*

### **Step 2: Impact Assessment (15-30 minutes)**

**System Health Check:**
```bash
# Supabase status verification
curl -I https://[PROJECT-URL].supabase.co/rest/v1/
curl -I https://[PROJECT-URL].supabase.co/auth/v1/

# Database connectivity
psql "postgresql://[CONNECTION-STRING]" -c "SELECT 1;"

# Edge Functions status
curl -I https://[PROJECT-URL].supabase.co/functions/v1/study-generate
```

**Data Integrity Verification:**
```sql
-- Check recent data consistency
SELECT COUNT(*) FROM study_guides WHERE created_at > NOW() - INTERVAL '1 hour';
SELECT COUNT(*) FROM jeff_reed_sessions WHERE created_at > NOW() - INTERVAL '1 hour';
SELECT COUNT(*) FROM feedback WHERE created_at > NOW() - INTERVAL '1 hour';
```

### **Step 3: Communication (30-45 minutes)**

**Internal Communication:**
- ⚠️ *[REQUIRES HUMAN INPUT: Development team emergency contacts]*
- ⚠️ *[REQUIRES HUMAN INPUT: Management escalation procedures]*
- ⚠️ *[REQUIRES HUMAN INPUT: Legal team notification (if security breach)]*

**External Communication:**
- **Status Page Update:** ⚠️ *[REQUIRES HUMAN INPUT: Status page URL and update procedure]*
- **User Notification:** Email/in-app notification template
- **Support Team Briefing:** Customer service talking points

**Communication Template:**
```
Subject: [URGENT] Disciplefy Service Disruption - [TIMESTAMP]

We are currently experiencing technical difficulties with the Disciplefy: Bible Study app. 

Impact: [Brief description of user-facing impact]
Estimated Resolution: [Time estimate]
Workaround: [Any available alternatives]

We sincerely apologize for the inconvenience and are working to restore full service as quickly as possible.

Updates: [Status page URL]
```

---

## 🛠️ **Recovery Procedures**

### **Database Recovery**

**Scenario 1: Database Corruption**
```bash
# 1. Stop all application traffic
# Update Supabase Edge Function to return maintenance mode

# 2. Assess corruption extent
psql "postgresql://[CONNECTION-STRING]" -c "
  SELECT schemaname, tablename, 
         pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
  FROM pg_tables 
  WHERE schemaname = 'public'
  ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
"

# 3. Restore from backup (Supabase automatic backups)
# Access Supabase Dashboard > Settings > Database > Backups
# Select most recent uncorrupted backup

# Production configuration
production_config:
  supabase_project:
    url: "https://[PROJECT-ID].supabase.co"
    plan: "Pro/Team"
    backup_frequency: "6 hours"
    dashboard_access: "[SUPABASE DASHBOARD LOGIN]"
    
  domain_setup:
    primary: "disciplefy.app"
    api: "api.disciplefy.app"
    admin: "admin.disciplefy.app"
    
  ssl_certificates:
    provider: "Let's Encrypt / CloudFlare"
    auto_renewal: "enabled"

# ⚠️ [REQUIRES HUMAN INPUT: Update production Supabase project details and dashboard access credentials]
```

**Scenario 2: Data Loss Recovery**
```sql
-- Verify backup integrity
SELECT 
  backup_time,
  backup_size,
  status
FROM pg_stat_backup_history 
ORDER BY backup_time DESC 
LIMIT 5;

-- Restore specific tables if needed
-- ⚠️ [REQUIRES HUMAN INPUT: Contact Supabase support for selective restore]
```

### **Application Recovery**

**Edge Functions Deployment Issues:**
```bash
# 1. Check function logs
supabase functions logs study-generate --project-ref [PROJECT-REF]

# 2. Redeploy functions
supabase functions deploy study-generate --project-ref [PROJECT-REF]
supabase functions deploy auth-session --project-ref [PROJECT-REF]
supabase functions deploy feedback --project-ref [PROJECT-REF]

# 3. Verify deployment
curl -X POST "https://[PROJECT-URL].supabase.co/functions/v1/study-generate" \
  -H "Authorization: Bearer [ANON-KEY]" \
  -H "Content-Type: application/json" \
  -d '{"input_type": "test", "input_value": "test"}'
```

**Flutter App Issues:**
```bash
# 1. Rollback to last known good version
# ⚠️ [REQUIRES HUMAN INPUT: CI/CD rollback procedure]

# 2. Emergency hotfix deployment
flutter build web --release
flutter build apk --release
flutter build ipa --release

# 3. Update app stores with emergency patch
# ⚠️ [REQUIRES HUMAN INPUT: App store emergency review process]
```

### **Security Breach Response**

**Immediate Actions:**
1. **Isolate Affected Systems:** Disable compromised accounts/tokens
2. **Preserve Evidence:** Capture logs and system state
3. **Change Critical Credentials:** Reset all API keys and passwords
4. **Enable Additional Monitoring:** Activate enhanced logging

**Security Isolation:**
```sql
-- Disable all user sessions
UPDATE auth.sessions SET expires_at = NOW() WHERE expires_at > NOW();

-- Reset API keys
-- ⚠️ [REQUIRES HUMAN INPUT: Generate new Supabase API keys]

-- Enable audit logging
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();
```

**Evidence Preservation:**
```bash
# Export recent logs
supabase logs --type database --start "2024-01-01" --end "2024-01-02" > incident_logs.txt

# Capture system configuration
# ⚠️ [REQUIRES HUMAN INPUT: Document affected user accounts and access patterns]
```

---

## 📊 **Monitoring & Validation**

### **Recovery Verification Checklist**

**System Health:**
- [ ] Database responding within 2 seconds
- [ ] All Edge Functions returning 200 status
- [ ] Authentication flow working
- [ ] Study guide generation functional
- [ ] File uploads/downloads operational

**Data Integrity:**
- [ ] Recent user data accessible
- [ ] Study guides displaying correctly
- [ ] User preferences preserved
- [ ] Payment records intact (if applicable)

**Performance Metrics:**
```bash
# API response times
curl -w "@curl-format.txt" -s -o /dev/null "https://[PROJECT-URL].supabase.co/rest/v1/study_guides"

# Database performance
psql "postgresql://[CONNECTION-STRING]" -c "
  SELECT query, mean_exec_time, calls 
  FROM pg_stat_statements 
  ORDER BY mean_exec_time DESC 
  LIMIT 10;
"
```

### **Post-Recovery Actions**

**Documentation:**
1. **Incident Report:** Complete post-mortem analysis
2. **Timeline Documentation:** Detailed recovery timeline
3. **Lessons Learned:** Process improvements identified
4. **Preventive Measures:** Updates to prevent recurrence

**System Hardening:**
- Review and update backup procedures
- Enhance monitoring and alerting
- Update security configurations
- Test recovery procedures quarterly

---

## 🔄 **Backup Verification**

### **Automated Backup Schedule**
- **Database Backups:** Every 6 hours (Supabase automatic)
- **File Storage Backups:** Daily (Supabase Storage)
- **Configuration Backups:** Weekly manual export

### **Backup Testing Procedure**
```bash
# Monthly backup restore test
# 1. Create test environment
# 2. Restore latest backup
# 3. Verify data integrity
# 4. Test critical user flows
# 5. Document any issues

# ⚠️ [REQUIRES HUMAN INPUT: Test environment setup procedure]
```

### **Backup Retention Policy**
- **Hourly backups:** 24 hours retention
- **Daily backups:** 30 days retention
- **Weekly backups:** 1 year retention
- **Monthly backups:** 7 years retention (compliance)

---

## 📞 **Emergency Contacts**

### **Internal Team**
```yaml
emergency_contacts:
  technical_lead:
    name: "[YOUR NAME]"
    phone: "[24/7 CONTACT NUMBER]"
    email: "[EMAIL]@disciplefy.app"
    role: "Primary technical incident response"
    
  security_officer:
    name: "[SECURITY LEAD NAME]"
    phone: "[24/7 CONTACT NUMBER]"
    email: "security@disciplefy.app"
    role: "Security incident coordination"
    
  management_escalation:
    name: "[CTO/FOUNDER NAME]"
    phone: "[EMERGENCY CONTACT]"
    email: "[EMAIL]@disciplefy.app"
    role: "Executive decision making"
    
  devops_engineer:
    name: "[DEVOPS ENGINEER NAME]"
    phone: "[CONTACT NUMBER]"
    email: "[EMAIL]@disciplefy.app"
    role: "Infrastructure recovery"
```

⚠️ **[REQUIRES HUMAN INPUT: Complete emergency contact information above]**

### **External Vendors**
```yaml
vendor_contacts:
  supabase_support:
    plan: "Pro/Team/Enterprise"
    contact: "support@supabase.com"
    emergency_escalation: "[ENTERPRISE SUPPORT CONTACT]"
    response_time: "4 hours (Pro), 1 hour (Enterprise)"
    
  openai_support:
    plan: "[API PLAN LEVEL]"
    contact: "support@openai.com"
    rate_limits: "[YOUR RATE LIMITS]"
    
  infrastructure_providers:
    primary: "Supabase"
    backup: "[BACKUP PROVIDER IF ANY]"
    monitoring: "[MONITORING SERVICE]"
```

⚠️ **[REQUIRES HUMAN INPUT: Update vendor support plan levels and contacts]**

### **Regulatory Bodies**
```yaml
regulatory_contacts:
  data_protection_authority:
    region: "[YOUR REGION - EU/US/INDIA]"
    contact: "[DPA BREACH NOTIFICATION EMAIL]"
    phone: "[DPA PHONE NUMBER]"
    notification_deadline: "72 hours (GDPR)"
    
  cybersecurity_authority:
    national_cert: "[NATIONAL CERT CONTACT]"
    email: "[CERT EMAIL]"
    reporting_requirements: "[SECTOR-SPECIFIC REQUIREMENTS]"
```

⚠️ **[REQUIRES HUMAN INPUT: Add regulatory contact information for your jurisdiction]**

---

## 📋 **Recovery Checklist Templates**

### **Database Recovery Checklist**
- [ ] Incident detected and logged
- [ ] Team notified and war room activated
- [ ] Impact assessment completed
- [ ] Backup integrity verified
- [ ] Recovery point identified
- [ ] Application traffic stopped
- [ ] Database restored from backup
- [ ] Data integrity verified
- [ ] Application services restarted
- [ ] User acceptance testing completed
- [ ] Service fully restored
- [ ] Post-incident review scheduled

### **Security Incident Checklist**
- [ ] Incident contained and isolated
- [ ] Evidence preserved
- [ ] Affected systems identified
- [ ] Credentials rotated
- [ ] Users notified (if required)
- [ ] Regulators notified (if required)
- [ ] Forensic analysis initiated
- [ ] Security patches applied
- [ ] Systems restored and hardened
- [ ] Incident documentation completed

---

**This playbook should be reviewed quarterly and updated based on system changes and lessons learned from any incidents.**