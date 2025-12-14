# **👤 Anonymous User Data Lifecycle Management**

**Project Name:** Disciplefy: Bible Study  
**Backend:** Supabase (Unified Architecture)  
**Version:** 1.0  
**Date:** July 2025

## **1. 🎯 Overview & Scope**

### **Anonymous User Definition**
Anonymous users are individuals who access the Disciplefy: Bible Study app without creating an authenticated account. They can generate study guides, use  sessions, and provide feedback while maintaining privacy.

### **Data Lifecycle Scope**
- Session management and tracking
- Content generation and temporary storage
- Feedback collection and anonymization
- Data retention and automated cleanup
- Migration pathways to authenticated accounts
- Regulatory compliance (GDPR, India DPDP Act)

## **2. 📊 Anonymous User Data Categories**

### **Session Data**
| **Data Type** | **Purpose** | **Retention** | **PII Risk** | **Cleanup Method** |
|---------------|-------------|---------------|--------------|-------------------|
| Session ID | Track app usage | 24 hours | None | Automatic expiry |
| IP Address | Rate limiting | 1 hour | Low | Hashed after rate check |
| Device ID | Abuse prevention | 7 days | Medium | Anonymized hash |
| User Agent | Analytics | 30 days | Low | Aggregated only |

### **Generated Content**
| **Data Type** | **Purpose** | **Retention** | **Storage** | **Migration Path** |
|---------------|-------------|---------------|-------------|-------------------|
| Study Guides | User reference | 7 days | Local cache | Copy to user account |
|  Sessions | Progress tracking | 7 days | Local + server | Transfer ownership |
| Input Queries | Service improvement | 24 hours | Anonymized logs | Discard |
| Feedback | Quality improvement | 6 months | Anonymous aggregation | No migration |

### **Analytics Data**
| **Data Type** | **Purpose** | **Retention** | **Granularity** | **Compliance** |
|---------------|-------------|---------------|-----------------|----------------|
| Usage Patterns | Product improvement | 90 days | Aggregated only | GDPR compliant |
| Error Logs | System debugging | 30 days | No PII | Automatic cleanup |
| Performance Metrics | App optimization | 60 days | Statistical only | Privacy-safe |

## **3. 🔒 Privacy-First Session Management**

### **Anonymous Session Creation**
⚠️ **UPDATE**: The anonymous_sessions table was removed in migration 20250818000001_remove_unused_tables.sql as it was identified as unused in the current codebase.

```sql
-- Anonymous session table (REMOVED - for reference only)
-- This table structure was originally planned but never used in production
/*
CREATE TABLE anonymous_sessions (
  session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_fingerprint_hash VARCHAR(64), -- Hashed device identifier
  ip_address_hash VARCHAR(64), -- Hashed IP for rate limiting
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '24 hours'),
  study_guides_count INTEGER DEFAULT 0,
  jeff_reed_sessions_count INTEGER DEFAULT 0,
  is_migrated BOOLEAN DEFAULT false
);
*/

-- Automatic cleanup trigger
CREATE OR REPLACE FUNCTION cleanup_expired_anonymous_sessions()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM anonymous_sessions 
  WHERE expires_at < NOW();
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_cleanup_expired_sessions
  AFTER INSERT ON anonymous_sessions
  EXECUTE FUNCTION cleanup_expired_anonymous_sessions();
```

### **Privacy-Safe Device Fingerprinting**
```javascript
class PrivacySafeFingerprinting {
  static generateAnonymousId() {
    // Combine non-PII device characteristics
    const deviceInfo = {
      screenResolution: `${screen.width}x${screen.height}`,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      language: navigator.language,
      platform: navigator.platform.substring(0, 10) // Limit platform info
    };
    
    // Create hash without storing original values
    return this.hashDeviceInfo(deviceInfo);
  }
  
  static hashDeviceInfo(deviceInfo) {
    // Use crypto hash for privacy protection
    const dataString = JSON.stringify(deviceInfo);
    return crypto.subtle.digest('SHA-256', new TextEncoder().encode(dataString));
  }
}
```

## **4. 📝 Content Generation & Storage**

### **Anonymous Study Guide Management**
```sql
-- Anonymous study guides with privacy controls
-- Note: session_id is now a standalone UUID without FK constraint
CREATE TABLE anonymous_study_guides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID, -- No longer references anonymous_sessions (table removed)
  input_type VARCHAR(20) NOT NULL CHECK (input_type IN ('scripture', 'topic')),
  input_value_hash VARCHAR(64), -- Hashed input for duplicate detection
  summary TEXT NOT NULL,
  context TEXT NOT NULL,
  related_verses TEXT[] NOT NULL,
  reflection_questions TEXT[] NOT NULL,
  prayer_points TEXT[] NOT NULL,
  language VARCHAR(5) DEFAULT 'en',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '7 days')
);

-- Privacy-compliant indexing
CREATE INDEX idx_anonymous_guides_session ON anonymous_study_guides(session_id);
CREATE INDEX idx_anonymous_guides_expiry ON anonymous_study_guides(expires_at);
CREATE INDEX idx_anonymous_guides_hash ON anonymous_study_guides(input_value_hash);
```

### ** Anonymous Sessions**
```sql
-- Anonymous  sessions
-- Note: This table likely needs to be renamed to match actual implementation
CREATE TABLE anonymous_jeff_reed_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID, -- No longer references anonymous_sessions (table removed)
  topic VARCHAR(100) NOT NULL,
  current_step INTEGER DEFAULT 1 CHECK (current_step >= 1 AND current_step <= 4),
  step_1_context TEXT,
  step_2_scholar_guide TEXT,
  step_3_group_discussion TEXT,
  step_4_application TEXT,
  step_1_completed_at TIMESTAMP WITH TIME ZONE,
  step_2_completed_at TIMESTAMP WITH TIME ZONE,
  step_3_completed_at TIMESTAMP WITH TIME ZONE,
  step_4_completed_at TIMESTAMP WITH TIME ZONE,
  completion_status BOOLEAN DEFAULT false,
  language VARCHAR(5) DEFAULT 'en',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '7 days')
);
```

## **5. 🔄 Anonymous to Authenticated Migration**

### **Migration Workflow**
```dart
class AnonymousToAuthMigration {
  static Future<void> migrateAnonymousData(String sessionId, String userId) async {
    await _database.transaction((txn) async {
      // Migrate study guides
      await txn.execute('''
        INSERT INTO study_guides (
          user_id, input_type, input_value, summary, context,
          related_verses, reflection_questions, prayer_points, language
        )
        SELECT 
          ?, input_type, 
          CASE WHEN input_value_hash IS NOT NULL 
               THEN '[Recovered from anonymous session]' 
               ELSE input_value END,
          summary, context, related_verses, reflection_questions, 
          prayer_points, language
        FROM anonymous_study_guides 
        WHERE session_id = ?
      ''', [userId, sessionId]);
      
      // Migrate  sessions
      await txn.execute('''
        INSERT INTO jeff_reed_sessions (
          user_id, topic, current_step, step_1_context, step_2_scholar_guide,
          step_3_group_discussion, step_4_application, completion_status, language
        )
        SELECT 
          ?, topic, current_step, step_1_context, step_2_scholar_guide,
          step_3_group_discussion, step_4_application, completion_status, language
        FROM anonymous_jeff_reed_sessions 
        WHERE session_id = ?
      ''', [userId, sessionId]);
      
      // Mark session as migrated
      await txn.execute(
        'UPDATE anonymous_sessions SET is_migrated = true WHERE session_id = ?',
        [sessionId]
      );
      
      // Schedule cleanup (delayed to ensure migration success)
      await scheduleDelayedCleanup(sessionId);
    });
  }
}
```

### **Migration UI Flow**
```dart
class MigrationPromptWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AnonymousSessionData>(
      stream: AnonymousSessionService.getCurrentSession(),
      builder: (context, snapshot) {
        final hasContent = snapshot.hasData && 
                          (snapshot.data.studyGuidesCount > 0 || 
                           snapshot.data.jeffReedSessionsCount > 0);
        
        if (!hasContent) return SizedBox.shrink();
        
        return Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Save Your Progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'You have ${snapshot.data.studyGuidesCount} study guides. '
                  'Create an account to save them permanently.',
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => _dismissMigrationPrompt(),
                      child: Text('Maybe Later'),
                    ),
                    ElevatedButton(
                      onPressed: () => _startAccountCreation(),
                      child: Text('Create Account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

## **6. 🗑️ Automated Data Cleanup**

### **Cleanup Procedures**
```sql
-- Scheduled cleanup function
CREATE OR REPLACE FUNCTION perform_anonymous_data_cleanup()
RETURNS INTEGER AS $$
DECLARE
  cleaned_count INTEGER := 0;
BEGIN
  -- Cleanup expired study guides
  DELETE FROM anonymous_study_guides WHERE expires_at < NOW();
  GET DIAGNOSTICS cleaned_count = ROW_COUNT;
  
  -- Cleanup expired  sessions
  DELETE FROM anonymous_jeff_reed_sessions WHERE expires_at < NOW();
  
  -- Cleanup expired and migrated sessions
  DELETE FROM anonymous_sessions 
  WHERE expires_at < NOW() OR (is_migrated = true AND created_at < NOW() - INTERVAL '1 day');
  
  -- Cleanup orphaned analytics data
  DELETE FROM analytics_events 
  WHERE user_id IS NULL AND created_at < NOW() - INTERVAL '90 days';
  
  RETURN cleaned_count;
END;
$$ LANGUAGE plpgsql;

-- Schedule cleanup to run every hour
SELECT cron.schedule('anonymous-data-cleanup', '0 * * * *', 'SELECT perform_anonymous_data_cleanup();');
```

### **Cleanup Monitoring**
```sql
-- Cleanup monitoring table
CREATE TABLE cleanup_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cleanup_type VARCHAR(50) NOT NULL,
  records_cleaned INTEGER NOT NULL,
  execution_time_ms INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enhanced cleanup with logging
CREATE OR REPLACE FUNCTION perform_monitored_cleanup()
RETURNS VOID AS $$
DECLARE
  start_time TIMESTAMP;
  end_time TIMESTAMP;
  duration_ms INTEGER;
  cleaned_guides INTEGER;
  cleaned_sessions INTEGER;
BEGIN
  start_time := clock_timestamp();
  
  -- Perform cleanup and track results
  SELECT perform_anonymous_data_cleanup() INTO cleaned_guides;
  
  end_time := clock_timestamp();
  duration_ms := EXTRACT(MILLISECONDS FROM (end_time - start_time));
  
  -- Log cleanup results
  INSERT INTO cleanup_logs (cleanup_type, records_cleaned, execution_time_ms)
  VALUES ('anonymous_data', cleaned_guides, duration_ms);
END;
$$ LANGUAGE plpgsql;
```

## **7. 📊 Anonymous Analytics & Insights**

### **Privacy-Safe Analytics Collection**
```dart
class AnonymousAnalytics {
  static Future<void> trackAnonymousUsage(String event, Map<String, dynamic> params) async {
    // Remove any potential PII from params
    final sanitizedParams = _sanitizeAnalyticsParams(params);
    
    final analyticsEvent = {
      'event': event,
      'params': sanitizedParams,
      'session_type': 'anonymous',
      'timestamp': DateTime.now().toIso8601String(),
      'app_version': await _getAppVersion(),
    };
    
    await AnalyticsService.sendAnonymousEvent(analyticsEvent);
  }
  
  static Map<String, dynamic> _sanitizeAnalyticsParams(Map<String, dynamic> params) {
    // Remove or hash sensitive data
    final sanitized = Map<String, dynamic>.from(params);
    
    // Remove direct user inputs
    sanitized.remove('input_text');
    sanitized.remove('user_query');
    
    // Hash or categorize sensitive fields
    if (sanitized.containsKey('bible_verse')) {
      sanitized['bible_verse'] = _categorizeVerse(sanitized['bible_verse']);
    }
    
    return sanitized;
  }
}
```

### **Aggregated Reporting**
```sql
-- Anonymous usage analytics view
CREATE VIEW anonymous_usage_stats AS
SELECT 
  DATE(created_at) as usage_date,
  COUNT(DISTINCT session_id) as unique_sessions,
  COUNT(*) as total_study_guides,
  AVG(study_guides_count) as avg_guides_per_session,
  STRING_AGG(DISTINCT language, ',') as languages_used
FROM anonymous_sessions s
LEFT JOIN anonymous_study_guides g ON s.session_id = g.session_id
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY usage_date DESC;
```

## **8. ⚖️ Regulatory Compliance**

### **GDPR Compliance Framework**
```dart
class GDPRCompliance {
  // Data subject rights for anonymous users
  static Future<void> handleDataSubjectRequest(String requestType, String sessionId) async {
    switch (requestType) {
      case 'access':
        await _provideDataAccess(sessionId);
        break;
      case 'deletion':
        await _performDataDeletion(sessionId);
        break;
      case 'portability':
        await _exportAnonymousData(sessionId);
        break;
    }
  }
  
  static Future<void> _performDataDeletion(String sessionId) async {
    // Immediate deletion of all associated data
    await _database.transaction((txn) async {
      await txn.delete('anonymous_study_guides', where: 'session_id = ?', whereArgs: [sessionId]);
      await txn.delete('anonymous_jeff_reed_sessions', where: 'session_id = ?', whereArgs: [sessionId]);
      await txn.delete('anonymous_sessions', where: 'session_id = ?', whereArgs: [sessionId]);
    });
    
    // Log deletion for compliance audit
    await _logComplianceAction('data_deletion', sessionId);
  }
}
```

### **India DPDP Act Compliance**
```dart
class DPDPCompliance {
  // Notice and consent for anonymous data processing
  static Future<void> showDataProcessingNotice() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Data Processing Notice'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('We process the following data to provide our service:'),
            SizedBox(height: 8),
            Text('• Study guide content (stored for 7 days)'),
            Text('• Usage patterns (anonymized analytics)'),
            Text('• Session data (expires in 24 hours)'),
            SizedBox(height: 8),
            Text('You can request data deletion at any time through Settings.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _declineDataProcessing(),
            child: Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () => _acceptDataProcessing(),
            child: Text('Accept'),
          ),
        ],
      ),
    );
  }
}
```

### **Data Processing Record**
```sql
-- Data processing audit log
CREATE TABLE data_processing_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID,
  processing_purpose VARCHAR(100) NOT NULL,
  data_categories TEXT[] NOT NULL,
  legal_basis VARCHAR(50) NOT NULL,
  retention_period VARCHAR(50) NOT NULL,
  consent_given BOOLEAN DEFAULT false,
  consent_timestamp TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## **9. 🔍 Abuse Prevention**

### **Anonymous User Rate Limiting**
```dart
class AnonymousRateLimiting {
  static final Map<String, RateLimiter> _sessionLimiters = {};
  
  static Future<bool> checkRateLimit(String sessionId, String action) async {
    final limiter = _sessionLimiters.putIfAbsent(
      sessionId, 
      () => RateLimiter(
        maxRequests: action == 'study_generation' ? 3 : 10,
        windowDuration: Duration(hours: 1),
      ),
    );
    
    return limiter.canPerformAction();
  }
  
  // Enhanced abuse detection
  static Future<bool> detectSuspiciousActivity(String sessionId) async {
    final session = await _getAnonymousSession(sessionId);
    
    // Flag suspicious patterns
    if (session.studyGuidesCount > 5 && 
        session.createdAt.isAfter(DateTime.now().subtract(Duration(hours: 1)))) {
      await _flagSuspiciousSession(sessionId);
      return true;
    }
    
    return false;
  }
}
```

### **Device-Based Restrictions**
```dart
class DeviceRestrictions {
  static Future<bool> checkDeviceLimit(String deviceHash) async {
    final deviceUsage = await _database.query(
      'anonymous_sessions',
      where: 'device_fingerprint_hash = ? AND created_at > ?',
      whereArgs: [deviceHash, DateTime.now().subtract(Duration(days: 1))],
    );
    
    // Limit to 5 sessions per device per day
    return deviceUsage.length < 5;
  }
}
```

## **10. 📈 Lifecycle Metrics**

### **Key Performance Indicators**
```sql
-- Anonymous user lifecycle KPIs
CREATE VIEW anonymous_lifecycle_metrics AS
SELECT 
  'daily_anonymous_sessions' as metric_name,
  COUNT(DISTINCT session_id) as metric_value,
  CURRENT_DATE as metric_date
FROM anonymous_sessions 
WHERE DATE(created_at) = CURRENT_DATE

UNION ALL

SELECT 
  'conversion_rate' as metric_name,
  ROUND(
    (COUNT(CASE WHEN is_migrated THEN 1 END) * 100.0 / COUNT(*)), 2
  ) as metric_value,
  CURRENT_DATE as metric_date
FROM anonymous_sessions 
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'

UNION ALL

SELECT 
  'average_session_duration' as metric_name,
  EXTRACT(MINUTES FROM AVG(last_activity - created_at)) as metric_value,
  CURRENT_DATE as metric_date
FROM anonymous_sessions 
WHERE DATE(created_at) = CURRENT_DATE;
```

## **11. ✅ Implementation Checklist**

### **Data Architecture**
- [ ] Anonymous session table created with automatic cleanup
- [ ] Anonymous study guides table with expiration
- [ ] Anonymous  sessions table configured
- [ ] Privacy-safe analytics collection implemented

### **Lifecycle Management**
- [ ] Automated cleanup procedures scheduled
- [ ] Migration workflows tested and documented
- [ ] Data retention policies enforced
- [ ] Cleanup monitoring and logging active

### **Privacy & Compliance**
- [ ] GDPR data subject rights implemented
- [ ] India DPDP Act compliance measures active
- [ ] Privacy notices and consent flows configured
- [ ] Data processing audit logging operational

### **Security & Abuse Prevention**
- [ ] Rate limiting for anonymous users enforced
- [ ] Device-based restrictions implemented
- [ ] Suspicious activity detection active
- [ ] Abuse reporting mechanisms configured

### **User Experience**
- [ ] Migration prompts and flows implemented
- [ ] Clear data retention messaging provided
- [ ] Privacy settings and controls accessible
- [ ] Smooth anonymous-to-auth transitions working

This comprehensive lifecycle management ensures anonymous users can fully engage with the Disciplefy: Bible Study app while maintaining privacy, security, and regulatory compliance throughout their journey.