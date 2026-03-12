pub mod blog_generator;
pub mod schedules;

use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

use reqwest::Client;
use sqlx::PgPool;
use tokio_cron_scheduler::{Job, JobScheduler};

use crate::config::Config;

/// Shared flag to prevent concurrent CRON execution.
pub static CRON_RUNNING: AtomicBool = AtomicBool::new(false);

/// Guard that sets `CRON_RUNNING` to false on drop.
pub struct CronGuard;

impl CronGuard {
    pub fn try_acquire() -> Option<Self> {
        if CRON_RUNNING.compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst).is_ok() {
            Some(CronGuard)
        } else {
            None
        }
    }
}

impl Drop for CronGuard {
    fn drop(&mut self) {
        CRON_RUNNING.store(false, Ordering::SeqCst);
    }
}

pub async fn start_scheduler(pool: PgPool, config: Config, http: Client) {
    let sched = JobScheduler::new().await.expect("Failed to create scheduler");

    // Blog generation CRON
    let blog_pool = pool.clone();
    let blog_config = Arc::new(config.clone());
    let blog_http = http.clone();

    let blog_job = Job::new_async(schedules::BLOG_GENERATION, move |_uuid, _lock| {
        let p = blog_pool.clone();
        let c = blog_config.clone();
        let h = blog_http.clone();
        Box::pin(async move {
            let _guard = match CronGuard::try_acquire() {
                Some(g) => g,
                None => {
                    tracing::warn!("Blog generation CRON skipped: previous run still in progress");
                    return;
                }
            };
            if let Err(e) = blog_generator::run_blog_generation(&p, &c, &h).await {
                tracing::error!("Blog generation CRON failed: {}", e);
            }
        })
    })
    .expect("Failed to create blog CRON job");

    sched.add(blog_job).await.expect("Failed to add blog CRON job");

    sched.start().await.expect("Failed to start CRON scheduler");
    tracing::info!(schedule = schedules::BLOG_GENERATION, "CRON scheduler started");
}
