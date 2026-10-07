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
