//! Subscription reconciliation CRON.
//!
//! Calls the `expire-subscriptions` Edge Function, which:
//!   - expires subscriptions past their billing period,
//!   - activates Razorpay subscriptions that were paid but whose
//!     `subscription.activated` webhook never arrived,
//!   - clears abandoned checkouts and un-parks the plan they superseded.
//!
//! Razorpay has no "user abandoned checkout" event, and a missed activation
//! webhook otherwise leaves a paying customer on their old plan permanently.
//! This job is the safety net for both.

use reqwest::Client;

use crate::config::Config;
use crate::error::AppError;

/// Invoke the expire-subscriptions Edge Function and log what it reconciled.
pub async fn run_subscription_reconcile(config: &Config, http: &Client) -> Result<(), AppError> {
    let url = format!("{}/functions/v1/expire-subscriptions", config.supabase_url);

    let response = http
        .post(&url)
        // Service-role key: the function is a background job endpoint and is not
        // reachable with the anon key.
        .header(
            "Authorization",
            format!("Bearer {}", config.supabase_service_role_key),
        )
        .header("Content-Type", "application/json")
        .json(&serde_json::json!({}))
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("expire-subscriptions request failed: {e}")))?;

    let status = response.status();
    let body = response.text().await.unwrap_or_default();

    if !status.is_success() {
        return Err(AppError::Internal(format!(
            "expire-subscriptions returned {status}: {body}"
        )));
    }

    tracing::info!("Subscription reconciliation completed: {}", body);
    Ok(())
}
