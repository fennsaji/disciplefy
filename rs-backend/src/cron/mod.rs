pub mod blog_generator;
pub mod schedules;

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use reqwest::Client;
use sqlx::PgPool;
use tokio_cron_scheduler::{Job, JobScheduler};
use uuid::Uuid;

use crate::config::Config;
use crate::models::cron_config::{self, CronConfig};

/// Shared flag to prevent concurrent CRON execution.
pub static CRON_RUNNING: AtomicBool = AtomicBool::new(false);

/// Guard that sets `CRON_RUNNING` to false on drop.
pub struct CronGuard;

impl CronGuard {
    pub fn try_acquire() -> Option<Self> {
        if CRON_RUNNING
            .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
            .is_ok()
        {
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

pub async fn start_scheduler(
    pool: &PgPool,
    config: &Config,
    http: &Client,
) -> (JobScheduler, HashMap<String, Uuid>) {
    let configs = cron_config::list(pool).await.unwrap_or_else(|e| {
        tracing::warn!("Could not load cron_config from DB ({}), using hardcoded defaults", e);
        vec![
            CronConfig {
                name: "blog_generation".into(),
                enabled: true,
                schedule: schedules::BLOG_GENERATION.into(),
                label: "Daily at 5:30 AM IST (midnight UTC)".into(),
                updated_at: chrono::Utc::now(),
            },
            CronConfig {
                name: "blog_retry".into(),
                enabled: true,
                schedule: schedules::BLOG_RETRY.into(),
                label: "Every 4 hours".into(),
                updated_at: chrono::Utc::now(),
            },
        ]
    });

    let sched = JobScheduler::new().await.expect("Failed to create scheduler");
    let mut job_ids: HashMap<String, Uuid> = HashMap::new();

    // Blog generation CRON
    let blog_cfg = configs.iter().find(|c| c.name == "blog_generation");
    let blog_schedule = blog_cfg
        .map(|c| c.schedule.clone())
        .unwrap_or_else(|| schedules::BLOG_GENERATION.into());
    let blog_pool = pool.clone();
    let blog_config = Arc::new(config.clone());
    let blog_http = http.clone();

    let blog_job = Job::new_async(blog_schedule.as_str(), move |_uuid, _lock| {
        let p = blog_pool.clone();
        let c = blog_config.clone();
        let h = blog_http.clone();
        Box::pin(async move {
            // Per-run enabled check — fail-open if DB unreachable
            match cron_config::get(&p, "blog_generation").await {
                Ok(cfg) if !cfg.enabled => {
                    tracing::info!("blog_generation cron disabled — skipping");
                    return;
                }
                Err(e) => tracing::warn!("Could not read cron_config: {} — proceeding anyway", e),
                _ => {}
            }
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

    let blog_uuid = sched.add(blog_job).await.expect("Failed to add blog CRON job");
    job_ids.insert("blog_generation".into(), blog_uuid);

    // Blog retry CRON
    let retry_cfg = configs.iter().find(|c| c.name == "blog_retry");
    let retry_schedule = retry_cfg
        .map(|c| c.schedule.clone())
        .unwrap_or_else(|| schedules::BLOG_RETRY.into());
    let retry_pool = pool.clone();
    let retry_config = Arc::new(config.clone());
    let retry_http = http.clone();

    let retry_job = Job::new_async(retry_schedule.as_str(), move |_uuid, _lock| {
        let p = retry_pool.clone();
        let c = retry_config.clone();
        let h = retry_http.clone();
        Box::pin(async move {
            // Per-run enabled check for blog_retry specifically
            match cron_config::get(&p, "blog_retry").await {
                Ok(cfg) if !cfg.enabled => {
                    tracing::info!("blog_retry cron disabled — skipping");
                    return;
                }
                Err(e) => tracing::warn!("Could not read cron_config: {} — proceeding anyway", e),
                _ => {}
            }
            let _guard = match CronGuard::try_acquire() {
                Some(g) => g,
                None => {
                    tracing::warn!("Blog retry CRON skipped: previous run still in progress");
                    return;
                }
            };
            if let Err(e) = blog_generator::run_blog_generation(&p, &c, &h).await {
                tracing::error!("Blog retry CRON failed: {}", e);
            }
        })
    })
    .expect("Failed to create blog retry CRON job");

    let retry_uuid = sched.add(retry_job).await.expect("Failed to add blog retry CRON job");
    job_ids.insert("blog_retry".into(), retry_uuid);

    sched.start().await.expect("Failed to start CRON scheduler");
    tracing::info!(
        schedule = blog_schedule.as_str(),
        retry_schedule = retry_schedule.as_str(),
        "CRON scheduler started"
    );

    (sched, job_ids)
}
