/**
 * Validation for the optional shared-guide preview fields on a new post:
 * the study mode the guide was generated in and a short plain-text summary.
 *
 * Both are optional so older clients (which omit them) keep working; the
 * feed then falls back to the input type + language label.
 */

import type { StudyMode } from '../_shared/types/index.ts'
import { sanitizeText } from '../_shared/services/llm-utils/response-parser.ts'
import { AppError } from '../_shared/utils/error-handler.ts'

/** Longest stored summary; mirrors the column CHECK constraint. */
export const GUIDE_SUMMARY_MAX_LENGTH = 280

export const GUIDE_STUDY_MODES: readonly StudyMode[] = ['quick', 'standard', 'deep', 'lectio', 'sermon']

/**
 * Returns the study mode, or null when absent. Any other value is a
 * validation error rather than being silently dropped.
 */
export function parseGuideStudyMode(value: unknown): StudyMode | null {
  if (value === undefined || value === null || value === '') return null
  if (typeof value !== 'string') {
    throw new AppError('VALIDATION_ERROR', 'guide_study_mode must be a string', 400)
  }
  const mode = value.trim().toLowerCase()
  if (!(GUIDE_STUDY_MODES as readonly string[]).includes(mode)) {
    throw new AppError('VALIDATION_ERROR', 'Invalid guide_study_mode', 400)
  }
  return mode as StudyMode
}

/**
 * Returns the summary as plain text — control characters and angle brackets
 * removed, whitespace collapsed (the shared short-text sanitizer), capped at
 * [GUIDE_SUMMARY_MAX_LENGTH] on a word boundary — or null when empty/absent.
 */
export function parseGuideSummary(value: unknown): string | null {
  if (value === undefined || value === null) return null
  if (typeof value !== 'string') {
    throw new AppError('VALIDATION_ERROR', 'guide_summary must be a string', 400)
  }
  // deno-lint-ignore no-control-regex
  const plain = sanitizeText(value.replace(/[\x00-\x1F\x7F]/g, ' '))
  if (!plain) return null
  if (plain.length <= GUIDE_SUMMARY_MAX_LENGTH) return plain

  const cut = plain.slice(0, GUIDE_SUMMARY_MAX_LENGTH - 1)
  const lastSpace = cut.lastIndexOf(' ')
  const head = lastSpace > GUIDE_SUMMARY_MAX_LENGTH / 2 ? cut.slice(0, lastSpace) : cut
  return `${head.trimEnd()}…`
}
