// marketing/app/sitemap.ts
import type { MetadataRoute } from "next";
import { locales, type Locale } from "@/i18n";
import { getAllPosts } from "@/lib/blog";

const BASE = "https://www.disciplefy.in";

const staticPages = [
  "",
  "/download",
  "/pricing",
  "/about",
  "/blog",
  "/privacy",
  "/terms",
  "/refund",
  "/contact",
  "/features/ai-bible-study",
  "/features/daily-verse",
  "/features/study-guides",
  "/features/fellowship",
  "/features/voice-buddy",
  "/features/memory-verses",
  "/features/learning-paths",
  "/features/follow-up-chat",
  // NOTE: Uncomment /vs/youversion only after Phase 3 authority-building is complete
  // "/vs/youversion",
];

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const entries: MetadataRoute.Sitemap = [];

  for (const page of staticPages) {
    // Build the hreflang map shared by all locale variants of this page
    const languages: Record<string, string> = {};
    for (const loc of locales) {
      const prefix = loc === "en" ? "" : `/${loc}`;
      languages[loc] = `${BASE}${prefix}${page}`;
    }

    for (const locale of locales) {
      const localePrefix = locale === "en" ? "" : `/${locale}`;
      entries.push({
        url: `${BASE}${localePrefix}${page}`,
        lastModified: new Date(),
        changeFrequency: page === "" ? "weekly" : "monthly",
        priority: page === "" ? 1 : 0.8,
        alternates: { languages },
      });
    }
  }

  // Blog posts — only include the canonical locale URL for each post (post.locale)
  // to avoid submitting duplicate-locale URLs for posts that don't have translations.
  const seenSlugs = new Set<string>();
  for (const locale of locales) {
    let page = 1;
    let hasMore = true;
    while (hasMore) {
      const { posts, pagination } = await getAllPosts(locale as Locale, page, 100);
      const prefix = locale === "en" ? "" : `/${locale}`;
      for (const post of posts) {
        const canonicalKey = `${post.locale ?? locale}:${post.slug}`;
        if (seenSlugs.has(canonicalKey)) continue;
        seenSlugs.add(canonicalKey);
        entries.push({
          url: `${BASE}${prefix}/blog/${post.slug}`,
          lastModified: post.published_at ? new Date(post.published_at) : new Date(),
          changeFrequency: "monthly",
          priority: 0.6,
        });
      }
      hasMore = pagination.has_more;
      page++;
    }
  }

  return entries;
}
