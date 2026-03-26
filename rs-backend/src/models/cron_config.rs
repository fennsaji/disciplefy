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
