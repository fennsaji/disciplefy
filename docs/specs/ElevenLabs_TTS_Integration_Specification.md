# ElevenLabs Text-to-Speech Integration Specification

**Document Version**: 1.0
**Last Updated**: 2026-01-12
**Status**: Proposed
**Owner**: Product & Engineering Team

---

## Executive Summary

This specification outlines the integration of ElevenLabs Flash v2.5 Text-to-Speech API for the **AI Discipler voice conversation feature only**. The implementation provides a cost-effective premium differentiator while maintaining budget constraints through strategic usage limits.

### Key Features:
- **Premium Users**: Unlimited ElevenLabs TTS for AI Discipler conversations
- **Free Users**: 1-minute trial to experience superior voice quality
- **Fallback**: Automatic transition to Google Cloud TTS after trial expires
- **Cost Control**: Estimated $4,800/month (88% cheaper than full hybrid approach)

---

## 1. Business Rationale

### 1.1 Problem Statement

Current Google Cloud TTS implementation for AI Discipler has the following limitations:
- **High Latency**: 200-500ms response time creates "robotic" conversation feel
- **Voice Quality**: Neural2 voices lack emotional depth and naturalness
- **User Engagement**: Delayed responses reduce conversational immersion
- **Premium Differentiation**: No compelling audio quality advantage for paid users

### 1.2 Solution

Integrate ElevenLabs Flash v2.5 model for AI Discipler conversations:
- **Ultra-Low Latency**: 75ms (3-6x faster than Google Cloud TTS)
- **Superior Voice Quality**: Natural prosody, emotional expression, conversational tone
- **Strategic Trial**: 1-minute free trial converts users to premium
- **Focused Scope**: AI Discipler only (not Study Guide Listening)

### 1.3 Success Metrics

| Metric | Baseline (Google TTS) | Target (ElevenLabs) |
|--------|----------------------|---------------------|
| **Voice Response Latency** | 200-500ms | <100ms |
| **User Satisfaction** | 4.2/5 | >4.7/5 |
| **AI Discipler Engagement** | 3.5 exchanges/session | >5 exchanges/session |
| **Premium Conversion** | 30% | >40% |
| **Monthly TTS Cost** | $5,000 | <$5,000 |

---

## 2. Cost Analysis

### 2.1 ElevenLabs Pricing

| Tier | Characters/Month | Price | Additional Chars |
|------|------------------|-------|------------------|
| Free | 10,000 | $0 | N/A |
| Starter | 30,000 | $5 | $0.30/1k |
| Creator | 100,000 | $22 | $0.22/1k |
| Pro | 500,000 | $99 | $0.20/1k |
| Scale | 2,000,000 | $330 | $0.12/1k |

### 2.2 Projected Usage (AI Discipler Only)

**Assumptions** (for 10,000 active users):
- Average conversation: 1,000 characters (5 exchanges × 200 chars/response)
- Free users: 1 trial conversation + 2 fallback conversations = 3 conversations/month
- Premium users (30%): 10 conversations/month each

**Monthly Character Usage**:
```
Free Users (7,000):
  Trial (ElevenLabs): 7,000 users × 200 chars (1 min) = 1.4M chars
  Post-trial (Google TTS): 7,000 users × 2,800 chars = 19.6M chars (not ElevenLabs)

Premium Users (3,000):
  Unlimited (ElevenLabs): 3,000 users × 10 conversations × 1,000 chars = 30M chars

Total ElevenLabs Usage: 1.4M + 30M = 31.4M characters/month
```

### 2.3 Monthly Cost Breakdown

| Component | Volume | Cost | Notes |
|-----------|--------|------|-------|
| **Scale Tier Base** | 2M chars included | $330 | Base subscription |
| **Overage** | 29.4M chars × $0.12 | $3,528 | Additional usage |
| **Total ElevenLabs** | 31.4M chars | **$3,858/month** | AI Discipler only |
| **Google Cloud TTS** | 19.6M chars × $0.016 | $314/month | Free users fallback |
| **Grand Total** | | **$4,172/month** | Combined TTS costs |

**vs. Original Hybrid Plan**: $42,000/month → **90% cost reduction** ✅

---

## 3. Technical Architecture

### 3.1 High-Level Design

```
┌────────────────────────────────────────────────────┐
│           AI Discipler Voice Flow                   │
└────────────────────────────────────────────────────┘
                      │
                      ▼
         ┌────────────────────────┐
         │  User Plan Detection   │
         │  + Trial Quota Check   │
         └────────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        │                           │
        ▼                           ▼
┌──────────────────┐      ┌──────────────────┐
│  Premium User    │      │   Free User      │
│  Plan: standard/ │      │   Plan: free     │
│       premium    │      │                  │
└──────────────────┘      └──────────────────┘
        │                           │
        ▼                           ▼
┌──────────────────┐      ┌──────────────────┐
│ ElevenLabs TTS   │      │ Check Trial      │
│ (Unlimited)      │      │ Quota Used       │
│                  │      └──────────────────┘
│ Flash v2.5       │                │
│ 75ms latency     │      ┌─────────┴─────────┐
└──────────────────┘      │                   │
                          ▼                   ▼
                  ┌──────────────┐   ┌──────────────┐
                  │ Trial Active │   │ Trial Expired│
                  │ (<60 seconds)│   │ (≥60 seconds)│
                  └──────────────┘   └──────────────┘
                          │                   │
                          ▼                   ▼
                  ┌──────────────┐   ┌──────────────┐
                  │ ElevenLabs   │   │ Google Cloud │
                  │ TTS          │   │ TTS          │
                  └──────────────┘   └──────────────┘
                          │                   │
                          └─────────┬─────────┘
                                    ▼
                          ┌──────────────────┐
                          │  Increment Trial │
                          │  Usage Counter   │
                          └──────────────────┘
```

### 3.2 Database Schema Changes

#### New Table: `user_tts_usage`

```sql
CREATE TABLE user_tts_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  trial_seconds_used INTEGER DEFAULT 0 CHECK (trial_seconds_used >= 0),
  trial_expires_at TIMESTAMPTZ,
  last_reset_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT unique_user_tts_usage UNIQUE (user_id)
);

-- Index for fast user lookups
CREATE INDEX idx_user_tts_usage_user_id ON user_tts_usage(user_id);

-- Row Level Security
ALTER TABLE user_tts_usage ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only read their own usage
CREATE POLICY "Users can view own TTS usage"
  ON user_tts_usage FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Service role can manage all records
CREATE POLICY "Service role full access"
  ON user_tts_usage FOR ALL
  USING (auth.role() = 'service_role');
```

#### Migration Notes:
- Trial resets monthly (checked via `last_reset_at`)
- `trial_seconds_used`: Cumulative audio duration consumed
- `trial_expires_at`: Optional hard expiry date (for future time-based trials)

---

## 4. Implementation Details

### 4.1 Phase 1: Backend Service (Week 1)

#### File: `backend/supabase/functions/_shared/services/elevenlabs-tts-service.ts`

```typescript
interface ElevenLabsConfig {
  apiKey: string
  voiceId: string
  modelId: 'eleven_flash_v2_5'
  optimizeStreamingLatency: number // 0-4, 4 = fastest
}

interface TTSResponse {
  audioData: Uint8Array
  durationSeconds: number
  success: boolean
  error?: string
}

class ElevenLabsTTSService {
  private apiKey: string
  private baseUrl = 'https://api.elevenlabs.io/v1'

  // Voice IDs for different languages
  private static VOICE_MAP: Record<string, string> = {
    'en-US': 'pNInz6obpgDQGcFmaJgB', // Adam (conversational male)
    'en-IN': 'ThT5KcBeYPX3keUQqHPh', // Sarah (Indian accent female)
    'hi': '21m00Tcm4TlvDq8ikWAM',    // Hindi native voice
    'ml': 'yoZ06aMxZJJ28mfd3POQ',    // Malayalam native voice
  }

  async synthesize(
    text: string,
    language: string = 'en-US',
    streaming: boolean = true
  ): Promise<TTSResponse> {
    const voiceId = ElevenLabsTTSService.VOICE_MAP[language] || ElevenLabsTTSService.VOICE_MAP['en-US']

    try {
      const response = await fetch(
        `${this.baseUrl}/text-to-speech/${voiceId}${streaming ? '/stream' : ''}`,
        {
          method: 'POST',
          headers: {
            'xi-api-key': this.apiKey,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            text,
            model_id: 'eleven_flash_v2_5',
            voice_settings: {
              stability: 0.5,
              similarity_boost: 0.75,
              style: 0.0,
              use_speaker_boost: true,
            },
            optimize_streaming_latency: streaming ? 4 : 0,
          }),
        }
      )

      if (!response.ok) {
        throw new Error(`ElevenLabs API error: ${response.status} ${response.statusText}`)
      }

      const audioData = new Uint8Array(await response.arrayBuffer())
      const durationSeconds = this.estimateAudioDuration(text)

      return { audioData, durationSeconds, success: true }
    } catch (error) {
      console.error('[ElevenLabs] TTS synthesis failed:', error)
      return {
        audioData: new Uint8Array(),
        durationSeconds: 0,
        success: false,
        error: error.message
      }
    }
  }

  private estimateAudioDuration(text: string): number {
    // Estimate: ~150 words per minute = 2.5 words per second
    const wordCount = text.split(/\s+/).length
    return Math.ceil(wordCount / 2.5)
  }
}

export { ElevenLabsTTSService }
```

#### File: `backend/supabase/functions/_shared/services/tts-quota-service.ts`

```typescript
import { SupabaseClient } from '@supabase/supabase-js'

interface TTSQuotaCheck {
  canUseTrial: boolean
  remainingSeconds: number
  usedSeconds: number
  trialLimit: number
}

const TRIAL_LIMIT_SECONDS = 60 // 1 minute

class TTSQuotaService {
  constructor(private supabase: SupabaseClient) {}

  async checkTrialQuota(userId: string): Promise<TTSQuotaCheck> {
    // Get or create usage record
    const { data: usage, error } = await this.supabase
      .from('user_tts_usage')
      .select('trial_seconds_used, last_reset_at')
      .eq('user_id', userId)
      .single()

    if (error && error.code !== 'PGRST116') { // Not found is OK
      throw new Error(`Failed to check TTS quota: ${error.message}`)
    }

    let usedSeconds = 0

    if (usage) {
      // Check if monthly reset needed
      const lastReset = new Date(usage.last_reset_at)
      const now = new Date()
      const monthsSinceReset =
        (now.getFullYear() - lastReset.getFullYear()) * 12 +
        (now.getMonth() - lastReset.getMonth())

      if (monthsSinceReset >= 1) {
        // Reset usage
        await this.supabase
          .from('user_tts_usage')
          .update({ trial_seconds_used: 0, last_reset_at: now.toISOString() })
          .eq('user_id', userId)
        usedSeconds = 0
      } else {
        usedSeconds = usage.trial_seconds_used
      }
    } else {
      // Create new record
      await this.supabase
        .from('user_tts_usage')
        .insert({ user_id: userId, trial_seconds_used: 0 })
    }

    const remainingSeconds = Math.max(0, TRIAL_LIMIT_SECONDS - usedSeconds)
    const canUseTrial = remainingSeconds > 0

    return {
      canUseTrial,
      remainingSeconds,
      usedSeconds,
      trialLimit: TRIAL_LIMIT_SECONDS,
    }
  }

  async incrementUsage(userId: string, secondsUsed: number): Promise<void> {
    const { error } = await this.supabase.rpc('increment_tts_usage', {
      p_user_id: userId,
      p_seconds_used: secondsUsed,
    })

    if (error) {
      console.error('[TTSQuota] Failed to increment usage:', error)
      // Non-critical: Don't throw, just log
    }
  }
}

export { TTSQuotaService, TRIAL_LIMIT_SECONDS }
```

#### Database Function: `increment_tts_usage`

```sql
CREATE OR REPLACE FUNCTION increment_tts_usage(
  p_user_id UUID,
  p_seconds_used INTEGER
) RETURNS void AS $$
BEGIN
  INSERT INTO user_tts_usage (user_id, trial_seconds_used, last_reset_at)
  VALUES (p_user_id, p_seconds_used, NOW())
  ON CONFLICT (user_id)
  DO UPDATE SET
    trial_seconds_used = user_tts_usage.trial_seconds_used + p_seconds_used,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 4.2 Phase 2: Provider Selection Logic (Week 1-2)

#### File: `backend/supabase/functions/voice-conversation/index.ts` (Enhanced)

```typescript
import { ElevenLabsTTSService } from '../_shared/services/elevenlabs-tts-service.ts'
import { TTSQuotaService } from '../_shared/services/tts-quota-service.ts'

async function generateTTSResponse(
  userId: string,
  text: string,
  language: string,
  userPlan: string
): Promise<Uint8Array> {
  const supabase = createClient(...)
  const quotaService = new TTSQuotaService(supabase)

  // Premium users: Always use ElevenLabs
  if (userPlan === 'standard' || userPlan === 'premium') {
    const elevenlabs = new ElevenLabsTTSService(Deno.env.get('ELEVENLABS_API_KEY')!)
    const result = await elevenlabs.synthesize(text, language, true)

    if (result.success) {
      return result.audioData
    }

    // Fallback to Google Cloud TTS
    console.warn('[TTS] ElevenLabs failed for premium user, falling back to Google Cloud')
    return await generateGoogleCloudTTS(text, language)
  }

  // Free users: Check trial quota
  const quota = await quotaService.checkTrialQuota(userId)

  if (quota.canUseTrial) {
    const elevenlabs = new ElevenLabsTTSService(Deno.env.get('ELEVENLABS_API_KEY')!)
    const result = await elevenlabs.synthesize(text, language, true)

    if (result.success) {
      // Increment trial usage
      await quotaService.incrementUsage(userId, result.durationSeconds)
      return result.audioData
    }
  }

  // Trial expired or failed: Use Google Cloud TTS
  return await generateGoogleCloudTTS(text, language)
}
```

### 4.3 Phase 3: Frontend Integration (Week 2)

#### File: `frontend/lib/features/voice_buddy/presentation/bloc/voice_buddy_bloc.dart`

```dart
Future<void> _onProcessVoiceInput(
  ProcessVoiceInput event,
  Emitter<VoiceBuddyState> emit,
) async {
  emit(VoiceBuddyProcessing());

  try {
    // Send to backend for LLM + TTS processing
    final response = await _voiceRepository.processVoiceInput(
      text: event.transcribedText,
      conversationHistory: _conversationHistory,
      language: event.language,
    );

    // Response includes audio data (ElevenLabs or Google Cloud TTS)
    await _audioPlayer.playBytes(response.audioData);

    // Check if trial expired (for free users)
    if (response.trialExpired == true && response.userPlan == 'free') {
      emit(VoiceBuddyTrialExpired(
        message: 'Your 1-minute AI Discipler trial has ended. Upgrade to Premium for unlimited conversations with enhanced voice quality!',
        remainingFreeConversations: response.remainingFreeConversations ?? 0,
      ));
    } else {
      emit(VoiceBuddyResponseReady(response: response));
    }
  } catch (e) {
    emit(VoiceBuddyError(message: e.toString()));
  }
}
```

#### Trial Expiry UI Component

```dart
// Show banner when trial expires
if (state is VoiceBuddyTrialExpired) {
  return Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.primaryColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.primaryColor, width: 2),
    ),
    child: Column(
      children: [
        Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 32),
        SizedBox(height: 12),
        Text(
          'Free Trial Complete',
          style: AppFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Text(
          state.message,
          textAlign: TextAlign.center,
          style: AppFonts.inter(fontSize: 14),
        ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => context.go('/premium'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text('Upgrade to Premium'),
        ),
        SizedBox(height: 8),
        TextButton(
          onPressed: () => _dismissTrialBanner(),
          child: Text('Continue with Standard Voice'),
        ),
      ],
    ),
  );
}
```

---

## 5. User Experience Flow

### 5.1 Free User Journey

**First Conversation (Trial Active)**:
1. User opens AI Discipler
2. Speaks to AI: "Tell me about John 3:16"
3. Backend checks: User is free → Trial quota = 60 seconds remaining
4. Response generated with **ElevenLabs TTS** (ultra-low latency, natural voice)
5. User experiences superior voice quality
6. Usage incremented: 60 - 12 = 48 seconds remaining

**Second Conversation (Trial Active)**:
1. User continues: "What does this mean for my life?"
2. Backend checks: Trial quota = 48 seconds remaining ✅
3. Response generated with **ElevenLabs TTS**
4. Usage incremented: 48 - 15 = 33 seconds remaining

**Third Conversation (Trial Expires Mid-Response)**:
1. User asks: "Can you pray with me about this?"
2. Backend checks: Trial quota = 33 seconds remaining
3. Response generated with **ElevenLabs TTS** (uses remaining 33 seconds)
4. **Trial Expired Banner** displayed:
   > "Your 1-minute AI Discipler trial has ended. Upgrade to Premium for unlimited conversations with enhanced voice quality!"
5. User can:
   - **Upgrade to Premium** (button)
   - **Continue with Standard Voice** (free, uses Google Cloud TTS)

**Fourth Conversation (Trial Expired)**:
1. User continues with standard voice
2. Backend checks: Trial quota = 0 seconds remaining ❌
3. Response generated with **Google Cloud TTS** (Neural2-F)
4. Slightly higher latency, but still functional

### 5.2 Premium User Journey

**All Conversations**:
1. User opens AI Discipler
2. Backend checks: User is premium → **Unlimited ElevenLabs TTS** ✅
3. All responses use ultra-low latency, natural voice
4. No trial limits, no degradation
5. Premium badge displayed in UI

### 5.3 Trial-to-Premium Conversion Flow

**Conversion Points**:
1. **Trial Expiry Banner** (in-conversation)
2. **Settings Page**: Show trial usage (e.g., "38/60 seconds used")
3. **Premium Page**: Highlight "Unlimited AI Discipler with enhanced voice" feature

**Expected Conversion Rate**: 40-50% (based on 1-minute trial quality difference)

---

## 6. Configuration & Environment

### 6.1 Environment Variables

#### Backend (`.env`)
```env
# ElevenLabs API
ELEVENLABS_API_KEY=your_api_key_here
ELEVENLABS_ENABLED=true

# TTS Configuration
TTS_TRIAL_SECONDS=60
TTS_FALLBACK_PROVIDER=google_cloud
```

#### Frontend (Not needed - backend handles all TTS logic)

### 6.2 Feature Flags

```typescript
// Feature flag for gradual rollout
const ELEVENLABS_ROLLOUT_PERCENTAGE = 100 // 0-100

function isElevenLabsEnabled(userId: string): boolean {
  if (!Deno.env.get('ELEVENLABS_ENABLED')) return false

  // Hash-based deterministic rollout
  const hash = hashUserId(userId)
  return (hash % 100) < ELEVENLABS_ROLLOUT_PERCENTAGE
}
```

---

## 7. Testing Strategy

### 7.1 Unit Tests

```typescript
// Test: Trial quota enforcement
describe('TTSQuotaService', () => {
  it('should allow trial usage under 60 seconds', async () => {
    const quota = await quotaService.checkTrialQuota(userId)
    expect(quota.canUseTrial).toBe(true)
    expect(quota.remainingSeconds).toBe(60)
  })

  it('should deny trial usage after 60 seconds', async () => {
    await quotaService.incrementUsage(userId, 60)
    const quota = await quotaService.checkTrialQuota(userId)
    expect(quota.canUseTrial).toBe(false)
    expect(quota.remainingSeconds).toBe(0)
  })

  it('should reset trial monthly', async () => {
    await quotaService.incrementUsage(userId, 60)
    // Simulate 1 month passing
    await simulateMonthPassing()
    const quota = await quotaService.checkTrialQuota(userId)
    expect(quota.remainingSeconds).toBe(60)
  })
})

// Test: Provider selection logic
describe('TTS Provider Selection', () => {
  it('should use ElevenLabs for premium users', async () => {
    const provider = await selectTTSProvider(userId, 'premium')
    expect(provider).toBe('elevenlabs')
  })

  it('should use ElevenLabs for free users with trial quota', async () => {
    const provider = await selectTTSProvider(userId, 'free')
    expect(provider).toBe('elevenlabs')
  })

  it('should fallback to Google Cloud after trial expires', async () => {
    await quotaService.incrementUsage(userId, 60)
    const provider = await selectTTSProvider(userId, 'free')
    expect(provider).toBe('google_cloud')
  })
})
```

### 7.2 Integration Tests

```typescript
// Test: End-to-end voice conversation with TTS
describe('Voice Conversation with ElevenLabs', () => {
  it('should generate audio with ElevenLabs for premium user', async () => {
    const response = await processVoiceInput({
      userId: premiumUserId,
      text: 'Tell me about John 3:16',
      language: 'en',
    })

    expect(response.audioData).toBeDefined()
    expect(response.ttsProvider).toBe('elevenlabs')
    expect(response.latency).toBeLessThan(100) // ms
  })

  it('should track trial usage for free users', async () => {
    const response1 = await processVoiceInput({
      userId: freeUserId,
      text: 'What is faith?',
      language: 'en',
    })

    expect(response1.ttsProvider).toBe('elevenlabs')
    expect(response1.trialSecondsRemaining).toBeLessThan(60)
  })
})
```

### 7.3 Load Testing

**Scenario**: 1,000 concurrent AI Discipler conversations
- Measure ElevenLabs API response time under load
- Verify fallback to Google Cloud TTS on ElevenLabs rate limit
- Ensure quota tracking doesn't create database bottlenecks

---

## 8. Rollout Plan

### Phase 1: Internal Testing (Week 3)
- **Audience**: Development team (5 users)
- **Goal**: Validate ElevenLabs integration, quota tracking, fallback logic
- **Duration**: 3 days
- **Success Criteria**: Zero critical bugs, latency <100ms

### Phase 2: Beta Release (Week 4)
- **Audience**: 5% of users (500 users)
- **Goal**: Monitor cost, user feedback, conversion rate
- **Duration**: 1 week
- **Rollback**: Feature flag → disable ElevenLabs if costs exceed $500/week

### Phase 3: Gradual Rollout (Week 5-6)
- **Week 5**: 25% of users (2,500 users)
- **Week 6**: 50% of users (5,000 users)
- **Monitoring**: Cost per user, trial-to-premium conversion, error rates

### Phase 4: Full Production (Week 7+)
- **Audience**: 100% of users (10,000 users)
- **Monitoring**: Continuous cost tracking, performance metrics
- **Optimization**: Negotiate enterprise pricing with ElevenLabs

---

## 9. Risk Mitigation

### 9.1 Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **ElevenLabs API downtime** | High | Low | Automatic fallback to Google Cloud TTS |
| **Cost overrun** | Critical | Medium | Daily cost alerts, hard monthly cap at $6,000 |
| **Trial abuse** | Medium | Low | Rate limiting, anomaly detection |
| **Latency degradation** | High | Low | Monitor 95th percentile, alert if >150ms |

### 9.2 Business Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Low trial conversion** | Medium | Medium | A/B test trial duration (30s, 60s, 90s) |
| **Premium churn** | High | Low | Ensure quality remains consistent |
| **Budget constraints** | Critical | Medium | Adjust trial duration or rollout percentage |

### 9.3 Fallback Strategy

**If costs exceed budget**:
1. Reduce trial duration: 60s → 30s → 15s
2. Reduce rollout percentage: 100% → 50% → 25%
3. Premium-only: Disable trial entirely, ElevenLabs for premium only
4. Complete rollback: Revert to Google Cloud TTS for all users

---

## 10. Monitoring & Alerts

### 10.1 Cost Monitoring

**Daily Report**:
```sql
-- Total ElevenLabs characters used today
SELECT
  COUNT(*) as conversations,
  SUM(response_length_chars) as total_chars,
  SUM(response_length_chars) * 0.00012 as estimated_cost_usd
FROM tts_usage_logs
WHERE
  tts_provider = 'elevenlabs'
  AND created_at >= CURRENT_DATE;
```

**Alert Thresholds**:
- **Warning**: Daily cost >$200 (projected $6,000/month)
- **Critical**: Daily cost >$300 (projected $9,000/month)

### 10.2 Performance Monitoring

**Metrics**:
- Average TTS latency (target: <100ms)
- 95th percentile latency (target: <150ms)
- Error rate (target: <1%)
- Fallback rate (target: <5%)

**Dashboards**:
- Real-time TTS provider distribution (ElevenLabs vs Google Cloud)
- Trial usage histogram (distribution of users by seconds used)
- Premium conversion funnel

---

## 11. Success Criteria

### Go-Live Requirements

- [ ] ElevenLabs API integration complete and tested
- [ ] Quota tracking system verified (trial limits, monthly resets)
- [ ] Fallback to Google Cloud TTS validated
- [ ] Database migration applied to production
- [ ] Cost monitoring dashboard deployed
- [ ] Beta testing completed with >90% satisfaction
- [ ] Premium conversion rate >35% among trial users
- [ ] Average latency <100ms (95th percentile <150ms)

### Post-Launch Review (30 Days)

- [ ] Monthly TTS cost <$5,000
- [ ] AI Discipler engagement increased >20%
- [ ] Premium conversion rate >40%
- [ ] User satisfaction score >4.7/5
- [ ] Zero P0/P1 incidents related to TTS

---

## 12. Future Enhancements

### Quarter 2 Optimizations

1. **Voice Cloning**: Allow premium users to clone their own voice for personalized AI Discipler
2. **Emotion Control**: Adjust voice emotion based on conversation context (joyful, contemplative, urgent)
3. **Multi-Voice Conversations**: Different voices for Bible characters in narrative readings
4. **Voice Preferences**: User-selectable voice profiles (male/female, accent, age)

### Cost Optimization Strategies

1. **Caching**: Cache common phrases, Bible verses, greetings (reduce usage by ~20%)
2. **Compression**: Use Opus codec to reduce audio file size by ~40%
3. **Enterprise Pricing**: Negotiate custom contract with ElevenLabs (target 50% discount)
4. **Smart Sampling**: Use ElevenLabs only for first exchange, Google Cloud for follow-ups

---

## 13. Appendix

### A. ElevenLabs Voice IDs

| Language | Voice ID | Voice Name | Gender | Accent |
|----------|----------|------------|--------|--------|
| English (US) | `pNInz6obpgDQGcFmaJgB` | Adam | Male | American |
| English (IN) | `ThT5KcBeYPX3keUQqHPh` | Sarah | Female | Indian |
| Hindi | `21m00Tcm4TlvDq8ikWAM` | Ravi | Male | Native |
| Malayalam | `yoZ06aMxZJJ28mfd3POQ` | Priya | Female | Native |

### B. API Rate Limits

| Tier | Concurrent Requests | Characters/Minute |
|------|---------------------|-------------------|
| Free | 2 | 10,000 |
| Starter | 3 | 30,000 |
| Creator | 5 | 100,000 |
| Pro | 10 | 500,000 |
| Scale | 20 | 2,000,000 |

### C. References

- [ElevenLabs API Documentation](https://elevenlabs.io/docs/api-reference/text-to-speech)
- [ElevenLabs Pricing](https://elevenlabs.io/pricing/api)
- [ElevenLabs Language Support](https://help.elevenlabs.io/hc/en-us/articles/13313366263441-What-languages-do-you-support)
- [Existing AI Discipler Voice Specification](./AI_Study_Buddy_Voice_Specification.md)

---

**Document Status**: Ready for Review
**Next Steps**: Engineering team review → Budget approval → Implementation kickoff
