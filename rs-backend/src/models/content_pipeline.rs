//! Admin override for where the telegram_daily_post and prewarm pickers
//! start in the catalogue, instead of always the earliest active topic.
//! See migration 20260912185053_content_pipeline_progress.sql.

use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::AppError;

/// The two jobs this override applies to. Anything else is rejected before
/// it reaches the database's own CHECK constraint.
pub fn is_known_job(name: &str) -> bool {
    matches!(name, "telegram_daily_post" | "prewarm")
}

#[derive(Debug, Clone, sqlx::FromRow, serde::Serialize)]
pub struct ContentPipelineProgress {
    pub job_name: String,
    pub start_learning_path_id: Option<Uuid>,
    pub updated_at: DateTime<Utc>,
    /// Joined for display; None when there is no override or the path was
    /// deleted (ON DELETE SET NULL already cleared the id in that case).
    pub start_learning_path_title: Option<String>,
    /// Where the job would actually resume right now (ignoring the override
    /// above) — the next topic `next_telegram_topic`/`prewarm_missing_lessons`
    /// would pick. None once every active topic has been covered.
    pub current_learning_path_id: Option<Uuid>,
    pub current_learning_path_title: Option<String>,
    pub current_topic_title: Option<String>,
}

#[derive(sqlx::FromRow)]
struct CurrentTopicRow {
    learning_path_id: Uuid,
    path_title: String,
    title: String,
}

async fn current_position(
    pool: &PgPool,
    job_name: &str,
) -> Result<Option<CurrentTopicRow>, AppError> {
    let row = match job_name {
        "telegram_daily_post" => {
            sqlx::query_as::<_, CurrentTopicRow>(
                "SELECT learning_path_id, path_title, title FROM telegram_current_topic('en')",
            )
            .fetch_optional(pool)
            .await?
        }
        "prewarm" => {
            sqlx::query_as::<_, CurrentTopicRow>(
                "SELECT learning_path_id, path_title, title FROM prewarm_current_topic('en', 'standard')",
            )
            .fetch_optional(pool)
            .await?
        }
        _ => None,
    };
    Ok(row)
}

fn merge_current_position(mut row: ContentPipelineProgress, pos: Option<CurrentTopicRow>) -> ContentPipelineProgress {
    if let Some(pos) = pos {
        row.current_learning_path_id = Some(pos.learning_path_id);
        row.current_learning_path_title = Some(pos.path_title);
        row.current_topic_title = Some(pos.title);
    }
    row
}

pub async fn list(pool: &PgPool) -> Result<Vec<ContentPipelineProgress>, AppError> {
    let rows = sqlx::query_as::<_, ContentPipelineProgress>(
        "SELECT cpp.job_name, cpp.start_learning_path_id, cpp.updated_at, lp.title AS start_learning_path_title,
                NULL::uuid AS current_learning_path_id, NULL::text AS current_learning_path_title, NULL::text AS current_topic_title
         FROM content_pipeline_progress cpp
         LEFT JOIN learning_paths lp ON lp.id = cpp.start_learning_path_id
         ORDER BY cpp.job_name",
    )
    .fetch_all(pool)
    .await?;

    let mut out = Vec::with_capacity(rows.len());
    for row in rows {
        let pos = current_position(pool, &row.job_name).await?;
        out.push(merge_current_position(row, pos));
    }
    Ok(out)
}

/// Sets (or clears, with `None`) the starting learning path for `job_name`.
/// Validates the path exists and is active before writing — a stale id from
/// a stale admin-web tab must not silently point the picker at nothing.
pub async fn set_start_path(
    pool: &PgPool,
    job_name: &str,
    learning_path_id: Option<Uuid>,
) -> Result<ContentPipelineProgress, AppError> {
    if !is_known_job(job_name) {
        return Err(AppError::NotFound(format!(
            "Content pipeline job '{job_name}' not found"
        )));
    }

    if let Some(id) = learning_path_id {
        let exists: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM learning_paths WHERE id = $1 AND is_active)",
        )
        .bind(id)
        .fetch_one(pool)
        .await?;
        if !exists {
            return Err(AppError::BadRequest(
                "learning_path_id does not exist or is not active".into(),
            ));
        }
    }

    sqlx::query(
        "UPDATE content_pipeline_progress SET start_learning_path_id = $2 WHERE job_name = $1",
    )
    .bind(job_name)
    .bind(learning_path_id)
    .execute(pool)
    .await?;

    let row = sqlx::query_as::<_, ContentPipelineProgress>(
        "SELECT cpp.job_name, cpp.start_learning_path_id, cpp.updated_at, lp.title AS start_learning_path_title,
                NULL::uuid AS current_learning_path_id, NULL::text AS current_learning_path_title, NULL::text AS current_topic_title
         FROM content_pipeline_progress cpp
         LEFT JOIN learning_paths lp ON lp.id = cpp.start_learning_path_id
         WHERE cpp.job_name = $1",
    )
    .bind(job_name)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Content pipeline job '{job_name}' not found")))?;

    let pos = current_position(pool, job_name).await?;
    Ok(merge_current_position(row, pos))
}

#[cfg(test)]
mod tests {
    use super::is_known_job;

    #[test]
    fn only_the_two_pipeline_jobs_are_known() {
        assert!(is_known_job("telegram_daily_post"));
        assert!(is_known_job("prewarm"));
        assert!(!is_known_job("blog_generation"));
        assert!(!is_known_job("nope"));
    }
}
