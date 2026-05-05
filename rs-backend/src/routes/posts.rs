use axum::extract::{Path, Query, State};
use axum::Json;
use serde_json::{json, Value};

use crate::error::AppError;
use crate::models::post;
use crate::AppState;

pub async fn list_posts(
    State(state): State<AppState>,
    Query(query): Query<post::ListPostsQuery>,
) -> Result<Json<Value>, AppError> {
    let result = post::list_posts(&state.pool, &query).await?;
    Ok(Json(json!({
        "success": true,
        "data": result.posts,
        "pagination": result.pagination,
    })))
}

pub async fn get_post(
    State(state): State<AppState>,
    Path(slug): Path<String>,
) -> Result<Json<Value>, AppError> {
    let p = post::get_post_by_slug(&state.pool, &slug).await?;
    let learning_path = post::get_learning_path_for_post(&state.pool, &p).await?;
    let word_count = p.content.split_whitespace().count() as i32;
    let read_time = (word_count as f64 / 200.0).ceil() as i32;

    Ok(Json(json!({
        "success": true,
        "data": {
            "id": p.id,
            "slug": p.slug,
            "title": p.title,
            "excerpt": p.excerpt,
            "content": p.content,
            "author": p.author,
            "locale": p.locale,
            "tags": p.tags,
            "featured": p.featured,
            "status": p.status,
            "published_at": p.published_at,
            "read_time": read_time.max(1),
            "learning_path": learning_path,
        }
    })))
}

pub async fn get_tags(
    State(state): State<AppState>,
    Query(params): Query<std::collections::HashMap<String, String>>,
) -> Result<Json<Value>, AppError> {
    let locale = params.get("locale").map(|s| s.as_str()).unwrap_or("en");
    let tags = post::get_tags(&state.pool, locale).await?;
    Ok(Json(json!({ "success": true, "data": tags })))
}

pub async fn search_posts(
    State(state): State<AppState>,
    Query(query): Query<post::SearchQuery>,
) -> Result<Json<Value>, AppError> {
    if query.q.trim().is_empty() {
        return Err(AppError::BadRequest(
            "Search query 'q' is required".to_string(),
        ));
    }
    let result = post::search_posts(&state.pool, &query).await?;
    Ok(Json(json!({
        "success": true,
        "data": result.posts,
        "pagination": result.pagination,
    })))
}

pub async fn get_adjacent_posts(
    State(state): State<AppState>,
    Path(slug): Path<String>,
) -> Result<Json<Value>, AppError> {
    let adjacent = post::get_adjacent_posts(&state.pool, &slug).await?;
    Ok(Json(json!({
        "success": true,
        "data": adjacent,
    })))
}

pub async fn list_learning_paths(
    State(state): State<AppState>,
    Query(params): Query<std::collections::HashMap<String, String>>,
) -> Result<Json<Value>, AppError> {
    let locale = params.get("locale").map(|s| s.as_str()).unwrap_or("en");
    let paths = post::list_learning_paths(&state.pool, locale).await?;
    Ok(Json(json!({
        "success": true,
        "data": paths,
    })))
}
