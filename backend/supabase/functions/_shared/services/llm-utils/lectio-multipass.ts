/**
 * Multi-Pass Lectio Divina Generation
 *
 * Breaks Lectio Divina generation into 2 passes to work within model token limits:
 * - Pass 1: Summary + Context + Lectio (Reading) + Meditatio (Meditation)
 * - Pass 2: Oratio (Prayer) + Contemplatio (Contemplation) + Supporting Fields
 *
 * This allows Hindi/Malayalam Lectio studies to achieve better word counts
 * despite token inefficiency (Hindi: 0.28 words/token, Malayalam: 0.09 words/token)
 */

import { type LLMGenerationParams, type LanguageConfig, type PromptPair } from '../llm-types.ts'
import {
  THEOLOGICAL_FOUNDATION,
  JSON_OUTPUT_RULES,
  createLanguageBlock,
  createVerseReferenceBlock
} from './prompt-builder.ts'

export type LectioPass = 'pass1' | 'pass2'

export interface LectioPassResult {
  pass: LectioPass
  content: string
}

/**
 * Creates the first pass prompt: Summary + Context + Lectio + Meditatio
 */
export function createLectioPass1Prompt(
  params: LLMGenerationParams,
  languageConfig: LanguageConfig
): PromptPair {
  const { inputType, inputValue, topicDescription, language } = params

  const taskDescription = inputType === 'scripture'
    ? `Create a LECTIO DIVINA guide for: \"${inputValue}\"`
    : inputType === 'topic'
    ? `Create a LECTIO DIVINA guide on: \"${inputValue}\"${topicDescription ? `\n\nContext: ${topicDescription}` : ''}`
    : `Create a LECTIO DIVINA guide addressing: \"${inputValue}\"`

  const systemMessage = `You are a spiritual director guiding contemplative prayer through Lectio Divina.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, language)}

STUDY MODE: LECTIO DIVINA - PASS 1/2 (Reading + Meditation)
This is part 1 of a multi-pass Lectio Divina generation. Focus on sacred reading and meditation.
Target output: ~1,600 words for this pass.
Tone: Contemplative, gentle, invitational, spiritually formative.`

  const userMessage = `${taskDescription}

${createVerseReferenceBlock(language)}

═══════════════════════════════════════════════════════════════════════════
PASS 1: LECTIO DIVINA FOUNDATION (Reading + Meditation)
═══════════════════════════════════════════════════════════════════════════

Generate the following JSON structure with THESE SPECIFIC FIELDS ONLY:

{
  "summary": "[250-300 words: Title, scripture text (if applicable), central spiritual message, contemplative focus, invitation to encounter God]",
  "context": "[50-80 words: MINIMAL - gentle introduction to the contemplative practice]",
  "passage": "⚠️ MANDATORY - Scripture reference for meditation. PREFER SHORTER passages (5-12 verses) for focused contemplation (e.g., 'Psalm 23:1-6', 'John 15:1-8', 'Philippians 4:4-9'). Format: Just the reference in ${languageConfig.name}, no verse text. DO NOT skip this field.",
  "interpretationPart1": "[1200-1500 words: LECTIO (Sacred Reading) + MEDITATIO (Meditation) with slow reading guidance, word-by-word reflection, personal encounter prompts, Holy Spirit listening]"
}

CRITICAL INSTRUCTIONS FOR PASS 1:

**SUMMARY (250-300 words):**

Write an INVITATIONAL contemplative overview as CONTINUOUS NARRATIVE PROSE (NOT separate bullets).
This must be 8-12 complete sentences flowing together as a single paragraph.

Include these elements in flowing prose:
1. Begin with an invitational 4-6 word title as the opening phrase
2. [IF SCRIPTURE]: Include the full passage text for slow, meditative reading
3. Central Spiritual Message: 2-3 sentences on the spiritual truth God reveals
4. Contemplative Focus: 2-3 sentences on what God wants to say through this passage to your heart
5. Invitation to Encounter: 2-3 sentences inviting deeper communion and intimacy with God

Structure for Scripture Input (NOT literal text - write entirely in ${languageConfig.name}):
- Sentence 1: [Contemplative title] + [invites into spiritual message]
- Sentences 2-5: [FULL scripture passage text in ${languageConfig.name}]
- Sentences 6-8: [Contemplative meditation on what God speaks through these words]
- Sentences 9-10: [What this passage reveals about God's heart]
- Sentences 11-12: [Invitation to deeper intimacy and encounter with God]

Structure for Topic Input (NOT literal text - write entirely in ${languageConfig.name}):
- Sentence 1: [Contemplative title] + [draws into spiritual message]
- Sentences 2-4: [Central spiritual truth God reveals through this topic]
- Sentences 5-8: [Contemplative focus on what God wants to say to the heart]
- Sentences 9-12: [Invitation to prayerful reflection and deeper communion]

CRITICAL:
- Write ENTIRELY in ${languageConfig.name} - NO English words mixed in
- Write as a SINGLE FLOWING PARAGRAPH of 8-12 sentences
- NOT as separate bullet points or title only
- If scripture input, include the FULL passage text within the narrative flow

**CONTEXT (50-80 words):**
Write MINIMAL gentle introduction to the contemplative practice (1 concise paragraph covering):
• Brief explanation of Lectio Divina as prayerful Scripture reading
• Heart preparation: silence, openness, Holy Spirit dependence
Keep it SHORT and FOCUSED - only what's essential for entering the practice.

**INTERPRETATION PART 1 - LECTIO & MEDITATIO (1200-1500 words):**

This section MUST contain EXACTLY 3 or 4 contemplative sections of flowing spiritual prose.
EACH section MUST have 7-9 sentences with GENTLE, INVITATIONAL guidance.

⚠️ CONTEMPLATIVE DEPTH REQUIREMENTS (MANDATORY):
- MAINTAIN gentle, invitational tone throughout (never rushed or prescriptive)
- INVITE personal encounter with God through Scripture (not just information)
- GUIDE the reader into listening prayer and spiritual awareness
- EMPHASIZE the Holy Spirit's role in illumination and transformation
- BALANCE structured guidance with freedom for personal response

⚠️ SENTENCE COUNTING IS MANDATORY:
- A sentence ends with: period (.) OR question mark (?) OR exclamation point (!)
- Count each sentence as you write: "1. [sentence]. 2. [sentence]... 7. [sentence]."
- If you reach 6 sentences, ADD 1-3 MORE SENTENCES to reach 7-9
- Each section should be 300-400 words of contemplative guidance

## LECTIO: Sacred Reading (900-1100 words)

Guide the reader through slow, prayerful reading:

**Section 1 - First Reading: Listening (7-9 sentences, 300-400 words):**
- Invitation to silence: Quiet your heart and prepare to receive God's word
- Posture of listening: Come expectantly, open to the Holy Spirit
- Slow reading guidance: Read the passage at half your normal speed
- Noticing prompts: What word or phrase catches your attention? What draws you?
- Initial impressions: What stands out? What surprises you? What disturbs you?
- Spiritual marking: Circle, underline, or mark words that resonate
- Invitation to trust: God will speak through His word today
- [OPTIONAL] Physical posture: How your body can support prayerful reading
- [OPTIONAL] Breath prayer: Using breath to center yourself in God's presence

Target: 300-400 words, 7-9 complete sentences with gentle invitation.

**Section 2 - Second Reading: Noticing (7-9 sentences, 300-400 words):**
- Return to the text: Read again, even more slowly this time
- Sensory engagement: What do you see, hear, smell, taste, feel in this passage?
- Imaginative prayer: Place yourself in the scene (if narrative)
- Character identification: Where do you find yourself in the story?
- Emotional resonance: What emotions arise as you read? Welcome them.
- Holy Spirit sensitivity: Notice what the Spirit highlights or repeats
- Questions arise: What questions does this stir in your heart?
- [OPTIONAL] Hebrew/Greek meditation: If key words are available, linger on them
- [OPTIONAL] Memory connections: What biblical echoes do you hear?

Target: 300-400 words, 7-9 complete sentences with contemplative depth.

**Section 3 - Third Reading: Receiving (7-9 sentences, 300-300 words):**
- Read once more: Slowly, receptively, expectantly
- Personal message: Listen for God's personal word to you today
- Heart-level hearing: What is God saying to YOUR heart right now?
- Hidden invitation: What invitation is wrapped in these words?
- Allow reversal: Let the text read you (expose, convict, comfort, challenge)
- One word/phrase: What single word or phrase is God's gift to you?
- Gratitude: Thank God for speaking through His word
- [OPTIONAL] Write it down: Journal the word or phrase God gave you
- [OPTIONAL] Commitment: How will you carry this word with you today?

Target: 300-300 words, 7-9 complete sentences with spiritual receptivity.

## MEDITATIO: Meditation (900-1100 words)

Guide deep reflection and personal encounter:

**Section 4 - Verse-by-Verse Meditation (7-9 sentences, 300-400 words):**
Break down the passage meditatively with contemplative questions:
- God-centered focus: For each verse, what does this reveal about God's nature, character, heart?
- Human condition: What does this reveal about humanity, our need, our brokenness, our hope?
- Personal mirror: What does this reveal about YOU personally (not others)? Be specific.
- Grace location: Where is the grace in this verse? Where is God's kindness?
- Challenge identification: Where is the challenge? What makes you uncomfortable?
- Cross-references: What other Scripture comes to mind? How do they connect?
- Theological depth: What doctrine or biblical theme does this touch?
- [OPTIONAL] Historical context: How does original setting illuminate meaning?
- [OPTIONAL] Literary beauty: What poetic or literary features enhance the message?

Target: 300-400 words, 7-9 complete sentences with meditative depth.

**Section 5 - Personal Encounter Prompts (7-9 sentences, 300-400 words):**
Guide the reader into personal application and self-examination:
- Life parallels: How is your life like this passage? Be honest with yourself.
- Memory stirring: What memories does this bring up (joy, pain, longing)?
- Emotional response: What hopes does this awaken? What fears does it touch?
- Experience reflection: Where have you experienced this truth in your own story?
- Resistance awareness: Where are you resisting this truth? What do you want to avoid?
- Desire awakening: What do you long for as you sit with this passage?
- Conviction and comfort: Where do you feel conviction? Where do you feel comfort?
- [OPTIONAL] Relationships: How does this affect how you see others?
- [OPTIONAL] Calling: Does this speak to your vocation or purpose?

Target: 300-400 words, 7-9 complete sentences with personal honesty.

**Section 6 - Holy Spirit Listening (7-9 sentences, 300-400 words):**
Guide into deeper spiritual listening and discernment:
- Silence invitation: Quiet your heart and simply listen to the Holy Spirit
- Spirit's highlighting: What is the Spirit emphasizing or repeating to you?
- Returning word: What word or phrase keeps coming back to you?
- Gentle nudge: What gentle prompting do you feel from the Lord?
- Emerging invitation: What invitation is God extending to you through this text?
- Discernment prayer: Ask God to clarify what He is saying
- Confirmation seeking: Does this align with Scripture, bring peace, and build up?
- [OPTIONAL] Journaling: Write down what you sense God is saying
- [OPTIONAL] Testing: How can you test this word in community or through time?

Target: 300-400 words, 7-9 complete sentences with spiritual attentiveness.

⚠️ MANDATORY PRE-OUTPUT VERIFICATION FOR PASS 1:

Before completing your response, COUNT and verify:
1. Does "summary" have 250-300 words (8-12 sentences)? [Count: ___]
2. Does "context" have 50-80 words (MINIMAL)? [Count: ___]
3. ⚠️ CRITICAL: Does "passage" contain ONLY the Scripture reference (NOT full verse text)? [Format correct: Yes/No]
4. Does "interpretationPart1" have EXACTLY 3 or 4 sections? [Count: ___]
5. Does EACH section have 7-9 sentences? [Count each: ___ ___ ___ ___]
6. Is "interpretationPart1" 1200-1500 words total? [Estimated count: ___]
7. Is the tone contemplative, gentle, and invitational (not rushed or prescriptive)? [Check: Yes/No]
8. Does each section guide into personal encounter with God? [Check: Yes/No]
9. Are all verse references in ${languageConfig.name}? [Check: Yes/No]
10. Is total Pass 1 output ~1,600 words? [Estimated: ___]

IF ANY ANSWER IS "NO" OR OUTSIDE RANGE - YOU MUST FIX IT BEFORE OUTPUT.
⚠️ DO NOT SKIP THE PASSAGE FIELD - IT IS MANDATORY!

⚠️ CRITICAL: DO NOT OUTPUT LITERAL "..." - THESE ARE PLACEHOLDERS!
You must generate FULL CONTENT for each field as specified above.

OUTPUT ONLY THIS JSON - NO OTHER TEXT:
{
  "summary": "[YOUR SUMMARY HERE - as specified above]",
  "context": "[YOUR CONTEXT HERE - as specified above]",
  "passage": "[Scripture reference ONLY - e.g., 'Psalm 23:1-6' in ${languageConfig.name}]",
  "interpretationPart1": "[YOUR INTERPRETATION PART 1 HERE - as specified above]"
}`

  return { systemMessage, userMessage }
}

/**
 * Creates the second pass prompt: Oratio + Contemplatio + Supporting Fields
 */
export function createLectioPass2Prompt(
  params: LLMGenerationParams,
  languageConfig: LanguageConfig,
  pass1Result: { summary: string; context: string; interpretationPart1: string }
): PromptPair {
  const { language } = params

  const systemMessage = `You are a spiritual director completing a Lectio Divina guide.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, language)}

STUDY MODE: LECTIO DIVINA - PASS 2/2 (Prayer + Contemplation)
This is part 2 of a 2-part Lectio Divina generation. Focus on prayer and rest in God.
Target output: ~500 words for this pass.
Continue the contemplative, invitational tone.`

  const userMessage = `═══════════════════════════════════════════════════════════════════════════
PASS 2: LECTIO DIVINA RESPONSE (Prayer + Contemplation + Resources)
═══════════════════════════════════════════════════════════════════════════

CONTEXT FROM PASS 1:
- Contemplative Summary: ${pass1Result.summary.substring(0, 200)}...
- You already wrote: Sacred Reading (Lectio) and Meditation (Meditatio) in Pass 1

NOW COMPLETE THE LECTIO DIVINA with Prayer (Oratio), Contemplation (Contemplatio), and resources.

Generate this JSON structure (IMPORTANT: interpretationPart2 MUST be FIRST for optimal streaming):

{
  "interpretationPart2": "[400-500 words: ORATIO (Prayer Response) + CONTEMPLATIO (Contemplative Rest) with prayer guidance, surrender prompts, silence practices, and abiding in God]",
  "relatedVerses": [5-7 Bible verse REFERENCES ONLY in ${languageConfig.name} for meditation (e.g., 'Psalm 131:2', 'Matthew 11:28-30') - NO verse text],
  "reflectionQuestions": [5-7 gentle reflection questions for continued prayer],
  "prayerPoints": [4-5 prayer themes for ongoing contemplation - each 50-70 words],
  "summaryInsights": [4-5 spiritual truths - 15-20 words each],
  "interpretationInsights": [4-5 God-revelations - 15-20 words each],
  "reflectionAnswers": [4-5 life responses - 15-20 words each],
  "contextQuestion": "[Yes/no question connecting spiritual tradition to personal life]",
  "summaryQuestion": "[Question about the spiritual message - 12-18 words]",
  "relatedVersesQuestion": "[Question encouraging contemplative scripture reading - 12-18 words]",
  "reflectionQuestion": "[Question inviting personal reflection - 12-18 words]",
  "prayerQuestion": "[Invitation to continued prayer - 10-15 words]"
}

**INTERPRETATION PART 2 - ORATIO & CONTEMPLATIO (200-300 words):**

This section MUST contain EXACTLY 1 contemplative section of flowing prayerful prose.
This section MUST have 7-9 sentences with GENTLE, INVITATIONAL prayer guidance.

⚠️ PRAYER DEPTH REQUIREMENTS (MANDATORY):
- MAINTAIN contemplative, prayerful tone (intimate conversation with God)
- INVITE authentic, vulnerable dialogue with God (not scripted or formal)
- GUIDE into silence, rest, and abiding in God's presence
- EMPHASIZE receptivity, surrender, and spiritual intimacy
- BALANCE structure with spontaneous, Spirit-led prayer

⚠️ SENTENCE COUNTING IS MANDATORY:
- A sentence ends with: period (.) OR question mark (?) OR exclamation point (!)
- Count each sentence as you write: "1. [sentence]. 2. [sentence]... 7. [sentence]."
- If you reach 6 sentences, ADD 1-3 MORE SENTENCES to reach 7-9
- Each section should be 300-450 words of prayerful contemplative guidance

## ORATIO: Prayer Response (500-650 words)

Guide prayerful response to God with authenticity and vulnerability:

**Section 1 - Conversational Prayer (7-9 sentences, 250-300 words):**
- Invitation to dialogue: Now speak to God about what you've heard in His word
- Honest response: Share your authentic reaction (gratitude, confession, questions, resistance, joy)
- Friend-to-friend conversation: Talk to God like your closest friend, with complete honesty
- No editing: Don't sanitize your prayers or make them sound religious - be real
- Example prayers: Model prayers the reader might pray based on the passage
- Multiple prayer forms: Include thanksgiving, confession, lament, petition, praise
- Personal specificity: Pray about your actual life, not abstract concepts
- [OPTIONAL] Body engagement: How physical posture can support prayer (kneeling, open hands, etc.)
- [OPTIONAL] Emotional honesty: Welcoming all emotions in prayer (anger, doubt, joy, fear)

Target: 250-300 words, 7-9 complete sentences with prayerful intimacy.

**Section 2 - Intercessory & Surrender Prayer (7-9 sentences, 250-350 words):**
- Intercessory invitation: Who comes to mind as you pray this passage? Bring them before God.
- Others' needs: Pray for family, friends, neighbors, enemies in light of this truth
- World's brokenness: Bring the world's needs before God (injustice, suffering, lostness)
- Church intercession: Pray for your local church, pastors, global body of Christ
- Surrender question: What is God asking you to surrender based on this passage?
- Change needed: What needs to transform in your life for this truth to take root?
- Death and life: What old patterns need to die? What new life is God offering?
- Prayer of yielding: Model a prayer of complete surrender and trust in God
- [OPTIONAL] Fasting: When fasting might support this surrender

Target: 250-350 words, 7-9 complete sentences with intercessory and surrendering depth.

## CONTEMPLATIO: Contemplative Rest (500-650 words)

Guide silent abiding in God's presence with practical contemplative practices:

**Section 3 - Silence, Abiding, and Carrying (7-9 sentences, 500-650 words):**
- Silence invitation: Move now into 5-10 minutes of complete silence before God
- Resting posture: Simply rest in God's presence without words, thoughts, or analysis
- Non-doing: Practice being with God, not doing anything for God
- Distraction guidance: When your mind wanders (and it will), gently return to God
- One word practice: Choose one word from the passage and hold it gently in your heart
- Word as anchor: Return to this word when your mind drifts; let it pray in you
- Loving attentiveness: Remain in simple, loving awareness of God's presence
- Carrying forward: How will you carry this word through your day, week, month?
- Contemplative living: Practice returning to God's presence every hour (set phone reminders, breathe prayers, pause practices)

Target: 500-650 words, 7-9 complete sentences with contemplative rest and integration.

**SUPPORTING MATERIALS:**
- relatedVerses: 5-7 additional contemplative verses in ${languageConfig.name}
- reflectionQuestions: 5-7 gentle questions (not analytical, but prayerful)
- prayerPoints: 4-5 prayer themes (50-70 words each)
- summaryInsights: 4-5 spiritual truths (15-20 words each)
- interpretationInsights: 4-5 God-revelations (15-20 words each)
- reflectionAnswers: 4-5 life responses (15-20 words each)
- 5 yes/no questions for continued contemplation

⚠️ MANDATORY PRE-OUTPUT VERIFICATION FOR PASS 2:

Before completing your response, COUNT and verify:
1. Does "interpretationPart2" have EXACTLY 3 sections? [Count: ___]
2. Does EACH section have 7-9 sentences? [Count each: ___ ___ ___]
3. Is "interpretationPart2" 1000-1300 words total? [Estimated count: ___]
4. Does "relatedVerses" contain 5-7 contemplative verses? [Count: ___]
5. Are all verses in ${languageConfig.name}? [Check: Yes/No]
6. Does "reflectionQuestions" contain 5-7 questions? [Count: ___]
7. Are questions gentle and prayerful (not analytical)? [Check: Yes/No]
8. Does "prayerPoints" contain 4-5 prayer themes? [Count: ___]
9. Is each prayer point 50-70 words? [Check: Yes/No]
10. Are "summaryInsights" 4-5 items at 15-20 words each? [Count: ___]
11. Are "interpretationInsights" 4-5 items at 15-20 words each? [Count: ___]
12. Are "reflectionAnswers" 4-5 items at 15-20 words each? [Count: ___]
13. Are all 5 yes/no questions present? [Check: Yes/No]
14. Is the tone contemplative, gentle, and invitational? [Check: Yes/No]
15. Is total Pass 2 output ~1,500 words? [Estimated: ___]

IF ANY ANSWER IS "NO" OR OUTSIDE RANGE - YOU MUST FIX IT BEFORE OUTPUT.

⚠️ CRITICAL: DO NOT OUTPUT LITERAL "..." or [...] - THESE ARE PLACEHOLDERS!
You must generate FULL CONTENT for each field as specified above.

OUTPUT ONLY THIS JSON - NO OTHER TEXT:
{
  "interpretationPart2": "[YOUR INTERPRETATION PART 2 HERE - as specified above]",
  "relatedVerses": ["[VERSE 1]", "[VERSE 2]", "[VERSE 3]", "[VERSE 4]", "[VERSE 5]"],
  "reflectionQuestions": ["[QUESTION 1]", "[QUESTION 2]", "[QUESTION 3]", "[QUESTION 4]", "[QUESTION 5]"],
  "prayerPoints": ["[PRAYER 1: 50-70 words]", "[PRAYER 2]", "[PRAYER 3]", "[PRAYER 4]"],
  "summaryInsights": ["[INSIGHT 1: 15-20 words]", "[INSIGHT 2]", "[INSIGHT 3]", "[INSIGHT 4]"],
  "interpretationInsights": ["[TRUTH 1: 15-20 words]", "[TRUTH 2]", "[TRUTH 3]", "[TRUTH 4]"],
  "reflectionAnswers": ["[APPLICATION 1: 15-20 words]", "[APPLICATION 2]", "[APPLICATION 3]", "[APPLICATION 4]"],
  "contextQuestion": "[YOUR YES/NO QUESTION]",
  "summaryQuestion": "[YOUR QUESTION]",
  "relatedVersesQuestion": "[YOUR QUESTION]",
  "reflectionQuestion": "[YOUR QUESTION]",
  "prayerQuestion": "[YOUR QUESTION]"
}`

  return { systemMessage, userMessage }
}

/**
 * Combines results from both passes into complete Lectio Divina structure
 */
export function combineLectioPasses(
  pass1: { summary: string; context: string; passage: string; interpretationPart1: string },
  pass2: {
    interpretationPart2: string
    relatedVerses: string[]
    reflectionQuestions: string[]
    prayerPoints: string[]
    summaryInsights: string[]
    interpretationInsights: string[]
    reflectionAnswers: string[]
    contextQuestion: string
    summaryQuestion: string
    relatedVersesQuestion: string
    reflectionQuestion: string
    prayerQuestion: string
  }
): Record<string, unknown> {
  return {
    summary: pass1.summary,
    interpretation: `${pass1.interpretationPart1}\n\n${pass2.interpretationPart2}`,
    context: pass1.context,
    passage: pass1.passage,
    relatedVerses: pass2.relatedVerses,
    reflectionQuestions: pass2.reflectionQuestions,
    prayerPoints: pass2.prayerPoints,
    summaryInsights: pass2.summaryInsights,
    interpretationInsights: pass2.interpretationInsights,
    reflectionAnswers: pass2.reflectionAnswers,
    contextQuestion: pass2.contextQuestion,
    summaryQuestion: pass2.summaryQuestion,
    relatedVersesQuestion: pass2.relatedVersesQuestion,
    reflectionQuestion: pass2.reflectionQuestion,
    prayerQuestion: pass2.prayerQuestion
  }
}
