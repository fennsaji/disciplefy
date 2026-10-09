/**
 * Whether a study costs nothing because it is a catalogue (learning-path) lesson.
 *
 * A lesson is free in Quick Read, so anyone can start a path without credits,
 * and in the mode its path recommends. A topic outside every path
 * (`recommendedMode === null`) is never free: a study the user types in pays,
 * whatever the mode.
 *
 * @param recommendedMode the path's recommended mode, or null if the topic is in no path
 * @param studyMode the mode the reader asked for
 */
export function isFreeCatalogueLesson(recommendedMode: string | null, studyMode: string): boolean {
  return recommendedMode !== null && (studyMode === 'quick' || studyMode === recommendedMode)
}

/** A title folded for comparison: Unicode NFC, lower case, single spaces, trimmed. */
export function normalizeTopicTitle(title: string): string {
  return title.normalize('NFC').toLowerCase().replace(/\s+/g, ' ').trim()
}

/** Whether [inputValue] is one of the catalogue titles of a topic, in any language. */
export function titleMatchesTopic(inputValue: string, titles: readonly string[]): boolean {
  const input = normalizeTopicTitle(inputValue)
  if (input === '') return false
  return titles.some((title) => normalizeTopicTitle(title) === input)
}

export interface CatalogueRequest {
  /** The client's `topic_id`, if any. */
  readonly topicId: string | undefined
  /** The client's `input_value`. */
  readonly inputValue: string
  /** Every title the catalogue holds for the topic: base, translations, path overrides. Empty if unknown. */
  readonly titles: readonly string[]
  /** The recommended mode of a path holding the topic, or null if none does. */
  readonly recommendedMode: string | null
  readonly studyMode: string
}

export interface CatalogueDecision {
  /** The topic id to read and write the shared cache under, or undefined to use the input hash only. */
  readonly cacheTopicId: string | undefined
  /** Whether the study costs no credits. */
  readonly isFree: boolean
}

/**
 * Decides whether a request is a real catalogue lesson.
 *
 * The client's `topic_id` is trusted only when its `input_value` is one of
 * that topic's catalogue titles. Otherwise the request is a normal paid study
 * keyed by its input hash, so it can neither be free nor write a guide into
 * the shared cache row every reader of that lesson is served from.
 */
export function resolveCatalogueRequest(req: CatalogueRequest): CatalogueDecision {
  const verified = req.topicId !== undefined && titleMatchesTopic(req.inputValue, req.titles)
  if (!verified) return { cacheTopicId: undefined, isFree: false }
  return { cacheTopicId: req.topicId, isFree: isFreeCatalogueLesson(req.recommendedMode, req.studyMode) }
}
