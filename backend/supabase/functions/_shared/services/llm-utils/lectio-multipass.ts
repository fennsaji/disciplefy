/**
 * Multi-Pass Meditative Reading Generation
 *
 * Protestant meditative Scripture reading — a prayerful, text-anchored approach
 * to reading and applying God's Word. Grounded in Scripture-interprets-Scripture
 * hermeneutics and Reformed spiritual disciplines (not Catholic contemplative mysticism).
 *
 * Replaces the former "Lectio Divina" mode which promoted Catholic contemplative
 * practices incompatible with the platform's Protestant Evangelical doctrinal framework.
 *
 * Breaks generation into 2 passes to work within model token limits:
 * - Pass 1: Summary + Context + Reading (Careful Reading) + Reflection (Biblical Reflection)
 * - Pass 2: Prayer Response + Application & Commitment + Supporting Fields
 *
 * This allows Hindi/Malayalam studies to achieve better word counts
 * despite token inefficiency (Hindi: 0.28 words/token, Malayalam: 0.09 words/token)
 */

import { type LLMGenerationParams, type LanguageConfig, type CacheablePromptPair } from '../llm-types.ts'
import {
  createSharedFoundation,
  createVerseReferenceBlock,
  getLanguageExamples
} from './prompt-builder.ts'

export type LectioPass = 'pass1' | 'pass2'

export interface LectioPassResult {
  pass: LectioPass
  content: string
}

/**
 * Creates the first pass prompt: Summary + Context + Careful Reading + Biblical Reflection
 */
export function createLectioPass1Prompt(
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
    ? `Create a MEDITATIVE READING guide for: \"${inputValue}\"`
    : `Create a MEDITATIVE READING guide on: \"${inputValue}\"${topicDescription ? `\n\nContext: ${topicDescription}` : ''}${pathContext}`

  const sharedSystem = createSharedFoundation(languageConfig, language, discipleLevel, false)

  const passSystem = `You are a Bible study guide leading prayerful Scripture reading and personal application.

STUDY MODE: MEDITATIVE READING - PASS 1/2 (Careful Reading + Biblical Reflection)
This is part 1 of a multi-pass Meditative Reading generation. Focus on slow, careful reading of the biblical text and deep reflection on what Scripture itself says.
Target output: ~950-1100 words for this pass.
Tone: Prayerful, warm, Scripture-anchored, clear. All spiritual insight must flow FROM the text, not from feelings, impressions, or inner experiences.

PROTESTANT DISTINCTIVES (MANDATORY):
- All discernment is anchored to the biblical text — never to feelings, visions, or subjective impressions alone
- "God speaking" means God speaking through His written Word (2 Timothy 3:16-17), not mystical inner voices
- Prayer is a believer's response to what Scripture reveals, not a technique for achieving spiritual states
- Silence and stillness are valid postures for reflection, but never as emptying techniques or centering practices
- Scripture interprets Scripture — cross-references must illuminate, not replace, the primary text`

  const userMessage = `${taskDescription}

${createVerseReferenceBlock(language)}

---
PASS 1: MEDITATIVE READING FOUNDATION (Careful Reading + Biblical Reflection)
---

Generate the following JSON structure with THESE SPECIFIC FIELDS ONLY:

{
  "summary": "[150-200 words: Title, scripture text (if applicable), central biblical message, what God reveals about Himself, invitation to read His Word carefully]",
  "context": "[40-60 words: MINIMAL - gentle introduction to prayerful Scripture reading as a Protestant spiritual discipline]",
  "passage": "⚠️ MANDATORY - Scripture reference for meditation. PREFER SHORTER passages (5-12 verses) for focused reading (e.g., 'Psalm 23:1-6', 'John 15:1-8', 'Philippians 4:4-9'). Format: Just the reference in ${languageConfig.name}, no verse text. DO NOT skip this field.",
  "interpretationPart1": "[700-900 words: **[Careful Reading header in ${languageConfig.name}]** + CAREFUL READING (First + Second Reading, 300-400 words) + **[Biblical Reflection header in ${languageConfig.name}]** + BIBLICAL REFLECTION (What God Reveals, 300-400 words). EACH SECTION MUST BEGIN WITH A BOLD **HEADER** IN ${languageConfig.name}.]"
}

CRITICAL INSTRUCTIONS FOR PASS 1:

**SUMMARY (150-200 words):**

Write an INVITATIONAL overview as CONTINUOUS NARRATIVE PROSE (NOT separate bullets).
This must be 6-8 complete sentences flowing together as a single paragraph.

Include these elements in flowing prose:
1. Begin with a clear, Scripture-grounded 4-6 word title as the opening phrase
2. Central Biblical Message: 2-3 sentences on the core theological truth God reveals in this text
3. What this reveals about God: 1-2 sentences on God's character, promises, or commands here
4. Invitation to read: 1-2 sentences inviting prayerful, attentive engagement with God's Word

Structure (NOT literal text - write entirely in ${languageConfig.name}):
- Sentence 1: [Title grounded in what the text says] + [invites into the biblical message]
- Sentences 2-4: [What God is saying to His people through these words]
- Sentences 5-6: [What this reveals about God's nature and purposes]
- Sentences 7-8: [Invitation to read carefully and respond in prayer]

CRITICAL:
- Write ENTIRELY in ${languageConfig.name} - NO English words mixed in
- Write as a SINGLE FLOWING PARAGRAPH of 6-8 sentences
- NOT as separate bullet points or title only

**CONTEXT (40-60 words):**
Write MINIMAL introduction to prayerful Scripture reading as a Protestant spiritual discipline (1 concise paragraph):
• Brief explanation of meditative Bible reading as an act of faith — coming to God's Word expectantly
• Heart preparation: quieting distractions, praying for understanding, Holy Spirit dependence (1 Corinthians 2:12-14)
Keep it SHORT and FOCUSED - only what's essential for entering the study.

**INTERPRETATION PART 1 - CAREFUL READING & BIBLICAL REFLECTION (700-900 words):**

This section MUST contain EXACTLY 2 sections of flowing prayerful prose.
EACH section MUST have 6-8 sentences with CLEAR, SCRIPTURE-ANCHORED guidance.

⚠️ BOLD SECTION HEADERS ARE MANDATORY:
Each section MUST begin with a **bold header** translated into ${languageConfig.name}:
- Section 1 starts with: **[Translation of "Careful Reading: Observing the Text"]** (bold, native language)
- Section 2 starts with: **[Translation of "Biblical Reflection: What God Reveals"]** (bold, native language)

⚠️ TEXTUAL GROUNDING REQUIREMENTS (MANDATORY):
- ALL spiritual insights MUST be drawn from and tested by the biblical text
- Do NOT instruct readers to "listen to God" in ways separate from Scripture
- INVITE careful observation of what the text actually says (not what they feel about it)
- EMPHASIZE the Holy Spirit's role in illuminating the written Word (John 16:13)
- BALANCE structured study with personal, prayerful response to what Scripture reveals

Count sentences as you write (end with ./!/?). Each section: 6-8 sentences, 300-400 words.

## CAREFUL READING: First and Second Pass Through the Text

**Section 1 - First Reading: Observation & Understanding (6-8 sentences, 300-400 words):**
- Invitation to pray first: Ask the Holy Spirit to open your eyes (Psalm 119:18)
- Observation prompts: What does the text actually SAY? What words are repeated or striking?
- Immediate context: What comes before and after this passage? How does that shape its meaning?
- Theological content: What does this passage teach about God, humanity, sin, or salvation?
- Original audience: What was God saying to them? What does that mean for us?
- Personal alignment: Which commands, promises, or warnings apply directly to you?

Target: 300-400 words, 6-8 complete sentences with observational and interpretive focus.

## BIBLICAL REFLECTION: What the Text Reveals About God

**Section 2 - What God Reveals (6-8 sentences, 300-400 words):**
Work through the passage focusing on what it reveals about God:
- God's nature: What does this passage teach about who God is (His attributes, character, ways)?
- Christ-centered reading: How does this passage point to or find fulfillment in Jesus Christ?
- Grace and truth: Where is the grace of God visible? Where is the demand of God visible?
- Doxological response: What about God in this passage moves you to worship, trust, or obedience?

⚠️ DO NOT include prayer content here — prayer response belongs ONLY in Pass 2 (Section 3). End this section with a question or reflection that prepares the reader to respond in prayer, but do NOT write the prayer itself.

Target: 300-400 words, 6-8 complete sentences with theological depth.

VERIFY: summary 150-200 words | context 40-60 words | passage reference ONLY (MANDATORY) | interpretationPart1: 2 sections with bold headers, 6-8 sentences each, 700-900 words | Prayerful & Scripture-anchored tone (not mystical) | Verse refs in ${languageConfig.name} | Total ~950-1100 words. FIX any issues BEFORE output.

Generate FULL CONTENT - no literal "..." placeholders.

${getLanguageExamples(language)}

OUTPUT ONLY THIS JSON - NO OTHER TEXT:
{
  "summary": "[YOUR 150-200 WORD SUMMARY HERE - as specified above]",
  "context": "[YOUR 40-60 WORD CONTEXT HERE - as specified above]",
  "passage": "[Scripture reference ONLY - e.g., 'Psalm 23:1-6' in ${languageConfig.name}]",
  "interpretationPart1": "[YOUR 700-900 WORD INTERPRETATION PART 1 HERE - 2 sections, each with bold header in ${languageConfig.name}]"
}`

  return { sharedSystem, passSystem, userMessage }
}

/**
 * Creates the second pass prompt: Prayer Response + Application & Commitment + Supporting Fields
 */
export function createLectioPass2Prompt(
  params: LLMGenerationParams,
  languageConfig: LanguageConfig,
  pass1Result: { summary: string; context: string; interpretationPart1: string }
): CacheablePromptPair {
  const { language, discipleLevel } = params

  const sharedSystem = createSharedFoundation(languageConfig, language, discipleLevel, false)

  const passSystem = `You are a Bible study guide completing a Meditative Reading guide.

STUDY MODE: MEDITATIVE READING - PASS 2/2 (Prayer Response + Application & Commitment)
This is part 2 of a 2-part Meditative Reading generation. Focus on prayerful response to Scripture and concrete life application.
Target output: ~600-750 words for this pass.
Continue the prayerful, Scripture-anchored tone. All prayer and application must flow from the biblical text studied in Pass 1.

PROTESTANT DISTINCTIVES (MANDATORY):
- Prayer is response to what Scripture reveals — always grounded in the text
- Application must be specific, concrete, and measurable — not vague spiritual feelings
- Commitment should be accountable: who, what, when, how — real-life obedience to God's Word`

  const userMessage = `---
PASS 2: MEDITATIVE READING RESPONSE (Prayer + Application & Commitment + Resources)
---

CONTEXT FROM PASS 1:
- Summary: ${pass1Result.summary.substring(0, 200)}...
- You already wrote: Careful Reading (Observation, Understanding, Personalizing) and Biblical Reflection in Pass 1

NOW COMPLETE THE MEDITATIVE READING with Prayer Response, Application & Commitment, and resources.

Generate this JSON structure (IMPORTANT: interpretationPart2 MUST be FIRST for optimal streaming):

{
  "interpretationPart2": "[500-650 words: **[Prayer Response header in ${languageConfig.name}]** + PRAYER RESPONSE (responding to God in prayer, 250-320 words) + **[Application & Commitment header in ${languageConfig.name}]** + APPLICATION & COMMITMENT (concrete, specific obedience, 250-320 words). EACH SECTION MUST BEGIN WITH A BOLD **HEADER** IN ${languageConfig.name}.]",
  "relatedVerses": [5-7 Bible verse REFERENCES ONLY in ${languageConfig.name} that support or expand the passage studied (e.g., 'Psalm 131:2', 'Matthew 11:28-30') - NO verse text],
  "reflectionQuestions": [5-7 reflection questions grounded in the text studied],
  "prayerPoints": [4-5 specific prayer topics arising directly from the passage - each 50-70 words as a SINGLE paragraph (no line breaks)],
  "summaryInsights": [4-5 key biblical truths from the passage - 15-20 words each],
  "interpretationInsights": [4-5 theological insights revealed by the text - 15-20 words each],
  "reflectionAnswers": [4-5 concrete life applications - 15-20 words each],
  "contextQuestion": "[Yes/no question connecting the passage's original context to personal life]",
  "summaryQuestion": "[Question about the central biblical message of the passage - 12-18 words]",
  "relatedVersesQuestion": "[Question encouraging further Bible reading on this theme - 12-18 words]",
  "reflectionQuestion": "[Question inviting personal reflection on the text - 12-18 words]",
  "prayerQuestion": "[Invitation to respond in prayer based on what Scripture taught - 10-15 words]"
}

**INTERPRETATION PART 2 - PRAYER RESPONSE & APPLICATION (500-650 words):**

This section MUST contain EXACTLY 2 focused sections of flowing prayerful prose.
Each section MUST have 6-8 sentences with CLEAR, TEXT-GROUNDED guidance.

⚠️ BOLD SECTION HEADERS ARE MANDATORY:
Each section MUST begin with a **bold header** translated into ${languageConfig.name}:
- Section 1 starts with: **[Translation of "Prayer Response: Speaking to God"]** (bold, native language)
- Section 2 starts with: **[Translation of "Application & Commitment: Living the Word"]** (bold, native language)

⚠️ CRITICAL DISTINCTION:
- interpretationPart2 = FLOWING NARRATIVE PROSE (paragraphs, personal guidance for the reader)
- prayerPoints = BULLET PRAYER TOPICS (short prompts, NOT long paragraphs)
Do NOT put prayer paragraphs in prayerPoints. They belong in interpretationPart2.

⚠️ SCRIPTURE-ANCHORED PRAYER REQUIREMENTS (MANDATORY):
- All prayer topics MUST arise from what the passage actually teaches
- Prayer is honest dialogue with God — thanksgiving, confession, petition, and praise rooted in the text
- Do NOT instruct readers to empty their minds or wait for inner voices — prayer is speaking and listening through Scripture
- GUIDE into authentic, specific prayer about real-life situations in light of God's Word
- BALANCE structured prayer prompts with freedom for personal, Spirit-led prayer

Count sentences as you write (end with ./!/?). Each section: 6-8 sentences, 250-320 words.

## PRAYER RESPONSE: Responding to God Based on the Text

Guide prayerful response to what Scripture revealed:

**Section 1 - Prayer of Response (6-8 sentences, 250-320 words):**
- Begin with thanksgiving: Thank God specifically for what this passage reveals about Him
- Confession: If the passage exposed sin or unbelief, pray honestly for forgiveness (1 John 1:9)
- Trust and faith: Pray to believe the promises the passage declared — name them specifically
- Petition: Ask God for what the passage calls you to — strength, obedience, faith, wisdom
- Intercession: Who comes to mind as you read this passage? Pray for them in light of its truth
- Surrender: What are you submitting to God in response to His Word? Name it specifically
- Closing praise: End with worship of God for who He is as revealed in this passage

Target: 250-320 words, 6-8 complete sentences with textually-grounded prayer.

## APPLICATION & COMMITMENT: Concrete Obedience to What Scripture Taught

Guide specific, measurable life application:

**Section 2 - Commitment to Obey (6-8 sentences, 250-320 words):**
- One truth to believe: What specific biblical truth will you commit to trusting this week? Name it.
- One sin to repent of: What specific sin or attitude does this passage call you to turn from? Be honest.
- One action to take: What concrete, observable step of obedience will you take in the next 7 days? Be specific (who, what, when, where).
- One person to serve: Who specifically can you serve or encourage this week based on what you studied?
- Accountability: Who will you tell about this commitment so they can encourage and check in?
- Scripture to memorize: Which single verse from this passage will you memorize to carry with you?
- Closing prayer of commitment: Pray aloud your specific commitment to God — a simple, sincere prayer of intention

Target: 250-320 words, 6-8 complete sentences with specific, accountable application.

**SUPPORTING MATERIALS:**
- relatedVerses: 5-7 additional verses that support the passage's themes in ${languageConfig.name}
- reflectionQuestions: 5-7 questions grounded in the text (not abstract or mystical)
- prayerPoints: 4-5 specific prayer topics (50-70 words each), arising from the passage
- summaryInsights: 4-5 key biblical truths (15-20 words each)
- interpretationInsights: 4-5 theological insights (15-20 words each)
- reflectionAnswers: 4-5 concrete life applications (15-20 words each)
- 5 yes/no questions connecting the text to personal life

VERIFY: interpretationPart2: 2 sections with bold headers, 6-8 sentences each, 500-650 words | 5-7 relatedVerses | 5-7 text-grounded reflectionQuestions | 4-5 prayerPoints (50-70 words each) | 4-5 items each for summaryInsights/interpretationInsights/reflectionAnswers (15-20 words) | 5 yes/no questions | Prayerful & Scripture-anchored tone | Verse refs in ${languageConfig.name} | Total ~600-750 words. FIX any issues BEFORE output.

Generate FULL CONTENT - no literal "..." or [...] placeholders.

${getLanguageExamples(language)}

OUTPUT ONLY THIS JSON - NO OTHER TEXT:
{
  "interpretationPart2": "[YOUR 500-650 WORD INTERPRETATION PART 2 HERE - 2 sections with bold headers in ${languageConfig.name}]",
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

  return { sharedSystem, passSystem, userMessage }
}

/**
 * Combines results from both passes into complete Meditative Reading structure
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
