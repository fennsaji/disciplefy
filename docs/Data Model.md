# **📊 Comprehensive Data Model - Defeah Bible Study App**

**Project Name:** Defeah Bible Study  
**Backend:** Supabase (PostgreSQL)  
**Version:** 1.0  
**Date:** July 2025

## **1. 🏗️ Core Entity Relationships**

```
User (1) ←→ (0..*) StudyGuide
User (1) ←→ (0..*) JeffReedSession  
User (1) ←→ (0..*) Feedback
User (1) ←→ (0..*) AdminLog
StudyGuide (1) ←→ (0..*) Feedback
JeffReedSession (1) ←→ (0..*) Feedback
```

## **2. 📋 Complete Entity Definitions**

### **👤 User Table**
```sql
CREATE TABLE auth.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE,
  name VARCHAR(255),
  auth_provider VARCHAR(50) DEFAULT 'anonymous',
  language_preference VARCHAR(5) DEFAULT 'en',
  theme_preference VARCHAR(20) DEFAULT 'light',
  is_admin BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### **📖 StudyGuide Table**
```sql
CREATE TABLE study_guides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  input_type VARCHAR(20) NOT NULL CHECK (input_type IN ('scripture', 'topic')),
  input_value VARCHAR(255) NOT NULL,
  summary TEXT NOT NULL,
  context TEXT NOT NULL,
  related_verses TEXT[] NOT NULL,
  reflection_questions TEXT[] NOT NULL,
  prayer_points TEXT[] NOT NULL,
  language VARCHAR(5) DEFAULT 'en',
  is_saved BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_study_guides_user_id ON study_guides(user_id);
CREATE INDEX idx_study_guides_created_at ON study_guides(created_at DESC);
CREATE INDEX idx_study_guides_input_type ON study_guides(input_type);
CREATE INDEX idx_study_guides_language ON study_guides(language);
```

### **🎯 JeffReedSession Table**
```sql
CREATE TABLE jeff_reed_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
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
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_jeff_reed_sessions_user_id ON jeff_reed_sessions(user_id);
CREATE INDEX idx_jeff_reed_sessions_topic ON jeff_reed_sessions(topic);
CREATE INDEX idx_jeff_reed_sessions_completion ON jeff_reed_sessions(completion_status);
```

### **📝 Feedback Table**
```sql
CREATE TABLE feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  study_guide_id UUID REFERENCES study_guides(id) ON DELETE CASCADE,
  jeff_reed_session_id UUID REFERENCES jeff_reed_sessions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  was_helpful BOOLEAN NOT NULL,
  message TEXT,
  category VARCHAR(50) DEFAULT 'general',
  sentiment_score FLOAT CHECK (sentiment_score >= -1.0 AND sentiment_score <= 1.0),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraint: Must reference either study_guide or jeff_reed_session
  CONSTRAINT feedback_reference_check 
    CHECK ((study_guide_id IS NOT NULL AND jeff_reed_session_id IS NULL) OR 
           (study_guide_id IS NULL AND jeff_reed_session_id IS NOT NULL))
);

-- Indexes
CREATE INDEX idx_feedback_study_guide_id ON feedback(study_guide_id);
CREATE INDEX idx_feedback_jeff_reed_session_id ON feedback(jeff_reed_session_id);
CREATE INDEX idx_feedback_user_id ON feedback(user_id);
CREATE INDEX idx_feedback_created_at ON feedback(created_at DESC);
```

### **💳 Donations Table**
```sql
CREATE TABLE donations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  razorpay_payment_id VARCHAR(255) UNIQUE,
  razorpay_order_id VARCHAR(255) NOT NULL,
  amount INTEGER NOT NULL CHECK (amount > 0),
  currency VARCHAR(3) DEFAULT 'INR',
  status VARCHAR(20) DEFAULT 'created',
  receipt_email VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE
);

-- Indexes
CREATE INDEX idx_donations_user_id ON donations(user_id);
CREATE INDEX idx_donations_status ON donations(status);
CREATE INDEX idx_donations_created_at ON donations(created_at DESC);
```

### **📊 AdminLog Table**
```sql
CREATE TABLE admin_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  action VARCHAR(100) NOT NULL,
  target_table VARCHAR(50),
  target_id UUID,
  ip_address INET,
  user_agent TEXT,
  details JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_admin_logs_admin_user_id ON admin_logs(admin_user_id);
CREATE INDEX idx_admin_logs_action ON admin_logs(action);
CREATE INDEX idx_admin_logs_created_at ON admin_logs(created_at DESC);
```

### **🛡️ LLM Security Events Table**
```sql
CREATE TABLE llm_security_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id VARCHAR(255),
  ip_address INET,
  event_type VARCHAR(50) NOT NULL,
  input_text TEXT,
  risk_score FLOAT CHECK (risk_score >= 0.0 AND risk_score <= 1.0),
  action_taken VARCHAR(50),
  detection_details JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_security_events_type_time ON llm_security_events(event_type, created_at DESC);
CREATE INDEX idx_security_events_user ON llm_security_events(user_id, created_at DESC);
CREATE INDEX idx_security_events_ip ON llm_security_events(ip_address, created_at DESC);
```

### **📈 Analytics Table**
```sql
CREATE TABLE analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type VARCHAR(50) NOT NULL,
  event_data JSONB,
  session_id VARCHAR(255),
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_analytics_events_type ON analytics_events(event_type);
CREATE INDEX idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX idx_analytics_events_created_at ON analytics_events(created_at DESC);
```

## **3. 🔐 Row Level Security (RLS) Policies**

### **User Data Protection**
```sql
-- Users can only access their own data
ALTER TABLE study_guides ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own study guides" ON study_guides
  FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can insert own study guides" ON study_guides
  FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Jeff Reed Sessions
ALTER TABLE jeff_reed_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own jeff reed sessions" ON jeff_reed_sessions
  FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can insert own jeff reed sessions" ON jeff_reed_sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Feedback
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own feedback" ON feedback
  FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can insert own feedback" ON feedback
  FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);
```

### **Admin Access Policies**
```sql
-- Admin users can access all data
CREATE POLICY "Admins can view all study guides" ON study_guides
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM auth.users 
      WHERE auth.uid() = id AND is_admin = true
    )
  );

-- Similar admin policies for all tables
```

## **4. 📊 Data Relationships & Constraints**

### **Foreign Key Relationships**
- **User → StudyGuide**: One-to-many (user can have multiple study guides)
- **User → JeffReedSession**: One-to-many (user can have multiple sessions)
- **User → Feedback**: One-to-many (user can provide multiple feedback)
- **StudyGuide → Feedback**: One-to-many (study guide can have multiple feedback)
- **JeffReedSession → Feedback**: One-to-many (session can have multiple feedback)

### **Business Rules**
- Anonymous users (user_id = NULL) can generate content but cannot save permanently
- JeffReedSession completion_status automatically set to true when step_4_completed_at is populated
- Feedback must reference either a StudyGuide OR JeffReedSession, not both
- Admin logs capture all administrative actions with IP tracking

## **5. 🚀 Performance Optimization**

### **Database Indexes**
- Primary keys automatically indexed
- Foreign keys indexed for join performance
- Timestamp fields indexed for chronological queries
- Composite indexes for complex queries

### **Query Optimization**
```sql
-- Efficient user history query
SELECT sg.*, f.was_helpful 
FROM study_guides sg 
LEFT JOIN feedback f ON sg.id = f.study_guide_id 
WHERE sg.user_id = ? 
ORDER BY sg.created_at DESC 
LIMIT 20;

-- Jeff Reed session progress query
SELECT topic, current_step, completion_status 
FROM jeff_reed_sessions 
WHERE user_id = ? AND completion_status = false 
ORDER BY updated_at DESC;
```

## **6. 🔄 Data Migration & Versioning**

### **Version Compatibility**
- **V1.0**: Basic study guide generation
- **V1.1**: Jeff Reed session tracking
- **V1.2**: Multi-language support
- **V2.0**: Advanced analytics and admin features
- **V2.1**: Enhanced security logging
- **V2.2**: Performance optimizations
- **V2.3**: Extended feedback and quality metrics

### **Migration Strategy**
- Backward compatible schema changes
- Gradual rollout of new features
- Data integrity validation after each migration
- Rollback procedures for critical issues

## **7. 📋 Data Validation Rules**

### **Input Validation**
- **input_type**: Must be 'scripture' or 'topic'
- **language**: Must be valid ISO language code (en, hi, ml)
- **amount**: Must be positive integer for donations
- **current_step**: Must be between 1 and 4 for Jeff Reed sessions

### **Content Validation**
- **summary, context**: Non-empty text fields
- **related_verses, reflection_questions, prayer_points**: Non-empty arrays
- **sentiment_score**: Must be between -1.0 and 1.0

## **8. 🏷️ Standardized Terminology**

### **Study Guide Output Fields**
- **summary**: Brief overview paragraph
- **context**: Historical and theological background
- **related_verses**: Array of scripture references
- **reflection_questions**: Array of thoughtful questions
- **prayer_points**: Array of prayer and action items

### **Jeff Reed Session Steps**
- **step_1_context**: Historical and cultural background
- **step_2_scholar_guide**: Theological explanation and commentary
- **step_3_group_discussion**: Questions for group reflection
- **step_4_application**: Practical ways to live out the teaching

## **✅ Data Model Implementation Checklist**

- [ ] All tables created with proper constraints
- [ ] Row Level Security policies implemented
- [ ] Indexes created for performance optimization
- [ ] Foreign key relationships established
- [ ] Business rules enforced via constraints
- [ ] Data validation rules implemented
- [ ] Admin access controls configured
- [ ] Migration scripts prepared
- [ ] Performance testing completed
- [ ] Backup and recovery procedures established