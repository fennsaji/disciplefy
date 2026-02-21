/**
 * Multi-Pass Standard Study Generation
 *
 * Breaks standard study generation into 2 passes to work within model token limits:
 * - Pass 1: Summary + Context + Interpretation Part 1 (Main Teaching)
 * - Pass 2: Interpretation Part 2 (Application) + Supporting Fields
 *
 * This primarily helps Malayalam standard studies achieve better word counts
 * (Malayalam: 0.09 words/token - currently only reaching ~1500 words vs 2000-2500 target)
 * Hindi standard studies already meet targets with single-pass generation.
 */

import { type LLMGenerationParams, type LanguageConfig, type PromptPair } from '../llm-types.ts'
import {
  THEOLOGICAL_FOUNDATION,
  JSON_OUTPUT_RULES,
  createLanguageBlock,
  createVerseReferenceBlock,
  getWordCountTarget
} from './prompt-builder.ts'

export type StandardPass = 'pass1' | 'pass2'

export interface StandardPassResult {
  pass: StandardPass
  content: string
}

/**
 * Creates the first pass prompt: Summary + Context + Interpretation Part 1
 */
export function createStandardPass1Prompt(
  params: LLMGenerationParams,
  languageConfig: LanguageConfig
): PromptPair {
  const { inputType, inputValue, topicDescription, language } = params
  const wordTarget = getWordCountTarget(languageConfig, 'standard')

  const taskDescription = inputType === 'scripture'
    ? `Create a STANDARD STUDY for: \"${inputValue}\"`
    : inputType === 'topic'
    ? `Create a STANDARD STUDY on: \"${inputValue}\"${topicDescription ? `\n\nContext: ${topicDescription}` : ''}`
    : `Create a STANDARD STUDY addressing: \"${inputValue}\"`

  const systemMessage = `You are a Bible teacher creating balanced, accessible study guides.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, language)}

STUDY MODE: STANDARD STUDY - PASS 1/2 (Foundation + Teaching)
This is part 1 of a multi-pass standard study generation. Focus on solid teaching.
Target output: ~700 words for this pass.
Tone: Clear, accessible, biblically grounded, practical.`

  const userMessage = `${taskDescription}

${createVerseReferenceBlock(language)}

═══════════════════════════════════════════════════════════════════════════
PASS 1: STANDARD STUDY FOUNDATION (Summary + Context + Teaching)
═══════════════════════════════════════════════════════════════════════════

Generate the following JSON structure with THESE SPECIFIC FIELDS ONLY:

{
  "summary": "[80-100 words: Study title, key message, main takeaways, practical focus]",
  "context": "[40-60 words: MINIMAL - necessary biblical background only]",
  "passage": "⚠️ MANDATORY - Scripture reference for meditation. PREFER LONGER PASSAGES (10-20+ verses) that provide substantial content (e.g., 'Romans 8:1-39', 'Psalm 119:1-24'). Format: Just the reference in ${languageConfig.name}, no verse text. DO NOT skip this field.",
  "interpretationPart1": "[500-650 words: MAIN TEACHING with verse explanation, key principles, theological insights, biblical connections]"
}

CRITICAL INSTRUCTIONS FOR PASS 1:

**SUMMARY (80-100 words):**

Write a CLEAR and ACCESSIBLE overview as CONTINUOUS NARRATIVE PROSE (NOT separate bullets).
This must be 5-6 complete sentences flowing together as a single paragraph.

Include these elements in flowing prose:
1. Begin with a clear 4-6 word study title as the opening phrase
2. Key Message: 2-3 sentences explaining the core biblical truth
3. Main Takeaways: 2-3 sentences highlighting what readers will learn
4. Practical Focus: 1-2 sentences showing how this applies to daily life

Structure (NOT literal text - write entirely in ${languageConfig.name}):
- Sentence 1: [Study title] + [introduces key message]
- Sentences 2-3: [Explains the core biblical truth this study teaches]
- Sentences 4-5: [Highlights main takeaways and practical application]

CRITICAL:
- Write ENTIRELY in ${languageConfig.name} - NO English words mixed in
- Write as a SINGLE FLOWING PARAGRAPH of 5-6 sentences
- NOT as separate bullet points or title only

**CONTEXT (40-60 words):**
Write MINIMAL necessary biblical background only (1 concise paragraph covering):
• Historical context: Authorship, date, original audience
• Literary setting and theological framework
Keep it SHORT and FOCUSED - only what's essential to understand the study.

**INTERPRETATION PART 1 - MAIN TEACHING (500-650 words):**

This section MUST contain EXACTLY 2 paragraphs of continuous narrative prose.
EACH paragraph MUST have 6-8 sentences.

⚠️ SENTENCE COUNTING IS MANDATORY:
- A sentence ends with: period (.) OR question mark (?) OR exclamation point (!)
- Count each sentence as you write: "1. [sentence]. 2. [sentence]... 6. [sentence]."
- If you reach 5 sentences, ADD 1-3 MORE SENTENCES to reach 6-8
- Each paragraph should be 200-280 words of flowing prose

## Paragraph 1 (6-8 sentences): Verse Explanation

Break down the passage clearly with depth:
- What does this passage say? (Observation)
- What does it mean in original context? (Interpretation)
- Why does it matter theologically? (Significance)
- Key words and phrases explained with precision
- Structure and flow of thought analyzed
- Cross-references to related passages
- Textual context and literary features
- [OPTIONAL] Original language insights if relevant
- [OPTIONAL] Historical background connection

Target: 200-280 words, 6-8 complete sentences with rich content.

## Paragraph 2 (6-8 sentences): Key Principles & Theological Insights

Extract 2-3 timeless principles and connect to broader biblical teaching:
- What universal truths does this teach?
- What does this reveal about God's character?
- How does this point to the gospel and Christ?
- How do these principles apply across cultures and time?
- What theological doctrines are supported here?
- Christological connections (how it points to Christ)

Target: 200-280 words, 6-8 complete sentences with biblical support.

⚠️ MANDATORY PRE-OUTPUT VERIFICATION FOR PASS 1:

Before completing your response, COUNT and verify:
1. Does "summary" have 80-100 words (5-6 sentences)? [Count: ___]
2. Does "context" have 40-60 words (MINIMAL)? [Count: ___]
3. ⚠️ CRITICAL: Does "passage" contain ONLY the Scripture reference (NOT full verse text)? [Format correct: Yes/No]
4. Does "interpretationPart1" have EXACTLY 2 paragraphs? [Count: ___]
5. Does EACH paragraph in interpretationPart1 have 6-8 sentences? [Count each: ___ ___]
6. Is "interpretationPart1" 500-650 words total? [Estimated count: ___]
7. Are all verse references in ${languageConfig.name}? [Check: Yes/No]
8. Is total Pass 1 output ~700 words? [Estimated: ___]

IF ANY ANSWER IS "NO" OR OUTSIDE RANGE - YOU MUST FIX IT BEFORE OUTPUT.
⚠️ DO NOT SKIP THE PASSAGE FIELD - IT IS MANDATORY!

⚠️ CRITICAL: DO NOT OUTPUT LITERAL "..." - THESE ARE PLACEHOLDERS!
You must generate FULL CONTENT for each field as specified above.

OUTPUT ONLY THIS JSON - NO OTHER TEXT:
{
  "summary": "[YOUR 80-100 WORD SUMMARY HERE - as specified above]",
  "context": "[YOUR 40-60 WORD CONTEXT HERE - as specified above]",
  "passage": "[Scripture reference ONLY - e.g., 'Romans 8:1-39' in ${languageConfig.name}]",
  "interpretationPart1": "[YOUR 500-650 WORD INTERPRETATION PART 1 HERE - 2 paragraphs]"
}`

  return { systemMessage, userMessage }
}

/**
 * Creates the second pass prompt: Interpretation Part 2 + Supporting Fields
 */
export function createStandardPass2Prompt(
  params: LLMGenerationParams,
  languageConfig: LanguageConfig,
  pass1Result: { summary: string; context: string; interpretationPart1: string }
): PromptPair {
  const { language } = params

  const systemMessage = `You are a Bible teacher completing a balanced, accessible study guide.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, language)}

STUDY MODE: STANDARD STUDY - PASS 2/2 (Application + Resources)
This is part 2 of a 2-part standard study generation. Focus on practical life change.
Target output: ~500 words for this pass.
Continue the clear, practical, biblically grounded tone.`

  const userMessage = `═══════════════════════════════════════════════════════════════════════════
PASS 2: STANDARD STUDY APPLICATION (Life Application + Resources)
═══════════════════════════════════════════════════════════════════════════

CONTEXT FROM PASS 1:
- Study Summary: ${pass1Result.summary.substring(0, 200)}...
- You already wrote: Main teaching and key principles in Pass 1

NOW COMPLETE THE STUDY with practical application and supporting resources.

Generate this JSON structure (IMPORTANT: interpretationPart2 MUST be FIRST for optimal streaming):

{
  "interpretationPart2": "[350-450 words: PRACTICAL APPLICATION with life transformation and specific action steps]",
  "relatedVerses": [5-7 Bible verse REFERENCES ONLY in ${languageConfig.name} for further study (e.g., 'John 14:6', 'Romans 12:1-2') - NO verse text],
  "reflectionQuestions": [5-7 reflection questions mixing understanding and application],
  "prayerPoints": [3-5 prayer points based on the study - each 40-50 words],
  "summaryInsights": [4-5 key takeaways - 15-20 words each],
  "interpretationInsights": [4-5 biblical truths taught - 15-20 words each],
  "reflectionAnswers": [4-5 life applications - 15-20 words each],
  "contextQuestion": "[Yes/no question connecting biblical context to modern life]",
  "summaryQuestion": "[Question about the key message - 12-18 words]",
  "relatedVersesQuestion": "[Question encouraging scripture study - 12-18 words]",
  "reflectionQuestion": "[Application question for reflection - 12-18 words]",
  "prayerQuestion": "[Invitation question encouraging response - 10-15 words]"
}

**INTERPRETATION PART 2 - PRACTICAL APPLICATION (350-450 words):**

This section MUST contain EXACTLY 2 paragraphs of continuous narrative prose.
EACH paragraph MUST have 5-7 sentences with PRACTICAL, ACTION-ORIENTED content.

⚠️ PRACTICAL APPLICATION EMPHASIS:
- Focus on HOW to apply, not just WHAT to apply
- Include SPECIFIC examples from daily life (home, work, relationships)
- Provide CONCRETE action steps readers can take this week
- Address REAL struggles and challenges believers face
- Bridge from biblical truth to contemporary Christian living

## Paragraph 1 (5-7 sentences): Life Transformation

Show how this truth changes daily life with specificity:
- Personal Growth: How should this shape your character? Give examples.
- Relationships: How does this affect how you treat family, friends, coworkers?
- Mindset Shifts: What thought patterns need to change?
- Heart Transformation: What attitudes or desires need renewal?
- Behavioral Changes: What specific actions demonstrate obedience?

Target: 150-200 words, 5-7 complete sentences with practical depth.

## Paragraph 2 (5-7 sentences): Specific Action Steps

Provide CONCRETE steps for the next 7 days:
- This Week: 2-3 SPECIFIC actions to take (be precise, not general)
- With God: How to deepen your relationship with Him (prayer, Scripture)
- With Others: How to apply this in relationships
- In Challenges: How to use this when facing difficulties

Target: 150-200 words, 5-7 complete sentences that are actionable, not vague.

**SUPPORTING MATERIALS:**
- relatedVerses: 5-7 verse REFERENCES ONLY in ${languageConfig.name} (e.g., 'Galatians 5:22-23') - NO verse text
- reflectionQuestions: 5-7 questions (understanding + application)
- prayerPoints: 3-5 prayer points (40-50 words each)
- summaryInsights: 4-5 takeaways (15-20 words each)
- interpretationInsights: 4-5 biblical truths (15-20 words each)
- reflectionAnswers: 4-5 applications (15-20 words each)
- 5 yes/no questions for engagement

⚠️ MANDATORY PRE-OUTPUT VERIFICATION FOR PASS 2:

Before completing your response, COUNT and verify:
1. Does "interpretationPart2" have EXACTLY 2 paragraphs? [Count: ___]
2. Does EACH paragraph have 5-7 sentences? [Count each: ___ ___]
3. Is "interpretationPart2" 350-450 words total? [Estimated count: ___]
4. Does "prayerPoints" contain 3-5 prayer points? [Count: ___]
5. Is each prayer point 40-50 words? [Check: Yes/No]
6. Are "summaryInsights" 4-5 items at 15-20 words each? [Count: ___]
7. Are "interpretationInsights" 4-5 items at 15-20 words each? [Count: ___]
8. Are "reflectionAnswers" 4-5 items at 15-20 words each? [Count: ___]
9. Are all verse references in ${languageConfig.name}? [Check: Yes/No]
10. Is total Pass 2 output ~500 words? [Estimated: ___]

IF ANY ANSWER IS "NO" OR OUTSIDE RANGE - YOU MUST FIX IT BEFORE OUTPUT.

⚠️ CRITICAL: DO NOT OUTPUT LITERAL "..." or [...] - THESE ARE PLACEHOLDERS!
You must generate FULL CONTENT for each field as specified above.

OUTPUT ONLY THIS JSON - NO OTHER TEXT:
{
  "interpretationPart2": "[YOUR INTERPRETATION PART 2 HERE - as specified above]",
  "relatedVerses": ["[VERSE 1]", "[VERSE 2]", "[VERSE 3]", "[VERSE 4]", "[VERSE 5]"],
  "reflectionQuestions": ["[QUESTION 1]", "[QUESTION 2]", "[QUESTION 3]", "[QUESTION 4]", "[QUESTION 5]"],
  "prayerPoints": ["[PRAYER 1: 40-50 words]", "[PRAYER 2]", "[PRAYER 3]"],
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
 * Combines results from both passes into complete standard study structure
 */
export function combineStandardPasses(
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
