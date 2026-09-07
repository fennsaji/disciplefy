//! Discipler daily post: each fellowship's *current lesson* from its own
//! `fellowship_study` row, generated in the fellowship's language through
//! study-generate-v2, posted as Discipler. See spec §4 (run order) and §5
//! (advance/switch rules).
//!
//! The advance/switch decision is resolved by
//! `fellowship_daily::resolve_post_plan` before any generation happens, and
//! only committed (alongside the post) in `fellowship_daily::insert_daily_post`
//! — so a failed generation never leaves the study cursor ahead of what was
//! actually posted.
use chrono::Utc;
use reqwest::Client;
use sqlx::PgPool;

use crate::config::Config;
use crate::error::AppError;
use crate::models::fellowship_daily::{self, DailyFellowship, DailyPostInsert, Lesson};
use crate::services::fellowship_teaser::{self, TeaserRequest};
use crate::services::{content_formatter, study_api};

pub(crate) struct Localized<'a> {
    pub title: &'a str,
    pub description: Option<&'a str>,
    pub path_title: &'a str,
    pub path_description: &'a str,
}

/// Pick localized fields with English fallback, exactly like blog generation.
pub(crate) fn localize<'a>(lesson: &'a Lesson, locale: &str) -> Localized<'a> {
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
            title: pick(&lesson.hi_title, &lesson.title),
            description: pick_opt(&lesson.hi_description, &lesson.description),
            path_title: pick(&lesson.hi_path_title, &lesson.path_title),
            path_description: pick(&lesson.hi_path_description, &lesson.path_description),
        },
        "ml" => Localized {
            title: pick(&lesson.ml_title, &lesson.title),
            description: pick_opt(&lesson.ml_description, &lesson.description),
            path_title: pick(&lesson.ml_path_title, &lesson.path_title),
            path_description: pick(&lesson.ml_path_description, &lesson.path_description),
        },
        _ => Localized {
            title: &lesson.title,
            description: lesson.description.as_deref(),
            path_title: &lesson.path_title,
            path_description: &lesson.path_description,
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

/// Outcome of a single fellowship's run, so the finish line can report
/// `posted`/`skipped`/`failed` separately instead of lumping every non-error
/// outcome into a meaningless "ok" count.
enum Outcome {
    Posted,
    Skipped,
}

async fn post_for_fellowship(
    pool: &PgPool,
    config: &Config,
    http: &Client,
    f: &DailyFellowship,
) -> Result<Outcome, AppError> {
    let today = Utc::now().date_naive();

    // Spec §4 step 1: skip when the fellowship isn't due yet at its own cadence.
    let last = fellowship_daily::last_daily_post(pool, f.id).await?;
    let last_date = last.as_ref().map(|l| l.post_date);
    if !fellowship_daily::should_post_today(last_date, today, f.daily_post_frequency_days) {
        return Ok(Outcome::Skipped);
    }

    // Spec §4 step 2 + §5: resolved entirely in memory, nothing written yet.
    let Some(plan) =
        fellowship_daily::resolve_post_plan(pool, f.id, last.as_ref(), f.daily_post_auto_advance)
            .await?
    else {
        tracing::info!(fellowship = %f.name, "No lesson to post today — skipping");
        return Ok(Outcome::Skipped);
    };

    let l = localize(&plan.lesson, &f.language);

    let guide = study_api::generate_study_guide(
        http,
        config,
        &plan.lesson.input_type,
        l.title,
        l.description,
        Some(l.path_title),
        Some(l.path_description),
        Some(&plan.lesson.disciple_level),
        &f.language,
        batch_mode(&plan.lesson.study_mode),
    )
    .await?;

    let (summary, question, verse) = content_formatter::extract_daily_fields(&guide);
    let teaser = fellowship_teaser::fetch_daily_teaser(
        config,
        http,
        TeaserRequest {
            fellowship_id: f.id,
            topic_title: l.title,
            path_title: l.path_title,
            language: &f.language,
            summary: &summary,
            verse: verse.as_deref(),
            question: question.as_deref(),
        },
    )
    .await;

    let daily = content_formatter::format_daily_post(l.title, &guide, &f.language, teaser.as_ref());
    let outcome = fellowship_daily::insert_daily_post(
        pool,
        DailyPostInsert {
            fellowship_id: f.id,
            content: &daily.content,
            topic_id: plan.lesson.topic_id,
            topic_title: l.title,
            guide_title: l.title,
            study_guide_id: guide.study_guide_id,
            language: &f.language,
            learning_path_topic_id: plan.lesson.id,
            post_date: today,
            study_write: plan.write,
        },
    )
    .await?;

    let post_id = match outcome {
        fellowship_daily::InsertOutcome::Posted(id) => id,
        fellowship_daily::InsertOutcome::StaleStudy => {
            // A mentor `/advance`, `/set`, or `/reset` landed while generation
            // was in flight — the guarded UPDATE matched zero rows and the
            // whole transaction rolled back. Nothing was persisted; the next
            // eligible run recomputes the plan from the fresh state.
            tracing::warn!(fellowship = %f.name, "study changed during generation, skipping");
            return Ok(Outcome::Skipped);
        }
        fellowship_daily::InsertOutcome::AlreadyPosted => {
            // Raced another trigger of the same job for the same (fellowship, day)
            // — the whole transaction (advance/switch included) rolled back.
            tracing::info!(fellowship = %f.name, "Daily post already exists for today — skipping");
            return Ok(Outcome::Skipped);
        }
    };

    tracing::info!(fellowship = %f.name, topic = %l.title, %post_id, from_cache = guide.from_cache, "Daily post created");

    if let Err(e) = notify(config, http, post_id).await {
        tracing::error!(%post_id, "Daily post notify failed (post kept): {}", e);
    }
    Ok(Outcome::Posted)
}

pub async fn run_fellowship_daily_post(
    pool: &PgPool,
    config: &Config,
    http: &Client,
) -> Result<(), AppError> {
    tracing::info!("Starting Discipler daily post CRON job");
    let fellowships = fellowship_daily::list_daily_fellowships(pool).await?;
    if fellowships.is_empty() {
        tracing::info!("No fellowships due for a daily post");
        return Ok(());
    }
    let (mut posted, mut skipped, mut failed) = (0usize, 0usize, 0usize);
    for f in &fellowships {
        match post_for_fellowship(pool, config, http, f).await {
            Ok(Outcome::Posted) => posted += 1,
            Ok(Outcome::Skipped) => skipped += 1,
            Err(e) => {
                failed += 1;
                tracing::error!(fellowship = %f.name, "Daily post failed: {}", e);
            }
        }
    }
    tracing::info!(
        posted,
        skipped,
        failed,
        "Discipler daily post CRON job finished"
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn lesson() -> Lesson {
        Lesson {
            id: uuid::Uuid::nil(),
            topic_id: uuid::Uuid::nil(),
            title: "Faith".into(),
            description: Some("d".into()),
            input_type: "topic".into(),
            position: 0,
            path_title: "Path".into(),
            path_description: "pd".into(),
            disciple_level: "new".into(),
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
        let t = lesson();
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
