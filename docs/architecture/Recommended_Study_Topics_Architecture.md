# Recommended Study Topics - Revamp Plan

**Last Updated**: November 28, 2025  
**Status**: Planning

---

## Current State

We have 46 Bible study topics across 8 categories (Foundations of Faith, Christian Life, Discipleship, etc.) with Hindi and Malayalam translations. Topics are displayed as a horizontal carousel on the home screen and a browsable grid on the Study Topics screen.

**What works well:**
- Multi-language support
- Caching for offline access
- Category-based filtering
- Deep linking from notifications
- Saved Guides feature (can reuse for bookmarking topics)

**What's missing:**
- No personalization - everyone sees the same topics
- No progress tracking - users can't see what they've completed
- No learning structure - topics are isolated, not connected
- Limited discovery - only search and category filters

---

## Vision

Transform topics from a static list into a **personalized learning journey** that adapts to each user's spiritual growth, tracks their progress, and guides them through structured discipleship paths.

---

## Proposed Improvements

### 1. Personalized "For You" Section

**Problem**: Home screen shows the same 6 topics to everyone regardless of their history or interests.

**Solution**: Show personalized recommendations based on:
- Topics they haven't studied yet
- Categories they engage with most
- Time since last study session

**User Experience**:
- "Recommended for you" section at top of home screen
- 3-4 handpicked topics that feel relevant
- Refreshes daily with new suggestions

---

### 2. Progress Tracking

**Problem**: Users can't see which topics they've completed or how far they've progressed.

**Solution**: Visual indicators showing completion status.

**User Experience**:
- Checkmark badge on completed topic cards
- "3 of 6 completed" progress in each category
- "Continue where you left off" for incomplete studies
- Personal stats: "You've completed 12 topics this month"

---

### 3. Learning Paths (Structured Journeys)

**Problem**: Topics are isolated - no guidance on what to study next or in what order.

**Solution**: Curated sequences of topics that build on each other.

**Example Paths**:
- **New Believer Journey** (4 weeks): Salvation → Bible Basics → Prayer → Fellowship
- **Deeper Faith** (6 weeks): Holy Spirit → Spiritual Gifts → Discernment → Serving
- **Family Focus** (4 weeks): Marriage → Parenting → Conflict Resolution → Family Worship

**User Experience**:
- "Learning Paths" section on Study Topics screen
- Progress bar showing journey completion
- Unlock next topic after completing previous
- Certificate or badge upon path completion

---

### 4. Topic Relationships

**Problem**: After completing a topic, users don't know what to study next.

**Solution**: Connect related topics together.

**User Experience**:
- "Up Next" suggestion after completing a study
- "Related Topics" section on each topic card
- "Prerequisites" for advanced topics (optional)

---

### 5. Enhanced Discovery

**Problem**: Current discovery is limited to search and category filters.

**Solution**: Multiple ways to find relevant content.

**New Discovery Methods**:
- **Trending**: Most popular topics this week
- **Seasonal**: Easter, Christmas, Lent-themed topics
- **Life Situations**: "Going through trials", "New job", "Marriage preparation"
- **Scripture-based**: "Topics about John 3:16" or "Psalms studies"

---

### 6. Save Topics for Later

**Problem**: Users might want to save interesting topics to study later.

**Solution**: Reuse existing Saved Guides feature to allow saving topics (not just completed guides).

**User Experience**:
- Save icon on topic cards (before starting study)
- Saved topics appear in existing Saved Guides section
- Distinguish between "Saved Topics" and "Completed Guides"

---

### 7. Topic Insights & Analytics

**Problem**: No visibility into what users find valuable.

**Solution**: Track engagement to improve content.

**Metrics to Track**:
- Most started topics
- Most completed topics
- Average completion time
- Drop-off points
- Category preferences by user segment

---

## Implementation Phases

### Phase 1: Foundation (Quick Wins)
- Add completion tracking to topic cards
- Show "Continue studying" for incomplete guides
- Extend Saved Guides to support saving topics

### Phase 2: Personalization
- Build "For You" recommendation engine
- Add related topics suggestions

### Phase 3: Learning Paths
- Design 3-5 initial learning paths
- Build path progress tracking
- Add path completion rewards

### Phase 4: Enhanced Discovery
- Add trending topics
- Implement seasonal/situational categories
- Scripture-based topic search

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Topics started per user/month | ~2 | 5+ |
| Topic completion rate | Unknown | 70%+ |
| Return to Study Topics screen | Low | 3x/week |
| Learning path enrollments | N/A | 30% of active users |

---

## Open Questions

1. Should learning paths be free or premium-only?
2. How many topics should "For You" show? (3? 5?)
3. Should we add user-generated topic requests?
4. Do we need an admin panel for topic management?
5. Should completed paths unlock badges/achievements?

---

## Next Steps

1. Prioritize which improvements to tackle first
2. Design UI mockups for key features
3. Plan database changes needed
4. Estimate development effort per phase
