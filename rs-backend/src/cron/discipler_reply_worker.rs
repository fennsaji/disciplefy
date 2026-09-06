//! Drains discipler_reply_queue and flushes hourly activity digests.
use chrono::{Timelike, Utc};
use reqwest::Client;
use sqlx::PgPool;
use uuid::Uuid;

use crate::config::Config;
use crate::error::AppError;

#[derive(Debug, sqlx::FromRow)]
struct QueueRow {
    id: Uuid,
    post_id: Uuid,
    #[allow(dead_code)]
    comment_id: Option<Uuid>,
    trigger: String,
    attempts: i32,
    created_at: chrono::DateTime<Utc>,
}

pub(crate) fn next_status_after_failure(attempts: i32) -> &'static str {
    if attempts >= 3 {
        "failed"
    } else {
        "pending"
    }
}

async fn claim_due(pool: &PgPool) -> Result<Vec<QueueRow>, AppError> {
    let rows = sqlx::query_as::<_, QueueRow>(
        "UPDATE discipler_reply_queue q SET status = 'processing', updated_at = now()
         WHERE q.id IN (
           SELECT id FROM discipler_reply_queue
           WHERE (status = 'pending' AND run_after <= now())
              OR (status = 'processing' AND updated_at < now() - interval '10 minutes')
           ORDER BY run_after LIMIT 20 FOR UPDATE SKIP LOCKED)
         RETURNING q.id, q.post_id, q.comment_id, q.trigger, q.attempts, q.created_at",
    )
    .fetch_all(pool)
    .await?;
    Ok(rows)
}

async fn mentor_answered_since(
    pool: &PgPool,
    post_id: Uuid,
    since: chrono::DateTime<Utc>,
) -> Result<bool, AppError> {
    let (exists,): (bool,) = sqlx::query_as(
        "SELECT EXISTS (
           SELECT 1 FROM fellowship_comments c
           JOIN fellowship_posts p ON p.id = c.post_id
           JOIN fellowship_members m ON m.fellowship_id = p.fellowship_id AND m.user_id = c.author_user_id
           WHERE c.post_id = $1 AND c.is_deleted = false AND c.created_at >= $2
             AND m.role = 'mentor' AND m.is_active = true)",
    )
    .bind(post_id)
    .bind(since)
    .fetch_one(pool)
    .await?;
    Ok(exists)
}

/// Update a queue row's status after the worker's own decision (not the Edge Function's).
///
/// The `discipler-reply` Edge Function increments `attempts` on its own success path
/// (a call that reached it and completed, however it resolved). This worker only writes
/// `attempts = attempts + 1` here when the *transport itself* failed (status `pending`
/// retry or terminal `failed`) — never for `skipped_mentor_answered`, which isn't a
/// call attempt at all. Between the two paths, each real attempt is counted exactly once.
async fn set_status(
    pool: &PgPool,
    id: Uuid,
    status: &str,
    err: Option<&str>,
    delay_minutes: i64,
) -> Result<(), AppError> {
    let bump_attempts = matches!(status, "pending" | "failed");
    sqlx::query(
        "UPDATE discipler_reply_queue
         SET status = $2, last_error = $3, updated_at = now(),
             attempts = CASE WHEN $5 THEN attempts + 1 ELSE attempts END,
             run_after = CASE WHEN $2 = 'pending' THEN now() + ($4 || ' minutes')::interval ELSE run_after END
         WHERE id = $1",
    )
    .bind(id)
    .bind(status)
    .bind(err)
    .bind(delay_minutes.to_string())
    .bind(bump_attempts)
    .execute(pool)
    .await?;
    Ok(())
}

async fn call_reply(config: &Config, http: &Client, queue_id: Uuid) -> Result<(), AppError> {
    let url = format!(
        "{}/functions/v1/fellowship-posts/discipler-reply",
        config.supabase_url
    );
    let resp = http
        .post(&url)
        .header("apikey", &config.supabase_anon_key)
        .header("X-Internal-Api-Key", &config.internal_api_key)
        .header("Content-Type", "application/json")
        .json(&serde_json::json!({ "queue_id": queue_id }))
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("discipler-reply request failed: {e}")))?;
    let status = resp.status();
    let body = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        return Err(AppError::Internal(format!(
            "discipler-reply returned {status}: {body}"
        )));
    }
    tracing::info!(%queue_id, "discipler-reply: {}", body.chars().take(160).collect::<String>());
    Ok(())
}

async fn discard_stale_drafts(pool: &PgPool) -> Result<u64, AppError> {
    let r = sqlx::query(
        "UPDATE fellowship_comments SET is_deleted = true
         WHERE is_pending_review = true AND is_deleted = false AND created_at < now() - interval '7 days'",
    )
    .execute(pool)
    .await?;
    Ok(r.rows_affected())
}

async fn flush_digests(pool: &PgPool, config: &Config, http: &Client) -> Result<(), AppError> {
    let ids: Vec<(Uuid,)> = sqlx::query_as(
        "SELECT DISTINCT fellowship_id FROM discipler_activity WHERE pushed_at IS NULL",
    )
    .fetch_all(pool)
    .await?;
    for (fellowship_id,) in ids {
        let url = format!(
            "{}/functions/v1/fellowship-posts/notify",
            config.supabase_url
        );
        let resp = http
            .post(&url)
            .header(
                "Authorization",
                format!("Bearer {}", config.supabase_service_role_key),
            )
            .header("apikey", &config.supabase_anon_key)
            .header("Content-Type", "application/json")
            .json(&serde_json::json!({ "kind": "activity_digest", "fellowship_id": fellowship_id }))
            .send()
            .await;
        match resp {
            Ok(r) if r.status().is_success() => {
                tracing::info!(%fellowship_id, "Activity digest sent")
            }
            Ok(r) => tracing::error!(%fellowship_id, "Digest returned {}", r.status()),
            Err(e) => tracing::error!(%fellowship_id, "Digest request failed: {}", e),
        }
    }
    Ok(())
}

pub async fn run_discipler_reply_worker(
    pool: &PgPool,
    config: &Config,
    http: &Client,
) -> Result<(), AppError> {
    let rows = claim_due(pool).await?;
    let now = Utc::now();
    let is_top_of_hour = now.minute() == 0;

    if rows.is_empty() && !is_top_of_hour {
        tracing::debug!("discipler_reply_worker: nothing to do");
    }

    for row in rows {
        let attempts = row.attempts + 1; // discipler-reply increments in the DB; mirror it here for the backoff decision
        if row.trigger == "question" {
            match mentor_answered_since(pool, row.post_id, row.created_at).await {
                Ok(true) => {
                    set_status(pool, row.id, "skipped_mentor_answered", None, 0).await?;
                    continue;
                }
                Ok(false) => {}
                Err(e) => {
                    tracing::warn!(queue_id = %row.id, "mentor check failed, proceeding: {}", e);
                }
            }
        }
        if let Err(e) = call_reply(config, http, row.id).await {
            let status = next_status_after_failure(attempts);
            tracing::warn!(queue_id = %row.id, attempts, status, "Reply call failed: {}", e);
            set_status(pool, row.id, status, Some(&e.to_string()), 2).await?;
        }
    }

    if is_top_of_hour {
        match discard_stale_drafts(pool).await {
            Ok(n) if n > 0 => tracing::info!(discarded = n, "Stale Discipler drafts discarded"),
            Ok(_) => {}
            Err(e) => tracing::error!("Discard stale drafts failed: {}", e),
        }
        if let Err(e) = flush_digests(pool, config, http).await {
            tracing::error!("Activity digest flush failed: {}", e);
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::next_status_after_failure;
    #[test]
    fn retries_twice_then_fails() {
        assert_eq!(next_status_after_failure(1), "pending");
        assert_eq!(next_status_after_failure(2), "pending");
        assert_eq!(next_status_after_failure(3), "failed");
        assert_eq!(next_status_after_failure(9), "failed");
    }
}
