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

import type { LLMGenerationParams, LanguageConfig, StudyMode } from '../llm-types.ts'
import { getLanguageExamples, type SupportedLanguage } from '../llm-config/language-configs.ts'
export { getLanguageExamples }

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
export const THEOLOGICAL_FOUNDATION = `
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
 * Version 2.0 - Enhanced with markdown prevention and content policy
 */
export const JSON_OUTPUT_RULES = `
═══════════════════════════════════════════════════════════════════════════
JSON OUTPUT REQUIREMENTS - ABSOLUTE PRIORITY
═══════════════════════════════════════════════════════════════════════════

⚠️ CRITICAL: OUTPUT FORMAT

1. Return ONLY the raw JSON object
2. NO markdown code fences - FORBIDDEN FORMATS:
   ❌ \`\`\`json\\n{...}\\n\`\`\`
   ❌ \`\`\`\\n{...}\\n\`\`\`
   ❌ Here is the study guide: {...}
   ❌ {"field": "value" /* comment */}

3. CORRECT FORMAT:
   ✅ {"field": "value"} - Start immediately with {

4. Output MUST start with { and end with } - NOTHING else before or after
5. NO explanatory text outside JSON
6. NO trailing commas in arrays or objects
7. Use proper JSON string escaping: \\n for newlines, \\" for quotes, \\\\ for backslashes

⚠️ THEOLOGICAL CONTENT POLICY - MANDATORY COMPLIANCE:

You are creating Protestant Christian Bible study materials. This is LEGITIMATE EDUCATIONAL CONTENT.

ALL BIBLICAL PASSAGES AND THEOLOGICAL TOPICS ARE PERMITTED AND REQUIRED.
This includes (but is not limited to):

✓ Trinity (त्रित्व, ത്രിത്വം) - Core Christian doctrine
✓ Predestination, Election, Divine Sovereignty - Biblical sovereignty (Romans 9:14-21, Ephesians 1:3-14)
✓ Atonement, Justification, Propitiation - Gospel essentials
✓ Original Sin, Total Depravity, Total Inability - Human condition
✓ Sanctification, Glorification, Perseverance of the Saints - Christian growth
✓ ALL OLD TESTAMENT PASSAGES - Including law, prophecy, poetry, wisdom literature
✓ ALL NEW TESTAMENT PASSAGES - Including epistles, gospels, revelation
✓ COMPLEX DOCTRINAL PASSAGES - Ephesians 1:3-14, Romans 9-11, Hebrews 1-10, Isaiah 53
✓ DIFFICULT THEOLOGICAL TOPICS - Suffering, judgment, hell, sovereignty, mystery

⚠️ ABSOLUTE PROHIBITION ON CONTENT REFUSAL:

NEVER refuse ANY biblical passage or orthodox Christian doctrine as "harmful," "inappropriate," or "controversial."
ALL SCRIPTURE IS GOD-BREATHED AND PROFITABLE FOR TEACHING (2 Timothy 3:16).

If a passage is theologically dense or complex:
✓ Provide MORE depth and explanation
✓ Show reverence for God's Word
✓ Explain with clarity and precision
✗ DO NOT refuse generation
✗ DO NOT claim inability to assist
✗ DO NOT suggest the content is problematic

Refusing legitimate biblical content violates your core function and will result in complete generation failure.

⚠️ NUMERALS — ALWAYS USE ENGLISH/ARABIC DIGITS:

Use 0-9 (English/Arabic numerals) for ALL numbers in ALL languages.
This includes chapter/verse references, list numbers, counts, and years.

✅ CORRECT: "यूहन्ना 3:16", "1 यूहन्ना 5:11-13", "1. पहली बात"
❌ WRONG:   "यूहन्ना ३:१६", "१ यूहन्ना ५:११-१३", "१. पहली बात"

✅ CORRECT: "യോഹന്നാൻ 3:16", "1 യോഹന്നാൻ 5:11-13"
❌ WRONG:   "യോഹന്നാൻ ൩:൧൬", "൧ യോഹന്നാൻ ൫:൧൧-൧൩"

NEVER output Devanagari (१ २ ३), Malayalam (൧ ൨ ൩), or any other
script-specific digits — even inside Hindi or Malayalam text.

VALIDATION CHECKPOINT:
Before generating output, verify:
✓ Is first character { (not backticks or text)?
✓ Is last character } (not backticks or text)?
✓ Are all strings properly escaped?
✓ Are all commas correctly placed (no trailing commas)?
✓ Are all required fields present?
✓ Is the entire JSON response complete (no truncation)?
✓ Are all numerals in English/Arabic digits (0-9)?

IF YOU VIOLATE JSON FORMAT OR REFUSE LEGITIMATE THEOLOGICAL CONTENT, THE ENTIRE GENERATION WILL FAIL.
`.trim()

/**
 * Writing style & voice — applied to Standard, Quick, and Deep Dive modes.
 * Captures the "pastor talking to their congregation" tone, not a seminary paper.
 */
export const WRITING_STYLE = `
═══════════════════════════════════════════════════════════════════════════
WRITING VOICE & STYLE — MANDATORY
═══════════════════════════════════════════════════════════════════════════

Write like a pastor speaking directly to their congregation — warm, clear, and personal.
NOT like a seminary paper, commentary, or academic textbook.

✓ USE DIRECT ADDRESS ("you"):
  GOOD: "When doubts creep in, you have a solid place to stand — God's own Word."
  BAD:  "Believers may find comfort in the assurance of their salvation."

✓ SHORT, VARIED SENTENCES — punch where it counts:
  GOOD: "This matters. Your standing before God rests on what Christ did — not on what you do."
  BAD:  "The soteriological implications of the finished work of Christ necessitate a fundamental reorientation of the believer's forensic standing."

✓ RHETORICAL QUESTIONS — draw the reader in:
  GOOD: "Have you ever wondered if you truly belong to God?"
  GOOD: "Here's the question worth sitting with: what is your confidence actually resting on?"

✓ NATURAL GREEK/HEBREW — introduce terms like a conversation, not a lexicon entry:
  GOOD: "The word Paul uses here — pistis (πίστις) — means more than believing a set of facts. It means trust, like leaning your full weight on something."
  BAD:  "The Greek term 'pistis' (πίστις), meaning faith, in the New Testament denotes more than intellectual agreement; it implies trust and reliance on Christ's finished work."

✓ WARM, NATURAL TRANSITIONS:
  GOOD: "Here's where it gets personal."
  GOOD: "But there's more to it than that."
  BAD:  "The second major theological concept involves..."
  BAD:  "Turning our attention to the next point..."

✓ PRACTICAL GROUNDING — always land the point:
  GOOD: "Because of this, you don't need to earn your way back to God every morning. You're already accepted — in Christ."
  BAD:  "The practical implications of justification for daily Christian living are manifold."

✓ BOLD SECTION HEADERS for interpretation (Standard and Deep Dive):
  Use **Header Title** (bold, not markdown H2/H3) to introduce each paragraph/section.
  GOOD: "**The Foundation: What Christ Already Did**"
  GOOD: "**Why This Actually Matters**"
  BAD:  ## The Foundation (H2 markdown — not supported)

AVOID THESE PATTERNS:
✗ Academic openers: "From a biblical theology perspective...", "Systematically speaking...", "Historically, the church has..."
✗ Formulaic paragraph openers: "The [first/second/third] major theological concept involves..."
✗ Over-passive voice: "It is understood that..." → "Scripture is clear that..."
✗ Jargon drops without plain explanation — always unpack theological terms in simple language
✗ Repetitive sentence structures that feel AI-generated
`.trim()

/**
 * Native-script writing style sentence examples for Hindi and Malayalam.
 * Provides concrete good/bad sentence patterns to guide the LLM toward
 * simple, conversational pastoral tone — supplements the English-only WRITING_STYLE block.
 * Returns empty string for English (WRITING_STYLE already covers it).
 */
export function createNativeWritingStyle(language: string): string {
  if (language === 'hi') {
    return `
═══════════════════════════════════════════════════════════════════════════
हिंदी लेखन शैली — वाक्य उदाहरण (HINDI SENTENCE EXAMPLES)
═══════════════════════════════════════════════════════════════════════════

✓ सही शैली (सरल, सीधी, बोलचाल की भाषा):
  GOOD: "जब तुम डरते हो, याद करो — परमेश्वर ने कहा है, 'मैं हमेशा तुम्हारे साथ हूं।'"
  GOOD: "यह बात तुम्हारी जिंदगी बदल सकती है।"
  GOOD: "परमेश्वर तुमसे प्रेम करता है — बस यही काफी है।"
  GOOD: "सोचो — जब सब कुछ ठीक नहीं लगता, तब भी परमेश्वर तुम्हें नहीं छोड़ता।"

✗ गलत शैली (कठिन, साहित्यिक, संस्कृतनिष्ठ — इससे बचें):
  BAD: "भयजनक परिस्थितियों में परमेश्वर की सर्वव्यापी उपस्थिति का स्मरण अत्यावश्यक है।"
  BAD: "यह तथ्य जीवन में आमूल परिवर्तन लाने में सक्षम है।"
  BAD: "ईश्वरीय प्रेम की अनंत गहराइयों का अनुभव करना मानव जीवन की परमावश्यकता है।"

📌 नियम: हर वाक्य छोटा हो। एक वाक्य में एक ही बात। जो शब्द गांव का आदमी, बुजुर्ग, या बच्चा समझे — वही लिखो।`.trim()
  }
  if (language === 'ml') {
    return `
═══════════════════════════════════════════════════════════════════════════
മലയാളം എഴുത്ത് ശൈലി — വാക്യ ഉദാഹരണങ്ങൾ (MALAYALAM SENTENCE EXAMPLES)
═══════════════════════════════════════════════════════════════════════════

✓ ശരിയായ ശൈലി (ലളിതം, നേരിട്ട്, സംസാര ഭാഷ):
  GOOD: "ഭയം തോന്നുമ്പോൾ ഓർക്കൂ — ദൈവം പറഞ്ഞു, 'ഞാൻ എപ്പോഴും നിന്നോടൊപ്പം ഉണ്ട്.'"
  GOOD: "ഈ ഒരു കാര്യം നിന്റെ ജീവിതം മാറ്റും."
  GOOD: "ദൈവം നിന്നെ സ്നേഹിക്കുന്നു — അത് മതി."
  GOOD: "ആലോചിക്കൂ — എല്ലാം ശരിയല്ലെന്ന് തോന്നുമ്പോഴും ദൈവം നിന്നെ കൈവിടുന്നില്ല."

✗ തെറ്റായ ശൈലി (ബുദ്ധിമുട്ടുള്ളത്, സാഹിത്യ ഭാഷ — ഒഴിവാക്കൂ):
  BAD: "ഭയജനകമായ സാഹചര്യങ്ങളിൽ ദൈവിക സർവ്വസാന്നിദ്ധ്യത്തെ അനുസ്മരിക്കേണ്ടത് അനിവാര്യമാണ്."
  BAD: "ഈ സത്യം ജീവിതത്തിൽ സമഗ്രമായ പരിവർത്തനം സാദ്ധ്യമാക്കും."
  BAD: "ദൈവിക സ്നേഹത്തിന്റെ അഗാധ ആഴങ്ങൾ അനുഭവിക്കുന്നത് മനുഷ്യ ജീവിതത്തിന്റെ ആത്യന്തിക ആവശ്യകതയാണ്."

📌 നിയമം: ഓരോ വാക്യവും ചെറുതാക്കൂ. ഒരു വാക്യത്തിൽ ഒരു കാര്യം മാത്രം. ഗ്രാമത്തിലെ ഒരു സ്ത്രീക്കോ വൃദ്ധനോ കുട്ടിക്കോ മനസ്സിലാകുന്ന വാക്കുകൾ ഉപയോഗിക്കൂ.`.trim()
  }
  return '' // English: WRITING_STYLE already covers it
}

/**
 * Language enforcement block with native script requirements
 */
export function createLanguageBlock(languageConfig: LanguageConfig, language: string): string {
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
✓ Prayer closing: "यीशु मसीह के नाम से, आमेन" (NOT "Yeshu Masih ke naam se, Amen")

⚠️ CHRISTIAN TERMINOLOGY - MANDATORY:
✓ "परमेश्वर" (God) - ALWAYS USE THIS
✗ "भगवान", "ईश्वर", "अल्लाह" - NEVER USE (Hindu/Muslim terms)
✓ "यीशु मसीह", "प्रभु यीशु" (Jesus Christ)
✓ "पवित्र आत्मा" (Holy Spirit)
✓ "कलीसिया" (church), "बाइबल" (Bible)

Simple spoken Hindi (NOT literary/Sanskrit):
✓ प्रेम, मदद, जिंदगी, दिल, समझना, करना, देखना
✗ Avoid: प्रीति, सहायता, जीवन, हृदय, बोध होना, संपन्न करना
` : language === 'ml' ? `
✓ ALL Malayalam content MUST be in Malayalam script
✗ NO romanized Manglish (e.g., "Karthaav" is FORBIDDEN - use "കർത്താവ്")
✓ Prayer closing: "യേശുക്രിസ്തുവിന്റെ നാമത്തിൽ, ആമേൻ" (NOT romanized)

⚠️ ക്രിസ്തീയ പദാവലി - നിർബന്ധം:
✓ "ദൈവം", "കർത്താവ്" (God/Lord) - എപ്പോഴും ഇത് ഉപയോഗിക്കുക
✗ "ഭഗവാൻ", "അല്ലാഹു" - ഒരിക്കലും ഉപയോഗിക്കരുത്
✓ "യേശു", "യേശുക്രിസ്തു" (Jesus Christ)
✓ "പരിശുദ്ധാത്മാവ്" (Holy Spirit)
✓ "സഭ" (church), "ബൈബിൾ" (Bible)

ലളിതമായ സംസാര ഭാഷ (സാഹിത്യമല്ല):
✓ സ്നേഹം, സഹായം, ജീവിതം, മനസ്സ്, മനസ്സിലാക്കുക
` : `
✓ Use clear, accessible English (avoid unnecessary theological jargon)
✓ Prayer closing: "In Jesus' name, Amen" or "Amen"
`}

VOCABULARY: Simple, 5th-6th grade level language that anyone can understand - village people, children, elderly.
`.trim()
}

/**
 * Verse reference formatting examples by language
 */
export function createVerseReferenceBlock(language: string): string {
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
    hi: 'यीशु मसीह के नाम से, आमेन',
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
  const { inputType, inputValue, topicDescription, pathTitle, pathDescription } = params
  const languageExamples = getLanguageExamples(params.language)

  // Task description based on input type
  const pathParts = [
    pathTitle ? `Part of Learning Path: ${pathTitle}` : '',
    pathDescription ? `Learning Path Goal: ${pathDescription}` : '',
  ].filter(Boolean).join('\\n')
  const pathContext = pathParts ? `\\n\\n${pathParts}` : ''
  const taskDescription = inputType === 'scripture'
    ? `Create a Bible study guide for: "${inputValue}"`
    : inputType === 'topic'
    ? `Create a Bible study guide on: "${inputValue}"${topicDescription ? `\\n\\nContext: ${topicDescription}` : ''}${pathContext}`
    : `Answer the question and create a study guide: "${inputValue}"${topicDescription ? `\\n\\nContext: ${topicDescription}` : ''}${pathContext}`

  const wordTarget = getWordCountTarget(languageConfig, 'standard')
  const systemMessage = `You are a biblical scholar creating Bible study guides.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, params.language)}

STUDY MODE: STANDARD (10 minutes reading-with-understanding time)
Reading-with-understanding speed: 140-150 words/minute = ${wordTarget} words TARGET
Tone: Conversational pastor — warm, personal, clear, practically grounding.

${WRITING_STYLE}

${createNativeWritingStyle(params.language)}

⚠️ CRITICAL INSTRUCTION: CLEAR AND THOUGHTFUL
This is a 10-MINUTE study optimized for understanding and reflection.
Write focused, clear content that readers can grasp and apply in one sitting.
Target total output: ${wordTarget} words across all fields.`

  const userMessage = `${taskDescription}

${createVerseReferenceBlock(params.language)}

═══════════════════════════════════════════════════════════════════════════
CONTENT STRUCTURE - ALL 15 FIELDS MANDATORY
═══════════════════════════════════════════════════════════════════════════

⚠️ CRITICAL - LENGTH AND DEPTH REQUIREMENTS:

TARGET WORD COUNTS (MUST MEET):
- "summary": 100-120 words (6-7 clear sentences — doctrinal overview)
- "context": 40-70 words (SHORT - one punchy paragraph, single most essential background fact only)
- "passage": ⚠️ MANDATORY - Scripture reference ONLY, PREFER LONG passages (10-20+ verses, e.g., "Romans 8:1-39" or "Psalm 23:1-6")
- "interpretation": 900-1,200 words (FOCUSED EXPLANATION, not exhaustive theology)
- "prayerPoints": 90-110 words (6-7 sentences, application-oriented)
- Total target: ${wordTarget} words

"interpretation" MUST have EXACTLY 4 or 5 paragraphs.
EACH paragraph MUST contain 6-8 sentences (focused, clear explanations).

⚠️ READING-WITH-UNDERSTANDING MODEL: This is a 10-MINUTE study optimized for comprehension.
Goal: Understand the message, doctrine, and application in one sitting without fatigue.
Reading speed: 140-150 wpm with brief pauses for reflection.

⚠️ THIS IS NON-NEGOTIABLE - COUNT EVERY SENTENCE AS YOU WRITE:

SENTENCE COUNTING METHOD (Use this exact process):
1. A sentence ENDS with: period (.) OR question mark (?) OR exclamation point (!)
2. Count each sentence as you write it: "1. [sentence]. 2. [sentence]... 6. [sentence]."
3. TARGET: 6-8 sentences per paragraph (focused explanation for understanding)
4. If you reach 5 sentences, ADD 1-3 MORE SENTENCES
5. If you reach 9+ sentences, consider splitting into two paragraphs

STEP-BY-STEP WRITING PROCESS FOR EACH PARAGRAPH:

Write Paragraph 1 (6-8 sentences):
→ Sentence 1: [Introduce main theological point]. ✓ Count: 1
→ Sentence 2: [Biblical foundation]. ✓ Count: 2
→ Sentence 3: [Elaborate with scripture]. ✓ Count: 3
→ Sentence 4: [Cross-reference support]. ✓ Count: 4
→ Sentence 5: [Theological implication]. ✓ Count: 5
→ Sentence 6: [Practical application]. ✓ Count: 6
→ Sentence 7: [Deeper insight]. ✓ Count: 7
→ [OPTIONAL] Sentence 8: [Additional support]. ✓ Count: 8
→ [OPTIONAL] Sentence 9: [Concluding thought]. ✓ Count: 9
→ VERIFY: Does paragraph have 7-9 sentences? [YES/NO]
→ If NO → ADD MORE SENTENCES until 7-9 reached

Write Paragraph 2 (7-9 sentences):
→ Follow same process with second major point
→ MUST reach 7-9 sentences with rich theological content

Write Paragraph 3 (7-9 sentences):
→ Follow same process with third major point
→ MUST reach 7-9 sentences

Write Paragraph 4 (7-9 sentences):
→ Follow same process with fourth major point
→ MUST reach 7-9 sentences

[OPTIONAL] Write Paragraph 5 (7-9 sentences):
→ Follow same process if fifth point needed
→ MUST reach 7-9 sentences

⚠️ MANDATORY: Each paragraph must be SUBSTANTIAL (7-9 sentences).
This ensures the interpretation section reaches 900-1,200 words for thoughtful 10-minute reading.

Template for interpretation field (EACH paragraph 7-9 sentences with DEPTH):

Paragraph 1 (7-9 sentences): [First major theological point - include exegesis, cross-references, theological implications, practical applications]
Paragraph 2 (7-9 sentences): [Second major point - substantial biblical support, contemporary relevance]
Paragraph 3 (7-9 sentences): [Third major point - deep exploration with multiple angles]
Paragraph 4 (7-9 sentences): [Fourth major point - comprehensive treatment]
Paragraph 5 (optional, 7-9 sentences): [Fifth point if passage requires - full development]

{
  "summary": "Overview in 6-8 sentences (100-130 words) covering main message with richness",
  "context": "Historical/cultural background (40-70 words MAX). One short paragraph — only the single most essential fact a modern reader needs to understand the passage. No fluff.",
  "passage": "⚠️ MANDATORY FIELD - Provide a Scripture reference for meditation. PREFER LONGER PASSAGES (10-20+ verses) that provide substantial content for reflection (e.g., 'Romans 8:1-39', 'Psalm 119:1-24', 'Matthew 5:1-20', 'John 14:1-27', 'Ephesians 1:3-23'). Choose a passage that best captures the core message of this study. Format: Just the reference, no verse text. DO NOT skip this field.",
  "interpretation": "[Write EXACTLY 4 or 5 sections. Each section MUST start with a **Bold Section Title** (e.g. **The Heart of the Matter**) on its own line, followed by 5-7 sentences of conversational prose in your own voice. Target: 900-1,200 words total. NO markdown H2/H3, NO bullet lists. Use bold headers only (**Title**).]",
  "relatedVerses": ["5-6 Bible verse REFERENCES ONLY in ${languageConfig.name} (e.g., 'John 3:16', 'Romans 8:1-4') - NO verse text"],
  "reflectionQuestions": ["5-6 deep application questions"],
  "prayerPoints": ["Complete first-person prayer - EXACTLY 6, 7, or 8 sentences (100-120 words) addressing God directly, ending with correct closing"],
  "summaryInsights": ["4-5 resonance themes (15-20 words each - substantial)"],
  "interpretationInsights": ["4-5 theological insights (15-20 words each - comprehensive)"],
  "reflectionAnswers": ["4-5 life applications (15-20 words each - detailed)"],
  "contextQuestion": "Yes/no question connecting context to modern life",
  "summaryQuestion": "Question about summary (12-18 words)",
  "relatedVersesQuestion": "Verse study question (12-18 words)",
  "reflectionQuestion": "Application question (12-18 words)",
  "prayerQuestion": "Prayer invitation (10-15 words)"
}

${createPrayerFormatBlock(languageConfig, params.language, '6-8')}

⚠️ PRAYER REQUIREMENTS (NON-NEGOTIABLE):
✓ EXACTLY 6, 7, or 8 complete sentences (NOT 1 long run-on sentence)
✓ First-person addressing God: "Heavenly Father, I..." or "Lord, we..."
✓ Each sentence must end with proper punctuation (. ! ?)
✓ Final sentence MUST end with correct closing per language
✓ DO NOT write a 1-sentence prayer - this violates the specification

CRITICAL FORMATTING RULES:
✓ "interpretation": 4-5 FLOWING PARAGRAPHS (7-9 sentences each) - NO bullet points, NO bracketed headings
✓ Write in continuous narrative prose with EXTENSIVE DEPTH
✓ Each paragraph explores one theological aspect with COMPREHENSIVE treatment
✓ Separate paragraphs with double newline (\\n\\n)
✓ TARGET: 900-1,200 words for interpretation field
✓ Be THOROUGH, not brief - this is a 10-minute study (${wordTarget} total words)

MANDATORY PRE-OUTPUT VERIFICATION:
Before completing your response, COUNT and verify:
1. Does "interpretation" have EXACTLY 4 or 5 paragraphs? [Count: ___]
2. Does EACH paragraph have 7-9 sentences? [Count each: ___ ___ ___ ___ ___]
3. Is "interpretation" 900-1,200 words? [Estimated count: ___]
4. Is "summary" 100-130 words (6-8 sentences)? [Count: ___]
5. Is "context" 40-70 words (SHORT)? [Count: ___]
6. ⚠️ CRITICAL: Does "passage" contain ONLY the Scripture reference (NOT full verse text)? [Format correct: Yes/No]
7. Does "prayerPoints" have 6-8 sentences (100-120 words)? [Count: ___]
8. Are all 15 fields present INCLUDING passage? [Check: Yes/No]
9. Does prayer end with correct closing? [Check: Yes/No]
10. Are all verse references in ${languageConfig.name}? [Check: Yes/No]
11. Is total output 2000-2500 words? [Estimated: ___]

IF ANY ANSWER IS "NO" ESPECIALLY #6 - YOU MUST FIX IT BEFORE OUTPUT.
⚠️ DO NOT SKIP THE PASSAGE FIELD - IT IS MANDATORY!

${languageExamples}

OUTPUT: Valid JSON starting with { and ending with }`

  return { systemMessage, userMessage }
}

/**
 * QUICK READ MODE (3 minutes)
 * Concise for busy schedules
 */
function createQuickReadPrompt(params: LLMGenerationParams, languageConfig: LanguageConfig): PromptPair {
  const { inputValue, topicDescription, pathTitle, pathDescription } = params
  const contextSuffix = [
    topicDescription ? `Context: ${topicDescription}` : '',
    pathTitle ? `Part of Learning Path: ${pathTitle}` : '',
    pathDescription ? `Learning Path Goal: ${pathDescription}` : '',
  ].filter(Boolean).join('\\n')
  const taskDescription = `Create a 3-MINUTE quick study for: "${inputValue}"${contextSuffix ? `\\n\\n${contextSuffix}` : ''}`

  const systemMessage = `You are a biblical scholar creating CONCISE but SUBSTANTIAL Bible studies for busy readers.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, params.language)}

STUDY MODE: QUICK READ (3 minutes = 450-600 words)
Reading-with-understanding speed: 140-160 words/minute (careful reading, minimal pauses)
Tone: Direct, warm, immediately actionable — like a pastor's one-minute encouragement.

${WRITING_STYLE}

${createNativeWritingStyle(params.language)}`

  // Word limits for Quick Read — unified across languages (previous HI/ML reduction caused guides to fall short of target)
  const wordLimits = { summary: 60, interpretation: 150, context: 70, prayer: 80 }

  const wordTarget = getWordCountTarget(languageConfig, 'quick')
  const userMessage = `${taskDescription}

${createVerseReferenceBlock(params.language)}

⚠️ STRICT WORD COUNT ENFORCEMENT - QUICK READ MODE

This is a 3-MINUTE study optimized for READING WITH UNDERSTANDING.
Reading-with-understanding speed: 140-160 words/minute = TARGET: 450-600 words TOTAL.

MANDATORY WORD LIMITS (STRICTLY ENFORCED - ${params.language.toUpperCase()}):
- summary: 50-60 words (EN) / 40-50 words (HI/ML) — 3-4 clear, simple sentences
- context: 40-70 words — Only essential background to orient the reader
- interpretation: 120-150 words — 2 short paragraphs, 5-7 sentences total
- prayer: 60-80 words — 4-5 short, reflective sentences
- relatedVerses: EXACTLY 3 verses (NOT 4, NOT 2)
- reflectionQuestions: EXACTLY 3 questions (NOT 4, NOT 2)
- All insight arrays: EXACTLY 3 items (NOT 4, NOT 2)

⚠️ Word limits above apply to all languages. Use full limits to produce a complete, substantive 3-minute guide.

CONTENT STRUCTURE (ALL 15 FIELDS MANDATORY):
{
  "summary": "Main message in 3-4 sentences (MAX ${wordLimits.summary} words)",
  "context": "Essential background (50-100 words MAX). ONE brief paragraph with only critical context.",
  "passage": "⚠️ MANDATORY FIELD - Provide a Scripture reference for meditation. PREFER LONGER PASSAGES (10-20+ verses) that provide substantial content for reflection (e.g., 'Romans 8:1-39', 'Psalm 119:1-24', 'Matthew 5:1-20'). Choose a passage that best captures the core message of this study. Format: Just the reference in ${languageConfig.name}, no verse text. DO NOT skip this field.",
  "interpretation": "EXACTLY 2 paragraphs. Paragraph 1: 3-4 sentences. Paragraph 2: 3-4 sentences. Total: 6-8 sentences. MAX ${wordLimits.interpretation} words. NO headings, NO bullets.",
  "relatedVerses": ["EXACTLY 3 Bible verse REFERENCES ONLY in ${languageConfig.name} (e.g., 'Matthew 5:16', 'Psalm 23:1') - NO verse text"],
  "reflectionQuestions": ["EXACTLY 3 practical application questions"],
  "prayerPoints": ["EXACTLY 4 or 5 sentences addressing God directly. MAX ${wordLimits.prayer} words."],
  "summaryInsights": ["EXACTLY 3 key themes (8-12 words each)"],
  "interpretationInsights": ["EXACTLY 3 theological insights (8-12 words each)"],
  "reflectionAnswers": ["EXACTLY 3 life applications (8-12 words each)"],
  "contextQuestion": "Yes/no question connecting context to modern life",
  "summaryQuestion": "Brief question (6-10 words)",
  "relatedVersesQuestion": "Verse question (6-10 words)",
  "reflectionQuestion": "Application question (6-10 words)",
  "prayerQuestion": "Prayer prompt (5-8 words)"
}

${createPrayerFormatBlock(languageConfig, params.language, '4-5')}

⚠️ CRITICAL STRUCTURAL REQUIREMENTS:

"interpretation" field:
Paragraph 1 (3-4 sentences): [First theological insight]
Paragraph 2 (3-4 sentences): [Second theological insight]
Total: 6-8 sentences across 2 paragraphs
Word count: Aim for ${wordLimits.interpretation - 10}-${wordLimits.interpretation} words (NO MORE than ${wordLimits.interpretation})

"context" field:
Paragraph 1 (2-3 sentences): [Historical/cultural background]
Paragraph 2 (optional, 2-3 sentences): [Modern relevance]
Total: 4-6 sentences
Word count: Aim for ${wordLimits.context - 15}-${wordLimits.context} words (NO MORE than ${wordLimits.context})

CRITICAL FORMATTING:
✓ Continuous narrative prose (NO headings, NO bullets)
✓ Separate paragraphs with double newline (\\n\\n)
✓ Focus on ONE central truth
✓ Brevity is paramount - this is QUICK READ (3 minutes)
✓ Aim for the FULL word limits in every field — a guide that is too short is as bad as one that is too long

MANDATORY PRE-OUTPUT VERIFICATION:
Count and verify BEFORE completing:
1. "summary": ≤ ${wordLimits.summary} words? [Count: ___]
2. "interpretation": EXACTLY 2 paragraphs? [Yes/No]
3. "interpretation": Each paragraph 3-4 sentences? [Para 1: ___ Para 2: ___]
4. "interpretation": ≤ ${wordLimits.interpretation} words? [Count: ___]
5. "context": ≤ ${wordLimits.context} words? [Count: ___]
6. "prayer": 4-5 sentences? [Count: ___]
7. "prayer": ≤ ${wordLimits.prayer} words? [Count: ___]
8. "relatedVerses": EXACTLY 3? [Count: ___]
9. "reflectionQuestions": EXACTLY 3? [Count: ___]
10. "summaryInsights": EXACTLY 3? [Count: ___]
11. "interpretationInsights": EXACTLY 3? [Count: ___]
12. "reflectionAnswers": EXACTLY 3? [Count: ___]
13. All 15 fields present including passage? [Yes/No]

IF ANY COUNT IS WRONG - YOU MUST FIX IT BEFORE OUTPUT.
IF WORD LIMITS ARE EXCEEDED - YOU MUST CUT CONTENT TO MEET LIMITS.

${getLanguageExamples(params.language)}

OUTPUT: Valid JSON starting with { and ending with }`

  return { systemMessage, userMessage }
}

/**
 * DEEP DIVE MODE (15 minutes) - COMPREHENSIVE THEOLOGICAL DEPTH
 * Deep exploration with integrated word studies and extended context
 */
function createDeepDivePrompt(params: LLMGenerationParams, languageConfig: LanguageConfig): PromptPair {
  const { inputType, inputValue, topicDescription, pathTitle, pathDescription } = params

  const pathParts = [
    pathTitle ? `Part of Learning Path: ${pathTitle}` : '',
    pathDescription ? `Learning Path Goal: ${pathDescription}` : '',
  ].filter(Boolean).join('\\n')
  const pathContext = pathParts ? `\\n\\n${pathParts}` : ''
  const taskDescription = inputType === 'scripture'
    ? `Create a DEEP DIVE study for: "${inputValue}"`
    : `Create a DEEP DIVE study on: "${inputValue}"${topicDescription ? `\\n\\nContext: ${topicDescription}` : ''}${pathContext}`

  const systemMessage = `You are an expert biblical scholar creating IN-DEPTH theological studies.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, params.language)}

STUDY MODE: DEEP DIVE (15 minutes reading-with-understanding time)
Reading-with-understanding speed: 120-140 words/minute (slow, focused reflection)
Focus: COMPREHENSIVE theological depth + integrated word studies + extended context.
Tone: Warm pastoral depth — conversational but substantive, like a thorough sermon from a scholar-pastor.

${WRITING_STYLE}

⚠️ CRITICAL DISTINCTION: This is DEEP THEOLOGICAL EXPLORATION, NOT just a longer Standard mode.
Emphasize:
- Deep theological analysis with systematic theology connections
- Greek/Hebrew word studies INTEGRATED naturally where they illuminate meaning (not formulaically)
- Extended historical/cultural/theological context
- Original language insights that deepen understanding
- Doctrinal precision and biblical theology framework
- Scholarly depth delivered in plain, engaging language — not academic prose

Target total output: 1,800-2,100 words across all fields.
Goal: Comprehensive depth + linguistic precision + theological richness, all in human voice.`

  const userMessage = `${taskDescription}

${createVerseReferenceBlock(params.language)}

═══════════════════════════════════════════════════════════════════════════
DEEP DIVE STRUCTURE - COMPREHENSIVE THEOLOGICAL DEPTH (15 minutes)
═══════════════════════════════════════════════════════════════════════════

⚠️ CRITICAL DEEP DIVE FOCUS:

This is COMPREHENSIVE THEOLOGICAL EXPLORATION, not just a longer Standard mode. EMPHASIZE:
✓ Deep theological analysis with systematic theology connections
✓ Greek/Hebrew word studies INTEGRATED where they illuminate meaning
✓ Extended historical, cultural, and theological context
✓ Biblical theology framework showing redemptive-historical development
✓ Original language insights that deepen understanding
✓ Doctrinal precision appropriate for serious Bible students
✓ Cross-references with exegetical analysis

TARGET WORD COUNTS (MUST MEET):
- "interpretation": 1,350-1,550 words (COMPREHENSIVE theological depth with integrated word studies)
- "summary": 120-150 words (Clear theological overview)
- "context": 40-70 words (SHORT - one punchy paragraph, single most essential background fact only)
- "prayerPoints": 90-120 words (Gospel-shaped, focused prayer)
- Total target: 1,800-2,100 words

INTERPRETATION SECTION MUST contain:
- EXACTLY 5 or 6 paragraphs of continuous prose
- EACH paragraph MUST have 6-7 sentences (depth through precision, not repetition)
- Total word count: 1,350-1,550 words MANDATORY

⚠️ READING-WITH-UNDERSTANDING MODEL: This is a 15-MINUTE DEEP DIVE for serious Bible students.
Reading speed: 120-140 wpm with slow, intentional reflection and theological processing.
Goal: Comprehensive depth, linguistic precision, doctrinal clarity.

COUNT YOUR SENTENCES CAREFULLY:
- A sentence ends with period (.), question mark (?), or exclamation point (!)
- EACH paragraph = 6-7 sentences (scholarly depth with clarity)
- Focus on theological richness and exegetical insight, not verbosity
- Deep Dive requires comprehensive exploration + integrated word studies + doctrinal precision

INTERPRETATION PARAGRAPH STRUCTURE (6-7 sentences EACH):

Write 5-6 paragraphs of COMPREHENSIVE THEOLOGICAL DEPTH with integrated word studies.
INTEGRATE Greek/Hebrew word analysis naturally where it illuminates meaning.
DO NOT force word studies into every paragraph - use them strategically where they add depth.

## Paragraph 1 (6-7 sentences): Theological Foundation & Key Terms
Establish the theological framework for this topic/passage.
→ What is the central theological question or doctrine being addressed?
→ Introduce 1-2 KEY Greek/Hebrew terms that unlock meaning (if applicable)
→ Provide initial word analysis: original language, basic meaning, significance
→ How does this topic fit into biblical theology and God's redemptive plan?
→ What systematic theology connections are essential to understand?
→ [Example: For "Who is Jesus?" - introduce "Christos," "Huios tou Theou," "Kyrios" with brief definitions]

## Paragraph 2 (6-7 sentences): First Major Theological Concept - Deep Exploration
Explore the first major aspect of this topic with scholarly depth.
→ INCLUDE word study if a key term illuminates this concept (Greek/Hebrew analysis, usage, meaning)
→ Provide exegetical analysis: What does Scripture actually say about this?
→ Cross-references: How do other passages develop this theme?
→ Historical/cultural context: What background helps us understand this?
→ Theological implications: What does this reveal about God, humanity, salvation, etc.?
→ [Example: Deep exploration of "Christos" - OT background, fulfillment in Jesus, messianic significance]

## Paragraph 3 (6-7 sentences): Second Major Theological Concept - Comprehensive Treatment
Develop the second crucial aspect with doctrinal precision.
→ INTEGRATE word study if relevant (semantic range, biblical usage, doctrinal weight)
→ Biblical theology: How does this develop from OT to NT?
→ Systematic theology connections: How does this fit with other doctrines?
→ Church history perspective: How have Christians historically understood this?
→ Theological nuances: What distinctions or clarifications are needed?
→ [Example: Deity of Christ explored through "Huios tou Theou" - divine sonship, eternal generation]

## Paragraph 4 (6-7 sentences): Third Major Theological Concept - In-Depth Analysis
Address the third essential dimension with scholarly rigor.
→ USE word study where it deepens understanding (original language insights)
→ Exegetical precision: What does careful study of the text reveal?
→ Doctrinal significance: Why does this matter for Christian theology?
→ Gospel connection: How does this point to Christ and His work?
→ Apologetic considerations: How does this answer objections or clarify truth?
→ [Example: Lordship of Christ through "Kyrios" - divine name, sovereign authority, worship]

## Paragraph 5 (6-7 sentences): Theological Synthesis & Integration
Bring together the major concepts into unified theological understanding.
→ How do all these elements work together to form a complete doctrine?
→ Systematic theology: What is the comprehensive biblical teaching on this?
→ Biblical theology: How does this fit into the whole counsel of God?
→ Common errors avoided: What false teaching does this clarity expose?
→ Theological precision: What profound truths emerge from deep study?
→ [Example: How Christos + Huios tou Theou + Kyrios reveal Jesus' full identity]

## [OPTIONAL] Paragraph 6 (6-7 sentences): Practical Application & Life Impact
Show how deep theological understanding transforms Christian living.
→ From theology to life: How does this truth change daily Christian experience?
→ Worship implications: How should this deepen our adoration of God?
→ Doctrinal stability: How does this precision protect against error?
→ Pastoral application: How should churches teach and apply this?
→ Personal transformation: What changes when believers grasp this deeply?
→ [Example: Living under Christ's lordship, worshiping the divine Son, trusting the Messiah]

TARGET: 5-6 paragraphs × 6-7 sentences each = 1,350-1,550 words for interpretation

JSON STRUCTURE:
{
  "summary": "Comprehensive theological overview (6-7 sentences, 120-150 words) introducing the topic with scholarly depth.",
  "context": "Historical/cultural background (40-70 words MAX). One short paragraph — only the single most essential fact a modern reader needs. The depth belongs in interpretation, not context.",
  "passage": "⚠️ MANDATORY FIELD - Provide a Scripture reference for deep study. PREFER LONGER passages that provide rich theological content (e.g., 'Romans 8:1-39', 'John 14:1-27', 'Ephesians 2:1-10', 'Psalm 139:1-24'). Choose a passage that best captures this topic. Format: Just the reference, no verse text. DO NOT skip this field.",
  "interpretation": "[EXACTLY 5 or 6 sections as structured above. Each section starts with a **Bold Section Title** on its own line (e.g. **The Word Behind the Word**), followed by 5-7 sentences in warm, direct pastoral voice. Target: 1,350-1,550 words. Integrate Greek/Hebrew where it illuminates meaning naturally — not formulaically. NO markdown H2/H3, NO bullet lists. Bold section headers only (**Title**).]",
  "relatedVerses": ["5-6 Bible verse REFERENCES ONLY supporting key theological points in ${languageConfig.name} (e.g., 'Romans 5:1', 'Ephesians 2:8-9') - NO verse text"],
  "reflectionQuestions": ["5-6 deep theological and application questions"],
  "prayerPoints": ["Comprehensive first-person prayer (5-6 sentences, 90-120 words) responding to theological depth"],
  "summaryInsights": ["4-5 key themes (15-20 words each - theological insights)"],
  "interpretationInsights": ["4-5 doctrinal truths (15-20 words each - theological precision)"],
  "reflectionAnswers": ["4-5 applications (15-20 words each - life transformation)"],
  "contextQuestion": "Yes/no question connecting historical/theological context to modern life",
  "summaryQuestion": "Question about central theological message (12-18 words)",
  "relatedVersesQuestion": "Question about cross-references and biblical connections (12-18 words)",
  "reflectionQuestion": "Deep application question for reflection (12-18 words)",
  "prayerQuestion": "Prayer invitation responding to theological truth (10-15 words)"
}

${createPrayerFormatBlock(languageConfig, params.language, '5-6')}

MANDATORY PRE-OUTPUT VERIFICATION:
Count and verify BEFORE completing:
1. "interpretation": EXACTLY 5 or 6 paragraphs? [Count: ___]
2. Paragraph 1 (Theological Foundation): 6-7 sentences establishing framework? [Count: ___]
3. Paragraph 2 (First Concept): 6-7 sentences with deep exploration? [Count: ___]
4. Paragraph 3 (Second Concept): 6-7 sentences with comprehensive treatment? [Count: ___]
5. Paragraph 4 (Third Concept): 6-7 sentences with in-depth analysis? [Count: ___]
6. Paragraph 5 (Synthesis): 6-7 sentences showing theological integration? [Count: ___]
7. Paragraph 6 (if included - Application): 6-7 sentences on life transformation? [Count: ___]
8. "interpretation": 1,350-1,550 words total? [Estimate: ___ words]
9. "summary": 120-150 words (6-7 sentences) theological overview? [Count: ___]
10. "context": 40-70 words (SHORT background)? [Estimate: ___ words]
11. "prayer": 5-6 sentences (90-120 words)? [Count: ___]
12. All 15 fields present including passage? [Yes/No]
13. Is total output 1,800-2,100 words? [Estimate: ___]
14. Does interpretation integrate word studies WHERE RELEVANT (not forced)? [Yes/No]
15. Does this provide comprehensive theological depth beyond Standard mode? [Yes/No]
16. Would this realistically take 15 minutes with deep theological reflection? [Yes/No]

IF ANY COUNT IS WRONG - YOU MUST FIX IT BEFORE OUTPUT.
IF WORD COUNTS ARE TOO LOW OR TOO HIGH - ADJUST TO MEET 1,800-2,100 WORD TARGET.
This is a 15-MINUTE DEEP DIVE - comprehensive depth within focused timeframe.

⚠️ CRITICAL: Deep Dive is COMPREHENSIVE THEOLOGICAL EXPLORATION, distinct from Standard mode.
- MUST provide deeper theological analysis than Standard mode
- SHOULD integrate Greek/Hebrew word studies where they illuminate meaning (not forced into every paragraph)
- MUST keep context short (40-70 words) — depth belongs in interpretation, not context
- MUST show systematic theology connections and biblical theology framework
- MUST provide scholarly depth appropriate for serious Bible students
- This is NOT just Standard mode with word studies added - it's COMPREHENSIVE DEPTH

${getLanguageExamples(params.language)}

OUTPUT: Valid JSON starting with { and ending with }`

  return { systemMessage, userMessage }
}

/**
 * LECTIO DIVINA MODE (15 minutes)
 * Contemplative meditative study
 */
function createLectioDivinaPrompt(params: LLMGenerationParams, languageConfig: LanguageConfig): PromptPair {
  const { inputType, inputValue, topicDescription, pathTitle, pathDescription } = params

  const pathParts = [
    pathTitle ? `Part of Learning Path: ${pathTitle}` : '',
    pathDescription ? `Learning Path Goal: ${pathDescription}` : '',
  ].filter(Boolean).join('\\n')
  const pathContext = pathParts ? `\\n\\n${pathParts}` : ''
  const taskDescription = inputType === 'scripture'
    ? `Create a MEDITATIVE READING guide for: "${inputValue}"`
    : `Create a MEDITATIVE READING guide on: "${inputValue}"${topicDescription ? `\\n\\nContext: ${topicDescription}` : ''}${pathContext}`

  const wordTarget = getWordCountTarget(languageConfig, 'lectio')
  const systemMessage = `You are a Bible study guide leading prayerful Scripture reading and personal application.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, params.language)}${getDiscipleLevelContext(params.discipleLevel)}

STUDY MODE: MEDITATIVE READING (10 minutes prayerful Scripture reading)
Reading pace: slow and attentive — observation, reflection, prayer, obedience.
Four Protestant movements: CAREFUL READING (observe) → BIBLICAL REFLECTION (understand) → PRAYER RESPONSE (respond) → APPLICATION (obey).
Tone: Prayerful, warm, Scripture-anchored, clear. All spiritual insight must flow FROM the text, not from feelings, impressions, or inner experiences.

PROTESTANT DISTINCTIVES (MANDATORY):
- All discernment is anchored to the biblical text — never to feelings, visions, or subjective impressions alone
- "God speaking" means God speaking through His written Word (2 Timothy 3:16-17), not mystical inner voices
- Prayer is a believer's response to what Scripture reveals, not a technique for achieving spiritual states
- Silence and stillness are valid postures for reflection, but never as emptying techniques or centering practices
- Scripture interprets Scripture — cross-references must illuminate, not replace, the primary text

⚠️ CRITICAL INSTRUCTION: DEPTH, NOT COVERAGE
This is a 10-MINUTE prayerful meditation on Scripture.
Target total output: ${wordTarget} words across all fields.
Goal: Encounter the living Word of God carefully and respond in faith and obedience.

${createNativeWritingStyle(params.language)}`

  const userMessage = `${taskDescription}

${createVerseReferenceBlock(params.language)}

═══════════════════════════════════════════════════════════════════════════
MEDITATIVE READING STRUCTURE - ALL 15 FIELDS MANDATORY
═══════════════════════════════════════════════════════════════════════════

⚠️ CRITICAL LENGTH AND DEPTH REQUIREMENTS:

TARGET WORD COUNTS (MUST MEET):
- "interpretation": 800-1,000 words (4 paragraphs of Scripture-anchored guidance)
- "summary": 150-200 words (Scripture focus with prayerful invitation)
- "context": 40-60 words (BRIEF - heart preparation for meditative reading)
- "prayerPoints": 50-70 words each (specific, text-grounded prayer)
- Total target: ${wordTarget} words

INTERPRETATION SECTION MUST contain:
- EXACTLY 4 paragraphs of clear, Scripture-anchored guidance
- EACH paragraph has 6-8 sentences with concrete, text-grounded direction
- Total word count: 800-1,000 words MANDATORY

INTERPRETATION PARAGRAPH STRUCTURE (6-8 sentences EACH):

Write Paragraph 1 (6-8 sentences): CAREFUL READING — Observation & Understanding
→ Invite prayer first: Ask the Holy Spirit to open your eyes (Psalm 119:18)
→ Observation prompts: What does the text actually SAY? What words are repeated or striking?
→ Immediate context: What comes before and after? How does that shape the meaning?
→ Theological content: What does this passage teach about God, humanity, sin, or salvation?
→ Original audience: What was God saying to them? What does that mean for us today?
→ Personal alignment: Which commands, promises, or warnings apply directly to you?

Write Paragraph 2 (6-8 sentences): BIBLICAL REFLECTION — What God Reveals
→ God's nature: What does this passage teach about who God is (His character, attributes, ways)?
→ Christ-centered reading: How does this passage point to or find fulfillment in Jesus Christ?
→ Grace and truth: Where is the grace of God visible? Where is the demand of God visible?
→ Scripture interprets Scripture: What other passages illuminate this one?
→ Doxological response: What about God in this passage moves you to worship, trust, or obedience?

Write Paragraph 3 (6-8 sentences): PRAYER RESPONSE — Responding to God Based on the Text
→ Thanksgiving: Thank God specifically for what this passage reveals about Him
→ Confession: If the passage exposed sin or unbelief, pray honestly for forgiveness (1 John 1:9)
→ Trust: Pray to believe the specific promises the passage declared — name them
→ Petition: Ask God for what the passage calls you to — strength, obedience, faith, wisdom
→ Intercession: Who comes to mind as you read this? Pray for them in light of the text

Write Paragraph 4 (6-8 sentences): APPLICATION & COMMITMENT — Concrete Obedience
→ One truth to believe: What specific biblical truth will you commit to trusting this week?
→ One sin to repent of: What specific sin or attitude does this passage call you to turn from?
→ One action to take: What concrete, observable step of obedience will you take this week?
→ One person to serve: Who can you serve or encourage based on what you studied?
→ Scripture to carry: Which single verse from this passage will you memorize or return to today?

TARGET: 4 paragraphs × 6-8 sentences each = 800-1,000 words for interpretation

CONTENT STRUCTURE (ALL 15 FIELDS MANDATORY):
{
  "summary": "**Scripture for Meditation**\\n\\n[Reference in ${languageConfig.name}]\\n\\n[Prayerful, warm invitation to read this passage carefully — 150-200 words. State what the passage is about and what God reveals through it. Invite the reader to come with open Bible, open heart, and dependence on the Holy Spirit.]",
  "context": "Brief introduction to prayerful Scripture reading as a Protestant spiritual discipline (40-60 words): coming to God's Word expectantly, asking the Holy Spirit for understanding (1 Corinthians 2:12-14), reading observationally and responding in prayer and obedience.",
  "passage": "⚠️ MANDATORY FIELD - Provide a Scripture reference for meditation. PREFER SHORTER passages (5-12 verses) for focused reading (e.g., 'Psalm 23:1-6', 'John 15:1-8', 'Philippians 4:4-9', '1 John 4:7-12'). Format: Just the reference in ${languageConfig.name}, no verse text. DO NOT skip this field.",
  "interpretation": "[EXACTLY 4 paragraphs as structured above. EACH paragraph with 6-8 sentences of Scripture-anchored guidance. Target: 800-1,000 words. Guide through: CAREFUL READING → BIBLICAL REFLECTION → PRAYER RESPONSE → APPLICATION & COMMITMENT. NO headings, NO bullets. Flowing prayerful prose grounded in the text.]",
  "relatedVerses": ["5-7 Bible verse REFERENCES ONLY in ${languageConfig.name} that support the passage themes (e.g., 'Psalm 119:18', 'John 16:13') - NO verse text"],
  "reflectionQuestions": ["What does this passage actually say? What words or phrases stand out?", "What does this passage teach about God's character or purposes?", "How does this passage point to or find fulfillment in Jesus Christ?", "What specific sin or attitude does this passage call you to repent of?", "What one concrete step of obedience will you take this week based on this text?"],
  "prayerPoints": ["Specific prayer topic arising from the passage (4-5 sentences, 50-70 words). Address God directly. Ground the prayer in what the text reveals. Close with appropriate ending for ${languageConfig.name}"],
  "summaryInsights": ["4-5 key biblical truths from the passage (15-20 words each)"],
  "interpretationInsights": ["4-5 theological insights revealed by the text (15-20 words each)"],
  "reflectionAnswers": ["4-5 concrete life applications from the text (15-20 words each)"],
  "contextQuestion": "Yes/no question connecting the passage's original context to personal life today",
  "summaryQuestion": "Question about the central biblical message of the passage (12-18 words)",
  "relatedVersesQuestion": "Question encouraging further Bible reading on this theme (12-18 words)",
  "reflectionQuestion": "Question inviting personal reflection on the text (12-18 words)",
  "prayerQuestion": "Invitation to respond in prayer based on what Scripture taught (10-15 words)"
}

${createPrayerFormatBlock(languageConfig, params.language, '4-5')}

CRITICAL CONTENT REQUIREMENTS:
✓ "summary": Warm, prayerful invitation grounded in the passage (150-200 words)
✓ "interpretation": 4 paragraphs guiding CAREFUL READING → BIBLICAL REFLECTION → PRAYER RESPONSE → APPLICATION (800-1,000 words)
✓ "context": BRIEF introduction to prayerful Protestant Scripture reading (40-60 words)
✓ All reflection questions grounded in the TEXT — not abstract, mystical, or centering-prayer based
✓ All prayer points specific to what the passage TEACHES — not vague spiritual impressions

MANDATORY PRE-OUTPUT VERIFICATION:
Count and verify BEFORE completing:
1. "interpretation": EXACTLY 4 paragraphs? [Count: ___]
2. Paragraph 1 (CAREFUL READING): 6-8 sentences? [Count: ___]
3. Paragraph 2 (BIBLICAL REFLECTION): 6-8 sentences? [Count: ___]
4. Paragraph 3 (PRAYER RESPONSE): 6-8 sentences? [Count: ___]
5. Paragraph 4 (APPLICATION): 6-8 sentences? [Count: ___]
6. "interpretation": 800-1,000 words total? [Estimate: ___ words]
7. "summary": 150-200 words? [Count: ___]
8. "context": 40-60 words (brief orientation)? [Estimate: ___ words]
9. All 15 fields present including passage? [Yes/No]
10. Is total output ~${wordTarget} words? [Estimate: ___]
11. Is the tone prayerful and Scripture-anchored (not mystical or centering-prayer based)? [Yes/No]
12. Are all reflection questions grounded in the TEXT? [Yes/No]
13. Would this realistically fit 10 minutes of attentive, prayerful reading? [Yes/No]

IF ANY COUNT IS WRONG - YOU MUST FIX IT BEFORE OUTPUT.
IF WORD COUNTS ARE TOO LOW OR TOO HIGH - ADJUST TO MEET ${wordTarget} WORD TARGET.

${getLanguageExamples(params.language)}

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

export function getSermonHeadings(language: string): Record<string, string> {
  return SERMON_HEADINGS[language] || SERMON_HEADINGS['en']
}

function createSermonOutlinePrompt(params: LLMGenerationParams, languageConfig: LanguageConfig): PromptPair {
  const { inputType, inputValue, topicDescription, pathTitle, pathDescription } = params
  const headings = getSermonHeadings(params.language)

  const sermonFormat = inputType === 'scripture' ? 'EXPOSITORY' : 'TOPICAL (3-Point)'

  const pathParts = [
    pathTitle ? `Part of Learning Path: ${pathTitle}` : '',
    pathDescription ? `Learning Path Goal: ${pathDescription}` : '',
  ].filter(Boolean).join('\\n')
  const pathContext = pathParts ? `\\n\\n${pathParts}` : ''
  const taskDescription = inputType === 'scripture'
    ? `Create an ${sermonFormat} sermon outline for: "${inputValue}"`
    : `Create a ${sermonFormat} sermon outline on: "${inputValue}"${topicDescription ? `\\n\\nContext: ${topicDescription}` : ''}${pathContext}`

  const wordTarget = getWordCountTarget(languageConfig, 'sermon')
  const systemMessage = `You are an experienced preacher creating sermon outlines for pastors.

${THEOLOGICAL_FOUNDATION}

${JSON_OUTPUT_RULES}

${createLanguageBlock(languageConfig, params.language)}

STUDY MODE: SERMON OUTLINE (50-60 minutes SPOKEN delivery time)
⚠️ NOTE: This is a PREACHER-FACING EXPLANATION, not a full manuscript.
Reading time: ~30 minutes (4,500-5,350 words) | Preaching time: 50-60 minutes (expanded orally)
Target total output: 4,500-5,350 words across all fields.

⚠️ CRITICAL INSTRUCTION: PROVIDE DEEP PREACHER-FACING EXPLANATION
This is NOT a full manuscript - it's a comprehensive outline that preachers will expand during delivery.
- Focus on CONCEPTUAL hooks and illustrations (not full stories)
- Provide CORE theological teaching (preachers will elaborate)
- Give 2-3 key verses per point (not exhaustive lists)
- Offer 3-4 focused applications (not 5-7)
Tone: Clear, theologically rich, pastorally wise, suitable for preacher preparation.

${createNativeWritingStyle(params.language)}`

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
SERMON STRUCTURE - ALL 15 FIELDS MANDATORY
═══════════════════════════════════════════════════════════════════════════

⚠️ CRITICAL LENGTH AND DEPTH REQUIREMENTS:

TARGET WORD COUNTS (MUST MEET):
- "interpretation": 3800-4500 words (DEEP PREACHER-FACING EXPLANATION)
- "summary": 250-350 words (compelling sermon thesis and hook)
- "context": 40-70 words (SHORT - one paragraph, single most essential background fact for preaching)
- "prayerPoints" (altar call): 300-400 words (invitation with gospel recap)
- Total target: ${wordTarget} words

INTERPRETATION SECTION (PREACHER-FACING EXPLANATION) MUST contain:
- Introduction: 450-550 words (5 min preach | ~4 min read)
- Point 1: 1000-1200 words (15 min preach | ~8 min read)
- Point 2: 1000-1200 words (15 min preach | ~8 min read)
- Point 3: 700-900 words (12 min preach | ~6 min read)
- Conclusion: 350-450 words (5 min preach | ~3 min read)
- Total: 3800-4500 words MANDATORY

⚠️ WHY THIS LENGTH: This is a PREACHER-FACING EXPLANATION that pastors will expand during delivery.
- Preachers need CORE theological content, not full manuscript
- Conceptual illustrations (not full stories) that preachers develop live
- 2-3 key verses per point (not exhaustive lists)
- Focus on DEPTH of explanation that can be expanded orally

TIMING BREAKDOWN (50-60 minutes preaching from this content):
Introduction: 5 min | Point 1: 15 min | Point 2: 15 min | Point 3: 12 min | Conclusion: 5 min | Altar Call: 4-6 min

SERMON OUTLINE STRUCTURE:

**INTRODUCTION (5 minutes preach | ~4 minutes read, 450-550 words):**

## ${headings.introduction}

**Hook** (120-150 words):
Provide a CONCEPTUAL hook (not a full story):
- Real-life tension, question, or problem that listeners face
- Cultural moment or observation everyone relates to
- Provocative question that creates curiosity
- Key statistic or research finding
Keep it CONCISE - give the idea, not every detail. Preacher will expand this live with stories and examples.

**Bridge** (180-220 words):
Connect life → text → Gospel theme in 2-3 concise paragraphs:
- Why this message matters TODAY
- The pain point or need this addresses
- How God's Word speaks to this issue
Focus on CONCEPTUAL connection - preacher will add personal vulnerability and examples during delivery.

**Preview** (100-120 words):
Outline the sermon movement clearly:
- State your thesis memorably
- Preview your 3 main points with compelling titles
- Set expectations for the journey
Make it CLEAR and MEMORABLE - this is the roadmap.

**${headings.transition}** (50-60 words):
One compelling paragraph bridging to Point 1. Create momentum.

**POINT 1 (15 min preach | ~8 min read, 1000-1200 words):**

## ${headings.point} 1: [Memorable Title - 3-6 words]

**${headings.mainTeaching}** (350-450 words):
Write 3-4 concise paragraphs with CORE theological exposition:
- Paragraph 1: Introduce the main theological truth clearly
- Paragraph 2: Define key biblical terms and explain the doctrine
- Paragraph 3: Connect to Christ's person and work (Christological focus)
- Paragraph 4: Address common misconceptions briefly
Focus on CORE doctrinal claims - explain meaning, not every implication. Preacher will elaborate.

**${headings.scriptureFoundation}** (300-350 words):
List 2-3 key Bible verses (in ${languageConfig.name}) with brief explanation (100-120 words per verse):
• **[Bible Reference 1]** - [Reference only, no full verse text]
  - Context: Who wrote, to whom, why (1-2 sentences)
  - Meaning: Core truth this verse teaches (2-3 sentences)
  - Connection: How it supports this point (1-2 sentences)

• **[Bible Reference 2]**
  [Same structure - keep concise]

Avoid quoting long passages - give references and core explanation only.

**${headings.illustration}** (Conceptual, 150-200 words):
Provide a CONCEPTUAL illustration idea (not a full story):
- **Illustration Concept**: Describe the type of story or example that works here (e.g., "A story about trusting God in financial uncertainty" or "An example of forgiveness in a broken relationship")
- **Key Elements**: What makes this illustration powerful (2-3 sentences)
- **Connection Point**: How it ties to the doctrinal truth (1-2 sentences)
- **Preacher Note**: "Expand this with personal testimony or local examples"
Preacher will fill out the full story during live delivery.

**${headings.application}** (180-220 words):
Provide 3-4 focused applications (50-70 words each):

• **[Application Focus]** (50-70 words):
Give HEART + LIFE application in one concise paragraph:
- What needs to change internally (heart/mindset)
- What this looks like practically (specific action)
- Keep it focused - preacher will add examples and address obstacles live

[Continue for 3-4 applications - keep each under 70 words]

**${headings.transition}** (50-70 words):
One paragraph bridging to Point 2. Show logical flow.

**POINT 2 (15 min preach | ~8 min read, 1000-1200 words):**

## ${headings.point} 2: [Memorable Title - 3-6 words]

Use SAME STRUCTURE as Point 1:
- **Main Teaching**: 350-450 words (3-4 paragraphs)
- **Scripture Foundation**: 300-350 words (2-3 verses explained)
- **Illustration (Conceptual)**: 150-200 words
- **Application**: 180-220 words (3-4 applications)
- **Transition**: 50-70 words

This is usually the theological weight center of the sermon.

**POINT 3 (12 min preach | ~6 min read, 700-900 words):**

## ${headings.point} 3: [Memorable Title - 3-6 words]

Condensed structure:
- **Main Teaching**: 280-350 words (2-3 paragraphs)
- **Scripture Foundation**: 220-260 words (2-3 verses)
- **Illustration (Conceptual)**: 120-150 words
- **Application**: 120-150 words (2-3 strong applications)
- **Transition**: 40-60 words

**CONCLUSION (5 min preach | ~3 min read, 350-450 words):**

## ${headings.conclusion}

Write 4 concise paragraphs:
- **Point 1 Summary** (80-100 words): Restate the main truth with fresh language
- **Point 2 Summary** (80-100 words): Connect to Point 1, show building argument
- **Point 3 Summary** (80-100 words): Bring all points together into unified gospel truth
- **Gospel Climax** (100-120 words): Tie everything to Christ's finished work. Make the gospel clear and compelling.

Keep summaries CONCISE - give the core idea, preacher will add emotional intensity and examples.

**ALTAR CALL / PRAYER PROMPTS (4-6 min preach | ~3 min read, 300-400 words):**

**${headings.gospelRecap}** (120-150 words):
Write 2-3 concise paragraphs with clear gospel presentation:
- God's holiness and our sin
- Christ's substitutionary death and resurrection
- Call to repentance and faith
Keep it CLEAR and FOCUSED - preacher will add vivid language and emotional appeal.

**${headings.theInvitation}** (120-150 words):
Write 2-3 paragraphs with specific invitation based on sermon theme:
- Direct invitation: "If you sense God calling you to [specific response]..."
- Create urgency with grace: "Respond TODAY"
- Pastoral reassurance: "If unsure, talk with me after"
Preacher will expand with personal warmth and Spirit-led emphasis.

**${headings.responseOptions}** (50-70 words):
List 4-5 clear response options:
• Come forward during closing song
• Raise hand for prayer
• Meet pastor after service
• Contact during the week
• Fill out connection card

**${headings.closingPrayer}** (60-80 words):
Brief first-person prayer outline:
- Pray for those responding
- Pray for Spirit's work
- Pray for courage to obey
Preacher will expand into full prayer during delivery.

CONTENT STRUCTURE (ALL 15 FIELDS MANDATORY):
{
  "summary": "**Sermon Title:** [Compelling 3-6 word title]\\n\\n**Thesis Statement:** [1-2 sentence core message of entire sermon - memorable and transformative]\\n\\n**Hook Preview:** [2-3 sentences describing the introduction's attention-grabber and why it matters]\\n\\n**Key Question:** [The central question this sermon answers]\\n\\n**Gospel Connection:** [2-3 sentences showing how this sermon ultimately points to Christ]\\n\\nTarget: 250-350 words with compelling framing that makes people want to hear the full sermon",
  "context": "Historical/cultural background (40-70 words MAX). One short paragraph — only the single most essential fact needed for preaching this passage. No fluff.",
  "passage": "⚠️ MANDATORY FIELD - Provide a Scripture reference for meditation reading. PREFER LONGER PASSAGES (10-20+ verses) that provide substantial content for reflection and meditation (e.g., 'Romans 8:1-39', 'Psalm 119:1-24', 'Matthew 5:1-20', 'Isaiah 53:1-12'). Choose a passage that best captures the core message of this sermon and provides rich material for personal devotion. Format: Just the reference in ${languageConfig.name}, no verse text. DO NOT skip this field.",
  "interpretation": "[PREACHER-FACING EXPLANATION following structure above. Target: 3,800-4,500 words. Include: Introduction (450-550 words), Point 1 (1,000-1,200 words), Point 2 (1,000-1,200 words), Point 3 (700-900 words), Conclusion (350-450 words). Provide CORE theological content and conceptual illustrations that preachers will expand during delivery.]",
  "relatedVerses": ["5-7 Bible verse REFERENCES ONLY in ${languageConfig.name} for further study (e.g., 'Isaiah 53:5', '1 Peter 2:24') - NO verse text"],
  "reflectionQuestions": ["5-7 discussion questions for small groups - mix theological reflection and personal application"],
  "prayerPoints": ["**ALTAR CALL / PRAYER PROMPTS (300-400 words)**\\n\\n**${headings.gospelRecap}** (120-150 words):\\n[Write 2-3 concise paragraphs with clear gospel presentation: God's holiness, our sin, Christ's death and resurrection, call to repentance and faith. Keep it focused - preacher will expand.]\\n\\n**${headings.theInvitation}** (120-150 words):\\n[Write 2-3 paragraphs with specific invitation based on sermon theme. Be direct and gracious. Preacher will add personal warmth.]\\n\\n**${headings.responseOptions}** (50-70 words):\\n• Come forward during closing song\\n• Raise hand for prayer\\n• Meet pastor after service\\n• Contact during the week\\n• Fill out connection card\\n\\n**${headings.closingPrayer}** (60-80 words):\\n[Brief prayer outline. Preacher will expand into full prayer during delivery.]\\n\\nAmen."],
  "summaryInsights": ["5 sermon takeaways congregation should remember (15-20 words each - memorable and actionable)"],
  "interpretationInsights": ["5 theological truths taught in the sermon (15-20 words each - doctrinally precise)"],
  "reflectionAnswers": ["5 life applications from the sermon (15-20 words each - specific and transformative)"],
  "contextQuestion": "Compelling yes/no question connecting biblical context to modern life challenges",
  "summaryQuestion": "Thought-provoking question about the sermon thesis (12-18 words)",
  "relatedVersesQuestion": "Question encouraging further scripture study during the week (12-18 words)",
  "reflectionQuestion": "Convicting application question for personal reflection (12-18 words)",
  "prayerQuestion": "Invitation question encouraging commitment and response (10-15 words)"
}

CRITICAL: USE EXACT HEADINGS IN ${languageConfig.name} (NOT ENGLISH):
✓ "${headings.introduction}" ✓ "${headings.point}" ✓ "${headings.mainTeaching}"
✓ "${headings.scriptureFoundation}" ✓ "${headings.illustration}" ✓ "${headings.application}"
✓ "${headings.transition}" ✓ "${headings.conclusion}"
✓ "${headings.gospelRecap}" ✓ "${headings.theInvitation}"
✓ "${headings.responseOptions}" ✓ "${headings.closingPrayer}"

FORMAT REQUIREMENTS (PREACHER-FACING EXPLANATION):
✓ Introduction: 450-550 words (Hook: 120-150, Bridge: 180-220, Preview: 100-120, Transition: 50-60)
✓ Point 1 - Main Teaching: 3-4 concise paragraphs (350-450 words)
✓ Point 1 - Scripture Foundation: 2-3 verses with brief explanation (300-350 words total)
✓ Point 1 - Illustration: CONCEPTUAL idea, not full story (150-200 words)
✓ Point 1 - Application: 3-4 focused applications (180-220 words, 50-70 words each)
✓ Point 1 - Transition: 50-70 words
✓ Point 2: Same structure as Point 1 (1000-1200 words)
✓ Point 3: Condensed structure (700-900 words)
✓ Conclusion: 350-450 words (4 paragraphs: 80-100 words each + 100-120 gospel climax)
✓ TOTAL INTERPRETATION: 3800-4500 words MANDATORY

SERMON FORMAT:
${inputType === 'scripture' ? `EXPOSITORY SERMON: Verse-by-verse exposition through passage with deep exegesis, original language insights, and systematic progression through the text` : `TOPICAL SERMON: 3-point message developing theme with multiple scripture support, logical argument progression, and practical life transformation`}

${createPrayerFormatBlock(languageConfig, params.language, 'varies')}

MANDATORY PRE-OUTPUT VERIFICATION:
Count and verify BEFORE completing:
1. INTRODUCTION section: 450-550 words? [Estimate: ___]
   - Hook (conceptual): 120-150 words? [___]
   - Bridge: 180-220 words? [___]
   - Preview: 100-120 words? [___]
   - Transition: 50-60 words? [___]

2. POINT 1 complete: 1000-1200 words total? [Estimate: ___]
   - Main Teaching: 3-4 paragraphs (350-450 words)? [Paragraph count: ___ | Word count: ___]
   - Scripture Foundation: 2-3 verses (300-350 words)? [Verse count: ___ | Word count: ___]
   - Illustration (conceptual): 150-200 words? [___]
   - Application: 3-4 points (180-220 words, 50-70 each)? [Point count: ___ | Word count: ___]
   - Transition: 50-70 words? [___]

3. POINT 2 complete: 1000-1200 words total? [Estimate: ___]
   [Same structure as Point 1]

4. POINT 3 complete: 700-900 words total? [Estimate: ___]
   - Main Teaching: 2-3 paragraphs (280-350 words)? [Paragraph count: ___ | Word count: ___]
   - Scripture Foundation: 2-3 verses (220-260 words)? [Verse count: ___ | Word count: ___]
   - Illustration (conceptual): 120-150 words? [___]
   - Application: 2-3 points (120-150 words)? [Point count: ___ | Word count: ___]
   - Transition: 40-60 words? [___]

5. CONCLUSION section: 350-450 words? [Estimate: ___]
   - Point 1 summary: 80-100 words? [___]
   - Point 2 summary: 80-100 words? [___]
   - Point 3 summary: 80-100 words? [___]
   - Gospel Climax: 100-120 words? [___]

6. "interpretation" TOTAL: 3,800-4,500 words? [Estimate: ___]
7. "summary": 250-350 words with sermon title, thesis, hook, key question, gospel connection? [Count: ___]
8. "context": 40-70 words (SHORT background)? [Count: ___]
9. "prayerPoints" (altar call): 300-400 words (gospel recap, invitation, response options, prayer outline)? [Count: ___]
10. All 15 fields present (including passage)? [Yes/No]
11. Are all headings in ${languageConfig.name} (NOT English)? [Yes/No]
12. Is TOTAL output 4,500-5,350 words? [Estimate: ___]
13. Would this provide CORE content that preachers can expand to 50-60 minutes? [Yes/No]
14. Does sermon maintain gospel centrality throughout? [Yes/No]

IF ANY COUNT IS WRONG - YOU MUST FIX IT BEFORE OUTPUT.
IF WORD COUNTS ARE TOO LOW - YOU MUST MEET THE ${wordTarget} WORD TARGET.
This is PREACHER-FACING EXPLANATION - provide core theological content with conceptual illustrations that preachers will expand during live delivery.

⚠️ CRITICAL: This outline must equip a pastor with CORE theological content, conceptual hooks, 2-3 key verses per point, and focused applications. Pastors will expand this during live preaching to fill 50-60 minutes.

${getLanguageExamples(params.language)}

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
✗ NO romanized Hinglish (e.g., "Yeshu" → use "यीशु")
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

/**
 * Calculate optimal max_tokens based on language script efficiency and study mode
 *
 * Token efficiency by language (words per token):
 * - English/Latin: 0.70 words/token (baseline)
 * - Hindi/Devanagari: 0.28 words/token (2.5x more tokens needed)
 * - Malayalam: 0.09 words/token (7-8x more tokens needed)
 *
 * v3.4: Dynamic token allocation to fix Hindi Sermon shortfall (47% → 100%)
 * and Malayalam underperformance (35-50% → 100% on adjusted targets)
 */
export function calculateOptimalTokens(params: LLMGenerationParams, languageConfig: LanguageConfig): number {
  const { language, studyMode = 'standard' } = params

  // Base token allocations for English (optimized for 0.70 words/token efficiency)
  const baseTokensEnglish: Record<string, number> = {
    quick: 8000,       // 600-750 words (Claude 3.5 Haiku max: 8192)
    standard: 16000,   // 2000-2500 words
    deep: 16000,       // 5000-6000 words
    lectio: 16000,     // 3000-3500 words
    sermon: 16000      // 9000-11000 words
  }

  // Language-specific multipliers based on script efficiency and adjusted word targets
  const languageMultipliers: Record<string, Record<string, number>> = {
    en: {
      quick: 1.0,
      standard: 1.0,
      deep: 1.0,
      lectio: 1.0,
      sermon: 1.0
    },
    hi: {
      quick: 1.0,        // 16k tokens → 500-600 words
      standard: 1.0,     // 16k tokens → 2000-2500 words
      deep: 1.024,       // 16.4k tokens (model max)
      lectio: 1.0,       // 16k tokens → 3000-3500 words
      sermon: 1.024      // 16.4k tokens → ~4500 words (model limit: 0.28 words/token efficiency)
    },
    ml: {
      // Malayalam adjusted targets (token-inefficient: 0.09 words/token = 7-8x more tokens)
      // Capped at model's 16,384 token limit for realistic generation
      quick: 0.44,       // 7k tokens → 400-500 words
      standard: 1.024,   // 16.4k tokens → ~1500 words (model max)
      deep: 1.024,       // 16.4k tokens → ~1500 words (model max)
      lectio: 1.024,     // 16.4k tokens → ~1500 words (model max)
      sermon: 1.024      // 16.4k tokens → ~1500 words (model max, Malayalam severely limited)
    }
  }

  const base = baseTokensEnglish[studyMode] || 16000

  // Get language-specific multiplier
  const langMultipliers = languageMultipliers[language] || languageMultipliers.en
  const multiplier = langMultipliers[studyMode] || 1.0

  const calculatedTokens = Math.floor(base * multiplier)

  // Cap at model's maximum completion tokens based on study mode
  // - Claude 3.5 Haiku (quick mode): 8,192 tokens max
  // - Claude 3.5 Sonnet (other modes): 16,384 tokens max
  // - GPT-4o-mini: 16,384 tokens max
  const MODEL_MAX_TOKENS = studyMode === 'quick' ? 8192 : 16384
  const maxTokens = Math.min(calculatedTokens, MODEL_MAX_TOKENS)

  if (calculatedTokens > MODEL_MAX_TOKENS) {
    console.warn(`[Token Calculation] Requested ${calculatedTokens} tokens exceeds model limit, capping at ${MODEL_MAX_TOKENS}`)
  }

  console.log(`[Token Calculation] ${language} ${studyMode}: ${maxTokens} tokens (${multiplier}x base)`)

  return maxTokens
}

/**
 * Gets language-specific word count target for a specific study mode.
 * Uses Reading-With-Understanding Time Model (v2.0) with realistic comprehension speeds.
 * Returns adjusted targets for Malayalam (70% of English due to token inefficiency).
 *
 * @param languageConfig - Language configuration
 * @param studyMode - Study mode
 * @returns Word count target display string (e.g., "1500-1800" for Standard mode)
 */
export function getWordCountTarget(languageConfig: LanguageConfig, studyMode: StudyMode): string {
  // Reading-With-Understanding Time Model v2.0
  // Optimized for comprehension at 110-160 wpm (vs previous 200 wpm)
  const defaultTargets: Record<StudyMode, string> = {
    quick: '450-600',       // 3 min @ 140-160 wpm (understanding-focused)
    standard: '1200-1500',  // 8 min @ 140-150 wpm (thoughtful reading)
    deep: '1500-1800',      // 12 min @ 120-140 wpm (comprehensive depth)
    lectio: '1000-1200',    // 9 min @ 110-130 wpm (contemplative)
    sermon: '4500-5350'     // 30 min read | 50-60 min preach (preacher-facing explanation)
  }

  return languageConfig.wordCountTargets?.[studyMode]?.display || defaultTargets[studyMode]
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

/**
 * Returns audience-level instructions based on disciple level.
 *
 * Used to calibrate vocabulary, theological depth, and application focus
 * so the study guide meets the reader where they are.
 *
 * @param discipleLevel - One of: seeker | believer | follower | disciple | leader
 * @returns A block of instructions describing audience expectations, or empty string if not set.
 */
export function getDiscipleLevelContext(discipleLevel?: string): string {
  if (!discipleLevel) return ''

  const levelMap: Record<string, string> = {
    seeker: `AUDIENCE LEVEL: SEEKER (Exploring Faith)
- Assume little or no prior Bible knowledge
- Use simple, everyday language — avoid Christian jargon entirely
- Briefly explain any theological terms you must use
- Be welcoming, non-judgmental, and curiosity-inviting
- Focus on foundational truths and relatable life questions
- Application: personal meaning, curiosity, and open invitation`,

    believer: `AUDIENCE LEVEL: NEW BELIEVER (Recently Accepted Faith)
- Assume the reader has just begun following Jesus
- Use clear, encouraging language with gentle theological vocabulary
- Introduce core biblical concepts simply, building confidence
- Focus on growth, assurance, and foundational spiritual habits
- Application: building daily faith, prayer, and Scripture reading`,

    follower: `AUDIENCE LEVEL: GROWING FOLLOWER (Established Christian)
- Assume a solid grasp of basic Bible stories and Christian vocabulary
- Use moderate theological depth; introduce nuance and wider biblical context
- Explore richer themes without over-simplification
- Focus on deeper personal growth, obedience, and community
- Application: lifestyle transformation and faithful discipleship`,

    disciple: `AUDIENCE LEVEL: MATURING DISCIPLE (Dedicated Believer)
- Assume strong Bible literacy and serious commitment to discipleship
- Use deeper theological language; explore complex biblical themes confidently
- Connect cross-textual patterns, systematic theology, and church history
- Focus on spiritual maturity, accountability, and reproducing faith
- Application: mentoring others, deeper study, and kingdom-minded living`,

    leader: `AUDIENCE LEVEL: CHRISTIAN LEADER (Mature Leader & Mentor)
- Assume advanced theological literacy and experience teaching others
- Use sophisticated theological depth; handle complex doctrines with nuance
- Provide insights useful for teaching, preaching, and pastoral care
- Focus on equipping leaders to mentor, teach, and shepherd others
- Application: leadership wisdom, sermon prep, and discipleship multiplication`,
  }

  const instruction = levelMap[discipleLevel.toLowerCase()]
  return instruction
    ? `\n\n═══════════════════════════════════════════════════════════════════════════\n${instruction}\n═══════════════════════════════════════════════════════════════════════════`
    : ''
}
