//! Central registry of all CRON schedules.
//! Format: sec min hour day_of_month month day_of_week

/// Blog generation — daily at 5:30 AM IST (00:00 UTC)
pub const BLOG_GENERATION: &str = "0 0 0 * * *";
