//! Central registry of all CRON schedules.
//! Format: sec min hour day_of_month month day_of_week

/// Blog generation — daily at 5:30 AM IST (00:00 UTC)
pub const BLOG_GENERATION: &str = "0 0 0 * * *";

/// Blog retry — every 4 hours, to regenerate any locales that failed in the main run
pub const BLOG_RETRY: &str = "0 0 */4 * * *";
