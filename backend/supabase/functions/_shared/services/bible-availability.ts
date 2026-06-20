import { getFeatureFlag } from './feature-flag-service.ts'

export const BIBLE_API_CALLS_FLAG = 'bible_api_calls_enabled'
export const BIBLE_CONTENT_FLAG = 'bible_content_enabled'

/**
 * Kill-switch read semantics: a flag is ENABLED unless an admin has explicitly
 * set it disabled. Missing/undefined flag => enabled (fail-open) so a transient
 * flag-read miss never takes Bible features down.
 *
 * `flagEnabled` operates on a snake_case `{ is_enabled }` shape (easy to unit-test).
 */
export function flagEnabled(flag: { is_enabled?: boolean } | undefined | null): boolean {
  return flag?.is_enabled !== false
}

/**
 * Kill-switch decision for a `FeatureFlag` as returned by feature-flag-service,
 * whose enabled field is camelCase `isEnabled`. Maps it onto `flagEnabled`.
 */
export function featureFlagEnabled(flag: { isEnabled?: boolean } | undefined | null): boolean {
  return flagEnabled(flag ? { is_enabled: flag.isEnabled } : undefined)
}

export async function isBibleApiCallsEnabled(): Promise<boolean> {
  return featureFlagEnabled(await getFeatureFlag(BIBLE_API_CALLS_FLAG))
}

export async function isBibleContentEnabled(): Promise<boolean> {
  return featureFlagEnabled(await getFeatureFlag(BIBLE_CONTENT_FLAG))
}
