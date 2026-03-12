use reqwest::Client;
use sqlx::PgPool;
use uuid::Uuid;

use crate::config::Config;
use crate::error::AppError;
use crate::models::post;
use crate::services::{content_formatter, study_api};

const LOCALES: &[&str] = &["en", "hi", "ml"];
const DELAY_BETWEEN_CALLS_SECS: u64 = 5;

#[derive(Debug, sqlx::FromRow)]
struct LearningPathTopic {
    id: Uuid,
    title: String,
    description: Option<String>,
    input_type: String,
    path_id: Uuid,
    path_title: String,
    path_description: String,
    disciple_level: String,
    category: Option<String>,
}

/// Main blog generation function -- called by CRON scheduler or manual trigger.
pub async fn run_blog_generation(
    pool: &PgPool,
    config: &Config,
    http: &Client,
) -> Result<(), AppError> {
    tracing::info!("Starting blog generation CRON job");

    // 1. Fetch all active learning path topics
    let topics = sqlx::query_as::<_, LearningPathTopic>(
        "SELECT lpt.id, lpt.title, lpt.description, lpt.input_type,
                lp.id AS path_id, lp.title AS path_title, lp.description AS path_description,
                lp.disciple_level, lp.category
         FROM learning_path_topics lpt
         JOIN learning_paths lp ON lpt.learning_path_id = lp.id
         WHERE lp.is_active = true
         ORDER BY lp.display_order, lpt.position",
    )
    .fetch_all(pool)
    .await?;

    tracing::info!(topic_count = topics.len(), "Fetched learning path topics");

    let mut generated = 0;
    let mut skipped = 0;
    let mut failed = 0;

    for topic in &topics {
        for locale in LOCALES {
            // 2. Check if post already exists
            match post::post_exists_for_topic(pool, topic.id, locale).await {
                Ok(true) => {
                    skipped += 1;
                    continue;
                }
                Ok(false) => {}
                Err(e) => {
                    tracing::error!(topic_id = %topic.id, locale, "Existence check failed: {}", e);
                    failed += 1;
                    continue;
                }
            }

            tracing::info!(
                topic = %topic.title,
                locale,
                "Generating blog post"
            );

            // 3. Call study-generate-v2
            let guide = match study_api::generate_study_guide(
                http,
                config,
                &topic.input_type,
                &topic.title,
                topic.description.as_deref(),
                Some(&topic.path_title),
                Some(&topic.path_description),
                Some(&topic.disciple_level),
                locale,
            )
            .await
            {
                Ok(g) => g,
                Err(e) => {
                    tracing::error!(topic = %topic.title, locale, "Study API failed: {}", e);
                    failed += 1;
                    tokio::time::sleep(std::time::Duration::from_secs(DELAY_BETWEEN_CALLS_SECS))
                        .await;
                    continue;
                }
            };

            // 4. Format into blog post
            let blog = content_formatter::format_blog_post(
                &topic.title,
                &guide,
                topic.category.as_deref().unwrap_or(""),
                &topic.disciple_level,
            );

            // 5. Insert into DB
            let input = post::CreatePostInput {
                title: blog.title,
                content: blog.content,
                excerpt: blog.excerpt,
                locale: locale.to_string(),
                tags: blog.tags,
                featured: false,
                status: "published".to_string(),
                slug: None,
                source_type: Some("learning_path_topic".to_string()),
                source_topic_id: Some(topic.id),
                source_learning_path_id: Some(topic.path_id),
            };

            match post::create_post(pool, input).await {
                Ok(p) => {
                    tracing::info!(slug = %p.slug, locale, "Blog post created");
                    generated += 1;
                }
                Err(e) => {
                    tracing::error!(topic = %topic.title, locale, "Insert failed: {}", e);
                    failed += 1;
                }
            }

            // Rate limit
            tokio::time::sleep(std::time::Duration::from_secs(DELAY_BETWEEN_CALLS_SECS)).await;
        }
    }

    tracing::info!(generated, skipped, failed, "Blog generation complete");
    Ok(())
}
