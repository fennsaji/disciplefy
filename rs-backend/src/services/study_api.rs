use reqwest::Client;
use serde_json::Value;
use std::collections::HashMap;

use crate::config::Config;
use crate::error::AppError;

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
    let mut url = format!(
        "{}/functions/v1/study-generate-v2?input_type={}&input_value={}&language={}&mode=standard",
        config.supabase_url,
        urlencoding::encode(input_type),
        urlencoding::encode(input_value),
        urlencoding::encode(language),
    );

    // Add optional params
    if let Some(desc) = topic_description {
        url.push_str(&format!("&topic_description={}", urlencoding::encode(desc)));
    }
    if let Some(title) = path_title {
        url.push_str(&format!("&path_title={}", urlencoding::encode(title)));
    }
    if let Some(desc) = path_description {
        url.push_str(&format!("&path_description={}", urlencoding::encode(desc)));
    }
    if let Some(level) = disciple_level {
        url.push_str(&format!("&disciple_level={}", urlencoding::encode(level)));
    }

    tracing::info!(
        language,
        input_type,
        input_value,
        "Calling study-generate-v2"
    );

    let resp = http
        .get(&url)
        .header(
            "Authorization",
            format!("Bearer {}", config.supabase_service_role_key),
        )
        .header("apikey", &config.supabase_anon_key)
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

    // Parse SSE stream
    let body = resp
        .text()
        .await
        .map_err(|e| AppError::Internal(format!("Failed to read SSE body: {}", e)))?;
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
