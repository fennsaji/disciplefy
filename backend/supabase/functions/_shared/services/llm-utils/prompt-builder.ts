/**
 * LLM Prompt Builder Module
 * 
 * Centralizes all prompt construction logic for different LLM use cases.
 * Provides type-safe prompt generation for study guides, daily verses, and follow-ups.
 */

import type { LLMGenerationParams, LanguageConfig, StudyMode } from '../llm-types.ts'
import { getLanguageExamples, getLanguageConfigOrDefault, type SupportedLanguage } from '../llm-config/language-configs.ts'

/**
 * Prompt pair containing system and user messages
 */
export interface PromptPair {
  systemMessage: string
  userMessage: string
}

/**
 * Creates the system message for study guide generation.
 * 
 * @param languageConfig - Language-specific configuration
 * @returns System message string
 */
export function createStudyGuideSystemMessage(languageConfig: LanguageConfig): string {
  return `You are a biblical scholar creating Bible study guides. Your responses must be valid JSON only.

THEOLOGICAL APPROACH:
- Protestant theological alignment
- Biblical accuracy and Christ-centered interpretation
- Practical spiritual application

LANGUAGE REQUIREMENTS:
- ${languageConfig.promptModifiers.languageInstruction}
- ${languageConfig.promptModifiers.complexityInstruction}
- Cultural Context: ${languageConfig.culturalContext}
- Use simple vocabulary accessible to common people

JSON OUTPUT REQUIREMENTS:
- Output ONLY valid JSON - no extra text before or after
- Use proper JSON string escaping for any quotes or special characters
- Keep sentences clear and well-structured
- Ensure proper JSON structure with no trailing commas
- Use standard JSON formatting with proper escaping

TONE: Pastoral, warm, encouraging, practical for daily spiritual growth.`
}

/**
 * Creates the user message for study guide generation.
 * 
 * @param params - Generation parameters
 * @param languageConfig - Language-specific configuration
 * @returns User message string
 */
export function createStudyGuideUserMessage(params: LLMGenerationParams, languageConfig: LanguageConfig): string {
  const { inputType, inputValue, topicDescription } = params
  const languageExamples = getLanguageExamples(params.language)

  // Create type-specific task description
  let taskDescription: string
  if (inputType === 'scripture') {
    taskDescription = `Create a Bible study guide for the scripture reference: "${inputValue}"`
  } else if (inputType === 'topic') {
    if (topicDescription) {
      taskDescription = `Create a Bible study guide for the topic: "${inputValue}"\n\nTopic Context: ${topicDescription}`
    } else {
      taskDescription = `Create a Bible study guide for the topic: "${inputValue}"`
    }
  } else if (inputType === 'question') {
    taskDescription = `Answer the biblical/theological question and create a comprehensive study guide: "${inputValue}"`
  } else {
    taskDescription = `Create a Bible study guide for: "${inputValue}"`
  }

  // Create input-specific instructions
  let specificInstructions = ''
  if (inputType === 'question') {
    specificInstructions = `
QUESTION-SPECIFIC REQUIREMENTS:
- Provide a direct, biblically grounded answer to the question
- Support your answer with relevant scripture passages
- Address common misconceptions if applicable
- Include practical applications of the biblical teaching
- Maintain theological accuracy and pastoral sensitivity
`
  }

  // Language-specific verse reference examples
  const verseReferenceExamples = getVerseReferenceExamples(params.language)

  return `TASK: ${taskDescription}

REQUIRED JSON OUTPUT FORMAT (follow exactly):
{
  "summary": "Brief overview (2-3 sentences) capturing the main message${inputType === 'question' ? ' and answering the question' : ''}",
  "interpretation": "Theological interpretation (4-5 paragraphs) explaining meaning and key teachings${inputType === 'question' ? ' with direct answer to the question' : ''}", 
  "context": "Historical and cultural background (1-2 paragraphs) for understanding",
  "relatedVerses": ["3-5 relevant Bible verses with references in ${languageConfig.name}"],
  "reflectionQuestions": ["4-6 practical application questions"],
  "prayerPoints": ["3-4 prayer suggestions"]
}${specificInstructions}

CRITICAL: RELATED VERSES LANGUAGE REQUIREMENT
- ALL verse references in "relatedVerses" MUST be in ${languageConfig.name}
- Book names must be in ${languageConfig.name} script/language
${verseReferenceExamples}

CRITICAL JSON FORMATTING RULES:
- Output ONLY valid JSON - no markdown, no extra text before or after
- Use proper JSON string escaping for quotes and special characters
- Keep content natural and readable while ensuring valid JSON
- Use standard JSON formatting with proper escaping
- No trailing commas in arrays or objects

${languageExamples}

Output format: Start with { and end with } - nothing else.`
}

/**
 * Creates an enhanced prompt for study guide generation.
 * Routes to mode-specific prompts based on studyMode parameter.
 *
 * @param params - Generation parameters (includes studyMode)
 * @param languageConfig - Language-specific configuration
 * @returns Prompt pair with system and user messages
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
    case 'standard':
    default:
      return {
        systemMessage: createStudyGuideSystemMessage(languageConfig),
        userMessage: createStudyGuideUserMessage(params, languageConfig)
      }
  }
}

// ==================== Mode-Specific Prompts ====================

/**
 * Creates a Quick Read prompt (3-minute study).
 * Generates condensed content using the standard 6-section format for streaming compatibility.
 * Sections are adapted for brevity: key insight, key verse, single reflection, brief prayer.
 */
function createQuickReadPrompt(params: LLMGenerationParams, languageConfig: LanguageConfig): PromptPair {
  const { inputType, inputValue, topicDescription } = params
  const languageExamples = getLanguageExamples(params.language)
  const verseReferenceExamples = getVerseReferenceExamples(params.language)

  let taskDescription: string
  if (inputType === 'scripture') {
    taskDescription = `Create a QUICK 3-minute Bible study for: "${inputValue}"`
  } else if (inputType === 'topic') {
    taskDescription = topicDescription
      ? `Create a QUICK 3-minute Bible study on: "${inputValue}"\n\nContext: ${topicDescription}`
      : `Create a QUICK 3-minute Bible study on: "${inputValue}"`
  } else {
    taskDescription = `Answer briefly and create a QUICK 3-minute study for: "${inputValue}"`
  }

  const systemMessage = `You are a biblical scholar creating CONCISE Bible study guides for busy readers. Your responses must be valid JSON only.

STUDY MODE: QUICK READ (3 minutes)
Focus on delivering ONE powerful insight that readers can apply immediately.

THEOLOGICAL APPROACH:
- Protestant theological alignment
- Biblical accuracy and Christ-centered interpretation
- Immediately practical spiritual application

LANGUAGE REQUIREMENTS:
- ${languageConfig.promptModifiers.languageInstruction}
- ${languageConfig.promptModifiers.complexityInstruction}
- Cultural Context: ${languageConfig.culturalContext}
- Use simple, accessible vocabulary

JSON OUTPUT REQUIREMENTS:
- Output ONLY valid JSON - no extra text
- Use proper JSON string escaping
- Keep content brief and impactful

TONE: Direct, warm, encouraging, immediately actionable.`

  const userMessage = `TASK: ${taskDescription}

QUICK READ FORMAT - REQUIRED JSON OUTPUT (use EXACTLY these field names):
{
  "summary": "ONE powerful key insight in 2-3 sentences - the main takeaway",
  "interpretation": "Key verse with brief explanation: [Reference]: [Verse text]. [1-2 sentence explanation]",
  "context": "Brief context (1-2 sentences) - keep minimal for quick reading",
  "relatedVerses": ["Include ONLY the single most relevant verse with reference in ${languageConfig.name}"],
  "reflectionQuestions": ["ONE practical reflection question for immediate application"],
  "prayerPoints": ["ONE brief, focused prayer point"]
}

CRITICAL RULES FOR QUICK READ:
- Keep EVERYTHING concise - this is a 3-minute study
- "interpretation" must include the key verse text with its reference
- Only ONE item in each array field
- Focus on immediate practical takeaway

CRITICAL: VERSE REFERENCE MUST BE IN ${languageConfig.name}
${verseReferenceExamples}

CRITICAL JSON FORMATTING RULES:
- Output ONLY valid JSON - no markdown, no extra text
- Use proper JSON string escaping
- No trailing commas

${languageExamples}

Output format: Start with { and end with } - nothing else.`

  return { systemMessage, userMessage }
}

/**
 * Creates a Deep Dive prompt (25-minute study).
 * Generates extended content using the standard 6-section format for streaming compatibility.
 * Word studies and cross-references are embedded in the interpretation and context sections.
 */
function createDeepDivePrompt(params: LLMGenerationParams, languageConfig: LanguageConfig): PromptPair {
  const { inputType, inputValue, topicDescription } = params
  const languageExamples = getLanguageExamples(params.language)
  const verseReferenceExamples = getVerseReferenceExamples(params.language)

  let taskDescription: string
  if (inputType === 'scripture') {
    taskDescription = `Create a COMPREHENSIVE Deep Dive Bible study for: "${inputValue}"`
  } else if (inputType === 'topic') {
    taskDescription = topicDescription
      ? `Create a COMPREHENSIVE Deep Dive Bible study on: "${inputValue}"\n\nContext: ${topicDescription}`
      : `Create a COMPREHENSIVE Deep Dive Bible study on: "${inputValue}"`
  } else {
    taskDescription = `Provide a thorough answer and create a COMPREHENSIVE Deep Dive study for: "${inputValue}"`
  }

  const systemMessage = `You are an expert biblical scholar creating IN-DEPTH Bible study guides for serious students. Your responses must be valid JSON only.

STUDY MODE: DEEP DIVE (25 minutes)
Provide scholarly depth while maintaining accessibility.

THEOLOGICAL APPROACH:
- Protestant theological alignment
- Biblical accuracy with original language insights
- Historical-grammatical hermeneutics
- Christ-centered interpretation
- Thorough practical application

LANGUAGE REQUIREMENTS:
- ${languageConfig.promptModifiers.languageInstruction}
- ${languageConfig.promptModifiers.complexityInstruction}
- Cultural Context: ${languageConfig.culturalContext}
- Balance scholarly depth with clarity

JSON OUTPUT REQUIREMENTS:
- Output ONLY valid JSON - no extra text
- Use proper JSON string escaping
- Provide comprehensive content

TONE: Scholarly yet pastoral, thorough, illuminating.`

  const userMessage = `TASK: ${taskDescription}

DEEP DIVE FORMAT - REQUIRED JSON OUTPUT (use EXACTLY these field names):
{
  "summary": "Comprehensive overview (4-5 sentences) with key themes and scholarly insights",
  "interpretation": "In-depth theological interpretation (6-8 paragraphs) including:\\n\\n**Word Studies:**\\n- Include 2-3 Greek/Hebrew words with transliterations and meanings\\n- Explain theological significance of key terms\\n\\n**Doctrinal Implications:**\\n- Explore theological depth and application",
  "context": "Extended historical, cultural, and literary context (3-4 paragraphs) including:\\n\\n**Cross-References:**\\n- Include 5-8 related passages with brief explanations of connections\\n- Show how other Scriptures illuminate this passage",
  "relatedVerses": ["5-8 relevant Bible verses with references in ${languageConfig.name} - include a brief note on each connection"],
  "reflectionQuestions": ["6-8 deep, thought-provoking questions including one journaling prompt at the end"],
  "prayerPoints": ["4-5 comprehensive prayer suggestions for deep application"]
}

CRITICAL CONTENT REQUIREMENTS FOR DEEP DIVE:
- "interpretation" MUST include word study section with Greek/Hebrew terms
- "context" MUST include cross-reference connections
- Each section should be substantially longer than standard study
- Include scholarly insights while remaining accessible
- Last item in "reflectionQuestions" should be a journaling prompt

CRITICAL: ALL VERSE REFERENCES MUST BE IN ${languageConfig.name}
${verseReferenceExamples}

CRITICAL JSON FORMATTING RULES:
- Output ONLY valid JSON - no markdown, no extra text
- Use proper JSON string escaping (\\n for newlines)
- No trailing commas

${languageExamples}

Output format: Start with { and end with } - nothing else.`

  return { systemMessage, userMessage }
}

/**
 * Creates a Lectio Divina prompt (15-minute meditative study).
 * Generates content using the standard 6-section format for streaming compatibility.
 * Maps Lectio Divina movements to standard sections for meditation guidance.
 */
function createLectioDivinaPrompt(params: LLMGenerationParams, languageConfig: LanguageConfig): PromptPair {
  const { inputType, inputValue, topicDescription } = params
  const languageExamples = getLanguageExamples(params.language)
  const verseReferenceExamples = getVerseReferenceExamples(params.language)

  let taskDescription: string
  if (inputType === 'scripture') {
    taskDescription = `Create a Lectio Divina meditation guide for: "${inputValue}"`
  } else if (inputType === 'topic') {
    taskDescription = topicDescription
      ? `Create a Lectio Divina meditation guide on: "${inputValue}"\n\nContext: ${topicDescription}`
      : `Create a Lectio Divina meditation guide on: "${inputValue}"`
  } else {
    taskDescription = `Create a Lectio Divina meditation guide for: "${inputValue}"`
  }

  const systemMessage = `You are a spiritual director guiding readers through Lectio Divina, the ancient practice of divine reading. Your responses must be valid JSON only.

STUDY MODE: LECTIO DIVINA (15 minutes)
Guide the reader through the four movements of sacred reading.

LECTIO DIVINA MOVEMENTS:
1. LECTIO (Read) - Slow, attentive reading of Scripture
2. MEDITATIO (Meditate) - Pondering words/phrases that resonate
3. ORATIO (Pray) - Responding to God in prayer
4. CONTEMPLATIO (Rest) - Silent rest in God's presence

THEOLOGICAL APPROACH:
- Contemplative Christian tradition
- Focus on personal encounter with God through Scripture
- Christ-centered, Spirit-led meditation
- Emphasis on listening and receiving

LANGUAGE REQUIREMENTS:
- ${languageConfig.promptModifiers.languageInstruction}
- ${languageConfig.promptModifiers.complexityInstruction}
- Cultural Context: ${languageConfig.culturalContext}
- Use gentle, inviting, meditative language

JSON OUTPUT REQUIREMENTS:
- Output ONLY valid JSON - no extra text
- Use proper JSON string escaping

TONE: Contemplative, gentle, inviting, spiritually nurturing.`

  const userMessage = `TASK: ${taskDescription}

LECTIO DIVINA FORMAT - REQUIRED JSON OUTPUT (use EXACTLY these field names):
{
  "summary": "**Scripture for Meditation**\\n\\n[Reference in ${languageConfig.name}]\\n\\n[Complete scripture passage text]\\n\\n*Read this passage slowly 2-3 times, letting the words wash over you.*",
  "interpretation": "**LECTIO (Read) & MEDITATIO (Meditate)**\\n\\nLECTIO: [Guidance for slow, attentive reading]\\n\\nMEDITATIO: [Guidance for pondering and meditation]\\n\\nAs you read again slowly, notice which word or phrase catches your attention. This is the Spirit inviting you to pause and receive.",
  "context": "**About Lectio Divina**\\n\\nLectio Divina (divine reading) is an ancient Christian practice dating back to the 3rd century. It invites us to move from reading about God to encountering God through His Word. There are four movements: Lectio (read), Meditatio (meditate), Oratio (pray), and Contemplatio (rest).\\n\\nApproach this time with an open heart, free from agenda. Let God speak to you through His Word.",
  "relatedVerses": ["List 5-7 significant words or phrases from the passage for meditation - these are focus words that invite deeper reflection"],
  "reflectionQuestions": ["**ORATIO (Pray)** - A prayer starter to respond to God based on the passage...", "What is God inviting you to in this Word?", "How might this passage shape your day?", "**CONTEMPLATIO (Rest)** - Rest in God's presence. Sit in silence for 2-3 minutes, simply being with God, letting go of words and thoughts."],
  "prayerPoints": ["[Prayer template/starter that the reader can personalize]", "[A blessing to carry with you: A brief sending word]", "[One way to carry this Word into daily life]"]
}

CRITICAL CONTENT REQUIREMENTS FOR LECTIO DIVINA:
- "summary" must include the full scripture text formatted for slow reading
- "interpretation" must guide through LECTIO and MEDITATIO movements
- "relatedVerses" should be FOCUS WORDS/PHRASES from the passage for meditation (not other verses)
- "reflectionQuestions" must include ORATIO and CONTEMPLATIO movements
- "prayerPoints" should include prayer template, blessing, and practice reminder
- Use meditative, gentle, inviting language throughout

CRITICAL: SCRIPTURE REFERENCE MUST BE IN ${languageConfig.name}
${verseReferenceExamples}

CRITICAL JSON FORMATTING RULES:
- Output ONLY valid JSON - no markdown, no extra text
- Use proper JSON string escaping (\\n for newlines)
- No trailing commas

${languageExamples}

Output format: Start with { and end with } - nothing else.`

  return { systemMessage, userMessage }
}

/**
 * Creates a simplified prompt for generating only a Bible verse reference.
 * 
 * @param excludeReferences - List of recently used references to avoid
 * @param language - Target language for cultural context
 * @returns Prompt pair for reference generation
 */
export function createVerseReferencePrompt(excludeReferences: string[], language: string): PromptPair {
  const excludeList = excludeReferences.length > 0
    ? ` Avoid these recently used verses: ${excludeReferences.join(', ')}.`
    : ''

  const languageConfig = getLanguageConfigOrDefault(language)

  const systemMessage = `You are a biblical scholar selecting inspiring Bible verses for daily spiritual encouragement.

Your task is to select ONE meaningful Bible verse reference. The actual verse text will be fetched from an authentic Bible API.

OUTPUT REQUIREMENTS:
- Return ONLY valid JSON with the exact structure specified
- No markdown formatting, no code blocks, no extra text
- Use proper JSON string escaping

LANGUAGE CONTEXT: ${languageConfig.culturalContext}`

  const userMessage = `Select one meaningful Bible verse reference for daily spiritual encouragement.${excludeList}

VERSE SELECTION CRITERIA:
- Choose verses that offer comfort, strength, hope, faith, peace, or guidance
- Focus on well-known, doctrinally sound verses
- Prefer single verses (not multi-verse passages) for clarity
- Ensure the verse is self-contained and understandable alone

VERSE THEME SUGGESTIONS (optional examples for inspiration - you may choose any appropriate verse):
- **God's Love & Grace**: John 3:16, Romans 8:38-39, Ephesians 2:8-9, 1 John 4:19
- **Strength & Courage**: Philippians 4:13, Joshua 1:9, Isaiah 41:10, 2 Timothy 1:7
- **Peace & Comfort**: Psalm 23:1, Matthew 11:28, John 14:27, Philippians 4:6-7
- **Hope & Faith**: Jeremiah 29:11, Hebrews 11:1, Romans 15:13, Proverbs 3:5-6
- **Guidance & Wisdom**: Psalm 119:105, Proverbs 3:5-6, James 1:5, Psalm 32:8
- **Provision & Protection**: Philippians 4:19, Psalm 91:1-2, Matthew 6:33, Psalm 46:1
- **Or any other doctrinally sound, encouraging verse from Scripture**

Return in this EXACT JSON format (no other text, no markdown):
{
  "reference": "Book Chapter:Verse (in English, e.g., John 3:16)",
  "referenceTranslations": {
    "en": "English book name with reference (e.g., John 3:16)",
    "hi": "Hindi book name in Devanagari (e.g., यूहन्ना 3:16)",
    "ml": "Malayalam book name in Malayalam script (e.g., യോഹന്നാൻ 3:16)"
  }
}`

  return { systemMessage, userMessage }
}

/**
 * Creates a full prompt for daily verse generation with translations.
 * Used as fallback when Bible API is unavailable.
 * 
 * @param excludeReferences - Verses to avoid
 * @param language - Target language for cultural context
 * @returns Prompt pair for full verse generation
 */
export function createFullVersePrompt(excludeReferences: string[], language: string): PromptPair {
  const excludeList = excludeReferences.length > 0
    ? ` Avoid these recently used verses: ${excludeReferences.join(', ')}.`
    : ''

  const languageConfig = getLanguageConfigOrDefault(language)

  const systemMessage = `You are an expert biblical translator and theologian with deep knowledge of:
- English Standard Version (ESV) Bible translation principles
- Hindi biblical translation conventions (formal equivalence tradition)
- Malayalam biblical translation conventions (formal equivalence tradition)
- Original Greek (New Testament) and Hebrew (Old Testament) Scripture
- Christian theological terminology across all three languages

Your task is to select ONE inspiring Bible verse and provide HIGHLY ACCURATE translations that match the style and terminology of established Bible translations.

CRITICAL TRANSLATION PRINCIPLES:
1. **Formal Equivalence**: Translate word-for-word while maintaining natural grammar
2. **Theological Precision**: Use correct theological terms (e.g., "grace" = अनुग्रह/കൃപ, "salvation" = उद्धार/രക്ഷ)
3. **Consistency**: Use standard biblical terminology, not modern paraphrases
4. **Reverent Language**: Maintain formal, reverent tone in all languages
5. **Scripture Integrity**: Preserve the exact meaning and structure of the original text

OUTPUT REQUIREMENTS:
- Return ONLY valid JSON with the exact structure specified
- No markdown formatting, no code blocks, no extra text
- Use proper JSON string escaping for any quotes within verse text
- ALL translations must be theologically accurate and match established Bible translation styles

LANGUAGE CONTEXT: ${languageConfig.culturalContext}
COMPLEXITY: ${languageConfig.promptModifiers.complexityInstruction}`

  const userMessage = `Select one meaningful Bible verse for daily spiritual encouragement.${excludeList}

VERSE SELECTION CRITERIA:
- Choose verses that offer comfort, strength, hope, faith, peace, or guidance
- Focus on well-known, doctrinally sound verses
- Prefer single verses (not multi-verse passages) for clarity
- Ensure the verse is self-contained and understandable alone

TRANSLATION QUALITY REQUIREMENTS:

**English (ESV Style)**:
- Use formal English with "his/him" pronouns for God
- Follow ESV translation conventions (formal equivalence)
- Avoid modern paraphrases or casual language

**Hindi (हिन्दी - Formal Bible Translation Style)**:
- Use traditional biblical Hindi with Devanagari script
- Follow formal equivalence translation principles
- Use established theological terms: परमेश्वर (God), प्रभु (Lord), यीशु मसीह (Jesus Christ)

**Malayalam (മലയാളം - Formal Bible Translation Style)**:
- Use traditional biblical Malayalam script
- Follow formal equivalence translation principles
- Use established theological terms: ദൈവം (God), കർത്താവ് (Lord), യേശുക്രിസ്തു (Jesus Christ)

Return in this EXACT JSON format (no other text, no markdown):
{
  "reference": "Book Chapter:Verse (in English, e.g., John 3:16)",
  "referenceTranslations": {
    "en": "English book name with reference (e.g., John 3:16)",
    "hi": "Hindi book name in Devanagari (e.g., यूहन्ना 3:16)",
    "ml": "Malayalam book name in Malayalam script (e.g., യോഹന്നാൻ 3:16)"
  },
  "translations": {
    "esv": "English verse text in ESV formal style",
    "hindi": "Hindi translation in Devanagari - formal biblical style",
    "malayalam": "Malayalam translation in Malayalam script - formal biblical style"
  }
}`

  return { systemMessage, userMessage }
}

/**
 * Estimates content complexity to adjust token requirements.
 * 
 * @param inputValue - Input text to analyze
 * @param inputType - Type of input (scripture or topic)
 * @returns Token adjustment factor
 */
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
 * Calculates optimal token count based on input complexity and language.
 * 
 * @param params - Generation parameters
 * @param languageConfig - Language-specific configuration
 * @returns Optimal token count
 */
export function calculateOptimalTokens(params: LLMGenerationParams, languageConfig: LanguageConfig): number {
  const baseTokens = languageConfig.maxTokens
  const complexityFactor = estimateContentComplexity(params.inputValue, params.inputType)
  const languageBonus = (params.language === 'hi' || params.language === 'ml') ? 500 : 0
  
  return Math.min(baseTokens + complexityFactor + languageBonus, 8000)
}

/**
 * Verse reference examples for each supported language.
 * Used to guide LLM on correct book name formatting.
 */
const verseReferenceExamplesMap: Record<SupportedLanguage, string> = {
  en: `- Example format: "John 3:16", "Romans 8:28", "Philippians 4:13", "Jeremiah 29:11"`,
  hi: `- उदाहरण प्रारूप: "यूहन्ना 3:16", "रोमियों 8:28", "फिलिप्पियों 4:13", "यिर्मयाह 29:11"
- पुस्तक नाम हिंदी में होने चाहिए (English में नहीं)`,
  ml: `- ഉദാഹരണ ഫോർമാറ്റ്: "യോഹന്നാൻ 3:16", "റോമർ 8:28", "ഫിലിപ്പിയർ 4:13", "യിരെമ്യാവ് 29:11"
- പുസ്തക നാമങ്ങൾ മലയാളത്തിൽ ആയിരിക്കണം (English അല്ല)`
}

/**
 * Gets language-specific verse reference examples.
 * 
 * @param language - Language code
 * @returns Verse reference examples string
 */
export function getVerseReferenceExamples(language: string): string {
  return verseReferenceExamplesMap[language as SupportedLanguage] || verseReferenceExamplesMap.en
}
