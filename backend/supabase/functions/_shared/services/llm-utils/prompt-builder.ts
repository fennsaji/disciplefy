/**
 * REFINED LLM Prompt Builder Module
 *
 * Optimized for:
 * - Reduced redundancy through shared blocks
 * - Clearer instruction hierarchy
 * - Stronger theological guardrails
 * - Improved JSON compliance
 * - Better long-context performance
 */

import type { LLMGenerationParams, LanguageConfig } from '../llm-types.ts'
import { getLanguageExamples, type SupportedLanguage } from '../llm-config/language-configs.ts'

export interface PromptPair {
  systemMessage: string
  userMessage: string
}

// ============================================================================
// SHARED FOUNDATIONAL BLOCKS (Reused Across All Modes)
// ============================================================================

/**
 * Core theological guardrails - non-negotiable across all study modes
 * Enforces Protestant orthodoxy, sola Scriptura, and Christ-centered hermeneutics
 */
const THEOLOGICAL_FOUNDATION = `
═══════════════════════════════════════════════════════════════════════════
THEOLOGICAL FRAMEWORK - NON-NEGOTIABLE CONSTRAINTS
═══════════════════════════════════════════════════════════════════════════

DOCTRINAL ORTHODOXY (Protestant Evangelical):
✓ Sola Scriptura: Scripture ALONE as final authority (no tradition, papal authority, or extra-biblical revelation as co-equal)
✓ Sola Fide: Salvation by grace ALONE through faith ALONE in Christ ALONE
✓ Penal Substitutionary Atonement: Christ bore God's wrath for sinners on the cross
✓ Biblical Inerrancy: Scripture is without error in original manuscripts
✓ Triune God: One God in three persons (Father, Son, Holy Spirit)

HERMENEUTICAL METHOD (Historical-Grammatical):
✓ Authorial Intent: Interpret according to what the original author meant to original audience
✓ Grammatical-Historical Context: Consider grammar, history, culture, literary genre
✓ Scripture Interprets Scripture: Use clear passages to illuminate difficult ones
✓ Christocentric Reading: All Scripture ultimately points to and finds fulfillment in Jesus Christ
✓ REJECT: Allegorical speculation, eisegesis (reading into text), prosperity gospel, word-faith theology

GOSPEL CLARITY (Essential for Salvation):
✓ Human Condition: All have sinned and fall short of God's glory (Romans 3:23)
✓ God's Holiness: God's wrath against sin requires satisfaction (Romans 6:23)
✓ Christ's Work: Jesus lived sinlessly, died substitutionally, rose bodily (1 Cor 15:3-4)
✓ Saving Faith: Repentance from sin + faith in Christ alone (not works, not rituals)
✓ REJECT: Works-based salvation, decisional regeneration without repentance, universalism

DOCTRINAL PROHIBITIONS (NEVER Teach):
✗ Prosperity gospel (health/wealth as entitlement)
✗ Word-faith theology ("name it and claim it")
✗ Liberal theology (Scripture as merely human wisdom)
✗ Universalism (all paths lead to God)
✗ Works-righteousness (salvation earned by human merit)
✗ Extra-biblical revelation as authoritative (dreams, visions, "God told me")
`.trim()

/**
 * JSON output enforcement - highest priority for system stability
 * Front-loaded to prevent truncation under token pressure
 */
const JSON_OUTPUT_RULES = `
═══════════════════════════════════════════════════════════════════════════
JSON OUTPUT REQUIREMENTS - ABSOLUTE PRIORITY
═══════════════════════════════════════════════════════════════════════════

MANDATORY FORMAT:
1. Output MUST start with { and end with } - NOTHING else before or after
2. NO markdown code blocks (no \`\`\`json)
3. NO explanatory text outside JSON
4. NO trailing commas in arrays or objects
5. Use proper JSON string escaping: \\n for newlines, \\" for quotes, \\\\ for backslashes

VALIDATION CHECKPOINT:
Before generating output, verify:
✓ Is first character { ?
✓ Is last character } ?
✓ Are all strings properly escaped?
✓ Are all commas correctly placed (no trailing commas)?
✓ Are all required fields present?

IF YOU VIOLATE JSON FORMAT, THE ENTIRE GENERATION WILL FAIL.
`.trim()

/**
 * Language enforcement block with native script requirements
 */
function createLanguageBlock(languageConfig: LanguageConfig, language: string): string {
  return `
═══════════════════════════════════════════════════════════════════════════
LANGUAGE REQUIREMENTS - STRICT ENFORCEMENT
═══════════════════════════════════════════════════════════════════════════

PRIMARY LANGUAGE: ${languageConfig.name}
${languageConfig.promptModifiers.languageInstruction}
${languageConfig.promptModifiers.complexityInstruction}
Cultural Context: ${languageConfig.culturalContext}

NATIVE SCRIPT ENFORCEMENT:
${language === 'hi' ? `
✓ ALL Hindi content MUST be in Devanagari script
✗ NO romanized Hinglish (e.g., "Prabhu" is FORBIDDEN - use "प्रभु")
✓ Prayer closing: "येशु मसीह के नाम से, आमेन" (NOT "Yeshu Masih ke naam se, Amen")
` : language === 'ml' ? `
✓ ALL Malayalam content MUST be in Malayalam script
✗ NO romanized Manglish (e.g., "Karthaav" is FORBIDDEN - use "കർത്താവ്")
✓ Prayer closing: "യേശുക്രിസ്തുവിന്റെ നാമത്തിൽ, ആമേൻ" (NOT romanized)
` : `
✓ Use clear, accessible English (avoid unnecessary theological jargon)
✓ Prayer closing: "In Jesus' name, Amen" or "Amen"
`}

VOCABULARY: Simple, accessible to all education levels while maintaining theological precision.
`.trim()
}

/**
 * Verse reference formatting examples by language
 */
function createVerseReferenceBlock(language: string): string {
  const examples = {
    en: 'Examples: "John 3:16", "Romans 8:28", "Psalm 23:1"',
    hi: 'उदाहरण: "यूहन्ना 3:16", "रोमियों 8:28", "भजन संहिता 23:1" - पुस्तक नाम हिंदी में (English में नहीं)',
    ml: 'ഉദാഹരണം: "യോഹന്നാൻ 3:16", "റോമർ 8:28", "സങ്കീർത്തനങ്ങൾ 23:1" - പുസ്തക നാമങ്ങൾ മലയാളത്തിൽ'
  }

  return `
VERSE REFERENCE FORMAT:
${examples[language as SupportedLanguage] || examples.en}
✓ ALL verse references MUST use ${language === 'hi' ? 'Devanagari script' : language === 'ml' ? 'Malayalam script' : 'English'} book names
`.trim()
}

/**
 * Prayer format requirements (universal structure, language-specific closing)
 */
function createPrayerFormatBlock(languageConfig: LanguageConfig, language: string, sentenceCount: string = '6-8'): string {
  const closings = {
    en: 'In Jesus\' name, Amen',
    hi: 'येशु मसीह के नाम से, आमेन',
    ml: 'യേശുക്രിസ്തുവിന്റെ നാമത്തിൽ, ആമേൻ'
  }

  return `
PRAYER FORMAT REQUIREMENTS:
1. Structure: [Address God] → [Prayer content based on study] → [Closing]
2. Length: ${sentenceCount} complete sentences
3. Person: First-person ("I"/"we"), addressing God directly
4. Tone: Reverent, personal, aligned with study content
5. Closing: "${closings[language as SupportedLanguage] || closings.en}"
6. Language: ENTIRE prayer in ${languageConfig.name} (including closing)
`.trim()
}

// ============================================================================
// MODE-SPECIFIC PROMPT BUILDERS
// ============================================================================

/**
 * STANDARD MODE (10 minutes)
 * Balanced depth for daily devotional use
 */
function createStandardModePrompt(params: LLMGenerationParams, languageConfig: LanguageConfig): PromptPair {
  const { inputType, inputValue, topicDescription } = params
  const languageExamples = getLanguageExamples(params.language)

  // Task description based on input type
  const taskDescription = inputType === 'scripture'
    ? `Create a Bible study guide for: "${inputValue}"`
    : inputType === 'topic'
    ? `Create a Bible study guide on: "${inputValue}"${topicDescription ? `\\n\\nContext: ${topicDescription}` : ''}`
    : `Answer the question and create a study guide: "${inputValue}"`

  const systemMessage = `You are a biblical scholar creating Bible study guides.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, params.language)}

STUDY MODE: STANDARD (10 minutes)
Tone: Pastoral, warm, encouraging, practical for daily spiritual growth.`

  const userMessage = `${taskDescription}

${createVerseReferenceBlock(params.language)}

═══════════════════════════════════════════════════════════════════════════
CONTENT STRUCTURE - ALL 14 FIELDS MANDATORY
═══════════════════════════════════════════════════════════════════════════

{
  "summary": "Overview in 4-5 sentences covering main message",
  "interpretation": "Theological teaching in 4-5 paragraphs. Each paragraph 5-6 sentences. Continuous prose WITHOUT headings/bullets.",
  "context": "Historical/cultural background in 2-3 paragraphs (3-5 sentences each)",
  "relatedVerses": ["4-6 Bible verses with references in ${languageConfig.name}"],
  "reflectionQuestions": ["5-6 application questions"],
  "prayerPoints": ["Complete first-person prayer (6-8 sentences)"],
  "summaryInsights": ["4-5 resonance themes (12-18 words each)"],
  "interpretationInsights": ["4-5 theological insights (12-18 words each)"],
  "reflectionAnswers": ["4-5 life applications (12-18 words each)"],
  "contextQuestion": "Yes/no question connecting context to modern life",
  "summaryQuestion": "Question about summary (10-15 words)",
  "relatedVersesQuestion": "Verse study question (10-15 words)",
  "reflectionQuestion": "Application question (10-15 words)",
  "prayerQuestion": "Prayer invitation (8-12 words)"
}

${createPrayerFormatBlock(languageConfig, params.language, '6-8')}

CRITICAL FORMATTING RULES:
✓ "interpretation": 4-5 FLOWING PARAGRAPHS (5-6 sentences each) - NO bullet points, NO bracketed headings
✓ Write in continuous narrative prose
✓ Each paragraph explores one theological aspect with depth

VERIFICATION BEFORE OUTPUT:
✓ Does "interpretation" have 4-5 full paragraphs (NOT bullet lists)?
✓ Is each paragraph 5-6 complete sentences?
✓ Are all 14 fields present?
✓ Does prayer have 6-8 sentences and correct closing?
✓ Are all verse references in ${languageConfig.name}?

${languageExamples}

OUTPUT: Valid JSON starting with { and ending with }`

  return { systemMessage, userMessage }
}

/**
 * QUICK READ MODE (3 minutes)
 * Concise for busy schedules
 */
function createQuickReadPrompt(params: LLMGenerationParams, languageConfig: LanguageConfig): PromptPair {
  const taskDescription = `Create a 3-MINUTE quick study for: "${params.inputValue}"`

  const systemMessage = `You are a biblical scholar creating CONCISE but SUBSTANTIAL Bible studies for busy readers.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, params.language)}

STUDY MODE: QUICK READ (3 minutes = 600-750 words)
Reading speed: 200-250 words/minute
Tone: Direct, warm, immediately actionable, theologically sound.`

  const userMessage = `${taskDescription}

${createVerseReferenceBlock(params.language)}

CONTENT STRUCTURE (ALL 14 FIELDS MANDATORY - 3-minute reading time):
{
  "summary": "Main message in 3-4 sentences capturing core truth and practical relevance",
  "interpretation": "Theological explanation in 2 flowing paragraphs (3-4 sentences each). Explain meaning and how it points to Christ. Total: 6-8 sentences of continuous prose WITHOUT headings or bullet points.",
  "context": "Historical and cultural background in 1-2 paragraphs (2-3 sentences each). Explain original setting and modern relevance.",
  "relatedVerses": ["3-4 supporting Bible verses with references in ${languageConfig.name}"],
  "reflectionQuestions": ["3-4 practical application questions"],
  "prayerPoints": ["Complete first-person prayer (4-5 sentences) addressing the study's main themes"],
  "summaryInsights": ["3-4 key themes (10-15 words each)"],
  "interpretationInsights": ["3-4 theological insights (10-15 words each)"],
  "reflectionAnswers": ["3-4 life applications (10-15 words each)"],
  "contextQuestion": "Yes/no question connecting biblical context to modern life",
  "summaryQuestion": "Brief question (6-10 words)",
  "relatedVersesQuestion": "Verse question (6-10 words)",
  "reflectionQuestion": "Application question (6-10 words)",
  "prayerQuestion": "Prayer prompt (5-8 words)"
}

${createPrayerFormatBlock(languageConfig, params.language, '4-5')}

CONTENT LENGTH REQUIREMENTS FOR 3-MINUTE READ (600-750 words total):
✓ Summary: 3-4 sentences (50-60 words)
✓ Interpretation: 2 paragraphs × 3-4 sentences = 6-8 sentences (120-160 words) - MAIN CONTENT
✓ Context: 1-2 paragraphs × 2-3 sentences = 4-6 sentences (80-120 words)
✓ Prayer: 4-5 sentences (60-80 words)
✓ Related Verses: 3-4 verses (with references)
✓ Questions: 3-4 questions each for reflection
✓ Insights: 3-4 items per array (10-15 words each)

CRITICAL FORMATTING:
✓ "interpretation" MUST be 2 flowing paragraphs (NO headings, NO bullets)
✓ Each paragraph 3-4 complete sentences
✓ Continuous narrative prose explaining theology clearly and concisely
✓ Focus on ONE central truth with enough depth for 3-minute read

VERIFICATION BEFORE OUTPUT:
✓ Does "interpretation" have exactly 2 full paragraphs (6-8 sentences total)?
✓ Is each paragraph 3-4 complete sentences of continuous prose?
✓ Does "context" have 1-2 paragraphs (4-6 sentences total)?
✓ Does "summary" have 3-4 sentences?
✓ Does prayer have 4-5 sentences with correct closing?
✓ Are there 3-4 related verses in ${languageConfig.name}?
✓ Are there 3-4 reflection questions?
✓ Are all 14 fields present?
✓ Is total content approximately 600-750 words (3-minute read)?

OUTPUT: Valid JSON starting with { and ending with }`

  return { systemMessage, userMessage }
}

/**
 * DEEP DIVE MODE (25 minutes)
 * Scholarly depth for serious students
 */
function createDeepDivePrompt(params: LLMGenerationParams, languageConfig: LanguageConfig): PromptPair {
  const { inputType, inputValue, topicDescription } = params

  const taskDescription = inputType === 'scripture'
    ? `Create a DEEP DIVE study for: "${inputValue}"`
    : `Create a COMPREHENSIVE study on: "${inputValue}"${topicDescription ? `\\n\\nContext: ${topicDescription}` : ''}`

  const systemMessage = `You are an expert biblical scholar creating IN-DEPTH studies for serious students.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, params.language)}

STUDY MODE: DEEP DIVE (25 minutes)
Scholarly depth with accessibility. Include original language insights, systematic theology, church history.
Tone: Scholarly yet pastoral, thorough, illuminating.`

  const userMessage = `${taskDescription}

${createVerseReferenceBlock(params.language)}

═══════════════════════════════════════════════════════════════════════════
DEEP DIVE STRUCTURE - EXTENSIVE CONTENT REQUIRED
═══════════════════════════════════════════════════════════════════════════

INTERPRETATION SECTION (1500-2000 words MINIMUM):

**Theological Exposition (6-8 paragraphs):**
Paragraph 1: Introduce main theological themes (5-7 sentences)
Paragraph 2: First major concept with biblical support (5-7 sentences)
Paragraph 3: Second major concept (5-7 sentences)
Paragraph 4: Third major concept (5-7 sentences)
Paragraph 5: Connect to broader biblical theology (5-7 sentences)
Paragraph 6: Address theological tensions (5-7 sentences)
Paragraphs 7-8: Synthesize and apply (5-7 sentences each)

**Word Studies (2-3 key words):**
For EACH word: Greek/Hebrew with transliteration, root meaning, biblical usage, theological significance (3-4 sentences per word)

**Doctrinal Implications (3-4 paragraphs):**
Paragraph 1: Systematic theology connections (5-6 sentences)
Paragraph 2: Church history perspective (5-6 sentences)
Paragraph 3: Contemporary application (5-6 sentences)
Paragraph 4: Practical implications (5-6 sentences)

CONTEXT SECTION (800-1000 words MINIMUM):

**Historical Context (2-3 paragraphs, 5-6 sentences each)**
**Literary Context (2 paragraphs, 5-6 sentences each)**
**Cross-References (5-8 passages with 2-3 sentence explanations each)**

JSON STRUCTURE:
{
  "summary": "Comprehensive overview (4-5 sentences) with scholarly insights",
  "interpretation": "[COMPLETE exposition as structured above]",
  "context": "[COMPLETE context as structured above]",
  "relatedVerses": ["5-8 verses with 2-3 sentence explanations"],
  "reflectionQuestions": ["6-8 deep questions + 1 journaling prompt"],
  "prayerPoints": ["Comprehensive prayer (7-9 sentences)"],
  "summaryInsights": ["4-5 profound themes (12-18 words each)"],
  "interpretationInsights": ["4-5 theological insights (12-18 words each)"],
  "reflectionAnswers": ["4-5 transformative applications (12-18 words each)"],
  "contextQuestion": "Nuanced yes/no question",
  "summaryQuestion": "Thoughtful question (10-15 words)",
  "relatedVersesQuestion": "Cross-reference question (10-15 words)",
  "reflectionQuestion": "Deep application question (10-15 words)",
  "prayerQuestion": "Contemplative question (8-12 words)"
}

${createPrayerFormatBlock(languageConfig, params.language, '7-9')}

FINAL VERIFICATION:
✓ Is "interpretation" 1500-2000 words with 6-8 paragraphs + word studies + doctrinal implications?
✓ Is "context" 800-1000 words with historical + literary + cross-references?
✓ Are ALL paragraphs 5-7 sentences (not 1-2 sentences)?
✓ Would this realistically take 25 minutes to study?
IF ANY ANSWER IS "NO" - EXPAND SUBSTANTIALLY.

OUTPUT: Valid JSON starting with { and ending with }`

  return { systemMessage, userMessage }
}

/**
 * LECTIO DIVINA MODE (15 minutes)
 * Contemplative meditative study
 */
function createLectioDivinaPrompt(params: LLMGenerationParams, languageConfig: LanguageConfig): PromptPair {
  const { inputType, inputValue, topicDescription } = params

  const taskDescription = inputType === 'scripture'
    ? `Create a Lectio Divina meditation guide for: "${inputValue}"`
    : inputType === 'topic'
    ? `Create a Lectio Divina meditation guide on: "${inputValue}"${topicDescription ? `\\n\\nContext: ${topicDescription}` : ''}`
    : `Create a Lectio Divina meditation guide for: "${inputValue}"`

  const systemMessage = `You are a spiritual director guiding Lectio Divina (sacred reading).

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, params.language)}

STUDY MODE: LECTIO DIVINA (15 minutes)
Four movements: LECTIO (read) → MEDITATIO (meditate) → ORATIO (pray) → CONTEMPLATIO (rest).
Tone: Contemplative, gentle, inviting, spiritually nurturing. Focus on personal encounter with God through Scripture.`

  const userMessage = `${taskDescription}

${createVerseReferenceBlock(params.language)}

═══════════════════════════════════════════════════════════════════════════
LECTIO DIVINA STRUCTURE - ALL 14 FIELDS MANDATORY
═══════════════════════════════════════════════════════════════════════════

{
  "summary": "**Scripture for Meditation**\\n\\n[Reference]\\n\\n[FULL passage text]\\n\\n*Read slowly 2-3 times, letting words wash over you.*\\n\\n**Focus Words:** [5-7 significant words/phrases for meditation]",
  "interpretation": "**LECTIO (Read) & MEDITATIO (Meditate)**\\n\\nLECTIO: [Guidance for slow reading - NOT scripture text]\\n\\nMEDITATIO: [Guidance for pondering - NOT scripture text]\\n\\nNotice which word catches your attention. This is the Spirit inviting you to pause.",
  "context": "**About Lectio Divina**\\n\\nLectio Divina (divine reading) is an ancient Christian practice (3rd century). Moves from reading about God to encountering God. Four movements: Lectio, Meditatio, Oratio, Contemplatio. Approach with open heart, free from agenda.",
  "relatedVerses": ["3-5 related Bible verses in ${languageConfig.name}"],
  "reflectionQuestions": ["**ORATIO (Pray)** - Prayer starter responding to passage...", "What is God inviting you to?", "How might this shape your day?", "**CONTEMPLATIO (Rest)** - Sit in silence 2-3 minutes with God."],
  "prayerPoints": ["Gentle contemplative first-person prayer (3-4 sentences). Address God gently, close with Amen"],
  "summaryInsights": ["2-3 gentle resonance themes (8-12 words each)"],
  "interpretationInsights": ["2-3 contemplative insights (8-12 words each)"],
  "reflectionAnswers": ["2-3 gentle responses to God's invitation (8-12 words each)"],
  "contextQuestion": "Gentle yes/no question inviting personal reflection",
  "summaryQuestion": "Gentle question about what draws attention (8-12 words)",
  "relatedVersesQuestion": "Question about which verse to meditate on (8-12 words)",
  "reflectionQuestion": "Contemplative question about God's invitation (8-12 words)",
  "prayerQuestion": "Gentle question encouraging prayer (6-10 words)"
}

${createPrayerFormatBlock(languageConfig, params.language, '3-4')}

CRITICAL CONTENT REQUIREMENTS:
✓ "summary": ACTUAL SCRIPTURE TEXT formatted for slow reading + 5-7 focus words at end
✓ "interpretation": GUIDANCE for LECTIO/MEDITATIO (not scripture - that's in summary)
✓ Both fields MANDATORY - serve different purposes
✓ Use meditative, gentle, inviting language throughout

VERIFICATION:
✓ Does "summary" include full scripture text?
✓ Does "summary" end with 5-7 focus words list?
✓ Does "interpretation" provide meditation guidance (not scripture)?
✓ Are all 14 fields present?
✓ Is prayer 3-4 sentences with correct closing?

OUTPUT: Valid JSON starting with { and ending with }`

  return { systemMessage, userMessage }
}

/**
 * SERMON OUTLINE MODE (50-60 minutes)
 * Complete preachable sermon outline
 */

// Sermon headings by language
const SERMON_HEADINGS: Record<string, Record<string, string>> = {
  'en': {
    openingPrayer: 'Opening Prayer & Welcome',
    introduction: 'Introduction / Hook',
    point: 'Point',
    mainTeaching: 'Main Teaching',
    scriptureFoundation: 'Scripture Foundation',
    illustration: 'Illustration',
    application: 'Application',
    transition: 'Transition',
    conclusion: 'Conclusion',
    gospelRecap: 'Gospel Recap',
    theInvitation: 'The Invitation',
    responseOptions: 'Response Options',
    closingPrayer: 'Closing Prayer'
  },
  'hi': {
    openingPrayer: 'प्रार्थना और स्वागत',
    introduction: 'प्रस्तावना',
    point: 'मुख्य बिंदु',
    mainTeaching: 'मुख्य शिक्षा',
    scriptureFoundation: 'पवित्रशास्त्र आधार',
    illustration: 'उदाहरण',
    application: 'व्यावहारिक उपयोग',
    transition: 'संक्रमण',
    conclusion: 'निष्कर्ष',
    gospelRecap: 'सुसमाचार सारांश',
    theInvitation: 'निमंत्रण',
    responseOptions: 'प्रतिक्रिया विकल्प',
    closingPrayer: 'समापन प्रार्थना'
  },
  'ml': {
    openingPrayer: 'പ്രാർത്ഥനയും സ്വാഗതവും',
    introduction: 'ആമുഖം',
    point: 'പ്രധാന പോയിന്റ്',
    mainTeaching: 'പ്രധാന പഠനം',
    scriptureFoundation: 'തിരുവെഴുത്ത് അടിസ്ഥാനം',
    illustration: 'ഉദാഹരണം',
    application: 'പ്രയോഗം',
    transition: 'പരിവർത്തനം',
    conclusion: 'നിഗമനം',
    gospelRecap: 'സുവിശേഷ സംഗ്രഹം',
    theInvitation: 'ക്ഷണം',
    responseOptions: 'പ്രതികരണ ഓപ്ഷനുകൾ',
    closingPrayer: 'സമാപന പ്രാർത്ഥന'
  }
}

function getSermonHeadings(language: string): Record<string, string> {
  return SERMON_HEADINGS[language] || SERMON_HEADINGS['en']
}

function createSermonOutlinePrompt(params: LLMGenerationParams, languageConfig: LanguageConfig): PromptPair {
  const { inputType, inputValue, topicDescription } = params
  const headings = getSermonHeadings(params.language)

  const sermonFormat = inputType === 'scripture' ? 'EXPOSITORY' : 'TOPICAL (3-Point)'

  const taskDescription = inputType === 'scripture'
    ? `Create an ${sermonFormat} sermon outline for: "${inputValue}"`
    : inputType === 'topic'
    ? `Create a ${sermonFormat} sermon outline on: "${inputValue}"${topicDescription ? `\\n\\nContext: ${topicDescription}` : ''}`
    : `Create a sermon outline addressing: "${inputValue}"`

  const systemMessage = `You are an experienced preacher creating sermon outlines for pastors.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, params.language)}

STUDY MODE: SERMON OUTLINE (50-60 minutes)
Complete preachable outline with timing, illustrations, altar call.
Tone: Clear, engaging, suitable for oral delivery.`

  // Build sermon outline template
  const outlineTemplate = `**SERMON OUTLINE FORMAT** - Detailed preacher's notes (NOT full speech):

## ${headings.introduction} (5 min)
• Hook: [Compelling attention-grabber - story, question, or statistic that draws people in]
• Bridge: [Connect the hook to today's scripture/topic - explain why this matters to their lives]
• Preview: [Brief overview of the 3 main points they'll hear today]
**${headings.transition}:** [Clear bridge sentence connecting introduction to Point 1]

## ${headings.point} 1: [Clear, Memorable Title] (15 min)

**${headings.mainTeaching}:**
[Write 2-3 cohesive paragraphs (8-12 sentences total) explaining the main theological teaching. Start with the foundational truth and define key terms. Build the explanation progressively, showing biblical basis and connecting to the redemptive story of Christ. Address common misconceptions and provide orthodox teaching. Deepen understanding by connecting to systematic theology. Make it substantial enough for the preacher to teach from for several minutes.]

**${headings.scriptureFoundation}:**
• [Bible Reference 1] - [Provide context: who wrote, to whom, when, why. Explain original meaning in 2-3 sentences. Show how it supports this point in 1-2 sentences.]
• [Bible Reference 2] - [Explain the verse's context and meaning. Show word studies or Greek/Hebrew insights if helpful. Connect to point in 3-4 sentences total.]
• [Bible Reference 3] - [Cross-reference showing same truth elsewhere in Scripture. Explain context and application. 3-4 sentences.]

**${headings.illustration}:**
• Setup: [Describe the illustration setting - who, what, when, where. 2-3 sentences.]
• Key Details: [Walk through the illustration step-by-step. Make it vivid and relatable. 3-4 sentences.]
• The Point: [Connect illustration directly to the theological truth being taught. 1-2 sentences.]
• Emotional Impact: [Help them feel the weight of this truth. What does it mean for their lives? 1-2 sentences.]

**${headings.application}:**
• [Specific action step #1 - Not just "pray more" but HOW to pray, WHEN to pray, WHAT to pray about. 2-3 sentences with practical details.]
• [Specific action step #2 - Concrete behavior change. Give examples of what this looks like in daily life. 2-3 sentences.]
• [Specific action step #3 - Relational application. How does this change how we treat others? Specific scenarios. 2-3 sentences.]
• [Heart-level application - Internal transformation. How should this change their thinking/desires/affections? 2-3 sentences.]

**${headings.transition}:** [Clear, compelling bridge sentence showing how Point 1 leads naturally to Point 2]

## ${headings.point} 2: [Clear, Memorable Title] (15 min)
[Use SAME DETAILED STRUCTURE as Point 1 above - Main Teaching as 2-3 paragraphs (8-12 sentences), 3-5 Scripture Foundation verses with full explanations, detailed Illustration outline, 3-5 specific Application points]

## ${headings.point} 3: [Clear, Memorable Title] (12 min)
[Use SAME DETAILED STRUCTURE as Point 1 above - Main Teaching as 2-3 paragraphs (8-12 sentences), 3-5 Scripture Foundation verses with full explanations, detailed Illustration outline, 3-5 specific Application points]

## ${headings.conclusion} (5 min)
• [Summary of Point 1 - Restate main truth with fresh language]
• [Summary of Point 2 - Connect to Point 1, build momentum]
• [Summary of Point 3 - Bring all points together in gospel clarity]
• [Final exhortation - Compelling call to respond. Make it urgent and gracious. 2-3 sentences.]`

  // Build altar call template
  const altarCallTemplate = `**ALTAR CALL / INVITATION** (4-6 min)

**${headings.gospelRecap}:**
[Brief gospel reminder]

**${headings.theInvitation}:**
If you feel God calling you to [specific response], I invite you to respond...

**${headings.responseOptions}:**
• Come forward for prayer
• Raise your hand
• Meet with pastor after service

**${headings.closingPrayer}:**
[Prayer for those responding]

Amen.`

  const userMessage = `${taskDescription}

${createVerseReferenceBlock(params.language)}

═══════════════════════════════════════════════════════════════════════════
SERMON STRUCTURE - ALL 14 FIELDS MANDATORY
═══════════════════════════════════════════════════════════════════════════

TIMING BREAKDOWN (50-60 minutes total):
Introduction: 5 min | Point 1: 15 min | Point 2: 15 min | Point 3: 12 min | Conclusion: 5 min | Altar Call: 4-6 min

{
  "summary": "Sermon thesis and hook (3-4 sentences)",
  "interpretation": "[Complete sermon outline following template above]",
  "context": "Background for preparation (2-3 paragraphs) - historical/cultural/textual context",
  "relatedVerses": ["5-7 additional supporting verses in ${languageConfig.name}"],
  "reflectionQuestions": ["5-7 discussion questions for small groups"],
  "prayerPoints": ["[Complete altar call following template above]"],
  "summaryInsights": ["3-4 key takeaways (10-15 words each)"],
  "interpretationInsights": ["3-4 main theological points (10-15 words each)"],
  "reflectionAnswers": ["3-4 practical applications (10-15 words each)"],
  "contextQuestion": "Yes/no connecting biblical context to modern life",
  "summaryQuestion": "Question about sermon thesis (8-12 words)",
  "relatedVersesQuestion": "Question encouraging scripture study (8-12 words)",
  "reflectionQuestion": "Application question (8-12 words)",
  "prayerQuestion": "Question inviting commitment (6-10 words)"
}

CRITICAL: USE EXACT HEADINGS (DO NOT TRANSLATE):
✓ "${headings.introduction}"
✓ "${headings.point}"
✓ "${headings.mainTeaching}"
✓ "${headings.scriptureFoundation}"
✓ "${headings.illustration}"
✓ "${headings.application}"
✓ "${headings.transition}"
✓ "${headings.conclusion}"

ALTAR CALL HEADINGS:
✓ "${headings.gospelRecap}"
✓ "${headings.theInvitation}"
✓ "${headings.responseOptions}"
✓ "${headings.closingPrayer}"

FORMAT REQUIREMENTS (DETAILED PREACHER'S OUTLINE):
✓ OUTLINE format with bullet points for most sections - EXCEPT Main Teaching which is paragraphs
✓ Main Teaching: 2-3 cohesive PARAGRAPHS (8-12 sentences total) - NOT bullet points
✓ Scripture Foundation: 3-5 verses PER POINT with DETAILED explanations (3-4 sentences per verse explaining context, meaning, application)
✓ Illustration: DETAILED outline of illustration (5-7 sentences: setup, key details, connection to point, emotional impact)
✓ Application: 3-5 specific, practical application points (2-3 sentences each showing HOW to apply)
✓ Transitions: ONE clear sentence bridging to next section
✓ REMEMBER: This outline must support 50-60 minutes of preaching - provide SUBSTANTIAL content

SERMON FORMAT:
${inputType === 'scripture' ? `
EXPOSITORY: Verse-by-verse exposition
• Break down passage systematically
• Explain original meaning + modern application
• Structure around textual flow` : `
TOPICAL: 3-point sermon
• Develop 3 main points around theme
• Support each with multiple scriptures
• Logical progression of ideas`}

ALTAR CALL REQUIREMENTS:
✓ "prayerPoints" contains COMPLETE altar call template
✓ Gospel recap (1-2 sentences)
✓ Clear invitation with specific response
✓ Multiple response options
✓ Closing prayer for respondents
✓ End with Amen
✓ ENTIRE altar call in ${languageConfig.name}

${createPrayerFormatBlock(languageConfig, params.language, 'varies')}

VERIFICATION:
✓ Is "interpretation" an OUTLINE (not full speech)?
✓ Are headings EXACT matches (not English)?
✓ Does each Main Teaching section have 2-3 cohesive PARAGRAPHS (8-12 sentences)?
✓ Does each point have Scripture Foundation subsection with DETAILED verse explanations (3-4 sentences per verse)?
✓ Does each Illustration have detailed outline (5-7 sentences)?
✓ Does each Application have 3-5 specific practical points?
✓ Is there ENOUGH detail to support 50-60 minutes of preaching?
✓ Does "prayerPoints" contain complete altar call?
✓ Does timing total 50-60 minutes?
✓ Are all 14 fields present?

OUTPUT: Valid JSON starting with { and ending with }`

  return { systemMessage, userMessage }
}

/**
 * Main prompt router - dispatches to appropriate mode
 */
export function createStudyGuidePrompt(params: LLMGenerationParams, languageConfig: LanguageConfig): PromptPair {
  const studyMode = params.studyMode || 'standard'

  switch (studyMode) {
    case 'quick':
      return createQuickReadPrompt(params, languageConfig)
    case 'deep':
      return createDeepDivePrompt(params, languageConfig)
    case 'lectio':
      return createLectioDivinaPrompt(params, languageConfig)
    case 'sermon':
      return createSermonOutlinePrompt(params, languageConfig)
    case 'standard':
    default:
      return createStandardModePrompt(params, languageConfig)
  }
}

// ============================================================================
// DAILY VERSE GENERATION FUNCTIONS
// ============================================================================

/**
 * Creates prompt for generating a daily verse reference only.
 * Used by daily verse notification system.
 */
export function createVerseReferencePrompt(
  excludeReferences: string[],
  language: string
): PromptPair {
  const excludeList = excludeReferences.length > 0
    ? `\n\nEXCLUDE these recently used references:\n${excludeReferences.map(ref => `- ${ref}`).join('\n')}`
    : ''

  const languageInstructions = language === 'hi'
    ? 'Hindi translations MUST use Devanagari script (e.g., "यूहन्ना 3:16" NOT "Yuhanna 3:16")'
    : language === 'ml'
    ? 'Malayalam translations MUST use Malayalam script (e.g., "യോഹന്നാൻ 3:16" NOT "Yohannan 3:16")'
    : 'English translations should use standard book names'

  const systemMessage = `
${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

═══════════════════════════════════════════════════════════════════════════
DAILY VERSE REFERENCE SELECTION - SPECIFIC REQUIREMENTS
═══════════════════════════════════════════════════════════════════════════

TASK: Select ONE meaningful, encouraging Bible verse reference for daily inspiration.

SELECTION CRITERIA:
✓ Choose verses that are encouraging, uplifting, or practically applicable to daily life
✓ Prefer well-known verses that resonate across denominations
✓ Avoid overly complex theological passages or obscure references
✓ Ensure the verse can stand alone without extensive context
✓ Do NOT repeat any of the excluded references provided${excludeList}

LANGUAGE REQUIREMENTS:
${languageInstructions}
${getVerseReferenceExamples(language)}

OUTPUT FORMAT (strict JSON):
{
  "reference": "English reference (e.g., John 3:16)",
  "referenceTranslations": {
    "en": "English format",
    "hi": "हिंदी प्रारूप (Devanagari only)",
    "ml": "മലയാളം ഫോർമാറ്റ് (Malayalam script only)"
  }
}

VALIDATION CHECKLIST:
✓ Is the JSON properly formatted (no markdown blocks)?
✓ Are all three language translations provided?
✓ Are Hindi and Malayalam in native scripts (NOT romanized)?
✓ Is the verse reference valid and complete?
✓ Does the verse avoid recently used references?
`.trim()

  const userMessage = 'Select an encouraging Bible verse reference for today\'s daily inspiration. Output only valid JSON.'

  return { systemMessage, userMessage }
}

/**
 * Creates prompt for generating a complete daily verse with full text.
 * Used as fallback when Bible API fails.
 */
export function createFullVersePrompt(
  excludeReferences: string[],
  language: string
): PromptPair {
  const excludeList = excludeReferences.length > 0
    ? `\n\nEXCLUDE these recently used references:\n${excludeReferences.map(ref => `- ${ref}`).join('\n')}`
    : ''

  const languageInstructions = language === 'hi'
    ? `
Hindi Requirements:
✓ Reference: "यूहन्ना 3:16" (Devanagari script)
✓ Verse text: Must be in Devanagari script
✗ NO romanized Hinglish (e.g., "Yeshu" → use "येशु")
`
    : language === 'ml'
    ? `
Malayalam Requirements:
✓ Reference: "യോഹന്നാൻ 3:16" (Malayalam script)
✓ Verse text: Must be in Malayalam script
✗ NO romanized Manglish (e.g., "Yeshu" → use "യേശു")
`
    : `
English Requirements:
✓ Use clear, accessible English
✓ Standard Bible translations (NIV, ESV style)
`

  const systemMessage = `
${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

═══════════════════════════════════════════════════════════════════════════
DAILY VERSE GENERATION - COMPLETE TEXT
═══════════════════════════════════════════════════════════════════════════

TASK: Generate ONE complete Bible verse with reference and full text in all three languages.

SELECTION CRITERIA:
✓ Choose verses that are encouraging, uplifting, or practically applicable
✓ Prefer well-known verses (John 3:16, Philippians 4:13, Romans 8:28, Proverbs 3:5-6, etc.)
✓ Ensure verse is meaningful when read alone without additional context
✓ Do NOT repeat any of the excluded references provided${excludeList}

TRANSLATION ACCURACY:
✓ English: Use standard Bible translation style (NIV/ESV equivalent)
✓ Hindi: Accurate Devanagari translation from standard Hindi Bibles
✓ Malayalam: Accurate Malayalam script translation from standard Malayalam Bibles
✓ Maintain theological accuracy across all languages

LANGUAGE REQUIREMENTS:
${languageInstructions}
${getVerseReferenceExamples(language)}

OUTPUT FORMAT (strict JSON):
{
  "reference": "English reference (e.g., John 3:16)",
  "referenceTranslations": {
    "en": "English format (John 3:16)",
    "hi": "हिंदी प्रारूप (यूहन्ना 3:16)",
    "ml": "മലയാളം ഫോർമാറ്റ് (യോഹന്നാൻ 3:16)"
  },
  "translations": {
    "en": "For God so loved the world that he gave his one and only Son...",
    "hi": "क्योंकि परमेश्वर ने जगत से ऐसा प्रेम रखा कि उसने अपना एकलौता पुत्र दे दिया...",
    "ml": "ദൈവം ലോകത്തെ ഇത്രമേൽ സ്നേഹിച്ചു, താൻ തന്റെ ഏകജാതനായ പുത്രനെ നൽകുവാൻ..."
  }
}

VALIDATION CHECKLIST:
✓ Is the JSON properly formatted (no markdown blocks)?
✓ Are reference translations in native scripts?
✓ Are verse translations in native scripts?
✓ Is the verse text accurate and meaningful?
✓ Does it avoid recently used references?
`.trim()

  const userMessage = 'Generate a complete daily Bible verse with full text in all three languages. Output only valid JSON.'

  return { systemMessage, userMessage }
}

// ============================================================================
// HELPER FUNCTIONS (Preserved from original)
// ============================================================================

export function estimateContentComplexity(inputValue: string, inputType: string): number {
  const inputLength = inputValue.length

  if (inputType === 'scripture') {
    return inputLength < 20 ? 0 : 500
  } else {
    const complexityIndicators = [
      'theology', 'doctrine', 'hermeneutics', 'exegesis',
      'eschatology', 'soteriology', 'pneumatology'
    ]

    const hasComplexTerms = complexityIndicators.some(term =>
      inputValue.toLowerCase().includes(term)
    )

    if (hasComplexTerms || inputLength > 100) {
      return 1000
    } else if (inputLength > 50) {
      return 500
    } else {
      return 0
    }
  }
}

export function calculateOptimalTokens(params: LLMGenerationParams, languageConfig: LanguageConfig): number {
  const baseTokens = languageConfig.maxTokens
  const complexityFactor = estimateContentComplexity(params.inputValue, params.inputType)
  const contentQualityBonus = 1000

  return Math.min(baseTokens + complexityFactor + contentQualityBonus, 8000)
}

/**
 * Verse reference examples for each language
 */
export function getVerseReferenceExamples(language: string): string {
  const examples: Record<SupportedLanguage, string> = {
    en: '- Example format: "John 3:16", "Romans 8:28", "Philippians 4:13"',
    hi: '- उदाहरण प्रारूप: "यूहन्ना 3:16", "रोमियों 8:28", "फिलिप्पियों 4:13"\\n- पुस्तक नाम हिंदी में होने चाहिए',
    ml: '- ഉദാഹരണ ഫോർമാറ്റ്: "യോഹന്നാൻ 3:16", "റോമർ 8:28", "ഫിലിപ്പിയർ 4:13"\\n- പുസ്തക നാമങ്ങൾ മലയാളത്തിൽ'
  }

  return examples[language as SupportedLanguage] || examples.en
}
