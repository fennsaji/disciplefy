use std::collections::HashMap;
use std::sync::atomic::Ordering;

use axum::extract::{Path, State};
use axum::http::HeaderMap;
use axum::Json;
use serde::Deserialize;
use serde_json::{json, Value};
use uuid::Uuid;

use crate::auth;
use crate::config::Config;
use crate::cron::{
    BLOG_GENERATION_RUNNING, BLOG_RETRY_RUNNING, DISCIPLER_REPLY_WORKER_RUNNING,
    FELLOWSHIP_DAILY_POST_RUNNING,
};
use crate::error::AppError;
use crate::models::{content_pipeline, cron_config, post};
use crate::services::content_formatter;
use crate::AppState;

/// Which guard flag a job name uses. None = unknown job.
pub(crate) fn guard_for(name: &str) -> Option<&'static std::sync::atomic::AtomicBool> {
    use crate::cron::*;
    Some(match name {
        "blog_generation" => &BLOG_GENERATION_RUNNING,
        "blog_retry" => &BLOG_RETRY_RUNNING,
        "blog_publish_scheduled" => &BLOG_PUBLISH_SCHEDULED_RUNNING,
        "subscription_reconcile" => &SUBSCRIPTION_RECONCILE_RUNNING,
        "fellowship_daily_post" => &FELLOWSHIP_DAILY_POST_RUNNING,
        "discipler_reply_worker" => &DISCIPLER_REPLY_WORKER_RUNNING,
        "telegram_daily_post" => &TELEGRAM_DAILY_POST_RUNNING,
        "prewarm" => &PREWARM_RUNNING,
        "cost_reconcile" => &COST_RECONCILE_RUNNING,
        _ => return None,
    })
}

async fn run_job(name: &str, pool: sqlx::PgPool, config: Config, http: reqwest::Client) {
    let r = match name {
        "blog_generation" => {
            crate::cron::blog_generator::run_blog_generation(&pool, &config, &http).await
        }
        "blog_retry" => crate::cron::blog_generator::run_blog_retry(&pool, &config, &http).await,
        "blog_publish_scheduled" => crate::models::post::publish_due_scheduled(&pool)
            .await
            .map(|_| ()),
        "subscription_reconcile" => {
            crate::cron::subscription_reconciler::run_subscription_reconcile(&config, &http).await
        }
        "fellowship_daily_post" => {
            crate::cron::fellowship_daily_post::run_fellowship_daily_post(&pool, &config, &http)
                .await
        }
        "discipler_reply_worker" => {
            crate::cron::discipler_reply_worker::run_discipler_reply_worker(&pool, &config, &http)
                .await
        }
        "telegram_daily_post" => {
            crate::cron::telegram_daily_post::run_telegram_daily_post(&config, &http).await
        }
        "prewarm" => crate::cron::prewarm::run_prewarm(&config, &http).await,
        "cost_reconcile" => crate::cron::cost_reconcile::run_cost_reconcile(&config, &http).await,
        other => Err(AppError::BadRequest(format!("Unknown cron '{other}'"))),
    };
    if let Err(e) = r {
        tracing::error!(job = name, "CRON failed: {}", e);
    }
}

#[cfg(test)]
mod tests {
    use super::guard_for;
    #[test]
    fn known_jobs_have_guards() {
        for n in [
            "blog_generation",
            "blog_retry",
            "blog_publish_scheduled",
            "subscription_reconcile",
            "fellowship_daily_post",
            "discipler_reply_worker",
            "telegram_daily_post",
        ] {
            assert!(guard_for(n).is_some(), "{n}");
        }
        assert!(guard_for("nope").is_none());
    }
}

async fn verify_admin(headers: &HeaderMap, state: &AppState) -> Result<auth::AdminUser, AppError> {
    auth::require_admin(headers, &state.config, &state.pool, &state.http).await
}

pub async fn create_post(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(input): Json<post::CreatePostInput>,
) -> Result<Json<Value>, AppError> {
    verify_admin(&headers, &state).await?;
    let p = post::create_post(&state.pool, input).await?;
    Ok(Json(json!({ "success": true, "data": p })))
}

pub async fn update_post(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(input): Json<post::UpdatePostInput>,
) -> Result<Json<Value>, AppError> {
    verify_admin(&headers, &state).await?;
    let p = post::update_post(&state.pool, id, input).await?;
    Ok(Json(json!({ "success": true, "data": p })))
}

pub async fn delete_post(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<Value>, AppError> {
    verify_admin(&headers, &state).await?;
    post::delete_post(&state.pool, id).await?;
    Ok(Json(json!({ "success": true, "message": "Post deleted" })))
}

pub async fn publish_post(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<Value>, AppError> {
    verify_admin(&headers, &state).await?;
    let p = post::publish_post(&state.pool, id).await?;
    Ok(Json(json!({ "success": true, "data": p })))
}

pub async fn unpublish_post(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<Value>, AppError> {
    verify_admin(&headers, &state).await?;
    let p = post::unpublish_post(&state.pool, id).await?;
    Ok(Json(json!({ "success": true, "data": p })))
}

pub async fn trigger_cron(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Value>, AppError> {
    trigger_cron_named(State(state), headers, Path("blog_generation".to_string())).await
}

pub async fn trigger_cron_named(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(name): Path<String>,
) -> Result<Json<Value>, AppError> {
    verify_admin(&headers, &state).await?;

    let flag =
        guard_for(&name).ok_or_else(|| AppError::NotFound(format!("Cron '{name}' not found")))?;
    let guard = crate::cron::CronGuard::try_acquire(flag)
        .ok_or_else(|| AppError::BadRequest(format!("{name} is already running")))?;

    let pool = state.pool.clone();
    let config = state.config.clone();
    let http = state.http.clone();
    let job_name = name.clone();
    tokio::spawn(async move {
        // guard is moved into the spawned task so it releases when done
        let _g = guard;
        run_job(&job_name, pool, config, http).await;
    });

    Ok(Json(
        json!({ "success": true, "message": format!("{name} triggered") }),
    ))
}

pub async fn cron_status(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Value>, AppError> {
    verify_admin(&headers, &state).await?;
    let crons = cron_config::list(&state.pool).await?;
    let generation_running = BLOG_GENERATION_RUNNING.load(Ordering::SeqCst);
    let retry_running = BLOG_RETRY_RUNNING.load(Ordering::SeqCst);
    let fellowship_daily_post_running = FELLOWSHIP_DAILY_POST_RUNNING.load(Ordering::SeqCst);
    let discipler_reply_worker_running = DISCIPLER_REPLY_WORKER_RUNNING.load(Ordering::SeqCst);
    Ok(Json(json!({
        "is_running": generation_running || retry_running || fellowship_daily_post_running || discipler_reply_worker_running,
        "blog_generation_running": generation_running,
        "blog_retry_running": retry_running,
        "fellowship_daily_post_running": fellowship_daily_post_running,
        "discipler_reply_worker_running": discipler_reply_worker_running,
        "crons": crons.iter().map(|c| json!({
            "name": c.name,
            "enabled": c.enabled,
            "schedule": c.schedule,
            "label": c.label,
            "updated_at": c.updated_at,
        })).collect::<Vec<_>>()
    })))
}

pub async fn cron_enable(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(name): Path<String>,
) -> Result<Json<Value>, AppError> {
    verify_admin(&headers, &state).await?;
    let cfg = cron_config::set_enabled(&state.pool, &name, true).await?;
    Ok(Json(json!({ "success": true, "data": {
        "name": cfg.name, "enabled": cfg.enabled,
        "schedule": cfg.schedule, "label": cfg.label, "updated_at": cfg.updated_at
    }})))
}

pub async fn cron_disable(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(name): Path<String>,
) -> Result<Json<Value>, AppError> {
    verify_admin(&headers, &state).await?;
    let cfg = cron_config::set_enabled(&state.pool, &name, false).await?;
    Ok(Json(json!({ "success": true, "data": {
        "name": cfg.name, "enabled": cfg.enabled,
        "schedule": cfg.schedule, "label": cfg.label, "updated_at": cfg.updated_at
    }})))
}

#[derive(Deserialize)]
pub struct UpdateScheduleBody {
    pub schedule: String,
    pub label: String,
}

pub async fn cron_update_schedule(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(name): Path<String>,
    Json(body): Json<UpdateScheduleBody>,
) -> Result<Json<Value>, AppError> {
    verify_admin(&headers, &state).await?;

    // 1. Validate cron expression
    croner::Cron::new(&body.schedule)
        .with_seconds_required()
        .with_dom_and_dow()
        .parse()
        .map_err(|e| AppError::BadRequest(format!("Invalid cron expression: {}", e)))?;

    // 2. Update DB
    let cfg = cron_config::set_schedule(&state.pool, &name, &body.schedule, &body.label).await?;

    // 3. Hot-reload: remove old job, add new one
    let old_uuid = {
        let ids = state.cron_job_ids.lock().unwrap();
        ids.get(&name).copied()
    };

    match old_uuid {
        None => {
            tracing::error!(
                name = name.as_str(),
                "Job UUID not tracked — schedule saved to DB but will apply on next restart"
            );
            return Err(AppError::Internal(
                "Job UUID not tracked — schedule saved to DB but will apply on next restart".into(),
            ));
        }
        Some(uuid) => {
            if let Err(e) = state.scheduler.remove(&uuid).await {
                tracing::warn!(
                    name = name.as_str(),
                    "Failed to remove old job: {} — proceeding with add",
                    e
                );
            }

            let pool = state.pool.clone();
            let config = state.config.clone();
            let http = state.http.clone();
            let new_schedule = body.schedule.clone();
            let job_name = name.clone();

            let new_job =
                tokio_cron_scheduler::Job::new_async(new_schedule.as_str(), move |_uuid, _lock| {
                    let p = pool.clone();
                    let c = std::sync::Arc::new(config.clone());
                    let h = http.clone();
                    let n = job_name.clone();
                    Box::pin(async move {
                        match cron_config::get(&p, &n).await {
                            Ok(cfg) if !cfg.enabled => {
                                tracing::info!("{} cron disabled — skipping", n);
                                return;
                            }
                            Err(e) => tracing::warn!(
                                "Could not read cron_config: {} — proceeding anyway",
                                e
                            ),
                            _ => {}
                        }
                        let Some(flag) = guard_for(&n) else {
                            tracing::error!(job = %n, "Unknown cron, not rescheduled");
                            return;
                        };
                        let _guard = match crate::cron::CronGuard::try_acquire(flag) {
                            Some(g) => g,
                            None => {
                                tracing::warn!(job = %n, "CRON skipped: previous run still in progress");
                                return;
                            }
                        };
                        run_job(&n, p, (*c).clone(), h).await;
                    })
                })
                .map_err(|e| AppError::Internal(format!("Failed to create new job: {}", e)))?;

            let new_uuid = state
                .scheduler
                .add(new_job)
                .await
                .map_err(|e| AppError::Internal(format!("Failed to add new job: {}", e)))?;

            state
                .cron_job_ids
                .lock()
                .unwrap()
                .insert(name.clone(), new_uuid);
        }
    }

    Ok(Json(json!({ "success": true, "data": {
        "name": cfg.name, "enabled": cfg.enabled,
        "schedule": cfg.schedule, "label": cfg.label, "updated_at": cfg.updated_at
    }})))
}

pub async fn generate_blog_from_study_guide(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(guide_id): Path<Uuid>,
) -> Result<Json<Value>, AppError> {
    verify_admin(&headers, &state).await?;

    // 1. Fetch study guide
    let guide = post::fetch_study_guide_for_blog(&state.pool, guide_id)
        .await?
        .ok_or_else(|| AppError::NotFound("Study guide not found".to_string()))?;

    // 2. Check if blog already exists for this guide
    if let Some((_id, slug)) = post::check_blog_exists_for_guide(&state.pool, guide_id).await? {
        return Ok(Json(json!({
            "success": true,
            "already_exists": true,
            "data": { "slug": slug }
        })));
    }

    // 3. Build StudyGuideResult sections from flat DB columns
    let mut sections: HashMap<String, String> = HashMap::new();
    if let Some(v) = guide.summary {
        sections.insert("summary".to_string(), v);
    }
    if let Some(v) = guide.context {
        sections.insert("context".to_string(), v);
    }
    if let Some(v) = guide.interpretation {
        sections.insert("interpretation".to_string(), v);
    }
    if let Some(v) = guide.passage {
        sections.insert("passage".to_string(), v);
    }
    if let Some(v) = guide.related_verses {
        sections.insert("relatedVerses".to_string(), v);
    }
    if let Some(v) = guide.reflection_questions {
        sections.insert("reflectionQuestions".to_string(), v);
    }
    if let Some(v) = guide.prayer_points {
        sections.insert("prayerPoints".to_string(), v);
    }
    if let Some(v) = guide.interpretation_insights {
        sections.insert("interpretationInsights".to_string(), v);
    }

    let guide_result = crate::services::study_api::StudyGuideResult {
        sections,
        study_guide_id: None,
        from_cache: false,
    };

    // 4. Format into blog content
    let category = guide.category.as_deref().unwrap_or("");
    let disciple_level = guide.disciple_level.as_deref().unwrap_or("beginner");
    let blog = content_formatter::format_blog_post(
        &guide.input_value,
        &guide_result,
        category,
        disciple_level,
        &guide.language,
    );

    // 5. Build slug from title + locale
    let slug = format!("{}-{}", slug::slugify(&guide.input_value), guide.language);

    // 6. Persist
    let input = post::CreatePostInput {
        title: blog.title,
        content: blog.content,
        excerpt: blog.excerpt,
        locale: guide.language.clone(),
        tags: blog.tags,
        featured: false,
        status: "published".to_string(),
        slug: Some(slug),
        source_type: Some("study_guide".to_string()),
        source_topic_id: guide.topic_id,
        source_learning_path_id: guide.learning_path_id,
        source_guide_id: Some(guide_id),
        scheduled_for: None,
    };

    let p = post::create_post(&state.pool, input).await?;

    tracing::info!(
        guide_id = %guide_id,
        slug = %p.slug,
        locale = %p.locale,
        "Blog post generated from study guide"
    );

    Ok(Json(json!({
        "success": true,
        "already_exists": false,
        "data": {
            "id":     p.id,
            "slug":   p.slug,
            "title":  p.title,
            "locale": p.locale
        }
    })))
}

// ---------------------------------------------------------------------------
// Content pipeline progress — where telegram_daily_post and prewarm start
// ---------------------------------------------------------------------------

pub async fn content_pipeline_overview(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(job_name): Path<String>,
) -> Result<Json<Value>, AppError> {
    verify_admin(&headers, &state).await?;
    let overview = content_pipeline::overview(&state.pool, &job_name).await?;
    Ok(Json(json!({ "success": true, "data": overview })))
}

#[derive(Deserialize)]
pub struct SetStartBody {
    pub learning_path_id: Option<Uuid>,
    /// Takes precedence over `learning_path_id`. Both null clears the override.
    pub learning_path_topic_id: Option<Uuid>,
}

pub async fn content_pipeline_set_start(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(job_name): Path<String>,
    Json(body): Json<SetStartBody>,
) -> Result<Json<Value>, AppError> {
    verify_admin(&headers, &state).await?;
    content_pipeline::set_start(
        &state.pool,
        &job_name,
        body.learning_path_id,
        body.learning_path_topic_id,
    )
    .await?;
    let overview = content_pipeline::overview(&state.pool, &job_name).await?;
    Ok(Json(json!({ "success": true, "data": overview })))
}
