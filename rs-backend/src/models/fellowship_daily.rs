//! Queries for the Discipler daily post cron. Each fellowship posts the current
//! lesson of its own `fellowship_study` row — no global topic cursor.
//!
//! The advance/switch decision is resolved entirely in memory
//! (`resolve_post_plan`) *before* any study-guide generation happens; the
//! resulting plan is only persisted together with the post itself, in the one
//! transaction `insert_daily_post` opens. That way a failed generation (LLM
//! timeout, rate limit, ...) never leaves `fellowship_study` pointing at a
//! lesson nothing was ever posted for (spec §6: "Now" == the lesson Discipler
//! most recently posted).
//!
//! Generation can take tens of seconds, during which a mentor could `/advance`,
//! `/set`, or `/reset` the same fellowship. The `fellowship_study` UPDATE
//! inside `insert_daily_post`'s transaction is therefore guarded by the exact
//! state the plan was computed from (`StudyGuard`); if the row moved in the
//! meantime the guard matches zero rows, the whole transaction (post, cursor,
//! activity — everything) is rolled back and the run is counted as skipped,
//! not posted. The next eligible run recomputes the plan from scratch.
use chrono::{DateTime, NaiveDate, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::AppError;

pub const DISCIPLER_USER_ID: &str = "00000000-0000-4000-8000-00000000d15c";

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct DailyFellowship {
    pub id: Uuid,
    pub name: String,
    pub language: String,
    pub daily_post_frequency_days: i32,
    pub daily_post_auto_advance: bool,
}

/// Fellowships allowed a daily post today (admin allowed + mentor on + active).
/// Frequency and already-posted checks happen per-fellowship (spec §4).
pub async fn list_daily_fellowships(pool: &PgPool) -> Result<Vec<DailyFellowship>, AppError> {
    let rows = sqlx::query_as::<_, DailyFellowship>(
        "SELECT f.id, f.name, f.language, f.daily_post_frequency_days, f.daily_post_auto_advance
         FROM fellowships f
         WHERE f.is_active = true AND f.daily_post_allowed = true AND f.daily_post_on = true
         ORDER BY f.created_at",
    )
    .fetch_all(pool)
    .await?;
    Ok(rows)
}

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct FellowshipStudy {
    pub id: Uuid,
    pub fellowship_id: Uuid,
    pub learning_path_id: Uuid,
    pub current_guide_index: i32,
    pub started_at: DateTime<Utc>,
    pub completed_at: Option<DateTime<Utc>>,
    pub completed_path_ids: Vec<Uuid>,
}

const STUDY_COLUMNS: &str = "id, fellowship_id, learning_path_id, current_guide_index, started_at, completed_at, completed_path_ids";

/// The fellowship's `fellowship_study` row, whatever state it's in (there is at
/// most one per fellowship — `UNIQUE (fellowship_id)`). `None` only when the
/// fellowship has never been assigned a study at all.
pub async fn load_study(
    pool: &PgPool,
    fellowship_id: Uuid,
) -> Result<Option<FellowshipStudy>, AppError> {
    let study = sqlx::query_as::<_, FellowshipStudy>(&format!(
        "SELECT {STUDY_COLUMNS} FROM fellowship_study WHERE fellowship_id = $1"
    ))
    .bind(fellowship_id)
    .fetch_optional(pool)
    .await?;
    Ok(study)
}

/// Guarantees a `fellowship_study` row exists, inserting the default learning
/// path (`default_learning_path_id()`) when the fellowship has none at all.
/// This is the only immediate (non-deferred) write in this module: it never
/// discards a pending post, because a brand-new row has no "current lesson"
/// a post could already be in flight for.
pub async fn ensure_study(pool: &PgPool, fellowship_id: Uuid) -> Result<FellowshipStudy, AppError> {
    if let Some(study) = load_study(pool, fellowship_id).await? {
        return Ok(study);
    }
    let study = sqlx::query_as::<_, FellowshipStudy>(&format!(
        "INSERT INTO fellowship_study (fellowship_id, learning_path_id, current_guide_index, started_at)
         VALUES ($1, public.default_learning_path_id(), 0, now())
         RETURNING {STUDY_COLUMNS}"
    ))
    .bind(fellowship_id)
    .fetch_one(pool)
    .await?;
    Ok(study)
}

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct Lesson {
    /// learning_path_topics.id
    pub id: Uuid,
    /// recommended_topics.id — used as source_topic_id downstream
    pub topic_id: Uuid,
    pub title: String,
    pub description: Option<String>,
    pub input_type: String,
    pub position: i32,
    pub path_title: String,
    pub path_description: String,
    pub disciple_level: String,
    // Localized fields from recommended_topics_translations
    pub hi_title: Option<String>,
    pub ml_title: Option<String>,
    pub hi_description: Option<String>,
    pub ml_description: Option<String>,
    // Localized fields from learning_path_translations
    pub hi_path_title: Option<String>,
    pub ml_path_title: Option<String>,
    pub hi_path_description: Option<String>,
    pub ml_path_description: Option<String>,
    pub study_mode: String,
}

/// A topic is visible in a path when BOTH `lpt.is_active` (this path wants it)
/// AND `rt.is_active` (the topic itself is live) — see migration
/// `20260721000005_renumber_positions_and_remap_fellowships.sql`. `rt.is_active`
/// is nullable, so the test is `IS TRUE`, never a bare `rt.is_active`.
const VISIBLE_WHERE: &str =
    "lpt.learning_path_id = $1 AND lpt.is_active = true AND rt.is_active IS TRUE";

/// The lesson at `index`, or the next higher-position active lesson if that
/// slot is inactive/hidden. `None` when the path has no more active lessons
/// at or after `index`.
///
/// This is also how completion is decided (see `resolve_post_plan`): the path
/// is complete exactly when `current_lesson(path, posted.position + 1)`
/// returns `None` — "no visible lesson at a later position" — rather than
/// comparing a raw position against a separate `COUNT(*)`, which silently
/// breaks if positions are ever re-gapped.
pub async fn current_lesson(
    pool: &PgPool,
    path_id: Uuid,
    index: i32,
) -> Result<Option<Lesson>, AppError> {
    let sql = format!(
        "SELECT lpt.id, lpt.topic_id, rt.title, rt.description, rt.input_type, lpt.position,
                COALESCE(lp.recommended_mode, 'standard') AS study_mode,
                lp.title AS path_title, lp.description AS path_description,
                lp.disciple_level,
                hi_t.title AS hi_title, ml_t.title AS ml_title,
                hi_t.description AS hi_description, ml_t.description AS ml_description,
                hi_lp.title AS hi_path_title, ml_lp.title AS ml_path_title,
                hi_lp.description AS hi_path_description, ml_lp.description AS ml_path_description
         FROM learning_path_topics lpt
         JOIN recommended_topics rt ON rt.id = lpt.topic_id
         JOIN learning_paths lp ON lp.id = lpt.learning_path_id
         LEFT JOIN recommended_topics_translations hi_t ON hi_t.topic_id = rt.id AND hi_t.language_code = 'hi'
         LEFT JOIN recommended_topics_translations ml_t ON ml_t.topic_id = rt.id AND ml_t.language_code = 'ml'
         LEFT JOIN learning_path_translations hi_lp ON hi_lp.learning_path_id = lp.id AND hi_lp.lang_code = 'hi'
         LEFT JOIN learning_path_translations ml_lp ON ml_lp.learning_path_id = lp.id AND ml_lp.lang_code = 'ml'
         WHERE {VISIBLE_WHERE} AND lpt.position >= $2
         ORDER BY lpt.position
         LIMIT 1"
    );
    let lesson = sqlx::query_as::<_, Lesson>(&sql)
        .bind(path_id)
        .bind(index)
        .fetch_optional(pool)
        .await?;
    Ok(lesson)
}

pub struct LastPost {
    pub post_date: NaiveDate,
    pub learning_path_topic_id: Uuid,
    pub created_at: DateTime<Utc>,
}

/// The most recent daily post recorded for this fellowship, if any.
pub async fn last_daily_post(
    pool: &PgPool,
    fellowship_id: Uuid,
) -> Result<Option<LastPost>, AppError> {
    #[derive(sqlx::FromRow)]
    struct Row {
        post_date: NaiveDate,
        learning_path_topic_id: Uuid,
        created_at: DateTime<Utc>,
    }
    let row: Option<Row> = sqlx::query_as(
        "SELECT post_date, learning_path_topic_id, created_at FROM discipler_daily_posts
         WHERE fellowship_id = $1 ORDER BY post_date DESC, created_at DESC LIMIT 1",
    )
    .bind(fellowship_id)
    .fetch_optional(pool)
    .await?;
    Ok(row.map(|r| LastPost {
        post_date: r.post_date,
        learning_path_topic_id: r.learning_path_topic_id,
        created_at: r.created_at,
    }))
}

/// True when a fellowship posting `freq` days apart is due today.
pub fn should_post_today(last: Option<NaiveDate>, today: NaiveDate, freq: i32) -> bool {
    match last {
        None => true,
        Some(last) => (today - last).num_days() >= i64::from(freq),
    }
}

/// The path is complete exactly when no lesson exists at a later position
/// than the one just posted — pure decision over the result of
/// `current_lesson(path, posted.position + 1)`, so it's testable without a DB.
pub fn is_path_complete(next: &Option<Lesson>) -> bool {
    next.is_none()
}

/// A resolved path switch: `from` marked complete (added to history unless
/// already there), `to` chosen by `display_order` among active paths not yet
/// in the completed set — or, if every remaining candidate has no visible
/// lesson, the first active path with a visible lesson, dropped back out of
/// the completed set if it was already in it (mirrors the Edge `/set`
/// handler's history bookkeeping).
#[derive(Clone)]
pub struct SwitchPlan {
    pub from_title: String,
    pub to_path_id: Uuid,
    pub to_title: String,
    pub completed_path_ids: Vec<Uuid>,
}

/// The exact `fellowship_study` state a plan was computed from. Guards the
/// UPDATE in `insert_daily_post` so a concurrent mentor action (`/advance`,
/// `/set`, `/reset`) during generation can't be silently clobbered by a stale
/// plan — see the module doc comment.
#[derive(Clone)]
pub struct StudyGuard {
    pub learning_path_id: Uuid,
    pub current_guide_index: i32,
    pub completed_at: Option<DateTime<Utc>>,
}

impl StudyGuard {
    fn from_study(study: &FellowshipStudy) -> Self {
        StudyGuard {
            learning_path_id: study.learning_path_id,
            current_guide_index: study.current_guide_index,
            completed_at: study.completed_at,
        }
    }
}

/// What to do to `fellowship_study` when the post commits. Every variant
/// (including `NoChange`) carries the `StudyGuard` the plan was computed
/// from: even when there's nothing to change, we still need to confirm the
/// row hasn't moved since — otherwise a mentor action landing mid-generation
/// on this (most common) branch would go undetected and the cron would post
/// for a lesson the group already left (NEW-1).
pub enum StudyWrite {
    NoChange {
        guard: StudyGuard,
    },
    Resync {
        study_id: Uuid,
        new_index: i32,
        guard: StudyGuard,
    },
    Switch {
        plan: SwitchPlan,
        /// Position of the lesson actually being posted on the new path —
        /// may be > 0 if the new path's leading slots are hidden.
        posted_index: i32,
        guard: StudyGuard,
    },
}

pub struct PostPlan {
    pub lesson: Lesson,
    pub write: StudyWrite,
}

/// Resolves a path switch away from `study.learning_path_id`. Candidates are
/// tried in `display_order`: active paths not yet in `completed_path_ids`
/// first, then (wrap-around) every active path again. A candidate with no
/// visible lesson is skipped for *this* resolution only — it is never
/// recorded into `completed_path_ids` (hopping over an empty path is not the
/// same as the fellowship having completed it, and persisting that would
/// strand it out of rotation even after it later gains visible topics). Only
/// `study.learning_path_id` itself — the path that is genuinely exhausted —
/// is added to history. If the chosen candidate happens to already be in the
/// completed set (the wrap-around case, or "every fresh path was empty so we
/// fell back to one already completed"), it's dropped back out of the set,
/// mirroring the Edge `/set` handler.
async fn resolve_switch_plan(
    pool: &PgPool,
    study: &FellowshipStudy,
) -> Result<Option<PostPlan>, AppError> {
    let guard = StudyGuard::from_study(study);

    let from_title: String = sqlx::query_scalar("SELECT title FROM learning_paths WHERE id = $1")
        .bind(study.learning_path_id)
        .fetch_one(pool)
        .await?;

    let mut completed_path_ids = study.completed_path_ids.clone();
    if !completed_path_ids.contains(&study.learning_path_id) {
        completed_path_ids.push(study.learning_path_id);
    }

    let not_completed: Vec<Uuid> = sqlx::query_scalar(
        "SELECT id FROM learning_paths WHERE is_active = true AND id <> ALL($1) ORDER BY display_order",
    )
    .bind(&completed_path_ids)
    .fetch_all(pool)
    .await?;
    let all_active: Vec<Uuid> = sqlx::query_scalar(
        "SELECT id FROM learning_paths WHERE is_active = true ORDER BY display_order",
    )
    .fetch_all(pool)
    .await?;

    let mut candidates = not_completed;
    for id in &all_active {
        if !candidates.contains(id) {
            candidates.push(*id);
        }
    }

    for candidate in candidates {
        let Some(lesson) = current_lesson(pool, candidate, 0).await? else {
            // No visible lesson on this candidate — try the next one. Not
            // recorded anywhere; it stays eligible for the next resolution.
            continue;
        };
        let to_title: String = sqlx::query_scalar("SELECT title FROM learning_paths WHERE id = $1")
            .bind(candidate)
            .fetch_one(pool)
            .await?;

        let mut final_completed = completed_path_ids.clone();
        if final_completed.contains(&candidate) {
            final_completed.retain(|&id| id != candidate);
        }

        let posted_index = lesson.position;
        return Ok(Some(PostPlan {
            lesson,
            write: StudyWrite::Switch {
                plan: SwitchPlan {
                    from_title,
                    to_path_id: candidate,
                    to_title,
                    completed_path_ids: final_completed,
                },
                posted_index,
                guard,
            },
        }));
    }

    tracing::warn!(
        fellowship_id = %study.fellowship_id,
        "No learning path with a visible lesson found — skipping"
    );
    Ok(None)
}

/// Resolves what today's post (if any) should be, entirely in memory — no
/// writes happen here. `ensure_study` is the sole exception (it only ever
/// bootstraps a brand-new fellowship's first path, which never discards a
/// pending post).
///
/// A completed study row, or a stored index with no active lesson left at or
/// after it (position gaps, topics hidden/removed after the fact), both mean
/// "this path is exhausted" and always resolve to the next path — this must
/// not depend on `auto_advance`, or a fellowship with auto-advance off would
/// be stranded on an exhausted path forever. `auto_advance` only gates the
/// mentor-facing decision in spec §4 step 2: move past a lesson that was
/// already posted.
pub async fn resolve_post_plan(
    pool: &PgPool,
    fellowship_id: Uuid,
    last: Option<&LastPost>,
    auto_advance: bool,
) -> Result<Option<PostPlan>, AppError> {
    let study = ensure_study(pool, fellowship_id).await?;
    let guard = StudyGuard::from_study(&study);

    if study.completed_at.is_some() {
        return resolve_switch_plan(pool, &study).await;
    }

    let Some(lesson) =
        current_lesson(pool, study.learning_path_id, study.current_guide_index).await?
    else {
        return resolve_switch_plan(pool, &study).await;
    };

    // Relies on `started_at` (written by `insert_daily_post`'s Switch/Resync
    // branches) and `discipler_daily_posts.created_at` (read back as
    // `LastPost.created_at` by `last_daily_post`) both coming from the same
    // transaction's `now()` — a `>` here (or writing `started_at` outside that
    // transaction) would let the lesson we just switched to look "not yet
    // posted" and re-post it.
    let already_posted = last
        .map(|l| l.learning_path_topic_id == lesson.id && l.created_at >= study.started_at)
        .unwrap_or(false);

    if !already_posted {
        let write = if lesson.position == study.current_guide_index {
            StudyWrite::NoChange { guard }
        } else {
            // Resync the stored cursor to the position we actually resolved
            // (it fell in a gap) so the next advance starts from the right spot.
            StudyWrite::Resync {
                study_id: study.id,
                new_index: lesson.position,
                guard,
            }
        };
        return Ok(Some(PostPlan { lesson, write }));
    }

    if !auto_advance {
        return Ok(None);
    }

    // Completion = no visible lesson at a position later than the one just
    // posted — not a count comparison (N3): that stays correct even if an
    // admin re-gaps positions after the fact.
    let next = current_lesson(pool, study.learning_path_id, lesson.position + 1).await?;
    if is_path_complete(&next) {
        return resolve_switch_plan(pool, &study).await;
    }
    let next_lesson = next.expect("checked by is_path_complete");
    Ok(Some(PostPlan {
        write: StudyWrite::Resync {
            study_id: study.id,
            new_index: next_lesson.position,
            guard,
        },
        lesson: next_lesson,
    }))
}

pub struct DailyPostInsert<'a> {
    pub fellowship_id: Uuid,
    pub content: &'a str,
    pub topic_id: Uuid,
    pub topic_title: &'a str,
    pub guide_title: &'a str,
    pub study_guide_id: Option<Uuid>,
    pub language: &'a str,
    pub learning_path_topic_id: Uuid,
    pub post_date: NaiveDate,
    pub study_write: StudyWrite,
}

/// Result of `insert_daily_post`. Both non-`Posted` variants mean the whole
/// transaction was rolled back — nothing was written.
pub enum InsertOutcome {
    Posted(Uuid),
    /// The `fellowship_study` guard matched zero rows: the row changed since
    /// the plan was computed (a mentor `/advance`, `/set`, or `/reset` landed
    /// during generation). Nothing persisted; the next run recomputes.
    StaleStudy,
    /// `(fellowship_id, post_date)` already existed (raced another trigger of
    /// the same job).
    AlreadyPosted,
}

/// Applies the resolved `study_write` (guarded against a concurrent change —
/// see `StudyGuard`), inserts the fellowship post, the cursor row, and (on a
/// switch) the "Path completed" activity row — all in one transaction.
pub async fn insert_daily_post(
    pool: &PgPool,
    input: DailyPostInsert<'_>,
) -> Result<InsertOutcome, AppError> {
    let discipler = Uuid::parse_str(DISCIPLER_USER_ID).expect("constant uuid");
    let mut tx = pool.begin().await?;

    match &input.study_write {
        StudyWrite::NoChange { guard } => {
            // Nothing to change, but still confirm the row hasn't moved since
            // the plan was computed (NEW-1) — otherwise a mentor action
            // landing mid-generation on this (most common) branch would go
            // undetected and the cron would post for an abandoned lesson.
            let row: Option<(i32,)> = sqlx::query_as(
                "SELECT 1 FROM fellowship_study
                 WHERE fellowship_id = $1 AND learning_path_id = $2 AND current_guide_index = $3
                   AND completed_at IS NOT DISTINCT FROM $4
                 FOR UPDATE",
            )
            .bind(input.fellowship_id)
            .bind(guard.learning_path_id)
            .bind(guard.current_guide_index)
            .bind(guard.completed_at)
            .fetch_optional(&mut *tx)
            .await?;
            if row.is_none() {
                tx.rollback().await?;
                return Ok(InsertOutcome::StaleStudy);
            }
        }
        StudyWrite::Resync {
            study_id,
            new_index,
            guard,
        } => {
            let result = sqlx::query(
                "UPDATE fellowship_study
                   SET current_guide_index = $2, updated_at = now()
                 WHERE id = $1 AND learning_path_id = $3 AND current_guide_index = $4
                   AND completed_at IS NOT DISTINCT FROM $5",
            )
            .bind(study_id)
            .bind(new_index)
            .bind(guard.learning_path_id)
            .bind(guard.current_guide_index)
            .bind(guard.completed_at)
            .execute(&mut *tx)
            .await?;
            if result.rows_affected() == 0 {
                tx.rollback().await?;
                return Ok(InsertOutcome::StaleStudy);
            }
        }
        StudyWrite::Switch {
            plan,
            posted_index,
            guard,
        } => {
            let result = sqlx::query(
                "UPDATE fellowship_study
                   SET learning_path_id = $2, current_guide_index = $3, started_at = now(),
                       completed_at = NULL, completed_path_ids = $4, updated_at = now()
                 WHERE fellowship_id = $1 AND learning_path_id = $5 AND current_guide_index = $6
                   AND completed_at IS NOT DISTINCT FROM $7",
            )
            .bind(input.fellowship_id)
            .bind(plan.to_path_id)
            .bind(posted_index)
            .bind(&plan.completed_path_ids)
            .bind(guard.learning_path_id)
            .bind(guard.current_guide_index)
            .bind(guard.completed_at)
            .execute(&mut *tx)
            .await?;
            if result.rows_affected() == 0 {
                tx.rollback().await?;
                return Ok(InsertOutcome::StaleStudy);
            }
        }
    }

    let (post_id,): (Uuid,) = sqlx::query_as(
        "INSERT INTO fellowship_posts
           (fellowship_id, author_user_id, content, post_type, topic_id, topic_title, guide_title,
            study_guide_id, guide_input_type, guide_language)
         VALUES ($1, $2, $3, 'daily', $4, $5, $6, $7, 'topic', $8)
         RETURNING id",
    )
    .bind(input.fellowship_id)
    .bind(discipler)
    .bind(input.content)
    .bind(input.topic_id.to_string())
    .bind(input.topic_title)
    .bind(input.guide_title)
    .bind(input.study_guide_id)
    .bind(input.language)
    .fetch_one(&mut *tx)
    .await?;

    let inserted: Option<(Uuid,)> = sqlx::query_as(
        "INSERT INTO discipler_daily_posts (fellowship_id, post_date, topic_id, learning_path_topic_id, study_guide_id, post_id)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (fellowship_id, post_date) DO NOTHING
         RETURNING id",
    )
    .bind(input.fellowship_id)
    .bind(input.post_date)
    .bind(input.topic_id)
    .bind(input.learning_path_topic_id)
    .bind(input.study_guide_id)
    .bind(post_id)
    .fetch_optional(&mut *tx)
    .await?;

    if inserted.is_none() {
        tx.rollback().await?;
        return Ok(InsertOutcome::AlreadyPosted);
    }

    if let StudyWrite::Switch { plan, .. } = &input.study_write {
        let summary = format!(
            "Path completed: {} → started {}",
            plan.from_title, plan.to_title
        );
        sqlx::query(
            "INSERT INTO discipler_activity (fellowship_id, kind, summary) VALUES ($1, 'daily_post', $2)",
        )
        .bind(input.fellowship_id)
        .bind(summary)
        .execute(&mut *tx)
        .await?;
    }

    tx.commit().await?;
    Ok(InsertOutcome::Posted(post_id))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn dummy_lesson(position: i32) -> Lesson {
        Lesson {
            id: Uuid::nil(),
            topic_id: Uuid::nil(),
            title: "T".into(),
            description: None,
            input_type: "topic".into(),
            position,
            path_title: "P".into(),
            path_description: "PD".into(),
            disciple_level: "new".into(),
            hi_title: None,
            ml_title: None,
            hi_description: None,
            ml_description: None,
            hi_path_title: None,
            ml_path_title: None,
            hi_path_description: None,
            ml_path_description: None,
            study_mode: "standard".into(),
        }
    }

    #[test]
    fn should_post_today_when_never_posted() {
        let today = NaiveDate::from_ymd_opt(2026, 9, 6).unwrap();
        assert!(should_post_today(None, today, 1));
        assert!(should_post_today(None, today, 7));
    }

    #[test]
    fn should_post_today_respects_frequency() {
        let today = NaiveDate::from_ymd_opt(2026, 9, 6).unwrap();
        let yesterday = NaiveDate::from_ymd_opt(2026, 9, 5).unwrap();
        assert!(should_post_today(Some(yesterday), today, 1));
        assert!(!should_post_today(Some(yesterday), today, 2));

        let six_days_ago = NaiveDate::from_ymd_opt(2026, 8, 31).unwrap();
        assert!(!should_post_today(Some(six_days_ago), today, 7));
        let seven_days_ago = NaiveDate::from_ymd_opt(2026, 8, 30).unwrap();
        assert!(should_post_today(Some(seven_days_ago), today, 7));
    }

    /// Finding 6: a fellowship that already posted today is never due again
    /// today, at any frequency (freq >= 1 always requires at least one full
    /// day to have elapsed).
    #[test]
    fn should_post_today_same_day_is_not_due() {
        let today = NaiveDate::from_ymd_opt(2026, 9, 6).unwrap();
        assert!(!should_post_today(Some(today), today, 1));
        assert!(!should_post_today(Some(today), today, 2));
        assert!(!should_post_today(Some(today), today, 7));
    }

    #[test]
    fn is_path_complete_false_when_a_later_lesson_exists() {
        assert!(!is_path_complete(&Some(dummy_lesson(4))));
    }

    #[test]
    fn is_path_complete_true_when_no_later_lesson_exists() {
        assert!(is_path_complete(&None));
    }
}
