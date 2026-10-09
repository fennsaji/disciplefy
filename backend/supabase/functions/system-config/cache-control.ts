/**
 * Cache-Control for system-config responses.
 *
 * The app keeps its own copy of the config (with its own TTL), so an HTTP
 * cache only adds staleness: with max-age/stale-while-revalidate a browser
 * kept serving the old feature flags for minutes after an admin toggle.
 * `no-cache` makes every request reach the function; a tester-specific
 * response is never stored at all.
 */
export function systemConfigCacheControl(testerBypassActive: boolean): string {
  return testerBypassActive ? 'private, no-store' : 'no-cache'
}
