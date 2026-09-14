//! Discipler daily post: each fellowship's *current lesson* from its own
//! `fellowship_study` row, generated in the fellowship's language through
//! study-generate-v2, posted as Discipler. See spec §4 (run order) and §5
//! (advance/switch rules).
//!
//! The job runs every minute and posts for every fellowship whose own IST
//! posting time has passed, that is due at its cadence, and that is not
//! skipped or paused. Mentor requests (post now, preview, new teaser, post
//! again — recorded by the `fellowship-study` Edge Function) are handled apart
//! from it by [run_request_worker], which checks every few seconds, so they
//! wait neither for this schedule nor for a long posting run.
//!
//! The advance/switch decision is resolved by
//! `fellowship_daily::resolve_post_plan` before any generation happens, and
//! only committed (alongside the post) in `fellowship_daily::insert_daily_post`
//! — so a failed generation never leaves the study cursor ahead of what was
//! actually posted.
use chrono::Utc;
use reqwest::Client;
use sqlx::PgPool;

use std::sync::Arc;
use tokio::sync::Semaphore;

use crate::config::Config;
use crate::error::AppError;
use crate::models::cron_config;
use crate::models::fellowship_daily::{
    self, DailyFellowship, DailyPostInsert, DailyRequest, Lesson, PostPlan, PreviewWrite,
};
use crate::services::fellowship_teaser::{self, Teaser, TeaserRequest};
use crate::services::{content_formatter, study_api};

/// Teaser regenerations a mentor may request per fellowship per day.
pub(crate) const REGENERATE_DAILY_CAP: i32 = 3;

/// How long a fellowship waits after a failed generation before the
/// every-minute job tries it again.
const RETRY_AFTER_FAILURE: chrono::Duration = chrono::Duration::hours(1);

/// Mentor requests generated at the same time; more wait for a free slot.
const MAX_CONCURRENT_REQUESTS: usize = 5;

/// How often the request worker looks for new mentor requests.
const REQUEST_POLL_INTERVAL: std::time::Duration = std::time::Duration::from_secs(5);

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
/// `posted`/`skipped`/`failed` separately. A skip carries the reason, worded
/// for the mentor, because a "Post now" request shows it to them.
enum Outcome {
    Posted,
    Skipped(&'static str),
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum RunMode {
    /// The every-minute schedule: posting time, cadence, skip and pause apply.
    Scheduled,
    /// A mentor's "Post now": publishes today's post regardless of schedule.
    PostNow,
}

/// Where the teaser for a post comes from.
enum TeaserSource {
    /// Already generated for this lesson and date (the mentor's preview).
    Reuse(Teaser),
    /// The shared per-topic teaser cache (generated on a miss).
    Cached,
    /// A new wording, bypassing the shared cache (mentor regenerate).
    Fresh,
}

struct BuiltPost {
    study_guide_id: Option<uuid::Uuid>,
    content: String,
    teaser: Option<Teaser>,
}

/// Generates the study guide and teaser for `lesson` and formats the post.
async fn build_post(
    config: &Config,
    http: &Client,
    f: &DailyFellowship,
    lesson: &Lesson,
    source: TeaserSource,
) -> Result<BuiltPost, AppError> {
    let l = localize(lesson, &f.language);

    let guide = study_api::generate_study_guide(
        http,
        config,
        &lesson.input_type,
        l.title,
        l.description,
        Some(l.path_title),
        Some(l.path_description),
        Some(&lesson.disciple_level),
        &f.language,
        batch_mode(&lesson.study_mode),
        Some(lesson.topic_id),
    )
    .await?;

    let fresh = matches!(source, TeaserSource::Fresh);
    let teaser = match source {
        TeaserSource::Reuse(t) => Some(t),
        TeaserSource::Cached | TeaserSource::Fresh => {
            let (_summary, verse) = content_formatter::extract_daily_fields(&guide);
            let grounding = content_formatter::teaser_grounding(&guide);
            fellowship_teaser::fetch_daily_teaser(
                config,
                http,
                TeaserRequest {
                    fellowship_id: f.id,
                    topic_id: lesson.topic_id,
                    topic_title: l.title,
                    path_title: l.path_title,
                    language: &f.language,
                    summary: &grounding,
                    verse: verse.as_deref(),
                    regenerate: fresh,
                },
            )
            .await
        }
    };

    let daily = content_formatter::format_daily_post(l.title, &guide, &f.language, teaser.as_ref());
    Ok(BuiltPost {
        study_guide_id: guide.study_guide_id,
        content: daily.content,
        teaser,
    })
}

async fn post_for_fellowship(
    pool: &PgPool,
    config: &Config,
    http: &Client,
    f: &DailyFellowship,
    mode: RunMode,
) -> Result<Outcome, AppError> {
    let now = Utc::now();
    let today = now.date_naive();

    let last = fellowship_daily::last_daily_post(pool, f.id).await?;
    let last_date = last.as_ref().map(|l| l.post_date);

    // Checked before generating anything: a second post the same day would
    // only be rejected at insert, after paying for the guide and teaser.
    if last_date == Some(today) {
        return Ok(Outcome::Skipped("Today's post has already gone out."));
    }

    if mode == RunMode::Scheduled {
        if fellowship_daily::is_paused(today, f.daily_post_paused_until) {
            return Ok(Outcome::Skipped("Daily posts are paused."));
        }
        // Spec §4 step 1: skip when the fellowship isn't due yet at its own
        // cadence. A skipped date counts as a posting day.
        let effective =
            fellowship_daily::effective_last_post(last_date, f.daily_post_skip_date, today);
        if !fellowship_daily::should_post_today(effective, today, f.daily_post_frequency_days) {
            return Ok(Outcome::Skipped("Not due today."));
        }
        if !fellowship_daily::slot_reached(fellowship_daily::ist_time(now), &f.daily_post_time) {
            return Ok(Outcome::Skipped("Before the posting time."));
        }
        if f.daily_post_last_failed_at
            .is_some_and(|t| now - t < RETRY_AFTER_FAILURE)
        {
            return Ok(Outcome::Skipped("Waiting to retry after a failure."));
        }
    }

    // Spec §4 step 2 + §5: resolved entirely in memory, nothing written yet.
    let Some(PostPlan { lesson, write }) =
        fellowship_daily::resolve_post_plan(pool, f.id, last.as_ref(), f.daily_post_auto_advance)
            .await?
    else {
        tracing::debug!(fellowship = %f.name, "No lesson to post today — skipping");
        return Ok(Outcome::Skipped(
            "There is no new lesson to post. Move to the next lesson first.",
        ));
    };

    // Use the mentor's preview teaser when it was made for this lesson today,
    // so the preview is not paid for a second time.
    let preview_teaser = fellowship_daily::load_preview(pool, f.id)
        .await?
        .filter(|p| p.post_date == today && p.learning_path_topic_id == lesson.id)
        .and_then(|p| {
            Some(Teaser {
                hook: p.teaser_hook?,
                body: p.teaser_body?,
            })
        });
    let source = match preview_teaser {
        Some(t) => TeaserSource::Reuse(t),
        None => TeaserSource::Cached,
    };

    let built = build_post(config, http, f, &lesson, source).await?;
    let l = localize(&lesson, &f.language);
    let outcome = fellowship_daily::insert_daily_post(
        pool,
        DailyPostInsert {
            fellowship_id: f.id,
            content: &built.content,
            topic_id: lesson.topic_id,
            topic_title: l.title,
            guide_title: l.title,
            study_guide_id: built.study_guide_id,
            language: &f.language,
            learning_path_topic_id: lesson.id,
            post_date: today,
            study_write: write,
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
            return Ok(Outcome::Skipped(
                "The lesson changed while the post was being prepared. Try again.",
            ));
        }
        fellowship_daily::InsertOutcome::AlreadyPosted => {
            // Raced another trigger of the same job for the same (fellowship, day)
            // — the whole transaction (advance/switch included) rolled back.
            tracing::info!(fellowship = %f.name, "Daily post already exists for today — skipping");
            return Ok(Outcome::Skipped("Today's post has already gone out."));
        }
    };

    tracing::info!(fellowship = %f.name, topic = %l.title, %post_id, "Daily post created");

    if let Err(e) = notify(config, http, post_id).await {
        tracing::error!(%post_id, "Daily post notify failed (post kept): {}", e);
    }
    Ok(Outcome::Posted)
}

/// Generates (or replaces) the preview of the next scheduled post.
async fn generate_preview(
    pool: &PgPool,
    config: &Config,
    http: &Client,
    f: &DailyFellowship,
) -> Result<(), AppError> {
    if !f.daily_post_preview_allowed {
        return Err(AppError::Forbidden(
            "Previews are not enabled for this fellowship.".into(),
        ));
    }
    let today = Utc::now().date_naive();
    let last = fellowship_daily::last_daily_post(pool, f.id).await?;
    let post_date = fellowship_daily::next_post_date(
        last.as_ref().map(|l| l.post_date),
        today,
        f.daily_post_frequency_days,
        f.daily_post_skip_date,
        f.daily_post_paused_until,
    );

    let Some(PostPlan { lesson, .. }) =
        fellowship_daily::resolve_post_plan(pool, f.id, last.as_ref(), f.daily_post_auto_advance)
            .await?
    else {
        return Err(AppError::BadRequest(
            "There is no new lesson to post. Move to the next lesson first.".into(),
        ));
    };

    let built = build_post(config, http, f, &lesson, TeaserSource::Cached).await?;
    store_preview(pool, f, &lesson, post_date, &built).await
}

/// Replaces the preview's teaser with a new wording, within the daily cap.
async fn regenerate_preview(
    pool: &PgPool,
    config: &Config,
    http: &Client,
    f: &DailyFellowship,
) -> Result<(), AppError> {
    if !f.daily_post_regenerate_allowed {
        return Err(AppError::Forbidden(
            "Regenerating the teaser is not enabled for this fellowship.".into(),
        ));
    }
    let today = Utc::now().date_naive();
    let Some(preview) = fellowship_daily::load_preview(pool, f.id).await? else {
        return Err(AppError::BadRequest("Preview the next post first.".into()));
    };
    if preview.post_date < today {
        return Err(AppError::BadRequest(
            "This preview is out of date. Preview the next post again.".into(),
        ));
    }
    let used = if preview.regenerate_date == Some(today) {
        preview.regenerate_count
    } else {
        0
    };
    if used >= REGENERATE_DAILY_CAP {
        return Err(AppError::BadRequest(
            "You have used today's teaser regenerations. Try again tomorrow.".into(),
        ));
    }

    let last = fellowship_daily::last_daily_post(pool, f.id).await?;
    let Some(PostPlan { lesson, .. }) =
        fellowship_daily::resolve_post_plan(pool, f.id, last.as_ref(), f.daily_post_auto_advance)
            .await?
    else {
        return Err(AppError::BadRequest(
            "There is no new lesson to post. Move to the next lesson first.".into(),
        ));
    };
    if lesson.id != preview.learning_path_topic_id {
        return Err(AppError::BadRequest(
            "The next lesson has changed. Preview the next post again.".into(),
        ));
    }

    let built = build_post(config, http, f, &lesson, TeaserSource::Fresh).await?;
    if built.teaser.is_none() {
        // Not counted against the cap: nothing new was produced.
        return Err(AppError::Internal(
            "teaser generation returned nothing".into(),
        ));
    }
    store_preview(pool, f, &lesson, preview.post_date, &built).await?;
    fellowship_daily::record_regenerate(pool, f.id, today, used + 1).await
}

async fn store_preview(
    pool: &PgPool,
    f: &DailyFellowship,
    lesson: &Lesson,
    post_date: chrono::NaiveDate,
    built: &BuiltPost,
) -> Result<(), AppError> {
    let l = localize(lesson, &f.language);
    fellowship_daily::upsert_preview(
        pool,
        &PreviewWrite {
            fellowship_id: f.id,
            post_date,
            learning_path_topic_id: lesson.id,
            topic_id: lesson.topic_id,
            topic_title: l.title,
            study_guide_id: built.study_guide_id,
            teaser_hook: built.teaser.as_ref().map(|t| t.hook.as_str()),
            teaser_body: built.teaser.as_ref().map(|t| t.body.as_str()),
            content: &built.content,
        },
    )
    .await
}

/// Replaces a daily post the mentor didn't like with a newly written version of
/// the same lesson, published now. The old post may already be gone — deleted
/// by a mentor, or removed outright — in which case the new one is simply posted.
async fn repost_daily_post(
    pool: &PgPool,
    config: &Config,
    http: &Client,
    f: &DailyFellowship,
    daily_post_id: Option<uuid::Uuid>,
) -> Result<(), AppError> {
    if !f.daily_post_post_now_allowed {
        return Err(AppError::Forbidden(
            "Posting again is not enabled for this fellowship.".into(),
        ));
    }
    let Some(daily_post_id) = daily_post_id else {
        return Err(AppError::BadRequest("Choose a post to post again.".into()));
    };
    let Some(row) = fellowship_daily::load_daily_post_row(pool, f.id, daily_post_id).await? else {
        return Err(AppError::NotFound(
            "That post is no longer available.".into(),
        ));
    };
    let Some(lesson) = fellowship_daily::lesson_by_id(pool, row.learning_path_topic_id).await?
    else {
        return Err(AppError::NotFound(
            "That lesson is no longer available.".into(),
        ));
    };

    // A fresh wording, not the cached one the mentor didn't like.
    let built = build_post(config, http, f, &lesson, TeaserSource::Fresh).await?;
    let l = localize(&lesson, &f.language);
    let post_id = fellowship_daily::replace_daily_post(
        pool,
        fellowship_daily::RepostInsert {
            fellowship_id: f.id,
            daily_post_id: row.id,
            old_post_id: row.post_id,
            content: &built.content,
            topic_id: lesson.topic_id,
            topic_title: l.title,
            study_guide_id: built.study_guide_id,
            language: &f.language,
        },
    )
    .await?;

    tracing::info!(fellowship = %f.name, topic = %l.title, %post_id, "Daily post posted again");
    if let Err(e) = notify(config, http, post_id).await {
        tracing::error!(%post_id, "Repost notify failed (post kept): {}", e);
    }
    Ok(())
}

/// The message a mentor sees for a failed request. Only messages written for
/// them are shown; anything internal becomes a generic line.
fn request_error_message(e: &AppError) -> String {
    match e {
        AppError::BadRequest(m) | AppError::Forbidden(m) | AppError::NotFound(m) => m.clone(),
        _ => "Something went wrong. Please try again later.".into(),
    }
}

async fn process_request(
    pool: &PgPool,
    config: &Config,
    http: &Client,
    r: &DailyRequest,
) -> Result<(), AppError> {
    let Some(f) = fellowship_daily::load_daily_fellowship(pool, r.fellowship_id).await? else {
        return Err(AppError::Forbidden(
            "Daily posts are not enabled for this fellowship.".into(),
        ));
    };
    match r.kind.as_str() {
        "post_now" => {
            if !f.daily_post_post_now_allowed {
                return Err(AppError::Forbidden(
                    "Posting now is not enabled for this fellowship.".into(),
                ));
            }
            match post_for_fellowship(pool, config, http, &f, RunMode::PostNow).await? {
                Outcome::Posted => Ok(()),
                Outcome::Skipped(reason) => Err(AppError::BadRequest(reason.into())),
            }
        }
        "preview" => generate_preview(pool, config, http, &f).await,
        "regenerate" => regenerate_preview(pool, config, http, &f).await,
        "repost" => repost_daily_post(pool, config, http, &f, r.target_daily_post_id).await,
        other => Err(AppError::BadRequest(format!("Unknown request: {other}"))),
    }
}

/// Runs one claimed request and records how it went.
async fn handle_request(pool: &PgPool, config: &Config, http: &Client, r: &DailyRequest) {
    let result = process_request(pool, config, http, r).await;
    if let Err(e) = &result {
        tracing::warn!(request = %r.id, kind = %r.kind, "Daily post request failed: {}", e);
    }
    let error = result.err().map(|e| request_error_message(&e));
    if let Err(e) = fellowship_daily::finish_request(pool, r.id, error.as_deref()).await {
        tracing::error!(request = %r.id, "Could not record request result: {}", e);
    }
}

/// Picks up mentor requests within seconds of a tap, independent of the
/// `fellowship_daily_post` schedule (its enabled switch still applies). Each
/// request runs on its own task, up to [MAX_CONCURRENT_REQUESTS] at once, so a
/// slow generation never holds up the next request.
pub async fn run_request_worker(pool: PgPool, config: Config, http: Client) {
    let slots = Arc::new(Semaphore::new(MAX_CONCURRENT_REQUESTS));
    let mut tick = tokio::time::interval(REQUEST_POLL_INTERVAL);
    tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
    tracing::info!("Daily post request worker started");

    loop {
        tick.tick().await;
        let free = slots.available_permits();
        if free == 0 || !cron_config::should_run(&pool, "fellowship_daily_post").await {
            continue;
        }
        let requests = match fellowship_daily::claim_pending_requests(&pool, free as i64).await {
            Ok(requests) => requests,
            Err(e) => {
                tracing::error!("Could not claim daily post requests: {}", e);
                continue;
            }
        };
        for r in requests {
            // Never waits: no more were claimed than there were free slots,
            // and only this loop takes them.
            let Ok(slot) = slots.clone().acquire_owned().await else {
                return;
            };
            let (pool, config, http) = (pool.clone(), config.clone(), http.clone());
            tokio::spawn(async move {
                let _slot = slot;
                handle_request(&pool, &config, &http, &r).await;
            });
        }
    }
}

pub async fn run_fellowship_daily_post(
    pool: &PgPool,
    config: &Config,
    http: &Client,
) -> Result<(), AppError> {
    let fellowships = fellowship_daily::list_daily_fellowships(pool).await?;
    let (mut posted, mut skipped, mut failed) = (0usize, 0usize, 0usize);
    for f in &fellowships {
        match post_for_fellowship(pool, config, http, f, RunMode::Scheduled).await {
            Ok(Outcome::Posted) => posted += 1,
            Ok(Outcome::Skipped(_)) => skipped += 1,
            Err(e) => {
                failed += 1;
                tracing::error!(fellowship = %f.name, "Daily post failed: {}", e);
                if let Err(e) = fellowship_daily::mark_post_failed(pool, f.id).await {
                    tracing::error!(fellowship = %f.name, "Could not record failure: {}", e);
                }
            }
        }
    }
    // Runs every minute: only report runs that did something.
    if posted > 0 || failed > 0 {
        tracing::info!(posted, skipped, failed, "Discipler daily post run finished");
    }
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

    #[test]
    fn request_errors_only_show_messages_written_for_mentors() {
        assert_eq!(
            request_error_message(&AppError::BadRequest("Preview the next post first.".into())),
            "Preview the next post first."
        );
        assert_eq!(
            request_error_message(&AppError::Internal("db exploded at 10.0.0.3".into())),
            "Something went wrong. Please try again later."
        );
    }
}
