-- Razorpay webhook event deduplication table (M3).
-- Prevents replay attacks and out-of-order deliveries from unconditionally
-- overwriting subscription status.

CREATE TABLE IF NOT EXISTS razorpay_webhook_events (
  event_id      TEXT PRIMARY KEY,         -- x-razorpay-event-id header
  event_type    TEXT NOT NULL,
  processed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-purge events older than 30 days (Razorpay's maximum retry window)
CREATE INDEX IF NOT EXISTS idx_razorpay_webhook_events_processed_at
  ON razorpay_webhook_events (processed_at);

ALTER TABLE razorpay_webhook_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role only" ON razorpay_webhook_events FOR ALL USING (false);
