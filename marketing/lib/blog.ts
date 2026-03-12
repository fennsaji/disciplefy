// marketing/lib/blog.ts
import { type Locale } from "@/i18n";

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

export interface Post extends PostMeta {
  id: string;
  content: string;
  status: string;
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
): Promise<{ posts: PostMeta[]; pagination: Pagination }> {
  const params = new URLSearchParams({
    locale,
    page: String(page),
    limit: String(limit),
  });
  if (tag) params.set("tag", tag);

  try {
    const res = await fetch(`${BLOG_API_URL}/api/v1/posts?${params}`, {
      next: { revalidate: 300 },
    });

    if (!res.ok) return { posts: [], pagination: EMPTY_PAGINATION };

    const json = await res.json();
    return { posts: json.data ?? [], pagination: json.pagination ?? EMPTY_PAGINATION };
  } catch (err) {
    console.error("Failed to fetch posts:", err);
    return { posts: [], pagination: EMPTY_PAGINATION };
  }
}

export async function getPost(slug: string): Promise<Post | null> {
  try {
    const res = await fetch(`${BLOG_API_URL}/api/v1/posts/${encodeURIComponent(slug)}`, {
      next: { revalidate: 3600 },
    });

    if (!res.ok) return null;
    const json = await res.json();
    return json.data ?? null;
  } catch (err) {
    console.error("Failed to fetch post:", err);
    return null;
  }
}

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

export async function getTags(locale: Locale): Promise<string[]> {
  try {
    const res = await fetch(`${BLOG_API_URL}/api/v1/posts/tags?locale=${locale}`, {
      next: { revalidate: 300 },
    });
    if (!res.ok) return [];
    const json = await res.json();
    return json.data ?? [];
  } catch (err) {
    console.error("Failed to fetch tags:", err);
    return [];
  }
}
