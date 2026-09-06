//! Discipler daily post: next learning-path topic per fellowship, generated in the
//! fellowship's language through study-generate-v2, posted as Discipler.
use chrono::Utc;
use reqwest::Client;
use sqlx::PgPool;

use crate::config::Config;
use crate::cron::blog_generator::LearningPathTopic;
use crate::error::AppError;
use crate::models::fellowship_daily::{self, DailyFellowship, DailyPostInsert};
use crate::services::{content_formatter, study_api};

pub(crate) struct Localized<'a> {
    pub title: &'a str,
    pub description: Option<&'a str>,
    pub path_title: &'a str,
    pub path_description: &'a str,
}

/// Pick localized fields with English fallback, exactly like blog generation.
pub(crate) fn localize<'a>(topic: &'a LearningPathTopic, locale: &str) -> Localized<'a> {
    let pick = |l: &'a Option<String>, en: &'a str| {
        l.as_deref().filter(|s| !s.trim().is_empty()).unwrap_or(en)
    };
    let pick_opt = |l: &'a Option<String>, en: &'a Option<String>| {
        l.as_deref()
            .filter(|s| !s.trim().is_empty())
            .or(en.as_deref())
    };
    match locale {
        "hi" => Localized {
            title: pick(&topic.hi_title, &topic.title),
            description: pick_opt(&topic.hi_description, &topic.description),
            path_title: pick(&topic.hi_path_title, &topic.path_title),
            path_description: pick(&topic.hi_path_description, &topic.path_description),
        },
        "ml" => Localized {
            title: pick(&topic.ml_title, &topic.title),
            description: pick_opt(&topic.ml_description, &topic.description),
            path_title: pick(&topic.ml_path_title, &topic.path_title),
            path_description: pick(&topic.ml_path_description, &topic.path_description),
        },
        _ => Localized {
            title: &topic.title,
            description: topic.description.as_deref(),
            path_title: &topic.path_title,
            path_description: &topic.path_description,
        },
    }
}

pub(crate) fn batch_mode(study_mode: &str) -> &str {
    match study_mode {
        "recommended" | "ask" => "standard",
        m => m,
    }
}

async fn notify(config: &Config, http: &Client, post_id: uuid::Uuid) -> Result<(), AppError> {
    let url = format!(
        "{}/functions/v1/fellowship-posts/notify",
        config.supabase_url
    );
    let resp = http
        .post(&url)
        .header(
            "Authorization",
            format!("Bearer {}", config.supabase_service_role_key),
        )
        .header("apikey", &config.supabase_anon_key)
        .header("Content-Type", "application/json")
        .json(&serde_json::json!({ "kind": "daily_post", "post_id": post_id }))
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("notify request failed: {e}")))?;
    if !resp.status().is_success() {
        let status = resp.status();
        let body = resp.text().await.unwrap_or_default();
        return Err(AppError::Internal(format!(
            "notify returned {status}: {body}"
        )));
    }
    Ok(())
}

async fn post_for_fellowship(
    pool: &PgPool,
    config: &Config,
    http: &Client,
    f: &DailyFellowship,
) -> Result<(), AppError> {
    let today = Utc::now().date_naive();
    let mut topic = fellowship_daily::find_next_topic_for_fellowship(pool, f.id).await?;
    if topic.is_none() {
        tracing::info!(fellowship = %f.name, "All topics used — wrapping cursor");
        fellowship_daily::reset_topic_cursor(pool, f.id).await?;
        topic = fellowship_daily::find_next_topic_for_fellowship(pool, f.id).await?;
    }
    let Some(topic) = topic else {
        tracing::warn!(fellowship = %f.name, "No active learning-path topics — skipping");
        return Ok(());
    };
    let l = localize(&topic, &f.language);

    let guide = study_api::generate_study_guide(
        http,
        config,
        &topic.input_type,
        l.title,
        l.description,
        Some(l.path_title),
        Some(l.path_description),
        Some(&topic.disciple_level),
        &f.language,
        batch_mode(&topic.study_mode),
    )
    .await?;

    let daily = content_formatter::format_daily_post(l.title, &guide, &f.language);
    let post_id = fellowship_daily::insert_daily_post(
        pool,
        DailyPostInsert {
            fellowship_id: f.id,
            content: &daily.content,
            topic_id: topic.topic_id,
            topic_title: l.title,
            guide_title: l.title,
            study_guide_id: guide.study_guide_id,
            language: &f.language,
            learning_path_topic_id: topic.id,
            post_date: today,
        },
    )
    .await?;
    tracing::info!(fellowship = %f.name, topic = %l.title, %post_id, from_cache = guide.from_cache, "Daily post created");

    if let Err(e) = notify(config, http, post_id).await {
        tracing::error!(%post_id, "Daily post notify failed (post kept): {}", e);
    }
    Ok(())
}

pub async fn run_fellowship_daily_post(
    pool: &PgPool,
    config: &Config,
    http: &Client,
) -> Result<(), AppError> {
    tracing::info!("Starting Discipler daily post CRON job");
    let today = Utc::now().date_naive();
    let fellowships = fellowship_daily::list_daily_fellowships(pool, today).await?;
    if fellowships.is_empty() {
        tracing::info!("No fellowships due for a daily post");
        return Ok(());
    }
    let (mut ok, mut failed) = (0usize, 0usize);
    for f in &fellowships {
        match post_for_fellowship(pool, config, http, f).await {
            Ok(()) => ok += 1,
            Err(e) => {
                failed += 1;
                tracing::error!(fellowship = %f.name, "Daily post failed: {}", e);
            }
        }
    }
    tracing::info!(ok, failed, "Discipler daily post CRON job finished");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn topic() -> LearningPathTopic {
        LearningPathTopic {
            id: uuid::Uuid::nil(),
            topic_id: uuid::Uuid::nil(),
            title: "Faith".into(),
            description: Some("d".into()),
            input_type: "topic".into(),
            path_id: uuid::Uuid::nil(),
            path_title: "Path".into(),
            path_description: "pd".into(),
            disciple_level: "new".into(),
            category: None,
            hi_title: Some("विश्वास".into()),
            ml_title: None,
            hi_description: None,
            ml_description: Some("  ".into()),
            hi_path_title: None,
            ml_path_title: Some("പാത".into()),
            hi_path_description: None,
            ml_path_description: None,
            study_mode: "recommended".into(),
        }
    }

    #[test]
    fn localize_falls_back_to_english() {
        let t = topic();
        let hi = localize(&t, "hi");
        assert_eq!(hi.title, "विश्वास");
        assert_eq!(hi.description, Some("d"));
        assert_eq!(hi.path_title, "Path");
        let ml = localize(&t, "ml");
        assert_eq!(ml.title, "Faith");
        assert_eq!(ml.description, Some("d"));
        assert_eq!(ml.path_title, "പാത");
    }

    #[test]
    fn batch_mode_coerces_interactive_modes() {
        assert_eq!(batch_mode("recommended"), "standard");
        assert_eq!(batch_mode("ask"), "standard");
        assert_eq!(batch_mode("deep"), "deep");
    }
}
