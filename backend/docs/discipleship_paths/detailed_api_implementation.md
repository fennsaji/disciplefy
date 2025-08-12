# Disciplefy Detailed API Implementation

## Overview
This document provides detailed implementation specifications for all Disciplefy APIs, including request/response schemas, validation rules, and business logic.

---

## 👤 User APIs

### GET `/users/me`
**Description:** Get the current user's profile information.

**Authentication:** Required

**Request:**
```http
GET /users/me
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "John Doe",
    "role": "member",
    "photo_url": "https://example.com/photo.jpg",
    "created_at": "2024-01-01T00:00:00Z",
    "fellowships": [
      {
        "id": "uuid",
        "name": "Morning Bible Study",
        "role": "member"
      }
    ],
    "active_paths": [
      {
        "path_id": "uuid",
        "path_title": "Foundations of Faith",
        "completed_lessons": 3,
        "total_lessons": 12
      }
    ]
  }
}
```

### PATCH `/users/me`
**Description:** Update the current user's profile information.

**Authentication:** Required

**Request:**
```http
PATCH /users/me
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "name": "John Doe Updated",
  "photo_url": "https://example.com/new-photo.jpg"
}
```

**Validation Rules:**
- `name`: Required, 2-50 characters, alphanumeric + spaces
- `photo_url`: Optional, valid URL format

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "John Doe Updated",
    "role": "member",
    "photo_url": "https://example.com/new-photo.jpg",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

---

## 🧑‍🤝‍🧑 Fellowship APIs

### POST `/fellowships`
**Description:** Create a new fellowship (Mentor only).

**Authentication:** Required (Mentor role)

**Request:**
```http
POST /fellowships
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "name": "Morning Bible Study Group",
  "description": "A group for daily morning Bible study and prayer"
}
```

**Validation Rules:**
- `name`: Required, 3-100 characters
- `description`: Optional, max 500 characters

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "Morning Bible Study Group",
    "description": "A group for daily morning Bible study and prayer",
    "mentor_id": "uuid",
    "mentor_name": "John Doe",
    "member_count": 1,
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

### GET `/fellowships`
**Description:** Get all fellowships the current user belongs to.

**Authentication:** Required

**Query Parameters:**
- `role`: Filter by role (mentor, member)
- `active`: Filter active/inactive fellowships (boolean)

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "name": "Morning Bible Study Group",
      "description": "A group for daily morning Bible study and prayer",
      "mentor_id": "uuid",
      "mentor_name": "John Doe",
      "member_count": 5,
      "user_role": "mentor",
      "created_at": "2024-01-01T00:00:00Z",
      "active_paths": [
        {
          "path_id": "uuid",
          "path_title": "Foundations of Faith",
          "progress_percentage": 25
        }
      ]
    }
  ]
}
```

### GET `/fellowships/:id`
**Description:** Get details for a specific fellowship.

**Authentication:** Required (must be member)

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "Morning Bible Study Group",
    "description": "A group for daily morning Bible study and prayer",
    "mentor_id": "uuid",
    "mentor_name": "John Doe",
    "mentor_email": "mentor@example.com",
    "member_count": 5,
    "user_role": "member",
    "created_at": "2024-01-01T00:00:00Z",
    "active_paths": [
      {
        "path_id": "uuid",
        "path_title": "Foundations of Faith",
        "started_at": "2024-01-01T00:00:00Z",
        "progress_percentage": 25,
        "completed_lessons": 3,
        "total_lessons": 12
      }
    ],
    "recent_activity": [
      {
        "type": "lesson_completed",
        "lesson_title": "Understanding Grace",
        "completed_by": "Jane Smith",
        "completed_at": "2024-01-01T00:00:00Z"
      }
    ]
  }
}
```

### GET `/fellowships/:id/members`
**Description:** List all members of a fellowship.

**Authentication:** Required (must be member)

**Query Parameters:**
- `role`: Filter by role (mentor, member)
- `limit`: Number of members per page (default: 20)
- `offset`: Pagination offset

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "name": "John Doe",
      "email": "john@example.com",
      "role": "mentor",
      "photo_url": "https://example.com/photo.jpg",
      "joined_at": "2024-01-01T00:00:00Z",
      "last_active": "2024-01-01T00:00:00Z",
      "path_progress": [
        {
          "path_id": "uuid",
          "path_title": "Foundations of Faith",
          "completed_lessons": 3,
          "total_lessons": 12
        }
      ]
    }
  ],
  "pagination": {
    "total": 5,
    "limit": 20,
    "offset": 0,
    "hasMore": false
  }
}
```

### POST `/fellowships/:id/members`
**Description:** Add a user to a fellowship (Mentor only).

**Authentication:** Required (Mentor role)

**Request:**
```http
POST /fellowships/123e4567-e89b-12d3-a456-426614174000/members
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "email": "newmember@example.com",
  "role": "member"
}
```

**Validation Rules:**
- `email`: Required, valid email format
- `role`: Required, must be "member" (mentors can't be added via API)

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "Jane Smith",
    "email": "newmember@example.com",
    "role": "member",
    "joined_at": "2024-01-01T00:00:00Z"
  }
}
```

### DELETE `/fellowships/:id/members/:userId`
**Description:** Remove a member from a fellowship (Mentor only).

**Authentication:** Required (Mentor role)

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "Member removed successfully",
    "removed_user_id": "uuid"
  }
}
```

---

## 📖 Discipleship Path APIs

### GET `/discipleship_paths`
**Description:** Get all available discipleship paths.

**Authentication:** Optional

**Query Parameters:**
- `difficulty`: Filter by difficulty (beginner, intermediate, advanced)
- `category`: Filter by category (foundations, character, leadership)
- `limit`: Number of paths per page (default: 20)
- `offset`: Pagination offset

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "title": "Foundations of Faith",
      "description": "Essential teachings for new believers",
      "difficulty": "beginner",
      "category": "foundations",
      "estimated_duration": "12 weeks",
      "lesson_count": 12,
      "sequence": 1,
      "created_at": "2024-01-01T00:00:00Z",
      "user_progress": {
        "started": true,
        "completed_lessons": 3,
        "total_lessons": 12,
        "started_at": "2024-01-01T00:00:00Z"
      }
    }
  ],
  "pagination": {
    "total": 15,
    "limit": 20,
    "offset": 0,
    "hasMore": false
  }
}
```

### GET `/discipleship_paths/:id`
**Description:** Get details for a specific discipleship path.

**Authentication:** Optional

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "title": "Foundations of Faith",
    "description": "Essential teachings for new believers",
    "difficulty": "beginner",
    "category": "foundations",
    "estimated_duration": "12 weeks",
    "lesson_count": 12,
    "sequence": 1,
    "created_at": "2024-01-01T00:00:00Z",
    "prerequisites": [],
    "learning_objectives": [
      "Understand basic Christian doctrines",
      "Develop daily prayer habits",
      "Learn to study the Bible effectively"
    ],
    "user_progress": {
      "started": true,
      "completed_lessons": 3,
      "total_lessons": 12,
      "started_at": "2024-01-01T00:00:00Z",
      "last_activity": "2024-01-01T00:00:00Z"
    }
  }
}
```

### GET `/discipleship_paths/:id/lessons`
**Description:** Get all lessons in a path.

**Authentication:** Optional

**Query Parameters:**
- `completed_only`: Filter completed lessons (boolean)
- `limit`: Number of lessons per page (default: 20)
- `offset`: Pagination offset

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "path_id": "uuid",
      "title": "Understanding Grace",
      "content": "Grace is the unmerited favor of God...",
      "journal_prompt": "How has God's grace impacted your life?",
      "sequence": 1,
      "estimated_duration": "30 minutes",
      "created_at": "2024-01-01T00:00:00Z",
      "user_completion": {
        "completed": true,
        "completed_at": "2024-01-01T00:00:00Z",
        "journal_entry": "God's grace has transformed my life..."
      }
    }
  ],
  "pagination": {
    "total": 12,
    "limit": 20,
    "offset": 0,
    "hasMore": false
  }
}
```

### POST `/discipleship_paths/:id/start`
**Description:** Start a discipleship path (must be part of a fellowship).

**Authentication:** Required

**Request:**
```http
POST /discipleship_paths/123e4567-e89b-12d3-a456-426614174000/start
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "fellowship_id": "uuid"
}
```

**Validation Rules:**
- `fellowship_id`: Required, user must be member of fellowship
- User must not have already started this path

**Response:**
```json
{
  "success": true,
  "data": {
    "path_id": "uuid",
    "path_title": "Foundations of Faith",
    "fellowship_id": "uuid",
    "fellowship_name": "Morning Bible Study Group",
    "started_at": "2024-01-01T00:00:00Z",
    "first_lesson": {
      "id": "uuid",
      "title": "Understanding Grace",
      "sequence": 1
    }
  }
}
```

### PATCH `/discipleship_paths/:pathId/lessons/:lessonId/complete`
**Description:** Mark a lesson complete for the current user.

**Authentication:** Required

**Request:**
```http
PATCH /discipleship_paths/123e4567-e89b-12d3-a456-426614174000/lessons/456e7890-e89b-12d3-a456-426614174000/complete
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "journal_entry": "This lesson helped me understand...",
  "reflection_rating": 5
}
```

**Validation Rules:**
- `journal_entry`: Optional, max 1000 characters
- `reflection_rating`: Optional, 1-5 scale
- User must have started the path
- Previous lessons must be completed (unless sequence is flexible)

**Response:**
```json
{
  "success": true,
  "data": {
    "lesson_id": "uuid",
    "lesson_title": "Understanding Grace",
    "completed_at": "2024-01-01T00:00:00Z",
    "journal_entry": "This lesson helped me understand...",
    "reflection_rating": 5,
    "next_lesson": {
      "id": "uuid",
      "title": "The Power of Prayer",
      "sequence": 2
    },
    "path_progress": {
      "completed_lessons": 2,
      "total_lessons": 12,
      "percentage": 16.67
    }
  }
}
```

### GET `/discipleship_paths/:id/progress`
**Description:** Get the current user's progress in a path.

**Authentication:** Required

**Response:**
```json
{
  "success": true,
  "data": {
    "path_id": "uuid",
    "path_title": "Foundations of Faith",
    "started_at": "2024-01-01T00:00:00Z",
    "last_activity": "2024-01-01T00:00:00Z",
    "overall_progress": {
      "completed_lessons": 3,
      "total_lessons": 12,
      "percentage": 25
    },
    "completed_lessons": [
      {
        "id": "uuid",
        "title": "Understanding Grace",
        "completed_at": "2024-01-01T00:00:00Z",
        "journal_entry": "God's grace has transformed my life...",
        "reflection_rating": 5
      }
    ],
    "upcoming_lessons": [
      {
        "id": "uuid",
        "title": "The Power of Prayer",
        "sequence": 4,
        "estimated_duration": "30 minutes"
      }
    ],
    "fellowship_progress": {
      "fellowship_id": "uuid",
      "fellowship_name": "Morning Bible Study Group",
      "fellowship_completed_lessons": 2,
      "fellowship_total_lessons": 12
    }
  }
}
```

---

## 📓 Fellowship Discipleship Progress APIs (Mentor Controlled)

### GET `/fellowships/:id/progress`
**Description:** Get discipleship progress for all members in the fellowship.

**Authentication:** Required (Mentor role)

**Query Parameters:**
- `path_id`: Filter by specific path
- `member_id`: Filter by specific member
- `status`: Filter by completion status (active, completed, inactive)

**Response:**
```json
{
  "success": true,
  "data": {
    "fellowship_id": "uuid",
    "fellowship_name": "Morning Bible Study Group",
    "active_paths": [
      {
        "path_id": "uuid",
        "path_title": "Foundations of Faith",
        "started_at": "2024-01-01T00:00:00Z",
        "member_progress": [
          {
            "user_id": "uuid",
            "user_name": "John Doe",
            "user_email": "john@example.com",
            "role": "mentor",
            "completed_lessons": 3,
            "total_lessons": 12,
            "percentage": 25,
            "last_activity": "2024-01-01T00:00:00Z",
            "recent_completions": [
              {
                "lesson_id": "uuid",
                "lesson_title": "Understanding Grace",
                "completed_at": "2024-01-01T00:00:00Z"
              }
            ]
          }
        ],
        "fellowship_stats": {
          "total_members": 5,
          "active_members": 4,
          "average_progress": 20,
          "lessons_completed_this_week": 8
        }
      }
    ]
  }
}
```

### PATCH `/fellowships/:id/progress/lessons/:lessonId`
**Description:** Mark a lesson as complete for the entire fellowship.

**Authentication:** Required (Mentor role)

**Request:**
```http
PATCH /fellowships/123e4567-e89b-12d3-a456-426614174000/progress/lessons/456e7890-e89b-12d3-a456-426614174000
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "path_id": "uuid",
  "notes": "Great discussion on grace today!"
}
```

**Validation Rules:**
- `path_id`: Required, fellowship must be active in this path
- `notes`: Optional, max 500 characters

**Response:**
```json
{
  "success": true,
  "data": {
    "lesson_id": "uuid",
    "lesson_title": "Understanding Grace",
    "path_id": "uuid",
    "path_title": "Foundations of Faith",
    "completed_at": "2024-01-01T00:00:00Z",
    "completed_by_mentor": "uuid",
    "notes": "Great discussion on grace today!",
    "members_affected": 5,
    "next_lesson": {
      "id": "uuid",
      "title": "The Power of Prayer",
      "sequence": 2
    }
  }
}
```

### DELETE `/fellowships/:id/progress/lessons/:lessonId`
**Description:** Unmark a lesson as complete for the entire fellowship.

**Authentication:** Required (Mentor role)

**Response:**
```json
{
  "success": true,
  "data": {
    "lesson_id": "uuid",
    "lesson_title": "Understanding Grace",
    "unmarked_at": "2024-01-01T00:00:00Z",
    "members_affected": 5,
    "message": "Lesson completion unmarked for all fellowship members"
  }
}
```

---

## 🛡️ Security & Validation

### Authentication
- All sensitive endpoints require JWT authentication
- Role-based access control (RBAC) for mentor-only operations
- Session management with automatic token refresh

### Input Validation
- All user inputs validated against schemas
- SQL injection prevention with parameterized queries
- XSS protection for user-generated content
- Rate limiting on all endpoints

### Error Handling
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid email format",
    "details": {
      "field": "email",
      "value": "invalid-email"
    },
    "timestamp": "2024-01-01T00:00:00Z",
    "requestId": "req_123456"
  }
}
```

### Common Error Codes
- `VALIDATION_ERROR`: Input validation failed
- `AUTHENTICATION_ERROR`: Invalid or expired token
- `AUTHORIZATION_ERROR`: Insufficient permissions
- `RESOURCE_NOT_FOUND`: Requested resource doesn't exist
- `CONFLICT_ERROR`: Resource already exists or is in use
- `RATE_LIMIT_EXCEEDED`: Too many requests
- `INTERNAL_SERVER_ERROR`: Unexpected server error

---

## 🚀 Performance Considerations

### Caching Strategy
- Redis caching for frequently accessed data
- CDN for static content (images, documents)
- Database query optimization with proper indexing

### Pagination
- All list endpoints support pagination
- Default limit of 20 items per page
- Maximum limit of 100 items per page

### Rate Limiting
- 100 requests per minute per user
- 1000 requests per hour per user
- Burst allowance for legitimate traffic spikes

---

## 📝 Implementation Notes

### Database Indexes
```sql
-- Users table
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

-- Fellowships table
CREATE INDEX idx_fellowships_mentor_id ON fellowships(mentor_id);
CREATE INDEX idx_fellowships_created_at ON fellowships(created_at);

-- Fellowship members table
CREATE INDEX idx_fellowship_members_fellowship_id ON fellowship_members(fellowship_id);
CREATE INDEX idx_fellowship_members_user_id ON fellowship_members(user_id);

-- Progress tracking tables
CREATE INDEX idx_user_path_progress_user_path ON user_path_progress(user_id, path_id);
CREATE INDEX idx_fellowship_path_progress_fellowship_path ON fellowship_path_progress(fellowship_id, path_id);
```

### Monitoring & Analytics
- Request/response logging for all endpoints
- Performance metrics collection
- Error tracking and alerting
- User behavior analytics
- Business metrics dashboard

### Testing Strategy
- Unit tests for all business logic
- Integration tests for API endpoints
- End-to-end tests for critical user flows
- Performance testing for high-traffic scenarios
- Security testing for authentication and authorization
