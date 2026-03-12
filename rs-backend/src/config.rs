use std::env;
use std::fmt;

#[derive(Clone)]
pub struct Config {
    pub database_url: String,
    pub supabase_url: String,
    pub supabase_anon_key: String,
    pub supabase_service_role_key: String,
    pub port: u16,
    pub allowed_origins: Vec<String>,
    pub db_pool_size: u32,
}

impl fmt::Debug for Config {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Config")
            .field("database_url", &"[REDACTED]")
            .field("supabase_url", &self.supabase_url)
            .field("supabase_anon_key", &"[REDACTED]")
            .field("supabase_service_role_key", &"[REDACTED]")
            .field("port", &self.port)
            .field("allowed_origins", &self.allowed_origins)
            .field("db_pool_size", &self.db_pool_size)
            .finish()
    }
}

impl Config {
    pub fn from_env() -> Self {
        Self {
            database_url: env::var("DATABASE_URL").expect("DATABASE_URL must be set"),
            supabase_url: env::var("SUPABASE_URL").expect("SUPABASE_URL must be set"),
            supabase_anon_key: env::var("SUPABASE_ANON_KEY")
                .expect("SUPABASE_ANON_KEY must be set"),
            supabase_service_role_key: env::var("SUPABASE_SERVICE_ROLE_KEY")
                .expect("SUPABASE_SERVICE_ROLE_KEY must be set"),
            port: env::var("PORT")
                .unwrap_or_else(|_| "8080".to_string())
                .parse()
                .expect("PORT must be a number"),
            allowed_origins: env::var("ALLOWED_ORIGINS")
                .unwrap_or_else(|_| "http://localhost:3000".to_string())
                .split(',')
                .map(|s| s.trim().to_string())
                .collect(),
            db_pool_size: env::var("DB_POOL_SIZE")
                .unwrap_or_else(|_| "5".to_string())
                .parse()
                .expect("DB_POOL_SIZE must be a number"),
        }
    }
}
