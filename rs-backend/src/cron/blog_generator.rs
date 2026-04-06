use reqwest::Client;
use sqlx::PgPool;
use uuid::Uuid;

use crate::config::Config;
use crate::error::AppError;
use crate::models::post;
use crate::services::{content_formatter, study_api};

const LOCALES: &[&str] = &["en", "hi", "ml"];

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct LearningPathTopic {
    pub id: Uuid,
    pub title: String,
    pub description: Option<String>,
    pub input_type: String,
    pub path_id: Uuid,
    pub path_title: String,
    pub path_description: String,
    pub disciple_level: String,
    pub category: Option<String>,
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

/// Generate and save a blog post for a single locale. Returns Ok(()) on success.
async fn generate_for_locale(
    http: &Client,
    config: &Config,
    pool: &PgPool,
    topic: &LearningPathTopic,
    locale: &str,
) -> Result<(), AppError> {
    let display_title: &str = match locale {
        "hi" => topic.hi_title.as_deref().unwrap_or(&topic.title),
        "ml" => topic.ml_title.as_deref().unwrap_or(&topic.title),
        _ => &topic.title,
    };
    let display_description: Option<&str> = match locale {
        "hi" => topic
            .hi_description
            .as_deref()
            .or(topic.description.as_deref()),
        "ml" => topic
            .ml_description
            .as_deref()
            .or(topic.description.as_deref()),
        _ => topic.description.as_deref(),
    };
    let display_path_title: &str = match locale {
        "hi" => topic.hi_path_title.as_deref().unwrap_or(&topic.path_title),
        "ml" => topic.ml_path_title.as_deref().unwrap_or(&topic.path_title),
        _ => &topic.path_title,
    };
    let display_path_description: &str = match locale {
        "hi" => topic
            .hi_path_description
            .as_deref()
            .unwrap_or(&topic.path_description),
        "ml" => topic
            .ml_path_description
            .as_deref()
            .unwrap_or(&topic.path_description),
        _ => &topic.path_description,
    };

    // 'recommended' and 'ask' are interactive modes — fall back to 'standard' for batch generation
    let mode = match topic.study_mode.as_str() {
        "recommended" | "ask" => "standard",
        m => m,
    };

    let guide = study_api::generate_study_guide(
        http,
        config,
        &topic.input_type,
        display_title,
        display_description,
        Some(display_path_title),
        Some(display_path_description),
        Some(&topic.disciple_level),
        locale,
        mode,
    )
    .await?;

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
        source_guide_id: None,
    };

    let p = post::create_post(pool, input).await?;
    tracing::info!(slug = %p.slug, locale, "Blog post created");
    Ok(())
}

/// Retry function -- only retries topics that already have at least one locale generated but are
/// missing others (i.e., a previous run partially failed). Does NOT pick up never-attempted topics.
pub async fn run_blog_retry(pool: &PgPool, config: &Config, http: &Client) -> Result<(), AppError> {
    tracing::info!("Starting blog retry CRON job");

    let topic = match post::find_next_partially_generated_topic(pool).await? {
        Some(t) => t,
        None => {
            tracing::info!("No partially-generated topics found — nothing to retry");
            return Ok(());
        }
    };

    tracing::info!(topic = %topic.title, "Found partially-generated topic, retrying missing locales");

    let already_generated = post::get_generated_locales(pool, topic.id).await?;
    let missing_locales: Vec<&str> = LOCALES
        .iter()
        .copied()
        .filter(|l| !already_generated.contains(&l.to_string()))
        .collect();

    if missing_locales.is_empty() {
        tracing::info!(topic = %topic.title, "All locales already generated, skipping");
        return Ok(());
    }

    tracing::info!(
        topic = %topic.title,
        missing = ?missing_locales,
        already_done = ?already_generated,
        "Retrying missing locales in parallel"
    );

    let mut handles = Vec::with_capacity(missing_locales.len());

    for locale in missing_locales {
        let locale = locale.to_string();
        let http = http.clone();
        let config = config.clone();
        let pool = pool.clone();
        let topic = topic.clone();

        let handle = tokio::spawn(async move {
            let result = generate_for_locale(&http, &config, &pool, &topic, &locale).await;
            (locale, result)
        });
        handles.push(handle);
    }

    let mut generated = 0usize;
    let mut failed = 0usize;

    for handle in handles {
        match handle.await {
            Ok((locale, Ok(()))) => {
                tracing::info!(locale, "Locale retried successfully");
                generated += 1;
            }
            Ok((locale, Err(e))) => {
                tracing::error!(locale, "Retry failed: {}", e);
                failed += 1;
            }
            Err(e) => {
                tracing::error!("Retry task panicked: {}", e);
                failed += 1;
            }
        }
    }

    tracing::info!(
        generated,
        failed,
        topic = %topic.title,
        "Blog retry complete"
    );

    Ok(())
}

/// Main blog generation function -- called by CRON scheduler or manual trigger.
/// Generates posts for ONE topic per run (all missing locales in parallel),
/// picking the next topic that is missing at least one locale.
pub async fn run_blog_generation(
    pool: &PgPool,
    config: &Config,
    http: &Client,
) -> Result<(), AppError> {
    tracing::info!("Starting blog generation CRON job");

    // 1. Find the next topic that is missing at least one locale
    let topic = match post::find_next_ungenerated_topic(pool).await? {
        Some(t) => t,
        None => {
            tracing::info!(
                "All topics already have blog posts for all locales — nothing to generate"
            );
            return Ok(());
        }
    };

    tracing::info!(topic = %topic.title, "Found topic with missing locales");

    // 2. Determine which locales are still missing
    let already_generated = post::get_generated_locales(pool, topic.id).await?;
    let missing_locales: Vec<&str> = LOCALES
        .iter()
        .copied()
        .filter(|l| !already_generated.contains(&l.to_string()))
        .collect();

    if missing_locales.is_empty() {
        tracing::info!(topic = %topic.title, "All locales already generated, skipping");
        return Ok(());
    }

    tracing::info!(
        topic = %topic.title,
        missing = ?missing_locales,
        already_done = ?already_generated,
        "Generating missing locales in parallel"
    );

    // 3. Spawn one task per missing locale and run them in parallel
    let mut handles = Vec::with_capacity(missing_locales.len());

    for locale in missing_locales {
        let locale = locale.to_string();
        let http = http.clone();
        let config = config.clone();
        let pool = pool.clone();
        let topic = topic.clone();

        let handle = tokio::spawn(async move {
            let result = generate_for_locale(&http, &config, &pool, &topic, &locale).await;
            (locale, result)
        });
        handles.push(handle);
    }

    let mut generated = 0usize;
    let mut failed = 0usize;

    for handle in handles {
        match handle.await {
            Ok((locale, Ok(()))) => {
                tracing::info!(locale, "Locale generated successfully");
                generated += 1;
            }
            Ok((locale, Err(e))) => {
                tracing::error!(locale, "Study API failed: {}", e);
                failed += 1;
            }
            Err(e) => {
                tracing::error!("Generation task panicked: {}", e);
                failed += 1;
            }
        }
    }

    tracing::info!(
        generated,
        failed,
        topic = %topic.title,
        "Blog generation complete"
    );

    Ok(())
}
