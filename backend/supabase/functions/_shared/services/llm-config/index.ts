/**
 * LLM Config Module Index
 * 
 * Re-exports all LLM configuration functions and types.
 */

export {
  getLanguageConfig,
  getLanguageConfigOrDefault,
  isLanguageSupported,
  getSupportedLanguages,
  getLanguageCount,
  getLanguageExamples,
  languageExamples
} from './language-configs.ts'
export type { SupportedLanguage } from './language-configs.ts'
