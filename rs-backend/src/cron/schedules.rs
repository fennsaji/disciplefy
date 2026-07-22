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
