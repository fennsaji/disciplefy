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
- BEGIN with a direct, biblically grounded answer to the question in the "summary" section
- Support your answer with relevant scripture passages throughout
- Address common misconceptions if applicable in the "interpretation" section
- Include practical applications of the biblical teaching in "reflectionQuestions"
- Maintain theological accuracy and pastoral sensitivity
- The "summary" should immediately answer the question, not just introduce the topic
- Use "interpretation" to provide deeper biblical support and theological reasoning
`
  } else if (inputType === 'scripture') {
    specificInstructions = `
SCRIPTURE-SPECIFIC REQUIREMENTS:
- Focus on explaining the meaning and significance of the biblical passage
- Provide the FULL SCRIPTURE TEXT in the "summary" section
- Break down the passage verse-by-verse or section-by-section in "interpretation"
- Explain historical and literary context in the "context" section
- Connect the passage to broader biblical themes through "relatedVerses"
- Apply the scripture's teaching to modern life in "reflectionQuestions"
- Make the biblical text accessible and personally relevant
`
  } else if (inputType === 'topic') {
    specificInstructions = `
TOPIC-SPECIFIC REQUIREMENTS:
- Provide comprehensive biblical teaching on the topic
- Survey key scripture passages that address the topic
- Organize content thematically in the "interpretation" section
- Explain the biblical foundation of the topic with theological depth
- Connect topic to practical Christian living in "reflectionQuestions"
- Address how the topic relates to spiritual growth and discipleship
`
  }

  // Language-specific verse reference examples
  const verseReferenceExamples = getVerseReferenceExamples(params.language)

  return `TASK: ${taskDescription}

CRITICAL: ALL 14 FIELDS BELOW ARE MANDATORY - DO NOT SKIP ANY FIELD

REQUIRED JSON OUTPUT FORMAT (include ALL fields, no exceptions):
{
  "summary": "Brief overview (2-3 sentences) capturing the main message${inputType === 'question' ? ' and answering the question' : ''}",
  "interpretation": "Theological interpretation (4-5 paragraphs) explaining meaning and key teachings${inputType === 'question' ? ' with direct answer to the question' : ''}",
  "context": "Historical and cultural background (1-2 paragraphs) for understanding",
  "relatedVerses": ["3-5 relevant Bible verses with references in ${languageConfig.name}"],
  "reflectionQuestions": ["4-6 practical application questions"],
  "prayerPoints": ["A complete, first-person prayer (5-7 sentences) addressing God directly that users can pray along with or personalize. Start with addressing God (e.g., 'Heavenly Father', 'Lord', 'Father God') and end with 'Amen' or 'In Jesus' name, Amen'"],
  "summaryInsights": ["MANDATORY: 3-4 key resonance themes (10-15 words each)"],
  "interpretationInsights": ["MANDATORY: 3-4 key theological insights (10-15 words each)"],
  "reflectionAnswers": ["MANDATORY: 3-4 actionable life application responses (10-15 words each)"],
  "contextQuestion": "Yes/no question connecting historical context to modern life",
  "summaryQuestion": "Engaging question about what resonates from the summary (8-12 words)",
  "relatedVersesQuestion": "Question prompting verse selection or memorization (8-12 words)",
  "reflectionQuestion": "Question connecting theological insights to daily life (8-12 words)",
  "prayerQuestion": "Question inviting personal prayer response (6-10 words)"
}

REQUIREMENT VERIFICATION:
✓ You MUST include summaryInsights array with 3-4 items
✓ You MUST include reflectionAnswers array with 3-4 items
✓ Do NOT skip any of the 14 required fields above

CRITICAL: PRAYER FORMAT REQUIREMENT
- "prayerPoints" MUST contain a complete, first-person prayer (NOT bullet points)
- The prayer should be 5-7 sentences addressing God directly (e.g., "Heavenly Father, I come before You...")
- End the prayer with "Amen" or "In Jesus' name, Amen"
- Users will listen to, read, or personalize this prayer during their study
- Example structure: [Address God] + [Prayer requests based on study content] + [Closing]
- MUST be output in ${languageConfig.name} language${specificInstructions}

CRITICAL: SUMMARY CARD INSIGHTS
Generate 3-4 brief, relatable themes that readers might resonate with from the summary:
- MUST be output in ${languageConfig.name} language
- Each insight should be 10-15 words maximum
- Focus on emotional/spiritual resonance (strength, comfort, challenge, hope, conviction)
- Make them personal and action-oriented
- English examples (TRANSLATE to ${languageConfig.name}): "Finding courage to face uncertainty", "Experiencing God's peace in chaos"
- CRITICAL: Output these insights in ${languageConfig.name}

CRITICAL: INTERPRETATION INSIGHTS & CONTEXT QUESTION
- MUST be output in ${languageConfig.name} language
- "interpretationInsights" must extract 3-4 distinct, actionable insights from the interpretation
- Each insight should be concise (10-15 words), theologically sound, and personally applicable
- Insights should represent different aspects: God's character, human response, practical application, doctrinal truth
- "contextQuestion" must be yes/no format, connecting the biblical situation to modern experience
- English example for context question (TRANSLATE to ${languageConfig.name}): "Have you ever felt pressure to conform like the early Christians?"
- CRITICAL: Output these insights and question in ${languageConfig.name}

CRITICAL: REFLECTION CARD QUESTIONS
Generate contextually appropriate questions for each reflection card interaction:
1. "summaryQuestion": Ask what aspect of the summary resonates most with the reader
   - Example: "क्या इस सारांश में आपको सबसे प्रभावशाली लगा?" (What impacted you most in this summary?)
   - Should be warm, inviting, and encourage personal connection with the summary

2. "relatedVersesQuestion": Encourage verse selection for further study or memorization
   - Example: "कौन सी आयत आप याद रखना चाहेंगे?" (Which verse would you like to memorize?)
   - Should inspire scripture engagement and memory

3. "reflectionQuestion": Connect the theological teachings to daily life application
   - Example: "आज आप इसे अपने जीवन में कैसे लागू करेंगे?" (How will you apply this today?)
   - Should bridge biblical truth to practical modern living

4. "prayerQuestion": Invite personal prayer based on the study content
   - Example: "आप इस अध्ययन के लिए कैसे प्रार्थना करना चाहेंगे?" (How would you like to pray about this study?)
   - Should be warm and encourage authentic prayer response

All reflection questions must be:
- In the study guide's language (Hindi/Malayalam/English)
- Contextually relevant to the actual content studied
- Open-ended to encourage thoughtful reflection
- 6-12 words maximum for clarity and readability

CRITICAL: REFLECTION ANSWERS
Generate 3-4 actionable life application responses that complement "reflectionQuestion":
- MUST be output in ${languageConfig.name} language
- Each answer should be practical, specific, and immediately applicable (10-15 words)
- Focus on different life domains: relationships, habits, mindset shifts, spiritual practices
- Make them concrete actions readers can take today based on the study content
- English examples (TRANSLATE to ${languageConfig.name}): "Practicing forgiveness in my relationships", "Setting aside time for daily prayer", "Choosing gratitude in difficult circumstances"
- CRITICAL: Output these answers in ${languageConfig.name}

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
  let inputSpecificGuidance = ''

  if (inputType === 'scripture') {
    taskDescription = `Create a QUICK 3-minute Bible study for: "${inputValue}"`
    inputSpecificGuidance = `
SCRIPTURE FOCUS (Quick Read):
- Include the scripture passage text in "summary"
- Explain the key insight from the passage in "interpretation"
- Keep explanation brief and immediately applicable`
  } else if (inputType === 'topic') {
    taskDescription = topicDescription
      ? `Create a QUICK 3-minute Bible study on: "${inputValue}"\n\nContext: ${topicDescription}`
      : `Create a QUICK 3-minute Bible study on: "${inputValue}"`
    inputSpecificGuidance = `
TOPIC FOCUS (Quick Read):
- Provide one key biblical principle about the topic in "summary"
- Support with one main scripture in "interpretation"
- Focus on immediate practical takeaway`
  } else {
    taskDescription = `Answer briefly and create a QUICK 3-minute study for: "${inputValue}"`
    inputSpecificGuidance = `
QUESTION FOCUS (Quick Read):
- Provide a direct, concise answer to the question in "summary"
- Support answer with one key scripture in "interpretation"
- Keep response clear and immediately helpful`
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
${inputSpecificGuidance}

CRITICAL: ALL 14 FIELDS BELOW ARE MANDATORY - DO NOT SKIP ANY FIELD

QUICK READ FORMAT - REQUIRED JSON OUTPUT (include ALL fields, no exceptions):
{
  "summary": "ONE powerful key insight in 2-3 sentences - the main takeaway",
  "interpretation": "Key verse with brief explanation: [Reference]: [Verse text]. [1-2 sentence explanation]",
  "context": "Brief context (1-2 sentences) - keep minimal for quick reading",
  "relatedVerses": ["Include ONLY the single most relevant verse with reference in ${languageConfig.name}"],
  "reflectionQuestions": ["ONE practical reflection question for immediate application"],
  "prayerPoints": ["A brief, complete first-person prayer (2-3 sentences) addressing God directly. Start with addressing God and end with 'Amen'"],
  "summaryInsights": ["MANDATORY: 2-3 brief resonance themes (8-12 words each)"],
  "interpretationInsights": ["MANDATORY: 2-3 brief action points (8-12 words)"],
  "reflectionAnswers": ["MANDATORY: 2-3 brief action responses (8-12 words each)"],
  "contextQuestion": "Simple yes/no question for daily life",
  "summaryQuestion": "Brief question about what resonates (6-10 words)",
  "relatedVersesQuestion": "Simple question about verse memorization (6-10 words)",
  "reflectionQuestion": "Quick application question for daily life (6-10 words)",
  "prayerQuestion": "Inviting prayer question (5-8 words)"
}

REQUIREMENT VERIFICATION:
✓ You MUST include summaryInsights array with 2-3 items
✓ You MUST include reflectionAnswers array with 2-3 items
✓ Do NOT skip any of the 14 required fields above

CRITICAL RULES FOR QUICK READ:
- Keep EVERYTHING concise - this is a 3-minute study
- "interpretation" must include the key verse text with its reference
- Only ONE item in each array field
- Focus on immediate practical takeaway

CRITICAL: PRAYER FORMAT (Quick Read)
- "prayerPoints" MUST contain ONE complete, brief first-person prayer (2-3 sentences)
- Address God directly and close with "Amen"
- Users will pray along with this prayer
- MUST be output in ${languageConfig.name} language

CRITICAL: SUMMARY CARD INSIGHTS (Quick Read)
Generate 2-3 brief themes readers might resonate with:
- MUST be output in ${languageConfig.name} language
- Each insight 8-12 words maximum
- Focus on immediate application (strength, comfort, encouragement)
- English examples (TRANSLATE to ${languageConfig.name}): "Finding daily strength", "Experiencing peace today"
- CRITICAL: Output these insights in ${languageConfig.name}

CRITICAL: INTERPRETATION INSIGHTS & CONTEXT QUESTION (Quick Read)
- MUST be output in ${languageConfig.name} language
- "interpretationInsights" must extract 2-3 brief, actionable points from the interpretation
- Each insight should be concise (8-12 words) and immediately applicable
- Insights should be simple and direct for quick daily application
- "contextQuestion" must be yes/no format, simple and relatable to daily life
- English example for context question (TRANSLATE to ${languageConfig.name}): "Do you face similar pressures in your daily life?"
- CRITICAL: Output these insights and question in ${languageConfig.name}

CRITICAL: REFLECTION ANSWERS (Quick Read)
Generate 2-3 brief action responses for immediate daily application:
- MUST be output in ${languageConfig.name} language
- Each answer should be simple, concrete, and doable today (8-12 words)
- Focus on immediate actions: attitude shifts, quick habits, simple choices
- English examples (TRANSLATE to ${languageConfig.name}): "Choosing patience today", "Pausing to pray before reacting"
- CRITICAL: Output these answers in ${languageConfig.name}

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
  let inputSpecificGuidance = ''

  if (inputType === 'scripture') {
    taskDescription = `Create a COMPREHENSIVE Deep Dive Bible study for: "${inputValue}"`
    inputSpecificGuidance = `
SCRIPTURE FOCUS (Deep Dive):
- Provide the FULL scripture text with verse-by-verse breakdown in "summary"
- Include word studies (Greek/Hebrew) for key terms in the passage in "interpretation"
- Analyze literary structure, grammar, and theological themes
- Explore cross-references that illuminate the passage
- Provide comprehensive application from the text`
  } else if (inputType === 'topic') {
    taskDescription = topicDescription
      ? `Create a COMPREHENSIVE Deep Dive Bible study on: "${inputValue}"\n\nContext: ${topicDescription}`
      : `Create a COMPREHENSIVE Deep Dive Bible study on: "${inputValue}"`
    inputSpecificGuidance = `
TOPIC FOCUS (Deep Dive):
- Survey major scripture passages addressing the topic in "summary"
- Provide theological exposition of biblical teaching on the topic in "interpretation"
- Include doctrinal implications and systematic theology connections
- Explore historical development of the topic in church history
- Provide comprehensive application for Christian living`
  } else {
    taskDescription = `Provide a thorough answer and create a COMPREHENSIVE Deep Dive study for: "${inputValue}"`
    inputSpecificGuidance = `
QUESTION FOCUS (Deep Dive):
- Provide a comprehensive, theologically robust answer to the question in "summary"
- Support answer with detailed biblical exposition in "interpretation"
- Address multiple perspectives and theological nuances
- Include relevant cross-references and doctrinal connections
- Provide practical implications of the biblical answer`
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
${inputSpecificGuidance}

CRITICAL: ALL 14 FIELDS BELOW ARE MANDATORY - DO NOT SKIP ANY FIELD

DEEP DIVE FORMAT - REQUIRED JSON OUTPUT (include ALL fields, no exceptions):
{
  "summary": "Comprehensive overview (4-5 sentences) with key themes and scholarly insights",
  "interpretation": "In-depth theological interpretation (6-8 paragraphs) including:\\n\\n**Word Studies:**\\n- Include 2-3 Greek/Hebrew words with transliterations and meanings\\n- Explain theological significance of key terms\\n\\n**Doctrinal Implications:**\\n- Explore theological depth and application",
  "context": "Extended historical, cultural, and literary context (3-4 paragraphs) including:\\n\\n**Cross-References:**\\n- Include 5-8 related passages with brief explanations of connections\\n- Show how other Scriptures illuminate this passage",
  "relatedVerses": ["5-8 relevant Bible verses with references in ${languageConfig.name} - include a brief note on each connection"],
  "reflectionQuestions": ["6-8 deep, thought-provoking questions including one journaling prompt at the end"],
  "prayerPoints": ["A comprehensive, first-person prayer (7-9 sentences) addressing God directly, incorporating the key theological themes from the study. Start with addressing God and end with 'In Jesus' name, Amen'"],
  "interpretationInsights": ["MANDATORY: 4-5 profound insights from word studies and doctrinal implications (12-18 words)"],
  "summaryInsights": ["MANDATORY: 4-5 profound resonance themes (12-18 words)"],
  "reflectionAnswers": ["MANDATORY: 4-5 transformative life application responses (12-18 words each)"],
  "contextQuestion": "Nuanced yes/no question connecting biblical context to contemporary issues",
  "summaryQuestion": "Thoughtful question about the comprehensive summary (10-15 words)",
  "relatedVersesQuestion": "Question encouraging verse study and cross-reference exploration (10-15 words)",
  "reflectionQuestion": "Deep application question connecting theology to life transformation (10-15 words)",
  "prayerQuestion": "Contemplative question inviting extended prayer response (8-12 words)"
}

REQUIREMENT VERIFICATION:
✓ You MUST include summaryInsights array with 4-5 items
✓ You MUST include reflectionAnswers array with 4-5 items
✓ Do NOT skip any of the 14 required fields above

CRITICAL CONTENT REQUIREMENTS FOR DEEP DIVE:
- "interpretation" MUST include word study section with Greek/Hebrew terms
- "context" MUST include cross-reference connections
- Each section should be substantially longer than standard study
- Include scholarly insights while remaining accessible
- Last item in "reflectionQuestions" should be a journaling prompt

CRITICAL: PRAYER FORMAT (Deep Dive)
- "prayerPoints" MUST contain a comprehensive, first-person prayer (7-9 sentences)
- Incorporate key theological themes from the study in the prayer
- Address God directly and close with "In Jesus' name, Amen"
- Users will pray along with or personalize this prayer
- MUST be output in ${languageConfig.name} language

CRITICAL: INTERPRETATION INSIGHTS & CONTEXT QUESTION (Deep Dive)
- MUST be output in ${languageConfig.name} language
- "interpretationInsights" must extract 4-5 profound theological insights from word studies and doctrinal content
- Each insight should be substantial (12-18 words), theologically rich, and intellectually engaging
- Insights should reflect the scholarly depth of Deep Dive mode (original language insights, doctrinal implications)
- "contextQuestion" must be yes/no format, nuanced and connecting ancient context to contemporary issues
- English example for context question (TRANSLATE to ${languageConfig.name}): "Have you experienced the tension between cultural expectations and biblical faithfulness?"
- CRITICAL: Output these insights and question in ${languageConfig.name}

CRITICAL: SUMMARY CARD INSIGHTS (Deep Dive)
Generate 4-5 profound themes readers might resonate with from the comprehensive summary:
- MUST be output in ${languageConfig.name} language
- Each insight should be substantial (12-18 words), theologically rich, and emotionally resonant
- Focus on deep spiritual formation (transformation, conviction, theological understanding, spiritual maturity)
- Make them intellectually engaging yet personally applicable
- English examples (TRANSLATE to ${languageConfig.name}): "Understanding God's sovereignty through historical redemption", "Experiencing transformation through doctrinal truth applied to daily life"
- CRITICAL: Output these insights in ${languageConfig.name}

CRITICAL: REFLECTION ANSWERS (Deep Dive)
Generate 4-5 transformative life application responses from the study:
- MUST be output in ${languageConfig.name} language
- Each answer should be substantial, theologically grounded, and transformative (12-18 words)
- Focus on character transformation, doctrinal convictions lived out, spiritual disciplines, kingdom priorities
- English examples (TRANSLATE to ${languageConfig.name}): "Cultivating daily dependence on God through morning prayer and meditation", "Reordering priorities to reflect kingdom values over worldly success"
- CRITICAL: Output these answers in ${languageConfig.name}

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
  let inputSpecificGuidance = ''

  if (inputType === 'scripture') {
    taskDescription = `Create a Lectio Divina meditation guide for: "${inputValue}"`
    inputSpecificGuidance = `
SCRIPTURE FOCUS (Lectio Divina):
- Provide the FULL scripture passage text for slow, meditative reading in "summary"
- Guide the reader through contemplative reflection on the passage
- Invite personal encounter with God through the text`
  } else if (inputType === 'topic') {
    taskDescription = topicDescription
      ? `Create a Lectio Divina meditation guide on: "${inputValue}"\n\nContext: ${topicDescription}`
      : `Create a Lectio Divina meditation guide on: "${inputValue}"`
    inputSpecificGuidance = `
TOPIC FOCUS (Lectio Divina):
- Select a key scripture passage that addresses the topic for meditation in "summary"
- Guide contemplative reflection on how God speaks through this passage about the topic
- Invite listening prayer and personal response to God's word on this topic`
  } else {
    taskDescription = `Create a Lectio Divina meditation guide for: "${inputValue}"`
    inputSpecificGuidance = `
QUESTION FOCUS (Lectio Divina):
- Select a scripture passage that addresses the question for meditation in "summary"
- Guide contemplative listening for how God speaks to the question through His Word
- Invite prayerful response and personal application of God's answer`
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
${inputSpecificGuidance}

CRITICAL: ALL 14 FIELDS BELOW ARE MANDATORY - DO NOT SKIP ANY FIELD
ABSOLUTELY REQUIRED: "summary" AND "interpretation" are BOTH mandatory and serve DIFFERENT purposes

LECTIO DIVINA FORMAT - REQUIRED JSON OUTPUT (include ALL fields, no exceptions):
{
  "summary": "**Scripture for Meditation**\\n\\n[Reference in ${languageConfig.name}]\\n\\n[Complete scripture passage text]\\n\\n*Read this passage slowly 2-3 times, letting the words wash over you.*\\n\\n**Focus Words for Meditation:** [List 5-7 significant words or phrases from the passage that invite deeper reflection]",
  "interpretation": "**LECTIO (Read) & MEDITATIO (Meditate)**\\n\\nLECTIO: [Guidance for slow, attentive reading - NOT the scripture text itself]\\n\\nMEDITATIO: [Guidance for pondering and meditation - NOT the scripture text itself]\\n\\nAs you read again slowly, notice which word or phrase catches your attention. This is the Spirit inviting you to pause and receive.",
  "context": "**About Lectio Divina**\\n\\nLectio Divina (divine reading) is an ancient Christian practice dating back to the 3rd century. It invites us to move from reading about God to encountering God through His Word. There are four movements: Lectio (read), Meditatio (meditate), Oratio (pray), and Contemplatio (rest).\\n\\nApproach this time with an open heart, free from agenda. Let God speak to you through His Word.",
  "relatedVerses": ["Include 3-5 related Bible verse references that complement this meditation in ${languageConfig.name}"],
  "reflectionQuestions": ["**ORATIO (Pray)** - A prayer starter to respond to God based on the passage...", "What is God inviting you to in this Word?", "How might this passage shape your day?", "**CONTEMPLATIO (Rest)** - Rest in God's presence. Sit in silence for 2-3 minutes, simply being with God, letting go of words and thoughts."],
  "prayerPoints": ["A gentle, contemplative first-person prayer (3-4 sentences) that responds to the Scripture meditation. Format as a prayer template users can personalize and pray. Start with addressing God gently (e.g., 'Father', 'Loving God') and close with 'Amen'"],
  "interpretationInsights": ["MANDATORY: 2-3 contemplative insights for reflection (8-12 words)"],
  "summaryInsights": ["MANDATORY: 2-3 gentle resonance themes (8-12 words)"],
  "reflectionAnswers": ["MANDATORY: 2-3 gentle responses to God's invitation (8-12 words each)"],
  "contextQuestion": "Gentle yes/no question inviting personal reflection",
  "summaryQuestion": "Gentle question about what draws attention in the passage (8-12 words)",
  "relatedVersesQuestion": "Inviting question about which related verse to meditate on (8-12 words)",
  "reflectionQuestion": "Contemplative question about God's invitation (8-12 words)",
  "prayerQuestion": "Gentle question encouraging prayer response (6-10 words)"
}

REQUIREMENT VERIFICATION:
✓ You MUST include summaryInsights array with 2-3 items
✓ You MUST include reflectionAnswers array with 2-3 items
✓ Do NOT skip any of the 14 required fields above

CRITICAL CONTENT REQUIREMENTS FOR LECTIO DIVINA:
- "summary": MUST include the ACTUAL SCRIPTURE TEXT (not guidance) formatted for slow reading, PLUS a list of 5-7 focus words/phrases for meditation at the end
- "interpretation": MUST provide GUIDANCE for LECTIO and MEDITATIO movements (NOT the scripture text - that goes in "summary")
- BOTH "summary" and "interpretation" are MANDATORY - they serve different purposes and cannot be combined
- "relatedVerses" should be 3-5 related Bible verse REFERENCES (e.g., "Psalm 23:1", "John 14:27") that complement the meditation
- "reflectionQuestions" must include ORATIO and CONTEMPLATIO movements
- Use meditative, gentle, inviting language throughout

CRITICAL: PRAYER FORMAT (Lectio Divina)
- "prayerPoints" MUST contain a gentle, contemplative first-person prayer (3-4 sentences)
- The prayer should respond to the Scripture meditation
- Format as a prayer template users can personalize and pray along with
- Address God gently (e.g., "Father", "Loving God") and close with "Amen"
- Use contemplative, receptive language that invites personal response
- MUST be output in ${languageConfig.name} language

CRITICAL: INTERPRETATION INSIGHTS & CONTEXT QUESTION (Lectio Divina)
- MUST be output in ${languageConfig.name} language
- "interpretationInsights" must extract 2-3 gentle, contemplative insights from the meditation
- Each insight should be brief (8-12 words), spiritually nurturing, and invitation-focused
- Insights should reflect the contemplative nature of Lectio Divina (listening, receiving, resting)
- "contextQuestion" must be yes/no format, gentle and inviting personal reflection on God's presence
- English example for context question (TRANSLATE to ${languageConfig.name}): "Have you felt God inviting you to slow down and listen?"
- CRITICAL: Output these insights and question in ${languageConfig.name}

CRITICAL: SUMMARY CARD INSIGHTS (Lectio Divina)
Generate 2-3 gentle themes readers might resonate with from the Scripture meditation:
- MUST be output in ${languageConfig.name} language
- Each insight should be brief (8-12 words), spiritually nurturing, and invitation-focused
- Focus on contemplative receptivity (listening to God, resting in His presence, receiving His love)
- Make them gentle and encouraging, reflecting the meditative nature of Lectio Divina
- English examples (TRANSLATE to ${languageConfig.name}): "Resting in God's loving presence", "Receiving God's word as gift today"
- CRITICAL: Output these insights in ${languageConfig.name}

CRITICAL: REFLECTION ANSWERS (Lectio Divina)
Generate 2-3 gentle responses to God's invitation from the meditation:
- MUST be output in ${languageConfig.name} language
- Each answer should be contemplative, receptive, and invitation-focused (8-12 words)
- Focus on spiritual receptivity: listening, resting, receiving, surrendering, abiding
- English examples (TRANSLATE to ${languageConfig.name}): "Sitting in silence with God daily", "Letting go of control and trusting"
- CRITICAL: Output these answers in ${languageConfig.name}

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
