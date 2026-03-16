use sqlx::postgres::{PgConnectOptions, PgPoolOptions};
use sqlx::{Executor, PgPool};
use std::str::FromStr;

pub async fn create_pool(database_url: &str, pool_size: u32) -> PgPool {
    let connect_options = PgConnectOptions::from_str(database_url)
        .expect("Invalid DATABASE_URL")
        .statement_cache_capacity(0);

    PgPoolOptions::new()
        .max_connections(pool_size)
        .after_connect(|conn, _meta| {
            Box::pin(async move {
                conn.execute("DEALLOCATE ALL").await?;
                Ok(())
            })
        })
        .connect_with(connect_options)
        .await
        .expect("Failed to connect to database")
}
