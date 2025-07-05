# **📐 Technical Architecture -- Defeah Bible Study App**

> Unified architecture using Supabase as primary backend, aligned with UX flow and version roadmap up to v2.3

## **1. High-Level Architecture Overview**

```
User
│
Flutter App (Client)
│
├── Prompt Input Screen
├── Daily Verse View  
├── Study Guide View
├── Jeff Reed 4-Step Flow
├── Settings / History / Donate
│
REST API Gateway (Supabase)
│
Backend Services (Supabase Edge Functions)
├── LLM Prompt Router
├── Study Generator  
├── Jeff Reed Topic Engine (Static input)
├── Feedback Collector
├── History Tracker
└── Admin Dashboard API
│
Supabase Database (PostgreSQL)
├── User Profiles
├── Study Guides
├── Jeff Reed Sessions
├── Feedback Records
└── Analytics Data
```

## **2. Component Breakdown**

### **🧩 Frontend (Flutter)**

- **PromptInputScreen**: Entry point for Scripture/Topic input
- **JeffReedFlowScreen**: Predefined static topics only, no prompt required. Includes built-in fallback for missing topics—defaults to 'Gospel' with a notification. Localization supported via Settings preference.
- **StudyGuideScreen**: Renders LLM content in standardized 5-section layout
- **FeedbackModal**: Appears after study generation
- **DailyVerseScreen**: Pulls verse of the day
- **SettingsScreen**: Theme, Language, Support options
- **HistoryScreen**: Resume or view past studies with completion indicators
- **DonateModal**: Razorpay/UPI integration
- **AdminDashboard**: Feedback insights and usage analytics (admin-only)

### **⚙️ Backend (Supabase Edge Functions)**

- **/api/study/generate**: Handles scripture/topic prompt via LLM
- **/api/study/jeffreed**: Static topic lookup + LLM contextual guidance. Returns each step as separate fields for frontend progression.
- **/api/topics**: Returns predefined Jeff Reed study topics (static list)
- **/api/history**: Manages retrieval and resume states
- **/api/feedback**: Accepts and aggregates feedback data
- **/api/admin/dashboard**: Admin analytics and feedback insights
- **/api/admin/users**: User management for administrators

## **3. Standardized Data Models**

### **📌 StudyGuide**
- id: UUID
- user_id: UUID (nullable for anonymous)
- input_type: "scripture" | "topic"
- input_value: string
- summary: text
- context: text
- related_verses: text[]
- reflection_questions: text[]
- prayer_points: text[]
- language: string
- created_at: timestamp

### **📌 JeffReedSession**
- id: UUID
- user_id: UUID (nullable for anonymous)
- topic: string
- current_step: integer (1-4)
- step_1_context: text
- step_2_scholar_guide: text
- step_3_group_discussion: text
- step_4_application: text
- step_1_completed_at: timestamp
- step_2_completed_at: timestamp
- step_3_completed_at: timestamp
- step_4_completed_at: timestamp
- completion_status: boolean
- created_at: timestamp
- updated_at: timestamp

### **📌 Feedback**
- id: UUID
- study_guide_id: UUID
- user_id: UUID (nullable for anonymous)
- was_helpful: boolean
- message: text (optional)
- sentiment_score: float (optional)
- created_at: timestamp

### **📌 User** 
- id: UUID
- email: string (optional)
- name: string (optional)
- auth_provider: string
- language_preference: string
- theme_preference: string
- created_at: timestamp

## **4. Navigation Flow**

1. App Launch → Welcome/Login (Supabase Auth)
2. Home → Generate Study → Prompt Input → Study Guide
3. Home → Jeff Reed Study → Topic Cards → 4-Step Flow
4. Study Guide → Feedback Modal or Share Modal
5. Settings → Donate / Language / Theme
6. History → Resume Study or View
7. Admin (admin users only) → Feedback Insights Dashboard

## **5. Security Architecture**

- **Authentication:** Supabase Auth (Google, Apple, Anonymous sessions)
- **Authorization:** Supabase Row Level Security (RLS) for all user data
- **API Security:** Edge function rate limiting + input validation
- **Data Encryption:** HTTPS/TLS for all communications, encrypted local storage
- **LLM Security:** Input sanitization, output validation, prompt injection prevention

## **6. Offline Strategy**

### **Cached Content**
- Last 10 generated study guides (encrypted local storage)
- Jeff Reed topic list and static content
- User preferences and settings
- Bible verse cache for offline reference

### **Sync Strategy**
- Automatic sync when online
- Conflict resolution: server wins for data, local wins for preferences
- Offline indicator in UI with graceful degradation

## **7. Error Handling Architecture**

- **Standardized Error Codes:** Consistent across all API endpoints
- **Fallback Content:** Static study guides for common verses when LLM fails
- **Retry Logic:** Exponential backoff for network failures
- **User-Facing Messages:** Friendly error messages with actionable guidance

## **8. Admin Panel Architecture**

### **Access Control**
- Admin users identified by email whitelist in Supabase
- Role-based access control (RBAC) with admin, user roles
- Admin dashboard accessible only to authenticated admin users

### **Features**
- Feedback insights and sentiment analysis
- Usage analytics and cost monitoring
- User management and support tools
- LLM usage and performance metrics

## **9. Upcoming Integrations**

- Integrate /api/history with JeffReedFlow to persist progress
- Automatically set 'completion_status' flag when all Jeff Reed steps completed
- Map feedback sentiment analysis to admin dashboard visualizations
- Anonymous user session tracking and abuse prevention