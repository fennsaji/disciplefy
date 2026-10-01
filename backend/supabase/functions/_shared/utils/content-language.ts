/**
 * Infers the study language from the script of a learning-path topic title.
 *
 * Released app versions (<= 1.0.8) open fellowship lessons with the member's
 * own study language instead of the fellowship's, so a Hindi lesson title can
 * arrive with `language=en` and produce an English guide. A localized topic
 * title is unambiguous about the language it was loaded in, so for catalogue
 * topics the title's script wins over a conflicting `language`.
 */
const DEVANAGARI = /[ऀ-ॿ]/
const MALAYALAM = /[ഀ-ൿ]/

export function detectScriptLanguage(text: string): 'hi' | 'ml' | null {
  if (MALAYALAM.test(text)) return 'ml'
  if (DEVANAGARI.test(text)) return 'hi'
  return null
}

/**
 * Returns the language a catalogue-topic guide should be generated and cached
 * in. Only applies when `topicId` is set (learning-path / fellowship lessons);
 * free-form Generate requests keep the requested language untouched.
 */
export function resolveTopicLanguage(
  requested: string,
  inputValue: string,
  topicId?: string,
): string {
  if (!topicId) return requested
  return detectScriptLanguage(inputValue) ?? requested
}
