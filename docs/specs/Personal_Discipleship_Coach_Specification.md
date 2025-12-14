# Personal Discipleship Coach - Technical Specification

**Document Version:** 1.0  
**Date:** January 18, 2025  
**Status:** Planning - Phase-Wise Development  
**Feature Priority:** Tier 1 ⭐⭐⭐⭐⭐  
**Estimated Development:** 6 weeks  
**Premium Tier:** Scholar ($9.99/month)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Technical Architecture](#2-technical-architecture)
3. [Database Schema](#3-database-schema)
4. [API Endpoints](#4-api-endpoints)
5. [Phase-Wise Development Plan](#5-phase-wise-development-plan)
6. [UI Components](#6-ui-components)
7. [LLM Integration](#7-llm-integration)
8. [Testing Strategy](#8-testing-strategy)
9. [Success Metrics](#9-success-metrics)
10. [Risk Mitigation](#10-risk-mitigation)

---

## 1. Executive Summary

### 1.1 Feature Overview

**Personal Discipleship Coach** is an AI-powered personalized spiritual growth guide that creates adaptive learning paths based on user behavior, spiritual maturity level, and growth goals.

**Core Value Proposition:**
- Solves: "I don't know what to study next"
- Provides: Personalized curriculum that evolves with the user
- Differentiator: No competitor offers AI-adaptive spiritual growth paths

### 1.2 Key Features

1. **Spiritual Assessment & Profiling**
   - Initial onboarding questionnaire
   - Learning style preferences
   - Spiritual maturity level detection

2. **AI-Powered Curriculum Generation**
   - Weekly personalized study plans
   - Topic progression based on engagement
   - Adaptive difficulty adjustment

3. **Progress Tracking & Analytics**
   - Completion rates and engagement metrics
   - Growth milestones and achievements
   - Weekly/monthly progress reviews

4. **Smart Recommendations**
   - Daily study suggestions
   - Context-aware insights
   - Knowledge gap identification

5. **Adaptive Learning System**
   - Real-time difficulty adjustment
   - Interest-based topic pivoting
   - Feedback-driven curriculum refinement

### 1.3 Success Criteria

**Engagement Metrics:**
- +50% daily study completion rate
- +40% 30-day retention
- 25-30% of premium users actively use coach

**Business Metrics:**
- Primary driver for Standard → Premium conversion
- 80%+ coach users rate experience 4+ stars
- 60%+ coach users complete 4+ weeks of curriculum

---

## 2. Technical Architecture

### 2.1 System Components

```
┌─────────────────────────────────────────────────────┐
│                  Flutter Frontend                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │  Coach   │  │  Study   │  │ Progress │          │
│  │Dashboard │  │  Screen  │  │Analytics │          │
│  └──────────┘  └──────────┘  └──────────┘          │
└─────────────────────────────────────────────────────┘
                      ↕ REST API
┌─────────────────────────────────────────────────────┐
│              Supabase Edge Functions                 │
│  ┌────────────────┐  ┌────────────────┐            │
│  │ Generate       │  │ Assess Growth  │            │
│  │ Curriculum     │  │ & Adapt        │            │
│  └────────────────┘  └────────────────┘            │
│  ┌────────────────┐  ┌────────────────┐            │
│  │ Daily          │  │ Track Progress │            │
│  │ Recommendation │  │ & Insights     │            │
│  └────────────────┘  └────────────────┘            │
└─────────────────────────────────────────────────────┘
                      ↕
┌─────────────────────────────────────────────────────┐
│                  LLM Services                        │
│  ┌────────────────┐  ┌────────────────┐            │
│  │ OpenAI GPT-4   │  │ Claude Haiku   │            │
│  │ (Curriculum)   │  │ (Fast Insights)│            │
│  └────────────────┘  └────────────────┘            │
└─────────────────────────────────────────────────────┘
                      ↕
┌─────────────────────────────────────────────────────┐
│              PostgreSQL Database                     │
│  ┌──────────────────────────────────────┐           │
│  │ • user_discipleship_profiles         │           │
│  │ • curriculum_plans                   │           │
│  │ • weekly_study_plans                 │           │
│  │ • daily_study_assignments            │           │
│  │ • coach_recommendations              │           │
│  │ • growth_assessments                 │           │
│  │ • learning_analytics                 │           │
│  └──────────────────────────────────────┘           │
└─────────────────────────────────────────────────────┘
```

### 2.2 Technology Stack

**Frontend:**
- Flutter 3.x (iOS, Android, Web)
- BLoC pattern for state management
- GetIt for dependency injection
- Cached network image for performance

**Backend:**
- Supabase PostgreSQL (database)
- Supabase Edge Functions (Deno/TypeScript)
- Supabase Auth (user management)
- Supabase Storage (cached plans)

**AI/LLM:**
- OpenAI GPT-4 Turbo (curriculum generation)
- Anthropic Claude Haiku (fast insights)
- Custom prompts with theological safeguards

**Notifications:**
- Firebase Cloud Messaging (FCM)
- Supabase Realtime (live updates)

---

## 3. Database Schema

### 3.1 Core Tables

#### **user_discipleship_profiles**
```sql
CREATE TABLE user_discipleship_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Spiritual Profile
  maturity_level TEXT NOT NULL CHECK (maturity_level IN (
    'new_believer',
    'growing_christian', 
    'mature_believer',
    'ministry_leader'
  )),
  
  -- Interests & Preferences
  primary_interests JSONB NOT NULL DEFAULT '[]', 
  -- ['prayer', 'grace', 'faith', 'worship', ...]
  
  learning_style JSONB NOT NULL DEFAULT '{}',
  -- {
  --   "daily_minutes": 15,
  --   "preferred_time": "morning",
  --   "study_styles": ["practical_application", "personal_reflection"],
  --   "difficulty_preference": "adaptive"
  -- }
  
  -- Growth Goals
  primary_goal TEXT NOT NULL,
  secondary_goals TEXT[] DEFAULT '{}',
  custom_goals TEXT,
  
  -- Preferences
  notification_preferences JSONB DEFAULT '{}',
  -- {
  --   "daily_reminder": true,
  --   "reminder_time": "08:00",
  --   "streak_protection": true,
  --   "weekly_preview": true
  -- }
  
  -- Metadata
  onboarding_completed BOOLEAN DEFAULT FALSE,
  profile_version INTEGER DEFAULT 1,
  last_profile_update TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id)
);

-- RLS Policies
ALTER TABLE user_discipleship_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON user_discipleship_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
  ON user_discipleship_profiles FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile"
  ON user_discipleship_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

#### **curriculum_plans**
```sql
CREATE TABLE curriculum_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Plan Metadata
  plan_name TEXT NOT NULL,
  description TEXT,
  total_weeks INTEGER NOT NULL DEFAULT 12,
  current_week INTEGER NOT NULL DEFAULT 1,
  
  -- Curriculum Structure
  curriculum_structure JSONB NOT NULL,
  -- {
  --   "theme": "Foundations of Faith",
  --   "weeks": [
  --     {
  --       "week_number": 1,
  --       "theme": "Understanding Salvation",
  --       "topics": ["grace", "faith", "repentance"],
  --       "difficulty": "beginner"
  --     },
  --     ...
  --   ]
  -- }
  
  -- Progression Tracking
  completion_percentage DECIMAL(5,2) DEFAULT 0.0,
  studies_completed INTEGER DEFAULT 0,
  total_studies INTEGER NOT NULL,
  
  -- Status
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
    'active',
    'paused',
    'completed',
    'abandoned'
  )),
  
  -- Adaptation History
  adaptations JSONB DEFAULT '[]',
  -- [
  --   {
  --     "date": "2025-01-15",
  --     "reason": "user_requested_higher_difficulty",
  --     "changes": "Increased theological depth for Week 5+"
  --   }
  -- ]
  
  -- Metadata
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  paused_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT valid_week_range CHECK (current_week >= 1 AND current_week <= total_weeks)
);

-- Indexes
CREATE INDEX idx_curriculum_plans_user_id ON curriculum_plans(user_id);
CREATE INDEX idx_curriculum_plans_status ON curriculum_plans(status);

-- RLS Policies
ALTER TABLE curriculum_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own plans"
  ON curriculum_plans FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own plans"
  ON curriculum_plans FOR UPDATE
  USING (auth.uid() = user_id);
```

#### **weekly_study_plans**
```sql
CREATE TABLE weekly_study_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  curriculum_plan_id UUID NOT NULL REFERENCES curriculum_plans(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Week Identification
  week_number INTEGER NOT NULL,
  week_theme TEXT NOT NULL,
  week_description TEXT,
  
  -- Timeline
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  
  -- Daily Studies (7 days)
  daily_studies JSONB NOT NULL,
  -- [
  --   {
  --     "day": "monday",
  --     "date": "2025-01-20",
  --     "study_id": "uuid",
  --     "title": "What is Grace?",
  --     "scripture": "Ephesians 2:8-9",
  --     "estimated_minutes": 15,
  --     "difficulty": "beginner",
  --     "objectives": ["Understand grace definition", ...],
  --     "completed": false,
  --     "completed_at": null
  --   },
  --   ...
  -- ]
  
  -- Progress
  studies_completed INTEGER DEFAULT 0,
  total_studies INTEGER DEFAULT 7,
  completion_percentage DECIMAL(5,2) DEFAULT 0.0,
  
  -- Status
  status TEXT NOT NULL DEFAULT 'upcoming' CHECK (status IN (
    'upcoming',
    'active',
    'completed',
    'skipped'
  )),
  
  -- Coach Insights
  intro_message TEXT,
  completion_message TEXT,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(curriculum_plan_id, week_number)
);

-- Indexes
CREATE INDEX idx_weekly_plans_user_id ON weekly_study_plans(user_id);
CREATE INDEX idx_weekly_plans_curriculum ON weekly_study_plans(curriculum_plan_id);
CREATE INDEX idx_weekly_plans_dates ON weekly_study_plans(start_date, end_date);

-- RLS Policies
ALTER TABLE weekly_study_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own weekly plans"
  ON weekly_study_plans FOR SELECT
  USING (auth.uid() = user_id);
```

#### **coach_recommendations**
```sql
CREATE TABLE coach_recommendations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Recommendation Context
  recommendation_type TEXT NOT NULL CHECK (recommendation_type IN (
    'daily_study',
    'topic_pivot',
    'difficulty_adjustment',
    'knowledge_gap',
    'milestone_celebration',
    'encouragement'
  )),
  
  -- Content
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  action_label TEXT,
  action_data JSONB,
  
  -- Priority
  priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN (
    'low',
    'normal',
    'high',
    'urgent'
  )),
  
  -- Display Control
  display_location TEXT NOT NULL DEFAULT 'coach_tab' CHECK (display_location IN (
    'coach_tab',
    'home_screen',
    'study_completion',
    'popup'
  )),
  
  -- Interaction
  viewed BOOLEAN DEFAULT FALSE,
  viewed_at TIMESTAMPTZ,
  acted_upon BOOLEAN DEFAULT FALSE,
  acted_at TIMESTAMPTZ,
  dismissed BOOLEAN DEFAULT FALSE,
  dismissed_at TIMESTAMPTZ,
  
  -- Expiration
  expires_at TIMESTAMPTZ,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT check_expiration CHECK (expires_at IS NULL OR expires_at > created_at)
);

-- Indexes
CREATE INDEX idx_coach_recommendations_user_id ON coach_recommendations(user_id);
CREATE INDEX idx_coach_recommendations_type ON coach_recommendations(recommendation_type);
CREATE INDEX idx_coach_recommendations_active ON coach_recommendations(user_id, viewed, dismissed, expires_at);

-- RLS Policies
ALTER TABLE coach_recommendations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own recommendations"
  ON coach_recommendations FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own recommendations"
  ON coach_recommendations FOR UPDATE
  USING (auth.uid() = user_id);
```

#### **growth_assessments**
```sql
CREATE TABLE growth_assessments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  curriculum_plan_id UUID REFERENCES curriculum_plans(id) ON DELETE CASCADE,
  
  -- Assessment Timing
  assessment_type TEXT NOT NULL CHECK (assessment_type IN (
    'weekly',
    'monthly',
    'quarterly',
    'annual',
    'on_demand'
  )),
  
  assessment_period TEXT NOT NULL, -- e.g., "2025-W03", "2025-01", "2025-Q1"
  
  -- Metrics
  studies_completed INTEGER NOT NULL DEFAULT 0,
  total_study_time_minutes INTEGER NOT NULL DEFAULT 0,
  average_study_duration_minutes DECIMAL(5,2),
  completion_rate DECIMAL(5,2), -- Percentage
  
  -- Engagement Quality
  follow_up_questions_asked INTEGER DEFAULT 0,
  average_study_rating DECIMAL(3,2), -- 1.0 to 5.0
  topics_explored INTEGER DEFAULT 0,
  
  -- Progress Indicators
  current_streak_days INTEGER DEFAULT 0,
  longest_streak_days INTEGER DEFAULT 0,
  
  -- AI-Generated Insights
  growth_summary TEXT,
  strengths JSONB DEFAULT '[]', -- ["Consistent daily practice", ...]
  areas_for_growth JSONB DEFAULT '[]', -- ["Deeper theological study", ...]
  recommended_next_steps JSONB DEFAULT '[]',
  
  -- Metadata
  generated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_growth_assessments_user_id ON growth_assessments(user_id);
CREATE INDEX idx_growth_assessments_period ON growth_assessments(assessment_period);
CREATE INDEX idx_growth_assessments_type ON growth_assessments(assessment_type);

-- RLS Policies
ALTER TABLE growth_assessments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own assessments"
  ON growth_assessments FOR SELECT
  USING (auth.uid() = user_id);
```

#### **learning_analytics**
```sql
CREATE TABLE learning_analytics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Event Tracking
  event_type TEXT NOT NULL CHECK (event_type IN (
    'study_started',
    'study_completed',
    'study_rated',
    'study_abandoned',
    'topic_explored',
    'follow_up_question',
    'difficulty_feedback',
    'curriculum_adjusted'
  )),
  
  -- Context
  study_guide_id UUID,
  weekly_plan_id UUID REFERENCES weekly_study_plans(id) ON DELETE SET NULL,
  curriculum_plan_id UUID REFERENCES curriculum_plans(id) ON DELETE CASCADE,
  
  -- Event Data
  event_data JSONB NOT NULL,
  -- Varies by event_type:
  -- study_completed: {
  --   "duration_seconds": 780,
  --   "completion_percentage": 100,
  --   "rating": 4,
  --   "difficulty_feedback": "just_right"
  -- }
  -- follow_up_question: {
  --   "question": "...",
  --   "topic": "grace",
  --   "answered": true
  -- }
  
  -- Metadata
  event_timestamp TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_learning_analytics_user_id ON learning_analytics(user_id);
CREATE INDEX idx_learning_analytics_event_type ON learning_analytics(event_type);
CREATE INDEX idx_learning_analytics_timestamp ON learning_analytics(event_timestamp);
CREATE INDEX idx_learning_analytics_curriculum ON learning_analytics(curriculum_plan_id);

-- RLS Policies
ALTER TABLE learning_analytics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own analytics"
  ON learning_analytics FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert analytics"
  ON learning_analytics FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

### 3.2 Database Functions

#### **Update Curriculum Progress**
```sql
CREATE OR REPLACE FUNCTION update_curriculum_progress()
RETURNS TRIGGER AS $$
BEGIN
  -- Update curriculum plan completion stats
  UPDATE curriculum_plans
  SET 
    studies_completed = (
      SELECT COUNT(*)
      FROM weekly_study_plans wsp,
      LATERAL (
        SELECT jsonb_array_elements(wsp.daily_studies) AS study
      ) studies
      WHERE wsp.curriculum_plan_id = NEW.curriculum_plan_id
        AND (study->>'completed')::boolean = true
    ),
    completion_percentage = (
      SELECT ROUND(
        (COUNT(*) FILTER (WHERE (study->>'completed')::boolean = true)::DECIMAL / 
         NULLIF(COUNT(*)::DECIMAL, 0)) * 100, 
        2
      )
      FROM weekly_study_plans wsp,
      LATERAL (
        SELECT jsonb_array_elements(wsp.daily_studies) AS study
      ) studies
      WHERE wsp.curriculum_plan_id = NEW.curriculum_plan_id
    ),
    current_week = NEW.week_number,
    updated_at = NOW()
  WHERE id = NEW.curriculum_plan_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_curriculum_progress
  AFTER UPDATE ON weekly_study_plans
  FOR EACH ROW
  WHEN (OLD.studies_completed IS DISTINCT FROM NEW.studies_completed)
  EXECUTE FUNCTION update_curriculum_progress();
```

#### **Get Current Study Assignment**
```sql
CREATE OR REPLACE FUNCTION get_current_study_assignment(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'weekly_plan_id', wsp.id,
    'week_number', wsp.week_number,
    'week_theme', wsp.week_theme,
    'today_study', (
      SELECT study
      FROM jsonb_array_elements(wsp.daily_studies) AS study
      WHERE (study->>'date')::DATE = CURRENT_DATE
        AND (study->>'completed')::boolean = false
      LIMIT 1
    ),
    'upcoming_studies', (
      SELECT jsonb_agg(study)
      FROM jsonb_array_elements(wsp.daily_studies) AS study
      WHERE (study->>'date')::DATE > CURRENT_DATE
        AND (study->>'completed')::boolean = false
    )
  ) INTO v_result
  FROM weekly_study_plans wsp
  WHERE wsp.user_id = p_user_id
    AND wsp.status = 'active'
    AND CURRENT_DATE BETWEEN wsp.start_date AND wsp.end_date
  LIMIT 1;
  
  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 4. API Endpoints

### 4.1 Edge Functions

#### **POST /coach/onboarding**
Complete initial spiritual assessment and create profile.

**Request:**
```typescript
{
  maturity_level: 'new_believer' | 'growing_christian' | 'mature_believer' | 'ministry_leader',
  primary_interests: string[], // ['grace', 'prayer', 'faith']
  learning_style: {
    daily_minutes: number, // 5-60
    preferred_time: 'morning' | 'afternoon' | 'evening' | 'night',
    study_styles: string[], // ['practical_application', 'theological_depth', ...]
    difficulty_preference: 'easy' | 'adaptive' | 'challenging'
  },
  primary_goal: string,
  secondary_goals?: string[],
  custom_goals?: string
}
```

**Response:**
```typescript
{
  profile_id: string,
  curriculum_plan_id: string,
  first_week_preview: {
    week_number: 1,
    theme: string,
    studies: Array<{
      day: string,
      title: string,
      scripture: string
    }>
  }
}
```

---

#### **POST /coach/generate-curriculum**
Generate personalized 12-week curriculum plan.

**Request:**
```typescript
{
  user_id: string,
  profile_id: string,
  force_regenerate?: boolean
}
```

**Response:**
```typescript
{
  curriculum_plan_id: string,
  plan_name: string,
  total_weeks: number,
  curriculum_structure: {
    theme: string,
    weeks: Array<{
      week_number: number,
      theme: string,
      topics: string[],
      difficulty: 'beginner' | 'intermediate' | 'advanced'
    }>
  }
}
```

**Implementation:**
```typescript
// backend/supabase/functions/coach/generate-curriculum/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { OpenAI } from 'https://esm.sh/openai@4';

const CURRICULUM_GENERATION_PROMPT = `
You are a theological expert and curriculum designer for a Bible study app.

Generate a personalized 12-week Bible study curriculum based on the user's profile:

User Profile:
- Maturity Level: {{maturity_level}}
- Primary Interests: {{primary_interests}}
- Learning Style: {{learning_style}}
- Primary Goal: {{primary_goal}}

Requirements:
1. Create a progressive learning path that builds on previous weeks
2. Balance theological depth with practical application
3. Include variety across Old Testament, New Testament, and topical studies
4. Align difficulty with user's maturity level
5. Focus on user's stated interests and goals
6. Follow orthodox Christian theology

Output Format (JSON):
{
  "plan_name": "Descriptive name for the curriculum",
  "theme": "Overall theme connecting all 12 weeks",
  "weeks": [
    {
      "week_number": 1,
      "theme": "Week theme",
      "description": "What user will learn this week",
      "topics": ["topic1", "topic2", "topic3"],
      "difficulty": "beginner|intermediate|advanced",
      "key_scriptures": ["Reference 1", "Reference 2"],
      "learning_objectives": ["Objective 1", "Objective 2"]
    },
    // ... 12 weeks total
  ]
}
`;

serve(async (req) => {
  try {
    const { user_id, profile_id, force_regenerate } = await req.json();
    
    // Initialize clients
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );
    
    const openai = new OpenAI({
      apiKey: Deno.env.get('OPENAI_API_KEY')!
    });
    
    // Check for existing active plan
    if (!force_regenerate) {
      const { data: existingPlan } = await supabase
        .from('curriculum_plans')
        .select('*')
        .eq('user_id', user_id)
        .eq('status', 'active')
        .single();
      
      if (existingPlan) {
        return new Response(JSON.stringify(existingPlan), {
          headers: { 'Content-Type': 'application/json' }
        });
      }
    }
    
    // Fetch user profile
    const { data: profile } = await supabase
      .from('user_discipleship_profiles')
      .select('*')
      .eq('id', profile_id)
      .single();
    
    if (!profile) {
      throw new Error('Profile not found');
    }
    
    // Generate curriculum using LLM
    const completion = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: [
        {
          role: 'system',
          content: 'You are a theological expert and curriculum designer.'
        },
        {
          role: 'user',
          content: CURRICULUM_GENERATION_PROMPT
            .replace('{{maturity_level}}', profile.maturity_level)
            .replace('{{primary_interests}}', profile.primary_interests.join(', '))
            .replace('{{learning_style}}', JSON.stringify(profile.learning_style))
            .replace('{{primary_goal}}', profile.primary_goal)
        }
      ],
      response_format: { type: 'json_object' },
      temperature: 0.7,
      max_tokens: 4000
    });
    
    const curriculumStructure = JSON.parse(
      completion.choices[0].message.content
    );
    
    // Calculate total studies (7 per week * 12 weeks)
    const totalStudies = 12 * 7;
    
    // Save curriculum plan
    const { data: plan, error } = await supabase
      .from('curriculum_plans')
      .insert({
        user_id,
        plan_name: curriculumStructure.plan_name,
        description: curriculumStructure.theme,
        total_weeks: 12,
        current_week: 1,
        curriculum_structure: curriculumStructure,
        total_studies: totalStudies,
        status: 'active'
      })
      .select()
      .single();
    
    if (error) throw error;
    
    return new Response(JSON.stringify(plan), {
      headers: { 'Content-Type': 'application/json' },
      status: 200
    });
    
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500
    });
  }
});
```

---

#### **POST /coach/generate-weekly-plan**
Generate detailed daily studies for a specific week.

**Request:**
```typescript
{
  curriculum_plan_id: string,
  week_number: number,
  start_date: string // ISO date
}
```

**Response:**
```typescript
{
  weekly_plan_id: string,
  week_theme: string,
  daily_studies: Array<{
    day: string,
    date: string,
    study_id: string,
    title: string,
    scripture: string,
    estimated_minutes: number,
    objectives: string[]
  }>
}
```

---

#### **GET /coach/daily-recommendation**
Get today's recommended study with personalized insights.

**Request:** Query params: `user_id`

**Response:**
```typescript
{
  weekly_plan_id: string,
  week_number: number,
  week_theme: string,
  today_study: {
    study_id: string,
    title: string,
    scripture: string,
    estimated_minutes: number,
    objectives: string[],
    coach_note: string, // Personalized message
    context: string // Why this study today
  },
  progress: {
    week_completion: number, // percentage
    streak_days: number,
    studies_this_week: number
  }
}
```

---

#### **POST /coach/track-study-event**
Track study-related events for analytics and adaptation.

**Request:**
```typescript
{
  event_type: 'study_started' | 'study_completed' | 'study_rated' | 'study_abandoned',
  study_guide_id: string,
  event_data: {
    duration_seconds?: number,
    completion_percentage?: number,
    rating?: number, // 1-5
    difficulty_feedback?: 'too_easy' | 'just_right' | 'too_hard'
  }
}
```

**Response:**
```typescript
{
  analytics_id: string,
  triggers_adaptation: boolean,
  new_recommendations?: Array<{
    type: string,
    message: string
  }>
}
```

---

#### **POST /coach/assess-growth**
Generate growth assessment and adaptive recommendations.

**Request:**
```typescript
{
  user_id: string,
  assessment_type: 'weekly' | 'monthly',
  period: string // e.g., "2025-W03" or "2025-01"
}
```

**Response:**
```typescript
{
  assessment_id: string,
  growth_summary: string,
  strengths: string[],
  areas_for_growth: string[],
  recommended_adjustments: {
    difficulty?: 'increase' | 'decrease',
    topics_to_explore?: string[],
    study_pace?: 'faster' | 'slower'
  },
  next_steps: string[]
}
```

---

#### **GET /coach/progress-analytics**
Retrieve comprehensive progress data and insights.

**Request:** Query params: `user_id`, `period?` (week/month/all)

**Response:**
```typescript
{
  overview: {
    current_week: number,
    total_weeks: number,
    overall_completion: number, // percentage
    studies_completed: number,
    total_study_time_hours: number
  },
  engagement: {
    current_streak: number,
    longest_streak: number,
    average_session_minutes: number,
    days_active_this_month: number
  },
  topics_mastered: string[],
  upcoming_milestones: Array<{
    type: string,
    description: string,
    days_until: number
  }>,
  achievements: Array<{
    id: string,
    name: string,
    unlocked_at: string
  }>
}
```

---

## 5. Phase-Wise Development Plan

### Phase 1: Foundation & Infrastructure (Week 1)

**Objective:** Set up database schema, core data models, and basic API structure.

#### Tasks:
1. **Database Setup** (2 days)
   - [ ] Create all core tables with RLS policies
   - [ ] Implement database functions and triggers
   - [ ] Create indexes for performance
   - [ ] Write migration scripts
   - [ ] Test data integrity constraints

2. **Flutter Data Models** (2 days)
   - [ ] Create Dart models for all entities
   - [ ] Implement JSON serialization/deserialization
   - [ ] Create repository interfaces
   - [ ] Set up data source abstractions
   - [ ] Write unit tests for models

3. **Basic API Scaffolding** (1 day)
   - [ ] Set up Edge Function project structure
   - [ ] Create shared utilities and validation
   - [ ] Implement error handling middleware
   - [ ] Set up LLM client wrappers
   - [ ] Configure environment variables

**Deliverables:**
- ✅ Complete database schema deployed to Supabase
- ✅ Flutter data layer with clean architecture
- ✅ Edge Functions scaffolding ready
- ✅ Unit tests passing (>80% coverage)

**Success Criteria:**
- Database migrations run successfully
- Models serialize/deserialize correctly
- Repository pattern properly abstracted

---

### Phase 2: Onboarding & Profile Creation (Week 2)

**Objective:** Build the spiritual assessment onboarding flow.

#### Tasks:
1. **Onboarding UI** (3 days)
   - [ ] Design onboarding screen layouts (Figma → Flutter)
   - [ ] Implement 5-screen onboarding flow
   - [ ] Add progress indicators and animations
   - [ ] Create custom interest selection chips
   - [ ] Implement time slider and preference toggles
   - [ ] Add skip/back navigation
   - [ ] Handle validation and error states

2. **Profile Creation API** (1 day)
   - [ ] Implement `/coach/onboarding` endpoint
   - [ ] Validate input data against schema
   - [ ] Save profile to database
   - [ ] Trigger curriculum generation
   - [ ] Return initial plan preview

3. **BLoC State Management** (1 day)
   - [ ] Create `OnboardingBloc` with events/states
   - [ ] Implement profile submission logic
   - [ ] Handle loading/success/error states
   - [ ] Cache onboarding progress locally
   - [ ] Integrate with repository layer

**Deliverables:**
- ✅ Complete onboarding UI (5 screens)
- ✅ Profile creation API functional
- ✅ User profile saved and retrievable

**Success Criteria:**
- Onboarding flow completes in <3 minutes
- Profile data persists correctly
- UI handles all edge cases gracefully

---

### Phase 3: Curriculum Generation (Week 2-3)

**Objective:** Implement AI-powered curriculum generation.

#### Tasks:
1. **LLM Prompt Engineering** (2 days)
   - [ ] Design curriculum generation prompt template
   - [ ] Add theological accuracy safeguards
   - [ ] Implement maturity-level customization
   - [ ] Test prompts with various profiles
   - [ ] Validate JSON output schema
   - [ ] Handle LLM errors and retries

2. **Curriculum Generation API** (2 days)
   - [ ] Implement `/coach/generate-curriculum` endpoint
   - [ ] Integrate OpenAI GPT-4 Turbo
   - [ ] Parse and validate LLM response
   - [ ] Save curriculum structure to DB
   - [ ] Implement caching strategy
   - [ ] Add rate limiting

3. **Weekly Plan Generation** (1 day)
   - [ ] Implement `/coach/generate-weekly-plan` endpoint
   - [ ] Create detailed daily study structures
   - [ ] Generate study titles and objectives
   - [ ] Map scriptures to each study
   - [ ] Calculate estimated durations

**Deliverables:**
- ✅ Curriculum generation fully functional
- ✅ 12-week personalized plans created
- ✅ Weekly plans with daily study details

**Success Criteria:**
- Curriculum generated in <15 seconds
- Theologically accurate content (manual review)
- Plans properly tailored to user profiles

---

### Phase 4: Coach Dashboard UI (Week 3-4)

**Objective:** Build the main Coach dashboard and navigation.

#### Tasks:
1. **Coach Tab Navigation** (1 day)
   - [ ] Add "Coach" tab to bottom navigation
   - [ ] Create coach tab routing
   - [ ] Implement tab state persistence
   - [ ] Add premium feature gate check

2. **Dashboard Layout** (3 days)
   - [ ] Build progress overview card
   - [ ] Create today's study recommendation card
   - [ ] Implement this week's journey timeline
   - [ ] Design upcoming milestones section
   - [ ] Add pull-to-refresh functionality
   - [ ] Implement skeleton loading states

3. **Weekly Plan View** (2 days)
   - [ ] Create weekly plan screen
   - [ ] Build daily study cards (7 days)
   - [ ] Implement completion checkmarks
   - [ ] Add "locked" state for future days
   - [ ] Show study details on tap
   - [ ] Display week theme and progress

**Deliverables:**
- ✅ Coach dashboard fully functional
- ✅ Weekly plan view with 7-day timeline
- ✅ Smooth navigation and UX

**Success Criteria:**
- Dashboard loads in <1 second
- All cards render with correct data
- Responsive design works on all devices

---

### Phase 5: Daily Recommendation System (Week 4)

**Objective:** Implement personalized daily study recommendations.

#### Tasks:
1. **Recommendation Engine** (2 days)
   - [ ] Implement `/coach/daily-recommendation` API
   - [ ] Fetch current study assignment
   - [ ] Generate personalized coach notes
   - [ ] Create contextual "why this study" messages
   - [ ] Calculate progress stats
   - [ ] Handle edge cases (week complete, plan paused)

2. **Study Integration** (2 days)
   - [ ] Link coach recommendation to study guide
   - [ ] Pre-fill study context from coach data
   - [ ] Add "Coach Note" banner in study screen
   - [ ] Track study start from coach recommendation
   - [ ] Update daily study status on completion

3. **Notifications** (1 day)
   - [ ] Implement daily reminder notifications
   - [ ] Send push at user's preferred time
   - [ ] Include today's study title in notification
   - [ ] Handle streak protection reminders
   - [ ] Add notification settings in coach config

**Deliverables:**
- ✅ Daily study recommendations working
- ✅ Personalized coach insights displayed
- ✅ Push notifications sent on schedule

**Success Criteria:**
- Recommendations update daily at midnight
- Coach notes feel personal and relevant
- Notifications sent reliably at set times

---

### Phase 6: Progress Tracking & Analytics (Week 5)

**Objective:** Track user engagement and display progress analytics.

#### Tasks:
1. **Analytics Event Tracking** (2 days)
   - [ ] Implement `/coach/track-study-event` API
   - [ ] Track study started/completed/abandoned
   - [ ] Capture study ratings and feedback
   - [ ] Log follow-up questions asked
   - [ ] Store event data for analysis

2. **Progress Analytics UI** (2 days)
   - [ ] Create progress/analytics screen
   - [ ] Build progress overview cards
   - [ ] Implement engagement metrics display
   - [ ] Show topics mastered timeline
   - [ ] Display achievements earned
   - [ ] Add visual charts (completion rate, time spent)

3. **Growth Assessment API** (1 day)
   - [ ] Implement `/coach/assess-growth` endpoint
   - [ ] Calculate weekly/monthly metrics
   - [ ] Generate AI-powered growth summaries
   - [ ] Identify strengths and growth areas
   - [ ] Provide recommended next steps

**Deliverables:**
- ✅ Comprehensive event tracking system
- ✅ Progress analytics dashboard
- ✅ Weekly growth assessments

**Success Criteria:**
- All study events tracked accurately
- Analytics update in real-time
- Growth summaries feel insightful

---

### Phase 7: Adaptive Learning System (Week 5-6)

**Objective:** Implement AI-driven curriculum adaptation based on user behavior.

#### Tasks:
1. **Adaptation Logic** (3 days)
   - [ ] Analyze user engagement patterns
   - [ ] Detect difficulty mismatches (too easy/hard)
   - [ ] Identify topic interest signals
   - [ ] Implement adaptation triggers
   - [ ] Generate curriculum adjustment recommendations

2. **Coach Insights & Recommendations** (2 days)
   - [ ] Create insight popup UI components
   - [ ] Implement recommendation system
   - [ ] Generate contextual coach messages
   - [ ] Add "Accept/Decline" adaptation flow
   - [ ] Update curriculum on user approval

3. **Dynamic Curriculum Updates** (1 day)
   - [ ] Allow mid-journey plan adjustments
   - [ ] Regenerate future weeks with new difficulty
   - [ ] Preserve completed studies
   - [ ] Log adaptation history
   - [ ] Notify user of curriculum changes

**Deliverables:**
- ✅ Adaptive learning system operational
- ✅ Coach insights displayed contextually
- ✅ Curriculum updates dynamically

**Success Criteria:**
- Adaptations triggered appropriately (not too aggressive)
- User acceptance rate >60%
- Adapted curriculum improves engagement

---

### Phase 8: Settings & Customization (Week 6)

**Objective:** Allow users to customize coach preferences and manage their journey.

#### Tasks:
1. **Coach Settings Screen** (2 days)
   - [ ] Create settings UI layout
   - [ ] Implement profile editing
   - [ ] Add study preference controls
   - [ ] Build notification settings
   - [ ] Create journey management actions

2. **Journey Management** (2 days)
   - [ ] Implement "Pause Journey" functionality
   - [ ] Add "Skip This Week" option
   - [ ] Create "Restart Journey" flow
   - [ ] Build "Request New Plan" feature
   - [ ] Handle status transitions properly

3. **Notification Customization** (1 day)
   - [ ] Allow custom reminder times
   - [ ] Toggle streak protection reminders
   - [ ] Configure weekly preview notifications
   - [ ] Test notification scheduling
   - [ ] Handle timezone changes

**Deliverables:**
- ✅ Coach settings fully functional
- ✅ Journey management options working
- ✅ Customizable notifications

**Success Criteria:**
- Settings persist correctly
- Journey pause/restart works smoothly
- Notification customization effective

---

### Phase 9: Polish, Testing & Launch Prep (Week 6)

**Objective:** Final polish, comprehensive testing, and launch preparation.

#### Tasks:
1. **UI/UX Polish** (2 days)
   - [ ] Review all screens with design team
   - [ ] Fix any visual inconsistencies
   - [ ] Add micro-animations and transitions
   - [ ] Optimize loading states
   - [ ] Test on multiple devices/screen sizes
   - [ ] Ensure accessibility compliance

2. **Integration Testing** (2 days)
   - [ ] End-to-end testing of full user journey
   - [ ] Test onboarding → curriculum → daily studies
   - [ ] Verify analytics tracking accuracy
   - [ ] Test adaptation triggers and flows
   - [ ] Validate API error handling
   - [ ] Load testing with concurrent users

3. **Documentation & Launch** (1 day)
   - [ ] Write user-facing help documentation
   - [ ] Create internal admin guide
   - [ ] Document API endpoints
   - [ ] Prepare launch announcement
   - [ ] Set up monitoring and alerts
   - [ ] Deploy to production

**Deliverables:**
- ✅ Fully polished and tested feature
- ✅ Documentation complete
- ✅ Production deployment ready

**Success Criteria:**
- Zero critical bugs in production
- All tests passing (unit + integration)
- Monitoring dashboards operational

---

## 6. UI Components

### 6.1 Component Library

#### **CoachDashboardCard**
```dart
// frontend/lib/features/coach/presentation/widgets/coach_dashboard_card.dart

class CoachDashboardCard extends StatelessWidget {
  final CoachDashboardData data;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting with time-based emoji
            _buildGreeting(data.userName, _getTimeOfDay()),
            
            SizedBox(height: 20),
            
            // Progress Overview
            _buildProgressOverview(
              currentWeek: data.currentWeek,
              totalWeeks: data.totalWeeks,
              completionPercentage: data.overallCompletion,
              streakDays: data.currentStreak,
              studiesCompleted: data.studiesCompleted,
              totalStudyHours: data.totalStudyHours,
            ),
            
            SizedBox(height: 24),
            
            // Today's Study Section
            _buildTodayStudy(data.todayStudy),
            
            SizedBox(height: 20),
            
            // This Week's Journey
            _buildWeeklyJourney(data.thisWeek),
            
            SizedBox(height: 20),
            
            // Upcoming Milestones
            _buildUpcomingMilestones(data.upcomingMilestones),
          ],
        ),
      ),
    );
  }
}
```

#### **DailyStudyCard**
```dart
// frontend/lib/features/coach/presentation/widgets/daily_study_card.dart

class DailyStudyCard extends StatelessWidget {
  final DailyStudy study;
  final VoidCallback onStartStudy;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onStartStudy,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Scripture
              Text(
                study.title,
                style: AppTextStyles.headingMedium,
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.book, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 4),
                  Text(
                    study.scripture,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Estimated Time
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    '~${study.estimatedMinutes} minutes',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Coach Note
              if (study.coachNote != null)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.highlight.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, 
                           size: 20, 
                           color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          study.coachNote!,
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              
              SizedBox(height: 16),
              
              // CTA Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onStartStudy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Start Study'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

#### **WeeklyPlanTimeline**
```dart
// frontend/lib/features/coach/presentation/widgets/weekly_plan_timeline.dart

class WeeklyPlanTimeline extends StatelessWidget {
  final List<DailyStudy> dailyStudies;
  final int currentDayIndex;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This Week\'s Journey',
          style: AppTextStyles.headingMedium,
        ),
        SizedBox(height: 16),
        
        ...dailyStudies.asMap().entries.map((entry) {
          final index = entry.key;
          final study = entry.value;
          final isToday = index == currentDayIndex;
          final isPast = index < currentDayIndex;
          final isFuture = index > currentDayIndex;
          
          return _buildDayItem(
            study: study,
            isToday: isToday,
            isPast: isPast,
            isFuture: isFuture,
            showConnector: index < dailyStudies.length - 1,
          );
        }).toList(),
      ],
    );
  }
  
  Widget _buildDayItem({
    required DailyStudy study,
    required bool isToday,
    required bool isPast,
    required bool isFuture,
    required bool showConnector,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline Indicator
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPast 
                        ? AppColors.success 
                        : isToday 
                            ? AppColors.primary 
                            : AppColors.surfaceVariant,
                    border: Border.all(
                      color: isToday ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isPast 
                        ? Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            study.dayNumber.toString(),
                            style: TextStyle(
                              color: isToday ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                if (showConnector)
                  Container(
                    width: 2,
                    height: 40,
                    color: isPast ? AppColors.success : AppColors.surfaceVariant,
                  ),
              ],
            ),
            
            SizedBox(width: 16),
            
            // Study Info
            Expanded(
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isToday 
                      ? AppColors.highlight.withOpacity(0.3)
                      : isFuture
                          ? AppColors.surface
                          : AppColors.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isToday ? AppColors.highlight : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day Label
                    Text(
                      '${study.dayName.toUpperCase()}, ${_formatDate(study.date)}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    
                    // Title
                    Text(
                      study.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isFuture && !isToday 
                            ? AppColors.textSecondary 
                            : AppColors.textPrimary,
                      ),
                    ),
                    
                    // Scripture
                    Text(
                      study.scripture,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    
                    SizedBox(height: 8),
                    
                    // Status or Time
                    if (isPast)
                      Row(
                        children: [
                          Icon(Icons.check_circle, 
                               size: 14, 
                               color: AppColors.success),
                          SizedBox(width: 4),
                          Text(
                            'Completed in ${study.completedInMinutes} min',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      )
                    else if (isFuture)
                      Row(
                        children: [
                          Icon(Icons.lock_outline, 
                               size: 14, 
                               color: AppColors.textSecondary),
                          SizedBox(width: 4),
                          Text(
                            'Unlocks ${_getDaysUntil(study.date)}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        '⏱️ ~${study.estimatedMinutes} minutes',
                        style: AppTextStyles.labelSmall,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (showConnector) SizedBox(height: 0),
      ],
    );
  }
}
```

#### **ProgressChart**
```dart
// frontend/lib/features/coach/presentation/widgets/progress_chart.dart

class ProgressChart extends StatelessWidget {
  final List<WeeklyProgress> weeklyProgress;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Progress',
              style: AppTextStyles.headingMedium,
            ),
            SizedBox(height: 20),
            
            // Bar Chart
            SizedBox(
              height: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: weeklyProgress.map((week) {
                  return _buildWeekBar(
                    week: week.weekNumber,
                    completionPercentage: week.completionPercentage,
                    isCurrent: week.isCurrent,
                  );
                }).toList(),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(AppColors.primary, 'Completed'),
                SizedBox(width: 16),
                _buildLegendItem(AppColors.surfaceVariant, 'Upcoming'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWeekBar({
    required int week,
    required double completionPercentage,
    required bool isCurrent,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Percentage Label
        if (completionPercentage > 0)
          Text(
            '${completionPercentage.toInt()}%',
            style: AppTextStyles.labelSmall,
          ),
        SizedBox(height: 4),
        
        // Bar
        Container(
          width: 24,
          height: (150 * completionPercentage / 100).clamp(8.0, 150.0),
          decoration: BoxDecoration(
            color: completionPercentage > 0 
                ? AppColors.primary 
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
            border: isCurrent 
                ? Border.all(color: AppColors.highlight, width: 2) 
                : null,
          ),
        ),
        
        SizedBox(height: 8),
        
        // Week Label
        Text(
          'W$week',
          style: AppTextStyles.labelSmall.copyWith(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
```

#### **CoachInsightBanner**
```dart
// frontend/lib/features/coach/presentation/widgets/coach_insight_banner.dart

class CoachInsightBanner extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.highlight.withOpacity(0.3),
            AppColors.highlight.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.highlight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb,
            color: AppColors.primary,
            size: 24,
          ),
          SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 Coach Insight',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  message,
                  style: AppTextStyles.bodySmall,
                ),
                
                if (actionLabel != null && onAction != null) ...[
                  SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: Text(actionLabel!),
                      ),
                      if (onDismiss != null) ...[
                        SizedBox(width: 8),
                        TextButton(
                          onPressed: onDismiss,
                          child: Text('Maybe Later'),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          if (onDismiss != null)
            IconButton(
              icon: Icon(Icons.close, size: 20),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
```

### 6.2 BLoC Architecture

#### **CoachBloc**
```dart
// frontend/lib/features/coach/presentation/bloc/coach_bloc.dart

// Events
abstract class CoachEvent extends Equatable {}

class LoadCoachDashboard extends CoachEvent {
  @override
  List<Object?> get props => [];
}

class RefreshCoachDashboard extends CoachEvent {
  @override
  List<Object?> get props => [];
}

class StartOnboarding extends CoachEvent {
  @override
  List<Object?> get props => [];
}

class SubmitOnboardingData extends CoachEvent {
  final OnboardingData data;
  SubmitOnboardingData(this.data);
  @override
  List<Object?> get props => [data];
}

class LoadWeeklyPlan extends CoachEvent {
  final int weekNumber;
  LoadWeeklyPlan(this.weekNumber);
  @override
  List<Object?> get props => [weekNumber];
}

class TrackStudyEvent extends CoachEvent {
  final String studyId;
  final StudyEventType eventType;
  final Map<String, dynamic> eventData;
  
  TrackStudyEvent({
    required this.studyId,
    required this.eventType,
    required this.eventData,
  });
  
  @override
  List<Object?> get props => [studyId, eventType, eventData];
}

class AcceptCoachRecommendation extends CoachEvent {
  final String recommendationId;
  AcceptCoachRecommendation(this.recommendationId);
  @override
  List<Object?> get props => [recommendationId];
}

class DismissCoachRecommendation extends CoachEvent {
  final String recommendationId;
  DismissCoachRecommendation(this.recommendationId);
  @override
  List<Object?> get props => [recommendationId];
}

// States
abstract class CoachState extends Equatable {}

class CoachInitial extends CoachState {
  @override
  List<Object?> get props => [];
}

class CoachLoading extends CoachState {
  @override
  List<Object?> get props => [];
}

class CoachDashboardLoaded extends CoachState {
  final CoachDashboardData data;
  CoachDashboardLoaded(this.data);
  @override
  List<Object?> get props => [data];
}

class OnboardingInProgress extends CoachState {
  final int currentStep;
  final OnboardingData? partialData;
  
  OnboardingInProgress({
    required this.currentStep,
    this.partialData,
  });
  
  @override
  List<Object?> get props => [currentStep, partialData];
}

class OnboardingComplete extends CoachState {
  final String curriculumPlanId;
  final WeekPreview firstWeekPreview;
  
  OnboardingComplete({
    required this.curriculumPlanId,
    required this.firstWeekPreview,
  });
  
  @override
  List<Object?> get props => [curriculumPlanId, firstWeekPreview];
}

class WeeklyPlanLoaded extends CoachState {
  final WeeklyStudyPlan plan;
  WeeklyPlanLoaded(this.plan);
  @override
  List<Object?> get props => [plan];
}

class CoachError extends CoachState {
  final String message;
  CoachError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class CoachBloc extends Bloc<CoachEvent, CoachState> {
  final CoachRepository repository;
  
  CoachBloc({required this.repository}) : super(CoachInitial()) {
    on<LoadCoachDashboard>(_onLoadDashboard);
    on<RefreshCoachDashboard>(_onRefreshDashboard);
    on<SubmitOnboardingData>(_onSubmitOnboarding);
    on<LoadWeeklyPlan>(_onLoadWeeklyPlan);
    on<TrackStudyEvent>(_onTrackStudyEvent);
    on<AcceptCoachRecommendation>(_onAcceptRecommendation);
    on<DismissCoachRecommendation>(_onDismissRecommendation);
  }
  
  Future<void> _onLoadDashboard(
    LoadCoachDashboard event,
    Emitter<CoachState> emit,
  ) async {
    emit(CoachLoading());
    
    final result = await repository.getCoachDashboard();
    
    result.fold(
      (failure) => emit(CoachError(failure.message)),
      (data) => emit(CoachDashboardLoaded(data)),
    );
  }
  
  Future<void> _onSubmitOnboarding(
    SubmitOnboardingData event,
    Emitter<CoachState> emit,
  ) async {
    emit(CoachLoading());
    
    final result = await repository.completeOnboarding(event.data);
    
    result.fold(
      (failure) => emit(CoachError(failure.message)),
      (response) => emit(OnboardingComplete(
        curriculumPlanId: response.curriculumPlanId,
        firstWeekPreview: response.firstWeekPreview,
      )),
    );
  }
  
  Future<void> _onTrackStudyEvent(
    TrackStudyEvent event,
    Emitter<CoachState> emit,
  ) async {
    // Track in background, don't block UI
    await repository.trackStudyEvent(
      studyId: event.studyId,
      eventType: event.eventType,
      eventData: event.eventData,
    );
    
    // Refresh dashboard to show updated stats
    add(RefreshCoachDashboard());
  }
  
  // ... other event handlers
}
```

---

## 7. LLM Integration

### 7.1 Prompt Templates

#### **Curriculum Generation Prompt**
```typescript
// backend/supabase/functions/_shared/prompts/curriculum-generation.ts

export const CURRICULUM_GENERATION_PROMPT = `
You are a theological expert and curriculum designer for a Bible study app.

Your task is to generate a personalized 12-week Bible study curriculum that:
1. Progressively builds on each week's learnings
2. Balances theological depth with practical application
3. Includes variety across Old Testament, New Testament, and topical studies
4. Aligns difficulty with the user's spiritual maturity level
5. Focuses on the user's stated interests and goals
6. Maintains orthodox Christian theology

USER PROFILE:
- Maturity Level: {{maturity_level}}
  * new_believer: Basic foundations, simple concepts, practical application
  * growing_christian: Deeper understanding, theological concepts, life application
  * mature_believer: Advanced theology, complex topics, ministry preparation
  * ministry_leader: Teaching depth, leadership principles, advanced exegesis

- Primary Interests: {{primary_interests}}
- Learning Style:
  * Daily Time: {{daily_minutes}} minutes
  * Preferred Time: {{preferred_time}}
  * Study Styles: {{study_styles}}
  * Difficulty: {{difficulty_preference}}

- Primary Goal: {{primary_goal}}
- Secondary Goals: {{secondary_goals}}

CURRICULUM STRUCTURE REQUIREMENTS:

1. Each week should have:
   - A clear theme that builds on previous weeks
   - 7 daily studies (one per day)
   - Mix of study types: exposition, topical, character study, practical application
   - Appropriate difficulty level
   - 3-5 key learning objectives

2. Overall curriculum should:
   - Start with foundational topics
   - Progress to more complex themes
   - Include at least 2 weeks on core doctrines (salvation, grace, faith)
   - Include at least 1 week on practical Christian living
   - Include at least 1 week on prayer/spiritual disciplines
   - End with application-focused or life-change topics

3. Topic Selection Guidelines:
   - Prioritize user's primary interests ({{primary_interests}})
   - Address user's stated goals
   - Ensure theological balance
   - Avoid controversial or divisive topics for beginners
   - Include Scripture memorization opportunities

OUTPUT FORMAT (JSON):
{
  "plan_name": "Engaging title (e.g., 'Foundations of Grace' or 'Journey to Deeper Faith')",
  "theme": "Overarching theme connecting all 12 weeks",
  "weeks": [
    {
      "week_number": 1,
      "theme": "Week theme (e.g., 'Understanding Salvation')",
      "description": "What the user will learn this week (2-3 sentences)",
      "topics": ["topic1", "topic2", "topic3"],
      "difficulty": "beginner" | "intermediate" | "advanced",
      "key_scriptures": ["Primary passage 1", "Primary passage 2"],
      "learning_objectives": [
        "Objective 1 (specific, measurable)",
        "Objective 2",
        "Objective 3"
      ],
      "daily_study_titles": [
        "Monday: Title",
        "Tuesday: Title",
        "Wednesday: Title",
        "Thursday: Title",
        "Friday: Title",
        "Saturday: Title",
        "Sunday: Title"
      ]
    },
    // ... weeks 2-12
  ]
}

IMPORTANT THEOLOGICAL GUIDELINES:
- Maintain biblical accuracy and orthodox Christian doctrine
- Present grace and salvation through faith in Jesus Christ
- Avoid legalism or works-based theology
- Balance God's justice and mercy
- Emphasize practical application of biblical truths
- Include Old and New Testament perspectives

Generate a curriculum that will genuinely help this user grow in their faith journey.
`;
```

#### **Weekly Study Generation Prompt**
```typescript
// backend/supabase/functions/_shared/prompts/weekly-study-generation.ts

export const WEEKLY_STUDY_GENERATION_PROMPT = `
You are creating detailed daily Bible studies for a specific week in a 12-week curriculum.

WEEK CONTEXT:
- Week Number: {{week_number}} of 12
- Week Theme: {{week_theme}}
- Week Description: {{week_description}}
- Learning Objectives: {{learning_objectives}}
- User's Maturity Level: {{maturity_level}}
- Daily Study Time: {{daily_minutes}} minutes

PREVIOUS WEEK'S TOPICS (if applicable):
{{previous_week_topics}}

GENERATE 7 DAILY STUDIES:

For each day (Monday-Sunday), create:
1. Study title (engaging, specific)
2. Primary Scripture passage (specific verses)
3. Secondary Scripture references (2-3 supporting passages)
4. Estimated reading time (based on user's daily minutes)
5. Study objectives (2-3 specific learning goals)
6.  4-step outline:
   - Observation questions (3-4 questions)
   - Interpretation questions (3-4 questions)
   - Application questions (2-3 questions)
   - Implementation prompts (1-2 practical action steps)

DAILY STUDY PROGRESSION:
- Monday: Introduce week theme with foundational passage
- Tuesday: Build on Monday's concepts with deeper exploration
- Wednesday: Mid-week application or practical example
- Thursday: Expand to related topics or broader context
- Friday: Challenge/growth opportunity
- Saturday: Personal reflection or testimony connection
- Sunday: Integration and preparation for next week

OUTPUT FORMAT (JSON):
{
  "week_number": {{week_number}},
  "week_theme": "{{week_theme}}",
  "intro_message": "Encouraging message for the start of this week (2-3 sentences)",
  "completion_message": "Congratulatory message for completing the week",
  "daily_studies": [
    {
      "day": "monday",
      "date": "{{monday_date}}",
      "title": "Engaging study title",
      "scripture": "Primary passage (e.g., 'John 3:16-21')",
      "secondary_scriptures": ["Romans 5:8", "1 John 4:9-10"],
      "estimated_minutes": 12,
      "difficulty": "beginner" | "intermediate" | "advanced",
      "objectives": [
        "Understand the concept of...",
        "Recognize how... applies to...",
        "Identify ways to..."
      ],
      "study_outline": {
        "observation": [
          "What does this passage tell us about...?",
          "Who are the main characters/themes?",
          "What is the context of this passage?"
        ],
        "interpretation": [
          "Why did... happen in this passage?",
          "What does... mean in this context?",
          "How does this relate to...?"
        ],
        "application": [
          "How does this truth apply to your life?",
          "What changes might God be calling you to make?"
        ],
        "implementation": [
          "This week, practice...",
          "Identify one area where you can..."
        ]
      },
      "memory_verse_suggestion": "John 3:16" // Optional
    },
    // ... 7 days total
  ]
}

QUALITY CHECKLIST:
✓ Each study builds on previous days
✓ Questions follow  methodology
✓ Appropriate difficulty for maturity level
✓ Practical application included
✓ Time estimates are realistic
✓ Theologically sound and biblical
`;
```

#### **Daily Recommendation Prompt**
```typescript
// backend/supabase/functions/_shared/prompts/daily-recommendation.ts

export const DAILY_RECOMMENDATION_PROMPT = `
You are a personal discipleship coach providing a personalized daily study introduction.

USER CONTEXT:
- Name: {{user_name}}
- Current Week: {{week_number}} of {{total_weeks}}
- Week Theme: {{week_theme}}
- Studies Completed This Week: {{studies_this_week}}
- Current Streak: {{streak_days}} days
- Recent Topics Explored: {{recent_topics}}

TODAY'S STUDY:
- Title: {{study_title}}
- Scripture: {{study_scripture}}
- Day in Week: {{day_name}}
- Objectives: {{objectives}}

YESTERDAY'S FEEDBACK (if available):
- Completed: {{yesterday_completed}}
- Rating: {{yesterday_rating}} / 5
- Difficulty Feedback: {{yesterday_difficulty}}
- Follow-up Questions Asked: {{yesterday_questions}}

Generate a personalized coach message (2-3 sentences) that:
1. Encourages the user based on their progress
2. Explains why today's study is relevant to their journey
3. Connects to yesterday's study (if applicable)
4. Maintains a warm, supportive tone

OUTPUT (plain text, 2-3 sentences):
Good morning, {{user_name}}! [Your personalized message here]

TONE GUIDELINES:
- Warm and encouraging, not preachy
- Personal and conversational
- Celebrate progress (streaks, completions)
- Connect studies to user's stated goals
- Acknowledge challenges when appropriate

EXAMPLES:
- "Great work maintaining your 15-day streak! Today we're diving deeper into grace by exploring how it transforms our relationships. This builds perfectly on yesterday's study about receiving grace."
- "Welcome to Week 3! You've shown great engagement with prayer topics. Today's study on intercessory prayer will give you practical tools to strengthen your prayer life."
- "You're halfway through this week - excellent progress! Today we're exploring forgiveness, which connects to the grace concepts you've been mastering. This might challenge you, but you're ready for it."
`;
```

### 7.2 LLM Configuration

```typescript
// backend/supabase/functions/_shared/llm-config.ts

export const LLM_CONFIG = {
  curriculum_generation: {
    model: 'gpt-4-turbo-preview',
    temperature: 0.7,
    max_tokens: 4000,
    response_format: { type: 'json_object' },
  },
  
  weekly_study_generation: {
    model: 'gpt-4-turbo-preview',
    temperature: 0.7,
    max_tokens: 3000,
    response_format: { type: 'json_object' },
  },
  
  daily_recommendation: {
    model: 'claude-haiku-20240307', // Fast, cost-effective
    temperature: 0.8,
    max_tokens: 200,
  },
  
  growth_assessment: {
    model: 'gpt-4-turbo-preview',
    temperature: 0.6,
    max_tokens: 1500,
    response_format: { type: 'json_object' },
  },
  
  adaptation_recommendation: {
    model: 'claude-haiku-20240307',
    temperature: 0.7,
    max_tokens: 500,
    response_format: { type: 'json_object' },
  },
};

// Cost estimation per operation
export const COST_PER_OPERATION = {
  curriculum_generation: 0.12, // USD (GPT-4 Turbo ~4K tokens)
  weekly_study_generation: 0.09, // USD (GPT-4 Turbo ~3K tokens)
  daily_recommendation: 0.001, // USD (Claude Haiku ~200 tokens)
  growth_assessment: 0.06, // USD (GPT-4 Turbo ~1.5K tokens)
};
```

---

## 8. Testing Strategy

### 8.1 Unit Tests

**Database Functions:**
```sql
-- Test: update_curriculum_progress trigger
BEGIN;
  -- Setup test data
  INSERT INTO curriculum_plans (id, user_id, total_weeks, total_studies)
  VALUES ('test-plan-1', 'test-user-1', 12, 84);
  
  INSERT INTO weekly_study_plans (id, curriculum_plan_id, user_id, week_number, daily_studies)
  VALUES ('test-week-1', 'test-plan-1', 'test-user-1', 1, '[
    {"day": "monday", "completed": true},
    {"day": "tuesday", "completed": true},
    {"day": "wednesday", "completed": false}
  ]'::jsonb);
  
  -- Update weekly plan
  UPDATE weekly_study_plans 
  SET studies_completed = 2 
  WHERE id = 'test-week-1';
  
  -- Assert curriculum plan updated
  SELECT * FROM curriculum_plans WHERE id = 'test-plan-1';
  -- Expected: studies_completed = 2, completion_percentage ~= 2.38
  
ROLLBACK;
```

**Flutter Models:**
```dart
// frontend/test/features/coach/data/models/coach_dashboard_model_test.dart

void main() {
  group('CoachDashboardModel', () {
    test('should deserialize from JSON correctly', () {
      final json = {
        'current_week': 3,
        'total_weeks': 12,
        'overall_completion': 25.0,
        'current_streak': 15,
        'studies_completed': 18,
        // ... more fields
      };
      
      final model = CoachDashboardModel.fromJson(json);
      
      expect(model.currentWeek, 3);
      expect(model.totalWeeks, 12);
      expect(model.overallCompletion, 25.0);
    });
    
    test('should handle missing optional fields', () {
      final json = {
        'current_week': 1,
        'total_weeks': 12,
        // Missing optional fields
      };
      
      final model = CoachDashboardModel.fromJson(json);
      
      expect(model.currentWeek, 1);
      expect(model.todayStudy, isNull);
    });
  });
}
```

### 8.2 Integration Tests

**Curriculum Generation Flow:**
```dart
// frontend/test/features/coach/integration/curriculum_generation_test.dart

void main() {
  group('Curriculum Generation Integration', () {
    testWidgets('complete onboarding and generate curriculum', (tester) async {
      // Setup
      await tester.pumpWidget(MyApp());
      
      // Navigate to onboarding
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      
      // Complete onboarding steps
      await tester.tap(find.text('Growing Christian'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      
      // Select interests
      await tester.tap(find.text('Grace'));
      await tester.tap(find.text('Prayer'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      
      // ... complete all steps
      
      // Submit onboarding
      await tester.tap(find.text('Create My Plan'));
      await tester.pumpAndSettle();
      
      // Wait for curriculum generation
      await tester.pump(Duration(seconds: 15));
      
      // Verify success
      expect(find.text('Your Journey Begins!'), findsOneWidget);
      expect(find.textContaining('12-week plan'), findsOneWidget);
    });
  });
}
```

### 8.3 E2E Tests

**Daily Study Flow:**
```dart
// frontend/test/e2e/daily_study_flow_test.dart

void main() {
  testWidgets('complete daily study from coach recommendation', (tester) async {
    // Setup authenticated user with active plan
    await setupAuthenticatedUser(tester);
    
    // Navigate to Coach tab
    await tester.tap(find.byIcon(Icons.school));
    await tester.pumpAndSettle();
    
    // Verify coach dashboard loaded
    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Today\'s Study'), findsOneWidget);
    
    // Start today's study
    await tester.tap(find.text('Start Study'));
    await tester.pumpAndSettle();
    
    // Verify study screen opened
    expect(find.text('Observation'), findsOneWidget);
    
    // Complete study (scroll through sections)
    await tester.dragUntilVisible(
      find.text('Application'),
      find.byType(SingleChildScrollView),
      Offset(0, -200),
    );
    
    await tester.dragUntilVisible(
      find.text('Mark as Complete'),
      find.byType(SingleChildScrollView),
      Offset(0, -200),
    );
    
    // Mark study complete
    await tester.tap(find.text('Mark as Complete'));
    await tester.pumpAndSettle();
    
    // Provide feedback
    await tester.tap(find.byIcon(Icons.star).at(3)); // 4 stars
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    
    // Verify analytics tracked
    // (Backend verification would be done via API inspection)
    
    // Return to coach tab
    await tester.tap(find.byIcon(Icons.school));
    await tester.pumpAndSettle();
    
    // Verify progress updated
    expect(find.textContaining('1 study completed today'), findsOneWidget);
  });
}
```

### 8.4 LLM Response Testing

**Theological Accuracy Validation:**
```typescript
// backend/supabase/functions/_tests/curriculum-validation.test.ts

describe('Curriculum Generation Validation', () => {
  it('should generate theologically sound curriculum', async () => {
    const profile = {
      maturity_level: 'growing_christian',
      primary_interests: ['grace', 'prayer'],
      // ... other fields
    };
    
    const curriculum = await generateCurriculum(profile);
    
    // Validate structure
    expect(curriculum.weeks).toHaveLength(12);
    expect(curriculum.plan_name).toBeTruthy();
    
    // Validate theological accuracy (manual review or keyword checks)
    const allTopics = curriculum.weeks.flatMap(w => w.topics);
    
    // Should include core doctrines
    expect(allTopics).toContain('grace');
    expect(allTopics).toContain('salvation');
    
    // Should not include heretical concepts
    expect(allTopics).not.toContain('works-based salvation');
    
    // Validate progression
    expect(curriculum.weeks[0].difficulty).toBe('beginner');
    expect(curriculum.weeks[11].difficulty).not.toBe('beginner');
  });
  
  it('should adapt difficulty to maturity level', async () => {
    const beginnerProfile = {
      maturity_level: 'new_believer',
      // ...
    };
    
    const advancedProfile = {
      maturity_level: 'ministry_leader',
      // ...
    };
    
    const beginnerCurriculum = await generateCurriculum(beginnerProfile);
    const advancedCurriculum = await generateCurriculum(advancedProfile);
    
    // Verify difficulty levels differ
    const beginnerDifficulties = beginnerCurriculum.weeks.map(w => w.difficulty);
    const advancedDifficulties = advancedCurriculum.weeks.map(w => w.difficulty);
    
    expect(beginnerDifficulties.filter(d => d === 'beginner').length)
      .toBeGreaterThan(advancedDifficulties.filter(d => d === 'beginner').length);
  });
});
```

---

## 9. Success Metrics

### 9.1 Feature Adoption Metrics

**Week 1-2 After Launch:**
- Onboarding completion rate: >70%
- Profile creation success rate: >95%
- First study from coach recommendation: >50%

**Month 1:**
- Active coach users: 25-30% of premium subscribers
- Daily recommendation engagement: >40%
- Weekly plan views: >60% of coach users

**Month 3:**
- 4+ weeks curriculum completion: >60% of coach users
- Daily study completion from coach: >50%
- Coach tab daily opens: >70% of coach users

### 9.2 Engagement Metrics

**Daily Engagement:**
- Studies completed via coach recommendation: >50% of all studies
- Coach insight interactions: >30% click-through rate
- Daily study streak maintenance: +40% vs. non-coach users

**Weekly Engagement:**
- Weekly plan completion: >60%
- Growth assessment views: >50% of coach users
- Adaptation acceptance rate: >60%

**Overall:**
- 30-day retention: +40% for coach users vs. non-coach
- Session duration: +60% for coach-directed studies
- Follow-up questions: +30% for coach users

### 9.3 Business Metrics

**Conversion:**
- Coach feature influence on Standard → Premium: Primary driver
- Onboarding to first study: <24 hours
- Trial to paid conversion: +20% for coach trial users

**Retention:**
- Churn rate: <5% monthly for active coach users
- Re-engagement: Coach notifications drive 2x more opens

**Revenue:**
- Premium subscription growth: +30% attributed to coach
- Average Revenue Per User (ARPU): +$3-5/month

### 9.4 Quality Metrics

**User Satisfaction:**
- Coach NPS: >50
- Study relevance rating: >4.0/5.0 average
- Perceived personalization: >80% "feels personalized"

**Technical:**
- API response time: <2s for curriculum generation
- Daily recommendation latency: <500ms
- Error rate: <1% for all coach endpoints

---

## 10. Risk Mitigation

### 10.1 Technical Risks

**Risk: LLM costs exceed budget**
- Mitigation: Aggressive caching of curricula and weekly plans
- Mitigation: Use Claude Haiku for simple operations
- Mitigation: Monitor costs daily, set alerts at $500/month threshold
- Fallback: Pre-generated curriculum templates for common profiles

**Risk: LLM generates theologically inaccurate content**
- Mitigation: Multiple validation layers in prompts
- Mitigation: Manual review of first 100 generated curricula
- Mitigation: User reporting for theological concerns
- Fallback: Human moderation queue for flagged content

**Risk: Curriculum generation too slow**
- Mitigation: Background job processing
- Mitigation: Show loading state with progress updates
- Mitigation: Cache common profile combinations
- Fallback: Faster model (GPT-3.5) for time-sensitive requests

### 10.2 Product Risks

**Risk: Users don't complete onboarding**
- Mitigation: 5-screen limit, skip option available
- Mitigation: Save progress for incomplete onboarding
- Mitigation: "Quick Start" option with defaults
- Fallback: Auto-generate basic plan without full profile

**Risk: Personalization doesn't feel personal**
- Mitigation: User testing with diverse profiles
- Mitigation: Collect feedback on relevance
- Mitigation: A/B test different prompt strategies
- Fallback: Allow manual curriculum customization

**Risk: Coach recommendations feel robotic**
- Mitigation: Warm, conversational tone in prompts
- Mitigation: Inject user-specific context (name, streak, goals)
- Mitigation: Variety in message templates
- Fallback: Human-written fallback messages

### 10.3 Business Risks

**Risk: Low conversion to premium**
- Mitigation: Offer weekend premium passes to sample coach
- Mitigation: Show coach preview in free tier
- Mitigation: Clear value communication in marketing
- Fallback: Move coach to Standard tier if adoption low

**Risk: High churn after first month**
- Mitigation: Weekly engagement hooks (new week, assessments)
- Mitigation: Adaptive difficulty prevents boredom
- Mitigation: Milestone celebrations and achievements
- Fallback: Email re-engagement campaigns

---

## 11. Launch Checklist

### Pre-Launch (1 week before)

- [ ] All unit tests passing (>80% coverage)
- [ ] Integration tests passing
- [ ] E2E tests passing on iOS, Android, Web
- [ ] Manual QA on 5+ device types
- [ ] Load testing (100 concurrent users)
- [ ] Theological review of sample curricula
- [ ] Legal review of AI-generated content
- [ ] Privacy policy updated
- [ ] Help documentation written
- [ ] Marketing materials prepared
- [ ] Customer support trained
- [ ] Monitoring dashboards configured
- [ ] Error tracking integrated (Sentry)
- [ ] Analytics events verified
- [ ] Beta testing with 20 users complete

### Launch Day

- [ ] Deploy backend to production
- [ ] Deploy frontend to app stores
- [ ] Verify all Edge Functions operational
- [ ] Test end-to-end flow in production
- [ ] Monitor error rates
- [ ] Monitor API response times
- [ ] Monitor LLM costs
- [ ] Send launch announcement
- [ ] Monitor user feedback channels
- [ ] Standby for hotfixes

### Post-Launch (Week 1)

- [ ] Daily metrics review
- [ ] User feedback collection
- [ ] Bug triage and fixes
- [ ] Cost analysis
- [ ] Performance optimization
- [ ] Success criteria evaluation
- [ ] Plan iteration 2 improvements

---

## 12. Future Enhancements

### Version 2.0 (Post-Launch + 3 months)

**Advanced Personalization:**
- AI analysis of chat questions to refine interests
- Collaborative filtering (recommend topics liked by similar users)
- Seasonal curricula (Advent, Lent, Easter)

**Social Features:**
- Share your journey with friends
- Group coaching for Study Circles
- Leaderboards for streaks/completions

**Content Expansion:**
- Video study content
- Audio devotionals
- Expert teacher integrations

**AI Enhancements:**
- Voice conversation with coach
- Image-based study notes (AI-generated visuals)
- Personalized memory verse selection

---

**Document Status:** ✅ Complete - Ready for Development

**Next Steps:**
1. Review with product and engineering teams
2. Finalize resource allocation
3. Begin Phase 1 development
4. Schedule weekly sprint reviews

---

*End of Personal Discipleship Coach Technical Specification v1.0*
