use axum::extract::{Path, State};
use axum::http::HeaderMap;
use axum::Json;
use serde_json::{json, Value};
use uuid::Uuid;

use crate::auth;
use crate::error::AppError;
use crate::models::post;
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

    let _guard = crate::cron::CronGuard::try_acquire()
        .ok_or_else(|| AppError::BadRequest("Blog generation is already running".to_string()))?;

    let pool = state.pool.clone();
    let config = state.config.clone();
    let http = state.http.clone();
    tokio::spawn(async move {
        // _guard is moved into the spawned task so it releases when done
        let _g = _guard;
        if let Err(e) = crate::cron::blog_generator::run_blog_generation(&pool, &config, &http).await {
            tracing::error!("Manual CRON trigger failed: {}", e);
        }
    });

    Ok(Json(json!({ "success": true, "message": "Blog generation triggered" })))
}
