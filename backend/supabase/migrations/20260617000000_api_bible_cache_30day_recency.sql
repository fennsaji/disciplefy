-- API.Bible content-recency compliance.
--
-- API.Bible Terms require any cached content to be refreshed at least every
-- 30 days. The daily_verses_cache previously stored fetched verse text with a
-- 6-month (bible-api-service) / 60-day (daily-verse-service) TTL, which exceeds
-- that limit. New writes now use a 30-day TTL in code; this migration brings
-- EXISTING rows into compliance.
--
-- Cap each row's expiry to (created_at + 30 days):
--   * rows cached >30 days ago  -> expires_at moves into the past -> treated as
--     a cache miss on next read -> regenerated and re-fetched fresh.
--   * rows cached <30 days ago  -> expiry capped to 30 days from when cached.
UPDATE daily_verses_cache
SET expires_at = LEAST(expires_at, created_at + INTERVAL '30 days')
WHERE expires_at > created_at + INTERVAL '30 days';
