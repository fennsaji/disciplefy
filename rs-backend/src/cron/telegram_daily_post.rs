//! Posts the daily lesson to the official Telegram channel, in each language.
//!
//! The work itself lives in the `telegram-daily-post` Edge Function — picking
//! the next lesson, reusing the cached teaser, sending the message and writing
//! the ledger row. This job exists so the schedule sits in `cron_config`
//! alongside the other jobs, where the admin dashboard can change it without a
//! deploy. It used to be a pg_cron entry, invisible to that page.
//!
//! One call per language, sequential: the function is idempotent per language
//! per day, so a retry or an overlapping run cannot double-post.

use reqwest::Client;
use std::time::Duration;

use crate::config::Config;
use crate::error::AppError;

/// Languages the channel posts in, in send order.
const LANGUAGES: [&str; 3] = ["en", "hi", "ml"];

/// Generous: the function may generate a teaser through an LLM on a cache miss.
const TIMEOUT: Duration = Duration::from_secs(60);

pub async fn run_telegram_daily_post(config: &Config, http: &Client) -> Result<(), AppError> {
    tracing::info!("Starting Telegram daily post CRON job");
    let url = format!("{}/functions/v1/telegram-daily-post", config.supabase_url);
    let (mut posted, mut skipped, mut failed) = (0usize, 0usize, 0usize);

    for language in LANGUAGES {
        let response = http
            .post(&url)
            .header("apikey", &config.supabase_anon_key)
            .header(
                "Authorization",
                format!("Bearer {}", config.supabase_service_role_key),
            )
            .header("Content-Type", "application/json")
            .timeout(TIMEOUT)
            .json(&serde_json::json!({ "language": language }))
            .send()
            .await;

        match response {
            Ok(r) if r.status().is_success() => {
                let body: serde_json::Value = r.json().await.unwrap_or_default();
                // The function reports its own outcome: a language with no
                // published article for the next lesson skips rather than
                // posting, and that is not a failure.
                if body
                    .get("skipped")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false)
                {
                    skipped += 1;
                    tracing::info!(
                        language,
                        reason = %body.get("reason").and_then(|v| v.as_str()).unwrap_or("unknown"),
                        "Telegram daily post skipped"
                    );
                } else {
                    posted += 1;
                    tracing::info!(
                        language,
                        topic = %body.get("topic_title").and_then(|v| v.as_str()).unwrap_or(""),
                        "Telegram daily post sent"
                    );
                }
            }
            Ok(r) => {
                failed += 1;
                let status = r.status();
                let body = r.text().await.unwrap_or_default();
                tracing::error!(language, %status, "Telegram daily post failed: {}", body);
            }
            Err(e) => {
                failed += 1;
                tracing::error!(language, "Telegram daily post request failed: {}", e);
            }
        }
    }

    tracing::info!(
        posted,
        skipped,
        failed,
        "Telegram daily post CRON job finished"
    );
    Ok(())
}
