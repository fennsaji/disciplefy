use axum::Json;
use serde_json::{json, Value};

pub async fn health_check() -> Json<Value> {
    Json(json!({
        "success": true,
        "status": "healthy",
        "service": "rs-backend"
    }))
}
