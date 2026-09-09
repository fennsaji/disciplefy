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

import { joinInterpretationParts } from './join-passes.ts'
import { type LLMGenerationParams, type LanguageConfig, type CacheablePromptPair } from '../llm-types.ts'
import {
  createSharedFoundation,
  createVerseReferenceBlock
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
): CacheablePromptPair {
  const { inputType, inputValue, topicDescription, pathTitle, pathDescription, discipleLevel, language } = params

  const pathParts = [
    pathTitle ? `Part of Learning Path: ${pathTitle}` : '',
    pathDescription ? `Learning Path Goal: ${pathDescription}` : '',
  ].filter(Boolean).join('\n')
  const pathContext = pathParts ? `\n\n${pathParts}` : ''
  const taskDescription = inputType === 'scripture'
    ? `Create a WORD STUDY for: \"${inputValue}\"`
    : `Create a WORD STUDY on: \"${inputValue}\"${topicDescription ? `\n\nContext: ${topicDescription}` : ''}${pathContext}`

  // Language-aware passage examples to prevent LLM from writing English references
  // when generating content in Hindi or Malayalam
  const passageExamples = language === 'hi'
    ? "'रोमियों 8:1-39', 'यूहन्ना 14:1-27', 'इफिसियों 2:1-10'"
    : language === 'ml'
    ? "'റോമർ 8:1-39', 'യോഹന്നാൻ 14:1-27', 'എഫേസ്യർ 2:1-10'"
    : "'Romans 8:1-39', 'John 14:1-27', 'Ephesians 2:1-10'"
  const passageOutputExample = language === 'hi'
    ? 'रोमियों 8:1-39'
    : language === 'ml'
    ? 'റോമർ 8:1-39'
    : 'Romans 8:1-39'

  const sharedSystem = createSharedFoundation(languageConfig, language, discipleLevel)

  const passSystem = `You are a Bible scholar creating WORD STUDIES with theological depth.

STUDY MODE: WORD STUDY - PASS 1/2 (Key Word Analysis)
This is part 1 of a 2-part WORD STUDY generation (12 minutes total).
Focus: Greek/Hebrew word analysis + semantic ranges + theological significance.
Target output: ~800-900 words for this pass.
Tone: Scholarly precision, exegetically rich, doctrinally sound.`

  const passInstructions = `${createVerseReferenceBlock(language)}

---
PASS 1: DEEP STUDY FOUNDATION (Summary + Context + Analysis)
---

Generate the following JSON structure with THESE SPECIFIC FIELDS ONLY:

{
  "summary": "[130-160 words: Study title, central theme, key questions, theological significance, study objectives]",
  "context": "[50-70 words: MINIMAL - essential theological and biblical framing]",
  "passage": "⚠️ MANDATORY - Scripture reference for deep study. PREFER LONGER passages with rich theological content (e.g., ${passageExamples}). If the input is a SINGLE VERSE, select the surrounding pericope (5–20 verses) to provide sufficient exegetical material. Format: Just the reference, no verse text. DO NOT skip this field.",
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
EACH paragraph MUST begin with a **Bold Section Title** followed by 6-8 sentences (depth without repetition).
Use **Bold Title** format (NOT ## markdown headers).

⚠️ SCHOLARLY DEPTH REQUIREMENTS (MANDATORY):
- INCLUDE original language insights (Hebrew/Greek words, grammar, syntax)
- ANALYZE textual variants and manuscript evidence where significant
- REFERENCE church fathers, historical theologians, and biblical scholars
- CONNECT to systematic theology and biblical theology frameworks
- PROVIDE cross-references with exegetical analysis
- DEMONSTRATE mastery of grammatical-historical hermeneutical method

Count sentences as you write (end with ./!/?). Each paragraph: 6-8 sentences, 235-300 words.

## Paragraph 1 (6-8 sentences): Verse-by-Verse Exegesis

Break down the key verses with scholarly rigor:
- Original language analysis: Hebrew/Greek words, grammar, syntax, verbal forms
- Lexical range: Word meanings in various contexts, semantic domains
- Literary devices: Metaphor, parallelism, chiasm, wordplay
- Cross-references: Related passages with exegetical connections
- Historical-cultural background: ANE context, Greco-Roman world

Target: 235-300 words, 6-8 complete sentences with scholarly precision.

## Paragraph 2 (6-8 sentences): Theological Interpretation

Explore the core theological dimensions:
- Doctrine of God: What this reveals about God's nature, character, attributes
- Christology: How this passage points to or relates to Christ
- Soteriology: Implications for salvation, grace, faith, justification
- Historical theological perspectives (Augustine, Calvin, Wesley, etc.)

Target: 235-300 words, 6-8 complete sentences with theological depth.

## Paragraph 3 (6-8 sentences): Doctrinal Implications

Analyze how this shapes Christian belief:
- Orthodox biblical interpretation of this passage
- Historical creeds and confessions relevant to this text
- Integration with broader systematic and biblical theology
- Pastoral and apologetic value of this passage

Target: 235-300 words, 6-8 complete sentences with doctrinal precision.

VERIFY: summary 130-160 words | context 50-70 words | passage reference ONLY (MANDATORY) | interpretationPart1: 3 paragraphs, 6-8 sentences each, 700-900 words | Includes Hebrew/Greek insights | Verse refs in ${languageConfig.name} | Total ~800-900 words. Generate FULL CONTENT - no placeholders. FIX any issues BEFORE output.


Return ONLY the JSON object described above.
`

  const userMessage = taskDescription

  return { sharedSystem, passSystem: `${passSystem}

${passInstructions}`, userMessage }
}

/**
 * Creates the second pass prompt: Interpretation Part 2 + Supporting Fields
 */
export function createDeepPass2Prompt(
  params: LLMGenerationParams,
  languageConfig: LanguageConfig,
  pass1Result: { summary: string; context: string; interpretationPart1: string }
): CacheablePromptPair {
  const { language, discipleLevel } = params

  const sharedSystem = createSharedFoundation(languageConfig, language, discipleLevel)

  const passSystem = `You are a Bible scholar and teacher completing an in-depth study guide.

STUDY MODE: DEEP STUDY - PASS 2/2 (Application + Resources)
This is part 2 of a 2-part deep study generation. Focus on practical transformation.
Target output: ~700 words for this pass.
Continue the scholarly tone with practical application.`

  const passInstructions = `CONTEXT FROM PASS 1:
- Study Summary: ${pass1Result.summary.substring(0, 200)}...
- You already wrote: Comprehensive exegetical analysis in Pass 1

NOW COMPLETE THE STUDY with practical application and supporting resources.

Generate this JSON structure (IMPORTANT: interpretationPart2 MUST be FIRST for optimal streaming):

{
  "interpretationPart2": "[550-700 words: PRACTICAL APPLICATION with life transformation, contemporary relevance, and action steps]",
  "relatedVerses": [7-10 Bible verse REFERENCES ONLY in ${languageConfig.name} for further study (e.g., 'Colossians 1:15-20', 'Hebrews 1:1-4') - NO verse text],
  "reflectionQuestions": [8-12 deep reflection questions mixing theology and application],
  "prayerPoints": [ONE single continuous prayer paragraph (6-8 sentences, 200-250 words) responding to the theological depth. Do NOT split into multiple items.]
}

**INTERPRETATION PART 2 - PRACTICAL APPLICATION (550-700 words):**

This section MUST contain EXACTLY 2 paragraphs of continuous transformative prose.
EACH paragraph MUST begin with a **Bold Section Title** followed by 6-8 sentences with DEEP PRACTICAL APPLICATION.
Use **Bold Title** format (NOT ## markdown headers).

⚠️ PRACTICAL DEPTH REQUIREMENTS (MANDATORY):
- MAINTAIN scholarly tone while being practically transformative
- BRIDGE theological insights from Pass 1 to actionable life change
- ADDRESS real struggles, challenges, and growth opportunities

Count sentences as you write (end with ./!/?). Each paragraph: 6-8 sentences, 275-350 words.

## Paragraph 1 (6-8 sentences): Life Transformation

Transform theological truth into life change:
- Mindset Shifts: Specific thought patterns that must change based on exegesis
- Heart Transformation: Attitudes, affections, desires that need renewal
- Identity in Christ: How this truth reshapes self-understanding
- Behavioral Changes: Specific actions that demonstrate obedience
- Relational Impact: How this affects marriage, family, friendships

Target: 275-350 words, 6-8 complete sentences with transformative depth.

## Paragraph 2 (6-8 sentences): Contemporary Relevance & Action Steps

Apply to modern contexts with concrete steps:
- Cultural Challenges: Specific contemporary issues this addresses
- This Week: 2-3 SPECIFIC actions for the next 7 days (be precise, not general)
- Spiritual Practices: Recommended disciplines for deepening this truth
- Crisis Application: How this helps in suffering, loss, doubt, failure

Target: 275-350 words, 6-8 complete sentences with contemporary insight and actionable steps.

**SUPPORTING MATERIALS:**
- relatedVerses: 7-10 additional verses in ${languageConfig.name}
- reflectionQuestions: 8-12 deep questions (theological + practical)
- prayerPoints: ONE single prayer paragraph (6-8 sentences, 200-250 words)

VERIFY: interpretationPart2: 2 paragraphs, 6-8 sentences each, 550-700 words | 7-10 relatedVerses | 8-12 reflectionQuestions | prayerPoints: 1 item, single paragraph (6-8 sentences, 200-250 words) | Verse refs in ${languageConfig.name} | Total ~700 words. FIX any issues BEFORE output.

Generate FULL CONTENT - no literal "..." or [...] placeholders.


Return ONLY the JSON object described above.
`

  const userMessage = `---
PASS 2: DEEP STUDY APPLICATION (Practical Transformation + Resources)
---
`

  return { sharedSystem, passSystem: `${passSystem}

${passInstructions}`, userMessage }
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
  }
): Record<string, unknown> {
  return {
    summary: pass1.summary,
    interpretation: joinInterpretationParts(
      [pass1.interpretationPart1, pass2.interpretationPart2],
      'deep-multipass'
    ),
    context: pass1.context,
    passage: pass1.passage,
    relatedVerses: pass2.relatedVerses,
    reflectionQuestions: pass2.reflectionQuestions,
    prayerPoints: pass2.prayerPoints
  }
}
