# AI Study Buddy Voice - Technical Specification

**Document Version:** 1.0  
**Date:** January 18, 2025  
**Status:** Planning - Phase-Wise Development  
**Feature Priority:** Tier 2 ⭐⭐⭐⭐  
**Estimated Development:** 4 weeks  
**Premium Tier:** Scholar ($9.99/month) - Unlimited  

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Technical Architecture](#2-technical-architecture)
3. [Multi-Language Support](#3-multi-language-support)
4. [Database Schema](#4-database-schema)
5. [API Endpoints](#5-api-endpoints)
6. [Phase-Wise Development Plan](#6-phase-wise-development-plan)
7. [UI Components](#7-ui-components)
8. [Voice Integration](#8-voice-integration)
9. [LLM Integration](#9-llm-integration)
10. [Testing Strategy](#10-testing-strategy)
11. [Success Metrics](#11-success-metrics)
12. [Cost Analysis](#12-cost-analysis)

---

## 1. Executive Summary

### 1.1 Feature Overview

**AI Study Buddy Voice** is a hands-free voice conversation feature that provides instant theological guidance and Bible study assistance through natural voice interactions - like having a "pastor in your pocket."

**Core Value Proposition:**
- Solves: "I want pastor-level answers instantly" + "I need hands-free Bible study"
- Provides: Unlimited voice conversations with AI theology expert in user's preferred language
- Differentiator: Only Bible app with multi-language voice AI + theological accuracy

### 1.2 Key Features

1. **Voice-First Interaction**
   - Natural speech recognition in 3 languages
   - Real-time AI voice responses
   - Continuous conversation mode (hands-free)
   - Background audio support (commute-friendly)

2. **Multi-Language Support**
   - English, Hindi (हिन्दी), Malayalam (മലയാളം)
   - Automatic language detection
   - Language switching mid-conversation
   - Native voice synthesis for each language

3. **Theological Conversation**
   - Scripture explanation and cross-referencing
   - Theological questions and debates
   - Prayer guidance and spiritual advice
   - Study guide enhancement (ask while reading)

4. **Context-Aware AI**
   - Remembers conversation history
   - Knows user's current study and topics
   - Personalized to spiritual maturity level
   - Maintains theological orthodoxy

5. **Premium Tiers**
   - Free: 3 conversations/day (5 min each)
   - Standard: 10 conversations/day
   - Premium: Unlimited + priority response

### 1.3 Success Criteria

**Adoption Metrics:**
- 60%+ of premium users try voice at least once
- 40%+ become weekly voice users
- Top 3 reason for free → premium conversion

**Engagement Metrics:**
- Average 3-5 conversations per active user per week
- 70%+ conversation completion rate
- 30%+ use voice while commuting/exercising

**Quality Metrics:**
- 4.5+ / 5.0 stars for voice quality
- <5% theological accuracy issues
- <2s latency for response start

---

## 2. Technical Architecture

### 2.1 System Components

```
┌─────────────────────────────────────────────────────┐
│              Flutter Frontend                        │
│  ┌──────────────┐  ┌──────────────┐                │
│  │   Voice UI   │  │ Conversation │                │
│  │  Widget      │  │   History    │                │
│  └──────────────┘  └──────────────┘                │
│         ↕                  ↕                         │
│  ┌──────────────┐  ┌──────────────┐                │
│  │ Speech-to-   │  │ Text-to-     │                │
│  │ Text Plugin  │  │ Speech Plugin│                │
│  └──────────────┘  └──────────────┘                │
└─────────────────────────────────────────────────────┘
                      ↕ WebSocket / EventSource
┌─────────────────────────────────────────────────────┐
│          Supabase Edge Functions                     │
│  ┌────────────────────────────────────┐             │
│  │  voice-conversation                │             │
│  │  - Receive audio/text input        │             │
│  │  - Stream to STT service           │             │
│  │  - Send to LLM with context        │             │
│  │  - Stream response back            │             │
│  │  - Convert to speech               │             │
│  └────────────────────────────────────┘             │
└─────────────────────────────────────────────────────┘
                      ↕
┌─────────────────────────────────────────────────────┐
│            External Services                         │
│  ┌────────────────┐  ┌────────────────┐            │
│  │ Google Cloud   │  │ OpenAI GPT-4   │            │
│  │ Speech-to-Text │  │ (LLM)          │            │
│  └────────────────┘  └────────────────┘            │
│  ┌────────────────┐  ┌────────────────┐            │
│  │ Google Cloud   │  │ Whisper API    │            │
│  │ Text-to-Speech │  │ (Alternative)  │            │
│  └────────────────┘  └────────────────┘            │
└─────────────────────────────────────────────────────┘
                      ↕
┌─────────────────────────────────────────────────────┐
│          PostgreSQL Database                         │
│  ┌──────────────────────────────────────┐           │
│  │ • voice_conversations                │           │
│  │ • conversation_messages              │           │
│  │ • voice_usage_tracking               │           │
│  │ • voice_preferences                  │           │
│  └──────────────────────────────────────┘           │
└─────────────────────────────────────────────────────┘
```

### 2.2 Technology Stack

**Frontend (Flutter):**
- `speech_to_text` (^6.3.0) - Multi-language speech recognition
- `flutter_tts` (^3.8.0) - Text-to-speech synthesis
- `record` (^5.0.0) - Audio recording
- `audioplayers` (^5.2.0) - Audio playback
- `web_socket_channel` - Real-time communication
- BLoC pattern for state management

**Backend (Supabase):**
- Edge Functions (Deno/TypeScript)
- PostgreSQL with RLS
- Realtime subscriptions
- Storage for audio caching (optional)

**External Services:**
- **Speech-to-Text:** Google Cloud Speech-to-Text (supports 125+ languages including EN, HI, ML)
- **Text-to-Speech:** Google Cloud TTS (supports 380+ voices, 50+ languages)
- **LLM Processing:** OpenAI GPT-4 Turbo (supports 50+ languages)
- **Alternative STT:** OpenAI Whisper API (99 languages)

**Audio Processing:**
- Format: WAV/OPUS (16kHz, mono)
- Compression: Opus codec for streaming
- Buffering: 2-3 second chunks

---

## 3. Multi-Language Support

### 3.1 Supported Languages

| Language | Code | Script | STT Support | TTS Support | Voice Quality |
|----------|------|--------|-------------|-------------|---------------|
| English  | en-US | Latin | ✅ Excellent | ✅ Excellent | Natural (Neural) |
| Hindi    | hi-IN | Devanagari (हिन्दी) | ✅ Excellent | ✅ Good | Neural |
| Malayalam| ml-IN | Malayalam (മലയാളം) | ✅ Good | ✅ Good | Neural |

### 3.2 Language Detection & Selection

**Automatic Detection:**
```typescript
// Google Cloud Speech-to-Text supports language detection
const speechConfig = {
  languageCode: 'en-US', // Primary language
  alternativeLanguageCodes: ['hi-IN', 'ml-IN'], // Detect others
  enableAutomaticPunctuation: true,
  model: 'latest_long'
};
```

**User Preference:**
- Use user's profile language preference (from daily verse settings)
- Allow manual language switching in voice interface
- Remember last-used language per conversation

**Language Switching:**
- User can say "Switch to Hindi" / "हिन्दी में बोलो" / "മലയാളത്തിൽ സംസാരിക്കൂ"
- Button to manually select language during conversation
- Auto-detect if user starts speaking in different language

### 3.3 Multi-Language TTS Configuration

**Google Cloud TTS Voices:**

```typescript
const TTS_VOICES = {
  'en-US': {
    name: 'en-US-Neural2-J', // Female, natural
    gender: 'FEMALE',
    speakingRate: 0.95,
    pitch: 0.0
  },
  'hi-IN': {
    name: 'hi-IN-Neural2-A', // Female, Hindi
    gender: 'FEMALE',
    speakingRate: 0.9,
    pitch: 0.0
  },
  'ml-IN': {
    name: 'ml-IN-Wavenet-A', // Female, Malayalam
    gender: 'FEMALE',
    speakingRate: 0.9,
    pitch: 0.0
  }
};
```

**Flutter TTS Fallback:**
```dart
// For offline or low-cost scenarios
final FlutterTts flutterTts = FlutterTts();

await flutterTts.setLanguage('en-US'); // or 'hi-IN', 'ml-IN'
await flutterTts.setPitch(1.0);
await flutterTts.setSpeechRate(0.5);
await flutterTts.setVoice({
  'name': 'en-us-x-sfg#female_1-local',
  'locale': 'en-US'
});
```

### 3.4 LLM Multi-Language Prompts

**System Prompt Template:**
```
You are a knowledgeable Bible study assistant speaking in {{LANGUAGE}}.

LANGUAGE REQUIREMENTS:
- Respond ONLY in {{LANGUAGE}} ({{LANGUAGE_CODE}})
- Use appropriate {{SCRIPT}} script
- Maintain theological terminology in {{LANGUAGE}}
- Cite Scripture references in {{LANGUAGE}} translation

LANGUAGE-SPECIFIC BIBLES:
- English: ESV, NIV, KJV
- Hindi: Hindi Bible (IRV - Indian Revised Version)
- Malayalam: Malayalam Bible (POC - Porulath Araya Chathan)

USER PROFILE:
- Language Preference: {{LANGUAGE}}
- Maturity Level: {{MATURITY_LEVEL}}
- Current Study: {{CURRENT_STUDY}}

Provide theologically sound, conversational responses as if you were a pastor having a friendly discussion with a church member.
```

---

## 4. Database Schema

### 4.1 Core Tables

#### **voice_conversations**
```sql
CREATE TABLE voice_conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Session Info
  session_id TEXT NOT NULL, -- Client-generated UUID
  language_code TEXT NOT NULL DEFAULT 'en-US' CHECK (language_code IN ('en-US', 'hi-IN', 'ml-IN')),
  
  -- Conversation Context
  conversation_type TEXT NOT NULL DEFAULT 'general' CHECK (conversation_type IN (
    'general',           -- Open-ended questions
    'study_enhancement', -- Questions during study guide
    'scripture_inquiry', -- Specific verse questions
    'prayer_guidance',   -- Prayer-related
    'theological_debate' -- Deep theological discussion
  )),
  
  related_study_guide_id UUID, -- If asking about a specific study
  related_scripture TEXT, -- e.g., "John 3:16"
  
  -- Conversation Metadata
  total_messages INTEGER DEFAULT 0,
  total_duration_seconds INTEGER DEFAULT 0,
  
  -- Status
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
    'active',
    'completed',
    'abandoned'
  )),
  
  -- User Feedback
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  feedback_text TEXT,
  was_helpful BOOLEAN,
  
  -- Timestamps
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_voice_conversations_user_id ON voice_conversations(user_id);
CREATE INDEX idx_voice_conversations_session_id ON voice_conversations(session_id);
CREATE INDEX idx_voice_conversations_status ON voice_conversations(status);
CREATE INDEX idx_voice_conversations_language ON voice_conversations(language_code);

-- RLS Policies
ALTER TABLE voice_conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own conversations"
  ON voice_conversations FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own conversations"
  ON voice_conversations FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own conversations"
  ON voice_conversations FOR UPDATE
  USING (auth.uid() = user_id);
```

#### **conversation_messages**
```sql
CREATE TABLE conversation_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID NOT NULL REFERENCES voice_conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Message Info
  message_order INTEGER NOT NULL, -- Sequence in conversation (1, 2, 3...)
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  
  -- Content
  content_text TEXT NOT NULL, -- Transcribed/generated text
  content_language TEXT NOT NULL DEFAULT 'en-US',
  
  -- Audio Metadata (if available)
  audio_duration_seconds DECIMAL(6,2),
  audio_url TEXT, -- Supabase Storage URL (if we cache audio)
  
  -- Processing Metadata
  transcription_confidence DECIMAL(4,3), -- 0.000 to 1.000 (from STT)
  llm_model_used TEXT, -- e.g., 'gpt-4-turbo-preview'
  llm_tokens_used INTEGER,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(conversation_id, message_order)
);

-- Indexes
CREATE INDEX idx_conversation_messages_conversation_id ON conversation_messages(conversation_id);
CREATE INDEX idx_conversation_messages_user_id ON conversation_messages(user_id);
CREATE INDEX idx_conversation_messages_order ON conversation_messages(conversation_id, message_order);

-- RLS Policies
ALTER TABLE conversation_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own messages"
  ON conversation_messages FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own messages"
  ON conversation_messages FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

#### **voice_usage_tracking**
```sql
CREATE TABLE voice_usage_tracking (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Usage Period
  usage_date DATE NOT NULL DEFAULT CURRENT_DATE,
  
  -- Usage Counts
  conversations_started INTEGER DEFAULT 0,
  conversations_completed INTEGER DEFAULT 0,
  total_messages_sent INTEGER DEFAULT 0,
  total_messages_received INTEGER DEFAULT 0,
  
  -- Duration Tracking
  total_conversation_seconds INTEGER DEFAULT 0,
  total_audio_seconds INTEGER DEFAULT 0,
  
  -- Language Usage
  language_usage JSONB DEFAULT '{}',
  -- {
  --   "en-US": 5,
  --   "hi-IN": 2,
  --   "ml-IN": 1
  -- }
  
  -- Subscription Tier (at time of use)
  tier_at_time TEXT NOT NULL CHECK (tier_at_time IN ('free', 'standard', 'premium')),
  
  -- Quota Management
  daily_quota_limit INTEGER, -- Conversations allowed per day
  daily_quota_used INTEGER DEFAULT 0,
  quota_exceeded BOOLEAN DEFAULT FALSE,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id, usage_date)
);

-- Indexes
CREATE INDEX idx_voice_usage_user_id ON voice_usage_tracking(user_id);
CREATE INDEX idx_voice_usage_date ON voice_usage_tracking(usage_date);
CREATE INDEX idx_voice_usage_tier ON voice_usage_tracking(tier_at_time);

-- RLS Policies
ALTER TABLE voice_usage_tracking ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own usage"
  ON voice_usage_tracking FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert usage"
  ON voice_usage_tracking FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "System can update usage"
  ON voice_usage_tracking FOR UPDATE
  USING (auth.uid() = user_id);
```

#### **voice_preferences**
```sql
CREATE TABLE voice_preferences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Language Preferences
  preferred_language TEXT NOT NULL DEFAULT 'en-US' CHECK (preferred_language IN ('en-US', 'hi-IN', 'ml-IN')),
  auto_detect_language BOOLEAN DEFAULT TRUE,
  
  -- Voice Settings
  tts_voice_gender TEXT DEFAULT 'female' CHECK (tts_voice_gender IN ('male', 'female')),
  speaking_rate DECIMAL(3,2) DEFAULT 0.95 CHECK (speaking_rate BETWEEN 0.5 AND 2.0),
  pitch DECIMAL(3,2) DEFAULT 0.0 CHECK (pitch BETWEEN -20.0 AND 20.0),
  
  -- Interaction Preferences
  auto_play_response BOOLEAN DEFAULT TRUE,
  show_transcription BOOLEAN DEFAULT TRUE,
  continuous_mode BOOLEAN DEFAULT FALSE, -- Keep mic open after response
  
  -- Context Preferences
  use_study_context BOOLEAN DEFAULT TRUE, -- Include current study in conversation
  cite_scripture_references BOOLEAN DEFAULT TRUE,
  
  -- Notification Preferences
  notify_daily_quota_reached BOOLEAN DEFAULT TRUE,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id)
);

-- RLS Policies
ALTER TABLE voice_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own preferences"
  ON voice_preferences FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own preferences"
  ON voice_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences"
  ON voice_preferences FOR UPDATE
  USING (auth.uid() = user_id);
```

### 4.2 Database Functions

#### **Check Daily Quota**
```sql
CREATE OR REPLACE FUNCTION check_voice_quota(p_user_id UUID, p_tier TEXT)
RETURNS JSONB AS $$
DECLARE
  v_usage RECORD;
  v_quota_limit INTEGER;
  v_can_start BOOLEAN;
BEGIN
  -- Determine quota based on tier
  v_quota_limit := CASE
    WHEN p_tier = 'free' THEN 3
    WHEN p_tier = 'standard' THEN 10
    WHEN p_tier = 'premium' THEN 999999 -- Unlimited
    ELSE 0
  END;
  
  -- Get today's usage
  SELECT * INTO v_usage
  FROM voice_usage_tracking
  WHERE user_id = p_user_id
    AND usage_date = CURRENT_DATE;
  
  -- If no record, create one
  IF v_usage IS NULL THEN
    INSERT INTO voice_usage_tracking (user_id, tier_at_time, daily_quota_limit)
    VALUES (p_user_id, p_tier, v_quota_limit)
    RETURNING * INTO v_usage;
  END IF;
  
  -- Check if can start new conversation
  v_can_start := v_usage.daily_quota_used < v_quota_limit;
  
  RETURN jsonb_build_object(
    'can_start', v_can_start,
    'quota_limit', v_quota_limit,
    'quota_used', v_usage.daily_quota_used,
    'quota_remaining', v_quota_limit - v_usage.daily_quota_used
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### **Increment Conversation Count**
```sql
CREATE OR REPLACE FUNCTION increment_voice_usage(
  p_user_id UUID,
  p_tier TEXT,
  p_language TEXT
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO voice_usage_tracking (
    user_id,
    usage_date,
    tier_at_time,
    daily_quota_limit,
    daily_quota_used,
    conversations_started,
    language_usage
  )
  VALUES (
    p_user_id,
    CURRENT_DATE,
    p_tier,
    CASE
      WHEN p_tier = 'free' THEN 3
      WHEN p_tier = 'standard' THEN 10
      WHEN p_tier = 'premium' THEN 999999
    END,
    1,
    1,
    jsonb_build_object(p_language, 1)
  )
  ON CONFLICT (user_id, usage_date)
  DO UPDATE SET
    daily_quota_used = voice_usage_tracking.daily_quota_used + 1,
    conversations_started = voice_usage_tracking.conversations_started + 1,
    language_usage = jsonb_set(
      voice_usage_tracking.language_usage,
      ARRAY[p_language],
      to_jsonb(COALESCE((voice_usage_tracking.language_usage->>p_language)::INTEGER, 0) + 1)
    ),
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 5. API Endpoints

### 5.1 Edge Functions

#### **POST /voice/start-conversation**
Start a new voice conversation session.

**Request:**
```typescript
{
  language: 'en-US' | 'hi-IN' | 'ml-IN',
  conversation_type: 'general' | 'study_enhancement' | 'scripture_inquiry' | 'prayer_guidance',
  related_study_guide_id?: string,
  related_scripture?: string
}
```

**Response:**
```typescript
{
  conversation_id: string,
  session_id: string,
  quota_info: {
    can_continue: boolean,
    quota_remaining: number,
    tier: 'free' | 'standard' | 'premium'
  },
  websocket_url: string // For streaming
}
```

---

#### **WebSocket /voice/stream-conversation**
Real-time bidirectional voice conversation streaming.

**Client → Server Messages:**
```typescript
{
  type: 'audio_chunk' | 'text_message' | 'end_turn',
  data: {
    audio?: ArrayBuffer, // Base64-encoded audio chunk
    text?: string, // Or direct text input
    language?: 'en-US' | 'hi-IN' | 'ml-IN'
  }
}
```

**Server → Client Messages:**
```typescript
{
  type: 'transcription' | 'llm_response' | 'audio_response' | 'error',
  data: {
    // For transcription
    text?: string,
    confidence?: number,
    language?: string,
    
    // For LLM response
    response_text?: string,
    scripture_references?: string[],
    
    // For audio response
    audio_chunk?: ArrayBuffer, // Base64-encoded
    audio_format?: 'wav' | 'opus',
    
    // For error
    error_code?: string,
    error_message?: string
  }
}
```

**Implementation:**
```typescript
// backend/supabase/functions/voice/stream-conversation/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { SpeechClient } from '@google-cloud/speech';
import { TextToSpeechClient } from '@google-cloud/text-to-speech';
import { OpenAI } from 'openai';

const speechClient = new SpeechClient({
  credentials: JSON.parse(Deno.env.get('GOOGLE_CLOUD_CREDENTIALS')!)
});

const ttsClient = new TextToSpeechClient({
  credentials: JSON.parse(Deno.env.get('GOOGLE_CLOUD_CREDENTIALS')!)
});

const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY')!
});

serve(async (req) => {
  // Upgrade to WebSocket
  const upgrade = req.headers.get('upgrade') || '';
  if (upgrade.toLowerCase() !== 'websocket') {
    return new Response('Expected WebSocket', { status: 426 });
  }
  
  const { socket, response } = Deno.upgradeWebSocket(req);
  
  let conversationHistory: Array<{ role: string; content: string }> = [];
  let currentLanguage = 'en-US';
  let audioBuffer: Uint8Array[] = [];
  
  socket.onmessage = async (event) => {
    try {
      const message = JSON.parse(event.data);
      
      if (message.type === 'audio_chunk') {
        // Accumulate audio chunks
        audioBuffer.push(new Uint8Array(message.data.audio));
        
      } else if (message.type === 'end_turn') {
        // Process accumulated audio
        const fullAudio = concatenateAudioBuffers(audioBuffer);
        audioBuffer = []; // Reset
        
        // 1. Speech-to-Text
        const transcription = await speechToText(fullAudio, message.data.language || currentLanguage);
        
        socket.send(JSON.stringify({
          type: 'transcription',
          data: {
            text: transcription.text,
            confidence: transcription.confidence,
            language: transcription.language
          }
        }));
        
        // 2. Add to conversation history
        conversationHistory.push({
          role: 'user',
          content: transcription.text
        });
        
        // 3. Get LLM response
        const llmResponse = await getLLMResponse(
          conversationHistory,
          transcription.language
        );
        
        conversationHistory.push({
          role: 'assistant',
          content: llmResponse.text
        });
        
        socket.send(JSON.stringify({
          type: 'llm_response',
          data: {
            response_text: llmResponse.text,
            scripture_references: llmResponse.scripture_refs
          }
        }));
        
        // 4. Text-to-Speech
        const audioResponse = await textToSpeech(
          llmResponse.text,
          transcription.language
        );
        
        // Stream audio back in chunks
        const chunkSize = 4096;
        for (let i = 0; i < audioResponse.length; i += chunkSize) {
          const chunk = audioResponse.slice(i, i + chunkSize);
          socket.send(JSON.stringify({
            type: 'audio_response',
            data: {
              audio_chunk: chunk,
              audio_format: 'opus'
            }
          }));
        }
        
      } else if (message.type === 'text_message') {
        // Direct text input (for testing or accessibility)
        conversationHistory.push({
          role: 'user',
          content: message.data.text
        });
        
        const llmResponse = await getLLMResponse(
          conversationHistory,
          message.data.language || currentLanguage
        );
        
        // ... same TTS flow as above
      }
      
    } catch (error) {
      socket.send(JSON.stringify({
        type: 'error',
        data: {
          error_code: 'PROCESSING_ERROR',
          error_message: error.message
        }
      }));
    }
  };
  
  return response;
});

async function speechToText(audioBuffer: Uint8Array, language: string) {
  const [response] = await speechClient.recognize({
    config: {
      encoding: 'LINEAR16',
      sampleRateHertz: 16000,
      languageCode: language,
      alternativeLanguageCodes: ['en-US', 'hi-IN', 'ml-IN'].filter(l => l !== language),
      enableAutomaticPunctuation: true,
      model: 'latest_long'
    },
    audio: {
      content: audioBuffer.toString('base64')
    }
  });
  
  const transcription = response.results
    .map(result => result.alternatives[0])
    .find(alt => alt.confidence > 0.7);
  
  return {
    text: transcription?.transcript || '',
    confidence: transcription?.confidence || 0,
    language: language
  };
}

async function getLLMResponse(
  conversationHistory: Array<{ role: string; content: string }>,
  language: string
) {
  const systemPrompt = getSystemPrompt(language);
  
  const completion = await openai.chat.completions.create({
    model: 'gpt-4-turbo-preview',
    messages: [
      { role: 'system', content: systemPrompt },
      ...conversationHistory
    ],
    temperature: 0.7,
    max_tokens: 500
  });
  
  const responseText = completion.choices[0].message.content;
  
  // Extract scripture references (simple regex)
  const scriptureRefs = extractScriptureReferences(responseText);
  
  return {
    text: responseText,
    scripture_refs: scriptureRefs
  };
}

async function textToSpeech(text: string, language: string) {
  const voiceConfig = TTS_VOICES[language];
  
  const [response] = await ttsClient.synthesizeSpeech({
    input: { text },
    voice: {
      languageCode: language,
      name: voiceConfig.name,
      ssmlGender: voiceConfig.gender
    },
    audioConfig: {
      audioEncoding: 'OGG_OPUS',
      speakingRate: voiceConfig.speakingRate,
      pitch: voiceConfig.pitch
    }
  });
  
  return response.audioContent;
}

function concatenateAudioBuffers(buffers: Uint8Array[]): Uint8Array {
  const totalLength = buffers.reduce((sum, buf) => sum + buf.length, 0);
  const result = new Uint8Array(totalLength);
  let offset = 0;
  for (const buf of buffers) {
    result.set(buf, offset);
    offset += buf.length;
  }
  return result;
}

function extractScriptureReferences(text: string): string[] {
  // Simple regex for Bible references
  const regex = /\b\d?\s?[A-Z][a-z]+\s+\d+:\d+(-\d+)?\b/g;
  return text.match(regex) || [];
}

const TTS_VOICES = {
  'en-US': {
    name: 'en-US-Neural2-J',
    gender: 'FEMALE',
    speakingRate: 0.95,
    pitch: 0.0
  },
  'hi-IN': {
    name: 'hi-IN-Neural2-A',
    gender: 'FEMALE',
    speakingRate: 0.9,
    pitch: 0.0
  },
  'ml-IN': {
    name: 'ml-IN-Wavenet-A',
    gender: 'FEMALE',
    speakingRate: 0.9,
    pitch: 0.0
  }
};

function getSystemPrompt(language: string): string {
  const prompts = {
    'en-US': `You are a knowledgeable Bible study assistant. Provide theologically sound answers based on orthodox Christian doctrine. Cite Scripture references when relevant. Keep responses conversational and under 150 words.`,
    
    'hi-IN': `आप एक जानकार बाइबल अध्ययन सहायक हैं। रूढ़िवादी ईसाई सिद्धांत के आधार पर धर्मशास्त्रीय रूप से सही उत्तर प्रदान करें। प्रासंगिक होने पर धर्मग्रंथ के संदर्भ उद्धृत करें। प्रतिक्रियाओं को संवादात्मक और 150 शब्दों से कम रखें।`,
    
    'ml-IN': `നിങ്ങൾ ഒരു അറിവുള്ള ബൈബിൾ പഠന സഹായകനാണ്. യാഥാസ്ഥിതിക ക്രിസ്ത്യൻ പ്രമാണത്തെ അടിസ്ഥാനമാക്കി ദൈവശാസ്ത്രപരമായി ശരിയായ ഉത്തരങ്ങൾ നൽകുക. പ്രസക്തമാകുമ്പോൾ തിരുവെഴുത്ത് റഫറൻസുകൾ ഉദ്ധരിക്കുക. പ്രതികരണങ്ങൾ സംഭാഷണാത്മകവും 150 വാക്കുകൾക്ക് താഴെയും ആയി സൂക്ഷിക്കുക.`
  };
  
  return prompts[language] || prompts['en-US'];
}
```

---

#### **POST /voice/end-conversation**
End conversation and save to history.

**Request:**
```typescript
{
  conversation_id: string,
  rating?: number, // 1-5
  feedback_text?: string,
  was_helpful?: boolean
}
```

**Response:**
```typescript
{
  success: boolean,
  conversation_summary: {
    total_messages: number,
    total_duration_seconds: number,
    topics_discussed: string[]
  }
}
```

---

#### **GET /voice/conversation-history**
Retrieve past voice conversations.

**Request:** Query params: `user_id`, `limit?`, `offset?`

**Response:**
```typescript
{
  conversations: Array<{
    id: string,
    session_id: string,
    language: string,
    conversation_type: string,
    total_messages: number,
    total_duration_seconds: number,
    started_at: string,
    ended_at: string,
    rating?: number,
    messages?: Array<{
      role: 'user' | 'assistant',
      content_text: string,
      created_at: string
    }>
  }>,
  total_count: number
}
```

---

#### **GET /voice/quota-status**
Check current voice usage quota.

**Request:** Query params: `user_id`

**Response:**
```typescript
{
  tier: 'free' | 'standard' | 'premium',
  quota_limit: number,
  quota_used: number,
  quota_remaining: number,
  can_start_conversation: boolean,
  resets_at: string // ISO timestamp for midnight
}
```

---

## 6. Phase-Wise Development Plan

### Phase 1: Voice Infrastructure (Week 1)

**Objective:** Set up basic voice recording, playback, and API integration.

#### Tasks:
1. **Flutter Voice Plugins** (2 days)
   - [ ] Integrate `speech_to_text` plugin
   - [ ] Test multi-language recognition (EN, HI, ML)
   - [ ] Integrate `flutter_tts` plugin
   - [ ] Test multi-language synthesis
   - [ ] Integrate `record` plugin for audio capture
   - [ ] Test audio quality (16kHz, mono, WAV)

2. **Google Cloud Setup** (1 day)
   - [ ] Create Google Cloud project
   - [ ] Enable Speech-to-Text API
   - [ ] Enable Text-to-Speech API
   - [ ] Configure service account credentials
   - [ ] Test API from Edge Function
   - [ ] Set up billing alerts

3. **Database Schema** (1 day)
   - [ ] Create all voice-related tables
   - [ ] Implement RLS policies
   - [ ] Create database functions (quota check, usage tracking)
   - [ ] Write migration scripts
   - [ ] Seed test data

4. **Basic UI Components** (1 day)
   - [ ] Create voice button widget
   - [ ] Build recording indicator (waveform animation)
   - [ ] Design conversation bubble layout
   - [ ] Add language selector dropdown

**Deliverables:**
- ✅ Voice recording and playback working
- ✅ Multi-language STT/TTS tested
- ✅ Database schema deployed
- ✅ Basic UI scaffolding

**Success Criteria:**
- Can record and transcribe speech in all 3 languages
- TTS produces natural-sounding audio
- Database handles concurrent operations

---

### Phase 2: Multi-Language Integration (Week 1-2)

**Objective:** Implement full multi-language voice conversation flow.

#### Tasks:
1. **Language Detection** (2 days)
   - [ ] Implement auto-language detection in STT
   - [ ] Create language preference management
   - [ ] Build language switching UI
   - [ ] Test language transitions mid-conversation
   - [ ] Handle mixed-language input

2. **Multi-Language LLM Prompts** (2 days)
   - [ ] Design system prompts for each language
   - [ ] Add theological terminology in HI and ML
   - [ ] Test response quality in all languages
   - [ ] Ensure Scripture citations in correct language
   - [ ] Validate cultural appropriateness

3. **Voice Preferences** (1 day)
   - [ ] Create voice settings screen
   - [ ] Implement TTS customization (speed, pitch)
   - [ ] Add voice gender selection
   - [ ] Save preferences to database
   - [ ] Apply preferences in conversations

**Deliverables:**
- ✅ Full multi-language conversation support
- ✅ Language auto-detection and switching
- ✅ Customizable voice preferences

**Success Criteria:**
- Users can converse in any of the 3 languages
- Language switching is seamless
- Responses are culturally and theologically appropriate

---

### Phase 3: AI Conversation Engine (Week 2-3)

**Objective:** Build intelligent conversation management with context awareness.

#### Tasks:
1. **WebSocket Streaming** (3 days)
   - [ ] Implement WebSocket Edge Function
   - [ ] Build bidirectional audio/text streaming
   - [ ] Handle chunked audio upload
   - [ ] Stream LLM responses in real-time
   - [ ] Implement error handling and reconnection

2. **Conversation Context Management** (2 days)
   - [ ] Track conversation history in memory
   - [ ] Include user's current study context
   - [ ] Retrieve relevant Scripture passages
   - [ ] Maintain theological accuracy
   - [ ] Implement conversation summarization

3. **Quota Management** (1 day)
   - [ ] Implement tier-based quotas (Free: 3, Standard: 10, Premium: unlimited)
   - [ ] Create quota checking function
   - [ ] Display quota status in UI
   - [ ] Handle quota exceeded gracefully
   - [ ] Send upgrade prompts for free users

**Deliverables:**
- ✅ Real-time voice conversation streaming
- ✅ Context-aware AI responses
- ✅ Quota system fully functional

**Success Criteria:**
- End-to-end voice conversation works smoothly
- AI responses are contextually relevant
- Quota limits enforced correctly

---

### Phase 4: UI & User Experience (Week 3-4)

**Objective:** Polish UI, add conversation history, and enhance UX.

#### Tasks:
1. **Voice Interface Polish** (3 days)
   - [ ] Design main voice screen layout
   - [ ] Add conversation bubbles with avatars
   - [ ] Implement waveform visualization during recording
   - [ ] Show real-time transcription
   - [ ] Add "thinking" animation during LLM processing
   - [ ] Display Scripture references as chips

2. **Conversation History** (2 days)
   - [ ] Create conversation history screen
   - [ ] Display past conversations with timestamps
   - [ ] Allow replay of previous conversations
   - [ ] Implement search/filter by topic or date
   - [ ] Add export conversation feature (text)

3. **Feedback & Rating** (1 day)
   - [ ] Add post-conversation rating dialog
   - [ ] Collect feedback on accuracy
   - [ ] Implement "Report Issue" for theology concerns
   - [ ] Track helpful vs unhelpful responses
   - [ ] Send feedback to analytics

**Deliverables:**
- ✅ Polished voice conversation UI
- ✅ Conversation history and replay
- ✅ User feedback system

**Success Criteria:**
- UI is intuitive and visually appealing
- Users can easily access past conversations
- Feedback collection is seamless

---

### Phase 5: Testing & Launch (Week 4)

**Objective:** Comprehensive testing, optimization, and production launch.

#### Tasks:
1. **Testing** (2 days)
   - [ ] Unit tests for all API endpoints
   - [ ] Integration tests for voice flow
   - [ ] Multi-language testing (EN, HI, ML)
   - [ ] Load testing with 50+ concurrent users
   - [ ] Edge case testing (network failures, poor audio)
   - [ ] Accessibility testing (screen reader support)

2. **Performance Optimization** (2 days)
   - [ ] Reduce STT latency (<1s)
   - [ ] Optimize LLM token usage
   - [ ] Implement response caching
   - [ ] Compress audio streams
   - [ ] Monitor API costs

3. **Launch Preparation** (1 day)
   - [ ] Write user documentation
   - [ ] Create tutorial video
   - [ ] Set up monitoring and alerts
   - [ ] Configure error tracking (Sentry)
   - [ ] Prepare marketing materials
   - [ ] Deploy to production

**Deliverables:**
- ✅ Fully tested and optimized feature
- ✅ Documentation complete
- ✅ Production deployment

**Success Criteria:**
- Zero critical bugs in production
- Response latency <2s on average
- Cost per conversation <$0.10

---

## 7. UI Components

### 7.1 Main Voice Screen

```dart
// frontend/lib/features/voice_buddy/presentation/screens/voice_buddy_screen.dart

class VoiceBuddyScreen extends StatefulWidget {
  @override
  _VoiceBuddyScreenState createState() => _VoiceBuddyScreenState();
}

class _VoiceBuddyScreenState extends State<VoiceBuddyScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  List<ConversationMessage> messages = [];
  bool isListening = false;
  bool isProcessing = false;
  String currentLanguage = 'en-US';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Study Buddy'),
        actions: [
          // Language Selector
          DropdownButton<String>(
            value: currentLanguage,
            icon: Icon(Icons.language, color: Colors.white),
            underline: SizedBox(),
            items: [
              DropdownMenuItem(value: 'en-US', child: Text('🇺🇸 English')),
              DropdownMenuItem(value: 'hi-IN', child: Text('🇮🇳 हिन्दी')),
              DropdownMenuItem(value: 'ml-IN', child: Text('🇮🇳 മലയാളം')),
            ],
            onChanged: (value) {
              setState(() => currentLanguage = value!);
            },
          ),
          
          // Settings
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/voice-settings'),
          ),
        ],
      ),
      
      body: Column(
        children: [
          // Quota Status Banner
          _buildQuotaBanner(),
          
          // Conversation Messages
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(messages[index]);
              },
            ),
          ),
          
          // Transcription Display (while listening)
          if (isListening)
            _buildTranscriptionOverlay(),
          
          // Voice Controls
          _buildVoiceControls(),
        ],
      ),
    );
  }
  
  Widget _buildQuotaBanner() {
    return BlocBuilder<VoiceQuotaBloc, VoiceQuotaState>(
      builder: (context, state) {
        if (state is VoiceQuotaLoaded) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.highlight.withOpacity(0.2),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  state.tier == 'premium'
                      ? 'Unlimited conversations'
                      : '${state.quotaRemaining} conversations left today',
                  style: AppTextStyles.bodySmall,
                ),
                Spacer(),
                if (state.tier != 'premium')
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/upgrade'),
                    child: Text('Upgrade'),
                  ),
              ],
            ),
          );
        }
        return SizedBox.shrink();
      },
    );
  }
  
  Widget _buildMessageBubble(ConversationMessage message) {
    final isUser = message.role == 'user';
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: isUser ? 64 : 0,
          right: isUser ? 0 : 64,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isUser) ...[
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.smart_toy, color: Colors.white, size: 20),
              ),
              SizedBox(width: 8),
            ],
            
            Flexible(
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUser 
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUser ? AppColors.primary : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.contentText,
                      style: AppTextStyles.bodyMedium,
                    ),
                    
                    // Scripture References (for AI responses)
                    if (!isUser && message.scriptureRefs != null && message.scriptureRefs!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 8,
                          children: message.scriptureRefs!.map((ref) {
                            return Chip(
                              label: Text(ref, style: AppTextStyles.labelSmall),
                              backgroundColor: AppColors.highlight.withOpacity(0.3),
                              padding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                      ),
                    
                    // Timestamp
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        _formatTime(message.createdAt),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (isUser) ...[
              SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildVoiceControls() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Waveform Visualization (when listening)
          if (isListening)
            SizedBox(
              height: 60,
              child: VoiceWaveform(isActive: isListening),
            ),
          
          SizedBox(height: 16),
          
          // Main Voice Button
          GestureDetector(
            onTapDown: (_) => _startListening(),
            onTapUp: (_) => _stopListening(),
            onTapCancel: () => _cancelListening(),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isListening
                      ? [AppColors.primary, AppColors.primary.withOpacity(0.7)]
                      : [AppColors.primary, AppColors.secondary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: isListening ? 10 : 0,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
          
          SizedBox(height: 12),
          
          // Instruction Text
          Text(
            isListening
                ? 'Listening...'
                : isProcessing
                    ? 'Processing...'
                    : 'Tap and hold to speak',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTranscriptionOverlay() {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.highlight.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.highlight),
      ),
      child: Row(
        children: [
          Icon(Icons.mic, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              _currentTranscription.isEmpty
                  ? 'Start speaking...'
                  : _currentTranscription,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
  
  // Voice interaction methods
  String _currentTranscription = '';
  
  Future<void> _startListening() async {
    bool available = await _speechToText.initialize();
    
    if (available) {
      setState(() {
        isListening = true;
        _currentTranscription = '';
      });
      
      _speechToText.listen(
        onResult: (result) {
          setState(() {
            _currentTranscription = result.recognizedWords;
          });
        },
        localeId: currentLanguage,
        listenMode: ListenMode.confirmation,
      );
    }
  }
  
  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() => isListening = false);
    
    if (_currentTranscription.isNotEmpty) {
      _sendMessage(_currentTranscription);
    }
  }
  
  void _cancelListening() {
    _speechToText.cancel();
    setState(() {
      isListening = false;
      _currentTranscription = '';
    });
  }
  
  Future<void> _sendMessage(String text) async {
    // Add user message
    setState(() {
      messages.add(ConversationMessage(
        role: 'user',
        contentText: text,
        createdAt: DateTime.now(),
      ));
      isProcessing = true;
    });
    
    // Send to API via BLoC
    context.read<VoiceBuddyBloc>().add(
      SendVoiceMessage(
        text: text,
        language: currentLanguage,
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
```

### 7.2 Voice Waveform Widget

```dart
// frontend/lib/features/voice_buddy/presentation/widgets/voice_waveform.dart

class VoiceWaveform extends StatefulWidget {
  final bool isActive;
  
  const VoiceWaveform({Key? key, required this.isActive}) : super(key: key);
  
  @override
  _VoiceWaveformState createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _heights = List.generate(50, (_) => 0.2);
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    
    if (widget.isActive) {
      _startAnimation();
    }
  }
  
  @override
  void didUpdateWidget(VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startAnimation();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopAnimation();
    }
  }
  
  void _startAnimation() {
    _timer = Timer.periodic(Duration(milliseconds: 100), (_) {
      setState(() {
        for (int i = 0; i < _heights.length; i++) {
          _heights[i] = 0.2 + (0.8 * (0.5 + 0.5 * sin((DateTime.now().millisecondsSinceEpoch / 100.0) + i * 0.3)));
        }
      });
    });
  }
  
  void _stopAnimation() {
    _timer?.cancel();
    setState(() {
      for (int i = 0; i < _heights.length; i++) {
        _heights[i] = 0.2;
      }
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: _heights.asMap().entries.map((entry) {
        return Container(
          width: 3,
          height: 60 * entry.value,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }
}
```

---

## 8. Voice Integration

### 8.1 Flutter Speech-to-Text Setup

```dart
// frontend/lib/core/services/speech_service.dart

import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    _isInitialized = await _speech.initialize(
      onError: (error) => print('Speech error: ${error.errorMsg}'),
      onStatus: (status) => print('Speech status: $status'),
    );
    
    return _isInitialized;
  }
  
  Future<List<stt.LocaleName>> getAvailableLanguages() async {
    return await _speech.locales();
  }
  
  Future<void> startListening({
    required String languageCode,
    required Function(String) onResult,
    Duration? timeout,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
      localeId: languageCode,
      listenMode: stt.ListenMode.confirmation,
      pauseFor: timeout ?? Duration(seconds: 3),
      partialResults: true,
      onSoundLevelChange: (level) {
        // Can use for waveform visualization
        print('Sound level: $level');
      },
    );
  }
  
  Future<void> stopListening() async {
    await _speech.stop();
  }
  
  Future<void> cancelListening() async {
    await _speech.cancel();
  }
  
  bool get isListening => _speech.isListening;
}
```

### 8.2 Flutter Text-to-Speech Setup

```dart
// frontend/lib/core/services/tts_service.dart

import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _tts.setSharedInstance(true);
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [IosTextToSpeechAudioCategoryOptions.allowBluetooth],
    );
    
    _tts.setStartHandler(() {
      print('TTS started');
    });
    
    _tts.setCompletionHandler(() {
      print('TTS completed');
    });
    
    _tts.setErrorHandler((msg) {
      print('TTS error: $msg');
    });
    
    _isInitialized = true;
  }
  
  Future<List<dynamic>> getAvailableLanguages() async {
    return await _tts.getLanguages;
  }
  
  Future<List<dynamic>> getAvailableVoices() async {
    return await _tts.getVoices;
  }
  
  Future<void> setLanguage(String languageCode) async {
    await _tts.setLanguage(languageCode);
  }
  
  Future<void> setVoice(Map<String, String> voice) async {
    await _tts.setVoice(voice);
  }
  
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate); // 0.0 to 1.0
  }
  
  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch); // 0.5 to 2.0
  }
  
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    await _tts.speak(text);
  }
  
  Future<void> stop() async {
    await _tts.stop();
  }
  
  Future<void> pause() async {
    await _tts.pause();
  }
  
  bool get isSpeaking => _tts.isSpeaking;
}
```

---

## 9. LLM Integration

### 9.1 Multi-Language Prompts

```typescript
// backend/supabase/functions/_shared/prompts/voice-conversation.ts

export const VOICE_CONVERSATION_PROMPTS = {
  'en-US': {
    system: `You are a knowledgeable and friendly Bible study assistant.

CORE PRINCIPLES:
- Provide theologically sound answers based on orthodox Christian doctrine
- Be conversational and warm, like a trusted pastor
- Cite Scripture references when relevant
- Keep responses under 150 words for voice clarity
- Use simple language appropriate for voice conversation

THEOLOGICAL GUIDELINES:
- Uphold salvation by grace through faith in Jesus Christ
- Present balanced biblical perspectives
- Avoid controversial or divisive interpretations
- Direct users to Scripture for ultimate authority

USER CONTEXT:
- Maturity Level: {{maturity_level}}
- Current Study: {{current_study}}
- Recent Topics: {{recent_topics}}

Respond naturally as if having a phone conversation with a church member seeking guidance.`,
    
    examples: [
      {
        user: "What does it mean to have faith?",
        assistant: "Great question! Faith, according to Hebrews 11:1, is confidence in what we hope for and assurance about what we don't see. It's trusting God's character and promises even when circumstances are unclear. Think of Abraham - he believed God's promise of descendants even when it seemed impossible. Faith isn't blind belief, but trust based on knowing God through His Word and experiencing His faithfulness. How does this understanding resonate with your current spiritual journey?"
      }
    ]
  },
  
  'hi-IN': {
    system: `आप एक जानकार और मित्रवत बाइबल अध्ययन सहायक हैं।

मूल सिद्धांत:
- रूढ़िवादी ईसाई सिद्धांत के आधार पर धर्मशास्त्रीय रूप से सही उत्तर प्रदान करें
- एक विश्वसनीय पादरी की तरह संवादात्मक और गर्मजोशी भरे रहें
- प्रासंगिक होने पर धर्मग्रंथ के संदर्भ उद्धृत करें
- स्पष्टता के लिए 150 शब्दों के अंदर उत्तर रखें
- बोलचाल की भाषा में सरल भाषा का उपयोग करें

धर्मशास्त्रीय दिशानिर्देश:
- यीशु मसीह में विश्वास के माध्यम से अनुग्रह द्वारा उद्धार को बनाए रखें
- संतुलित बाइबिल दृष्टिकोण प्रस्तुत करें
- विवादास्पद या विभाजनकारी व्याख्याओं से बचें
- अंतिम अधिकार के लिए उपयोगकर्ताओं को धर्मग्रंथ की ओर निर्देशित करें

उपयोगकर्ता संदर्भ:
- परिपक्वता स्तर: {{maturity_level}}
- वर्तमान अध्ययन: {{current_study}}
- हाल के विषय: {{recent_topics}}

स्वाभाविक रूप से जवाब दें जैसे कि मार्गदर्शन चाहने वाले चर्च सदस्य के साथ फोन पर बातचीत कर रहे हों।`,
    
    examples: [
      {
        user: "विश्वास का क्या अर्थ है?",
        assistant: "बहुत अच्छा सवाल! इब्रानियों 11:1 के अनुसार, विश्वास उस चीज़ पर भरोसा है जिसकी हम आशा करते हैं और जो हम नहीं देखते उसके बारे में आश्वासन है। यह परमेश्वर के चरित्र और वादों पर भरोसा करना है, भले ही परिस्थितियाँ अस्पष्ट हों। अब्राहम के बारे में सोचें - उन्होंने संतान के परमेश्वर के वादे पर विश्वास किया, भले ही यह असंभव लग रहा था। विश्वास अंधा विश्वास नहीं है, बल्कि उसके वचन के माध्यम से परमेश्वर को जानने और उसकी विश्वासयोग्यता का अनुभव करने पर आधारित विश्वास है।"
      }
    ]
  },
  
  'ml-IN': {
    system: `നിങ്ങൾ അറിവുള്ളതും സൗഹൃദപരവുമായ ബൈബിൾ പഠന സഹായകനാണ്.

അടിസ്ഥാന തത്ത്വങ്ങൾ:
- യാഥാസ്ഥിതിക ക്രിസ്ത്യൻ പ്രമാണത്തെ അടിസ്ഥാനമാക്കി ദൈവശാസ്ത്രപരമായി ശരിയായ ഉത്തരങ്ങൾ നൽകുക
- വിശ്വസ്ത പാസ്റ്ററെപ്പോലെ സംഭാഷണാത്മകവും ഊഷ്മളവുമായിരിക്കുക
- പ്രസക്തമാകുമ്പോൾ തിരുവെഴുത്ത് റഫറൻസുകൾ ഉദ്ധരിക്കുക
- വോയ്‌സ് വ്യക്തതയ്ക്കായി 150 വാക്കുകൾക്ക് താഴെ പ്രതികരണങ്ങൾ സൂക്ഷിക്കുക
- സംഭാഷണത്തിന് അനുയോജ്യമായ ലളിതമായ ഭാഷ ഉപയോഗിക്കുക

ദൈവശാസ്ത്ര മാർഗ്ഗനിർദ്ദേശങ്ങൾ:
- യേശുക്രിസ്തുവിലുള്ള വിശ്വാസത്തിലൂടെ കൃപയാൽ രക്ഷ ഉയർത്തിപ്പിടിക്കുക
- സമതുലിതമായ ബൈബിൾ വീക്ഷണങ്ങൾ അവതരിപ്പിക്കുക
- വിവാദപരമോ വിഭജനപരമോ ആയ വ്യാഖ്യാനങ്ങൾ ഒഴിവാക്കുക
- ആത്യന്തിക അധികാരത്തിനായി ഉപയോക്താക്കളെ തിരുവെഴുത്തിലേക്ക് നയിക്കുക

ഉപയോക്തൃ സന്ദർഭം:
- പക്വത നില: {{maturity_level}}
- നിലവിലെ പഠനം: {{current_study}}
- സമീപകാല വിഷയങ്ങൾ: {{recent_topics}}

മാർഗനിർദേശം തേടുന്ന ഒരു സഭാംഗവുമായി ഫോണിൽ സംസാരിക്കുന്നത് പോലെ സ്വാഭാവികമായി പ്രതികരിക്കുക.`,
    
    examples: [
      {
        user: "വിശ്വാസം എന്താണ്?",
        assistant: "മികച്ച ചോദ്യം! എബ്രായർ 11:1 അനുസരിച്ച്, നാം പ്രതീക്ഷിക്കുന്നതിൽ ആത്മവിശ്വാസവും കാണാത്തതിനെക്കുറിച്ചുള്ള ഉറപ്പുമാണ് വിശ്വാസം. സാഹചര്യങ്ങൾ വ്യക്തമല്ലെങ്കിലും ദൈവത്തിന്റെ സ്വഭാവത്തിലും വാഗ്ദാനങ്ങളിലും വിശ്വസിക്കുന്നതാണ്. അബ്രഹാമിനെക്കുറിച്ച് ചിന്തിക്കുക - അത് അസാധ്യമെന്ന് തോന്നിയപ്പോഴും സന്തതികളെക്കുറിച്ചുള്ള ദൈവത്തിന്റെ വാഗ്ദാനത്തിൽ അദ്ദേഹം വിശ്വസിച്ചു. വിശ്വാസം അന്ധമായ വിശ്വാസമല്ല, മറിച്ച് അവന്റെ വചനത്തിലൂടെ ദൈവത്തെ അറിയുന്നതിലും അവന്റെ വിശ്വസ്തത അനുഭവിക്കുന്നതിലും അധിഷ്ഠിതമായ വിശ്വാസമാണ്."
      }
    ]
  }
};
```

---

## 10. Testing Strategy

### 10.1 Multi-Language Testing

**Test Cases:**
```dart
// frontend/test/features/voice_buddy/voice_buddy_test.dart

void main() {
  group('Multi-Language Voice Conversation', () {
    testWidgets('should recognize English speech correctly', (tester) async {
      // Setup
      await tester.pumpWidget(MyApp());
      await tester.tap(find.text('Voice Buddy'));
      await tester.pumpAndSettle();
      
      // Select English
      await tester.tap(find.text('🇺🇸 English'));
      await tester.pumpAndSettle();
      
      // Simulate voice input (mock)
      // In real testing, use integration tests with actual audio
      
      // Verify transcription appears
      expect(find.text('What is grace?'), findsOneWidget);
    });
    
    testWidgets('should switch language mid-conversation', (tester) async {
      // Start in English
      await tester.tap(find.text('🇺🇸 English'));
      await tester.pumpAndSettle();
      
      // Send message in English
      // ... 
      
      // Switch to Hindi
      await tester.tap(find.text('🇮🇳 हिन्दी'));
      await tester.pumpAndSettle();
      
      // Verify language changed
      expect(find.text('🇮🇳 हिन्दी'), findsOneWidget);
    });
    
    testWidgets('should handle Malayalam script correctly', (tester) async {
      await tester.tap(find.text('🇮🇳 മലയാളം'));
      await tester.pumpAndSettle();
      
      // Verify Malayalam UI elements render
      expect(find.textContaining('മലയാളം'), findsWidgets);
    });
  });
}
```

### 10.2 Theological Accuracy Testing

**Manual Review Process:**
```markdown
# Theological Review Checklist

For each language, test the following topics:

1. **Core Doctrines:**
   - Salvation by grace through faith
   - Trinity
   - Deity of Christ
   - Resurrection

2. **Controversial Topics:**
   - Predestination vs free will
   - Baptism
   - Spiritual gifts
   - End times

3. **Cultural Sensitivity:**
   - Hindu background (for Hindi users)
   - Local church practices (for Malayalam users)
   - Western vs Eastern Christianity

4. **Scripture Citation:**
   - Verify correct translation cited
   - Check verse accuracy
   - Ensure context preserved
```

---

## 11. Success Metrics

### 11.1 Adoption Metrics

**Week 1:**
- 40%+ of premium users try voice at least once
- 25%+ complete a full conversation
- 20%+ try in non-English language

**Month 1:**
- 60%+ of premium users have tried voice
- 35%+ are weekly active voice users
- Average 3 conversations per active user per week

**Month 3:**
- 70%+ of premium users have tried voice
- 45%+ are weekly active voice users
- Top 3 reason for free → premium conversion

### 11.2 Quality Metrics

**Speech Recognition:**
- Transcription accuracy: >90% for all languages
- Average latency: <1s from speech end to transcription

**LLM Responses:**
- Theological accuracy: <5% flagged issues
- Response relevance: >80% rated "helpful"
- Average response time: <2s

**Text-to-Speech:**
- Voice naturalness: 4.5+ / 5.0 rating
- Pronunciation accuracy: >95% for all languages

### 11.3 Usage Patterns

**Language Distribution:**
- English: 60-70% of conversations
- Hindi: 20-30% of conversations
- Malayalam: 10-15% of conversations

**Conversation Types:**
- General questions: 40%
- Study enhancement: 30%
- Scripture inquiry: 20%
- Prayer guidance: 10%

**Time of Day:**
- Morning (6am-9am): 35%
- Commute (5pm-7pm): 30%
- Evening (8pm-10pm): 25%
- Other: 10%

---

## 12. Cost Analysis

### 12.1 Per-Conversation Cost Breakdown

**Speech-to-Text (Google Cloud):**
- English: $0.006 per minute
- Hindi/Malayalam: $0.009 per minute
- Average conversation: 5 minutes
- **STT Cost: $0.03 - $0.045 per conversation**

**Text-to-Speech (Google Cloud):**
- Neural voices: $16 per 1M characters
- Average response: 500 characters
- **TTS Cost: $0.008 per conversation**

**LLM Processing (OpenAI GPT-4 Turbo):**
- Input: $10 per 1M tokens (~750 words per conversation)
- Output: $30 per 1M tokens (~150 words per response)
- **LLM Cost: $0.012 per conversation**

**Total Cost Per Conversation:**
- Low estimate (English, short): $0.05
- Average estimate: $0.07
- High estimate (Non-English, long): $0.10

### 12.2 Monthly Cost Projections

**Scenario: 1000 Premium Users**
- Average 4 conversations/user/week = 16K conversations/month
- Cost: 16,000 × $0.07 = **$1,120/month**

**Scenario: 5000 Premium Users**
- Average 4 conversations/user/week = 80K conversations/month
- Cost: 80,000 × $0.07 = **$5,600/month**

### 12.3 Cost Optimization Strategies

1. **Response Caching:**
   - Cache common theological questions
   - Save 30-40% on repeat queries

2. **Tiered LLM Models:**
   - Use GPT-3.5 for simple queries
   - Reserve GPT-4 for complex theology
   - Save 50% on LLM costs

3. **Audio Compression:**
   - Use Opus codec for streaming
   - Reduce bandwidth by 60%

4. **Flutter TTS Fallback:**
   - Use local TTS for offline/budget mode
   - Zero cost per use

**Optimized Cost:** $0.04 per conversation (~43% savings)

---

## 13. Future Enhancements

### Version 2.0 (Post-Launch + 2 months)

**Advanced Features:**
- Wake word detection ("Hey Buddy")
- Offline mode with cached responses
- Multi-user conversations (group Bible study)
- Voice notes and journaling
- Integration with Memory Verses (voice practice)

**Additional Languages:**
- Tamil, Telugu, Kannada (South Indian languages)
- Spanish, Portuguese (global reach)

**AI Enhancements:**
- Voice emotion detection (adjust tone)
- Personalized voice profiles
- Custom wake words per user

---

## 14. Launch Checklist

### Pre-Launch (1 week before)

- [ ] All unit tests passing
- [ ] Multi-language testing complete (EN, HI, ML)
- [ ] Theological review completed for all languages
- [ ] Load testing (100 concurrent conversations)
- [ ] Cost monitoring dashboards setup
- [ ] Privacy policy updated (voice data)
- [ ] Help documentation (3 languages)
- [ ] Beta testing with 30 users (10 per language)
- [ ] Error tracking configured (Sentry)
- [ ] Analytics events verified

### Launch Day

- [ ] Deploy backend Edge Functions
- [ ] Deploy Flutter app update
- [ ] Verify WebSocket connections
- [ ] Test end-to-end in production (all languages)
- [ ] Monitor error rates
- [ ] Monitor API costs in real-time
- [ ] Send launch announcement (multi-language)
- [ ] Customer support ready (multi-language)
- [ ] Standby for hotfixes

### Post-Launch (Week 1)

- [ ] Daily metrics review (adoption, quality, cost)
- [ ] User feedback collection (all languages)
- [ ] Bug triage and fixes
- [ ] Theological accuracy monitoring
- [ ] Performance optimization
- [ ] A/B testing different prompts

---

**Document Status:** ✅ Complete - Ready for Development

**Next Steps:**
1. Review with product, engineering, and theology teams
2. Allocate resources for 4-week development
3. Begin Phase 1: Voice Infrastructure
4. Schedule weekly sprint reviews

---

*End of AI Study Buddy Voice Technical Specification v1.0*
