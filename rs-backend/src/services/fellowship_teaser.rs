//! Calls `fellowship-posts/daily-teaser` to get an LLM-written teaser for the
//! Discipler daily fellowship post. Any failure — transport, non-200, parse
//! error, or a field out of bounds — degrades to `None` so the caller falls
//! back to the plain-template post. Never log the teaser text or the summary
//! sent to generate it.
use std::time::Duration;

use reqwest::Client;
use serde::Deserialize;
use uuid::Uuid;

use crate::config::Config;

const TIMEOUT: Duration = Duration::from_secs(20);
const MAX_HOOK_CHARS: usize = 120;
const MAX_BODY_CHARS: usize = 300;

#[derive(Debug, Clone)]
pub struct Teaser {
    pub hook: String,
    pub body: String,
}

#[derive(Deserialize)]
struct TeaserResponse {
    hook: String,
    body: String,
}

pub struct TeaserRequest<'a> {
    pub fellowship_id: Uuid,
    pub topic_title: &'a str,
    pub path_title: &'a str,
    pub language: &'a str,
    pub summary: &'a str,
    pub verse: Option<&'a str>,
    pub question: Option<&'a str>,
}

/// Fetch a daily teaser, or `None` if it can't be produced. Never fails the caller.
pub async fn fetch_daily_teaser(
    config: &Config,
    http: &Client,
    req: TeaserRequest<'_>,
) -> Option<Teaser> {
    let url = format!(
        "{}/functions/v1/fellowship-posts/daily-teaser",
        config.supabase_url
    );
    let body = serde_json::json!({
        "fellowship_id": req.fellowship_id,
        "topic_title": req.topic_title,
        "path_title": req.path_title,
        "language": req.language,
        "summary": req.summary,
        "verse": req.verse,
        "question": req.question,
    });

    let resp = match http
        .post(&url)
        .header("apikey", &config.supabase_anon_key)
        .header("X-Internal-Api-Key", &config.internal_api_key)
        .header("Content-Type", "application/json")
        .timeout(TIMEOUT)
        .json(&body)
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            tracing::warn!("daily-teaser request failed: {}", e);
            return None;
        }
    };

    if !resp.status().is_success() {
        tracing::warn!(status = %resp.status(), "daily-teaser returned non-success");
        return None;
    }

    let parsed = match resp.json::<TeaserResponse>().await {
        Ok(p) => p,
        Err(e) => {
            tracing::warn!("daily-teaser response parse failed: {}", e);
            return None;
        }
    };

    let hook = parsed.hook.trim().to_string();
    let body = parsed.body.trim().to_string();

    if hook.is_empty()
        || body.is_empty()
        || hook.chars().count() > MAX_HOOK_CHARS
        || body.chars().count() > MAX_BODY_CHARS
    {
        tracing::warn!("daily-teaser fields empty or out of bounds, ignoring");
        return None;
    }

    Some(Teaser { hook, body })
}
