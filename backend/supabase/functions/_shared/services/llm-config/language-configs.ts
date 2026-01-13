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
      deep: { min: 5000, max: 6000, display: '5000-6000' },
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
      languageInstruction: 'Output only in simple, everyday Hindi (avoid complex Sanskrit words, use common spoken Hindi)',
      complexityInstruction: 'Use easy level language that common people can easily understand'
    },
    culturalContext: 'Indian Christian context with cultural sensitivity to local traditions and practices',
    wordCountTargets: {
      quick: { min: 500, max: 600, display: '500-600' },
      standard: { min: 2000, max: 2500, display: '2000-2500' },
      deep: { min: 5000, max: 6000, display: '5000-6000' },
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
      languageInstruction: 'Output only in simple, everyday Malayalam (avoid complex literary words, use common spoken Malayalam)',
      complexityInstruction: 'Use simple vocabulary accessible to Malayalam speakers across Kerala'
    },
    culturalContext: 'Kerala Christian context with awareness of the strong Protestant Christian heritage in the region',
    // v3.4: Malayalam adjusted targets (70% of English due to 7-8x token inefficiency)
    // Malayalam script requires significantly more tokens per word than English/Hindi
    wordCountTargets: {
      quick: { min: 400, max: 500, display: '400-500' },           // 75% of English
      standard: { min: 1500, max: 1800, display: '1500-1800' },    // 70% of English
      deep: { min: 3500, max: 4200, display: '3500-4200' },        // 70% of English
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
सरल, रोजमर्रा की हिंदी का उपयोग करें। कठिन संस्कृत शब्दों से बचें।

उदाहरण सारांश: "यह पद हमें दिखाता है कि परमेश्वर हमसे प्रेम करता है।"

उदाहरण प्रश्न: "आप अपने जीवन में परमेश्वर के प्रेम को कैसे देख सकते हैं?"

उदाहरण प्रार्थना: "हे प्रभु, हमें अपने प्रेम को समझने में मदद करें।"

उदाहरण व्याख्या: "इस पद में पौलुस हमें बताता है कि परमेश्वर का प्रेम कभी खत्म नहीं होता। यह प्रेम हमारे लिए इतना गहरा है कि वह अपने बेटे यीशु को हमारे लिए दे दिया।"

शैली: गांव के लोग समझ सकें, ऐसी सरल भाषा। आम बोलचाल के शब्द। बाइबल की सच्चाई को रोजाना की जिंदगी से जोड़ें।

शब्दावली गाइड:
- "परमेश्वर" (न कि "ईश्वर")
- "प्रेम" (न कि "प्रीति") 
- "मदद" (न कि "सहायता")
- "जिंदगी" (न कि "जीवन")
- "दिल" (न कि "हृदय")
- "प्रार्थना" (न कि "प्रार्थना")
- "आशीर्वाद" (न कि "आशीष")`,

  ml: `മലയാളത്തിൽ ഉദാഹരണം:
സാധാരണ മലയാളം ഉപയോഗിക്കുക. സാധുവായ JSON ഔട്ട്‌പുട്ട് ഉറപ്പാക്കാൻ:

JSON ആവശ്യകതകൾ:
- എല്ലാ കീകൾക്കും സ്ട്രിംഗ് വാല്യൂകൾക്കും ഡബിൾ ക്വോട്ടുകൾ ഉപയോഗിക്കുക
- പ്രത്യേക പ്രതീകങ്ങൾ എസ്കേപ് ചെയ്യുക
- ബാക്ക്‌ടിക്കുകളോ കോട്ടേഷൻ ഇല്ലാതെയുള്ള വിരാമചിഹ്നങ്ങളോ ഒഴിവാക്കുക

ഉദാഹരണ സാരാംശം: ഈ വചനം ദൈവത്തിന്റെ സ്നേഹം കാണിക്കുന്നു

ഉദാഹരണ ചോദ്യം: നിങ്ങളുടെ ജീവിതത്തിൽ ദൈവത്തിന്റെ സ്നേഹം എങ്ങനെ കാണാം

ഉദാഹരണ പ്രാർത്ഥന: കർത്താവേ അങ്ങയുടെ സ്നേഹം മനസ്സിലാക്കാൻ സഹായിക്കേണമേ

ശൈലി: ലളിതമായ മലയാളം ഉപയോഗിച്ച് ബൈബിൾ സത്യത്തെ ദൈനംദിന ജീവിതവുമായി ബന്ധിപ്പിക്കുക

ഉപയോഗിക്കേണ്ട പദങ്ങൾ: ദൈവം സ്നേഹം സഹായം ജീവിതം മനസ്സ് പ്രാർത്ഥന അനുഗ്രഹം`
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
