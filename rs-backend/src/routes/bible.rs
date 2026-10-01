//! Public, read-only Bible text API. No auth: the texts are public domain or
//! CC BY-SA, and every passage response carries its attribution line.

use std::collections::HashMap;

use axum::extract::{Path, Query};
use axum::http::header;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde_json::{json, Value};

use crate::error::AppError;
use crate::models::bible::{self, TranslationInfo, VerseQuery};

/// The text never changes between deploys, so clients and proxies may cache it.
const CACHE_CONTROL: &str = "public, max-age=86400, stale-while-revalidate=604800";

fn cached(body: Value) -> Response {
    ([(header::CACHE_CONTROL, CACHE_CONTROL)], Json(body)).into_response()
}

fn version_json(t: &TranslationInfo) -> Value {
    json!({
        "id": t.id,
        "name": t.name,
        "abbreviation": t.abbreviation,
        "language": t.language,
        "attribution": t.attribution,
        "license": t.license,
        "license_url": t.license_url,
        "source_url": t.source_url,
    })
}

pub async fn list_versions() -> Response {
    let versions: Vec<Value> = bible::TRANSLATIONS.iter().map(version_json).collect();
    cached(json!({ "success": true, "data": versions }))
}

pub async fn list_books(Path(version): Path<String>) -> Result<Response, AppError> {
    let tr = bible::translation(&version)?;
    let books: Vec<Value> = tr
        .books
        .iter()
        .map(|b| json!({ "id": b.code, "name": b.name, "chapters": b.chapters.len() }))
        .collect();
    Ok(cached(json!({
        "success": true,
        "data": { "version": version_json(tr.info), "books": books }
    })))
}

pub async fn get_verses(
    Path(version): Path<String>,
    Query(params): Query<HashMap<String, String>>,
) -> Result<Response, AppError> {
    let tr = bible::translation(&version)?;
    let get = |k: &str| bible::positive_int(k, params.get(k).map(String::as_str));
    let book = params
        .get("book")
        .map(|b| b.trim().to_string())
        .filter(|b| !b.is_empty() && b.len() <= 3 && b.chars().all(|c| c.is_ascii_alphanumeric()))
        .ok_or_else(|| AppError::BadRequest("'book' must be a USFM book code, e.g. JHN".into()))?;
    let query = VerseQuery {
        book,
        chapter: get("chapter")?
            .ok_or_else(|| AppError::BadRequest("'chapter' is required".into()))?,
        verse_start: get("verse_start")?,
        verse_end: get("verse_end")?,
        end_chapter: get("end_chapter")?,
    };
    let p = bible::passage(tr, &query)?;
    let text = p.verses.iter().map(|v| v.text).collect::<Vec<_>>().join(" ");
    Ok(cached(json!({
        "success": true,
        "data": {
            "version": version_json(tr.info),
            "book": p.book,
            "book_name": p.book_name,
            "reference": p.reference,
            "verses": p.verses,
            "text": text,
            "attribution": tr.info.attribution,
        }
    })))
}
