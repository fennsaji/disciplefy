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
pub async fn list_daily_fellowships(
    pool: &PgPool,
    today: NaiveDate,
) -> Result<Vec<DailyFellowship>, AppError> {
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
pub async fn find_next_topic_for_fellowship(
    pool: &PgPool,
    fellowship_id: Uuid,
) -> Result<Option<LearningPathTopic>, AppError> {
    let topic = sqlx::query_as::<_, LearningPathTopic>(TOPIC_SELECT)
        .bind(fellowship_id)
        .fetch_optional(pool)
        .await?;
    Ok(topic)
}

/// Wrap the cursor: forget which topics were used so the sequence restarts.
pub async fn reset_topic_cursor(pool: &PgPool, fellowship_id: Uuid) -> Result<(), AppError> {
    sqlx::query(
        "DELETE FROM discipler_daily_posts WHERE fellowship_id = $1 AND post_date < CURRENT_DATE",
    )
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
pub async fn insert_daily_post(
    pool: &PgPool,
    input: DailyPostInsert<'_>,
) -> Result<Uuid, AppError> {
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
