# Fellowship 1.0.5 — Plan 03: rs-backend Crons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two rs-backend cron jobs: `fellowship_daily_post` (generate the next learning-path study per fellowship and post it as Discipler) and `discipler_reply_worker` (drain the reply queue every minute and flush hourly activity digests), wired into the existing cron config, admin endpoints, and study API client.

**Architecture:** Mirrors `blog_generation`: a `pub const` schedule, an `AtomicBool` + `CronGuard`, a registration block in `start_scheduler`, a `cron_config` row (Plan 01), and an explicit arm in the admin schedule-update handler. Direct Postgres writes through sqlx; pushes go through the Edge Function route `fellowship-posts/notify` with the service-role bearer; model calls go through `fellowship-posts/discipler-reply` with the internal API key.

**Tech Stack:** Rust 2021, axum 0.7, sqlx 0.8 (runtime-checked queries), tokio-cron-scheduler 0.13, reqwest 0.12, serde_json, tracing.

**Spec:** `docs/superpowers/specs/2026-09-06-fellowship-discipler-redesign-design.md` §2 (worker), §3 (daily post). Index: `2026-09-06-fellowship-discipler-00-index.md`. Requires Plans 01 and 02.

## Global Constraints

See index. Relevant here:
- Schedules: `FELLOWSHIP_DAILY_POST = "0 0 1 * * *"`, `DISCIPLER_REPLY_WORKER = "0 * * * * *"`.
- Discipler user id `00000000-0000-4000-8000-00000000d15c`.
- Generation uses the blog's exact `generate_study_guide` parameters with `language = fellowship.language` and mode from the path (`recommended`/`ask` → `standard`).
- rs-backend has no tests directory; unit tests go in `#[cfg(test)] mod tests` at the bottom of the module, pure functions only.
- `cargo fmt`, `cargo clippy -- -D warnings`, `cargo test` must pass. Run from `rs-backend/`.

---

### Task 1: Capture `studyGuideId` from the study API

**Files:**
- Modify: `rs-backend/src/services/study_api.rs` (`StudyGuideResult` :18-21, parse loop :100-145)

**Interfaces:**
- Produces: `pub struct StudyGuideResult { pub sections: HashMap<String, String>, pub study_guide_id: Option<Uuid>, pub from_cache: bool }`.

- [ ] **Step 1: Write the failing test for the parser**

Extract the parse loop into a pure function and test it. Add at the bottom of `study_api.rs`:
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_sections_and_complete_event() {
        let body = "event: section\ndata: {\"type\":\"summary\",\"content\":\"Hello\"}\n\nevent: complete\ndata: {\"studyGuideId\":\"6f1c0d2e-4a6b-4c1d-9e2f-0123456789ab\",\"tokensConsumed\":0,\"fromCache\":true}\n";
        let r = parse_sse_body(body).unwrap();
        assert_eq!(r.sections.get("summary").map(String::as_str), Some("Hello"));
        assert_eq!(r.study_guide_id.map(|u| u.to_string()).as_deref(), Some("6f1c0d2e-4a6b-4c1d-9e2f-0123456789ab"));
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
```

- [ ] **Step 2: Run to verify failure** — `cargo test parses_sections` → compile error, `parse_sse_body` missing.

- [ ] **Step 3: Implement**

Replace the struct and the loop:
```rust
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
        let Some(data) = line.strip_prefix("data: ") else { continue };
        let Ok(parsed) = serde_json::from_str::<Value>(data) else { continue };

        if parsed.get("code").is_some() && parsed.get("message").is_some() {
            return Err(AppError::Internal(format!(
                "Study API error: {} - {}",
                parsed["code"].as_str().unwrap_or("unknown"),
                parsed["message"].as_str().unwrap_or("unknown")
            )));
        }

        if let Some(id) = parsed.get("studyGuideId").and_then(Value::as_str) {
            study_guide_id = Uuid::parse_str(id).ok();
            from_cache = parsed.get("fromCache").and_then(Value::as_bool).unwrap_or(false);
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
        return Err(AppError::Internal("No sections received from study-generate-v2".to_string()));
    }
    Ok(StudyGuideResult { sections, study_guide_id, from_cache })
}
```
In `generate_study_guide`, after `let body = String::from_utf8_lossy(&raw).into_owned();` replace the loop with:
```rust
    let result = parse_sse_body(&body)?;
    tracing::info!(section_count = result.sections.len(), from_cache = result.from_cache, "Study guide received");
    Ok(result)
```
Add `use uuid::Uuid;` at the top.

- [ ] **Step 4: Run tests** — `cargo test study_api` → 3 passed. `cargo clippy -- -D warnings` clean (blog_generator only reads `.sections`, so it still compiles).

- [ ] **Step 5: Commit**

```bash
git add rs-backend/src/services/study_api.rs
git commit -m "feat(rs-backend): capture studyGuideId and fromCache from the study SSE stream"
```

---

### Task 2: Daily post formatter

**Files:**
- Modify: `rs-backend/src/services/content_formatter.rs`

**Interfaces:**
- Produces: `pub fn format_daily_post(topic_title: &str, guide: &StudyGuideResult, locale: &str) -> DailyPostContent` where `pub struct DailyPostContent { pub content: String, pub question: Option<String>, pub verse: Option<String> }`. Content is plain text ≤ 1,900 chars: title line, two-sentence summary, verse line, question line, "Open the full study" line (localized).

- [ ] **Step 1: Write the failing tests** (append to the existing or new `#[cfg(test)] mod tests` in this file)

```rust
#[cfg(test)]
mod daily_tests {
    use super::*;
    use std::collections::HashMap;

    fn guide() -> StudyGuideResult {
        let mut s = HashMap::new();
        s.insert("summary".into(), "Paul reminds the Corinthians that trust outlasts sight. Faith is sight fixed on the eternal. A third sentence.".into());
        s.insert("reflectionQuestions".into(), "[\"When has faith carried you past what you could see?\",\"Second?\"]".into());
        s.insert("relatedVerses".into(), "[{\"reference\":\"2 Corinthians 5:7\",\"text\":\"For we walk by faith\"}]".into());
        StudyGuideResult { sections: s, study_guide_id: None, from_cache: false }
    }

    #[test]
    fn builds_english_daily_post() {
        let d = format_daily_post("Walking by Faith", &guide(), "en");
        assert!(d.content.starts_with("📖 Walking by Faith\n\n"));
        assert!(d.content.contains("Paul reminds the Corinthians that trust outlasts sight. Faith is sight fixed on the eternal."));
        assert!(!d.content.contains("A third sentence"));
        assert_eq!(d.verse.as_deref(), Some("2 Corinthians 5:7"));
        assert_eq!(d.question.as_deref(), Some("When has faith carried you past what you could see?"));
        assert!(d.content.ends_with("Open the full study →"));
    }

    #[test]
    fn falls_back_when_sections_missing() {
        let g = StudyGuideResult { sections: HashMap::from([("summary".to_string(), "Only one.".to_string())]), study_guide_id: None, from_cache: false };
        let d = format_daily_post("T", &g, "ml");
        assert_eq!(d.verse, None);
        assert_eq!(d.question, None);
        assert!(d.content.contains("Only one."));
        assert!(d.content.ends_with("മുഴുവൻ പഠനം തുറക്കുക →"));
    }

    #[test]
    fn related_verses_as_plain_strings() {
        let g = StudyGuideResult { sections: HashMap::from([
            ("summary".to_string(), "S.".to_string()),
            ("relatedVerses".to_string(), "[\"John 3:16\"]".to_string()),
        ]), study_guide_id: None, from_cache: false };
        assert_eq!(format_daily_post("T", &g, "hi").verse.as_deref(), Some("John 3:16"));
    }
}
```

- [ ] **Step 2: Run to verify failure** — `cargo test daily_tests` → compile error.

- [ ] **Step 3: Implement**

```rust
pub struct DailyPostContent {
    pub content: String,
    pub question: Option<String>,
    pub verse: Option<String>,
}

fn first_sentences(text: &str, n: usize) -> String {
    let mut out = String::new();
    let mut count = 0;
    for piece in text.split_inclusive(|c| c == '.' || c == '।' || c == '?' || c == '!') {
        out.push_str(piece);
        count += 1;
        if count == n { break; }
    }
    out.trim().to_string()
}

fn open_study_label(locale: &str) -> &'static str {
    match locale {
        "hi" => "पूरा अध्ययन खोलें →",
        "ml" => "മുഴുവൻ പഠനം തുറക്കുക →",
        _ => "Open the full study →",
    }
}

/// Plain-text daily post body for fellowship feeds (no markdown headings).
pub fn format_daily_post(topic_title: &str, guide: &StudyGuideResult, locale: &str) -> DailyPostContent {
    let summary = guide.sections.get("summary").map(|s| first_sentences(s, 2)).unwrap_or_default();

    let question = guide.sections.get("reflectionQuestions")
        .and_then(|raw| serde_json::from_str::<Vec<String>>(raw).ok())
        .and_then(|v| v.into_iter().next())
        .map(|q| q.trim().to_string())
        .filter(|q| !q.is_empty());

    let verse = guide.sections.get("relatedVerses").and_then(|raw| {
        if let Ok(v) = serde_json::from_str::<Vec<String>>(raw) {
            return v.into_iter().next();
        }
        serde_json::from_str::<Vec<serde_json::Value>>(raw).ok()
            .and_then(|v| v.into_iter().next())
            .and_then(|o| o.get("reference").and_then(|r| r.as_str()).map(String::from))
    }).map(|s| s.trim().to_string()).filter(|s| !s.is_empty());

    let mut content = format!("📖 {}\n\n{}", topic_title.trim(), summary);
    if let Some(v) = &verse { content.push_str(&format!("\n\n✝️ {}", v)); }
    if let Some(q) = &question { content.push_str(&format!("\n\n💬 {}", q)); }
    content.push_str(&format!("\n\n{}", open_study_label(locale)));

    let content: String = content.chars().take(1900).collect();
    DailyPostContent { content, question, verse }
}
```

- [ ] **Step 4: Run tests** — `cargo test daily_tests` → 3 passed.

- [ ] **Step 5: Commit**

```bash
git add rs-backend/src/services/content_formatter.rs
git commit -m "feat(rs-backend): format_daily_post for Discipler fellowship posts"
```

---

### Task 3: Fellowship daily models (queries)

**Files:**
- Create: `rs-backend/src/models/fellowship_daily.rs`
- Modify: `rs-backend/src/models/mod.rs` (add `pub mod fellowship_daily;`)

**Interfaces:**
- Produces:
```rust
pub const DISCIPLER_USER_ID: &str = "00000000-0000-4000-8000-00000000d15c";
pub struct DailyFellowship { pub id: Uuid, pub name: String, pub language: String }
pub async fn list_daily_fellowships(pool: &PgPool, today: NaiveDate) -> Result<Vec<DailyFellowship>, AppError>
pub async fn find_next_topic_for_fellowship(pool: &PgPool, fellowship_id: Uuid) -> Result<Option<LearningPathTopic>, AppError>
pub async fn reset_topic_cursor(pool: &PgPool, fellowship_id: Uuid) -> Result<(), AppError>
pub struct DailyPostInsert<'a> { pub fellowship_id: Uuid, pub content: &'a str, pub topic_id: Uuid, pub topic_title: &'a str, pub guide_title: &'a str, pub study_guide_id: Option<Uuid>, pub language: &'a str, pub learning_path_topic_id: Uuid, pub post_date: NaiveDate }
pub async fn insert_daily_post(pool: &PgPool, input: DailyPostInsert<'_>) -> Result<Uuid, AppError>
```

- [ ] **Step 1: Implement** (no DB tests exist in this crate; verified by running the cron in Task 4)

```rust
//! Queries for the Discipler daily post cron.
use chrono::NaiveDate;
use sqlx::PgPool;
use uuid::Uuid;

use crate::cron::blog_generator::LearningPathTopic;
use crate::error::AppError;

pub const DISCIPLER_USER_ID: &str = "00000000-0000-4000-8000-00000000d15c";

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct DailyFellowship {
    pub id: Uuid,
    pub name: String,
    pub language: String,
}

/// Fellowships that should get a post today and have not received one yet.
pub async fn list_daily_fellowships(pool: &PgPool, today: NaiveDate) -> Result<Vec<DailyFellowship>, AppError> {
    let rows = sqlx::query_as::<_, DailyFellowship>(
        "SELECT f.id, f.name, f.language
         FROM fellowships f
         WHERE f.is_active = true AND f.daily_post_allowed = true AND f.daily_post_on = true
           AND NOT EXISTS (SELECT 1 FROM discipler_daily_posts d WHERE d.fellowship_id = f.id AND d.post_date = $1)
         ORDER BY f.created_at",
    )
    .bind(today)
    .fetch_all(pool)
    .await?;
    Ok(rows)
}

const TOPIC_SELECT: &str =
    "SELECT lpt.id, lpt.topic_id, rt.title, rt.description, rt.input_type,
            COALESCE(lp.recommended_mode, 'standard') AS study_mode,
            lp.id AS path_id, lp.title AS path_title, lp.description AS path_description,
            lp.disciple_level, lp.category,
            hi_t.title AS hi_title, ml_t.title AS ml_title,
            hi_t.description AS hi_description, ml_t.description AS ml_description,
            hi_lp.title AS hi_path_title, ml_lp.title AS ml_path_title,
            hi_lp.description AS hi_path_description, ml_lp.description AS ml_path_description
     FROM learning_path_topics lpt
     JOIN recommended_topics rt ON lpt.topic_id = rt.id
     JOIN learning_paths lp ON lpt.learning_path_id = lp.id
     LEFT JOIN recommended_topics_translations hi_t ON hi_t.topic_id = rt.id AND hi_t.language_code = 'hi'
     LEFT JOIN recommended_topics_translations ml_t ON ml_t.topic_id = rt.id AND ml_t.language_code = 'ml'
     LEFT JOIN learning_path_translations hi_lp ON hi_lp.learning_path_id = lp.id AND hi_lp.lang_code = 'hi'
     LEFT JOIN learning_path_translations ml_lp ON ml_lp.learning_path_id = lp.id AND ml_lp.lang_code = 'ml'
     WHERE lp.is_active = true AND rt.is_active = true
       AND NOT EXISTS (SELECT 1 FROM discipler_daily_posts d
                       WHERE d.fellowship_id = $1 AND d.learning_path_topic_id = lpt.id)
     ORDER BY lp.display_order, lpt.position
     LIMIT 1";

/// Next unused topic for this fellowship in path display order.
pub async fn find_next_topic_for_fellowship(pool: &PgPool, fellowship_id: Uuid) -> Result<Option<LearningPathTopic>, AppError> {
    let topic = sqlx::query_as::<_, LearningPathTopic>(TOPIC_SELECT)
        .bind(fellowship_id)
        .fetch_optional(pool)
        .await?;
    Ok(topic)
}

/// Wrap the cursor: forget which topics were used so the sequence restarts.
pub async fn reset_topic_cursor(pool: &PgPool, fellowship_id: Uuid) -> Result<(), AppError> {
    sqlx::query("DELETE FROM discipler_daily_posts WHERE fellowship_id = $1 AND post_date < CURRENT_DATE")
        .bind(fellowship_id)
        .execute(pool)
        .await?;
    Ok(())
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
}

/// Inserts the fellowship post and the cursor row in one transaction. Returns the post id.
pub async fn insert_daily_post(pool: &PgPool, input: DailyPostInsert<'_>) -> Result<Uuid, AppError> {
    let discipler = Uuid::parse_str(DISCIPLER_USER_ID).expect("constant uuid");
    let mut tx = pool.begin().await?;

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

    sqlx::query(
        "INSERT INTO discipler_daily_posts (fellowship_id, post_date, topic_id, learning_path_topic_id, study_guide_id, post_id)
         VALUES ($1, $2, $3, $4, $5, $6)",
    )
    .bind(input.fellowship_id)
    .bind(input.post_date)
    .bind(input.topic_id)
    .bind(input.learning_path_topic_id)
    .bind(input.study_guide_id)
    .bind(post_id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(post_id)
}
```
`fellowship_posts.topic_id` is `TEXT` in the schema (migration `20260309000001`), hence `.to_string()`.

- [ ] **Step 2: Build** — `cargo build` clean. Register `pub mod fellowship_daily;` in `src/models/mod.rs`.

- [ ] **Step 3: Commit**

```bash
git add rs-backend/src/models/fellowship_daily.rs rs-backend/src/models/mod.rs
git commit -m "feat(rs-backend): daily post queries with per-fellowship topic cursor"
```

---

### Task 4: `fellowship_daily_post` cron job

**Files:**
- Create: `rs-backend/src/cron/fellowship_daily_post.rs`
- Modify: `rs-backend/src/cron/schedules.rs`, `rs-backend/src/cron/mod.rs`

**Interfaces:**
- Consumes: Tasks 1–3, `study_api::generate_study_guide`, `Config { supabase_url, supabase_service_role_key }`.
- Produces: `pub async fn run_fellowship_daily_post(pool: &PgPool, config: &Config, http: &Client) -> Result<(), AppError>`, static `FELLOWSHIP_DAILY_POST_RUNNING`, const `schedules::FELLOWSHIP_DAILY_POST`.

- [ ] **Step 1: Schedule constant**

Append to `schedules.rs`:
```rust
/// Discipler daily fellowship post — 01:00 UTC (06:30 IST).
pub const FELLOWSHIP_DAILY_POST: &str = "0 0 1 * * *";

/// Discipler reply worker — every minute; drains the reply queue and, on minute 0, flushes activity digests.
pub const DISCIPLER_REPLY_WORKER: &str = "0 * * * * *";
```

- [ ] **Step 2: Write the job with a pure, testable locale picker**

```rust
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
    let pick = |l: &'a Option<String>, en: &'a str| l.as_deref().filter(|s| !s.trim().is_empty()).unwrap_or(en);
    let pick_opt = |l: &'a Option<String>, en: &'a Option<String>| l.as_deref().filter(|s| !s.trim().is_empty()).or(en.as_deref());
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
    match study_mode { "recommended" | "ask" => "standard", m => m }
}

async fn notify(config: &Config, http: &Client, post_id: uuid::Uuid) -> Result<(), AppError> {
    let url = format!("{}/functions/v1/fellowship-posts/notify", config.supabase_url);
    let resp = http
        .post(&url)
        .header("Authorization", format!("Bearer {}", config.supabase_service_role_key))
        .header("apikey", &config.supabase_anon_key)
        .header("Content-Type", "application/json")
        .json(&serde_json::json!({ "kind": "daily_post", "post_id": post_id }))
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("notify request failed: {e}")))?;
    if !resp.status().is_success() {
        let status = resp.status();
        let body = resp.text().await.unwrap_or_default();
        return Err(AppError::Internal(format!("notify returned {status}: {body}")));
    }
    Ok(())
}

async fn post_for_fellowship(pool: &PgPool, config: &Config, http: &Client, f: &DailyFellowship) -> Result<(), AppError> {
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
        http, config, &topic.input_type, l.title, l.description, Some(l.path_title),
        Some(l.path_description), Some(&topic.disciple_level), &f.language, batch_mode(&topic.study_mode),
    ).await?;

    let daily = content_formatter::format_daily_post(l.title, &guide, &f.language);
    let post_id = fellowship_daily::insert_daily_post(pool, DailyPostInsert {
        fellowship_id: f.id, content: &daily.content, topic_id: topic.topic_id, topic_title: l.title,
        guide_title: l.title, study_guide_id: guide.study_guide_id, language: &f.language,
        learning_path_topic_id: topic.id, post_date: today,
    }).await?;
    tracing::info!(fellowship = %f.name, topic = %l.title, %post_id, from_cache = guide.from_cache, "Daily post created");

    if let Err(e) = notify(config, http, post_id).await {
        tracing::error!(%post_id, "Daily post notify failed (post kept): {}", e);
    }
    Ok(())
}

pub async fn run_fellowship_daily_post(pool: &PgPool, config: &Config, http: &Client) -> Result<(), AppError> {
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
            Err(e) => { failed += 1; tracing::error!(fellowship = %f.name, "Daily post failed: {}", e); }
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
            id: uuid::Uuid::nil(), topic_id: uuid::Uuid::nil(), title: "Faith".into(), description: Some("d".into()),
            input_type: "topic".into(), path_id: uuid::Uuid::nil(), path_title: "Path".into(), path_description: "pd".into(),
            disciple_level: "new".into(), category: None,
            hi_title: Some("विश्वास".into()), ml_title: None, hi_description: None, ml_description: Some("  ".into()),
            hi_path_title: None, ml_path_title: Some("പാത".into()), hi_path_description: None, ml_path_description: None,
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
```
`LearningPathTopic` fields must be `pub` (they are) and the struct must be constructible from this module (it is, same crate).

- [ ] **Step 3: Register in `cron/mod.rs`**

Add `pub mod fellowship_daily_post;` and `pub mod discipler_reply_worker;` (created in Task 6; add the second line then), statics:
```rust
pub static FELLOWSHIP_DAILY_POST_RUNNING: AtomicBool = AtomicBool::new(false);
pub static DISCIPLER_REPLY_WORKER_RUNNING: AtomicBool = AtomicBool::new(false);
```
Add to the hardcoded defaults vector:
```rust
            CronConfig { name: "fellowship_daily_post".into(), enabled: false, schedule: schedules::FELLOWSHIP_DAILY_POST.into(), label: "Daily 06:30 IST — Discipler learning-path post".into(), updated_at: chrono::Utc::now() },
            CronConfig { name: "discipler_reply_worker".into(), enabled: false, schedule: schedules::DISCIPLER_REPLY_WORKER.into(), label: "Every minute — drain Discipler reply queue".into(), updated_at: chrono::Utc::now() },
```
Add a registration block, copied from the `subscription_reconcile` block with these substitutions: variable prefix `daily_`, config name `"fellowship_daily_post"`, default `schedules::FELLOWSHIP_DAILY_POST`, guard `FELLOWSHIP_DAILY_POST_RUNNING`, body `fellowship_daily_post::run_fellowship_daily_post(&p, &c, &h)`, error label `"Discipler daily post CRON failed"`, `job_ids.insert("fellowship_daily_post".into(), daily_uuid)`. The closure must capture `pool`, `config` (as `Arc`), and `http` like the blog block does.

- [ ] **Step 4: Run tests and a local dry run**

`cargo test fellowship_daily_post` → 2 passed. `cargo clippy -- -D warnings` clean.
Local run (needs `rs-backend/.env` pointing at local Supabase, `INTERNAL_API_KEY` matching `backend/.env.local`, and an LLM key in the backend env):
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -Atc "update fellowships set daily_post_allowed=true, is_official=true where id='f0000000-0000-0000-0000-000000000001'; update cron_config set enabled=true where name='fellowship_daily_post';"
cd rs-backend && cargo run 2>&1 | grep -E "CRON scheduler started|Daily post" &
# trigger manually via the admin endpoint after Task 5, or temporarily set the schedule to "*/30 * * * * *" in cron_config and restart
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -Atc "select post_type, left(content, 60), study_guide_id is not null from fellowship_posts where author_user_id='00000000-0000-4000-8000-00000000d15c' order by created_at desc limit 1; select post_date, topic_id from discipler_daily_posts order by created_at desc limit 1;"
```
Expected: one `daily` post starting with `📖`, a cursor row for today, and the second run inserts nothing (idempotent).

- [ ] **Step 5: Commit**

```bash
git add rs-backend/src/cron/fellowship_daily_post.rs rs-backend/src/cron/schedules.rs rs-backend/src/cron/mod.rs
git commit -m "feat(rs-backend): fellowship_daily_post cron generating Discipler learning-path posts"
```

---

### Task 5: Admin cron endpoints know the new jobs

**Files:**
- Modify: `rs-backend/src/routes/admin.rs` (`trigger_cron` :73-98, `cron_status` :100-120, `cron_update_schedule` match :221-268)
- Modify: `rs-backend/src/routes/mod.rs:31` (trigger route gains `/:name`)

**Interfaces:**
- Produces: `POST /api/v1/admin/cron/trigger/:name` for `blog_generation | blog_retry | fellowship_daily_post | discipler_reply_worker`; `cron_status` reports `fellowship_daily_post_running`, `discipler_reply_worker_running`; schedule hot-reload routes each name to its own job.

- [ ] **Step 1: Write a pure dispatch table and test it**

Add to `admin.rs`:
```rust
/// Which guard flag a job name uses. None = unknown job.
pub(crate) fn guard_for(name: &str) -> Option<&'static std::sync::atomic::AtomicBool> {
    use crate::cron::*;
    Some(match name {
        "blog_generation" => &BLOG_GENERATION_RUNNING,
        "blog_retry" => &BLOG_RETRY_RUNNING,
        "blog_publish_scheduled" => &BLOG_PUBLISH_SCHEDULED_RUNNING,
        "subscription_reconcile" => &SUBSCRIPTION_RECONCILE_RUNNING,
        "fellowship_daily_post" => &FELLOWSHIP_DAILY_POST_RUNNING,
        "discipler_reply_worker" => &DISCIPLER_REPLY_WORKER_RUNNING,
        _ => return None,
    })
}

#[cfg(test)]
mod tests {
    use super::guard_for;
    #[test]
    fn known_jobs_have_guards() {
        for n in ["blog_generation", "blog_retry", "blog_publish_scheduled", "subscription_reconcile", "fellowship_daily_post", "discipler_reply_worker"] {
            assert!(guard_for(n).is_some(), "{n}");
        }
        assert!(guard_for("nope").is_none());
    }
}
```
Run `cargo test known_jobs_have_guards` → fails to compile until the statics from Task 4 (and Task 6) exist; after Task 4 add a temporary `pub static DISCIPLER_REPLY_WORKER_RUNNING` (already added in Task 4 Step 3) so it compiles.

- [ ] **Step 2: Job runner helper and refactor the three handlers**

```rust
async fn run_job(name: &str, pool: sqlx::PgPool, config: Config, http: reqwest::Client) {
    let r = match name {
        "blog_generation" => crate::cron::blog_generator::run_blog_generation(&pool, &config, &http).await,
        "blog_retry" => crate::cron::blog_generator::run_blog_retry(&pool, &config, &http).await,
        "blog_publish_scheduled" => crate::models::post::publish_due_scheduled(&pool).await.map(|_| ()),
        "subscription_reconcile" => crate::cron::subscription_reconciler::run_subscription_reconcile(&config, &http).await,
        "fellowship_daily_post" => crate::cron::fellowship_daily_post::run_fellowship_daily_post(&pool, &config, &http).await,
        "discipler_reply_worker" => crate::cron::discipler_reply_worker::run_discipler_reply_worker(&pool, &config, &http).await,
        other => Err(AppError::BadRequest(format!("Unknown cron '{other}'"))),
    };
    if let Err(e) = r { tracing::error!(job = name, "CRON failed: {}", e); }
}
```
`trigger_cron` becomes `Path(name): Path<String>` → `let flag = guard_for(&name).ok_or_else(|| AppError::NotFound(format!("Cron '{name}' not found")))?;` acquire the guard, `tokio::spawn` `run_job(&name, …)` with the guard moved in, respond `{ success: true, message: format!("{name} triggered") }`. Keep the old path working by registering both `/api/v1/admin/cron/trigger` (defaults to `blog_generation`) and `/api/v1/admin/cron/trigger/:name`.

`cron_status`: add `"fellowship_daily_post_running": FELLOWSHIP_DAILY_POST_RUNNING.load(Ordering::SeqCst)` and `"discipler_reply_worker_running": DISCIPLER_REPLY_WORKER_RUNNING.load(Ordering::SeqCst)`, and include them in `is_running`.

`cron_update_schedule` hot-reload closure: replace the whole `match n.as_str() { ... }` with:
```rust
                        let Some(flag) = guard_for(&n) else { tracing::error!(job = %n, "Unknown cron, not rescheduled"); return; };
                        let _guard = match crate::cron::CronGuard::try_acquire(flag) {
                            Some(g) => g,
                            None => { tracing::warn!(job = %n, "CRON skipped: previous run still in progress"); return; }
                        };
                        run_job(&n, p, (*c).clone(), h).await;
```
(`c` is the `Arc<Config>` captured by the closure; `p`/`h` the cloned pool and client.) This also fixes the pre-existing bug where `blog_retry` and `subscription_reconcile` were rescheduled as blog generation.

- [ ] **Step 3: Verify** — `cargo test`, `cargo clippy -- -D warnings`. With the server running and an admin JWT: `curl -X POST localhost:8080/api/v1/admin/cron/trigger/fellowship_daily_post -H "Authorization: Bearer $ADMIN_JWT"` → `{"success":true,...}`; `GET /api/v1/admin/cron/status` shows the two new flags.

- [ ] **Step 4: Commit**

```bash
git add rs-backend/src/routes/admin.rs rs-backend/src/routes/mod.rs
git commit -m "feat(rs-backend): trigger, status, and hot-reload support for all cron jobs"
```

---

### Task 6: `discipler_reply_worker` cron job

**Files:**
- Create: `rs-backend/src/cron/discipler_reply_worker.rs`
- Modify: `rs-backend/src/cron/mod.rs` (registration block; `pub mod` line added in Task 4)

**Interfaces:**
- Consumes: `Config { supabase_url, supabase_anon_key, internal_api_key, supabase_service_role_key }`.
- Produces: `pub async fn run_discipler_reply_worker(pool: &PgPool, config: &Config, http: &Client) -> Result<(), AppError>`.

Behaviour per tick:
1. Claim up to 20 due rows: `UPDATE … SET status='processing' WHERE id IN (SELECT id FROM discipler_reply_queue WHERE status='pending' AND run_after <= now() ORDER BY run_after LIMIT 20 FOR UPDATE SKIP LOCKED) RETURNING id, post_id, comment_id, trigger, attempts`.
2. For question triggers, if a mentor has commented on the post since the row was created, set `skipped_mentor_answered`.
3. Otherwise POST `fellowship-posts/discipler-reply` with `X-Internal-Api-Key`. Non-2xx: if `attempts >= 3` set `failed` else set back to `pending` with `run_after = now() + 2 min`.
4. Discard Discipler drafts older than 7 days (soft delete).
5. On minute 0 (`Utc::now().minute() == 0`), for each fellowship with unpushed activity rows call `notify { kind: 'activity_digest', fellowship_id }`.

- [ ] **Step 1: Write the failing test for the pure backoff rule**

```rust
#[cfg(test)]
mod tests {
    use super::next_status_after_failure;
    #[test]
    fn retries_twice_then_fails() {
        assert_eq!(next_status_after_failure(1), "pending");
        assert_eq!(next_status_after_failure(2), "pending");
        assert_eq!(next_status_after_failure(3), "failed");
        assert_eq!(next_status_after_failure(9), "failed");
    }
}
```

- [ ] **Step 2: Implement**

```rust
//! Drains discipler_reply_queue and flushes hourly activity digests.
use chrono::{Timelike, Utc};
use reqwest::Client;
use sqlx::PgPool;
use uuid::Uuid;

use crate::config::Config;
use crate::error::AppError;

#[derive(Debug, sqlx::FromRow)]
struct QueueRow {
    id: Uuid,
    post_id: Uuid,
    #[allow(dead_code)]
    comment_id: Option<Uuid>,
    trigger: String,
    attempts: i32,
    created_at: chrono::DateTime<Utc>,
}

pub(crate) fn next_status_after_failure(attempts: i32) -> &'static str {
    if attempts >= 3 { "failed" } else { "pending" }
}

async fn claim_due(pool: &PgPool) -> Result<Vec<QueueRow>, AppError> {
    let rows = sqlx::query_as::<_, QueueRow>(
        "UPDATE discipler_reply_queue q SET status = 'processing', updated_at = now()
         WHERE q.id IN (
           SELECT id FROM discipler_reply_queue
           WHERE status = 'pending' AND run_after <= now()
           ORDER BY run_after LIMIT 20 FOR UPDATE SKIP LOCKED)
         RETURNING q.id, q.post_id, q.comment_id, q.trigger, q.attempts, q.created_at",
    )
    .fetch_all(pool)
    .await?;
    Ok(rows)
}

async fn mentor_answered_since(pool: &PgPool, post_id: Uuid, since: chrono::DateTime<Utc>) -> Result<bool, AppError> {
    let (exists,): (bool,) = sqlx::query_as(
        "SELECT EXISTS (
           SELECT 1 FROM fellowship_comments c
           JOIN fellowship_posts p ON p.id = c.post_id
           JOIN fellowship_members m ON m.fellowship_id = p.fellowship_id AND m.user_id = c.author_user_id
           WHERE c.post_id = $1 AND c.is_deleted = false AND c.created_at >= $2
             AND m.role = 'mentor' AND m.is_active = true)",
    )
    .bind(post_id)
    .bind(since)
    .fetch_one(pool)
    .await?;
    Ok(exists)
}

async fn set_status(pool: &PgPool, id: Uuid, status: &str, err: Option<&str>, delay_minutes: i64) -> Result<(), AppError> {
    sqlx::query(
        "UPDATE discipler_reply_queue
         SET status = $2, last_error = $3, updated_at = now(),
             run_after = CASE WHEN $2 = 'pending' THEN now() + ($4 || ' minutes')::interval ELSE run_after END
         WHERE id = $1",
    )
    .bind(id).bind(status).bind(err).bind(delay_minutes.to_string())
    .execute(pool)
    .await?;
    Ok(())
}

async fn call_reply(config: &Config, http: &Client, queue_id: Uuid) -> Result<(), AppError> {
    let url = format!("{}/functions/v1/fellowship-posts/discipler-reply", config.supabase_url);
    let resp = http
        .post(&url)
        .header("apikey", &config.supabase_anon_key)
        .header("X-Internal-Api-Key", &config.internal_api_key)
        .header("Content-Type", "application/json")
        .json(&serde_json::json!({ "queue_id": queue_id }))
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("discipler-reply request failed: {e}")))?;
    let status = resp.status();
    let body = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        return Err(AppError::Internal(format!("discipler-reply returned {status}: {body}")));
    }
    tracing::info!(%queue_id, "discipler-reply: {}", body.chars().take(160).collect::<String>());
    Ok(())
}

async fn discard_stale_drafts(pool: &PgPool) -> Result<u64, AppError> {
    let r = sqlx::query(
        "UPDATE fellowship_comments SET is_deleted = true
         WHERE is_pending_review = true AND is_deleted = false AND created_at < now() - interval '7 days'",
    )
    .execute(pool)
    .await?;
    Ok(r.rows_affected())
}

async fn flush_digests(pool: &PgPool, config: &Config, http: &Client) -> Result<(), AppError> {
    let ids: Vec<(Uuid,)> = sqlx::query_as(
        "SELECT DISTINCT fellowship_id FROM discipler_activity WHERE pushed_at IS NULL",
    )
    .fetch_all(pool)
    .await?;
    for (fellowship_id,) in ids {
        let url = format!("{}/functions/v1/fellowship-posts/notify", config.supabase_url);
        let resp = http
            .post(&url)
            .header("Authorization", format!("Bearer {}", config.supabase_service_role_key))
            .header("apikey", &config.supabase_anon_key)
            .header("Content-Type", "application/json")
            .json(&serde_json::json!({ "kind": "activity_digest", "fellowship_id": fellowship_id }))
            .send()
            .await;
        match resp {
            Ok(r) if r.status().is_success() => tracing::info!(%fellowship_id, "Activity digest sent"),
            Ok(r) => tracing::error!(%fellowship_id, "Digest returned {}", r.status()),
            Err(e) => tracing::error!(%fellowship_id, "Digest request failed: {}", e),
        }
    }
    Ok(())
}

pub async fn run_discipler_reply_worker(pool: &PgPool, config: &Config, http: &Client) -> Result<(), AppError> {
    let rows = claim_due(pool).await?;
    for row in rows {
        let attempts = row.attempts + 1; // discipler-reply increments in the DB; mirror it here for the backoff decision
        if row.trigger == "question" && mentor_answered_since(pool, row.post_id, row.created_at).await? {
            set_status(pool, row.id, "skipped_mentor_answered", None, 0).await?;
            continue;
        }
        if let Err(e) = call_reply(config, http, row.id).await {
            let status = next_status_after_failure(attempts);
            tracing::warn!(queue_id = %row.id, attempts, status, "Reply call failed: {}", e);
            set_status(pool, row.id, status, Some(&e.to_string()), 2).await?;
        }
    }

    let now = Utc::now();
    if now.minute() == 0 {
        match discard_stale_drafts(pool).await {
            Ok(n) if n > 0 => tracing::info!(discarded = n, "Stale Discipler drafts discarded"),
            Ok(_) => {}
            Err(e) => tracing::error!("Discard stale drafts failed: {}", e),
        }
        if let Err(e) = flush_digests(pool, config, http).await {
            tracing::error!("Activity digest flush failed: {}", e);
        }
    }
    Ok(())
}
```
Note: `discipler-reply` itself sets the final `done`/`skipped_*`/`failed`/`pending` status on success responses; the worker only handles transport failures. Rows left in `processing` by a crash are re-claimed by adding `OR (status = 'processing' AND updated_at < now() - interval '10 minutes')` to the `claim_due` WHERE clause.

- [ ] **Step 3: Register in `cron/mod.rs`** — copy the daily block with prefix `worker_`, name `"discipler_reply_worker"`, schedule `schedules::DISCIPLER_REPLY_WORKER`, guard `DISCIPLER_REPLY_WORKER_RUNNING`, body `discipler_reply_worker::run_discipler_reply_worker(&p, &c, &h)`. Because it fires every minute, log at `debug` when there is nothing to do (`tracing::debug!` instead of `info!` in `run_discipler_reply_worker` when `rows` is empty and it is not minute 0).

- [ ] **Step 4: Verify**

`cargo test discipler_reply_worker` → 1 passed; clippy clean. Locally: enable the cron row, post a tagged question as Rahul (Plan 02 Task 5), watch the log: within a minute `discipler-reply: {"success":true,...}` and a Discipler comment appears. Set `discipler_reply_delay_min = 30` and post a question, then comment as Anna within the window → row ends `skipped_mentor_answered`.

- [ ] **Step 5: Commit**

```bash
git add rs-backend/src/cron/discipler_reply_worker.rs rs-backend/src/cron/mod.rs
git commit -m "feat(rs-backend): discipler_reply_worker cron draining the reply queue and hourly digests"
```

---

### Task 7: Startup log and deployment notes

**Files:**
- Modify: `rs-backend/src/cron/mod.rs` tail (~269-275)
- Modify: `rs-backend/README.md` (or `rs-backend/CLAUDE.md`) cron list

- [ ] **Step 1: Log every schedule at startup**

Replace the tail `tracing::info!(schedule = …, retry_schedule = …, "CRON scheduler started")` with one line per registered job: iterate `job_ids.keys()` and the resolved schedule strings, `tracing::info!(job = %name, schedule = %s, "CRON registered")`, then `tracing::info!("CRON scheduler started")`.

- [ ] **Step 2: Document** — add the two jobs to the cron table in the README with their names, schedules, and the env vars they need (`INTERNAL_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY`).

- [ ] **Step 3: Final checks** — `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test` all green.

- [ ] **Step 4: Commit**

```bash
git add rs-backend/src/cron/mod.rs rs-backend/README.md
git commit -m "chore(rs-backend): log all cron registrations and document Discipler jobs"
```

---

## Self-Review Notes

- Spec §3 algorithm steps 1–6: Task 4 (`post_for_fellowship`), Task 3 (queries incl. wrap), Task 2 (format), Task 1 (guide id). Notify goes through `fellowship-posts/notify` (Plan 02 Task 6).
- Spec §2 worker: claim, mentor-answered skip, internal call, 3 attempts, 7-day draft discard, hourly digest: Task 6.
- Admin `cron_update_schedule` catch-all bug: fixed in Task 5 via `guard_for` + `run_job`.
- `fellowship_posts.topic_id` is TEXT; the insert binds `to_string()`. `discipler_daily_posts.topic_id` is UUID.
- `content_formatter::labels_for` is private and unused here on purpose; `open_study_label` is a separate small map.
