use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;

pub async fn create_pool(database_url: &str, pool_size: u32) -> PgPool {
    PgPoolOptions::new()
        .max_connections(pool_size)
        .connect(database_url)
        .await
        .expect("Failed to connect to database")
}
