mod auth;
mod config;
mod cron;
mod db;
mod error;
mod models;
mod routes;
mod services;

use std::net::SocketAddr;
use std::time::Duration;

use axum::extract::DefaultBodyLimit;
use config::Config;
use reqwest::Client;
use sqlx::PgPool;
use tower_http::cors::{AllowHeaders, AllowMethods, AllowOrigin, CorsLayer};
use tracing_subscriber::EnvFilter;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub config: Config,
    pub http: Client,
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();

    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let config = Config::from_env();
    let pool = db::create_pool(&config.database_url, config.db_pool_size).await;
    let http = Client::builder()
        .timeout(Duration::from_secs(120))
        .build()
        .expect("Failed to build HTTP client");

    sqlx::query("SELECT 1").execute(&pool).await.expect("Database ping failed");
    tracing::info!("rs-backend: Database connected");

    let state = AppState {
        pool: pool.clone(),
        config: config.clone(),
        http: http.clone(),
    };

    cron::start_scheduler(pool.clone(), config.clone(), http.clone()).await;

    let origins: Vec<_> = config
        .allowed_origins
        .iter()
        .filter_map(|o| o.parse().ok())
        .collect();
    let cors = CorsLayer::new()
        .allow_origin(AllowOrigin::list(origins))
        .allow_methods(AllowMethods::any())
        .allow_headers(AllowHeaders::any());

    let app = routes::create_router()
        .with_state(state)
        .layer(cors)
        .layer(DefaultBodyLimit::max(256 * 1024)); // 256 KB

    let addr = SocketAddr::from(([0, 0, 0, 0], config.port));
    tracing::info!("Listening on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();
}

async fn shutdown_signal() {
    tokio::signal::ctrl_c()
        .await
        .expect("Failed to listen for ctrl+c");
    tracing::info!("Shutdown signal received");
}
