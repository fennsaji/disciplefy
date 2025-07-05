# **📐 Updated Technical Architecture -- Defeah Bible Study App**

> Includes alignment with UX flow and version roadmap up to v2.3

## **1. High-Level Architecture Overview**

- User

- │

- Flutter App (Client)

- │

- ├── Prompt Input Screen

- ├── Daily Verse View

- ├── Study Guide View

- ├── Jeff Reed 4-Step Flow

- ├── Settings / History / Donate

- │

- REST API Gateway

- │

- Backend Services (Hosted on Firebase/Supabase)

- ├── LLM Prompt Router

- ├── Study Generator

- ├── Jeff Reed Topic Engine (Static input)

- ├── Feedback Collector

- ├── History Tracker

- └── Admin Dashboard API

- │

- Vector DB / SQL DB (Firestore / Supabase)

- ├── User Profiles

- ├── Prompt History

- ├── Jeff Reed Flow States

- ├── Feedback Records

- └── Verse Log

## **2. Component Breakdown**

### **🧩 Frontend (Flutter)**

- **PromptInputScreen**: Entry point for Scripture/Topic input

- **JeffReedFlowScreen**: Fixed-topic only, no prompt required. Includes
  built-in fallback for missing or misconfigured topics---defaults to
  \'Gospel\' with a notification. Localization is supported via Settings
  preference, with dynamic text loading based on the selected language.

- **StudyGuideScreen**: Renders LLM content in 3-part layout

- **FeedbackModal**: Appears after study generation

- **DailyVerseScreen**: Pulls verse of the day

- **SettingsScreen**: Theme, Language, Support options

- **HistoryScreen**: Resume or view past studies with completion
  indicators

- **DonateModal**: Razorpay/UPI integration

### **⚙️ Backend**

- **/api/study/generate**: Handles scripture/topic prompt via LLM

- **/api/study/jeffreed**: Fixed-topic lookup + LLM contextual guidance.
  API response returns each step (context, interpretation, reflection,
  application) as separate fields to support frontend progression and
  resume logic.

- **/api/topics**: Returns Jeff Reed predefined study topics

- **/api/history**: Manages retrieval and resume states

- **/api/feedback**: Accepts and aggregates feedback data

## **3. Data Models**

### **📌 StudyGuide**

- id

- user_id

- type: \"topic\" \| \"scripture\"

- input_ref: string

- llm_response: json

- created_at

### **📌 JeffReedState**

- user_id

- topic

- step_1_context: text

- step_2_ai_output

- step_3_reflection

- step_4_application

- step_1_completed_at: timestamp

- step_2_completed_at: timestamp

- step_3_completed_at: timestamp

- step_4_completed_at: timestamp

- completion_status: boolean

### **📌 Feedback**

- study_id

- was_helpful: bool

- message: optional text

- timestamp

## **4. Navigation Flow (Updated)**

1.  App Launch → Welcome/Login

2.  Home → Generate Study → Prompt Input → Study Guide

3.  Home → Jeff Reed Study → Topic Cards → 4-Step Flow

4.  Study Guide → Feedback Modal or Share Modal

5.  Settings → Donate / Language / Theme

6.  History → Resume Study or View

7.  Admin → Feedback Insights Dashboard

## **5. Security Notes**

- Environment secrets pulled from Firebase/Supabase

- API Gateway protects LLM endpoints with API key + usage cap

- Jeff Reed topics are non-editable (read-only, stored in config)

- Donation flow uses Razorpay/Google Pay without storing card info

  - ⚠️ Ensure compliance with PCI DSS standards where applicable. Use
    secure tokens and avoid storing payment details.

## **✅ Upcoming To-Dos**

- Integrate /api/history with JeffReedFlow to persist progress

- Automatically set \'completion_status\' flag in study model when all
  steps in Jeff Reed flow are marked as completed in study model

- Map feedback tags to admin dashboard visualizations
