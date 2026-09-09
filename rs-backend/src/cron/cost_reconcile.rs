//! Checks our own cost figures against what Anthropic actually billed.
//!
//! Every cost number in the app is our own arithmetic: token counts times a
//! price table kept by hand. That table has already been wrong three ways at
//! once, and nothing noticed, because the same figure feeds the budgets, the
//! daily ceiling and the dashboard. Anthropic's Cost API reports the truth.
//!
//! The comparison lives in the `cost-reconcile` Edge Function. This job runs it
//! once a day for yesterday, the most recent day whose billing has settled, and
//! does nothing but report: a drift beyond a few percent is logged and written
//! to `cost_reconciliation` for the dashboard to show.

use reqwest::Client;
use std::time::Duration;

use crate::config::Config;
use crate::error::AppError;

/// One report request, possibly paged. Generous but not open-ended.
const TIMEOUT: Duration = Duration::from_secs(120);

pub async fn run_cost_reconcile(config: &Config, http: &Client) -> Result<(), AppError> {
    tracing::info!("Starting cost reconciliation CRON job");
    let url = format!("{}/functions/v1/cost-reconcile", config.supabase_url);

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
            tracing::info!(body = %body, "Cost reconciliation finished");
            Ok(())
        }
        Ok(r) => {
            let status = r.status();
            let body = r.text().await.unwrap_or_default();
            tracing::error!(%status, %body, "Cost reconciliation tick failed");
            Ok(())
        }
        Err(e) => {
            // Missing a day's comparison is not worth failing over; tomorrow's
            // run reports the same drift.
            tracing::error!(error = %e, "Cost reconciliation could not reach the function");
            Ok(())
        }
    }
}
