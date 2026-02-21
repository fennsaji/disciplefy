/**
 * Multi-Pass Deep Dive Generation - WORD STUDY FOCUS
 *
 * Breaks word study generation into 2 passes to work within model token limits:
 * - Pass 1: Summary + Context + Interpretation Part 1 (Key Word Analysis)
 * - Pass 2: Interpretation Part 2 (Synthesis + Application) + Supporting Fields
 *
 * Total target: 1,800-2,100 words (15 minutes @ 120-140 wpm)
 * Emphasis: Greek/Hebrew word studies + theological precision + doctrinal depth
 * This allows Hindi/Malayalam deep studies to achieve better word counts
 * despite token inefficiency (Hindi: 0.28 words/token, Malayalam: 0.09 words/token)
 */

import { type LLMGenerationParams, type LanguageConfig, type PromptPair } from '../llm-types.ts'
import {
  THEOLOGICAL_FOUNDATION,
  JSON_OUTPUT_RULES,
  createLanguageBlock,
  createVerseReferenceBlock,
  getWordCountTarget
} from './prompt-builder.ts'

export type DeepPass = 'pass1' | 'pass2'

export interface DeepPassResult {
  pass: DeepPass
  content: string
}

/**
 * Creates the first pass prompt: Summary + Context + Interpretation Part 1
 */
export function createDeepPass1Prompt(
  params: LLMGenerationParams,
  languageConfig: LanguageConfig
): PromptPair {
  const { inputType, inputValue, topicDescription, language } = params
  const wordTarget = getWordCountTarget(languageConfig, 'deep')

  const taskDescription = inputType === 'scripture'
    ? `Create a WORD STUDY for: \"${inputValue}\"`
    : inputType === 'topic'
    ? `Create a WORD STUDY on: \"${inputValue}\"${topicDescription ? `\n\nContext: ${topicDescription}` : ''}`
    : `Create a WORD STUDY addressing: \"${inputValue}\"`

  const systemMessage = `You are a Bible scholar creating WORD STUDIES with theological depth.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, language)}

STUDY MODE: WORD STUDY - PASS 1/2 (Key Word Analysis)
This is part 1 of a 2-part WORD STUDY generation (12 minutes total).
Focus: Greek/Hebrew word analysis + semantic ranges + theological significance.
Target output: ~800-900 words for this pass.
Tone: Scholarly precision, exegetically rich, doctrinally sound.`

  const userMessage = `${taskDescription}

${createVerseReferenceBlock(language)}

═══════════════════════════════════════════════════════════════════════════
PASS 1: DEEP STUDY FOUNDATION (Summary + Context + Analysis)
═══════════════════════════════════════════════════════════════════════════

Generate the following JSON structure with THESE SPECIFIC FIELDS ONLY:

{
  "summary": "[130-160 words: Study title, central theme, key questions, theological significance, study objectives]",
  "context": "[50-70 words: MINIMAL - essential theological and biblical framing]",
  "passage": "⚠️ MANDATORY - Scripture reference for deep study. PREFER LONGER passages with rich theological content (e.g., 'Romans 8:1-39', 'John 14:1-27', 'Ephesians 2:1-10'). Format: Just the reference in ${languageConfig.name}, no verse text. DO NOT skip this field.",
  "interpretationPart1": "[700-900 words: EXEGETICAL ANALYSIS with textual analysis, original language insights, theological interpretation, doctrinal implications]"
}

CRITICAL INSTRUCTIONS FOR PASS 1:

**SUMMARY (130-160 words):**

Write a COMPREHENSIVE scholarly overview as CONTINUOUS NARRATIVE PROSE (NOT separate bullets).
This must be 6-8 complete sentences flowing together as a single paragraph.

Include these elements in flowing prose:
1. Begin with a compelling 4-6 word study title as the opening phrase
2. Central Theme: 2 sentences explaining the core theological message
3. Key Questions: 1-2 sentences identifying the main questions this study answers
4. Theological Significance: 1-2 sentences explaining why this passage matters doctrinally

Structure (NOT literal text - write entirely in ${languageConfig.name}):
- Sentence 1: [Study title] + [introduces central theological theme]
- Sentences 2-4: [Explains the core theological message in depth]
- Sentences 5-6: [Identifies key questions and theological significance]
- Sentences 7-8: [Describes what learners will gain from this study]

CRITICAL:
- Write ENTIRELY in ${languageConfig.name} - NO English words mixed in
- Write as a SINGLE FLOWING PARAGRAPH of 6-8 sentences
- NOT as separate bullet points or title only

**CONTEXT (50-70 words):**
Write MINIMAL essential theological and biblical framing (1 concise paragraph covering):
• Historical background (authorship, date, original audience)
• Literary genre and theological framework
• Key doctrinal significance in redemptive history
Keep it SHORT and FOCUSED - only what's necessary to understand the deep study.

**INTERPRETATION PART 1 (700-900 words):**

This section MUST contain EXACTLY 3 paragraphs of continuous scholarly prose.
EACH paragraph MUST have 6-8 sentences (depth without repetition).

⚠️ SCHOLARLY DEPTH REQUIREMENTS (MANDATORY):
- INCLUDE original language insights (Hebrew/Greek words, grammar, syntax)
- ANALYZE textual variants and manuscript evidence where significant
- REFERENCE church fathers, historical theologians, and biblical scholars
- CONNECT to systematic theology and biblical theology frameworks
- PROVIDE cross-references with exegetical analysis
- DEMONSTRATE mastery of grammatical-historical hermeneutical method

⚠️ SENTENCE COUNTING IS MANDATORY:
- A sentence ends with: period (.) OR question mark (?) OR exclamation point (!)
- Count each sentence as you write: "1. [sentence]. 2. [sentence]... 7. [sentence]."
- If you reach 5 sentences, ADD 1-3 MORE SENTENCES to reach 6-8
- Each paragraph should be 200-280 words of dense scholarly content

## Paragraph 1 (6-8 sentences): Verse-by-Verse Exegesis

Break down the key verses with scholarly rigor:
- Original language analysis: Hebrew/Greek words, grammar, syntax, verbal forms
- Lexical range: Word meanings in various contexts, semantic domains
- Literary devices: Metaphor, parallelism, chiasm, wordplay
- Cross-references: Related passages with exegetical connections
- Historical-cultural background: ANE context, Greco-Roman world

Target: 200-280 words, 6-8 complete sentences with scholarly precision.

## Paragraph 2 (6-8 sentences): Theological Interpretation

Explore the core theological dimensions:
- Doctrine of God: What this reveals about God's nature, character, attributes
- Christology: How this passage points to or relates to Christ
- Soteriology: Implications for salvation, grace, faith, justification
- Historical theological perspectives (Augustine, Calvin, Wesley, etc.)

Target: 200-280 words, 6-8 complete sentences with theological depth.

## Paragraph 3 (6-8 sentences): Doctrinal Implications

Analyze how this shapes Christian belief:
- Orthodox biblical interpretation of this passage
- Historical creeds and confessions relevant to this text
- Integration with broader systematic and biblical theology
- Pastoral and apologetic value of this passage

Target: 200-280 words, 6-8 complete sentences with doctrinal precision.

⚠️ MANDATORY PRE-OUTPUT VERIFICATION FOR PASS 1:

Before completing your response, COUNT and verify:
1. Does "summary" have 130-160 words (6-8 sentences)? [Count: ___]
2. Does "context" have 50-70 words (MINIMAL)? [Count: ___]
3. ⚠️ CRITICAL: Does "passage" contain ONLY the Scripture reference (NOT full verse text)? [Format correct: Yes/No]
4. Does "interpretationPart1" have EXACTLY 3 paragraphs? [Count: ___]
5. Does EACH paragraph have 6-8 sentences? [Count each: ___ ___ ___]
6. Is "interpretationPart1" 700-900 words total? [Estimated count: ___]
7. Did you include original language insights (Hebrew/Greek)? [Check: Yes/No]
8. Are all verse references in ${languageConfig.name}? [Check: Yes/No]
9. Is total Pass 1 output ~800-900 words? [Estimated: ___]

IF ANY ANSWER IS "NO" OR OUTSIDE RANGE - YOU MUST FIX IT BEFORE OUTPUT.
⚠️ DO NOT SKIP THE PASSAGE FIELD - IT IS MANDATORY!

You must generate FULL CONTENT for each field as specified above.

OUTPUT ONLY THIS JSON - NO OTHER TEXT:
{
  "summary": "[YOUR 130-160 WORD SUMMARY HERE - as specified above]",
  "context": "[YOUR 50-70 WORD CONTEXT HERE - as specified above]",
  "passage": "[Scripture reference ONLY - e.g., 'Romans 8:1-39' in ${languageConfig.name}]",
  "interpretationPart1": "[YOUR 700-900 WORD INTERPRETATION PART 1 HERE - 3 paragraphs]"
}`

  return { systemMessage, userMessage }
}

/**
 * Creates the second pass prompt: Interpretation Part 2 + Supporting Fields
 */
export function createDeepPass2Prompt(
  params: LLMGenerationParams,
  languageConfig: LanguageConfig,
  pass1Result: { summary: string; context: string; interpretationPart1: string }
): PromptPair {
  const { language } = params

  const systemMessage = `You are a Bible scholar and teacher completing an in-depth study guide.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, language)}

STUDY MODE: DEEP STUDY - PASS 2/2 (Application + Resources)
This is part 2 of a 2-part deep study generation. Focus on practical transformation.
Target output: ~700 words for this pass.
Continue the scholarly tone with practical application.`

  const userMessage = `═══════════════════════════════════════════════════════════════════════════
PASS 2: DEEP STUDY APPLICATION (Practical Transformation + Resources)
═══════════════════════════════════════════════════════════════════════════

CONTEXT FROM PASS 1:
- Study Summary: ${pass1Result.summary.substring(0, 200)}...
- You already wrote: Comprehensive exegetical analysis in Pass 1

NOW COMPLETE THE STUDY with practical application and supporting resources.

Generate this JSON structure (IMPORTANT: interpretationPart2 MUST be FIRST for optimal streaming):

{
  "interpretationPart2": "[550-700 words: PRACTICAL APPLICATION with life transformation, contemporary relevance, and action steps]",
  "relatedVerses": [7-10 Bible verse REFERENCES ONLY in ${languageConfig.name} for further study (e.g., 'Colossians 1:15-20', 'Hebrews 1:1-4') - NO verse text],
  "reflectionQuestions": [8-12 deep reflection questions mixing theology and application],
  "prayerPoints": [5-7 prayer points based on the study - each 40-60 words],
  "summaryInsights": [5-7 key takeaways - 15-20 words each],
  "interpretationInsights": [5-7 theological truths taught - 15-20 words each],
  "reflectionAnswers": [5-7 life applications - 15-20 words each],
  "contextQuestion": "[Yes/no question connecting biblical context to modern life]",
  "summaryQuestion": "[Question about study theme - 12-18 words]",
  "relatedVersesQuestion": "[Question encouraging scripture study - 12-18 words]",
  "reflectionQuestion": "[Application question for reflection - 12-18 words]",
  "prayerQuestion": "[Invitation question encouraging commitment - 10-15 words]"
}

**INTERPRETATION PART 2 - PRACTICAL APPLICATION (550-700 words):**

This section MUST contain EXACTLY 2 paragraphs of continuous transformative prose.
EACH paragraph MUST have 6-8 sentences with DEEP PRACTICAL APPLICATION.

⚠️ PRACTICAL DEPTH REQUIREMENTS (MANDATORY):
- MAINTAIN scholarly tone while being practically transformative
- BRIDGE theological insights from Pass 1 to actionable life change
- ADDRESS real struggles, challenges, and growth opportunities

⚠️ SENTENCE COUNTING IS MANDATORY:
- A sentence ends with: period (.) OR question mark (?) OR exclamation point (!)
- Count each sentence as you write: "1. [sentence]. 2. [sentence]... 7. [sentence]."
- If you reach 5 sentences, ADD 1-3 MORE SENTENCES to reach 6-8
- Each paragraph should be 250-320 words of transformative content

## Paragraph 1 (6-8 sentences): Life Transformation

Transform theological truth into life change:
- Mindset Shifts: Specific thought patterns that must change based on exegesis
- Heart Transformation: Attitudes, affections, desires that need renewal
- Identity in Christ: How this truth reshapes self-understanding
- Behavioral Changes: Specific actions that demonstrate obedience
- Relational Impact: How this affects marriage, family, friendships

Target: 250-320 words, 6-8 complete sentences with transformative depth.

## Paragraph 2 (6-8 sentences): Contemporary Relevance & Action Steps

Apply to modern contexts with concrete steps:
- Cultural Challenges: Specific contemporary issues this addresses
- This Week: 2-3 SPECIFIC actions for the next 7 days (be precise, not general)
- Spiritual Practices: Recommended disciplines for deepening this truth
- Crisis Application: How this helps in suffering, loss, doubt, failure

Target: 250-320 words, 6-8 complete sentences with contemporary insight and actionable steps.

**SUPPORTING MATERIALS:**
- relatedVerses: 7-10 additional verses in ${languageConfig.name}
- reflectionQuestions: 8-12 deep questions (theological + practical)
- prayerPoints: 5-7 prayer points (40-60 words each)
- summaryInsights: 5-7 takeaways (15-20 words each)
- interpretationInsights: 5-7 theological truths (15-20 words each)
- reflectionAnswers: 5-7 applications (15-20 words each)
- 5 yes/no questions for engagement

⚠️ MANDATORY PRE-OUTPUT VERIFICATION FOR PASS 2:

Before completing your response, COUNT and verify:
1. Does "interpretationPart2" have EXACTLY 2 paragraphs? [Count: ___]
2. Does EACH paragraph have 6-8 sentences? [Count each: ___ ___]
3. Is "interpretationPart2" 550-700 words total? [Estimated count: ___]
4. Does "relatedVerses" contain 7-10 verses? [Count: ___]
5. Are all verses in ${languageConfig.name}? [Check: Yes/No]
6. Does "reflectionQuestions" contain 8-12 questions? [Count: ___]
7. Does "prayerPoints" contain 5-7 prayer points? [Count: ___]
8. Is each prayer point 40-60 words? [Check: Yes/No]
9. Are "summaryInsights" 5-7 items at 15-20 words each? [Count: ___]
10. Are "interpretationInsights" 5-7 items at 15-20 words each? [Count: ___]
11. Are "reflectionAnswers" 5-7 items at 15-20 words each? [Count: ___]
12. Are all 5 yes/no questions present? [Check: Yes/No]
13. Is total Pass 2 output ~700 words? [Estimated: ___]

IF ANY ANSWER IS "NO" OR OUTSIDE RANGE - YOU MUST FIX IT BEFORE OUTPUT.

⚠️ CRITICAL: DO NOT OUTPUT LITERAL "..." or [...] - THESE ARE PLACEHOLDERS!
You must generate FULL CONTENT for each field as specified above.

OUTPUT ONLY THIS JSON - NO OTHER TEXT:
{
  "interpretationPart2": "[YOUR INTERPRETATION PART 2 HERE - as specified above]",
  "relatedVerses": ["[VERSE 1]", "[VERSE 2]", "[VERSE 3]", "[VERSE 4]", "[VERSE 5]", "[VERSE 6]", "[VERSE 7]"],
  "reflectionQuestions": ["[QUESTION 1]", "[QUESTION 2]", "[QUESTION 3]", "[QUESTION 4]", "[QUESTION 5]", "[QUESTION 6]", "[QUESTION 7]", "[QUESTION 8]"],
  "prayerPoints": ["[PRAYER 1: 40-60 words]", "[PRAYER 2]", "[PRAYER 3]", "[PRAYER 4]", "[PRAYER 5]"],
  "summaryInsights": ["[INSIGHT 1: 15-20 words]", "[INSIGHT 2]", "[INSIGHT 3]", "[INSIGHT 4]", "[INSIGHT 5]"],
  "interpretationInsights": ["[TRUTH 1: 15-20 words]", "[TRUTH 2]", "[TRUTH 3]", "[TRUTH 4]", "[TRUTH 5]"],
  "reflectionAnswers": ["[APPLICATION 1: 15-20 words]", "[APPLICATION 2]", "[APPLICATION 3]", "[APPLICATION 4]", "[APPLICATION 5]"],
  "contextQuestion": "[YOUR YES/NO QUESTION]",
  "summaryQuestion": "[YOUR QUESTION]",
  "relatedVersesQuestion": "[YOUR QUESTION]",
  "reflectionQuestion": "[YOUR QUESTION]",
  "prayerQuestion": "[YOUR QUESTION]"
}`

  return { systemMessage, userMessage }
}

/**
 * Combines results from both passes into complete deep study structure
 */
export function combineDeepPasses(
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
