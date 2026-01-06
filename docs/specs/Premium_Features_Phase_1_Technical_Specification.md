# Premium Features Phase 1 - Technical Specification

**Document Version:** 1.0
**Last Updated:** November 9, 2025
**Status:** Draft
**Owner:** Engineering Team

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture & Design Principles](#architecture--design-principles)
3. [Feature 1: Daily Verse Streak](#feature-1-daily-verse-streak)
4. [Feature 2: Study Guide Preview Mode](#feature-2-study-guide-preview-mode)
5. [Feature 3: Memory Verses SRS](#feature-3-memory-verses-srs)
6. [Database Schema](#database-schema)
7. [API Endpoints](#api-endpoints)
8. [Frontend Implementation](#frontend-implementation)
9. [State Management](#state-management)
10. [Analytics & Metrics](#analytics--metrics)
11. [Testing Requirements](#testing-requirements)
12. [Security Considerations](#security-considerations)
13. [Performance Requirements](#performance-requirements)
14. [Rollout Strategy](#rollout-strategy)

---

## Overview

### Phase 1 Goals

**Timeline:** Months 1-2 (8 weeks)
**Objective:** Deliver immediate engagement boost through quick wins that demonstrate value and drive conversions

**Success Metrics:**
- +30% daily active users
- +20% daily opens through streak feature
- 10-15% free → standard conversion rate
- 5+ minutes average daily engagement

### Features Summary

| Feature | Tier | Development Time | Priority |
|---------|------|------------------|----------|
| Daily Verse Streak | Free | 2 weeks | P0 |
| Study Guide Preview Mode | Free | 1 week | P0 |
| Memory Verses SRS | Standard | 4 weeks | P0 |

---

## Architecture & Design Principles

### Clean Architecture Compliance

All features must follow the established Clean Architecture pattern:

```
Presentation Layer (UI/BLoC)
    ↓
Domain Layer (Entities/Use Cases)
    ↓
Data Layer (Repositories/Data Sources)
```

### Design Patterns

1. **BLoC Pattern** - All state management via event-driven BLoC
2. **Repository Pattern** - Single source of truth for data operations
3. **Dependency Injection** - GetIt for all service registration
4. **Single Responsibility** - Each class has one clear purpose
5. **Offline-First** - Local caching with background sync

### Technology Stack

**Frontend:**
- Flutter 3.x
- flutter_bloc 8.x
- Hive for local storage
- shared_preferences for simple key-value storage

**Backend:**
- Supabase PostgreSQL
- Supabase Edge Functions (Deno/TypeScript)
- Row Level Security (RLS) policies

**Analytics:**
- Custom event tracking via Supabase Analytics
- Daily aggregation for metrics dashboard

---

## Feature 1: Daily Verse Streak

### Overview

Gamified daily engagement feature that tracks consecutive days a user views their daily verse. Increases retention through commitment and consistency patterns (Duolingo-style).

**User Story:**
> As a user, I want to maintain a daily verse reading streak so that I stay motivated to engage with Scripture every day.

### User Flow

```
1. User opens app
   ↓
2. Daily Verse Card displays with current streak count
   ↓
3. User taps to view verse details (marks as "viewed" for the day)
   ↓
4. Streak counter increments if consecutive day
   ↓
5. Badge/animation celebrates milestone streaks (7, 30, 100 days)
```

### Business Logic

**Streak Calculation Rules:**
1. **New Streak:** First daily verse view = 1 day streak
2. **Continuation:** Daily verse viewed on consecutive calendar day = streak increments
3. **Break:** Miss a calendar day = streak resets to 0
4. **Timezone:** Use user's local timezone for day boundaries
5. **Grace Period:** None (strict consecutive day requirement)

**Milestone Celebrations:**
- 🔥 7 days: "Week Warrior" badge
- ✨ 30 days: "Monthly Master" badge
- 🏆 100 days: "Century Scholar" badge
- 🌟 365 days: "Yearly Champion" badge

### Data Model

**Entity: `DailyVerseStreak`**

```dart
class DailyVerseStreak {
  final String userId;
  final int currentStreak;      // Current consecutive days
  final int longestStreak;      // Personal best
  final DateTime lastViewedAt;  // Last time daily verse was viewed
  final int totalViews;         // Lifetime daily verse views
  final List<String> badges;    // Earned milestone badges
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyVerseStreak({
    required this.userId,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastViewedAt,
    required this.totalViews,
    required this.badges,
    required this.createdAt,
    required this.updatedAt,
  });
}
```

### Database Schema

**Table: `daily_verse_streaks`**

```sql
CREATE TABLE daily_verse_streaks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  current_streak INTEGER NOT NULL DEFAULT 0,
  longest_streak INTEGER NOT NULL DEFAULT 0,
  last_viewed_at TIMESTAMPTZ NOT NULL,
  total_views INTEGER NOT NULL DEFAULT 0,
  badges TEXT[] DEFAULT ARRAY[]::TEXT[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT daily_verse_streaks_user_id_key UNIQUE(user_id),
  CONSTRAINT daily_verse_streaks_current_streak_check CHECK (current_streak >= 0),
  CONSTRAINT daily_verse_streaks_longest_streak_check CHECK (longest_streak >= 0),
  CONSTRAINT daily_verse_streaks_total_views_check CHECK (total_views >= 0)
);

-- Index for efficient user lookups
CREATE INDEX idx_daily_verse_streaks_user_id ON daily_verse_streaks(user_id);

-- Index for leaderboard queries
CREATE INDEX idx_daily_verse_streaks_current_streak ON daily_verse_streaks(current_streak DESC);

-- RLS Policies
ALTER TABLE daily_verse_streaks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own streak"
  ON daily_verse_streaks FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own streak"
  ON daily_verse_streaks FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own streak"
  ON daily_verse_streaks FOR UPDATE
  USING (auth.uid() = user_id);
```

### API Endpoint

**Endpoint:** `POST /functions/v1/daily-verse-viewed`

**Request:**
```typescript
{
  // No body required - user identified via JWT
}
```

**Response:**
```typescript
{
  success: true,
  data: {
    current_streak: 7,
    longest_streak: 15,
    total_views: 42,
    last_viewed_at: "2025-11-09T10:30:00Z",
    badges: ["week_warrior", "monthly_master"],
    new_badge: "week_warrior" | null,  // If just earned
    streak_broken: false
  }
}
```

**Edge Function Logic:**

```typescript
// /supabase/functions/daily-verse-viewed/index.ts

import { createClient } from '@supabase/supabase-js';
import { corsHeaders } from '../_shared/cors.ts';

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get authenticated user
    const authHeader = req.headers.get('Authorization')!;
    const token = authHeader.replace('Bearer ', '');
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser(token);
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const userId = user.id;
    const now = new Date();

    // Get existing streak data
    const { data: existingStreak, error: fetchError } = await supabase
      .from('daily_verse_streaks')
      .select('*')
      .eq('user_id', userId)
      .single();

    if (fetchError && fetchError.code !== 'PGRST116') { // PGRST116 = no rows
      throw fetchError;
    }

    let currentStreak = 0;
    let longestStreak = 0;
    let totalViews = 0;
    let badges: string[] = [];
    let newBadge: string | null = null;
    let streakBroken = false;

    if (existingStreak) {
      const lastViewed = new Date(existingStreak.last_viewed_at);
      const daysSinceLastView = Math.floor((now.getTime() - lastViewed.getTime()) / (1000 * 60 * 60 * 24));

      // Check if already viewed today (prevent multiple increments)
      if (daysSinceLastView === 0) {
        // Already viewed today - return current data
        return new Response(
          JSON.stringify({
            success: true,
            data: {
              current_streak: existingStreak.current_streak,
              longest_streak: existingStreak.longest_streak,
              total_views: existingStreak.total_views,
              last_viewed_at: existingStreak.last_viewed_at,
              badges: existingStreak.badges,
              new_badge: null,
              streak_broken: false,
              already_viewed_today: true
            }
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Check if streak continues (consecutive day = 1 day difference)
      if (daysSinceLastView === 1) {
        currentStreak = existingStreak.current_streak + 1;
      } else {
        // Streak broken
        currentStreak = 1;
        streakBroken = true;
      }

      longestStreak = Math.max(currentStreak, existingStreak.longest_streak);
      totalViews = existingStreak.total_views + 1;
      badges = [...existingStreak.badges];

      // Check for new badges
      if (currentStreak === 7 && !badges.includes('week_warrior')) {
        badges.push('week_warrior');
        newBadge = 'week_warrior';
      }
      if (currentStreak === 30 && !badges.includes('monthly_master')) {
        badges.push('monthly_master');
        newBadge = 'monthly_master';
      }
      if (currentStreak === 100 && !badges.includes('century_scholar')) {
        badges.push('century_scholar');
        newBadge = 'century_scholar';
      }
      if (currentStreak === 365 && !badges.includes('yearly_champion')) {
        badges.push('yearly_champion');
        newBadge = 'yearly_champion';
      }

      // Update existing streak
      const { error: updateError } = await supabase
        .from('daily_verse_streaks')
        .update({
          current_streak: currentStreak,
          longest_streak: longestStreak,
          last_viewed_at: now.toISOString(),
          total_views: totalViews,
          badges: badges,
          updated_at: now.toISOString()
        })
        .eq('user_id', userId);

      if (updateError) throw updateError;
    } else {
      // First time viewing - create new streak
      currentStreak = 1;
      longestStreak = 1;
      totalViews = 1;
      badges = [];

      const { error: insertError } = await supabase
        .from('daily_verse_streaks')
        .insert({
          user_id: userId,
          current_streak: currentStreak,
          longest_streak: longestStreak,
          last_viewed_at: now.toISOString(),
          total_views: totalViews,
          badges: badges
        });

      if (insertError) throw insertError;
    }

    // Return updated streak data
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          current_streak: currentStreak,
          longest_streak: longestStreak,
          total_views: totalViews,
          last_viewed_at: now.toISOString(),
          badges: badges,
          new_badge: newBadge,
          streak_broken: streakBroken
        }
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error in daily-verse-viewed:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
```

### Frontend Implementation

**Location:** `frontend/lib/features/daily_verse/`

**New Files:**
```
features/daily_verse/
├── data/
│   ├── datasources/
│   │   └── streak_local_datasource.dart
│   ├── models/
│   │   └── daily_verse_streak_model.dart
│   └── repositories/
│       └── streak_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── daily_verse_streak.dart
│   ├── repositories/
│   │   └── streak_repository.dart
│   └── usecases/
│       ├── get_streak.dart
│       └── record_daily_verse_view.dart
└── presentation/
    ├── bloc/
    │   ├── streak_bloc.dart
    │   ├── streak_event.dart
    │   └── streak_state.dart
    └── widgets/
        ├── streak_counter_badge.dart
        └── milestone_celebration_dialog.dart
```

**BLoC Events:**

```dart
abstract class StreakEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadStreak extends StreakEvent {}

class RecordDailyVerseView extends StreakEvent {}

class ResetStreak extends StreakEvent {}
```

**BLoC States:**

```dart
abstract class StreakState extends Equatable {
  @override
  List<Object?> get props => [];
}

class StreakInitial extends StreakState {}

class StreakLoading extends StreakState {}

class StreakLoaded extends StreakState {
  final DailyVerseStreak streak;
  final String? newBadge;
  final bool streakBroken;

  StreakLoaded({
    required this.streak,
    this.newBadge,
    this.streakBroken = false,
  });

  @override
  List<Object?> get props => [streak, newBadge, streakBroken];
}

class StreakError extends StreakState {
  final String message;

  StreakError({required this.message});

  @override
  List<Object?> get props => [message];
}
```

**UI Integration in Daily Verse Card:**

```dart
// In daily_verse_card.dart

BlocBuilder<StreakBloc, StreakState>(
  builder: (context, state) {
    if (state is StreakLoaded) {
      return StreakCounterBadge(
        currentStreak: state.streak.currentStreak,
        longestStreak: state.streak.longestStreak,
        onTap: () {
          // Show streak details dialog
          _showStreakDetailsDialog(context, state.streak);
        },
      );
    }
    return const SizedBox.shrink();
  },
)
```

**Streak Counter Badge Widget:**

```dart
class StreakCounterBadge extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final VoidCallback onTap;

  const StreakCounterBadge({
    Key? key,
    required this.currentStreak,
    required this.longestStreak,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🔥',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 6),
            Text(
              '$currentStreak',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'day${currentStreak != 1 ? 's' : ''}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Analytics Events

```dart
// Track streak milestone achievements
Analytics.logEvent('streak_milestone', parameters: {
  'user_id': userId,
  'milestone': 'week_warrior', // or monthly_master, etc.
  'current_streak': 7,
  'total_views': 42,
});

// Track streak breaks
Analytics.logEvent('streak_broken', parameters: {
  'user_id': userId,
  'previous_streak': 15,
  'days_missed': 2,
});

// Track daily verse views
Analytics.logEvent('daily_verse_viewed', parameters: {
  'user_id': userId,
  'current_streak': 7,
  'already_viewed_today': false,
});
```

---

## Feature 2: Study Guide Preview Mode

### Overview

Allow free users to preview the first section of any study guide before requiring authentication or premium access. Reduces friction and increases conversion by demonstrating value upfront.

**User Story:**
> As a free user, I want to preview study guides so that I can see the quality and decide if I want to create an account or upgrade.

### User Flow

```
1. User lands on Study Guide page (authenticated or anonymous)
   ↓
2. First section is fully visible and interactive
   ↓
3. Subsequent sections show blurred preview with "Unlock Full Guide" CTA
   ↓
4. Tapping CTA triggers authentication flow (if not logged in)
   ↓
5. After auth, full guide unlocks
```

### Business Logic

**Preview Rules:**
1. **Always Available:** First section (Introduction) always accessible
2. **Blur Threshold:** Sections 2+ show 3 lines of text then blur
3. **Interactive Elements:** Follow-up chat disabled in preview mode
4. **CTA Placement:** Sticky bottom banner + inline CTAs between sections

**Conversion Tracking:**
- Track preview views
- Track CTA taps
- Track successful conversions (preview → full access)
- A/B test CTA copy

### Data Model

No new database entities required. Use existing `study_guides` table with client-side logic.

**Client-Side Logic:**

```dart
class StudyGuidePreviewLogic {
  static bool isSectionUnlocked(int sectionIndex, bool isAuthenticated) {
    // First section always unlocked
    if (sectionIndex == 0) return true;

    // Authenticated users see all sections
    return isAuthenticated;
  }

  static bool shouldShowBlur(int sectionIndex, bool isAuthenticated) {
    return !isSectionUnlocked(sectionIndex, isAuthenticated);
  }
}
```

### Frontend Implementation

**Modified Files:**
- `frontend/lib/features/study_guide/presentation/pages/study_guide_page.dart`
- `frontend/lib/features/study_guide/presentation/widgets/study_guide_section_card.dart`

**New Widgets:**
```
features/study_guide/
└── presentation/
    └── widgets/
        ├── preview_blur_overlay.dart
        └── unlock_guide_cta_banner.dart
```

**Preview Blur Overlay Widget:**

```dart
class PreviewBlurOverlay extends StatelessWidget {
  final Widget child;
  final bool shouldBlur;
  final VoidCallback onUnlockTap;

  const PreviewBlurOverlay({
    Key? key,
    required this.child,
    required this.shouldBlur,
    required this.onUnlockTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!shouldBlur) return child;

    return Stack(
      children: [
        // Blurred content
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Opacity(
              opacity: 0.3,
              child: child,
            ),
          ),
        ),

        // Unlock CTA
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
                ],
                stops: const [0.0, 0.5],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sign in to unlock full study guide',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: onUnlockTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: Text(
                      'Sign In to Continue',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

**Usage in Study Guide Page:**

```dart
// In study_guide_page.dart

ListView.builder(
  itemCount: sections.length,
  itemBuilder: (context, index) {
    final section = sections[index];
    final isUnlocked = StudyGuidePreviewLogic.isSectionUnlocked(
      index,
      isAuthenticated,
    );
    final shouldBlur = StudyGuidePreviewLogic.shouldShowBlur(
      index,
      isAuthenticated,
    );

    return PreviewBlurOverlay(
      shouldBlur: shouldBlur,
      onUnlockTap: () => _handleUnlockTap(context),
      child: StudyGuideSectionCard(
        section: section,
        isInteractive: isUnlocked,
      ),
    );
  },
)
```

### Analytics Events

```dart
// Track preview views
Analytics.logEvent('study_guide_preview_viewed', parameters: {
  'guide_id': guideId,
  'user_authenticated': isAuthenticated,
});

// Track unlock CTA taps
Analytics.logEvent('preview_unlock_tapped', parameters: {
  'guide_id': guideId,
  'section_index': sectionIndex,
  'cta_location': 'inline', // or 'banner'
});

// Track conversions
Analytics.logEvent('preview_converted', parameters: {
  'guide_id': guideId,
  'time_to_conversion_seconds': timeElapsed,
});
```

---

## Feature 3: Memory Verses SRS

### Overview

**Spaced Repetition System (SRS)** for Scripture memorization using scientifically-proven algorithm. Premium Standard tier feature that provides high-value differentiation.

**User Story:**
> As a standard subscriber, I want to memorize Bible verses using proven techniques so that I retain Scripture long-term.

### User Flow

```
1. User navigates to "Memory Verses" tab (Standard tier required)
   ↓
2. User adds verse to memory deck (from study guides or manual entry)
   ↓
3. System schedules review based on SRS algorithm
   ↓
4. User receives daily review session with due cards
   ↓
5. User rates recall difficulty (Again, Hard, Good, Easy)
   ↓
6. Algorithm adjusts next review interval
   ↓
7. Progress dashboard shows retention stats
```

### SRS Algorithm

**Modified SM-2 Algorithm (Optimized for Bible Verse Memorization):**

```
Review Schedule (Quality-Based):

Quality Rating (0-5):
- 0: Complete blackout
- 1: Incorrect response, correct answer seemed familiar
- 2: Incorrect response, correct answer remembered
- 3: Correct response, but required significant effort
- 4: Correct response, after some hesitation
- 5: Perfect recall

Interval Calculation:
- Quality < 3 (failed recall):
  * Reset to daily review (interval = 1 day)
  * Reset repetitions to 0
  * Continue ease factor calculation

- Quality >= 3 (successful recall):
  * Increment repetitions count
  * First 14 successful reviews: Daily review (interval = 1 day)
  * After mastery (15+ reviews): Progressive spacing
    - Review 15: 3 days
    - Review 16: 7 days
    - Review 17: 14 days
    - Review 18: 21 days
    - Review 19: 30 days
    - Review 20: 45 days
    - Review 21: 60 days
    - Review 22: 90 days
    - Review 23: 120 days
    - Review 24: 150 days
    - Review 25+: 180 days (maximum cap)

Ease Factor Calculation:
- Formula: EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
- Updated on every review regardless of success/failure
- Used for difficulty tracking and UI display

Initial Values:
- easeFactor = 2.5 (difficulty multiplier)
- interval = 1 day (first review)
- repetitions = 0

Constraints:
- easeFactor >= 1.3 (minimum)
- interval >= 1 day
- interval <= 180 days (6 months maximum)
- All verses reviewed at least every 6 months

Rationale:
- Daily reviews for first 2 weeks cement new verses in memory
- Gradual spacing after mastery prevents forgetting
- 6-month maximum ensures long-term retention
- Failed reviews reset to daily for re-learning
```

### Data Model

**Entity: `MemoryVerse`**

```dart
class MemoryVerse {
  final String id;
  final String userId;
  final String reference;       // e.g., "John 3:16"
  final String text;            // Full verse text
  final String translation;     // e.g., "NIV", "KJV"
  final double easeFactor;      // SM-2 difficulty (1.3 - 3.0)
  final int interval;           // Days until next review
  final DateTime nextReviewAt;  // When card is due
  final int reviewCount;        // Total reviews completed
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoryVerse({
    required this.id,
    required this.userId,
    required this.reference,
    required this.text,
    required this.translation,
    required this.easeFactor,
    required this.interval,
    required this.nextReviewAt,
    required this.reviewCount,
    required this.createdAt,
    required this.updatedAt,
  });
}

class ReviewSession {
  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int cardsReviewed;
  final int cardsCorrect;
  final int cardsDifficult;
  final int cardsForgotten;

  const ReviewSession({
    required this.id,
    required this.userId,
    required this.startedAt,
    this.completedAt,
    required this.cardsReviewed,
    required this.cardsCorrect,
    required this.cardsDifficult,
    required this.cardsForgotten,
  });
}
```

### Database Schema

**Table: `memory_verses`**

```sql
CREATE TABLE memory_verses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reference TEXT NOT NULL,
  text TEXT NOT NULL,
  translation TEXT NOT NULL DEFAULT 'NIV',
  ease_factor DECIMAL(3,2) NOT NULL DEFAULT 2.5,
  interval INTEGER NOT NULL DEFAULT 1,
  next_review_at TIMESTAMPTZ NOT NULL,
  review_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT memory_verses_ease_factor_check CHECK (ease_factor >= 1.3 AND ease_factor <= 3.0),
  CONSTRAINT memory_verses_interval_check CHECK (interval >= 1),
  CONSTRAINT memory_verses_review_count_check CHECK (review_count >= 0)
);

-- Index for efficient user queries
CREATE INDEX idx_memory_verses_user_id ON memory_verses(user_id);

-- Index for due card queries
CREATE INDEX idx_memory_verses_next_review ON memory_verses(user_id, next_review_at);

-- RLS Policies
ALTER TABLE memory_verses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own memory verses"
  ON memory_verses FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own memory verses"
  ON memory_verses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own memory verses"
  ON memory_verses FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own memory verses"
  ON memory_verses FOR DELETE
  USING (auth.uid() = user_id);
```

**Table: `review_sessions`**

```sql
CREATE TABLE review_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  cards_reviewed INTEGER NOT NULL DEFAULT 0,
  cards_correct INTEGER NOT NULL DEFAULT 0,
  cards_difficult INTEGER NOT NULL DEFAULT 0,
  cards_forgotten INTEGER NOT NULL DEFAULT 0,

  CONSTRAINT review_sessions_cards_check CHECK (
    cards_reviewed = cards_correct + cards_difficult + cards_forgotten
  )
);

-- Index for user session queries
CREATE INDEX idx_review_sessions_user_id ON review_sessions(user_id, started_at DESC);

-- RLS Policies
ALTER TABLE review_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own review sessions"
  ON review_sessions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own review sessions"
  ON review_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own review sessions"
  ON review_sessions FOR UPDATE
  USING (auth.uid() = user_id);
```

### API Endpoints

**1. Get Due Cards**

**Endpoint:** `GET /functions/v1/memory-verses/due`

**Response:**
```typescript
{
  success: true,
  data: {
    due_count: 5,
    verses: [
      {
        id: "uuid",
        reference: "John 3:16",
        text: "For God so loved the world...",
        translation: "NIV",
        next_review_at: "2025-11-09T10:00:00Z"
      }
    ]
  }
}
```

**2. Submit Review**

**Endpoint:** `POST /functions/v1/memory-verses/review`

**Request:**
```typescript
{
  verse_id: "uuid",
  rating: "good" | "again" | "hard" | "easy"
}
```

**Response:**
```typescript
{
  success: true,
  data: {
    next_review_at: "2025-11-14T10:00:00Z",
    new_interval: 5,
    ease_factor: 2.5
  }
}
```

**3. Add Memory Verse**

**Endpoint:** `POST /functions/v1/memory-verses`

**Request:**
```typescript
{
  reference: "John 3:16",
  text: "For God so loved the world...",
  translation: "NIV"
}
```

**Response:**
```typescript
{
  success: true,
  data: {
    id: "uuid",
    reference: "John 3:16",
    next_review_at: "2025-11-10T10:00:00Z"
  }
}
```

### Frontend Implementation

**Location:** `frontend/lib/features/memory_verses/`

**Directory Structure:**
```
features/memory_verses/
├── data/
│   ├── datasources/
│   │   ├── memory_verse_local_datasource.dart
│   │   └── memory_verse_remote_datasource.dart
│   ├── models/
│   │   ├── memory_verse_model.dart
│   │   └── review_session_model.dart
│   └── repositories/
│       └── memory_verse_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── memory_verse.dart
│   │   └── review_session.dart
│   ├── repositories/
│   │   └── memory_verse_repository.dart
│   └── usecases/
│       ├── add_memory_verse.dart
│       ├── get_due_cards.dart
│       ├── submit_review.dart
│       └── get_review_stats.dart
└── presentation/
    ├── bloc/
    │   ├── memory_verse_bloc.dart
    │   ├── memory_verse_event.dart
    │   └── memory_verse_state.dart
    ├── pages/
    │   ├── memory_verses_page.dart
    │   └── review_session_page.dart
    └── widgets/
        ├── memory_verse_card.dart
        ├── review_rating_buttons.dart
        ├── progress_dashboard.dart
        └── add_verse_dialog.dart
```

**Review Session Page:**

```dart
class ReviewSessionPage extends StatefulWidget {
  final List<MemoryVerse> dueCards;

  const ReviewSessionPage({Key? key, required this.dueCards}) : super(key: key);

  @override
  State<ReviewSessionPage> createState() => _ReviewSessionPageState();
}

class _ReviewSessionPageState extends State<ReviewSessionPage> {
  int currentCardIndex = 0;
  bool showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final currentCard = widget.dueCards[currentCardIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Review Session'),
        subtitle: Text('${currentCardIndex + 1} / ${widget.dueCards.length}'),
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (currentCardIndex + 1) / widget.dueCards.length,
          ),

          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Verse reference
                    Text(
                      currentCard.reference,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Verse text (tap to reveal)
                    GestureDetector(
                      onTap: () => setState(() => showAnswer = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: showAnswer
                              ? Colors.transparent
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: showAnswer
                            ? Text(
                                currentCard.text,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  height: 1.6,
                                ),
                                textAlign: TextAlign.center,
                              )
                            : Text(
                                'Tap to reveal verse',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Rating buttons (only show after answer revealed)
                    if (showAnswer)
                      ReviewRatingButtons(
                        onRate: (rating) => _handleRating(rating),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleRating(String rating) {
    // Submit review via BLoC
    context.read<MemoryVerseBloc>().add(
      SubmitReview(
        verseId: widget.dueCards[currentCardIndex].id,
        rating: rating,
      ),
    );

    // Move to next card or complete session
    if (currentCardIndex < widget.dueCards.length - 1) {
      setState(() {
        currentCardIndex++;
        showAnswer = false;
      });
    } else {
      // Session complete
      _completeSession();
    }
  }

  void _completeSession() {
    // Show completion dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Complete! 🎉'),
        content: const Text('Great work! Keep up the daily practice.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
```

**Review Rating Buttons:**

```dart
class ReviewRatingButtons extends StatelessWidget {
  final Function(String) onRate;

  const ReviewRatingButtons({Key? key, required this.onRate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'How well did you recall this verse?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildRatingButton(
              context,
              label: 'Again',
              color: Colors.red,
              icon: Icons.close,
              onTap: () => onRate('again'),
            ),
            _buildRatingButton(
              context,
              label: 'Hard',
              color: Colors.orange,
              icon: Icons.sentiment_dissatisfied,
              onTap: () => onRate('hard'),
            ),
            _buildRatingButton(
              context,
              label: 'Good',
              color: Colors.blue,
              icon: Icons.sentiment_satisfied,
              onTap: () => onRate('good'),
            ),
            _buildRatingButton(
              context,
              label: 'Easy',
              color: Colors.green,
              icon: Icons.sentiment_very_satisfied,
              onTap: () => onRate('easy'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingButton(
    BuildContext context, {
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Analytics Events

```dart
// Track verse added
Analytics.logEvent('memory_verse_added', parameters: {
  'user_id': userId,
  'reference': reference,
  'source': 'study_guide', // or 'manual'
});

// Track review session started
Analytics.logEvent('review_session_started', parameters: {
  'user_id': userId,
  'due_cards': dueCount,
});

// Track review submitted
Analytics.logEvent('verse_reviewed', parameters: {
  'user_id': userId,
  'verse_id': verseId,
  'rating': rating,
  'review_count': reviewCount,
});

// Track retention stats
Analytics.logEvent('retention_milestone', parameters: {
  'user_id': userId,
  'verses_mastered': 10, // interval >= 30 days
  'avg_retention_rate': 0.85,
});
```

---

## Database Schema

**Summary of all new tables:**

1. `daily_verse_streaks` - User streak tracking
2. `memory_verses` - SRS verse cards
3. `review_sessions` - Review session history

**Migration Script:**

```sql
-- Migration: phase_1_premium_features
-- Created: 2025-11-09

BEGIN;

-- ============================================================================
-- Table: daily_verse_streaks
-- ============================================================================

CREATE TABLE IF NOT EXISTS daily_verse_streaks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  current_streak INTEGER NOT NULL DEFAULT 0,
  longest_streak INTEGER NOT NULL DEFAULT 0,
  last_viewed_at TIMESTAMPTZ NOT NULL,
  total_views INTEGER NOT NULL DEFAULT 0,
  badges TEXT[] DEFAULT ARRAY[]::TEXT[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT daily_verse_streaks_user_id_key UNIQUE(user_id),
  CONSTRAINT daily_verse_streaks_current_streak_check CHECK (current_streak >= 0),
  CONSTRAINT daily_verse_streaks_longest_streak_check CHECK (longest_streak >= 0),
  CONSTRAINT daily_verse_streaks_total_views_check CHECK (total_views >= 0)
);

CREATE INDEX IF NOT EXISTS idx_daily_verse_streaks_user_id
  ON daily_verse_streaks(user_id);

CREATE INDEX IF NOT EXISTS idx_daily_verse_streaks_current_streak
  ON daily_verse_streaks(current_streak DESC);

ALTER TABLE daily_verse_streaks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own streak"
  ON daily_verse_streaks FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own streak"
  ON daily_verse_streaks FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own streak"
  ON daily_verse_streaks FOR UPDATE
  USING (auth.uid() = user_id);

-- ============================================================================
-- Table: memory_verses
-- ============================================================================

CREATE TABLE IF NOT EXISTS memory_verses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reference TEXT NOT NULL,
  text TEXT NOT NULL,
  translation TEXT NOT NULL DEFAULT 'NIV',
  ease_factor DECIMAL(3,2) NOT NULL DEFAULT 2.5,
  interval INTEGER NOT NULL DEFAULT 1,
  next_review_at TIMESTAMPTZ NOT NULL,
  review_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT memory_verses_ease_factor_check CHECK (ease_factor >= 1.3 AND ease_factor <= 3.0),
  CONSTRAINT memory_verses_interval_check CHECK (interval >= 1),
  CONSTRAINT memory_verses_review_count_check CHECK (review_count >= 0)
);

CREATE INDEX IF NOT EXISTS idx_memory_verses_user_id
  ON memory_verses(user_id);

CREATE INDEX IF NOT EXISTS idx_memory_verses_next_review
  ON memory_verses(user_id, next_review_at);

ALTER TABLE memory_verses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own memory verses"
  ON memory_verses FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own memory verses"
  ON memory_verses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own memory verses"
  ON memory_verses FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own memory verses"
  ON memory_verses FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- Table: review_sessions
-- ============================================================================

CREATE TABLE IF NOT EXISTS review_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  cards_reviewed INTEGER NOT NULL DEFAULT 0,
  cards_correct INTEGER NOT NULL DEFAULT 0,
  cards_difficult INTEGER NOT NULL DEFAULT 0,
  cards_forgotten INTEGER NOT NULL DEFAULT 0,

  CONSTRAINT review_sessions_cards_check CHECK (
    cards_reviewed = cards_correct + cards_difficult + cards_forgotten
  )
);

CREATE INDEX IF NOT EXISTS idx_review_sessions_user_id
  ON review_sessions(user_id, started_at DESC);

ALTER TABLE review_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own review sessions"
  ON review_sessions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own review sessions"
  ON review_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own review sessions"
  ON review_sessions FOR UPDATE
  USING (auth.uid() = user_id);

COMMIT;
```

---

## API Endpoints

**Summary of all new endpoints:**

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/functions/v1/daily-verse-viewed` | Record daily verse view | Yes |
| GET | `/functions/v1/memory-verses/due` | Get due review cards | Yes |
| POST | `/functions/v1/memory-verses` | Add memory verse | Yes |
| POST | `/functions/v1/memory-verses/review` | Submit review rating | Yes |
| GET | `/functions/v1/memory-verses/stats` | Get retention stats | Yes |

---

## State Management

### BLoC Architecture

All features use BLoC pattern with the following structure:

**Events:**
- User actions (button taps, form submissions)
- System events (initialization, data updates)

**States:**
- Initial, Loading, Loaded, Error states
- Each state immutable with Equatable

**Transitions:**
```
Event → BLoC Logic → State Emission → UI Rebuild
```

### Dependency Injection

```dart
// In injection_container.dart

// Daily Verse Streak
sl.registerLazySingleton(() => StreakRepository(
  localDataSource: sl(),
  remoteDataSource: sl(),
));
sl.registerFactory(() => GetStreak(repository: sl()));
sl.registerFactory(() => RecordDailyVerseView(repository: sl()));
sl.registerFactory(() => StreakBloc(
  getStreak: sl(),
  recordView: sl(),
));

// Memory Verses
sl.registerLazySingleton(() => MemoryVerseRepository(
  localDataSource: sl(),
  remoteDataSource: sl(),
));
sl.registerFactory(() => GetDueCards(repository: sl()));
sl.registerFactory(() => SubmitReview(repository: sl()));
sl.registerFactory(() => AddMemoryVerse(repository: sl()));
sl.registerFactory(() => MemoryVerseBloc(
  getDueCards: sl(),
  submitReview: sl(),
  addVerse: sl(),
));
```

---

## Analytics & Metrics

### Key Performance Indicators (KPIs)

**Phase 1 Success Metrics:**

| Metric | Baseline | Target | Tracking Frequency |
|--------|----------|--------|-------------------|
| Daily Active Users | Current | +30% | Daily |
| Daily Verse Opens | Current | +20% | Daily |
| Free → Standard Conversion | 5% | 10-15% | Weekly |
| Average Session Time | 3 min | 5+ min | Daily |
| Streak Retention (7+ days) | N/A | 40% | Weekly |
| SRS Cards Mastered | N/A | 10 avg/user | Monthly |

### Analytics Events

**Custom Events:**

```typescript
// Daily Verse Streak
- 'streak_milestone'      // Badge earned
- 'streak_broken'         // Streak lost
- 'daily_verse_viewed'    // Verse opened

// Study Guide Preview
- 'study_guide_preview_viewed'
- 'preview_unlock_tapped'
- 'preview_converted'

// Memory Verses SRS
- 'memory_verse_added'
- 'review_session_started'
- 'verse_reviewed'
- 'retention_milestone'
```

### Dashboard Queries

```sql
-- Daily Active Users with Streaks
SELECT
  DATE(last_viewed_at) AS date,
  COUNT(DISTINCT user_id) AS dau_with_streaks,
  AVG(current_streak) AS avg_streak
FROM daily_verse_streaks
WHERE last_viewed_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(last_viewed_at)
ORDER BY date DESC;

-- Conversion Rate (Preview → Full Access)
SELECT
  DATE(created_at) AS date,
  COUNT(*) FILTER (WHERE event = 'preview_viewed') AS previews,
  COUNT(*) FILTER (WHERE event = 'preview_converted') AS conversions,
  ROUND(
    COUNT(*) FILTER (WHERE event = 'preview_converted')::DECIMAL /
    NULLIF(COUNT(*) FILTER (WHERE event = 'preview_viewed'), 0) * 100,
    2
  ) AS conversion_rate_pct
FROM analytics_events
WHERE event IN ('preview_viewed', 'preview_converted')
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- SRS Retention Stats
SELECT
  user_id,
  COUNT(*) AS total_verses,
  AVG(CASE WHEN interval >= 30 THEN 1 ELSE 0 END) AS mastery_rate,
  AVG(review_count) AS avg_reviews_per_verse
FROM memory_verses
GROUP BY user_id
HAVING COUNT(*) >= 5;
```

---

## Testing Requirements

### Unit Tests

**Coverage Target:** 80% minimum

**Required Tests:**

1. **Daily Verse Streak Logic**
   - Test streak increment on consecutive day
   - Test streak break on missed day
   - Test milestone badge awarding
   - Test timezone handling

2. **Study Guide Preview Logic**
   - Test section unlock rules
   - Test blur threshold calculation
   - Test authentication state handling

3. **SRS Algorithm**
   - Test SM-2 interval calculation
   - Test ease factor adjustments
   - Test rating transitions (Again → Good → Easy)
   - Test edge cases (min/max ease factor)

**Example Test:**

```dart
// test/features/daily_verse/domain/usecases/record_daily_verse_view_test.dart

void main() {
  late RecordDailyVerseView useCase;
  late MockStreakRepository mockRepository;

  setUp(() {
    mockRepository = MockStreakRepository();
    useCase = RecordDailyVerseView(repository: mockRepository);
  });

  group('RecordDailyVerseView', () {
    test('should increment streak on consecutive day', () async {
      // Arrange
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final existingStreak = DailyVerseStreak(
        userId: 'user123',
        currentStreak: 5,
        longestStreak: 10,
        lastViewedAt: yesterday,
        totalViews: 42,
        badges: ['week_warrior'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => mockRepository.getStreak('user123'))
          .thenAnswer((_) async => Right(existingStreak));

      when(() => mockRepository.recordView('user123'))
          .thenAnswer((_) async => Right(
            existingStreak.copyWith(currentStreak: 6)
          ));

      // Act
      final result = await useCase('user123');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected Right, got Left'),
        (streak) {
          expect(streak.currentStreak, 6);
          expect(streak.streakBroken, false);
        },
      );
    });

    test('should reset streak when day is skipped', () async {
      // Arrange
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      final existingStreak = DailyVerseStreak(
        userId: 'user123',
        currentStreak: 15,
        longestStreak: 20,
        lastViewedAt: twoDaysAgo,
        totalViews: 100,
        badges: ['week_warrior', 'monthly_master'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => mockRepository.getStreak('user123'))
          .thenAnswer((_) async => Right(existingStreak));

      when(() => mockRepository.recordView('user123'))
          .thenAnswer((_) async => Right(
            existingStreak.copyWith(currentStreak: 1, streakBroken: true)
          ));

      // Act
      final result = await useCase('user123');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected Right, got Left'),
        (streak) {
          expect(streak.currentStreak, 1);
          expect(streak.streakBroken, true);
          expect(streak.longestStreak, 20); // Should preserve longest
        },
      );
    });

    test('should award badge at milestone', () async {
      // Arrange
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final existingStreak = DailyVerseStreak(
        userId: 'user123',
        currentStreak: 6,
        longestStreak: 10,
        lastViewedAt: yesterday,
        totalViews: 42,
        badges: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => mockRepository.getStreak('user123'))
          .thenAnswer((_) async => Right(existingStreak));

      when(() => mockRepository.recordView('user123'))
          .thenAnswer((_) async => Right(
            existingStreak.copyWith(
              currentStreak: 7,
              badges: ['week_warrior'],
              newBadge: 'week_warrior',
            )
          ));

      // Act
      final result = await useCase('user123');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected Right, got Left'),
        (streak) {
          expect(streak.currentStreak, 7);
          expect(streak.badges, contains('week_warrior'));
          expect(streak.newBadge, 'week_warrior');
        },
      );
    });
  });
}
```

### Integration Tests

**Required Flows:**

1. **End-to-End Streak Flow**
   - User opens app → Daily verse card loads → User taps verse → Streak increments → UI updates

2. **Study Guide Preview Flow**
   - Anonymous user lands on guide → First section visible → Remaining sections blurred → User taps unlock → Auth flow → Full guide unlocked

3. **Memory Verse Review Flow**
   - User navigates to Memory Verses → Due cards loaded → Review session started → User rates cards → SRS algorithm updates intervals → Session completes

### Widget Tests

**Required Tests:**

```dart
// test/features/daily_verse/presentation/widgets/streak_counter_badge_test.dart

void main() {
  testWidgets('StreakCounterBadge displays current streak', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreakCounterBadge(
            currentStreak: 7,
            longestStreak: 15,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('7'), findsOneWidget);
    expect(find.text('days'), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);
  });

  testWidgets('StreakCounterBadge handles tap', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreakCounterBadge(
            currentStreak: 7,
            longestStreak: 15,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(StreakCounterBadge));
    await tester.pumpAndSettle();

    expect(tapped, true);
  });
}
```

---

## Security Considerations

### Row Level Security (RLS)

All database tables MUST have RLS enabled with proper policies:

**✅ Required Policies:**
1. Users can only access their own data
2. No cross-user data leakage
3. Anonymous users cannot access premium features
4. Cascade deletes on user deletion

**❌ Prohibited Actions:**
- Direct database access bypassing RLS
- Exposing user data in API responses
- Allowing manipulation of other users' data

### Input Validation

**API Endpoint Validation:**

```typescript
// Example: Memory verse rating validation
const VALID_RATINGS = ['again', 'hard', 'good', 'easy'];

function validateReviewRequest(body: any): ValidationResult {
  if (!body.verse_id || typeof body.verse_id !== 'string') {
    return { valid: false, error: 'Invalid verse_id' };
  }

  if (!body.rating || !VALID_RATINGS.includes(body.rating)) {
    return { valid: false, error: 'Invalid rating' };
  }

  return { valid: true };
}
```

**Frontend Validation:**

```dart
// Example: Memory verse text validation
class MemoryVerseValidator {
  static String? validateReference(String? reference) {
    if (reference == null || reference.isEmpty) {
      return 'Verse reference is required';
    }

    if (reference.length > 100) {
      return 'Reference is too long';
    }

    return null;
  }

  static String? validateText(String? text) {
    if (text == null || text.isEmpty) {
      return 'Verse text is required';
    }

    if (text.length < 10) {
      return 'Verse text is too short';
    }

    if (text.length > 5000) {
      return 'Verse text is too long';
    }

    return null;
  }
}
```

### Rate Limiting

**API Rate Limits:**

| Endpoint | Limit | Window |
|----------|-------|--------|
| `/daily-verse-viewed` | 10 requests | 1 minute |
| `/memory-verses/*` | 30 requests | 1 minute |

**Implementation:**

```typescript
// Use Supabase Edge Functions built-in rate limiting
import { createClient } from '@supabase/supabase-js';

// Rate limit using IP + user_id
const rateLimitKey = `${req.headers.get('x-forwarded-for')}:${user.id}`;

// Check rate limit (implement with Redis or Supabase storage)
const isRateLimited = await checkRateLimit(rateLimitKey, 30, 60);
if (isRateLimited) {
  return new Response(
    JSON.stringify({ error: 'Rate limit exceeded' }),
    { status: 429, headers: corsHeaders }
  );
}
```

---

## Performance Requirements

### Response Time Targets

| Operation | Target | Max |
|-----------|--------|-----|
| Load daily verse | < 500ms | 1s |
| Record streak view | < 300ms | 800ms |
| Load study guide preview | < 800ms | 1.5s |
| Load due memory cards | < 600ms | 1.2s |
| Submit review | < 400ms | 1s |

### Caching Strategy

**Local Caching (Hive):**

```dart
class StreakLocalDataSource {
  static const String _boxName = 'streaks_cache';
  static const Duration _cacheExpiry = Duration(hours: 24);

  Future<DailyVerseStreak?> getCachedStreak(String userId) async {
    final box = await Hive.openBox<Map>(_boxName);
    final cached = box.get(userId);

    if (cached == null) return null;

    final cacheTime = DateTime.parse(cached['cache_time']);
    if (DateTime.now().difference(cacheTime) > _cacheExpiry) {
      await box.delete(userId);
      return null;
    }

    return DailyVerseStreakModel.fromJson(cached['data']).toEntity();
  }

  Future<void> cacheStreak(String userId, DailyVerseStreak streak) async {
    final box = await Hive.openBox<Map>(_boxName);
    await box.put(userId, {
      'data': DailyVerseStreakModel.fromEntity(streak).toJson(),
      'cache_time': DateTime.now().toIso8601String(),
    });
  }
}
```

**API Response Caching:**

```dart
// Use in-memory cache for frequently accessed data
class MemoryVerseCacheManager {
  static final Map<String, _CacheEntry<List<MemoryVerse>>> _cache = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  static List<MemoryVerse>? getCachedDueCards(String userId) {
    final entry = _cache[userId];
    if (entry == null) return null;

    if (DateTime.now().difference(entry.timestamp) > _cacheExpiry) {
      _cache.remove(userId);
      return null;
    }

    return entry.data;
  }

  static void cacheDueCards(String userId, List<MemoryVerse> cards) {
    _cache[userId] = _CacheEntry(cards, DateTime.now());
  }
}
```

### Database Optimization

**Required Indexes:**

```sql
-- Already included in schema above
CREATE INDEX idx_daily_verse_streaks_user_id ON daily_verse_streaks(user_id);
CREATE INDEX idx_memory_verses_next_review ON memory_verses(user_id, next_review_at);
CREATE INDEX idx_review_sessions_user_id ON review_sessions(user_id, started_at DESC);
```

**Query Optimization:**

```sql
-- Efficient due cards query
SELECT * FROM memory_verses
WHERE user_id = $1
  AND next_review_at <= NOW()
ORDER BY next_review_at ASC
LIMIT 20;

-- Efficient streak leaderboard query
SELECT user_id, current_streak, badges
FROM daily_verse_streaks
WHERE current_streak >= 7
ORDER BY current_streak DESC
LIMIT 100;
```

---

## Rollout Strategy

### Phase 1A: Daily Verse Streak (Week 1-2)

**Week 1:**
- Day 1-2: Database migration + API implementation
- Day 3-4: Frontend UI components
- Day 5: BLoC integration + local caching
- Day 6-7: Testing + bug fixes

**Week 2:**
- Day 1-2: Analytics integration
- Day 3: Beta testing with internal team
- Day 4-5: Bug fixes from beta
- Day 6-7: Production deployment + monitoring

**Success Criteria:**
- ✅ Zero critical bugs in beta
- ✅ < 500ms API response time
- ✅ Proper RLS enforcement
- ✅ Analytics events firing correctly

### Phase 1B: Study Guide Preview (Week 3)

**Week 3:**
- Day 1: UI implementation (blur overlay + CTAs)
- Day 2: Integration with existing study guide page
- Day 3: Analytics + conversion tracking
- Day 4-5: Testing (manual + automated)
- Day 6-7: Production deployment

**Success Criteria:**
- ✅ Preview logic works for all users
- ✅ Authentication flow seamless
- ✅ Conversion events tracked properly

### Phase 1C: Memory Verses SRS (Week 4-7)

**Week 4:**
- Day 1-2: Database schema + migrations
- Day 3-5: Edge Functions (Add, Review, Get Due)
- Day 6-7: SRS algorithm implementation + testing

**Week 5:**
- Day 1-3: Frontend UI (Memory Verses page, Review Session)
- Day 4-5: BLoC implementation + state management
- Day 6-7: Local caching + offline support

**Week 6:**
- Day 1-2: Progress dashboard + statistics
- Day 3-4: Integration with Study Guides (add verse from guide)
- Day 5-7: Comprehensive testing (unit + integration + E2E)

**Week 7:**
- Day 1-2: Analytics + metrics dashboard
- Day 3-4: Beta testing with power users
- Day 5: Bug fixes + polish
- Day 6-7: Production deployment + monitoring

**Success Criteria:**
- ✅ SRS algorithm correctly calculates intervals
- ✅ Review sessions track properly
- ✅ Data syncs reliably between local + remote
- ✅ Performance targets met (< 600ms)

### Deployment Checklist

**Pre-Deployment:**
- [ ] All unit tests passing (80%+ coverage)
- [ ] Integration tests passing
- [ ] Manual QA complete
- [ ] Database migrations tested on staging
- [ ] RLS policies verified
- [ ] API rate limiting tested
- [ ] Analytics events verified
- [ ] Error monitoring configured

**Deployment:**
- [ ] Database migration executed
- [ ] Edge Functions deployed
- [ ] Frontend deployed (web + mobile)
- [ ] Smoke tests on production
- [ ] Rollback plan documented

**Post-Deployment:**
- [ ] Monitor error rates (< 0.1%)
- [ ] Monitor API response times
- [ ] Track analytics events
- [ ] Monitor user feedback
- [ ] Review conversion metrics after 7 days

### Rollback Plan

**Trigger Conditions:**
- Error rate > 1%
- Critical bug affecting user data
- Performance degradation > 50%
- Security vulnerability discovered

**Rollback Steps:**
1. Revert frontend deployment
2. Disable new Edge Functions
3. Keep database tables (data preserved)
4. Communicate with users via in-app banner
5. Post-mortem analysis + hotfix

---

## Success Metrics Dashboard

**Weekly Review Metrics:**

```sql
-- KPI Summary Query
SELECT
  'Daily Active Users' AS metric,
  COUNT(DISTINCT user_id) AS current_week,
  LAG(COUNT(DISTINCT user_id)) OVER (ORDER BY week) AS previous_week,
  ROUND(
    (COUNT(DISTINCT user_id)::DECIMAL /
     LAG(COUNT(DISTINCT user_id)) OVER (ORDER BY week) - 1) * 100,
    2
  ) AS growth_pct
FROM (
  SELECT
    user_id,
    DATE_TRUNC('week', last_viewed_at) AS week
  FROM daily_verse_streaks
  WHERE last_viewed_at >= NOW() - INTERVAL '14 days'
) AS weekly_users
GROUP BY week
ORDER BY week DESC;
```

**Conversion Funnel:**

```
Preview Viewed → Unlock Tapped → Auth Complete → Full Guide Accessed
    100%              60%              40%              35%
```

**Target Metrics (End of Phase 1):**
- 📈 +30% DAU
- 🔥 40% of users with 7+ day streaks
- 📖 10-15% free → standard conversion
- 🧠 10+ verses per standard user
- ⏱️ 5+ minutes average session time

---

## Appendix

### Glossary

| Term | Definition |
|------|------------|
| **SRS** | Spaced Repetition System - Algorithm for optimal review timing |
| **SM-2** | SuperMemo 2 - Specific SRS algorithm implementation |
| **Ease Factor** | Difficulty multiplier in SRS (1.3 - 3.0) |
| **Interval** | Days between review sessions |
| **RLS** | Row Level Security - PostgreSQL security feature |
| **BLoC** | Business Logic Component - Flutter state management pattern |

### References

- [SM-2 Algorithm Documentation](https://www.supermemo.com/en/archives1990-2015/english/ol/sm2)
- [Flutter Clean Architecture Guide](https://resocoder.com/flutter-clean-architecture-tdd/)
- [Supabase RLS Best Practices](https://supabase.com/docs/guides/auth/row-level-security)
- [Gamification Psychology in Apps](https://www.nngroup.com/articles/gamification/)

---

**Document End**

*For questions or clarifications, contact the Engineering Team.*
