pub mod blog_generator;
pub mod discipler_reply_worker;
pub mod fellowship_daily_post;
pub mod telegram_daily_post;
pub mod schedules;
pub mod subscription_reconciler;

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use reqwest::Client;
use sqlx::PgPool;
use tokio_cron_scheduler::{Job, JobScheduler};
use uuid::Uuid;

use crate::config::Config;
use crate::models::cron_config::{self, CronConfig};

/// Per-job flags to prevent concurrent execution of the same job.
/// Each job has its own lock so they don't block each other.
pub static BLOG_GENERATION_RUNNING: AtomicBool = AtomicBool::new(false);
pub static BLOG_RETRY_RUNNING: AtomicBool = AtomicBool::new(false);
pub static BLOG_PUBLISH_SCHEDULED_RUNNING: AtomicBool = AtomicBool::new(false);
pub static SUBSCRIPTION_RECONCILE_RUNNING: AtomicBool = AtomicBool::new(false);
pub static FELLOWSHIP_DAILY_POST_RUNNING: AtomicBool = AtomicBool::new(false);
pub static DISCIPLER_REPLY_WORKER_RUNNING: AtomicBool = AtomicBool::new(false);
pub static TELEGRAM_DAILY_POST_RUNNING: AtomicBool = AtomicBool::new(false);

/// Guard that resets its flag to false on drop.
pub struct CronGuard {
    flag: &'static AtomicBool,
}

impl CronGuard {
    pub fn try_acquire(flag: &'static AtomicBool) -> Option<Self> {
        if flag
            .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
            .is_ok()
        {
            Some(CronGuard { flag })
        } else {
            None
        }
    }
}

impl Drop for CronGuard {
    fn drop(&mut self) {
        self.flag.store(false, Ordering::SeqCst);
    }
}

pub async fn start_scheduler(
    pool: &PgPool,
    config: &Config,
    http: &Client,
) -> (JobScheduler, HashMap<String, Uuid>) {
    let configs = cron_config::list(pool).await.unwrap_or_else(|e| {
        tracing::warn!(
            "Could not load cron_config from DB ({}), using hardcoded defaults",
            e
        );
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
            CronConfig {
                name: "blog_publish_scheduled".into(),
                enabled: true,
                schedule: schedules::BLOG_PUBLISH_SCHEDULED.into(),
                label: "Every minute — publish due scheduled posts".into(),
                updated_at: chrono::Utc::now(),
            },
            CronConfig {
                name: "subscription_reconcile".into(),
                enabled: true,
                schedule: schedules::SUBSCRIPTION_RECONCILE.into(),
                label: "Hourly — reconcile subscriptions with Razorpay".into(),
                updated_at: chrono::Utc::now(),
            },
            CronConfig {
                name: "fellowship_daily_post".into(),
                enabled: false,
                schedule: schedules::FELLOWSHIP_DAILY_POST.into(),
                label: "Daily 06:30 IST — Discipler learning-path post".into(),
                updated_at: chrono::Utc::now(),
            },
            CronConfig {
                name: "discipler_reply_worker".into(),
                enabled: false,
                schedule: schedules::DISCIPLER_REPLY_WORKER.into(),
                label: "Every minute — drain Discipler reply queue".into(),
                updated_at: chrono::Utc::now(),
            },
            CronConfig {
                name: "telegram_daily_post".into(),
                enabled: false,
                schedule: schedules::TELEGRAM_DAILY_POST.into(),
                label: "Daily 14:30 IST — Telegram channel post (en, hi, ml)".into(),
                updated_at: chrono::Utc::now(),
            },
        ]
    });

    let sched = JobScheduler::new()
        .await
        .expect("Failed to create scheduler");
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
            let _guard = match CronGuard::try_acquire(&BLOG_GENERATION_RUNNING) {
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

    let blog_uuid = sched
        .add(blog_job)
        .await
        .expect("Failed to add blog CRON job");
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
            let _guard = match CronGuard::try_acquire(&BLOG_RETRY_RUNNING) {
                Some(g) => g,
                None => {
                    tracing::warn!("Blog retry CRON skipped: previous run still in progress");
                    return;
                }
            };
            if let Err(e) = blog_generator::run_blog_retry(&p, &c, &h).await {
                tracing::error!("Blog retry CRON failed: {}", e);
            }
        })
    })
    .expect("Failed to create blog retry CRON job");

    let retry_uuid = sched
        .add(retry_job)
        .await
        .expect("Failed to add blog retry CRON job");
    job_ids.insert("blog_retry".into(), retry_uuid);

    // Scheduled-post publisher CRON
    let sched_cfg = configs.iter().find(|c| c.name == "blog_publish_scheduled");
    let sched_schedule = sched_cfg
        .map(|c| c.schedule.clone())
        .unwrap_or_else(|| schedules::BLOG_PUBLISH_SCHEDULED.into());
    let sched_pool = pool.clone();

    let publish_job = Job::new_async(sched_schedule.as_str(), move |_uuid, _lock| {
        let p = sched_pool.clone();
        Box::pin(async move {
            match cron_config::get(&p, "blog_publish_scheduled").await {
                Ok(cfg) if !cfg.enabled => {
                    tracing::info!("blog_publish_scheduled cron disabled — skipping");
                    return;
                }
                Err(e) => tracing::warn!("Could not read cron_config: {} — proceeding anyway", e),
                _ => {}
            }
            let _guard = match CronGuard::try_acquire(&BLOG_PUBLISH_SCHEDULED_RUNNING) {
                Some(g) => g,
                None => {
                    tracing::warn!(
                        "Scheduled-publish CRON skipped: previous run still in progress"
                    );
                    return;
                }
            };
            match crate::models::post::publish_due_scheduled(&p).await {
                Ok(published) if !published.is_empty() => {
                    tracing::info!(count = published.len(), "Auto-published scheduled posts");
                }
                Ok(_) => {}
                Err(e) => tracing::error!("Scheduled-publish CRON failed: {}", e),
            }
        })
    })
    .expect("Failed to create scheduled-publish CRON job");

    let publish_uuid = sched
        .add(publish_job)
        .await
        .expect("Failed to add scheduled-publish CRON job");
    job_ids.insert("blog_publish_scheduled".into(), publish_uuid);

    // Subscription reconciliation CRON
    let recon_cfg = configs.iter().find(|c| c.name == "subscription_reconcile");
    let recon_schedule = recon_cfg
        .map(|c| c.schedule.clone())
        .unwrap_or_else(|| schedules::SUBSCRIPTION_RECONCILE.into());
    let recon_config = Arc::new(config.clone());
    let recon_http = http.clone();
    let recon_pool = pool.clone();

    let recon_job = Job::new_async(recon_schedule.as_str(), move |_uuid, _lock| {
        let p = recon_pool.clone();
        let c = recon_config.clone();
        let h = recon_http.clone();
        Box::pin(async move {
            match cron_config::get(&p, "subscription_reconcile").await {
                Ok(cfg) if !cfg.enabled => {
                    tracing::info!("subscription_reconcile cron disabled — skipping");
                    return;
                }
                Err(e) => tracing::warn!("Could not read cron_config: {} — proceeding anyway", e),
                _ => {}
            }
            let _guard = match CronGuard::try_acquire(&SUBSCRIPTION_RECONCILE_RUNNING) {
                Some(g) => g,
                None => {
                    tracing::warn!(
                        "Subscription reconcile CRON skipped: previous run still in progress"
                    );
                    return;
                }
            };
            if let Err(e) = subscription_reconciler::run_subscription_reconcile(&c, &h).await {
                tracing::error!("Subscription reconcile CRON failed: {}", e);
            }
        })
    })
    .expect("Failed to create subscription reconcile CRON job");

    let recon_uuid = sched
        .add(recon_job)
        .await
        .expect("Failed to add subscription reconcile CRON job");
    job_ids.insert("subscription_reconcile".into(), recon_uuid);

    // Discipler daily fellowship post CRON
    let daily_cfg = configs.iter().find(|c| c.name == "fellowship_daily_post");
    let daily_schedule = daily_cfg
        .map(|c| c.schedule.clone())
        .unwrap_or_else(|| schedules::FELLOWSHIP_DAILY_POST.into());
    let daily_pool = pool.clone();
    let daily_config = Arc::new(config.clone());
    let daily_http = http.clone();

    let daily_job = Job::new_async(daily_schedule.as_str(), move |_uuid, _lock| {
        let p = daily_pool.clone();
        let c = daily_config.clone();
        let h = daily_http.clone();
        Box::pin(async move {
            match cron_config::get(&p, "fellowship_daily_post").await {
                Ok(cfg) if !cfg.enabled => {
                    tracing::info!("fellowship_daily_post cron disabled — skipping");
                    return;
                }
                Err(e) => tracing::warn!("Could not read cron_config: {} — proceeding anyway", e),
                _ => {}
            }
            let _guard = match CronGuard::try_acquire(&FELLOWSHIP_DAILY_POST_RUNNING) {
                Some(g) => g,
                None => {
                    tracing::warn!(
                        "Discipler daily post CRON skipped: previous run still in progress"
                    );
                    return;
                }
            };
            if let Err(e) = fellowship_daily_post::run_fellowship_daily_post(&p, &c, &h).await {
                tracing::error!("Discipler daily post CRON failed: {}", e);
            }
        })
    })
    .expect("Failed to create fellowship daily post CRON job");

    let daily_uuid = sched
        .add(daily_job)
        .await
        .expect("Failed to add fellowship daily post CRON job");
    job_ids.insert("fellowship_daily_post".into(), daily_uuid);

    // Discipler reply worker CRON
    let worker_cfg = configs.iter().find(|c| c.name == "discipler_reply_worker");
    let worker_schedule = worker_cfg
        .map(|c| c.schedule.clone())
        .unwrap_or_else(|| schedules::DISCIPLER_REPLY_WORKER.into());
    let worker_pool = pool.clone();
    let worker_config = Arc::new(config.clone());
    let worker_http = http.clone();

    let worker_job = Job::new_async(worker_schedule.as_str(), move |_uuid, _lock| {
        let p = worker_pool.clone();
        let c = worker_config.clone();
        let h = worker_http.clone();
        Box::pin(async move {
            match cron_config::get(&p, "discipler_reply_worker").await {
                Ok(cfg) if !cfg.enabled => {
                    tracing::debug!("discipler_reply_worker cron disabled — skipping");
                    return;
                }
                Err(e) => tracing::warn!("Could not read cron_config: {} — proceeding anyway", e),
                _ => {}
            }
            let _guard = match CronGuard::try_acquire(&DISCIPLER_REPLY_WORKER_RUNNING) {
                Some(g) => g,
                None => {
                    tracing::warn!(
                        "Discipler reply worker CRON skipped: previous run still in progress"
                    );
                    return;
                }
            };
            if let Err(e) = discipler_reply_worker::run_discipler_reply_worker(&p, &c, &h).await {
                tracing::error!("Discipler reply worker CRON failed: {}", e);
            }
        })
    })
    .expect("Failed to create discipler reply worker CRON job");

    let worker_uuid = sched
        .add(worker_job)
        .await
        .expect("Failed to add discipler reply worker CRON job");
    job_ids.insert("discipler_reply_worker".into(), worker_uuid);

    // Telegram channel post CRON
    let telegram_cfg = configs.iter().find(|c| c.name == "telegram_daily_post");
    let telegram_schedule = telegram_cfg
        .map(|c| c.schedule.clone())
        .unwrap_or_else(|| schedules::TELEGRAM_DAILY_POST.into());
    let telegram_pool = pool.clone();
    let telegram_config = Arc::new(config.clone());
    let telegram_http = http.clone();

    let telegram_job = Job::new_async(telegram_schedule.as_str(), move |_uuid, _lock| {
        let p = telegram_pool.clone();
        let c = telegram_config.clone();
        let h = telegram_http.clone();
        Box::pin(async move {
            match cron_config::get(&p, "telegram_daily_post").await {
                Ok(cfg) if !cfg.enabled => {
                    tracing::info!("telegram_daily_post cron disabled — skipping");
                    return;
                }
                Err(e) => tracing::warn!("Could not read cron_config: {} — proceeding anyway", e),
                _ => {}
            }
            let _guard = match CronGuard::try_acquire(&TELEGRAM_DAILY_POST_RUNNING) {
                Some(g) => g,
                None => {
                    tracing::warn!("Telegram daily post CRON skipped: previous run still in progress");
                    return;
                }
            };
            if let Err(e) = telegram_daily_post::run_telegram_daily_post(&c, &h).await {
                tracing::error!("Telegram daily post CRON failed: {}", e);
            }
        })
    })
    .expect("Failed to create Telegram daily post CRON job");

    let telegram_uuid = sched
        .add(telegram_job)
        .await
        .expect("Failed to add Telegram daily post CRON job");
    job_ids.insert("telegram_daily_post".into(), telegram_uuid);

    sched.start().await.expect("Failed to start CRON scheduler");

    let schedule_by_name: HashMap<&str, &str> = HashMap::from([
        ("blog_generation", blog_schedule.as_str()),
        ("blog_retry", retry_schedule.as_str()),
        ("blog_publish_scheduled", sched_schedule.as_str()),
        ("subscription_reconcile", recon_schedule.as_str()),
        ("fellowship_daily_post", daily_schedule.as_str()),
        ("discipler_reply_worker", worker_schedule.as_str()),
        ("telegram_daily_post", telegram_schedule.as_str()),
    ]);
    for name in job_ids.keys() {
        let s = schedule_by_name.get(name.as_str()).copied().unwrap_or("?");
        tracing::info!(job = %name, schedule = %s, "CRON registered");
    }
    tracing::info!("CRON scheduler started");

    (sched, job_ids)
}
