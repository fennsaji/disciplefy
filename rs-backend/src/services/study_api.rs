use reqwest::Client;
use serde_json::Value;
use std::collections::HashMap;

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
) -> Result<StudyGuideResult, AppError> {
    // Truncate long fields to prevent URL overflow — same limits as the mobile app.
    // (Non-Latin scripts URL-encode at up to 9 bytes/char, easily blowing past 8 KB limits.)
    let topic_description = topic_description.map(|s| truncate_chars(s, 300));
    let path_title = path_title.map(|s| truncate_chars(s, 100));
    let path_description = path_description.map(|s| truncate_chars(s, 200));

    let mut url = format!(
        "{}/functions/v1/study-generate-v2?input_type={}&input_value={}&language={}&mode=standard",
        config.supabase_url,
        urlencoding::encode(input_type),
        urlencoding::encode(input_value),
        urlencoding::encode(language),
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

    tracing::info!(
        input_type = %input_type,
        input_value = %input_value,
        language = %language,
        mode = "standard",
        topic_description = %topic_description.as_deref().unwrap_or("(none)"),
        path_title = %path_title.as_deref().unwrap_or("(none)"),
        path_description = %path_description.as_deref().unwrap_or("(none)"),
        disciple_level = %disciple_level.unwrap_or("(none)"),
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
    let mut sections = HashMap::new();

    for line in body.lines() {
        if let Some(data) = line.strip_prefix("data: ") {
            if let Ok(parsed) = serde_json::from_str::<Value>(data) {
                // Check for error event
                if parsed.get("code").is_some() && parsed.get("message").is_some() {
                    return Err(AppError::Internal(format!(
                        "Study API error: {} - {}",
                        parsed["code"].as_str().unwrap_or("unknown"),
                        parsed["message"].as_str().unwrap_or("unknown")
                    )));
                }

                // Parse section events
                if let (Some(section_type), Some(content)) =
                    (parsed.get("type"), parsed.get("content"))
                {
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
        }
    }

    if sections.is_empty() {
        return Err(AppError::Internal(
            "No sections received from study-generate-v2".to_string(),
        ));
    }

    tracing::info!(section_count = sections.len(), "Study guide received");
    Ok(StudyGuideResult { sections })
}
