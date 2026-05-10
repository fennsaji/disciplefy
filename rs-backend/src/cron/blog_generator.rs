use reqwest::Client;
use sqlx::PgPool;
use uuid::Uuid;

use crate::config::Config;
use crate::error::AppError;
use crate::models::post;
use crate::services::{content_formatter, study_api};

const LOCALES: &[&str] = &["en", "hi", "ml"];

#[derive(Debug, Clone, sqlx::FromRow)]
#[allow(dead_code)]
pub struct LearningPathTopic {
    pub id: Uuid,
    /// The recommended_topics.id — used as source_topic_id in blog_posts
    pub topic_id: Uuid,
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

    let slug = format!("{}-{}", slug::slugify(&topic.title), locale);

    let input = post::CreatePostInput {
        title: blog.title,
        content: blog.content,
        excerpt: blog.excerpt,
        locale: locale.to_string(),
        tags: blog.tags,
        featured: false,
        status: "published".to_string(),
        slug: Some(slug.clone()),
        source_type: Some("learning_path_topic".to_string()),
        source_topic_id: Some(topic.topic_id),
        source_learning_path_id: Some(topic.path_id),
        source_guide_id: None,
    };

    match post::create_post_if_not_exists(pool, input).await? {
        Some(p) => tracing::info!(slug = %p.slug, locale, "Blog post created"),
        None => {
            // Slug conflict — tag existing post so topic is marked done
            post::tag_existing_post_source(pool, &slug, topic.topic_id, topic.path_id).await?;
            tracing::info!(locale, slug = %slug, "Slug existed, tagged with source");
        }
    }
    Ok(())
}

/// Retry function -- only retries topics that already have at least one locale generated but are
/// missing others (i.e., a previous run partially failed). Does NOT pick up never-attempted topics.
pub async fn run_blog_retry(pool: &PgPool, config: &Config, http: &Client) -> Result<(), AppError> {
    tracing::info!("Starting blog retry CRON job");

    const MAX_SKIP_ATTEMPTS: usize = 10;

    for attempt in 0..MAX_SKIP_ATTEMPTS {
        let topic = match post::find_next_partially_generated_topic(pool).await? {
            Some(t) => t,
            None => {
                tracing::info!("No partially-generated topics found — nothing to retry");
                return Ok(());
            }
        };

        // Check which locales actually need generation (by slug existence)
        let mut missing_locales: Vec<&str> = Vec::new();
        for locale in LOCALES {
            let slug = format!("{}-{}", slug::slugify(&topic.title), locale);
            if !post::slug_exists(pool, &slug).await? {
                missing_locales.push(locale);
            } else {
                post::tag_existing_post_source(pool, &slug, topic.topic_id, topic.path_id).await?;
            }
        }

        if missing_locales.is_empty() {
            tracing::info!(
                topic = %topic.title,
                attempt,
                "All locale slugs exist (retry), tagged and skipping"
            );
            continue;
        }

        tracing::info!(
            topic = %topic.title,
            missing = ?missing_locales,
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

        return Ok(());
    }

    tracing::warn!("Blog retry: exhausted skip attempts without finding a topic to retry");
    Ok(())
}

/// Main blog generation function -- called by CRON scheduler or manual trigger.
/// Generates posts for ONE topic per run (all missing locales in parallel),
/// picking the next topic that is missing at least one locale.
///
/// Uses a loop to skip topics whose slugs already exist in the DB (even if
/// `source_topic_id` tracking is stale). Tags skipped topics so future runs
/// skip them via the SQL query directly.
pub async fn run_blog_generation(
    pool: &PgPool,
    config: &Config,
    http: &Client,
) -> Result<(), AppError> {
    tracing::info!("Starting blog generation CRON job");

    const MAX_SKIP_ATTEMPTS: usize = 20;

    for attempt in 0..MAX_SKIP_ATTEMPTS {
        // 1. Find the next topic that the SQL query thinks is missing locales
        let topic = match post::find_next_ungenerated_topic(pool).await? {
            Some(t) => t,
            None => {
                tracing::info!(
                    "All topics already have blog posts for all locales — nothing to generate"
                );
                return Ok(());
            }
        };

        // 2. Check which locales actually need generation (by slug existence)
        let mut missing_locales: Vec<&str> = Vec::new();
        for locale in LOCALES {
            let slug = format!("{}-{}", slug::slugify(&topic.title), locale);
            if !post::slug_exists(pool, &slug).await? {
                missing_locales.push(locale);
            } else {
                // Tag existing post so SQL query skips this topic next time
                post::tag_existing_post_source(pool, &slug, topic.topic_id, topic.path_id).await?;
            }
        }

        if missing_locales.is_empty() {
            tracing::info!(
                topic = %topic.title,
                attempt,
                "All locale slugs exist, tagged and skipping to next topic"
            );
            continue;
        }

        // 3. Generate missing locales
        tracing::info!(
            topic = %topic.title,
            missing = ?missing_locales,
            "Generating missing locales in parallel"
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

        return Ok(());
    }

    tracing::warn!(
        "Exhausted {} skip attempts without finding a topic to generate",
        MAX_SKIP_ATTEMPTS
    );
    Ok(())
}
