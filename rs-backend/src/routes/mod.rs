pub mod health;
pub mod posts;
pub mod admin;

use axum::routing::{get, post, put};
use axum::Router;
use crate::AppState;

pub fn create_router() -> Router<AppState> {
    Router::new()
        .route("/health", get(health::health_check))
        .route("/api/v1/posts", get(posts::list_posts))
        .route("/api/v1/posts/tags", get(posts::get_tags))
        .route("/api/v1/posts/search", get(posts::search_posts))
        .route("/api/v1/posts/{slug}", get(posts::get_post))
        .route("/api/v1/admin/posts", post(admin::create_post))
        .route("/api/v1/admin/posts/{id}", put(admin::update_post).delete(admin::delete_post))
        .route("/api/v1/admin/posts/{id}/publish", post(admin::publish_post))
        .route("/api/v1/admin/posts/{id}/unpublish", post(admin::unpublish_post))
        .route("/api/v1/admin/cron/trigger", post(admin::trigger_cron))
}
