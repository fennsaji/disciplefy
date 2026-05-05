pub mod admin;
pub mod health;
pub mod posts;

use crate::AppState;
use axum::routing::{get, post, put};
use axum::Router;

pub fn create_router() -> Router<AppState> {
    Router::new()
        .route("/health", get(health::health_check))
        .route("/api/v1/posts", get(posts::list_posts))
        .route("/api/v1/posts/tags", get(posts::get_tags))
        .route("/api/v1/posts/search", get(posts::search_posts))
        .route("/api/v1/posts/:slug", get(posts::get_post))
        .route(
            "/api/v1/posts/:slug/adjacent",
            get(posts::get_adjacent_posts),
        )
        .route("/api/v1/learning-paths", get(posts::list_learning_paths))
        .route("/api/v1/admin/posts", post(admin::create_post))
        .route(
            "/api/v1/admin/posts/:id",
            put(admin::update_post).delete(admin::delete_post),
        )
        .route("/api/v1/admin/posts/:id/publish", post(admin::publish_post))
        .route(
            "/api/v1/admin/posts/:id/unpublish",
            post(admin::unpublish_post),
        )
        .route("/api/v1/admin/cron/trigger", post(admin::trigger_cron))
        // Cron control — status before :name routes (explicit beats dynamic at same depth)
        .route("/api/v1/admin/cron/status", get(admin::cron_status))
        .route("/api/v1/admin/cron/:name/enable", post(admin::cron_enable))
        .route(
            "/api/v1/admin/cron/:name/disable",
            post(admin::cron_disable),
        )
        .route(
            "/api/v1/admin/cron/:name/schedule",
            put(admin::cron_update_schedule),
        )
        .route(
            "/api/v1/admin/study-guides/:guide_id/generate-blog",
            post(admin::generate_blog_from_study_guide),
        )
}
