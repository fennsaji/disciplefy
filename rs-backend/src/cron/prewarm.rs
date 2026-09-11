//! Pre-generates learning-path study guides on the Batch API.
//!
//! Every learning-path lesson produces the same guide for every reader, so it
//! is worth generating each one ahead of time rather than making the first
//! reader wait and pay. Batch costs half the streaming rate and answers within
//! 24 hours, which suits work nobody is waiting on.
//!
//! The work lives in the `prewarm` Edge Function, which holds the prompts. This
//! job only ticks it: one call decides whether to start a run, move it to the
//! second pass, or write the finished guides. Running hourly means a batch is
//! picked up soon after it ends without anything holding a connection open for
//! hours.
//!
//! Spending is governed by a monthly budget in `system_config`, editable from
//! the admin dashboard. When it is spent the function reports that and does
//! nothing until the next month.

use reqwest::Client;
use std::time::Duration;

use crate::config::Config;
use crate::error::AppError;

/// Submitting a batch of several hundred requests takes a moment, and reading
/// results back is a stream; neither is quick, and neither is urgent.
const TIMEOUT: Duration = Duration::from_secs(300);

pub async fn run_prewarm(config: &Config, http: &Client) -> Result<(), AppError> {
    tracing::info!("Starting pre-warm CRON job");
    let url = format!("{}/functions/v1/prewarm", config.supabase_url);

    let response = http
        .post(&url)
        .header("apikey", &config.supabase_anon_key)
        .header(
            "Authorization",
            format!("Bearer {}", config.supabase_service_role_key),
        )
        .header("Content-Type", "application/json")
        .timeout(TIMEOUT)
        .json(&serde_json::json!({}))
        .send()
        .await;

    match response {
        Ok(r) if r.status().is_success() => {
            let body: serde_json::Value = r.json().await.unwrap_or_default();
            let action = body
                .get("action")
                .and_then(|v| v.as_str())
                .unwrap_or("unknown");
            tracing::info!(action, body = %body, "Pre-warm tick finished");
            Ok(())
        }
        Ok(r) => {
            let status = r.status();
            let body = r.text().await.unwrap_or_default();
            tracing::error!(%status, %body, "Pre-warm tick failed");
            Ok(())
        }
        Err(e) => {
            // A failed tick costs nothing: the next one picks up wherever this
            // run left off, because the batch id is held in the database.
            tracing::error!(error = %e, "Pre-warm tick could not reach the function");
            Ok(())
        }
    }
}
