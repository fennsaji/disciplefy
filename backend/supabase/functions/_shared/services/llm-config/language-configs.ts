/**
 * Language Configuration Module
 * 
 * Centralizes all language-specific configurations for LLM generation.
 * Supports English, Hindi, and Malayalam with cultural context awareness.
 */

import type { LanguageConfig, LLMProvider } from '../llm-types.ts'

/**
 * Supported language codes
 */
export type SupportedLanguage = 'en' | 'hi' | 'ml'

/**
 * Language configurations map
 */
// v3.3: All languages now prefer Anthropic (Claude Sonnet 4.5) for better length compliance
// v3.4: Added language-specific word count targets for Malayalam (adjusted to 70% due to token inefficiency)
const languageConfigs: Map<SupportedLanguage, LanguageConfig> = new Map([
  ['en', {
    name: 'English',
    modelPreference: 'anthropic' as LLMProvider,  // v3.3: Changed from openai to anthropic
    maxTokens: 3000,
    temperature: 0.3,
    promptModifiers: {
      languageInstruction: 'Output only in clear, accessible English',
      complexityInstruction: 'Use clear, pastoral language appropriate for all education levels'
    },
    culturalContext: 'Western Christian context with Protestant theological emphasis',
    wordCountTargets: {
      quick: { min: 600, max: 750, display: '600-750' },
      standard: { min: 2000, max: 2500, display: '2000-2500' },
      deep: { min: 1800, max: 2400, display: '1800-2400' },
      lectio: { min: 3000, max: 3500, display: '3000-3500' },
      sermon: { min: 9000, max: 11000, display: '9000-11000' }
    }
  }],
  ['hi', {
    name: 'Hindi',
    modelPreference: 'anthropic' as LLMProvider,
    maxTokens: 4000,
    temperature: 0.2,
    promptModifiers: {
      // The vocabulary list is deliberate. A review on 9 Sep 2026 found इबादत
      // (Islamic) used repeatedly for Christian worship, बुजुर्ग (old man) for
      // church elder, and a scholarly section in one guide switching to Greek
      // script and English words in Devanagari mid-document. It sits in the
      // cached prefix, so it costs almost nothing after the first call.
      languageInstruction: `Output only in SIMPLE, everyday Hindi that a village believer with no formal education understands. This rule is absolute: it overrides any instruction elsewhere to be scholarly, rigorous or theologically deep. Never print Hebrew or Greek script. Never use an English word in Devanagari (सोशल मीडिया, फोन, टास्क, ड्यूटी, नोटबुक, ईमेल — use Hindi instead).

REQUIRED CHRISTIAN VOCABULARY (never the Hindu or Islamic equivalent):
- worship = आराधना / उपासना (NEVER इबादत, पूजा, दुआ)
- God = परमेश्वर / प्रभु (NEVER अल्लाह, ईश्वर, भगवान)
- church elder = प्राचीन / कलीसिया का अगुवा (NEVER बुजुर्ग, which means "old man")
- church = कलीसिया (NEVER मंदिर except naming the Jerusalem temple)
- Scripture = पवित्रशास्त्र / वचन
- repentance = पश्चाताप / मन फिराना
- grace = अनुग्रह
- salvation = उद्धार
Avoid Sanskritised literary words (निहितार्थ, अगम्यता, अज्ञेयता) — say the same thing in plain words instead.`,
      complexityInstruction: 'Use 5th-6th grade level Hindi - simple words that anyone can understand. Prefer spoken Hindi over literary Hindi.'
    },
    culturalContext: 'Indian Christian context - use terms familiar to Protestant Christians in India',
    wordCountTargets: {
      quick: { min: 500, max: 600, display: '500-600' },
      standard: { min: 2000, max: 2500, display: '2000-2500' },
      deep: { min: 1800, max: 2400, display: '1800-2400' },
      lectio: { min: 3000, max: 3500, display: '3000-3500' },
      sermon: { min: 9000, max: 11000, display: '9000-11000' }
    }
  }],
  ['ml', {
    name: 'Malayalam',
    modelPreference: 'anthropic' as LLMProvider,
    maxTokens: 4000,
    temperature: 0.2,
    promptModifiers: {
      // The vocabulary list is deliberate. A blind doctrinal review on 9 Sep 2026
      // found even Sonnet rendering grace as അനുഗ്രഹം (blessing) inside the
      // Ephesians 2:8 quotation, and reaching for Catholic-register words that
      // Kerala Protestant readers do not use. It sits in the cached prefix, so
      // it costs almost nothing after the first call of each session.
      languageInstruction: `Output only in SIMPLE, everyday Malayalam that common people speak at home. Use CHRISTIAN terminology familiar to Kerala Protestant churches. Avoid complex literary Malayalam completely.

REQUIRED MALAYALAM VOCABULARY (Kerala Protestant usage) — a review on 9 Sep
2026 found each banned word below actually produced, some of them changing
the theology (Christ "ruling" sin rather than bearing it; the new birth
rendered as Hindu reincarnation):
- grace = കൃപ (NEVER അനുഗ്രഹം, which means blessing)
- bore/carried (as in "bore our sins") = വഹിച്ചു (NEVER ഭരിച്ചു, which means ruled)
- confess (Rom 10:9) = ഏറ്റുപറയുക (NEVER സ്വീകരിക്കുക)
- apostles = അപ്പോസ്തലന്മാർ (NEVER പ്രേരിതന്മാർ)
- epistles/letters = ലേഖനങ്ങൾ (NEVER പത്രങ്ങൾ)
- the Lord's Prayer = കർത്തൃപ്രാർത്ഥന
- Old/New Testament = പഴയ നിയമം / പുതിയ നിയമം
- the cross = ക്രൂശ് (NEVER കുരിശ്, the Catholic/secular word)
- repentance = മാനസാന്തരം (NEVER പശ്ചാത്താപം or ഖേദം alone, which mean regret)
- new birth = വീണ്ടും ജനനം / വീണ്ടും ജനിക്കുക (NEVER പുനർജന്മം, which means Hindu reincarnation)
- a doctrinal confession or creed = വിശ്വാസപ്രമാണം (NEVER കുമ്പസാരം, the Catholic sacrament of confession to a priest)
- the Trinity = ത്രിയേകദൈവം or ത്രിത്വം (NEVER വിശുദ്ധ/പരിശുദ്ധ ത്രിത്വം, an Orthodox/Catholic register)
- resurrection = ഉയിർത്തെഴുന്നേൽപ്പ് / പുനരുത്ഥാനം — when the gospel is presented, say
  explicitly that Christ rose bodily; death without resurrection is an
  incomplete gospel (1 കൊരിന്ത്യർ 15:3-4)

BOOK NAMES (use exactly these): മത്തായി, മർക്കൊസ്, ലൂക്കോസ്, യോഹന്നാൻ, അപ്പൊസ്തലന്മാരുടെ പ്രവൃത്തികൾ, റോമർ, 1 കൊരിന്ത്യർ, 2 കൊരിന്ത്യർ, ഗലാത്യർ, എഫെസ്യർ, ഫിലിപ്പിയർ, കൊലൊസ്സ്യർ, എബ്രായർ, യാക്കോബ്, വെളിപ്പാട്.
NEVER invent or transliterate a book name.

Write theological terms in Malayalam, not transliterated English or Latin.
Never print a single Greek, Hebrew or Latin character anywhere in a
reader-facing field — not in the main text, not inside parentheses, not next
to a transliteration. Give the Malayalam transliteration alone: കൃപ എന്ന
ഗ്രീക്ക് പദം "കാരിസ്" എന്നാണ് — with nothing in the original script following
it. "കാരിസ് (χάρις)" is exactly what this rule forbids: the parenthetical
script is still Greek script. In quick and standard mode, skip
original-language commentary altogether; it belongs only in deep mode,
transliterated and nothing more.
Quotation marks belong only around Scripture quoted exactly from the
Sathyavedapusthakam text you were given, never around your own paraphrase of
a verse, and never around a pronoun or word you have silently changed.`,
      complexityInstruction: 'Use 5th-6th grade level Malayalam - simple spoken words, not formal/literary language. Make it easy for anyone to understand.'
    },
    culturalContext: 'Kerala Christian context - use terms familiar to Protestant Christians in Kerala churches',
    // v3.4: Malayalam adjusted targets (70% of English due to 7-8x token inefficiency)
    // Malayalam script requires significantly more tokens per word than English/Hindi
    wordCountTargets: {
      quick: { min: 400, max: 500, display: '400-500' },           // 75% of English
      standard: { min: 1500, max: 1800, display: '1500-1800' },    // 70% of English
      deep: { min: 1200, max: 1600, display: '1200-1600' },        // actual 2-pass output (~1100-1150 words due to token constraints)
      lectio: { min: 2200, max: 2600, display: '2200-2600' },      // 70% of English
      sermon: { min: 4000, max: 5000, display: '4000-5000' }       // 45% of English
    }
  }]
])

/**
 * Gets language configuration for a specific language code.
 * 
 * @param language - Language code (en, hi, ml)
 * @returns Language configuration or undefined if not supported
 */
export function getLanguageConfig(language: string): LanguageConfig | undefined {
  return languageConfigs.get(language as SupportedLanguage)
}

/**
 * Gets language configuration with fallback to English.
 * 
 * @param language - Language code
 * @returns Language configuration (defaults to English if not found)
 */
export function getLanguageConfigOrDefault(language: string): LanguageConfig {
  return languageConfigs.get(language as SupportedLanguage) || languageConfigs.get('en')!
}

/**
 * Checks if a language is supported.
 * 
 * @param language - Language code to check
 * @returns True if language is supported
 */
export function isLanguageSupported(language: string): language is SupportedLanguage {
  return languageConfigs.has(language as SupportedLanguage)
}

/**
 * Gets all supported language codes.
 * 
 * @returns Array of supported language codes
 */
export function getSupportedLanguages(): SupportedLanguage[] {
  return Array.from(languageConfigs.keys())
}

/**
 * Gets the total number of supported languages.
 * 
 * @returns Number of supported languages
 */
export function getLanguageCount(): number {
  return languageConfigs.size
}

/**
 * Language-specific examples for prompt engineering.
 * Provides formatting guidelines for better LLM output quality.
 */
export const languageExamples: Record<SupportedLanguage, string> = {
  en: `ENGLISH EXAMPLES & STYLE:
Use clear, accessible English appropriate for all education levels.

Example Summary: "This passage teaches us about God's unfailing love and how we can trust Him in difficult times."

Example Reflection Question: "How can you practically show God's love to someone in your family or community this week?"

Example Prayer Point: "Ask God to help you trust His love even when circumstances are challenging."

Tone: Pastoral, encouraging, and practical with modern language that connects biblical truth to daily life.`,

  hi: `हिंदी में उदाहरण और शैली:
बिल्कुल सरल, रोजमर्रा की हिंदी का उपयोग करें जो गांव के लोग भी समझ सकें।

उदाहरण सारांश: "यह पद हमें दिखाता है कि परमेश्वर हमसे प्रेम करता है।"

उदाहरण प्रश्न: "आप अपनी जिंदगी में परमेश्वर के प्रेम को कैसे देख सकते हैं?"

उदाहरण प्रार्थना: "हे प्रभु, हमें अपने प्रेम को समझने में मदद करें।"

शैली: 5-6 कक्षा के बच्चे समझ सकें, ऐसी आसान भाषा। रोज बोलने वाले शब्द। बाइबल की बात को रोजमर्रा की जिंदगी से जोड़ें।

⚠️ ईसाई शब्दावली - MANDATORY (Hindu/Muslim terms से बचें):

परमेश्वर के लिए:
✓ "परमेश्वर" (USE THIS - Christian term)
✗ "भगवान" (NEVER use - Hindu term)
✗ "ईश्वर" (NEVER use - Hindu term)
✗ "अल्लाह" (NEVER use - Muslim term)

यीशु के लिए:
✓ "यीशु मसीह", "प्रभु यीशु", "उद्धारकर्ता"
✗ "ईसा" (avoid - formal/Islamic usage)

पवित्र आत्मा के लिए:
✓ "पवित्र आत्मा" (Holy Spirit)
✗ "परमात्मा" (avoid - Hindu connotation)

सरल बोलचाल के शब्द (न कि कठिन संस्कृत):
✓ "प्रेम" (love) - न कि "प्रीति", "स्नेह"
✓ "मदद" (help) - न कि "सहायता"
✓ "जिंदगी" (life) - न कि "जीवन"
✓ "दिल" (heart) - न कि "हृदय"
✓ "प्रार्थना" (prayer) - सरल रखें
✓ "आशीर्वाद" (blessing) - न कि "आशीष"
✓ "विश्वास" (faith) - न कि "श्रद्धा"
✓ "पाप" (sin) - सरल रखें
✓ "माफी" (forgiveness) - न कि "क्षमा"
✓ "कलीसिया" (church) - न कि "गिरजाघर"
✓ "बाइबल" (Bible) - न कि "पवित्र ग्रंथ"

आम क्रियाएं - सरल बोलचाल:
✓ "करना" (do) - न कि "संपन्न करना"
✓ "देखना" (see) - न कि "दृष्टि डालना"
✓ "कहना" (say) - न कि "कथन करना"
✓ "समझना" (understand) - न कि "बोध होना"
✓ "मानना" (believe) - न कि "विश्वास धारण करना"

CRITICAL: हर वाक्य इतना आसान हो कि 10 साल का बच्चा या गांव का कोई भी व्यक्ति बिना किसी परेशानी के समझ सके।`,

  ml: `മലയാളത്തിൽ ഉദാഹരണം:
വളരെ ലളിതമായ, വീട്ടിൽ സംസാരിക്കുന്ന മലയാളം ഉപയോഗിക്കുക. എല്ലാവർക്കും മനസ്സിലാകണം.

ഉദാഹരണ സാരാംശം: "ഈ വചനം നമുക്ക് കാണിച്ചുതരുന്നത് ദൈവം നമ്മെ സ്നേഹിക്കുന്നു എന്നാണ്."

ഉദാഹരണ ചോദ്യം: "നിങ്ങളുടെ ജീവിതത്തിൽ ദൈവത്തിന്റെ സ്നേഹം എങ്ങനെ കാണാം?"

ഉദാഹരണ പ്രാർത്ഥന: "കർത്താവേ, അങ്ങയുടെ സ്നേഹം മനസ്സിലാക്കാൻ സഹായിക്കേണമേ."

ശൈലി: 5-6 ക്ലാസ്സിലെ കുട്ടികൾക്ക് മനസ്സിലാകുന്ന ലളിതമായ ഭാഷ. എല്ലാ ദിവസവും സംസാരിക്കുന്ന വാക്കുകൾ.

⚠️ ക്രിസ്തീയ പദാവലി - നിർബന്ധമായും ഉപയോഗിക്കേണ്ടത്:

ദൈവത്തിന്:
✓ "ദൈവം" (God - USE THIS Christian term)
✓ "കർത്താവ്" (Lord)
✗ "ഭഗവാൻ" (NEVER use - Hindu term)
✗ "അല്ലാഹു" (NEVER use - Muslim term)

യേശുവിന്:
✓ "യേശു", "യേശുക്രിസ്തു", "കർത്താവായ യേശു"
✓ "രക്ഷകൻ" (Savior)

പരിശുദ്ധാത്മാവിന്:
✓ "പരിശുദ്ധാത്മാവ്" (Holy Spirit)

ലളിതമായ, സംസാര ഭാഷ (സാഹിത്യ മലയാളമല്ല):
✓ "സ്നേഹം" (love) - ലളിതം
✓ "സഹായം" (help) - സാധാരണം
✓ "ജീവിതം" (life) - എളുപ്പം
✓ "മനസ്സ്" (heart/mind) - സംസാരം
✓ "പ്രാർത്ഥന" (prayer) - ലളിതം
✓ "അനുഗ്രഹം" (blessing — never as a translation of grace/കൃപ, see the required vocabulary above)
✓ "വിശ്വാസം" (faith)
✓ "പാപം" (sin)
✓ "ക്ഷമ" (forgiveness)
✓ "സഭ" (church)
✓ "ബൈബിൾ" (Bible)

സാധാരണ ക്രിയകൾ - എളുപ്പമുള്ള വാക്കുകൾ:
✓ "ചെയ്യുക" (do)
✓ "കാണുക" (see)
✓ "പറയുക" (say)
✓ "മനസ്സിലാക്കുക" (understand)
✓ "വിശ്വസിക്കുക" (believe)

CRITICAL: ഓരോ വാക്യവും 10 വയസ്സുള്ള കുട്ടിക്കോ ഗ്രാമത്തിലെ ആർക്കും എളുപ്പത്തിൽ മനസ്സിലാകണം.`
}

/**
 * Gets language-specific examples for prompt engineering.
 * 
 * @param language - Language code
 * @returns Language examples string or default English examples
 */
export function getLanguageExamples(language: string): string {
  return languageExamples[language as SupportedLanguage] || languageExamples.en
}
