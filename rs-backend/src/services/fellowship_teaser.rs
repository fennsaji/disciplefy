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
    /// Catalogue topic id. The teaser cache keys on it, so every surface that
    /// teases the same lesson (fellowship posts, the Telegram channel) shares
    /// one wording per language instead of paying for its own.
    pub topic_id: Uuid,
    pub topic_title: &'a str,
    pub path_title: &'a str,
    pub language: &'a str,
    pub summary: &'a str,
    pub verse: Option<&'a str>,
    pub question: Option<&'a str>,
}

/// JSON body for `fellowship-posts/daily-teaser`. `topic_id` is what the edge
/// function keys its cache on; without it the teaser is keyed on a hash of the
/// localized titles and never matches the one the Telegram job generated.
fn request_body(req: &TeaserRequest<'_>) -> serde_json::Value {
    serde_json::json!({
        "fellowship_id": req.fellowship_id,
        "topic_id": req.topic_id,
        "topic_title": req.topic_title,
        "path_title": req.path_title,
        "language": req.language,
        "summary": req.summary,
        "verse": req.verse,
        "question": req.question,
    })
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
    let body = request_body(&req);

    let resp = match http
        .post(&url)
        .header(
            "Authorization",
            format!("Bearer {}", config.supabase_service_role_key),
        )
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn request_body_carries_topic_id_for_cache_key() {
        let topic_id = Uuid::parse_str("111e8400-e29b-41d4-a716-446655440001").unwrap();
        let body = request_body(&TeaserRequest {
            fellowship_id: Uuid::nil(),
            topic_id,
            topic_title: "यीशु मसीह कौन हैं?",
            path_title: "नए विश्वासी की मूल बातें",
            language: "hi",
            summary: "s",
            verse: None,
            question: Some("q"),
        });
        assert_eq!(body["topic_id"], topic_id.to_string());
        assert_eq!(body["language"], "hi");
        assert_eq!(body["question"], "q");
        assert!(body["verse"].is_null());
    }
}
