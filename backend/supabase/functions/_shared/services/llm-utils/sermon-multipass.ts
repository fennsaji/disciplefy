/**
 * Multi-Pass Sermon Generation - Preacher-Facing Explanation
 *
 * Breaks sermon generation into 4 passes to work within model token limits:
 * - Pass 1: Summary + Context + Passage + Intro + Point 1 (~1,800 words)
 * - Pass 2: Point 2 only (~1,200 words)
 * - Pass 3: Point 3 only (~900 words)
 * - Pass 4: Conclusion + Altar Call + Supporting Fields (~1,100 words)
 *
 * Total target: 4,500-5,350 words (preacher-facing explanation, not full manuscript)
 * Preachers will expand this core content to 50-60 minutes during live delivery.
 */

import { type LLMGenerationParams, type LanguageConfig, type CacheablePromptPair } from '../llm-types.ts'
import {
  createSharedFoundation,
  createVerseReferenceBlock,
  getSermonHeadings,
  getWordCountTarget,
  getLanguageExamples
} from './prompt-builder.ts'

export type SermonPass = 'pass1' | 'pass2' | 'pass3' | 'pass4'

export interface SermonPassResult {
  pass: SermonPass
  content: string
}

/**
 * Creates the first pass prompt: Summary + Context + Interpretation (Intro + Point 1)
 */
export function createSermonPass1Prompt(
  params: LLMGenerationParams,
  languageConfig: LanguageConfig
): CacheablePromptPair {
  const { inputType, inputValue, topicDescription, pathTitle, pathDescription, discipleLevel, language } = params
  const headings = getSermonHeadings(language)
  const wordTarget = getWordCountTarget(languageConfig, 'sermon')

  const sermonFormat = inputType === 'scripture' ? 'EXPOSITORY' : 'TOPICAL (3-Point)'
  const pathParts = [
    pathTitle ? `Part of Learning Path: ${pathTitle}` : '',
    pathDescription ? `Learning Path Goal: ${pathDescription}` : '',
  ].filter(Boolean).join('\n')
  const pathContext = pathParts ? `\n\n${pathParts}` : ''
  const taskDescription = inputType === 'scripture'
    ? `Create an ${sermonFormat} sermon outline for: "${inputValue}"`
    : `Create a ${sermonFormat} sermon outline on: "${inputValue}"${topicDescription ? `\n\nContext: ${topicDescription}` : ''}${pathContext}`

  const sharedSystem = createSharedFoundation(languageConfig, language, discipleLevel)

  const passSystem = `You are an experienced preacher creating sermon outlines for pastors.

STUDY MODE: SERMON OUTLINE - PASS 1/4 (Introduction + First Point)
This is part 1 of a 4-part PREACHER-FACING EXPLANATION (not full manuscript).
Target output: ${params.language === 'ml' ? '~600 words for Malayalam (STRICT token limit to avoid timeout)' : '~1,800 words'}
Tone: Theologically rich, pastorally wise, suitable for preacher preparation.`

  const userMessage = `${taskDescription}

${createVerseReferenceBlock(language)}

---
PASS 1/4: SERMON FOUNDATION (Summary + Context + Passage + Intro + Point 1)
---

Generate the following JSON structure with THESE SPECIFIC FIELDS ONLY:

{
  "summary": "[250-350 words: Sermon title, thesis statement, hook preview, key question, gospel connection]",
  "context": "[50-100 words: MINIMAL - essential Scripture background only]",
  "passage": "⚠️ MANDATORY - Scripture reference for meditation. PREFER LONGER PASSAGES (10-20+ verses) for substantial content (e.g., 'Romans 8:1-39', 'Psalm 119:1-24', 'Matthew 5:1-20'). Format: Just the reference in ${languageConfig.name}, no verse text. DO NOT skip this field.",
  "interpretationPart1": "[1450-1750 words: PREACHER-FACING EXPLANATION for Introduction (450-550 words with conceptual hook, bridge, preview, transition) + Point 1 (1000-1200 words with core teaching, 2-3 verses, conceptual illustration, focused applications, transition)]"
}

CRITICAL INSTRUCTIONS FOR PASS 1:

**SUMMARY (${params.language === 'ml' ? '100-130 words - Malayalam STRICT token limit' : '250-350 words'}):**

Write a COMPELLING sermon overview as CONTINUOUS NARRATIVE PROSE (NOT separate bullets).
This must be ${params.language === 'ml' ? '4-5' : '8-12'} complete sentences flowing together as a single paragraph.

Include these elements in flowing prose:
1. Begin with a compelling 3-6 word sermon title as the opening phrase
2. Thesis Statement: 1-2 sentences declaring the core message
3. Hook Preview: 2-3 sentences describing the conceptual hook (not full story)
4. Key Question: 1-2 sentences identifying the central question this sermon answers
5. Gospel Connection: 2-3 sentences showing how this message points to Christ

Structure (NOT literal text - write entirely in ${languageConfig.name}):
- Sentence 1: [Sermon title] + [proclaims the thesis statement]
- Sentences 2-3: [Declares the core message that will be preached]
- Sentences 4-6: [Previews the conceptual hook - the idea, not full story]
- Sentences 7-8: [Identifies the central question this sermon answers]
- Sentences 9-12: [Shows how this message points to Christ and the gospel]

CRITICAL:
- Write ENTIRELY in ${languageConfig.name} - NO English words mixed in
- Write as a SINGLE FLOWING PARAGRAPH of 8-12 sentences
- NOT as separate bullet points or title only

**CONTEXT (${params.language === 'ml' ? '30-40 words - Malayalam STRICT limit' : '50-100 words'}):**
Write MINIMAL essential Scripture background only (1 concise paragraph):
• Brief historical context (authorship, date, original audience)
• Literary genre and placement in Bible
• Core theological framework for understanding the passage
Keep it SHORT and FOCUSED - only what's necessary to understand the sermon text.

**INTERPRETATION PART 1 (${params.language === 'ml' ? '450-550 words - Malayalam STRICT limit' : '1450-1750 words'}):**

🚨 CRITICAL: You MUST generate BOTH Introduction AND Point 1 in this pass!
❌ DO NOT stop after Introduction - Point 1 is MANDATORY!
✅ interpretationPart1 = Introduction ${params.language === 'ml' ? '(150-200 words) + Point 1 (300-350 words)' : '(450-550 words) + Point 1 (1000-1200 words)'}
✅ BOTH sections REQUIRED in this single field!

${params.language === 'ml' ? '⚠️ MALAYALAM STRICT TIMEOUT LIMIT: Pass 1 limited to ~600 words total to avoid Edge Function timeout.\nYou MUST stay within this limit - quality over quantity for Malayalam.' : ''}

PREACHER-FACING: Core theological content + conceptual ideas (not full manuscript). 3-4 paragraphs/section. Conceptual illustrations. 2-3 verses/point. 3-4 focused applications. Pastors expand during delivery.

## ${headings.introduction} (${params.language === 'ml' ? '150-200 words' : '450-550 words'})

**Hook (Conceptual)** (${params.language === 'ml' ? '40-50 words' : '120-150 words'}): Provide a CONCEPTUAL hook idea (not full story):
- Real-life tension, question, or problem
- Cultural moment or observation
- Key statistic or research finding
Give the IDEA clearly - preacher will add details and personal stories during delivery.

**Bridge** (${params.language === 'ml' ? '60-80 words' : '180-220 words'}): Write ${params.language === 'ml' ? '1-2 concise paragraphs' : '2-3 concise paragraphs'} connecting life → text → Gospel theme:
- Why this message matters TODAY
- The pain point this addresses
- How God's Word speaks to this issue
Focus on CONCEPTUAL connection - preacher will add examples.

**Preview** (${params.language === 'ml' ? '30-40 words' : '100-120 words'}): Write 1 paragraph outlining sermon journey:
- State thesis clearly
- Preview 3 main points with titles
Make it CLEAR and MEMORABLE.

**${headings.transition}** (${params.language === 'ml' ? '20-30 words' : '50-60 words'}): One compelling paragraph bridging to Point 1.

## ${headings.point} 1: [Memorable Title]  (${params.language === 'ml' ? '300-350 words' : '1000-1200 words'})

**${headings.mainTeaching}** (${params.language === 'ml' ? '100-120 words' : '350-450 words'}): Write ${params.language === 'ml' ? '1-2 paragraphs' : '3-4 concise paragraphs'} with CORE theological exposition:
- Introduce the main theological truth
- Define key biblical terms and explain the doctrine
- Connect to Christ's person and work
Focus on CORE doctrinal claims - preachers will elaborate.

**${headings.scriptureFoundation}** (${params.language === 'ml' ? '80-100 words' : '300-350 words'}): List ${params.language === 'ml' ? '2 verses' : '2-3 key verses'} in ${languageConfig.name} with brief explanation (${params.language === 'ml' ? '40-50 words per verse' : '100-120 words per verse'}):
- Context: Who wrote, to whom, why (1 sentence)
- Meaning: Core truth this verse teaches (1-2 sentences)
- Connection: How it supports this point (1 sentence)
Keep CONCISE - avoid quoting long passages.

**${headings.illustration}** (Conceptual, ${params.language === 'ml' ? '40-50 words' : '150-200 words'}): Provide CONCEPTUAL illustration idea:
- Describe the type of story/example that works
- Key elements that make it powerful
- Connection point to doctrinal truth
Preacher will fill out full story during delivery.

**${headings.application}** (${params.language === 'ml' ? '40-50 words' : '180-220 words'}): Provide ${params.language === 'ml' ? '2 focused applications' : '3-4 focused applications'} (${params.language === 'ml' ? '20-25 words each' : '50-70 words each'}):
- Heart + Life application
- What needs to change internally
- What this looks like practically
Keep focused - preacher will add examples.

**${headings.transition}** (${params.language === 'ml' ? '20-30 words' : '50-70 words'}): One paragraph bridging to Point 2.

VERIFY BEFORE OUTPUT:
- summary: ${params.language === 'ml' ? '100-130' : '250-350'} words | context: ${params.language === 'ml' ? '30-40' : '50-100'} words | passage: reference ONLY (MANDATORY)
- interpretationPart1 MUST include BOTH Introduction (${params.language === 'ml' ? '150-200' : '450-550'} words) AND Point 1 (${params.language === 'ml' ? '300-350' : '1000-1200'} words) — DO NOT stop after Introduction!
- Total: ${params.language === 'ml' ? '~600 words (STRICT timeout limit)' : '~1,800 words'} | Verse refs in ${languageConfig.name} | Conceptual illustrations only
FIX any issues BEFORE output.

Generate FULL CONTENT - no literal "..." placeholders.

${getLanguageExamples(language)}

OUTPUT ONLY THIS JSON - NO OTHER TEXT:
{
  "summary": "[YOUR ${params.language === 'ml' ? '100-130' : '250-350'} WORD SUMMARY HERE]",
  "context": "[YOUR ${params.language === 'ml' ? '30-40' : '50-100'} WORD CONTEXT HERE]",
  "passage": "[Scripture reference ONLY - e.g., 'Romans 8:1-39' in ${languageConfig.name}]",
  "interpretationPart1": "[YOUR ${params.language === 'ml' ? '450-550' : '1450-1750'} WORD PREACHER-FACING EXPLANATION HERE - Introduction (conceptual hook, bridge, preview, transition) + Point 1 (core teaching, 2 verses, conceptual illustration, 2 applications, transition)]"
}`

  return { sharedSystem, passSystem, userMessage }
}

/**
 * Creates the second pass prompt: Interpretation (Point 2 ONLY)
 */
export function createSermonPass2Prompt(
  params: LLMGenerationParams,
  languageConfig: LanguageConfig,
  pass1Result: { summary: string; context: string; interpretationPart1: string }
): CacheablePromptPair {
  const { language, discipleLevel } = params
  const headings = getSermonHeadings(language)

  const sharedSystem = createSharedFoundation(languageConfig, language, discipleLevel)

  const passSystem = `You are an experienced preacher continuing a sermon manuscript.

STUDY MODE: SERMON OUTLINE - PASS 2/4 (Point 2 Only)
This is part 2 of a 4-part PREACHER-FACING EXPLANATION. Continue building on Pass 1.
Target output: ${params.language === 'ml' ? '~400 words for Malayalam (STRICT timeout limit)' : '~1,000-1,200 words'}
Provide CORE content that preachers will expand during delivery.`

  const userMessage = `---
PASS 2/4: MAIN TEACHING POINT 2 (Point 2 Only)
---

CONTEXT FROM PASS 1:
- Sermon Summary: ${pass1Result.summary.substring(0, 300)}...
- You already wrote: Introduction + Point 1 in Pass 1

NOW GENERATE Point 2 ONLY following the SAME STRUCTURE as Point 1.

Generate this JSON structure:

{
  "interpretationPart2": "[${params.language === 'ml' ? '400 words' : '1000-1200 words'}: Point 2 with core teaching, 2 verses, conceptual illustration, focused applications, and transition]"
}

**INTERPRETATION PART 2 (${params.language === 'ml' ? '400 words' : '1000-1200 words'}):**

PREACHER-FACING: Core content, conceptual illustrations, ${params.language === 'ml' ? '2 verses, 2 applications' : '2-3 verses, 3-4 applications'}. Pastors expand during delivery.

## ${headings.point} 2: [Memorable Title] (${params.language === 'ml' ? '400 words' : '1000-1200 words'})

Use ${params.language === 'ml' ? 'CONDENSED' : 'SAME'} STRUCTURE as Point 1:
- **${headings.mainTeaching}** (${params.language === 'ml' ? '120-150 words' : '350-450 words'}): ${params.language === 'ml' ? '1-2 concise paragraphs' : '3-4 concise paragraphs'} with core theological exposition
- **${headings.scriptureFoundation}** (${params.language === 'ml' ? '100-120 words' : '300-350 words'}): 2${params.language === 'ml' ? '' : '-3'} verses with brief explanations (${params.language === 'ml' ? '50-60 words' : '100-120 words'} each)
- **${headings.illustration}** (Conceptual, ${params.language === 'ml' ? '50-60 words' : '150-200 words'}): Conceptual illustration idea
- **${headings.application}** (${params.language === 'ml' ? '60-80 words' : '180-220 words'}): ${params.language === 'ml' ? '2 focused applications (30-40 words each)' : '3-4 focused applications (50-70 words each)'}
- **${headings.transition}** (${params.language === 'ml' ? '20-30 words' : '50-70 words'}): One paragraph bridging to Point 3

This is usually the theological weight center of the sermon.

VERIFY: Point 2 complete with all components (Main Teaching, Scripture, Illustration, Application, Transition) | ${params.language === 'ml' ? '~400 words (STRICT limit)' : '1000-1200 words'} | Verse refs in ${languageConfig.name} | Conceptual illustrations only. FIX any issues BEFORE output.

Generate FULL CONTENT - no literal "..." placeholders.

${getLanguageExamples(language)}

OUTPUT ONLY THIS JSON - NO OTHER TEXT:
{
  "interpretationPart2": "[YOUR 1000-1200 WORD PREACHER-FACING EXPLANATION HERE - Point 2 (core teaching, 2-3 verses, conceptual illustration, 3-4 applications, transition)]"
}`

  return { sharedSystem, passSystem, userMessage }
}

/**
 * Creates the third pass prompt: Interpretation (Point 3 ONLY)
 */
export function createSermonPass3Prompt(
  params: LLMGenerationParams,
  languageConfig: LanguageConfig,
  pass1Result: { summary: string },
  pass2Result: { interpretationPart2: string }
): CacheablePromptPair {
  const { language, discipleLevel } = params
  const headings = getSermonHeadings(language)

  const sharedSystem = createSharedFoundation(languageConfig, language, discipleLevel)

  const passSystem = `You are an experienced preacher continuing a sermon manuscript.

STUDY MODE: SERMON OUTLINE - PASS 3/4 (Point 3 Only)
This is part 3 of a 4-part PREACHER-FACING EXPLANATION. Continue building on Pass 1 and Pass 2.
Target output: ${params.language === 'ml' ? '~350 words for Malayalam (STRICT timeout limit)' : '~700-900 words'}
Provide CORE content that preachers will expand during delivery.`

  const userMessage = `---
PASS 3/4: FINAL TEACHING POINT (Point 3 Only)
---

CONTEXT FROM PREVIOUS PASSES:
- Sermon Summary: ${pass1Result.summary.substring(0, 300)}...
- You already wrote: Introduction + Point 1 (Pass 1) + Point 2 (Pass 2)

NOW GENERATE Point 3 ONLY following a ${params.language === 'ml' ? 'HIGHLY CONDENSED' : 'CONDENSED'} STRUCTURE.

Generate this JSON structure:

{
  "interpretationPart3": "[${params.language === 'ml' ? '350 words' : '700-900 words'}: Point 3 with core teaching, 2 verses, conceptual illustration, focused applications, and transition]"
}

**INTERPRETATION PART 3 (${params.language === 'ml' ? '350 words' : '700-900 words'}):**

PREACHER-FACING: Core content (${params.language === 'ml' ? 'highly condensed' : 'condensed'}), conceptual illustrations, ${params.language === 'ml' ? '2 verses, 2 applications' : '2-3 verses, 2-3 applications'}. Pastors expand during delivery.

## ${headings.point} 3: [Memorable Title] (${params.language === 'ml' ? '350 words' : '700-900 words'})

${params.language === 'ml' ? 'Highly condensed' : 'Condensed'} structure:
- **${headings.mainTeaching}** (${params.language === 'ml' ? '100-120 words' : '280-350 words'}): ${params.language === 'ml' ? '1-2 paragraphs' : '2-3 paragraphs'} with core teaching
- **${headings.scriptureFoundation}** (${params.language === 'ml' ? '80-100 words' : '220-260 words'}): 2${params.language === 'ml' ? '' : '-3'} verses with brief explanations (${params.language === 'ml' ? '40-50 words' : '80-100 words'} each)
- **${headings.illustration}** (Conceptual, ${params.language === 'ml' ? '50-60 words' : '120-150 words'}): Conceptual illustration idea
- **${headings.application}** (${params.language === 'ml' ? '60-80 words' : '120-150 words'}): 2${params.language === 'ml' ? '' : '-3'} strong applications (${params.language === 'ml' ? '30-40 words' : '50-70 words'} each)
- **${headings.transition}** (${params.language === 'ml' ? '20-30 words' : '40-60 words'}): Bridge to Conclusion

VERIFY: Point 3 complete with all components (Main Teaching, Scripture, Illustration, Application, Transition) | ${params.language === 'ml' ? '~350 words (STRICT limit)' : '700-900 words'} | Verse refs in ${languageConfig.name} | Conceptual illustrations only. FIX any issues BEFORE output.

Generate FULL CONTENT - no literal "..." placeholders.

${getLanguageExamples(language)}

OUTPUT ONLY THIS JSON - NO OTHER TEXT:
{
  "interpretationPart3": "[YOUR 700-900 WORD PREACHER-FACING EXPLANATION HERE - Point 3 (core teaching, 2-3 verses, conceptual illustration, 2-3 applications, transition)]"
}`

  return { sharedSystem, passSystem, userMessage }
}

/**
 * Creates the fourth pass prompt: Conclusion + Altar Call + Supporting Fields
 */
export function createSermonPass4Prompt(
  params: LLMGenerationParams,
  languageConfig: LanguageConfig,
  pass1Result: { summary: string }
): CacheablePromptPair {
  const { language, discipleLevel } = params
  const headings = getSermonHeadings(language)

  const sharedSystem = createSharedFoundation(languageConfig, language, discipleLevel)

  const passSystem = `You are an experienced preacher completing a sermon manuscript.

STUDY MODE: SERMON OUTLINE - PASS 4/4 (Conclusion + Altar Call + Extras)
This is the final part of a 4-part PREACHER-FACING EXPLANATION. Bring it home powerfully.
Target output: ${params.language === 'ml' ? '~550 words for Malayalam (STRICT timeout limit)' : '~1,100 words'}
Provide CORE conclusion and altar call outline that preachers will expand.`

  const userMessage = `---
PASS 4/4: CONCLUSION + INVITATION + SUPPORTING MATERIALS
---

CONTEXT FROM PREVIOUS PASSES:
- You already wrote: Introduction + Point 1 (Pass 1) + Point 2 (Pass 2) + Point 3 (Pass 3)
- Sermon Summary: ${pass1Result.summary.substring(0, 200)}...

NOW COMPLETE THE SERMON with conclusion, altar call, and supporting materials.

Generate this JSON structure (IMPORTANT: interpretationPart4 MUST be LAST for streaming):

{
  "relatedVerses": ["${params.language === 'ml' ? '3-4' : '5-7'} Bible verse REFERENCES ONLY in ${languageConfig.name} for further study (e.g., 'Acts 4:12', '1 Timothy 2:5-6') - NO verse text"],
  "reflectionQuestions": ["${params.language === 'ml' ? '3-4' : '5-7'} discussion questions mixing theology and application"],
  "prayerPoints": ["[${params.language === 'ml' ? '180-220 words' : '300-400 words'} ALTAR CALL OUTLINE with gospel recap, invitation, response options, prayer outline]"],
  "summaryInsights": ["[${params.language === 'ml' ? '3 sermon takeaways - 12-15 words each' : '5 sermon takeaways - 15-20 words each'}]"],
  "interpretationInsights": ["[${params.language === 'ml' ? '3 theological truths taught - 12-15 words each' : '5 theological truths taught - 15-20 words each'}]"],
  "reflectionAnswers": ["[${params.language === 'ml' ? '3 life applications - 12-15 words each' : '5 life applications - 15-20 words each'}]"],
  "contextQuestion": "[Yes/no question connecting biblical context to modern life]",
  "summaryQuestion": "[Question about sermon thesis - 10-15 words]",
  "relatedVersesQuestion": "[Question encouraging scripture study - 10-15 words]",
  "reflectionQuestion": "[Application question for reflection - 10-15 words]",
  "prayerQuestion": "[Invitation question encouraging commitment - 8-12 words]",
  "interpretationPart4": "[${params.language === 'ml' ? '220-250 words' : '350-450 words'}: Conclusion with summaries of all 3 points (${params.language === 'ml' ? '50-60 words each' : '80-100 words each'}) + gospel climax (${params.language === 'ml' ? '70-90 words' : '100-120 words'})]"
}

**INTERPRETATION PART 4 - CONCLUSION (${params.language === 'ml' ? '220-250 words' : '350-450 words'}):**

Core conclusion content (not full manuscript). Clear, memorable, gospel-centered.

## ${headings.conclusion}
4 paragraphs: Point 1 summary (${params.language === 'ml' ? '50-60' : '80-100'} words) → Point 2 summary (${params.language === 'ml' ? '50-60' : '80-100'} words) → Point 3 summary (${params.language === 'ml' ? '50-60' : '80-100'} words) → Gospel Climax (${params.language === 'ml' ? '70-90' : '100-120'} words, tie to Christ's finished work)

**PRAYER POINTS - ALTAR CALL OUTLINE (${params.language === 'ml' ? '180-220 words' : '300-400 words'} as single string):**

Write CONCISE altar call outline in paragraphs:

**${headings.gospelRecap}** (${params.language === 'ml' ? '70-90 words' : '120-150 words'}): Write ${params.language === 'ml' ? '1-2 concise paragraphs' : '2-3 concise paragraphs'} with clear gospel presentation:
- God's holiness and our sin
- Christ's substitutionary death and resurrection
- Call to repentance and faith
Keep it CLEAR and FOCUSED - preacher will add vivid language.

**${headings.theInvitation}** (${params.language === 'ml' ? '60-80 words' : '120-150 words'}): Write ${params.language === 'ml' ? '1-2 paragraphs' : '2-3 paragraphs'} with specific invitation:
- Direct invitation based on sermon theme
- Create urgency with grace
- Pastoral reassurance for those unsure
Preacher will expand with personal warmth.

**${headings.responseOptions}** (${params.language === 'ml' ? '30-40 words' : '50-70 words'}): List ${params.language === 'ml' ? '3-4' : '4-5'} clear response options:
• Come forward during closing song
• Raise hand for prayer
• Meet pastor after service
${params.language === 'ml' ? '' : '• Contact during the week\n'}• Fill out connection card

**${headings.closingPrayer}** (${params.language === 'ml' ? '40-50 words' : '60-80 words'}): Brief first-person prayer outline:
- Pray for those responding
- Pray for Spirit's work
- Pray for courage to obey
Preacher will expand into full prayer during delivery. End with Amen.

**SUPPORTING MATERIALS:**
- relatedVerses: ${params.language === 'ml' ? '3-4' : '5-7'} verse REFERENCES ONLY in ${languageConfig.name} (e.g., '2 Corinthians 5:21') - NO verse text
- reflectionQuestions: ${params.language === 'ml' ? '3-4' : '5-7'} discussion questions
- summaryInsights: ${params.language === 'ml' ? '3 takeaways (12-15 words each)' : '5 takeaways (15-20 words each)'}
- interpretationInsights: ${params.language === 'ml' ? '3 theological truths (12-15 words each)' : '5 theological truths (15-20 words each)'}
- reflectionAnswers: ${params.language === 'ml' ? '3 applications (12-15 words each)' : '5 applications (15-20 words each)'}
- 5 yes/no questions for engagement

VERIFY BEFORE OUTPUT:
- interpretationPart4: ${params.language === 'ml' ? '220-250' : '350-450'} words (4 paragraphs: 3 point summaries + gospel climax)
- prayerPoints (altar call): ${params.language === 'ml' ? '180-220' : '300-400'} words with Gospel Recap, Invitation, Response Options, Closing Prayer
- All supporting fields present: ${params.language === 'ml' ? '3-4' : '5-7'} relatedVerses, ${params.language === 'ml' ? '3-4' : '5-7'} reflectionQuestions, ${params.language === 'ml' ? '3' : '5'} summaryInsights/interpretationInsights/reflectionAnswers, 5 yes/no questions
- Total: ${params.language === 'ml' ? '~550 words (STRICT limit)' : '~1,100 words'} | Verse refs in ${languageConfig.name}
FIX any issues BEFORE output.

Generate FULL CONTENT - no literal "..." or [...] placeholders.

${getLanguageExamples(language)}

OUTPUT ONLY THIS JSON - NO OTHER TEXT:
{
  "interpretationPart4": "[YOUR ${params.language === 'ml' ? '220-250' : '350-450'} WORD CONCLUSION HERE - PREACHER-FACING OUTLINE]",
  "prayerPoints": ["[YOUR ${params.language === 'ml' ? '180-220' : '300-400'} WORD ALTAR CALL HERE AS SINGLE STRING - CONCISE OUTLINE]"],
  "relatedVerses": ["[VERSE 1]", "[VERSE 2]", "[VERSE 3]"${params.language === 'ml' ? '' : ', "[VERSE 4]", "[VERSE 5]"'}],
  "reflectionQuestions": ["[QUESTION 1]", "[QUESTION 2]", "[QUESTION 3]"${params.language === 'ml' ? '' : ', "[QUESTION 4]", "[QUESTION 5]"'}],
  "summaryInsights": ["[INSIGHT 1: ${params.language === 'ml' ? '12-15' : '15-20'} words]", "[INSIGHT 2]", "[INSIGHT 3]"${params.language === 'ml' ? '' : ', "[INSIGHT 4]", "[INSIGHT 5]"'}],
  "interpretationInsights": ["[TRUTH 1: ${params.language === 'ml' ? '12-15' : '15-20'} words]", "[TRUTH 2]", "[TRUTH 3]"${params.language === 'ml' ? '' : ', "[TRUTH 4]", "[TRUTH 5]"'}],
  "reflectionAnswers": ["[APPLICATION 1: ${params.language === 'ml' ? '12-15' : '15-20'} words]", "[APPLICATION 2]", "[APPLICATION 3]"${params.language === 'ml' ? '' : ', "[APPLICATION 4]", "[APPLICATION 5]"'}],
  "contextQuestion": "[YOUR YES/NO QUESTION ABOUT BIBLICAL CONTEXT]",
  "summaryQuestion": "[YOUR QUESTION ABOUT SERMON THESIS - ${params.language === 'ml' ? '10-15' : '12-18'} words]",
  "relatedVersesQuestion": "[YOUR QUESTION ENCOURAGING SCRIPTURE STUDY - ${params.language === 'ml' ? '10-15' : '12-18'} words]",
  "reflectionQuestion": "[YOUR APPLICATION QUESTION - ${params.language === 'ml' ? '10-15' : '12-18'} words]",
  "prayerQuestion": "[YOUR INVITATION QUESTION - ${params.language === 'ml' ? '8-12' : '10-15'} words]"
}`

  return { sharedSystem, passSystem, userMessage }
}

/**
 * Combines results from all 4 passes into complete sermon structure
 */
export function combineSermonPasses(
  pass1: { summary: string; context: string; passage: string; interpretationPart1: string },
  pass2: { interpretationPart2: string },
  pass3: { interpretationPart3: string },
  pass4: {
    interpretationPart4: string
    prayerPoints: string[]
    relatedVerses: string[]
    reflectionQuestions: string[]
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
    interpretation: `${pass1.interpretationPart1}\n\n${pass2.interpretationPart2}\n\n${pass3.interpretationPart3}\n\n${pass4.interpretationPart4}`,
    context: pass1.context,
    passage: pass1.passage,
    relatedVerses: pass4.relatedVerses,
    reflectionQuestions: pass4.reflectionQuestions,
    prayerPoints: pass4.prayerPoints,
    summaryInsights: pass4.summaryInsights,
    interpretationInsights: pass4.interpretationInsights,
    reflectionAnswers: pass4.reflectionAnswers,
    contextQuestion: pass4.contextQuestion,
    summaryQuestion: pass4.summaryQuestion,
    relatedVersesQuestion: pass4.relatedVersesQuestion,
    reflectionQuestion: pass4.reflectionQuestion,
    prayerQuestion: pass4.prayerQuestion
  }
}
