//! Central registry of all CRON schedules.
//! Format: sec min hour day_of_month month day_of_week

/// Blog generation — daily at 5:30 AM IST (00:00 UTC)
pub const BLOG_GENERATION: &str = "0 0 0 * * *";

/// Blog retry — every 4 hours, to regenerate any locales that failed in the main run
pub const BLOG_RETRY: &str = "0 0 */4 * * *";

/// Publish scheduled posts — every minute, flips due scheduled posts to published.
pub const BLOG_PUBLISH_SCHEDULED: &str = "0 * * * * *";

/// Subscription reconciliation — hourly on the hour.
/// Expires ended subscriptions, activates paid ones whose webhook was missed,
/// and clears abandoned checkouts.
pub const SUBSCRIPTION_RECONCILE: &str = "0 0 * * * *";

/// Discipler daily fellowship post — 01:00 UTC (06:30 IST).
pub const FELLOWSHIP_DAILY_POST: &str = "0 0 1 * * *";

/// Discipler reply worker — every minute; drains the reply queue and, on minute 0, flushes activity digests.
pub const DISCIPLER_REPLY_WORKER: &str = "0 * * * * *";

/// Telegram daily post — 09:00 UTC (14:30 IST). One run posts every language;
/// the Edge Function is idempotent per language per day.
pub const TELEGRAM_DAILY_POST: &str = "0 0 9 * * *";
