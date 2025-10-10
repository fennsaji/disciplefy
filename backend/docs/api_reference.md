# Disciplefy Bible Study App - API Reference

## Overview

This document provides comprehensive API documentation for the Disciplefy Bible Study App backend. All endpoints are implemented as Supabase Edge Functions with built-in security validation, rate limiting, and analytics logging.

**Base URL**: `https://wzdcwxvyjuxjgzpnukvm.supabase.co` (Production) or `http://127.0.0.1:54321` (Local Development)

## Authentication

The API supports two authentication modes:
- **Anonymous**: Requires anonymous token
- **Authenticated**: Requires Bearer token from Supabase Auth

### Authentication Header
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

### Rate Limits
- **Anonymous Users**: 3 requests per 8-hour window per session
- **Authenticated Users**: 10 requests per hour per user

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
  "language": "string (optional, default: 'en')"
}
```

**Field Definitions**:
- `input_type`: Type of input - either "scripture" for Bible verses or "topic" for study topics
- `input_value`: The actual scripture reference (e.g., "John 3:16") or topic name (e.g., "Faith")
- `language`: Language code (supported: "en", "hi", "ml")

**Authentication Note**: User context is now automatically determined from the JWT token in the Authorization header for secure authentication.

**Response Body**:
```json
{
  "success": true,
  "data": {
    "study_guide": {
      "id": "string",
      "input": {
        "type": "scripture | topic",
        "value": "string",
        "language": "string"
      },
      "content": {
        "summary": "string",
        "interpretation": "string",
        "context": "string",
        "relatedVerses": ["string"],
        "reflectionQuestions": ["string"],
        "prayerPoints": ["string"]
      },
      "isSaved": "boolean",
      "createdAt": "string (ISO 8601)",
      "updatedAt": "string (ISO 8601)"
    },
    "from_cache": "boolean",
    "cache_stats": {
      "hit_rate": "number",
      "response_time_ms": "number"
    }
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

**Security Notes**:
- **Authentication**: User identity is securely validated via JWT token with signature verification, preventing user impersonation
- **Input Validation**: Includes prompt injection detection and content filtering
- **Rate Limiting**: Enforced based on authenticated user identity using centralized service, preventing bypass attacks
- **Content Caching**: Efficiently caches generated content to reduce API calls
- **Error Handling**: Returns proper error responses if LLM service is unavailable
- **Privacy**: Anonymous users' input is hashed for privacy protection
- **Environment Security**: All environment variables centralized with proper validation

---

### 2. Get Recommended Topics

**Endpoint**: `GET /functions/v1/topics-recommended`

**Description**: Retrieves curated Bible study topics following Jeff Reed's methodology.

**Authentication**: Required (Bearer token from Supabase Auth or anonymous token)

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Query Parameters**:
- `category` (optional): Filter by single topic category (legacy - cannot be used with `categories`)
- `categories` (optional): Filter by multiple topic categories (comma-separated, e.g., "Christian Life,Foundations of Faith")
- `language` (optional): Language code (default: "en")
- `limit` (optional): Number of topics to return (default: 20, max: 100)
- `offset` (optional): Number of topics to skip for pagination (default: 0)

**Example Requests**:

**Single Category (Legacy)**:
```
GET /functions/v1/topics-recommended?category=Christian%20Life&limit=5&offset=0
```

**Multiple Categories (New)**:
```
GET /functions/v1/topics-recommended?categories=Christian%20Life,Foundations%20of%20Faith&limit=10
```

**All Topics**:
```
GET /functions/v1/topics-recommended?language=en&limit=20&offset=0
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
  "error": "INVALID_PARAMETER",
  "message": "Cannot specify both \"category\" and \"categories\" parameters. Use only one.",
  "details": {
    "conflicting_parameters": ["category", "categories"]
  }
}
```

**400 Bad Request** (Invalid Limit):
```json
{
  "success": false,
  "error": "INVALID_PARAMETER",  
  "message": "Limit cannot exceed 100",
  "details": {
    "max_limit": 100
  }
}
```

**Notes**:
- Requires authentication (Bearer token or anonymous token)
- Rate limiting applied per standard rate limits
- **Multi-category filtering**: Use `categories` parameter with comma-separated values
- **Backward compatible**: All existing single-category queries continue to work
- **Cannot mix parameters**: Use either `category` OR `categories`, not both
- Currently supports English language topics only
- Available categories: Apologetics & Defense of Faith, Christian Life, Church & Community, Discipleship & Growth, Family & Relationships, Foundations of Faith, Mission & Service, Spiritual Disciplines

---

### 3. Get Topics Categories

**Endpoint**: `GET /functions/v1/topics-categories`

**Description**: Retrieves all available categories for Bible study topics.

**Authentication**: Required (Bearer token from Supabase Auth or anonymous token)

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Query Parameters**:
- `language` (optional): Language code (default: "en")

**Example Request**:
```
GET /functions/v1/topics-categories?language=en
```

**Response Body**:
```json
{
  "success": true,
  "data": {
    "categories": [
      "Apologetics & Defense of Faith",
      "Christian Life", 
      "Church & Community",
      "Discipleship & Growth",
      "Family & Relationships",
      "Foundations of Faith",
      "Mission & Service",
      "Spiritual Disciplines"
    ],
    "total": 8
  }
}
```

**Error Responses**:

**401 Unauthorized**:
```json
{
  "success": false,
  "error": "UNAUTHORIZED", 
  "message": "Authorization header required"
}
```

**Notes**:
- Requires authentication (Bearer token or anonymous token)
- Currently supports English language categories only
- Useful for building category filter UI components
- Categories are dynamically retrieved from the database
- Rate limiting applied per standard rate limits

---

### 4. Submit Feedback

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

### 5. Google OAuth Callback

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
  "error": "UNAUTHORIZED",
  "message": "Invalid or expired token"
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

### 6. Manage Anonymous Sessions

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

### 7. Daily Verse

**Endpoint**: `GET /functions/v1/daily-verse`

**Description**: Retrieves the daily Bible verse with multiple language translations using AI-powered verse generation.

**Authentication**: Required (Bearer token from Supabase Auth or anonymous token)

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Query Parameters**:
- `date` (optional): Specific date for verse in YYYY-MM-DD format (default: today)

**Example Request**:
```
GET /functions/v1/daily-verse?date=2025-07-20
```

**Response Body**:
```json
{
  "success": true,
  "data": {
    "reference": "string (e.g., 'John 3:16')",
    "date": "string (YYYY-MM-DD)",
    "translations": {
      "esv": "string (English Standard Version)",
      "hindi": "string (Hindi translation)",
      "malayalam": "string (Malayalam translation)"
    },
    "fromCache": "boolean",
    "timestamp": "string (ISO 8601)"
  }
}
```

**Error Responses**:

**400 Bad Request**:
```json
{
  "success": false,
  "error": "VALIDATION_ERROR",
  "message": "Invalid date format. Please use YYYY-MM-DD."
}
```

**502 Bad Gateway**:
```json
{
  "success": false,
  "error": "LLM_SERVICE_ERROR",
  "message": "Unable to generate daily verse content"
}
```

**Notes**:
- Uses LLM-powered verse generation with anti-repetition logic
- Automatically excludes recently used verses (past 30 days)
- Supports caching for improved performance
- Requires authentication (Bearer token or anonymous token)
- Analytics logging tracks verse access patterns
- Fallback system ensures verse availability even if LLM fails

---

### 8. Manage Study Guides

**Endpoint**: `GET /functions/v1/study-guides` and `POST /functions/v1/study-guides`

**Description**: Retrieve, save, and manage user study guides with support for both authenticated and anonymous users.

**Authentication**: Required for saving/unsaving guides, optional for retrieval

#### 8.1 Get Study Guides

**Method**: `GET /functions/v1/study-guides`

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN (required for authenticated users)
```

**Query Parameters**:
- `saved` (optional): If "true", returns only saved guides
- `limit` (optional): Number of guides to return (default: 20, max: 100)
- `offset` (optional): Number of guides to skip for pagination (default: 0)

**Example Request**:
```
GET /functions/v1/study-guides?saved=true&limit=10&offset=0
```

**Response Body**:
```json
{
  "success": true,
  "data": {
    "guides": [
      {
        "id": "string",
        "input_type": "scripture | topic",
        "input_value": "string (for authenticated users)",
        "input_value_hash": "string (for anonymous users)",
        "summary": "string",
        "interpretation": "string",
        "context": "string",
        "related_verses": ["string"],
        "reflection_questions": ["string"],
        "prayer_points": ["string"],
        "language": "string",
        "is_saved": "boolean",
        "created_at": "string (ISO 8601)",
        "updated_at": "string (ISO 8601)"
      }
    ],
    "total": "number",
    "hasMore": "boolean"
  }
}
```

#### 8.2 Save/Unsave Study Guide

**Method**: `POST /functions/v1/study-guides`

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN (required)
```

**Request Body**:
```json
{
  "guide_id": "string (required)",
  "action": "save | unsave (required)"
}
```

**Field Definitions**:
- `guide_id`: UUID of the study guide to save/unsave
- `action`: Either "save" to mark as saved or "unsave" to remove saved status

**Response Body**:
```json
{
  "success": true,
  "message": "Guide saved successfully",
  "data": {
    "guide": {
      "id": "string",
      "input_type": "scripture | topic",
      "input_value": "string",
      "summary": "string",
      "interpretation": "string",
      "context": "string",
      "related_verses": ["string"],
      "reflection_questions": ["string"],
      "prayer_points": ["string"],
      "language": "string",
      "is_saved": "boolean",
      "created_at": "string (ISO 8601)",
      "updated_at": "string (ISO 8601)"
    }
  }
}
```

**Error Responses**:

**401 Unauthorized** (Save/Unsave only):
```json
{
  "success": false,
  "error": "UNAUTHORIZED",
  "message": "Authentication required to save guides"
}
```

**404 Not Found**:
```json
{
  "success": false,
  "error": "NOT_FOUND",
  "message": "Study guide not found or you do not have permission to modify it"
}
```

**400 Bad Request**:
```json
{
  "success": false,
  "error": "INVALID_REQUEST",
  "message": "guide_id and action are required"
}
```

**Notes**:
- GET requests work for both authenticated and anonymous users
- Anonymous users see guides from their session only
- Authenticated users can save/unsave guides and see all their guides
- Supports pagination for large result sets
- Filters ensure users only see their own data
- Input validation prevents access to other users' guides

---

### 9. FCM Token Registration & Notification Preferences

**Endpoint**: `GET/POST/PUT/DELETE /functions/v1/register-fcm-token`

**Description**: Manages Firebase Cloud Messaging (FCM) tokens and user notification preferences for push notifications.

**Authentication**: Required (Bearer token from Supabase Auth)

#### 9.1 Get Notification Preferences

**Method**: `GET /functions/v1/register-fcm-token`

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response Body**:
```json
{
  "success": true,
  "data": {
    "preferences": {
      "user_id": "string",
      "daily_verse_enabled": "boolean",
      "recommended_topic_enabled": "boolean",
      "created_at": "string (ISO 8601)",
      "updated_at": "string (ISO 8601)"
    },
    "token_registered": "boolean"
  }
}
```

#### 9.2 Register FCM Token

**Method**: `POST /functions/v1/register-fcm-token`

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Request Body**:
```json
{
  "fcmToken": "string (required)",
  "platform": "string (required: 'ios' | 'android' | 'web')",
  "timezoneOffsetMinutes": "number (required)"
}
```

**Field Definitions**:
- `fcmToken`: Firebase Cloud Messaging token from device
- `platform`: Device platform (ios, android, or web)
- `timezoneOffsetMinutes`: User's timezone offset in minutes (e.g., 330 for IST, -300 for EST)

**Response Body**:
```json
{
  "success": true,
  "message": "FCM token registered successfully",
  "data": {
    "token_id": "string",
    "user_id": "string",
    "platform": "string",
    "registered_at": "string (ISO 8601)"
  }
}
```

#### 9.3 Update Notification Preferences

**Method**: `PUT /functions/v1/register-fcm-token`

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Request Body**:
```json
{
  "dailyVerseEnabled": "boolean (optional)",
  "recommendedTopicEnabled": "boolean (optional)"
}
```

**Field Definitions**:
- `dailyVerseEnabled`: Enable/disable daily verse notifications (6 AM local time)
- `recommendedTopicEnabled`: Enable/disable recommended topic notifications (8 AM local time)

**Response Body**:
```json
{
  "success": true,
  "message": "Preferences updated successfully",
  "data": {
    "preferences": {
      "user_id": "string",
      "daily_verse_enabled": "boolean",
      "recommended_topic_enabled": "boolean",
      "updated_at": "string (ISO 8601)"
    }
  }
}
```

#### 9.4 Unregister FCM Token

**Method**: `DELETE /functions/v1/register-fcm-token`

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Request Body**:
```json
{
  "fcmToken": "string (optional - if not provided, deletes all user's tokens)"
}
```

**Response Body**:
```json
{
  "success": true,
  "message": "FCM token unregistered successfully",
  "data": {
    "deleted_tokens": "number"
  }
}
```

**Error Responses**:

**401 Unauthorized**:
```json
{
  "success": false,
  "error": "UNAUTHORIZED",
  "message": "Authentication required"
}
```

**400 Bad Request**:
```json
{
  "success": false,
  "error": "INVALID_REQUEST",
  "message": "fcmToken, platform, and timezoneOffsetMinutes are required"
}
```

**500 Internal Server Error**:
```json
{
  "success": false,
  "error": "REGISTRATION_FAILED",
  "message": "Failed to register FCM token"
}
```

**Notes**:
- FCM tokens are automatically refreshed when devices update them
- Platform detection ensures proper notification delivery
- Timezone offset enables accurate local time delivery (6 AM, 8 AM)
- Duplicate tokens are handled gracefully (upsert logic)
- User can have multiple tokens (different devices)
- Preferences default to enabled for new users
- Tokens are automatically cleaned up after 90 days of inactivity

---

### 10. Send Daily Verse Notification (Service Role Only)

**Endpoint**: `POST /functions/v1/send-daily-verse-notification`

**Description**: Triggers batch delivery of daily verse notifications to all eligible users based on their timezone and preferences.

**Authentication**: Required (Service Role Key only)

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer SUPABASE_SERVICE_ROLE_KEY
```

**Request Body**: None required

**Response Body**:
```json
{
  "success": true,
  "message": "Daily verse notifications sent successfully",
  "data": {
    "notificationsSent": "number",
    "totalUsers": "number",
    "failedTokens": "number",
    "verse": {
      "reference": "string (e.g., 'Philippians 4:13')",
      "text": "string",
      "translation": "string"
    },
    "executionTime": "number (milliseconds)"
  }
}
```

**Error Responses**:

**401 Unauthorized**:
```json
{
  "success": false,
  "error": "UNAUTHORIZED",
  "message": "Service role authorization required"
}
```

**502 Bad Gateway**:
```json
{
  "success": false,
  "error": "FIREBASE_ERROR",
  "message": "Failed to send notifications via Firebase Cloud Messaging"
}
```

**500 Internal Server Error**:
```json
{
  "success": false,
  "error": "INTERNAL_ERROR",
  "message": "Failed to process notification batch"
}
```

**Notes**:
- **Scheduled Execution**: Automatically triggered via GitHub Actions at 6 AM across 8 timezone windows
- **User Filtering**: Only sends to users with `daily_verse_enabled = true`
- **Timezone-Aware**: Queries users by `timezone_offset_minutes` for accurate local delivery
- **Batch Processing**: Sends up to 500 tokens per FCM batch request
- **Deep Linking**: Notification includes `type: 'daily_verse'` for proper app navigation
- **Logging**: Records delivery status in `notification_logs` table
- **Verse Selection**: Uses daily-verse API with anti-repetition logic
- **Error Handling**: Invalid tokens are automatically removed from database

**GitHub Actions Trigger**:
```bash
# Manual trigger via GitHub Actions
gh workflow run send-notifications.yml --field notification_type=daily_verse

# Or trigger locally for testing
curl -X POST "http://127.0.0.1:54321/functions/v1/send-daily-verse-notification" \
  -H "Authorization: Bearer SERVICE_ROLE_KEY"
```

---

### 11. Send Recommended Topic Notification (Service Role Only)

**Endpoint**: `POST /functions/v1/send-recommended-topic-notification`

**Description**: Triggers batch delivery of personalized study topic recommendations to all eligible users based on their timezone and preferences.

**Authentication**: Required (Service Role Key only)

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer SUPABASE_SERVICE_ROLE_KEY
```

**Request Body**: None required

**Response Body**:
```json
{
  "success": true,
  "message": "Recommended topic notifications sent successfully",
  "data": {
    "notificationsSent": "number",
    "totalUsers": "number",
    "failedTokens": "number",
    "topic": {
      "id": "string",
      "title": "string",
      "description": "string",
      "category": "string"
    },
    "executionTime": "number (milliseconds)"
  }
}
```

**Error Responses**:

**401 Unauthorized**:
```json
{
  "success": false,
  "error": "UNAUTHORIZED",
  "message": "Service role authorization required"
}
```

**502 Bad Gateway**:
```json
{
  "success": false,
  "error": "FIREBASE_ERROR",
  "message": "Failed to send notifications via Firebase Cloud Messaging"
}
```

**500 Internal Server Error**:
```json
{
  "success": false,
  "error": "INTERNAL_ERROR",
  "message": "Failed to process notification batch"
}
```

**Notes**:
- **Scheduled Execution**: Automatically triggered via GitHub Actions at 8 AM across 8 timezone windows
- **User Filtering**: Only sends to users with `recommended_topic_enabled = true`
- **Timezone-Aware**: Queries users by `timezone_offset_minutes` for accurate local delivery
- **Batch Processing**: Sends up to 500 tokens per FCM batch request
- **Personalization**: Selects topics based on user's study history and preferences
- **Deep Linking**: Notification includes `type: 'recommended_topic'` and `topic_id` for navigation
- **Logging**: Records delivery status in `notification_logs` table
- **Topic Selection**: Uses topics-recommended API with smart recommendation logic
- **Error Handling**: Invalid tokens are automatically removed from database

**GitHub Actions Trigger**:
```bash
# Manual trigger via GitHub Actions
gh workflow run send-notifications.yml --field notification_type=recommended_topic

# Or trigger locally for testing
curl -X POST "http://127.0.0.1:54321/functions/v1/send-recommended-topic-notification" \
  -H "Authorization: Bearer SERVICE_ROLE_KEY"
```

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
- Anonymous users: 3 requests per 8-hour window per session
- Authenticated users: 10 requests per hour per user
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
// Generate study guide
const { data, error } = await supabase.functions.invoke('study-generate', {
  body: {
    input_type: 'scripture',
    input_value: 'John 3:16',
    language: 'en'
  }
});

// Access the generated study guide
const studyGuide = data.study_guide;
const content = studyGuide.content;

// Get all topic categories
const { data: categoriesData } = await supabase.functions.invoke('topics-categories');
const categories = categoriesData.categories;

// Get recommended topics (single category)
const { data: topicsData } = await supabase.functions.invoke('topics-recommended', {
  method: 'GET'
}, {
  query: { category: 'Christian Life', limit: '10' }
});

// Get recommended topics (multiple categories)  
const { data: multiTopicsData } = await supabase.functions.invoke('topics-recommended', {
  method: 'GET'
}, {
  query: { categories: 'Christian Life,Foundations of Faith', limit: '10' }
});

// Get saved study guides
const { data: guides } = await supabase.functions.invoke('study-guides', {
  body: {},
  method: 'GET'
});

// Save a study guide
const { data: savedGuide } = await supabase.functions.invoke('study-guides', {
  body: {
    guide_id: 'guide-uuid',
    action: 'save'
  }
});

// Register FCM token for push notifications
const { data: tokenData } = await supabase.functions.invoke('register-fcm-token', {
  body: {
    fcmToken: 'device-fcm-token-here',
    platform: 'web',
    timezoneOffsetMinutes: new Date().getTimezoneOffset() * -1
  }
});

// Get notification preferences
const { data: prefsData } = await supabase.functions.invoke('register-fcm-token', {
  method: 'GET'
});

// Update notification preferences
const { data: updatedPrefs } = await supabase.functions.invoke('register-fcm-token', {
  body: {
    dailyVerseEnabled: true,
    recommendedTopicEnabled: false
  },
  method: 'PUT'
});

// Trigger daily verse notification (service role only)
const { data: notificationResult } = await supabase.functions.invoke('send-daily-verse-notification', {
  method: 'POST'
});
```

### Flutter/Dart
```dart
// Generate study guide
final response = await Supabase.instance.client.functions.invoke(
  'study-generate',
  body: {
    'input_type': 'scripture',
    'input_value': 'John 3:16',
    'language': 'en'
  },
);

// Access the generated study guide
final studyGuide = response.data['study_guide'];
final content = studyGuide['content'];

// Get all topic categories
final categoriesResponse = await Supabase.instance.client.functions.invoke(
  'topics-categories',
  queryParameters: {'language': 'en'},
);
final categories = categoriesResponse.data['categories'];

// Get recommended topics (single category)
final topicsResponse = await Supabase.instance.client.functions.invoke(
  'topics-recommended',
  queryParameters: {
    'category': 'Christian Life',
    'limit': '10'
  },
);

// Get recommended topics (multiple categories)
final multiTopicsResponse = await Supabase.instance.client.functions.invoke(
  'topics-recommended', 
  queryParameters: {
    'categories': 'Christian Life,Foundations of Faith',
    'limit': '10'
  },
);

// Get saved study guides
final guidesResponse = await Supabase.instance.client.functions.invoke(
  'study-guides',
  headers: {'Content-Type': 'application/json'},
  queryParameters: {'saved': 'true', 'limit': '10'},
);

// Save a study guide
final saveResponse = await Supabase.instance.client.functions.invoke(
  'study-guides',
  body: {
    'guide_id': 'guide-uuid',
    'action': 'save'
  },
);

// Register FCM token for push notifications
final timezoneOffset = DateTime.now().timeZoneOffset.inMinutes;
final tokenResponse = await Supabase.instance.client.functions.invoke(
  'register-fcm-token',
  body: {
    'fcmToken': fcmToken,
    'platform': Platform.isIOS ? 'ios' : 'android',
    'timezoneOffsetMinutes': timezoneOffset,
  },
);

// Get notification preferences
final prefsResponse = await Supabase.instance.client.functions.invoke(
  'register-fcm-token',
  method: HttpMethod.get,
);
final preferences = prefsResponse.data['preferences'];

// Update notification preferences
final updateResponse = await Supabase.instance.client.functions.invoke(
  'register-fcm-token',
  method: HttpMethod.put,
  body: {
    'dailyVerseEnabled': true,
    'recommendedTopicEnabled': false,
  },
);
```

### Direct HTTP
```bash
# Generate study guide (authenticated)
curl -X POST "https://your-project.supabase.co/functions/v1/study-generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "input_type": "scripture",
    "input_value": "John 3:16",
    "language": "en"
  }'

# Generate study guide (anonymous)
curl -X POST "https://your-project.supabase.co/functions/v1/study-generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "input_type": "scripture",
    "input_value": "John 3:16",
    "language": "en"
  }'

# Get all topic categories
curl -X GET "https://your-project.supabase.co/functions/v1/topics-categories?language=en" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Get recommended topics (single category)
curl -X GET "https://your-project.supabase.co/functions/v1/topics-recommended?category=Christian%20Life&limit=10" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Get recommended topics (multiple categories)  
curl -X GET "https://your-project.supabase.co/functions/v1/topics-recommended?categories=Christian%20Life,Foundations%20of%20Faith&limit=10" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Get saved study guides
curl -X GET "https://your-project.supabase.co/functions/v1/study-guides?saved=true&limit=10" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Save a study guide
curl -X POST "https://your-project.supabase.co/functions/v1/study-guides" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "guide_id": "guide-uuid",
    "action": "save"
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
Required environment variables (centrally managed in `config.ts`):
- `SUPABASE_URL`: Supabase project URL
- `SUPABASE_ANON_KEY`: Supabase anonymous key for JWT validation
- `SUPABASE_SERVICE_ROLE_KEY`: Supabase service role key for database operations
- `OPENAI_API_KEY`: OpenAI API key for LLM services
- `ANTHROPIC_API_KEY`: Anthropic API key for LLM services
- `LLM_PROVIDER`: Primary LLM provider ('openai' or 'anthropic')
- `USE_MOCK`: Enable mock mode for testing ('true' or 'false')
- `FIREBASE_PROJECT_ID`: Firebase project ID for push notifications
- `FIREBASE_CLIENT_EMAIL`: Firebase service account email
- `FIREBASE_PRIVATE_KEY`: Firebase service account private key (PEM format)

### Monitoring
All endpoints include comprehensive logging:
- Request/response analytics
- Security event monitoring
- Error tracking and alerting
- Performance metrics

---

**Last Updated**: October 2025
**API Version**: 1.5
**Support**: support@disciplefy.in

## Security Changelog

### Version 1.5 (October 2025)
- **NEW FEATURE**: Added `/register-fcm-token` endpoint for Firebase Cloud Messaging token management
- **NEW FEATURE**: Added push notification preference management (GET, POST, PUT, DELETE methods)
- **NEW FEATURE**: Added `/send-daily-verse-notification` service endpoint for automated daily verse delivery
- **NEW FEATURE**: Added `/send-recommended-topic-notification` service endpoint for personalized topic recommendations
- **INTEGRATION**: Implemented Firebase Admin SDK integration with secure credential management
- **AUTOMATION**: Added GitHub Actions workflow for scheduled notification delivery (8 timezone windows)
- **ENHANCEMENT**: Timezone-aware notification delivery at 6 AM (daily verse) and 8 AM (topics)
- **ENHANCEMENT**: Batch notification processing with FCM (up to 500 tokens per batch)
- **SECURITY**: Service-role-only authentication for notification trigger endpoints
- **DATABASE**: Added notification_logs table for delivery tracking and analytics
- **DATABASE**: Added user_fcm_tokens table with platform and timezone tracking
- **DATABASE**: Added notification_preferences table with per-user settings
- **PRIVACY**: Automatic token cleanup after 90 days of inactivity

### Version 1.4 (August 2025)
- **NEW FEATURE**: Added `/topics-categories` endpoint for retrieving all available Bible study topic categories
- **ENHANCEMENT**: Enhanced `/topics-recommended` endpoint with multi-category filtering via `categories` parameter
- **IMPROVEMENT**: Added support for comma-separated category filtering (e.g., "Christian Life,Foundations of Faith")
- **BACKWARD COMPATIBILITY**: Maintained full backward compatibility for existing single-category queries
- **VALIDATION**: Added parameter validation to prevent using both `category` and `categories` parameters
- **DATABASE**: Added PostgreSQL functions for efficient multi-category filtering with proper security
- **PERFORMANCE**: Optimized category queries using array operations and database indexing

### Version 1.3 (July 2025)
- **NEW FEATURE**: Added `/daily-verse` endpoint with LLM-powered verse generation
- **SECURITY FIX**: Centralized all environment variable access to prevent scattered dependencies
- **SECURITY FIX**: Implemented dependency injection throughout codebase for better security
- **IMPROVEMENT**: Enhanced CSRF protection with constant-time comparison
- **IMPROVEMENT**: Added anonymous session migration with data preservation
- **IMPROVEMENT**: Implemented anti-repetition logic for daily verses
- **IMPROVEMENT**: Enhanced service container with proper singleton patterns

### Version 1.2 (July 2025)
- **BREAKING CHANGE**: Removed `user_context` parameter from study-generate endpoint
- **SECURITY FIX**: Implemented secure JWT validation to prevent user impersonation
- **IMPROVEMENT**: Enhanced rate limiting based on authenticated user identity
- **IMPROVEMENT**: Added comprehensive environment variable validation
- **IMPROVEMENT**: Optimized service instantiation for better performance
- **IMPROVEMENT**: Enhanced error handling and type safety