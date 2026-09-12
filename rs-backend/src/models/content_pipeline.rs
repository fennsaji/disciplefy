//! Admin view and control of the two global content jobs that walk the
//! learning-path catalogue: `telegram_daily_post` (one lesson a day to the
//! channel, in en/hi/ml) and `prewarm` (Batch API guides for every lesson).
//! See migrations 20260912185053_content_pipeline_progress.sql and
//! 20260912200604_content_pipeline_dashboard.sql.

use std::collections::HashSet;

use chrono::{DateTime, NaiveDate, Utc};
use serde::Serialize;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::AppError;

pub const LANGUAGES: [&str; 3] = ["en", "hi", "ml"];

pub fn is_known_job(name: &str) -> bool {
    matches!(name, "telegram_daily_post" | "prewarm")
}

// ---------------------------------------------------------------------------
// Rows
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct LessonRow {
    pub learning_path_id: Uuid,
    pub path_title: String,
    pub path_order: i32,
    pub learning_path_topic_id: Uuid,
    pub topic_id: Uuid,
    pub topic_title: String,
    pub topic_position: i32,
    pub telegram_sent_en: bool,
    pub telegram_sent_hi: bool,
    pub telegram_sent_ml: bool,
    pub blog_en: bool,
    pub blog_hi: bool,
    pub blog_ml: bool,
    pub guide_en: bool,
    pub guide_hi: bool,
    pub guide_ml: bool,
}

impl LessonRow {
    fn done_in(&self, job: &str, language: &str) -> bool {
        match (job, language) {
            ("telegram_daily_post", "en") => self.telegram_sent_en,
            ("telegram_daily_post", "hi") => self.telegram_sent_hi,
            ("telegram_daily_post", "ml") => self.telegram_sent_ml,
            ("prewarm", "en") => self.guide_en,
            ("prewarm", "hi") => self.guide_hi,
            ("prewarm", "ml") => self.guide_ml,
            _ => false,
        }
    }

    fn blog_in(&self, language: &str) -> bool {
        match language {
            "en" => self.blog_en,
            "hi" => self.blog_hi,
            "ml" => self.blog_ml,
            _ => false,
        }
    }
}

// ---------------------------------------------------------------------------
// Response shape
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct LanguageStatus {
    pub language: &'static str,
    pub done: bool,
    /// Telegram only: whether a published article exists in this language.
    /// The channel cannot post a lesson without one.
    pub blog_published: Option<bool>,
}

#[derive(Debug, Clone, Serialize)]
pub struct Lesson {
    pub learning_path_topic_id: Uuid,
    pub topic_id: Uuid,
    pub title: String,
    pub position: i32,
    pub languages: Vec<LanguageStatus>,
    pub done: bool,
    /// Sorts before the admin's chosen start point, so the job will not reach it.
    pub before_start: bool,
    pub is_next: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct PathProgress {
    pub id: Uuid,
    pub title: String,
    pub display_order: i32,
    pub total: usize,
    pub done: usize,
    /// done | current | partial | pending | skipped
    pub status: &'static str,
    pub lessons: Vec<Lesson>,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct LanguageCount {
    pub language: &'static str,
    pub done: usize,
    pub total: usize,
}

#[derive(Debug, Clone, Serialize)]
pub struct NextLesson {
    pub learning_path_id: Uuid,
    pub path_title: String,
    pub learning_path_topic_id: Uuid,
    pub topic_title: String,
    /// Telegram: languages that cannot post this lesson because no published
    /// article exists yet. The channel waits on this lesson until they do.
    pub blocked_languages: Vec<&'static str>,
}

#[derive(Debug, Clone, Serialize)]
pub struct StartPoint {
    pub learning_path_id: Option<Uuid>,
    pub learning_path_title: Option<String>,
    pub learning_path_topic_id: Option<Uuid>,
    pub topic_title: Option<String>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct TelegramHistoryRow {
    pub post_date: NaiveDate,
    pub language: String,
    pub status: String,
    pub error: Option<String>,
    pub topic_title: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct PrewarmRunRow {
    pub phase: String,
    pub status: String,
    pub request_count: i32,
    pub guides_written: i32,
    pub note: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize)]
pub struct PrewarmBudget {
    pub monthly_budget_usd: f64,
    pub spent_this_month_usd: f64,
}

#[derive(Debug, Clone, Serialize)]
pub struct Overview {
    pub job_name: String,
    pub start: Option<StartPoint>,
    pub total_topics: usize,
    pub done_topics: usize,
    pub by_language: Vec<LanguageCount>,
    pub next: Option<NextLesson>,
    pub paths: Vec<PathProgress>,
    pub telegram_history: Option<Vec<TelegramHistoryRow>>,
    pub prewarm_runs: Option<Vec<PrewarmRunRow>>,
    pub prewarm_budget: Option<PrewarmBudget>,
}

pub struct Progress {
    pub total_topics: usize,
    pub done_topics: usize,
    pub by_language: Vec<LanguageCount>,
    pub next: Option<NextLesson>,
    pub paths: Vec<PathProgress>,
}

// ---------------------------------------------------------------------------
// Pure aggregation (unit tested)
// ---------------------------------------------------------------------------

/// `rows` must be in catalogue order (path order, then position). `start` is
/// the (path order, topic position) key the pickers skip everything before.
pub fn build_progress(job: &str, rows: &[LessonRow], start: Option<(i32, i32)>) -> Progress {
    let is_telegram = job == "telegram_daily_post";

    let mut seen_topics = HashSet::new();
    let mut done_topics = HashSet::new();
    let mut lang_done = [0usize; 3];

    for r in rows {
        if seen_topics.insert(r.topic_id) {
            let mut all = true;
            for (i, l) in LANGUAGES.iter().enumerate() {
                if r.done_in(job, l) {
                    lang_done[i] += 1;
                } else {
                    all = false;
                }
            }
            if all {
                done_topics.insert(r.topic_id);
            }
        }
    }

    let mut next: Option<NextLesson> = None;
    let mut paths: Vec<PathProgress> = Vec::new();

    for r in rows {
        let languages: Vec<LanguageStatus> = LANGUAGES
            .iter()
            .map(|l| LanguageStatus {
                language: l,
                done: r.done_in(job, l),
                blog_published: is_telegram.then(|| r.blog_in(l)),
            })
            .collect();
        let done = languages.iter().all(|s| s.done);
        let before_start = start
            .map(|(o, p)| (r.path_order, r.topic_position) < (o, p))
            .unwrap_or(false);
        let is_next = next.is_none() && !done && !before_start;

        if is_next {
            next = Some(NextLesson {
                learning_path_id: r.learning_path_id,
                path_title: r.path_title.clone(),
                learning_path_topic_id: r.learning_path_topic_id,
                topic_title: r.topic_title.clone(),
                blocked_languages: if is_telegram {
                    languages
                        .iter()
                        .filter(|s| !s.done && s.blog_published == Some(false))
                        .map(|s| s.language)
                        .collect()
                } else {
                    Vec::new()
                },
            });
        }

        let lesson = Lesson {
            learning_path_topic_id: r.learning_path_topic_id,
            topic_id: r.topic_id,
            title: r.topic_title.clone(),
            position: r.topic_position,
            languages,
            done,
            before_start,
            is_next,
        };

        match paths.last_mut() {
            Some(p) if p.id == r.learning_path_id => p.lessons.push(lesson),
            _ => paths.push(PathProgress {
                id: r.learning_path_id,
                title: r.path_title.clone(),
                display_order: r.path_order,
                total: 0,
                done: 0,
                status: "pending",
                lessons: vec![lesson],
            }),
        }
    }

    for p in &mut paths {
        p.total = p.lessons.len();
        p.done = p.lessons.iter().filter(|l| l.done).count();
        p.status = if p.total > 0 && p.done == p.total {
            "done"
        } else if p.lessons.iter().any(|l| l.is_next) {
            "current"
        } else if p.lessons.iter().all(|l| l.before_start || l.done) {
            "skipped"
        } else if p.done > 0 {
            "partial"
        } else {
            "pending"
        };
    }

    Progress {
        total_topics: seen_topics.len(),
        done_topics: done_topics.len(),
        by_language: LANGUAGES
            .iter()
            .enumerate()
            .map(|(i, l)| LanguageCount {
                language: l,
                done: lang_done[i],
                total: seen_topics.len(),
            })
            .collect(),
        next,
        paths,
    }
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

#[derive(sqlx::FromRow)]
struct StartRow {
    start_learning_path_id: Option<Uuid>,
    learning_path_title: Option<String>,
    start_learning_path_topic_id: Option<Uuid>,
    topic_title: Option<String>,
    updated_at: DateTime<Utc>,
}

#[derive(sqlx::FromRow)]
struct StartKey {
    path_order: i32,
    topic_position: i32,
}

fn not_found(job_name: &str) -> AppError {
    AppError::NotFound(format!("Content pipeline job '{job_name}' not found"))
}

pub async fn overview(pool: &PgPool, job_name: &str) -> Result<Overview, AppError> {
    if !is_known_job(job_name) {
        return Err(not_found(job_name));
    }

    let start_row = sqlx::query_as::<_, StartRow>(
        "SELECT cpp.start_learning_path_id, lp.title AS learning_path_title,
                cpp.start_learning_path_topic_id, rt.title AS topic_title, cpp.updated_at
           FROM content_pipeline_progress cpp
           LEFT JOIN learning_paths lp ON lp.id = cpp.start_learning_path_id
           LEFT JOIN learning_path_topics lpt ON lpt.id = cpp.start_learning_path_topic_id
           LEFT JOIN recommended_topics rt ON rt.id = lpt.topic_id
          WHERE cpp.job_name = $1",
    )
    .bind(job_name)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| not_found(job_name))?;

    let start_key = sqlx::query_as::<_, StartKey>(
        "SELECT path_order, topic_position FROM content_pipeline_start($1)",
    )
    .bind(job_name)
    .fetch_optional(pool)
    .await?
    .map(|k| (k.path_order, k.topic_position));

    let rows = sqlx::query_as::<_, LessonRow>("SELECT * FROM content_pipeline_lessons()")
        .fetch_all(pool)
        .await?;

    let progress = build_progress(job_name, &rows, start_key);

    let start = (start_row.start_learning_path_id.is_some()
        || start_row.start_learning_path_topic_id.is_some())
    .then_some(StartPoint {
        learning_path_id: start_row.start_learning_path_id,
        learning_path_title: start_row.learning_path_title,
        learning_path_topic_id: start_row.start_learning_path_topic_id,
        topic_title: start_row.topic_title,
        updated_at: start_row.updated_at,
    });

    let (telegram_history, prewarm_runs, prewarm_budget) = if job_name == "telegram_daily_post" {
        let history = sqlx::query_as::<_, TelegramHistoryRow>(
            "SELECT t.post_date, t.language, t.status, t.error,
                    COALESCE(rt.title, '') AS topic_title, t.created_at
               FROM telegram_daily_posts t
               LEFT JOIN recommended_topics rt ON rt.id = t.topic_id
              ORDER BY t.post_date DESC, t.created_at DESC, t.language
              LIMIT 30",
        )
        .fetch_all(pool)
        .await?;
        (Some(history), None, None)
    } else {
        let runs = sqlx::query_as::<_, PrewarmRunRow>(
            "SELECT phase, status, request_count, guides_written, note, created_at, updated_at
               FROM prewarm_runs
              ORDER BY created_at DESC
              LIMIT 10",
        )
        .fetch_all(pool)
        .await?;
        let configured: Option<String> = sqlx::query_scalar(
            "SELECT value::text FROM system_config
              WHERE key = 'prewarm_monthly_budget_usd' AND is_active",
        )
        .fetch_optional(pool)
        .await?;
        let spent: f64 =
            sqlx::query_scalar("SELECT COALESCE(prewarm_spend_this_month(), 0)::float8")
                .fetch_one(pool)
                .await?;
        let budget = PrewarmBudget {
            // Mirrors the prewarm function's own fallback.
            monthly_budget_usd: configured
                .as_deref()
                .and_then(|v| v.trim().trim_matches('"').parse::<f64>().ok())
                .filter(|v| v.is_finite() && *v >= 0.0)
                .unwrap_or(20.0),
            spent_this_month_usd: spent,
        };
        (None, Some(runs), Some(budget))
    };

    Ok(Overview {
        job_name: job_name.to_string(),
        start,
        total_topics: progress.total_topics,
        done_topics: progress.done_topics,
        by_language: progress.by_language,
        next: progress.next,
        paths: progress.paths,
        telegram_history,
        prewarm_runs,
        prewarm_budget,
    })
}

/// Moves where the job resumes. A lesson (`learning_path_topic_id`) wins over
/// a path; both `None` clears the override so the job walks the catalogue from
/// the top again. Sent/generated history is never touched — finished lessons
/// stay finished.
pub async fn set_start(
    pool: &PgPool,
    job_name: &str,
    learning_path_id: Option<Uuid>,
    learning_path_topic_id: Option<Uuid>,
) -> Result<(), AppError> {
    if !is_known_job(job_name) {
        return Err(not_found(job_name));
    }

    let (path_id, topic_id) = match (learning_path_topic_id, learning_path_id) {
        (Some(lpt_id), _) => {
            let path: Option<Uuid> = sqlx::query_scalar(
                "SELECT lpt.learning_path_id
                   FROM learning_path_topics lpt
                   JOIN learning_paths lp ON lp.id = lpt.learning_path_id
                  WHERE lpt.id = $1 AND lpt.is_active AND lp.is_active",
            )
            .bind(lpt_id)
            .fetch_optional(pool)
            .await?;
            let path = path.ok_or_else(|| {
                AppError::BadRequest(
                    "learning_path_topic_id does not exist or is not active".into(),
                )
            })?;
            (Some(path), Some(lpt_id))
        }
        (None, Some(path)) => {
            let exists: bool = sqlx::query_scalar(
                "SELECT EXISTS(SELECT 1 FROM learning_paths WHERE id = $1 AND is_active)",
            )
            .bind(path)
            .fetch_one(pool)
            .await?;
            if !exists {
                return Err(AppError::BadRequest(
                    "learning_path_id does not exist or is not active".into(),
                ));
            }
            (Some(path), None)
        }
        (None, None) => (None, None),
    };

    sqlx::query(
        "UPDATE content_pipeline_progress
            SET start_learning_path_id = $2, start_learning_path_topic_id = $3
          WHERE job_name = $1",
    )
    .bind(job_name)
    .bind(path_id)
    .bind(topic_id)
    .execute(pool)
    .await?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn row(path: u128, order: i32, lpt: u128, topic: u128, pos: i32) -> LessonRow {
        LessonRow {
            learning_path_id: Uuid::from_u128(path),
            path_title: format!("Path {order}"),
            path_order: order,
            learning_path_topic_id: Uuid::from_u128(lpt),
            topic_id: Uuid::from_u128(topic),
            topic_title: format!("Topic {topic}"),
            topic_position: pos,
            telegram_sent_en: false,
            telegram_sent_hi: false,
            telegram_sent_ml: false,
            blog_en: true,
            blog_hi: true,
            blog_ml: true,
            guide_en: false,
            guide_hi: false,
            guide_ml: false,
        }
    }

    fn sent_all(mut r: LessonRow) -> LessonRow {
        r.telegram_sent_en = true;
        r.telegram_sent_hi = true;
        r.telegram_sent_ml = true;
        r
    }

    #[test]
    fn only_the_two_pipeline_jobs_are_known() {
        assert!(is_known_job("telegram_daily_post"));
        assert!(is_known_job("prewarm"));
        assert!(!is_known_job("blog_generation"));
    }

    #[test]
    fn next_is_first_unfinished_lesson_and_paths_get_status() {
        let rows = vec![
            sent_all(row(1, 1, 10, 100, 1)),
            row(1, 1, 11, 101, 2),
            row(2, 2, 20, 200, 1),
        ];
        let p = build_progress("telegram_daily_post", &rows, None);
        let next = p.next.expect("a next lesson");
        assert_eq!(next.learning_path_topic_id, Uuid::from_u128(11));
        assert_eq!(p.done_topics, 1);
        assert_eq!(p.total_topics, 3);
        assert_eq!(p.paths[0].status, "current");
        assert_eq!(p.paths[0].done, 1);
        assert_eq!(p.paths[1].status, "pending");
    }

    #[test]
    fn start_point_skips_earlier_lessons() {
        let rows = vec![
            row(1, 1, 10, 100, 1),
            row(2, 2, 20, 200, 1),
            row(2, 2, 21, 201, 2),
        ];
        let p = build_progress("telegram_daily_post", &rows, Some((2, 2)));
        assert_eq!(p.next.unwrap().learning_path_topic_id, Uuid::from_u128(21));
        assert_eq!(p.paths[0].status, "skipped");
        assert!(p.paths[1].lessons[0].before_start);
        assert_eq!(p.paths[1].status, "current");
    }

    #[test]
    fn telegram_reports_languages_missing_an_article() {
        let mut r = row(1, 1, 10, 100, 1);
        r.telegram_sent_en = true;
        r.blog_hi = false;
        let p = build_progress("telegram_daily_post", &[r], None);
        assert_eq!(p.next.unwrap().blocked_languages, vec!["hi"]);
    }

    #[test]
    fn prewarm_uses_guides_and_never_reports_blocked_languages() {
        let mut done = row(1, 1, 10, 100, 1);
        done.guide_en = true;
        done.guide_hi = true;
        done.guide_ml = true;
        let mut half = row(1, 1, 11, 101, 2);
        half.guide_en = true;
        half.blog_en = false;
        let p = build_progress("prewarm", &[done, half], None);
        assert_eq!(p.done_topics, 1);
        assert_eq!(
            p.by_language[0],
            LanguageCount {
                language: "en",
                done: 2,
                total: 2
            }
        );
        let next = p.next.unwrap();
        assert!(next.blocked_languages.is_empty());
        assert_eq!(p.paths[0].lessons[1].languages[0].blog_published, None);
    }

    #[test]
    fn a_topic_shared_by_two_paths_counts_once() {
        let rows = vec![
            sent_all(row(1, 1, 10, 100, 1)),
            sent_all(row(2, 2, 20, 100, 1)),
        ];
        let p = build_progress("telegram_daily_post", &rows, None);
        assert_eq!(p.total_topics, 1);
        assert_eq!(p.done_topics, 1);
        assert!(p.next.is_none());
        assert_eq!(p.paths[1].status, "done");
    }
}
