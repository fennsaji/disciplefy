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
 * Creates the first pass prompt: Summary + Context + Careful Reading + Biblical Reflection
 */
export function createLectioPass1Prompt(
  params: LLMGenerationParams,
  languageConfig: LanguageConfig
): PromptPair {
  const { inputType, inputValue, topicDescription, language } = params

  const taskDescription = inputType === 'scripture'
    ? `Create a MEDITATIVE READING guide for: \"${inputValue}\"`
    : inputType === 'topic'
    ? `Create a MEDITATIVE READING guide on: \"${inputValue}\"${topicDescription ? `\n\nContext: ${topicDescription}` : ''}`
    : `Create a MEDITATIVE READING guide addressing: \"${inputValue}\"`

  const systemMessage = `You are a Bible study guide leading prayerful Scripture reading and personal application.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, language)}

STUDY MODE: MEDITATIVE READING - PASS 1/2 (Careful Reading + Biblical Reflection)
This is part 1 of a multi-pass Meditative Reading generation. Focus on slow, careful reading of the biblical text and deep reflection on what Scripture itself says.
Target output: ~1,600 words for this pass.
Tone: Prayerful, warm, Scripture-anchored, clear. All spiritual insight must flow FROM the text, not from feelings, impressions, or inner experiences.

PROTESTANT DISTINCTIVES (MANDATORY):
- All discernment is anchored to the biblical text — never to feelings, visions, or subjective impressions alone
- "God speaking" means God speaking through His written Word (2 Timothy 3:16-17), not mystical inner voices
- Prayer is a believer's response to what Scripture reveals, not a technique for achieving spiritual states
- Silence and stillness are valid postures for reflection, but never as emptying techniques or centering practices
- Scripture interprets Scripture — cross-references must illuminate, not replace, the primary text`

  const userMessage = `${taskDescription}

${createVerseReferenceBlock(language)}

═══════════════════════════════════════════════════════════════════════════
PASS 1: MEDITATIVE READING FOUNDATION (Careful Reading + Biblical Reflection)
═══════════════════════════════════════════════════════════════════════════

Generate the following JSON structure with THESE SPECIFIC FIELDS ONLY:

{
  "summary": "[250-300 words: Title, scripture text (if applicable), central biblical message, what God reveals about Himself, invitation to read His Word carefully]",
  "context": "[50-80 words: MINIMAL - gentle introduction to prayerful Scripture reading as a Protestant spiritual discipline]",
  "passage": "⚠️ MANDATORY - Scripture reference for meditation. PREFER SHORTER passages (5-12 verses) for focused reading (e.g., 'Psalm 23:1-6', 'John 15:1-8', 'Philippians 4:4-9'). Format: Just the reference in ${languageConfig.name}, no verse text. DO NOT skip this field.",
  "interpretationPart1": "[1200-1500 words: CAREFUL READING (First + Second + Third Reading) + BIBLICAL REFLECTION (Verse Study + Personal Encounter)]"
}

CRITICAL INSTRUCTIONS FOR PASS 1:

**SUMMARY (250-300 words):**

Write an INVITATIONAL overview as CONTINUOUS NARRATIVE PROSE (NOT separate bullets).
This must be 8-12 complete sentences flowing together as a single paragraph.

Include these elements in flowing prose:
1. Begin with a clear, Scripture-grounded 4-6 word title as the opening phrase
2. [IF SCRIPTURE]: Include the full passage text for slow, careful reading
3. Central Biblical Message: 2-3 sentences on the core theological truth God reveals in this text
4. What this reveals about God: 2-3 sentences on God's character, promises, or commands here
5. Invitation to read: 2-3 sentences inviting prayerful, attentive engagement with God's Word

Structure for Scripture Input (NOT literal text - write entirely in ${languageConfig.name}):
- Sentence 1: [Title grounded in what the text says] + [invites into the biblical message]
- Sentences 2-5: [FULL scripture passage text in ${languageConfig.name}]
- Sentences 6-8: [What God is saying to His people through these words]
- Sentences 9-10: [What this passage reveals about God's nature and purposes]
- Sentences 11-12: [Invitation to read carefully and respond in prayer]

Structure for Topic Input (NOT literal text - write entirely in ${languageConfig.name}):
- Sentence 1: [Title grounded in biblical truth] + [draws into the biblical message]
- Sentences 2-4: [Central biblical truth God reveals through this topic]
- Sentences 5-8: [What Scripture says about this topic — grounded in specific texts]
- Sentences 9-12: [Invitation to engage God's Word and respond in prayer]

CRITICAL:
- Write ENTIRELY in ${languageConfig.name} - NO English words mixed in
- Write as a SINGLE FLOWING PARAGRAPH of 8-12 sentences
- NOT as separate bullet points or title only
- If scripture input, include the FULL passage text within the narrative flow

**CONTEXT (50-80 words):**
Write MINIMAL introduction to prayerful Scripture reading as a Protestant spiritual discipline (1 concise paragraph):
• Brief explanation of meditative Bible reading as an act of faith — coming to God's Word expectantly
• Heart preparation: quieting distractions, praying for understanding, Holy Spirit dependence (1 Corinthians 2:12-14)
Keep it SHORT and FOCUSED - only what's essential for entering the study.

**INTERPRETATION PART 1 - CAREFUL READING & BIBLICAL REFLECTION (1200-1500 words):**

This section MUST contain EXACTLY 3 or 4 sections of flowing prayerful prose.
EACH section MUST have 7-9 sentences with CLEAR, SCRIPTURE-ANCHORED guidance.

⚠️ TEXTUAL GROUNDING REQUIREMENTS (MANDATORY):
- ALL spiritual insights MUST be drawn from and tested by the biblical text
- Do NOT instruct readers to "listen to God" in ways separate from Scripture
- INVITE careful observation of what the text actually says (not what they feel about it)
- EMPHASIZE the Holy Spirit's role in illuminating the written Word (John 16:13)
- BALANCE structured study with personal, prayerful response to what Scripture reveals

⚠️ SENTENCE COUNTING IS MANDATORY:
- A sentence ends with: period (.) OR question mark (?) OR exclamation point (!)
- Count each sentence as you write: "1. [sentence]. 2. [sentence]... 7. [sentence]."
- If you reach 6 sentences, ADD 1-3 MORE SENTENCES to reach 7-9
- Each section should be 300-400 words of prayerful, text-grounded guidance

## CAREFUL READING: First, Second, and Third Pass Through the Text (900-1100 words)

Guide the reader through slow, prayerful reading of Scripture:

**Section 1 - First Reading: Observation (7-9 sentences, 300-400 words):**
- Invitation to pray first: Ask the Holy Spirit to open your eyes (Psalm 119:18)
- Slow reading guidance: Read the passage aloud at half your normal speed
- Observation prompts: What does the text actually SAY? (Not what it means yet — just what it says)
- Key words: What words are repeated, emphasized, or striking?
- Who/what/when/where: Identify the main characters, actions, setting, and context
- First impressions: What stands out? What surprises you? What do you not fully understand?
- Initial response: What is your honest reaction to what you have just read?
- [OPTIONAL] Write it down: Note words or phrases that catch your attention

Target: 300-400 words, 7-9 complete sentences with observational focus.

**Section 2 - Second Reading: Understanding (7-9 sentences, 300-400 words):**
- Read again: Slowly, with the question "What does this mean?"
- Immediate context: What comes before and after this passage? How does that shape its meaning?
- Biblical context: How does this fit within the book, the Testament, and the whole Bible story?
- Scripture cross-references: What other passages use similar language or address the same truth?
- Theological content: What does this passage teach about God, humanity, sin, salvation, or the Christian life?
- Original audience: What would this have meant to the original hearers? What was God saying to them?
- Questions from the text: What questions does a careful reading raise that you need to investigate further?
- [OPTIONAL] Word study: If a key word is unclear, consider its biblical usage elsewhere

Target: 300-400 words, 7-9 complete sentences with interpretive focus.

**Section 3 - Third Reading: Personalizing (7-9 sentences, 300-300 words):**
- Read once more: With the question "What does this mean for MY life?"
- Direct address: Which commands, promises, warnings, or examples apply directly to you?
- Personal alignment: Where does your life align with this truth? Where does it fall short?
- Promise to claim: Is there a specific promise of God here you need to believe today?
- Command to obey: Is there a specific instruction here you need to follow this week?
- Warning to heed: Is there a specific danger here you need to avoid?
- One response: What is ONE specific, concrete way you will respond to this passage?
- [OPTIONAL] Write it down: Record your personal response for accountability

Target: 300-300 words, 7-9 complete sentences with applicational focus.

## BIBLICAL REFLECTION: Deeper Engagement With What the Text Reveals (900-1100 words)

Guide thoughtful engagement with the theological content of the passage:

**Section 4 - What God Reveals (7-9 sentences, 300-400 words):**
Work through the passage focusing on what it reveals about God:
- God's nature: What does this passage teach about who God is (His attributes, character, ways)?
- God's purposes: What is God doing or intending in this text? What are His redemptive goals?
- God's relationship with people: How does God engage, respond to, or address humanity here?
- Christ-centered reading: How does this passage point to, prefigure, or find fulfillment in Jesus Christ?
- Grace and truth: Where is the grace of God visible? Where is the demand of God visible?
- Covenant connections: How does this passage connect to God's covenant promises and redemptive history?
- Doxological response: What about God in this passage moves you to worship, trust, or obedience?
- [OPTIONAL] Systematic connections: Which doctrine (God, humanity, Christ, salvation, church, last things) is most prominent here?

Target: 300-400 words, 7-9 complete sentences with theological depth.

**Section 5 - Personal Encounter With the Text (7-9 sentences, 300-400 words):**
Guide the reader into honest self-examination in light of what Scripture says:
- Self-examination: What does this passage reveal about your own heart, beliefs, or behaviors?
- Where you need grace: Where does this text expose your need for forgiveness or transformation?
- Where you need faith: What promise or truth in this passage requires faith for you to believe right now?
- Repentance prompted: Is there anything this passage calls you to repent of and turn from?
- Encouragement received: What encouragement or comfort does this passage provide for your current situation?
- Conviction and confidence: Where do you feel conviction? Where do you feel confidence in Christ?
- Honest prayer: What is your honest prayer to God based on what you have just read?
- [OPTIONAL] Relationships: How does this passage affect how you should treat or view others?

Target: 300-400 words, 7-9 complete sentences with honest self-examination.

⚠️ MANDATORY PRE-OUTPUT VERIFICATION FOR PASS 1:

Before completing your response, COUNT and verify:
1. Does "summary" have 250-300 words (8-12 sentences)? [Count: ___]
2. Does "context" have 50-80 words (MINIMAL)? [Count: ___]
3. ⚠️ CRITICAL: Does "passage" contain ONLY the Scripture reference (NOT full verse text)? [Format correct: Yes/No]
4. Does "interpretationPart1" have EXACTLY 3 or 4 sections? [Count: ___]
5. Does EACH section have 7-9 sentences? [Count each: ___ ___ ___ ___]
6. Is "interpretationPart1" 1200-1500 words total? [Estimated count: ___]
7. Is the tone prayerful and Scripture-anchored (not mystical or centering-prayer based)? [Check: Yes/No]
8. Does each section draw insights FROM the text rather than from feelings or impressions? [Check: Yes/No]
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
 * Creates the second pass prompt: Prayer Response + Application & Commitment + Supporting Fields
 */
export function createLectioPass2Prompt(
  params: LLMGenerationParams,
  languageConfig: LanguageConfig,
  pass1Result: { summary: string; context: string; interpretationPart1: string }
): PromptPair {
  const { language } = params

  const systemMessage = `You are a Bible study guide completing a Meditative Reading guide.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, language)}

STUDY MODE: MEDITATIVE READING - PASS 2/2 (Prayer Response + Application & Commitment)
This is part 2 of a 2-part Meditative Reading generation. Focus on prayerful response to Scripture and concrete life application.
Target output: ~500 words for this pass.
Continue the prayerful, Scripture-anchored tone. All prayer and application must flow from the biblical text studied in Pass 1.

PROTESTANT DISTINCTIVES (MANDATORY):
- Prayer is response to what Scripture reveals — always grounded in the text
- Application must be specific, concrete, and measurable — not vague spiritual feelings
- Commitment should be accountable: who, what, when, how — real-life obedience to God's Word`

  const userMessage = `═══════════════════════════════════════════════════════════════════════════
PASS 2: MEDITATIVE READING RESPONSE (Prayer + Application & Commitment + Resources)
═══════════════════════════════════════════════════════════════════════════

CONTEXT FROM PASS 1:
- Summary: ${pass1Result.summary.substring(0, 200)}...
- You already wrote: Careful Reading (Observation, Understanding, Personalizing) and Biblical Reflection in Pass 1

NOW COMPLETE THE MEDITATIVE READING with Prayer Response, Application & Commitment, and resources.

Generate this JSON structure (IMPORTANT: interpretationPart2 MUST be FIRST for optimal streaming):

{
  "interpretationPart2": "[400-500 words: PRAYER RESPONSE (responding to God in prayer based on the text) + APPLICATION & COMMITMENT (concrete, specific obedience to what Scripture taught) with prayer guidance, application steps, and accountability prompts]",
  "relatedVerses": [5-7 Bible verse REFERENCES ONLY in ${languageConfig.name} that support or expand the passage studied (e.g., 'Psalm 131:2', 'Matthew 11:28-30') - NO verse text],
  "reflectionQuestions": [5-7 reflection questions grounded in the text studied],
  "prayerPoints": [4-5 specific prayer topics arising directly from the passage - each 50-70 words],
  "summaryInsights": [4-5 key biblical truths from the passage - 15-20 words each],
  "interpretationInsights": [4-5 theological insights revealed by the text - 15-20 words each],
  "reflectionAnswers": [4-5 concrete life applications - 15-20 words each],
  "contextQuestion": "[Yes/no question connecting the passage's original context to personal life]",
  "summaryQuestion": "[Question about the central biblical message of the passage - 12-18 words]",
  "relatedVersesQuestion": "[Question encouraging further Bible reading on this theme - 12-18 words]",
  "reflectionQuestion": "[Question inviting personal reflection on the text - 12-18 words]",
  "prayerQuestion": "[Invitation to respond in prayer based on what Scripture taught - 10-15 words]"
}

**INTERPRETATION PART 2 - PRAYER RESPONSE & APPLICATION (400-500 words):**

This section MUST contain EXACTLY 2 focused sections of flowing prayerful prose.
Each section MUST have 7-9 sentences with CLEAR, TEXT-GROUNDED guidance.

⚠️ SCRIPTURE-ANCHORED PRAYER REQUIREMENTS (MANDATORY):
- All prayer topics MUST arise from what the passage actually teaches
- Prayer is honest dialogue with God — thanksgiving, confession, petition, and praise rooted in the text
- Do NOT instruct readers to empty their minds or wait for inner voices — prayer is speaking and listening through Scripture
- GUIDE into authentic, specific prayer about real-life situations in light of God's Word
- BALANCE structured prayer prompts with freedom for personal, Spirit-led prayer

⚠️ SENTENCE COUNTING IS MANDATORY:
- A sentence ends with: period (.) OR question mark (?) OR exclamation point (!)
- Count each sentence as you write: "1. [sentence]. 2. [sentence]... 7. [sentence]."
- If you reach 6 sentences, ADD 1-3 MORE SENTENCES to reach 7-9
- Each section should be 200-260 words of prayerful, grounded guidance

## PRAYER RESPONSE: Responding to God Based on the Text (400-500 words)

Guide prayerful response to what Scripture revealed:

**Section 1 - Prayer of Response (7-9 sentences, 200-260 words):**
- Begin with thanksgiving: Thank God specifically for what this passage reveals about Him
- Confession: If the passage exposed sin or unbelief, pray honestly for forgiveness (1 John 1:9)
- Trust and faith: Pray to believe the promises the passage declared — name them specifically
- Petition: Ask God for what the passage calls you to — strength, obedience, faith, wisdom
- Intercession: Who comes to mind as you read this passage? Pray for them in light of its truth
- Surrender: What are you submitting to God in response to His Word? Name it specifically
- Closing praise: End with worship of God for who He is as revealed in this passage

Target: 200-260 words, 7-9 complete sentences with textually-grounded prayer.

## APPLICATION & COMMITMENT: Concrete Obedience to What Scripture Taught (400-500 words)

Guide specific, measurable life application:

**Section 2 - Commitment to Obey (7-9 sentences, 200-260 words):**
- One truth to believe: What specific biblical truth will you commit to trusting this week? Name it.
- One sin to repent of: What specific sin or attitude does this passage call you to turn from? Be honest.
- One action to take: What concrete, observable step of obedience will you take in the next 7 days? Be specific (who, what, when, where).
- One person to serve: Who specifically can you serve or encourage this week based on what you studied?
- Accountability: Who will you tell about this commitment so they can encourage and check in?
- Scripture to memorize: Which single verse from this passage will you memorize to carry with you?
- Closing prayer of commitment: Pray aloud your specific commitment to God — a simple, sincere prayer of intention

Target: 200-260 words, 7-9 complete sentences with specific, accountable application.

**SUPPORTING MATERIALS:**
- relatedVerses: 5-7 additional verses that support the passage's themes in ${languageConfig.name}
- reflectionQuestions: 5-7 questions grounded in the text (not abstract or mystical)
- prayerPoints: 4-5 specific prayer topics (50-70 words each), arising from the passage
- summaryInsights: 4-5 key biblical truths (15-20 words each)
- interpretationInsights: 4-5 theological insights (15-20 words each)
- reflectionAnswers: 4-5 concrete life applications (15-20 words each)
- 5 yes/no questions connecting the text to personal life

⚠️ MANDATORY PRE-OUTPUT VERIFICATION FOR PASS 2:

Before completing your response, COUNT and verify:
1. Does "interpretationPart2" have EXACTLY 2 sections? [Count: ___]
2. Does EACH section have 7-9 sentences? [Count each: ___ ___]
3. Is "interpretationPart2" 400-500 words total? [Estimated count: ___]
4. Does "relatedVerses" contain 5-7 verses? [Count: ___]
5. Are all verses in ${languageConfig.name}? [Check: Yes/No]
6. Does "reflectionQuestions" contain 5-7 questions? [Count: ___]
7. Are questions grounded in the text (not abstract or mystical)? [Check: Yes/No]
8. Does "prayerPoints" contain 4-5 prayer topics? [Count: ___]
9. Is each prayer point 50-70 words? [Check: Yes/No]
10. Are "summaryInsights" 4-5 items at 15-20 words each? [Count: ___]
11. Are "interpretationInsights" 4-5 items at 15-20 words each? [Count: ___]
12. Are "reflectionAnswers" 4-5 items at 15-20 words each? [Count: ___]
13. Are all 5 yes/no questions present? [Check: Yes/No]
14. Is the tone prayerful and Scripture-anchored (not mystical or centering-prayer based)? [Check: Yes/No]
15. Is total Pass 2 output ~500 words? [Estimated: ___]

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
