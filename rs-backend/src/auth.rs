use axum::http::HeaderMap;
use reqwest::Client;
use serde::Deserialize;
use sqlx::PgPool;
use uuid::Uuid;

use crate::config::Config;
use crate::error::AppError;

#[derive(Debug, Clone)]
pub struct AdminUser {
    pub _user_id: Uuid,
}

#[derive(Debug, Deserialize)]
struct SupabaseUser {
    id: String,
}

async fn validate_supabase_jwt(
    token: &str,
    config: &Config,
    http: &Client,
) -> Result<Uuid, AppError> {
    let url = format!("{}/auth/v1/user", config.supabase_url);

    let resp = http
        .get(&url)
        .header("Authorization", format!("Bearer {}", token))
        .header("apikey", &config.supabase_anon_key)
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("Auth request failed: {}", e)))?;

    if !resp.status().is_success() {
        return Err(AppError::Unauthorized(
            "Invalid or expired token".to_string(),
        ));
    }

    let user: SupabaseUser = resp
        .json()
        .await
        .map_err(|e| AppError::Internal(format!("Failed to parse auth response: {}", e)))?;

    Uuid::parse_str(&user.id)
        .map_err(|_| AppError::Internal("Invalid user ID from auth".to_string()))
}

async fn is_admin(pool: &PgPool, user_id: Uuid) -> Result<bool, AppError> {
    let is_admin: Option<bool> =
        sqlx::query_scalar("SELECT is_admin FROM user_profiles WHERE id = $1")
            .bind(user_id)
            .fetch_optional(pool)
            .await?;

    Ok(is_admin.unwrap_or(false))
}

fn extract_bearer_token(headers: &HeaderMap) -> Result<String, AppError> {
    let header = headers
        .get("authorization")
        .and_then(|v| v.to_str().ok())
        .ok_or_else(|| AppError::Unauthorized("Missing Authorization header".to_string()))?;

    if !header.starts_with("Bearer ") {
        return Err(AppError::Unauthorized(
            "Invalid Authorization header format".to_string(),
        ));
    }

    Ok(header[7..].to_string())
}

pub async fn require_admin(
    headers: &HeaderMap,
    config: &Config,
    pool: &PgPool,
    http: &Client,
) -> Result<AdminUser, AppError> {
    let token = extract_bearer_token(headers)?;
    let user_id = validate_supabase_jwt(&token, config, http).await?;

    if !is_admin(pool, user_id).await? {
        return Err(AppError::Forbidden("Admin access required".to_string()));
    }

    Ok(AdminUser { _user_id: user_id })
}
