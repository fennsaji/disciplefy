// marketing/lib/blog.ts
import { cache } from "react";
import { type Locale } from "@/i18n";

const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

const BLOG_API_URL = process.env.BLOG_API_URL || "http://localhost:8080";

export interface PostMeta {
  slug: string;
  title: string;
  excerpt: string;
  author: string;
  locale: string;
  tags: string[];
  featured: boolean;
  published_at: string | null;
  read_time: number;
}

export interface LearningPathInfo {
  id: string;
  slug: string;
  title: string;
  description: string;
  disciple_level: string;
}

export interface LearningPathMeta {
  slug: string;
  title: string;
  post_count: number;
}

export interface Post extends PostMeta {
  id: string;
  content: string;
  status: string;
  learning_path?: LearningPathInfo | null;
}

export interface Pagination {
  page: number;
  limit: number;
  total: number;
  total_pages: number;
  has_more: boolean;
}

const EMPTY_PAGINATION: Pagination = { page: 1, limit: 10, total: 0, total_pages: 0, has_more: false };

export async function getAllPosts(
  locale: Locale,
  page = 1,
  limit = 10,
  tag?: string,
  learningPath?: string,
): Promise<{ posts: PostMeta[]; pagination: Pagination }> {
  const params = new URLSearchParams({
    locale,
    page: String(page),
    limit: String(limit),
  });
  if (tag) params.set("tag", tag);
  if (learningPath) params.set("learning_path", learningPath);

  const url = `${BLOG_API_URL}/api/v1/posts?${params}`;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch(url, { cache: "no-store" });

      if (!res.ok) {
        if (attempt < 3) { await delay(300 * attempt); continue; }
        return { posts: [], pagination: EMPTY_PAGINATION };
      }

      const json = await res.json();
      return { posts: json.data ?? [], pagination: json.pagination ?? EMPTY_PAGINATION };
    } catch (err) {
      if (attempt < 3) { await delay(300 * attempt); continue; }
      console.error("Failed to fetch posts after retries:", err);
      return { posts: [], pagination: EMPTY_PAGINATION };
    }
  }
  return { posts: [], pagination: EMPTY_PAGINATION };
}

// cache() deduplicates concurrent calls with the same slug within a single request
// (e.g. generateMetadata + page component both call getPost for the same slug).
export const getPost = cache(async function getPost(slug: string): Promise<Post | null> {
  const url = `${BLOG_API_URL}/api/v1/posts/${encodeURIComponent(slug)}`;
  // Retry up to 3 times on transient failures (5xx / network errors).
  // A genuine 404 from the API is returned immediately — no retry needed.
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      // cache: "no-store" is consistent with the page's force-dynamic setting.
      const res = await fetch(url, { cache: "no-store" });

      // Post genuinely doesn't exist → stop immediately, let caller notFound()
      if (res.status === 404) return null;

      // Transient server error → retry (unless last attempt)
      if (!res.ok) {
        if (attempt < 3) { await delay(300 * attempt); continue; }
        return null;
      }

      const json = await res.json();
      return json.data ?? null;
    } catch (err) {
      // Network / timeout error → retry
      if (attempt < 3) { await delay(300 * attempt); continue; }
      console.error("Failed to fetch post after retries:", err);
      return null;
    }
  }
  return null;
});

export async function searchPosts(query: string, locale: Locale): Promise<PostMeta[]> {
  const params = new URLSearchParams({ q: query, locale });
  try {
    const res = await fetch(`${BLOG_API_URL}/api/v1/posts/search?${params}`);
    if (!res.ok) return [];
    const json = await res.json();
    return json.data ?? [];
  } catch (err) {
    console.error("Failed to search posts:", err);
    return [];
  }
}

export interface AdjacentPost {
  slug: string;
  title: string;
}

export interface AdjacentPosts {
  prev: AdjacentPost | null;
  next: AdjacentPost | null;
}

export async function getAdjacentPosts(slug: string): Promise<AdjacentPosts> {
  try {
    const res = await fetch(
      `${BLOG_API_URL}/api/v1/posts/${encodeURIComponent(slug)}/adjacent`,
      { cache: "no-store" },
    );
    if (!res.ok) return { prev: null, next: null };
    const json = await res.json();
    return json.data ?? { prev: null, next: null };
  } catch {
    return { prev: null, next: null };
  }
}

export async function getTags(locale: Locale): Promise<string[]> {
  try {
    const res = await fetch(`${BLOG_API_URL}/api/v1/posts/tags?locale=${locale}`, {
      cache: "no-store",
    });
    if (!res.ok) return [];
    const json = await res.json();
    return json.data ?? [];
  } catch (err) {
    console.error("Failed to fetch tags:", err);
    return [];
  }
}

export async function getLearningPaths(locale: Locale): Promise<LearningPathMeta[]> {
  try {
    const res = await fetch(`${BLOG_API_URL}/api/v1/learning-paths?locale=${locale}`, {
      cache: "no-store",
    });
    if (!res.ok) return [];
    const json = await res.json();
    return json.data ?? [];
  } catch (err) {
    console.error("Failed to fetch learning paths:", err);
    return [];
  }
}
