# Disciplefy Bible Study App - API Reference

## Overview

This document provides comprehensive API documentation for the Disciplefy Bible Study App backend. All endpoints are implemented as Supabase Edge Functions with built-in security validation, rate limiting, and analytics logging.

**Base URL**: `https://wzdcwxvyjuxjgzpnukvm.supabase.co` (Production) or `http://127.0.0.1:54321` (Local Development)

## Authentication

The API supports two authentication modes:
- **Anonymous**: No authentication required, limited features
- **Authenticated**: Requires Bearer token from Supabase Auth

### Authentication Header
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

### Rate Limits
- **Anonymous Users**: 3 requests per hour per IP
- **Authenticated Users**: 30 requests per hour per user

---

## Endpoints

### 1. Generate Study Guide

**Endpoint**: `POST /functions/v1/study-generate`

**Description**: Generates AI-powered Bible study guides from scripture references or topics.

**Authentication**: Optional (supports both anonymous and authenticated users)

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN (optional)
```

**Request Body**:
```json
{
  "input_type": "scripture | topic",
  "input_value": "string (required)",
  "language": "string (optional, default: 'en')",
  "user_context": {
    "is_authenticated": "boolean",
    "user_id": "string (optional)",
    "session_id": "string (optional for anonymous)"
  }
}
```

**Field Definitions**:
- `input_type`: Type of input - either "scripture" for Bible verses or "topic" for study topics
- `input_value`: The actual scripture reference (e.g., "John 3:16") or topic name (e.g., "Faith")
- `language`: Language code (supported: "en", "hi", "ml")
- `user_context`: Context information for personalization and storage

**Response Body**:
```json
{
  "success": true,
  "data": {
    "id": "string",
    "summary": "string",
    "interpretation": "string",
    "context": "string",
    "related_verses": ["string"],
    "reflection_questions": ["string"],
    "prayer_points": ["string"],
    "language": "string",
    "created_at": "string (ISO 8601)"
  },
  "rate_limit": {
    "remaining": "number",
    "reset_time": "number (minutes)"
  }
}
```

**Error Responses**:

**400 Bad Request**:
```json
{
  "success": false,
  "error": "INVALID_REQUEST",
  "message": "input_type must be 'scripture' or 'topic'",
  "details": {
    "field": "input_type",
    "provided": "invalid_value"
  }
}
```

**429 Too Many Requests**:
```json
{
  "success": false,
  "error": "RATE_LIMITED",
  "message": "Rate limit exceeded. Try again in 45 minutes.",
  "details": {
    "retry_after": 2700,
    "limit": 3,
    "window": "1 hour"
  }
}
```

**500 Internal Server Error**:
```json
{
  "success": false,
  "error": "GENERATION_FAILED",
  "message": "Failed to generate study guide. Please try again.",
  "request_id": "uuid"
}
```

**Notes**:
- Includes prompt injection detection and content filtering
- Falls back to mock data if LLM service is unavailable
- Anonymous users' input is hashed for privacy
- Authenticated users' studies are saved to their account

---

### 2. Get Recommended Topics

**Endpoint**: `GET /functions/v1/topics-recommended`

**Description**: Retrieves curated Bible study topics following Jeff Reed's methodology.

**Authentication**: Not required (public endpoint)

**Request Headers**:
```
Content-Type: application/json
```

**Query Parameters**:
- `category` (optional): Filter by topic category
- `difficulty` (optional): Filter by difficulty level ("beginner", "intermediate", "advanced")
- `limit` (optional): Number of topics to return (default: 10, max: 50)
- `offset` (optional): Number of topics to skip for pagination (default: 0)

**Example Request**:
```
GET /functions/v1/topics-recommended?category=Bible%20Study%20Methods&difficulty=beginner&limit=5&offset=0
```

**Response Body**:
```json
{
  "success": true,
  "data": {
    "topics": [
      {
        "id": "string",
        "title": "string",
        "description": "string",
        "difficulty_level": "beginner | intermediate | advanced",
        "estimated_duration": "string",
        "key_verses": ["string"],
        "category": "string",
        "tags": ["string"],
        "created_at": "string (ISO 8601)"
      }
    ],
    "categories": ["string"],
    "total": "number",
    "pagination": {
      "limit": "number",
      "offset": "number",
      "has_more": "boolean"
    }
  }
}
```

**Error Responses**:

**400 Bad Request**:
```json
{
  "success": false,
  "error": "INVALID_PARAMETERS",
  "message": "Invalid difficulty level. Must be: beginner, intermediate, or advanced",
  "details": {
    "valid_values": ["beginner", "intermediate", "advanced"]
  }
}
```

**Notes**:
- No authentication required
- No rate limiting applied
- Currently supports 15 predefined topics in English
- Categories include: Bible Study Methods, Group Leadership, Spiritual Disciplines, etc.

---

### 3. Submit Feedback

**Endpoint**: `POST /functions/v1/feedback`

**Description**: Collects user feedback on study guides and app experience.

**Authentication**: Optional (supports both anonymous and authenticated users)

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN (optional)
```

**Request Body**:
```json
{
  "study_guide_id": "string (optional)",
  "jeff_reed_session_id": "string (optional)",
  "was_helpful": "boolean (required)",
  "message": "string (optional)",
  "category": "string (optional)",
  "user_context": {
    "is_authenticated": "boolean",
    "user_id": "string (optional)",
    "session_id": "string (optional)"
  }
}
```

**Field Definitions**:
- `study_guide_id`: ID of the study guide being reviewed (if applicable)
- `jeff_reed_session_id`: ID of the Jeff Reed session being reviewed (if applicable)
- `was_helpful`: Whether the content was helpful to the user
- `message`: Free-form feedback text
- `category`: Feedback category ("general", "content", "usability", "technical", "suggestion")
- `user_context`: User identification and context

**Response Body**:
```json
{
  "success": true,
  "data": {
    "feedback_id": "string",
    "sentiment_score": "number (-1 to 1)",
    "created_at": "string (ISO 8601)",
    "message": "Feedback submitted successfully"
  }
}
```

**Error Responses**:

**400 Bad Request**:
```json
{
  "success": false,
  "error": "INVALID_REQUEST",
  "message": "was_helpful field is required",
  "details": {
    "required_fields": ["was_helpful"]
  }
}
```

**404 Not Found**:
```json
{
  "success": false,
  "error": "RESOURCE_NOT_FOUND",
  "message": "Study guide not found",
  "details": {
    "study_guide_id": "provided_id"
  }
}
```

**Notes**:
- Feedback content is sanitized for security
- Sentiment analysis is performed on feedback text
- Resource verification ensures referenced study guides exist
- Anonymous feedback is allowed for general categories only

---

### 4. Google OAuth Callback

**Endpoint**: `POST /functions/v1/auth-google-callback`

**Description**: Handles Google OAuth callback and creates authenticated sessions.

**Authentication**: Not required (handles authentication creation)

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer SUPABASE_ANON_KEY
X-Anonymous-Session-ID: session_id (optional, for migration)
```

**Request Body**:
```json
{
  "code": "string (required if no error)",
  "state": "string (optional, for CSRF protection)",
  "error": "string (optional, OAuth error)",
  "error_description": "string (optional)"
}
```

**Field Definitions**:
- `code`: Authorization code from Google OAuth
- `state`: CSRF protection state parameter
- `error`: OAuth error code if authentication failed
- `error_description`: Detailed error description

**Response Body**:
```json
{
  "success": true,
  "session": {
    "access_token": "string",
    "refresh_token": "string",
    "expires_in": "number (seconds)",
    "user": {
      "id": "string",
      "email": "string",
      "email_verified": "boolean",
      "name": "string",
      "picture": "string",
      "provider": "google"
    }
  },
  "redirect_url": "string"
}
```

**Error Responses**:

**400 Bad Request**:
```json
{
  "success": false,
  "error": "INVALID_REQUEST",
  "message": "Either code or error parameter is required"
}
```

**401 Unauthorized**:
```json
{
  "success": false,
  "error": "OAUTH_EXCHANGE_FAILED",
  "message": "Failed to exchange authorization code for tokens",
  "details": {
    "oauth_error": "invalid_grant"
  }
}
```

**403 Forbidden**:
```json
{
  "success": false,
  "error": "CSRF_VALIDATION_FAILED",
  "message": "Invalid state parameter"
}
```

**429 Too Many Requests**:
```json
{
  "success": false,
  "error": "RATE_LIMITED",
  "message": "Too many OAuth attempts. Try again later.",
  "details": {
    "retry_after": 1800
  }
}
```

**Notes**:
- Validates CSRF state parameter for security
- Automatically migrates anonymous sessions to authenticated accounts
- Logs all OAuth events for security monitoring
- Rate limited to 30 attempts per hour per IP
- Determines redirect URL based on request origin

---

### 5. Manage Anonymous Sessions

**Endpoint**: `POST /functions/v1/auth-session`

**Description**: Creates and manages anonymous user sessions.

**Authentication**: Required for migration, not for creation

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer SUPABASE_ANON_KEY (creation) or Bearer USER_ACCESS_TOKEN (migration)
```

**Request Body**:

**Create Anonymous Session**:
```json
{
  "action": "create_anonymous",
  "device_fingerprint": "string (optional)"
}
```

**Migrate Anonymous Session**:
```json
{
  "action": "migrate_to_authenticated",
  "anonymous_session_id": "string (required)"
}
```

**Field Definitions**:
- `action`: Action to perform ("create_anonymous" or "migrate_to_authenticated")
- `device_fingerprint`: Device identification for session tracking (hashed for privacy)
- `anonymous_session_id`: UUID of the anonymous session to migrate

**Response Body**:

**Create Anonymous Session**:
```json
{
  "success": true,
  "data": {
    "session_id": "string (UUID)",
    "expires_at": "string (ISO 8601, 24 hours)",
    "is_anonymous": true
  }
}
```

**Migrate Anonymous Session**:
```json
{
  "success": true,
  "data": {
    "session_id": "string (user ID)",
    "expires_at": "string (ISO 8601)",
    "is_anonymous": false,
    "migration_successful": true
  }
}
```

**Error Responses**:

**400 Bad Request**:
```json
{
  "success": false,
  "error": "INVALID_REQUEST",
  "message": "action field is required"
}
```

**401 Unauthorized**:
```json
{
  "success": false,
  "error": "UNAUTHORIZED",
  "message": "User must be authenticated to migrate session"
}
```

**404 Not Found**:
```json
{
  "success": false,
  "error": "NOT_FOUND",
  "message": "Anonymous session not found"
}
```

**410 Gone**:
```json
{
  "success": false,
  "error": "SESSION_EXPIRED",
  "message": "Anonymous session has expired"
}
```

**Notes**:
- Anonymous sessions expire after 24 hours
- Device fingerprints are hashed for privacy
- Migration preserves study guides and preferences
- Session IDs are UUIDs for security
- Rate limited to 30 anonymous sessions per hour per IP

---

## Common Response Patterns

### Success Response Structure
```json
{
  "success": true,
  "data": {
    // Endpoint-specific data
  }
}
```

### Error Response Structure
```json
{
  "success": false,
  "error": "ERROR_CODE",
  "message": "Human-readable error message",
  "details": {
    // Additional error context
  },
  "request_id": "string (optional)"
}
```

### Rate Limit Headers
All authenticated endpoints include rate limit information:
```
X-RateLimit-Limit: 30
X-RateLimit-Remaining: 29
X-RateLimit-Reset: 1609459200
```

## Security Features

### Input Validation
- All inputs are validated and sanitized
- Custom validation rules for biblical references
- Prompt injection detection for LLM inputs
- XSS prevention for user content

### Rate Limiting
- Anonymous users: 3 requests/hour per IP
- Authenticated users: 30 requests/hour per user
- OAuth callbacks: 30 attempts/hour per IP

### Privacy Protection
- Device fingerprints are hashed with SHA-256
- Anonymous user inputs are hashed for privacy
- No sensitive data in analytics logging
- Session tokens follow JWT standards

### CORS Support
All endpoints support cross-origin requests with proper headers:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: authorization, x-client-info, apikey, content-type
```

## Error Codes Reference

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `INVALID_REQUEST` | 400 | Malformed request or missing required fields |
| `UNAUTHORIZED` | 401 | Authentication required or invalid token |
| `FORBIDDEN` | 403 | Request forbidden (e.g., CSRF failure) |
| `NOT_FOUND` | 404 | Resource not found |
| `METHOD_NOT_ALLOWED` | 405 | HTTP method not supported |
| `SESSION_EXPIRED` | 410 | Session has expired |
| `RATE_LIMITED` | 429 | Rate limit exceeded |
| `VALIDATION_ERROR` | 422 | Input validation failed |
| `INTERNAL_ERROR` | 500 | Server error |
| `LLM_SERVICE_ERROR` | 502 | LLM service unavailable |
| `DATABASE_ERROR` | 503 | Database connection error |

## SDKs and Integration

### JavaScript/TypeScript
```typescript
// Using Supabase client
const { data, error } = await supabase.functions.invoke('study-generate', {
  body: {
    input_type: 'scripture',
    input_value: 'John 3:16',
    language: 'en'
  }
});
```

### Flutter/Dart
```dart
// Using Supabase Flutter client
final response = await Supabase.instance.client.functions.invoke(
  'study-generate',
  body: {
    'input_type': 'scripture',
    'input_value': 'John 3:16',
    'language': 'en'
  },
);
```

### Direct HTTP
```bash
curl -X POST "https://your-project.supabase.co/functions/v1/study-generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "input_type": "scripture",
    "input_value": "John 3:16",
    "language": "en"
  }'
```

## Development and Testing

### Local Development
```bash
# Start local Supabase
supabase start

# Deploy functions
supabase functions deploy

# Test endpoints
./test_auth_flows.sh
```

### Environment Variables
Required environment variables:
- `SUPABASE_URL`: Supabase project URL
- `SUPABASE_ANON_KEY`: Supabase anonymous key
- `GOOGLE_OAUTH_CLIENT_ID`: Google OAuth client ID
- `GOOGLE_OAUTH_CLIENT_SECRET`: Google OAuth client secret

### Monitoring
All endpoints include comprehensive logging:
- Request/response analytics
- Security event monitoring
- Error tracking and alerting
- Performance metrics

---

**Last Updated**: January 2025  
**API Version**: 1.0  
**Support**: support@disciplefy.com