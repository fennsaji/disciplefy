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
pub struct LearningPathTopic {
    id: Uuid,
    title: String,
    description: Option<String>,
    input_type: String,
    path_id: Uuid,
    path_title: String,
    path_description: String,
    disciple_level: String,
    category: Option<String>,
    // Localized fields from recommended_topics_translations
    hi_title: Option<String>,
    ml_title: Option<String>,
    hi_description: Option<String>,
    ml_description: Option<String>,
    // Localized fields from learning_path_translations
    hi_path_title: Option<String>,
    ml_path_title: Option<String>,
    hi_path_description: Option<String>,
    ml_path_description: Option<String>,
}

/// Main blog generation function -- called by CRON scheduler or manual trigger.
/// Generates posts for ONE topic per run (all 3 locales), picking the next ungenerated topic.
pub async fn run_blog_generation(
    pool: &PgPool,
    config: &Config,
    http: &Client,
) -> Result<(), AppError> {
    tracing::info!("Starting blog generation CRON job");

    // 1. Find the next topic that has no posts in any locale yet
    let topic = match post::find_next_ungenerated_topic(pool).await? {
        Some(t) => t,
        None => {
            tracing::info!("All topics already have blog posts — nothing to generate");
            return Ok(());
        }
    };

    tracing::info!(topic = %topic.title, "Generating blog post for today's topic");

    let mut generated = 0;
    let mut failed = 0;

    // 2. Generate all 3 locales for this one topic
    for locale in LOCALES {
        tracing::info!(topic = %topic.title, locale, "Generating blog post");

        // Pick localized fields; fall back to English for unknown locales
        let display_title: &str = match *locale {
            "hi" => topic.hi_title.as_deref().unwrap_or(&topic.title),
            "ml" => topic.ml_title.as_deref().unwrap_or(&topic.title),
            _ => &topic.title,
        };
        let display_description: Option<&str> = match *locale {
            "hi" => topic.hi_description.as_deref().or(topic.description.as_deref()),
            "ml" => topic.ml_description.as_deref().or(topic.description.as_deref()),
            _ => topic.description.as_deref(),
        };
        let display_path_title: &str = match *locale {
            "hi" => topic.hi_path_title.as_deref().unwrap_or(&topic.path_title),
            "ml" => topic.ml_path_title.as_deref().unwrap_or(&topic.path_title),
            _ => &topic.path_title,
        };
        let display_path_description: &str = match *locale {
            "hi" => topic.hi_path_description.as_deref().unwrap_or(&topic.path_description),
            "ml" => topic.ml_path_description.as_deref().unwrap_or(&topic.path_description),
            _ => &topic.path_description,
        };

        let guide = match study_api::generate_study_guide(
            http,
            config,
            &topic.input_type,
            display_title,
            display_description,
            Some(display_path_title),
            Some(display_path_description),
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

        let blog = content_formatter::format_blog_post(
            display_title,
            &guide,
            topic.category.as_deref().unwrap_or(""),
            &topic.disciple_level,
            locale,
        );

        // Always derive the slug from the English title so it stays URL-friendly
        let slug = format!("{}-{}", slug::slugify(&topic.title), locale);

        let input = post::CreatePostInput {
            title: blog.title,
            content: blog.content,
            excerpt: blog.excerpt,
            locale: locale.to_string(),
            tags: blog.tags,
            featured: false,
            status: "published".to_string(),
            slug: Some(slug),
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

        tokio::time::sleep(std::time::Duration::from_secs(DELAY_BETWEEN_CALLS_SECS)).await;
    }

    tracing::info!(generated, failed, topic = %topic.title, "Blog generation complete");
    Ok(())
}
