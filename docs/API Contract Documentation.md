# **🌐 API Contract Documentation**

**Project Name:** Defeah Bible Study  
**Version:** 1.0  
**Type:** RESTful API  
**Backend:** Supabase Edge Functions

## **🔐 Authentication & Authorization**

- **Auth Method**: Supabase Auth (JWT-based)
- **Header**: Authorization: Bearer <token>
- **Anonymous Access**: Supported with stricter rate limits
- **Admin Access**: Role-based verification required

## **📥 1. Generate Study Guide**

**Endpoint**: POST /api/study/generate  
**Auth Required**: ❌ No (optional for saving)

**Description**: Generates a standardized study guide based on Bible verse or topic input

### **Request Body**
```json
{
  "input_type": "scripture",  // "scripture" or "topic"
  "input_value": "Romans 12:1",
  "language": "en"  // "en", "hi", "ml"
}
```

### **Response**
```json
{
  "guide_id": "abc123",
  "summary": "Brief overview of the passage...",
  "context": "Historical and theological background...",
  "related_verses": ["1 Peter 2:5", "John 3:16"],
  "reflection_questions": ["What does sacrifice mean to you?"],
  "prayer_points": ["Lord, help me offer myself fully to you..."],
  "language": "en",
  "created_at": "2025-07-04T12:34:56Z"
}
```

## **📤 2. Save Study Guide to Profile**

**Endpoint**: POST /api/study/save  
**Auth Required**: ✅ Yes

**Description**: Saves a generated study guide to authenticated user's history

### **Request Body**
```json
{
  "guide_id": "abc123",
  "personal_notes": "This really spoke to me about...",
  "is_favorited": false
}
```

### **Response**
```json
{
  "message": "Study guide saved successfully",
  "saved_at": "2025-07-04T12:34:56Z"
}
```

## **📚 3. Get Saved Guides (History)**

**Endpoint**: GET /api/study/saved  
**Auth Required**: ✅ Yes

**Description**: Fetches all saved study guides for authenticated user

### **Query Parameters**
- `limit` (optional): Number of guides to return (default: 20, max: 100)
- `offset` (optional): Pagination offset (default: 0)
- `language` (optional): Filter by language

### **Response**
```json
{
  "guides": [
    {
      "guide_id": "abc123",
      "input_value": "faith",
      "input_type": "topic",
      "summary": "Faith is the foundation...",
      "context": "Throughout Scripture...",
      "related_verses": ["Hebrews 11:1", "Romans 10:17"],
      "reflection_questions": ["How has faith grown in your life?"],
      "prayer_points": ["Strengthen my faith daily..."],
      "personal_notes": "This really spoke to me...",
      "is_favorited": true,
      "saved_at": "2025-07-04T12:34:56Z",
      "language": "en"
    }
  ],
  "total_count": 45,
  "has_more": true
}
```

## **❌ 4. Delete Saved Guide**

**Endpoint**: DELETE /api/study/saved/{guide_id}  
**Auth Required**: ✅ Yes

**Description**: Removes a saved study guide from user's collection

### **Response**
```json
{
  "message": "Study guide removed from saved items"
}
```

## **📘 5. Get Jeff Reed Topics**

**Endpoint**: GET /api/topics/jeffreed  
**Auth Required**: ❌ No

**Description**: Returns predefined static topics for Jeff Reed study method

### **Query Parameters**
- `language` (optional): Language for topic names (default: "en")

### **Response**
```json
{
  "topics": [
    {
      "id": "topic-001",
      "name": "Gospel",
      "description": "The good news of Jesus Christ",
      "scripture_references": ["John 3:16", "Romans 1:16"],
      "display_order": 1
    },
    {
      "id": "topic-002", 
      "name": "Grace",
      "description": "God's unmerited favor toward humanity",
      "scripture_references": ["Ephesians 2:8-9", "2 Corinthians 12:9"],
      "display_order": 2
    }
  ]
}
```

## **🧠 6. Generate Jeff Reed Study Session**

**Endpoint**: POST /api/study/jeffreed  
**Auth Required**: ❌ No (optional for saving progress)

**Description**: Generates a 4-step Jeff Reed study guide for a selected static topic

### **Request Body**
```json
{
  "topic_id": "topic-001",  // From topics endpoint
  "language": "en"
}
```

### **Response**
```json
{
  "session_id": "sess-456",
  "topic": "Gospel",
  "step_1_context": "Historical and cultural background of the Gospel message...",
  "step_2_scholar_guide": "Theological explanation and commentary...",
  "step_3_group_discussion": "Questions for group reflection and discussion...",
  "step_4_application": "Practical ways to live out this teaching...",
  "current_step": 1,
  "completion_status": false,
  "created_at": "2025-07-04T12:34:56Z"
}
```

## **📈 7. Update Jeff Reed Session Progress**

**Endpoint**: PUT /api/study/jeffreed/{session_id}/progress  
**Auth Required**: ✅ Yes

**Description**: Updates user's progress through Jeff Reed study steps

### **Request Body**
```json
{
  "completed_step": 2,
  "notes": "Completed reflection on Gospel basics"
}
```

### **Response**
```json
{
  "session_id": "sess-456",
  "current_step": 3,
  "completion_status": false,
  "updated_at": "2025-07-04T12:35:10Z"
}
```

## **📝 8. Submit Feedback**

**Endpoint**: POST /api/feedback  
**Auth Required**: ✅ Yes

**Description**: Submit feedback on LLM-generated study guides

### **Request Body**
```json
{
  "guide_id": "abc123",
  "was_helpful": true,
  "message": "Really helped me understand God's mercy.",
  "category": "content_quality"  // Optional: content_quality, theological_accuracy, technical_issue
}
```

### **Response**
```json
{
  "message": "Feedback recorded. Thank you!",
  "feedback_id": "fb-789"
}
```

## **🔍 9. Search Study Guides**

**Endpoint**: GET /api/study/search  
**Auth Required**: ❌ No

**Description**: Search through study guides by content or topic

### **Query Parameters**
- `q`: Search query string
- `type`: Filter by "scripture" or "topic"
- `language`: Filter by language
- `limit`: Results limit (default: 10, max: 50)

### **Response**
```json
{
  "results": [
    {
      "guide_id": "abc123",
      "input_value": "love",
      "summary": "God's love is unconditional...",
      "relevance_score": 0.95
    }
  ],
  "total_count": 15
}
```

## **👤 10. User Profile Management**

**Endpoint**: GET /api/user/profile  
**Auth Required**: ✅ Yes

### **Response**
```json
{
  "user_id": "user-123",
  "email": "user@example.com",
  "name": "John Doe",
  "language_preference": "en",
  "theme_preference": "light",
  "total_guides_generated": 25,
  "total_saved_guides": 12,
  "jeff_reed_sessions_completed": 3,
  "member_since": "2025-01-15T10:30:00Z"
}
```

**Endpoint**: PUT /api/user/profile  
**Auth Required**: ✅ Yes

### **Request Body**
```json
{
  "name": "John Doe",
  "language_preference": "hi",
  "theme_preference": "dark"
}
```

## **💳 11. Donation Processing**

**Endpoint**: POST /api/donations/create  
**Auth Required**: ❌ No (optional for receipt)

**Description**: Creates a donation transaction with Razorpay

### **Request Body**
```json
{
  "amount": 10000,  // Amount in smallest currency unit (paise for INR)
  "currency": "INR",
  "receipt_email": "donor@example.com"  // Optional
}
```

### **Response**
```json
{
  "transaction_id": "txn-789",
  "razorpay_order_id": "order_xyz123",
  "amount": 10000,
  "currency": "INR",
  "status": "created"
}
```

**Endpoint**: POST /api/donations/verify  
**Auth Required**: ❌ No

**Description**: Verifies payment completion via webhook

### **Request Body** (from Razorpay webhook)
```json
{
  "razorpay_payment_id": "pay_xyz789",
  "razorpay_order_id": "order_xyz123",
  "razorpay_signature": "signature_hash"
}
```

## **⚡ 12. Admin API Endpoints**

**Endpoint**: GET /api/admin/dashboard/overview  
**Auth Required**: ✅ Yes (Admin role)

### **Response**
```json
{
  "total_users": 1250,
  "daily_active_users": 85,
  "guides_generated_today": 156,
  "feedback_pending_review": 12,
  "llm_cost_today": 4.50,
  "system_health": "healthy"
}
```

**Endpoint**: GET /api/admin/feedback/queue  
**Auth Required**: ✅ Yes (Admin role)

### **Response**
```json
{
  "feedback_items": [
    {
      "feedback_id": "fb-123",
      "guide_id": "abc456",
      "user_id": "user-789",
      "was_helpful": false,
      "message": "The study guide was confusing",
      "sentiment_score": -0.6,
      "created_at": "2025-07-04T11:20:00Z",
      "status": "pending_review"
    }
  ],
  "total_pending": 12
}
```

## **🛡️ Error Response Format**

### **Standard Error Structure**
```json
{
  "error": {
    "code": "UI-E-001",
    "message": "Please provide a valid Bible verse or topic.",
    "details": "Input validation failed for format requirements",
    "timestamp": "2025-07-04T12:34:56Z",
    "request_id": "req-123abc"
  }
}
```

### **Common Error Codes**
- `UI-E-001`: Invalid input format
- `AU-E-001`: Authentication required
- `AU-E-002`: Invalid or expired token
- `RL-E-001`: Rate limit exceeded
- `LM-E-001`: LLM processing failed
- `DB-E-001`: Database operation failed
- `PM-E-001`: Payment processing failed

## **⏳ Rate Limiting**

| **User Type** | **Study Generation** | **API Requests** | **Window** |
|---------------|---------------------|------------------|------------|
| Anonymous | 3 guides | 10 requests | 1 hour |
| Authenticated | 30 guides | 100 requests | 1 hour |
| Admin | 1000 guides | 5000 requests | 1 hour |

### **Rate Limit Headers**
```
X-RateLimit-Limit: 30
X-RateLimit-Remaining: 25
X-RateLimit-Reset: 1625140800
```

### **Rate Limit Exceeded Response**
```json
{
  "error": {
    "code": "RL-E-001",
    "message": "Rate limit exceeded. Try again in 45 minutes or sign in for higher limits.",
    "retry_after": 2700
  }
}
```

## **🔧 API Versioning**

**URL Structure**: `/api/v1/{endpoint}`  
**Current Version**: v1  
**Version Header**: `API-Version: 1.0`

**Backward Compatibility**:
- V1.0 → V1.1: Additive changes only
- V1.x → V2.0: Breaking changes, parallel support for 6 months

## **📊 Response Caching**

| **Endpoint** | **Cache Duration** | **Cache Key** |
|--------------|-------------------|---------------|
| `/api/topics/jeffreed` | 24 hours | language |
| `/api/study/search` | 1 hour | query + filters |
| Study Guide generation | No cache | N/A |
| User profiles | 5 minutes | user_id |

## **🌍 Internationalization**

### **Supported Languages**
- `en`: English (default)
- `hi`: Hindi (V1.2+)
- `ml`: Malayalam (V1.2+)

### **Language Header**
```
Accept-Language: hi-IN,hi;q=0.9,en;q=0.8
```

### **Localized Endpoints**
- All user-facing content respects language preference
- Jeff Reed topics available in all supported languages
- Error messages localized based on Accept-Language header

## **✅ API Contract Validation**

### **Request Validation**
- JSON schema validation for all POST/PUT requests
- Input sanitization for security
- Required field verification
- Data type and format validation

### **Response Consistency**
- All responses include standard metadata
- Consistent error format across endpoints
- Proper HTTP status codes
- Request tracking via request_id

### **Security Compliance**
- All endpoints validate authentication where required
- Rate limiting enforced at edge function level
- Input validation prevents injection attacks
- Audit logging for all administrative actions

## **📋 Testing & Documentation**

### **API Testing**
- Automated test suite covering all endpoints
- Load testing for rate limiting validation
- Security testing for injection attempts
- Cross-language compatibility testing

### **Documentation Maintenance**
- OpenAPI 3.0 specification maintained
- Interactive API documentation available
- Postman collection for testing
- SDK documentation for Flutter integration