use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::AppError;

// ── Row types ──────────────────────────────────────────────

#[derive(Debug, sqlx::FromRow, Serialize)]
pub struct BlogPost {
    pub id: Uuid,
    pub slug: String,
    pub title: String,
    pub excerpt: String,
    pub content: String,
    pub author: String,
    pub locale: String,
    pub tags: Vec<String>,
    pub featured: bool,
    pub status: String,
    pub source_type: Option<String>,
    pub source_topic_id: Option<Uuid>,
    pub source_learning_path_id: Option<Uuid>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub published_at: Option<DateTime<Utc>>,
}

#[derive(Debug, sqlx::FromRow, Serialize)]
pub struct BlogPostMeta {
    pub slug: String,
    pub title: String,
    pub excerpt: String,
    pub author: String,
    pub locale: String,
    pub tags: Vec<String>,
    pub featured: bool,
    pub published_at: Option<DateTime<Utc>>,
    pub word_count: i64,
}

// ── Input types ────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct CreatePostInput {
    pub title: String,
    pub content: String,
    #[serde(default)]
    pub excerpt: String,
    pub locale: String,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub featured: bool,
    #[serde(default = "default_status")]
    pub status: String,
    pub slug: Option<String>,
    pub source_type: Option<String>,
    pub source_topic_id: Option<Uuid>,
    pub source_learning_path_id: Option<Uuid>,
}

fn default_status() -> String {
    "draft".to_string()
}

#[derive(Debug, Deserialize)]
pub struct UpdatePostInput {
    pub title: Option<String>,
    pub content: Option<String>,
    pub excerpt: Option<String>,
    pub tags: Option<Vec<String>>,
    pub featured: Option<bool>,
    pub status: Option<String>,
}

// ── Pagination ─────────────────────────────────────────────

#[derive(Debug, Serialize)]
pub struct PaginatedPosts {
    pub posts: Vec<PostListItem>,
    pub pagination: Pagination,
}

#[derive(Debug, Serialize)]
pub struct PostListItem {
    pub slug: String,
    pub title: String,
    pub excerpt: String,
    pub author: String,
    pub locale: String,
    pub tags: Vec<String>,
    pub featured: bool,
    pub published_at: Option<DateTime<Utc>>,
    pub read_time: i32,
}

#[derive(Debug, Serialize)]
pub struct Pagination {
    pub page: i64,
    pub limit: i64,
    pub total: i64,
    pub total_pages: i64,
    pub has_more: bool,
}

// ── Query parameters ───────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct ListPostsQuery {
    pub locale: String,
    #[serde(default = "default_page")]
    pub page: i64,
    #[serde(default = "default_limit")]
    pub limit: i64,
    pub tag: Option<String>,
    pub featured: Option<bool>,
}

fn default_page() -> i64 {
    1
}
fn default_limit() -> i64 {
    10
}

#[derive(Debug, Deserialize)]
pub struct SearchQuery {
    pub q: String,
    #[serde(default = "default_locale")]
    pub locale: String,
    #[serde(default = "default_page")]
    pub page: i64,
    #[serde(default = "default_limit")]
    pub limit: i64,
}

fn default_locale() -> String {
    "en".to_string()
}

// ── Database functions ─────────────────────────────────────

fn compute_read_time(word_count: i64) -> i32 {
    ((word_count as f64 / 200.0).ceil() as i32).max(1)
}

fn to_list_item(meta: BlogPostMeta) -> PostListItem {
    PostListItem {
        slug: meta.slug,
        title: meta.title,
        excerpt: meta.excerpt,
        author: meta.author,
        locale: meta.locale,
        tags: meta.tags,
        featured: meta.featured,
        published_at: meta.published_at,
        read_time: compute_read_time(meta.word_count),
    }
}

pub async fn list_posts(pool: &PgPool, q: &ListPostsQuery) -> Result<PaginatedPosts, AppError> {
    let limit = q.limit.clamp(1, 50);
    let offset = (q.page.max(1) - 1) * limit;

    let total: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM blog_posts WHERE locale = $1 AND status = 'published'
         AND ($2::text IS NULL OR $2 = ANY(tags))
         AND ($3::bool IS NULL OR featured = $3)",
    )
    .bind(&q.locale)
    .bind(&q.tag)
    .bind(q.featured)
    .fetch_one(pool)
    .await?;

    let rows = sqlx::query_as::<_, BlogPostMeta>(
        "SELECT slug, title, excerpt, author, locale, tags, featured, published_at,
                array_length(regexp_split_to_array(content, '\\s+'), 1)::bigint AS word_count
         FROM blog_posts
         WHERE locale = $1 AND status = 'published'
           AND ($2::text IS NULL OR $2 = ANY(tags))
           AND ($3::bool IS NULL OR featured = $3)
         ORDER BY published_at DESC NULLS LAST
         LIMIT $4 OFFSET $5",
    )
    .bind(&q.locale)
    .bind(&q.tag)
    .bind(q.featured)
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await?;

    let total_pages = if limit > 0 {
        (total as f64 / limit as f64).ceil() as i64
    } else {
        0
    };

    Ok(PaginatedPosts {
        posts: rows.into_iter().map(to_list_item).collect(),
        pagination: Pagination {
            page: q.page.max(1),
            limit,
            total,
            total_pages,
            has_more: q.page.max(1) < total_pages,
        },
    })
}

pub async fn get_post_by_slug(pool: &PgPool, slug: &str) -> Result<BlogPost, AppError> {
    sqlx::query_as::<_, BlogPost>(
        "SELECT * FROM blog_posts WHERE slug = $1 AND status = 'published'",
    )
    .bind(slug)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Post '{}' not found", slug)))
}

pub async fn get_tags(pool: &PgPool, locale: &str) -> Result<Vec<String>, AppError> {
    let tags: Vec<String> = sqlx::query_scalar(
        "SELECT DISTINCT unnest(tags) AS tag FROM blog_posts
         WHERE locale = $1 AND status = 'published' ORDER BY tag",
    )
    .bind(locale)
    .fetch_all(pool)
    .await?;
    Ok(tags)
}

pub async fn search_posts(pool: &PgPool, q: &SearchQuery) -> Result<PaginatedPosts, AppError> {
    let limit = q.limit.clamp(1, 50);
    let offset = (q.page.max(1) - 1) * limit;

    let total: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM blog_posts
         WHERE locale = $1 AND status = 'published'
           AND to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(excerpt,'') || ' ' || coalesce(content,''))
               @@ plainto_tsquery('simple', $2)"
    )
    .bind(&q.locale)
    .bind(&q.q)
    .fetch_one(pool)
    .await?;

    let rows = sqlx::query_as::<_, BlogPostMeta>(
        "SELECT slug, title, excerpt, author, locale, tags, featured, published_at,
                array_length(regexp_split_to_array(content, '\\s+'), 1)::bigint AS word_count
         FROM blog_posts
         WHERE locale = $1 AND status = 'published'
           AND to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(excerpt,'') || ' ' || coalesce(content,''))
               @@ plainto_tsquery('simple', $2)
         ORDER BY ts_rank(
           to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(excerpt,'') || ' ' || coalesce(content,'')),
           plainto_tsquery('simple', $2)
         ) DESC
         LIMIT $3 OFFSET $4"
    )
    .bind(&q.locale)
    .bind(&q.q)
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await?;

    let total_pages = if limit > 0 {
        (total as f64 / limit as f64).ceil() as i64
    } else {
        0
    };

    Ok(PaginatedPosts {
        posts: rows.into_iter().map(to_list_item).collect(),
        pagination: Pagination {
            page: q.page.max(1),
            limit,
            total,
            total_pages,
            has_more: q.page.max(1) < total_pages,
        },
    })
}

fn validate_create_input(input: &CreatePostInput) -> Result<(), AppError> {
    if input.title.trim().is_empty() {
        return Err(AppError::BadRequest("title is required".to_string()));
    }
    if input.title.len() > 500 {
        return Err(AppError::BadRequest(
            "title must be under 500 characters".to_string(),
        ));
    }
    if input.content.trim().is_empty() {
        return Err(AppError::BadRequest("content is required".to_string()));
    }
    let valid_locales = ["en", "hi", "ml"];
    if !valid_locales.contains(&input.locale.as_str()) {
        return Err(AppError::BadRequest(
            "locale must be one of: en, hi, ml".to_string(),
        ));
    }
    let valid_statuses = ["draft", "published"];
    if !valid_statuses.contains(&input.status.as_str()) {
        return Err(AppError::BadRequest(
            "status must be 'draft' or 'published'".to_string(),
        ));
    }
    if input.tags.len() > 20 {
        return Err(AppError::BadRequest("maximum 20 tags allowed".to_string()));
    }
    Ok(())
}

pub async fn create_post(pool: &PgPool, input: CreatePostInput) -> Result<BlogPost, AppError> {
    validate_create_input(&input)?;

    let slug = input.slug.unwrap_or_else(|| {
        let base = slug::slugify(&input.title);
        format!("{}-{}", base, &input.locale)
    });

    let published_at = if input.status == "published" {
        Some(Utc::now())
    } else {
        None
    };

    let post = sqlx::query_as::<_, BlogPost>(
        "INSERT INTO blog_posts (slug, title, excerpt, content, locale, tags, featured, status,
                                 source_type, source_topic_id, source_learning_path_id, published_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
         RETURNING *"
    )
    .bind(&slug)
    .bind(&input.title)
    .bind(&input.excerpt)
    .bind(&input.content)
    .bind(&input.locale)
    .bind(&input.tags)
    .bind(input.featured)
    .bind(&input.status)
    .bind(&input.source_type)
    .bind(input.source_topic_id)
    .bind(input.source_learning_path_id)
    .bind(published_at)
    .fetch_one(pool)
    .await?;

    Ok(post)
}

pub async fn update_post(
    pool: &PgPool,
    id: Uuid,
    input: UpdatePostInput,
) -> Result<BlogPost, AppError> {
    let post = sqlx::query_as::<_, BlogPost>(
        "UPDATE blog_posts SET
           title = COALESCE($2, title),
           content = COALESCE($3, content),
           excerpt = COALESCE($4, excerpt),
           tags = COALESCE($5, tags),
           featured = COALESCE($6, featured),
           status = COALESCE($7, status)
         WHERE id = $1
         RETURNING *",
    )
    .bind(id)
    .bind(input.title)
    .bind(input.content)
    .bind(input.excerpt)
    .bind(input.tags.as_deref())
    .bind(input.featured)
    .bind(input.status)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Post not found".to_string()))?;

    Ok(post)
}

pub async fn delete_post(pool: &PgPool, id: Uuid) -> Result<(), AppError> {
    let result = sqlx::query("DELETE FROM blog_posts WHERE id = $1")
        .bind(id)
        .execute(pool)
        .await?;

    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("Post not found".to_string()));
    }
    Ok(())
}

pub async fn publish_post(pool: &PgPool, id: Uuid) -> Result<BlogPost, AppError> {
    sqlx::query_as::<_, BlogPost>(
        "UPDATE blog_posts SET status = 'published', published_at = COALESCE(published_at, now())
         WHERE id = $1 RETURNING *",
    )
    .bind(id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Post not found".to_string()))
}

pub async fn unpublish_post(pool: &PgPool, id: Uuid) -> Result<BlogPost, AppError> {
    sqlx::query_as::<_, BlogPost>(
        "UPDATE blog_posts SET status = 'draft' WHERE id = $1 RETURNING *",
    )
    .bind(id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Post not found".to_string()))
}

pub async fn post_exists_for_topic(
    pool: &PgPool,
    topic_id: Uuid,
    locale: &str,
) -> Result<bool, AppError> {
    let exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM blog_posts WHERE source_topic_id = $1 AND locale = $2)",
    )
    .bind(topic_id)
    .bind(locale)
    .fetch_one(pool)
    .await?;
    Ok(exists)
}
