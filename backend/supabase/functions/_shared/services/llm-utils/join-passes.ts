/**
 * Joins the interpretation fragments produced by the multi-pass generators.
 *
 * The combiners used to build this with a template string:
 *
 *     `${pass1.interpretationPart1}\n\n${pass2.interpretationPart2}`
 *
 * When a pass omitted its part — a malformed LLM response, a schema change, or
 * a mock that only fills some fields — JavaScript stringified `undefined` and
 * the literal text "undefined" was written into `study_guides.interpretation`
 * and shown to the user. That was observed in a real Malayalam guide whose
 * interpretation was stored as "undefined\n\nundefined".
 *
 * Missing parts are dropped instead. If every part is missing the caller gets
 * an error, because a study guide with no interpretation is not something to
 * silently persist.
 */
export function joinInterpretationParts(
  parts: ReadonlyArray<unknown>,
  context: string
): string {
  const usable = parts
    .filter((p): p is string => typeof p === 'string' && p.trim().length > 0)
    .map(p => p.trim())

  if (usable.length === 0) {
    throw new Error(
      `${context}: no interpretation content returned by any pass — refusing to store an empty interpretation`
    )
  }

  if (usable.length !== parts.length) {
    console.warn(
      `[${context}] ${parts.length - usable.length} of ${parts.length} interpretation parts were missing; joining the rest`
    )
  }

  return usable.join('\n\n')
}
