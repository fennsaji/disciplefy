-- A generation that never finishes (worker crash, platform CPU-time kill mid
-- stream, etc.) was marked 'failed' with the tokens it had already consumed
-- gone for good — nothing refunded them, because the process that would have
-- run the refund never reached its own catch block. On a Standard-plan
-- balance with only enough tokens for one generation, this left users unable
-- to retry at all.
--
-- Fix: record what an in-progress generation charged, so whichever caller
-- later discovers it abandoned (the inline stale-check in study-generate-v2,
-- or the cleanup_stale_in_progress_studies cron) can refund it exactly once.

ALTER TABLE study_guides_in_progress
  ADD COLUMN identifier TEXT,
  ADD COLUMN daily_tokens_used INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN purchased_tokens_used INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN tokens_refunded BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN study_guides_in_progress.identifier IS 'User ID or session ID the token consumption for this attempt was charged to (NULL for free/unlimited generations that consumed nothing)';
COMMENT ON COLUMN study_guides_in_progress.daily_tokens_used IS 'Daily tokens this attempt consumed, for refunding if it is later found abandoned';
COMMENT ON COLUMN study_guides_in_progress.purchased_tokens_used IS 'Purchased tokens this attempt consumed, for refunding if it is later found abandoned';
COMMENT ON COLUMN study_guides_in_progress.tokens_refunded IS 'Set once a refund has been issued for this record, so a race between the inline stale-check and the cleanup cron cannot double-refund';

-- Marks stale 'generating' records as failed, one result row per record
-- cleaned. refund_identifier is NULL when that record consumed no tokens
-- (free/unlimited generation) — the caller only calls refundTokens for rows
-- where it isn't. The generating -> failed transition is the atomic guard:
-- a row only appears here for the single caller who flips it.
DROP FUNCTION IF EXISTS cleanup_stale_in_progress_studies();

CREATE FUNCTION cleanup_stale_in_progress_studies()
RETURNS TABLE (
  cleaned_id UUID,
  refund_identifier TEXT,
  refund_daily_tokens INTEGER,
  refund_purchased_tokens INTEGER
) AS $$
BEGIN
  RETURN QUERY
  UPDATE study_guides_in_progress
  SET
    status = 'failed',
    error_code = 'TIMEOUT',
    error_message = 'Generation abandoned or timed out (no updates for 5+ minutes)',
    last_updated_at = NOW(),
    tokens_refunded = TRUE
  WHERE status = 'generating'
    AND last_updated_at <= NOW() - INTERVAL '5 minutes'
  RETURNING
    id,
    CASE WHEN daily_tokens_used > 0 OR purchased_tokens_used > 0 THEN identifier ELSE NULL END,
    daily_tokens_used,
    purchased_tokens_used;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_stale_in_progress_studies() IS
'Marks stale in-progress study guide records as failed, one row per record cleaned. refund_identifier is set exactly when that record consumed tokens still owed back to the user — the caller refunds those via token-service.refundTokens.';
