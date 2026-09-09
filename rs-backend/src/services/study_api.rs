use reqwest::Client;
use serde_json::Value;
use std::collections::HashMap;
use uuid::Uuid;

use crate::config::Config;
use crate::error::AppError;

/// Truncate a string to at most `max_chars` Unicode scalar values.
/// Always cuts at a character boundary, so the result is always valid UTF-8.
fn truncate_chars(s: &str, max_chars: usize) -> String {
    s.char_indices()
        .nth(max_chars)
        .map(|(byte_idx, _)| &s[..byte_idx])
        .unwrap_or(s)
        .to_string()
}

#[derive(Debug, Clone)]
pub struct StudyGuideResult {
    pub sections: HashMap<String, String>,
    /// From the `complete` event; None if the stream ended without one.
    pub study_guide_id: Option<Uuid>,
    pub from_cache: bool,
}

pub(crate) fn parse_sse_body(body: &str) -> Result<StudyGuideResult, AppError> {
    let mut sections = HashMap::new();
    let mut study_guide_id: Option<Uuid> = None;
    let mut from_cache = false;

    for line in body.lines() {
        let Some(data) = line.strip_prefix("data: ") else {
            continue;
        };
        let Ok(parsed) = serde_json::from_str::<Value>(data) else {
            continue;
        };

        if parsed.get("code").is_some() && parsed.get("message").is_some() {
            return Err(AppError::Internal(format!(
                "Study API error: {} - {}",
                parsed["code"].as_str().unwrap_or("unknown"),
                parsed["message"].as_str().unwrap_or("unknown")
            )));
        }

        if let Some(id) = parsed.get("studyGuideId").and_then(Value::as_str) {
            study_guide_id = Uuid::parse_str(id).ok();
            from_cache = parsed
                .get("fromCache")
                .and_then(Value::as_bool)
                .unwrap_or(false);
            continue;
        }

        if let (Some(section_type), Some(content)) = (parsed.get("type"), parsed.get("content")) {
            let key = section_type.as_str().unwrap_or("").to_string();
            let val = match content {
                Value::String(s) => s.clone(),
                Value::Array(arr) => serde_json::to_string(arr).unwrap_or_default(),
                other => other.to_string(),
            };
            if !key.is_empty() {
                sections.insert(key, val);
            }
        }
    }

    if sections.is_empty() {
        return Err(AppError::Internal(
            "No sections received from study-generate-v2".to_string(),
        ));
    }
    Ok(StudyGuideResult {
        sections,
        study_guide_id,
        from_cache,
    })
}

/// Call study-generate-v2 Edge Function via SSE and collect all sections.
///
/// The SSE stream emits events:
/// - "section" with data: {"type":"summary","content":"..."}
/// - "complete" with data: {"studyGuideId":"..."}
/// - "error" with data: {"code":"...","message":"..."}
#[allow(clippy::too_many_arguments)]
pub async fn generate_study_guide(
    http: &Client,
    config: &Config,
    input_type: &str,
    input_value: &str,
    topic_description: Option<&str>,
    path_title: Option<&str>,
    path_description: Option<&str>,
    disciple_level: Option<&str>,
    language: &str,
    mode: &str,
    // Catalogue topic, when this study is a learning-path lesson. The cache
    // keys on it ahead of the title, so a guide made here under a translated
    // title is the guide the app serves for the same lesson.
    topic_id: Option<Uuid>,
) -> Result<StudyGuideResult, AppError> {
    // Truncate long fields to prevent URL overflow — same limits as the mobile app.
    // (Non-Latin scripts URL-encode at up to 9 bytes/char, easily blowing past 8 KB limits.)
    let topic_description = topic_description.map(|s| truncate_chars(s, 300));
    let path_title = path_title.map(|s| truncate_chars(s, 100));
    let path_description = path_description.map(|s| truncate_chars(s, 200));

    let mut url = format!(
        "{}/functions/v1/study-generate-v2?input_type={}&input_value={}&language={}&mode={}",
        config.supabase_url,
        urlencoding::encode(input_type),
        urlencoding::encode(input_value),
        urlencoding::encode(language),
        urlencoding::encode(mode),
    );

    // Add optional context params — these are what the LLM uses for full context
    if let Some(ref desc) = topic_description {
        url.push_str(&format!("&topic_description={}", urlencoding::encode(desc)));
    }
    if let Some(ref title) = path_title {
        url.push_str(&format!("&path_title={}", urlencoding::encode(title)));
    }
    if let Some(ref desc) = path_description {
        url.push_str(&format!("&path_description={}", urlencoding::encode(desc)));
    }
    if let Some(level) = disciple_level {
        url.push_str(&format!("&disciple_level={}", urlencoding::encode(level)));
    }
    if let Some(id) = topic_id {
        url.push_str(&format!("&topic_id={id}"));
    }

    tracing::info!(
        input_type = %input_type,
        input_value = %input_value,
        language = %language,
        mode = %mode,
        topic_description = %topic_description.as_deref().unwrap_or("(none)"),
        path_title = %path_title.as_deref().unwrap_or("(none)"),
        path_description = %path_description.as_deref().unwrap_or("(none)"),
        disciple_level = %disciple_level.unwrap_or("(none)"),
        topic_id = %topic_id.map(|i| i.to_string()).unwrap_or_else(|| "(none)".into()),
        "study-generate-v2 params"
    );

    let resp = http
        .get(&url)
        .header("apikey", &config.supabase_anon_key)
        .header("X-Internal-Api-Key", &config.internal_api_key)
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("HTTP request failed: {}", e)))?;

    if !resp.status().is_success() {
        let status = resp.status();
        let body = resp.text().await.unwrap_or_default();
        return Err(AppError::Internal(format!(
            "study-generate-v2 returned {}: {}",
            status, body
        )));
    }

    // Parse SSE stream — use bytes + lossy UTF-8 to handle Malayalam/Hindi characters
    let raw = resp
        .bytes()
        .await
        .map_err(|e| AppError::Internal(format!("Failed to read SSE body: {}", e)))?;
    let body = String::from_utf8_lossy(&raw).into_owned();

    let result = parse_sse_body(&body)?;
    tracing::info!(
        section_count = result.sections.len(),
        from_cache = result.from_cache,
        "Study guide received"
    );
    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_sections_and_complete_event() {
        let body = "event: section\ndata: {\"type\":\"summary\",\"content\":\"Hello\"}\n\nevent: complete\ndata: {\"studyGuideId\":\"6f1c0d2e-4a6b-4c1d-9e2f-0123456789ab\",\"tokensConsumed\":0,\"fromCache\":true}\n";
        let r = parse_sse_body(body).unwrap();
        assert_eq!(r.sections.get("summary").map(String::as_str), Some("Hello"));
        assert_eq!(
            r.study_guide_id.map(|u| u.to_string()).as_deref(),
            Some("6f1c0d2e-4a6b-4c1d-9e2f-0123456789ab")
        );
        assert!(r.from_cache);
    }

    #[test]
    fn error_event_is_an_error() {
        let body = "data: {\"code\":\"RATE_LIMIT\",\"message\":\"slow down\"}\n";
        assert!(parse_sse_body(body).is_err());
    }

    #[test]
    fn empty_sections_is_an_error() {
        assert!(parse_sse_body("data: {\"studyGuideId\":\"x\"}\n").is_err());
    }
}
