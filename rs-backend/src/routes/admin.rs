use std::collections::HashMap;
use std::sync::atomic::Ordering;

use axum::extract::{Path, State};
use axum::http::HeaderMap;
use axum::Json;
use serde::Deserialize;
use serde_json::{json, Value};
use uuid::Uuid;

use crate::auth;
use crate::cron::{BLOG_GENERATION_RUNNING, BLOG_RETRY_RUNNING};
use crate::error::AppError;
use crate::models::{cron_config, post};
use crate::services::content_formatter;
use crate::AppState;

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
    verify_admin(&headers, &state).await?;

    let _guard = crate::cron::CronGuard::try_acquire(&BLOG_GENERATION_RUNNING)
        .ok_or_else(|| AppError::BadRequest("Blog generation is already running".to_string()))?;

    let pool = state.pool.clone();
    let config = state.config.clone();
    let http = state.http.clone();
    tokio::spawn(async move {
        // _guard is moved into the spawned task so it releases when done
        let _g = _guard;
        if let Err(e) =
            crate::cron::blog_generator::run_blog_generation(&pool, &config, &http).await
        {
            tracing::error!("Manual CRON trigger failed: {}", e);
        }
    });

    Ok(Json(
        json!({ "success": true, "message": "Blog generation triggered" }),
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
    Ok(Json(json!({
        "is_running": generation_running || retry_running,
        "blog_generation_running": generation_running,
        "blog_retry_running": retry_running,
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
                        // Per-run enabled check
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
                        let flag = if n == "blog_retry" {
                            &crate::cron::BLOG_RETRY_RUNNING
                        } else {
                            &crate::cron::BLOG_GENERATION_RUNNING
                        };
                        let _guard = match crate::cron::CronGuard::try_acquire(flag) {
                            Some(g) => g,
                            None => {
                                tracing::warn!("CRON skipped: previous run still in progress");
                                return;
                            }
                        };
                        if let Err(e) =
                            crate::cron::blog_generator::run_blog_generation(&p, &c, &h).await
                        {
                            tracing::error!("CRON failed: {}", e);
                        }
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
    if let Some(v) = guide.summary        { sections.insert("summary".to_string(), v); }
    if let Some(v) = guide.context        { sections.insert("context".to_string(), v); }
    if let Some(v) = guide.interpretation { sections.insert("interpretation".to_string(), v); }
    if let Some(v) = guide.passage        { sections.insert("passage".to_string(), v); }
    if let Some(v) = guide.related_verses        { sections.insert("relatedVerses".to_string(), v); }
    if let Some(v) = guide.reflection_questions  { sections.insert("reflectionQuestions".to_string(), v); }
    if let Some(v) = guide.prayer_points         { sections.insert("prayerPoints".to_string(), v); }
    if let Some(v) = guide.interpretation_insights { sections.insert("interpretationInsights".to_string(), v); }

    let guide_result = crate::services::study_api::StudyGuideResult { sections };

    // 4. Format into blog content
    let category       = guide.category.as_deref().unwrap_or("");
    let disciple_level = guide.disciple_level.as_deref().unwrap_or("beginner");
    let blog = content_formatter::format_blog_post(
        &guide.input_value,
        &guide_result,
        category,
        disciple_level,
        &guide.language,
    );

    // 5. Build slug from title + locale
    let slug = format!("{}-{}", slug::slugify(&guide.input_value), &guide.language);

    // 6. Persist
    let input = post::CreatePostInput {
        title:    blog.title,
        content:  blog.content,
        excerpt:  blog.excerpt,
        locale:   guide.language.clone(),
        tags:     blog.tags,
        featured: false,
        status:   "published".to_string(),
        slug:     Some(slug),
        source_type:             Some("study_guide".to_string()),
        source_topic_id:         guide.topic_id,
        source_learning_path_id: guide.learning_path_id,
        source_guide_id:         Some(guide_id),
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
