use chrono::{DateTime, Utc};
use sqlx::PgPool;

use crate::error::AppError;

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct CronConfig {
    pub name: String,
    pub enabled: bool,
    pub schedule: String,
    pub label: String,
    pub updated_at: DateTime<Utc>,
}

pub async fn list(pool: &PgPool) -> Result<Vec<CronConfig>, AppError> {
    let rows = sqlx::query_as::<_, CronConfig>(
        "SELECT name, enabled, schedule, label, updated_at FROM cron_config ORDER BY name",
    )
    .fetch_all(pool)
    .await?;
    Ok(rows)
}

pub async fn get(pool: &PgPool, name: &str) -> Result<CronConfig, AppError> {
    sqlx::query_as::<_, CronConfig>(
        "SELECT name, enabled, schedule, label, updated_at FROM cron_config WHERE name = $1",
    )
    .bind(name)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Cron '{}' not found", name)))
}

/// Whether the scheduler should run `name` on this tick.
///
/// A job with no `cron_config` row does NOT run. Every recurring job is
/// supposed to have one, and the dashboard can only list and toggle jobs that
/// do — so a missing row means a job nobody can see and nobody can stop. That
/// is how the pre-warm job ended up submitting Batch API work every hour with
/// no off switch. Treating the gap as "off" makes the dashboard the only way
/// to start such a job, which is where the decision belongs.
///
/// A genuine database error still runs the job: a connectivity blip should not
/// silently halt every scheduled job in the system.
pub async fn should_run(pool: &PgPool, name: &str) -> bool {
    match get(pool, name).await {
        Ok(cfg) => cfg.enabled,
        Err(AppError::NotFound(_)) => {
            tracing::warn!("{name} cron has no cron_config row — not running it");
            false
        }
        Err(e) => {
            tracing::warn!("Could not read cron_config for {name}: {e} — proceeding anyway");
            true
        }
    }
}

pub async fn set_enabled(pool: &PgPool, name: &str, enabled: bool) -> Result<CronConfig, AppError> {
    sqlx::query_as::<_, CronConfig>(
        "UPDATE cron_config SET enabled = $2 WHERE name = $1
         RETURNING name, enabled, schedule, label, updated_at",
    )
    .bind(name)
    .bind(enabled)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Cron '{}' not found", name)))
}

pub async fn set_schedule(
    pool: &PgPool,
    name: &str,
    schedule: &str,
    label: &str,
) -> Result<CronConfig, AppError> {
    sqlx::query_as::<_, CronConfig>(
        "UPDATE cron_config SET schedule = $2, label = $3 WHERE name = $1
         RETURNING name, enabled, schedule, label, updated_at",
    )
    .bind(name)
    .bind(schedule)
    .bind(label)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Cron '{}' not found", name)))
}
