// marketing/app/robots.ts
import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      // ── Primary search engines: full content access, block internals ──────
      {
        userAgent: "Googlebot",
        allow: ["/"],
        disallow: ["/api/", "/_next/", "/*.json$"],
      },
      {
        userAgent: "Bingbot",
        allow: ["/"],
        disallow: ["/api/", "/_next/", "/*.json$"],
      },
      // ── AI training crawlers: block completely ─────────────────────────────
      // These bots scrape content to train large language models.
      // Blocking them protects original Bible study content from
      // being used as training data without consent.
      {
        userAgent: [
          "GPTBot",           // OpenAI GPT training
          "ChatGPT-User",     // OpenAI ChatGPT browsing
          "CCBot",            // Common Crawl (used by many LLMs)
          "Google-Extended",  // Google Gemini training
          "anthropic-ai",     // Anthropic Claude training
          "Claude-Web",       // Claude browsing
          "PerplexityBot",    // Perplexity AI
          "cohere-ai",        // Cohere training
          "Omgilibot",        // Social media AI scraper
          "Applebot-Extended", // Apple AI training
          "Bytespider",       // TikTok/ByteDance AI
          "PetalBot",         // Huawei AI
        ],
        disallow: ["/"],
      },
      // ── Aggressive scrapers: block internals, allow public content ─────────
      {
        userAgent: "AhrefsBot",
        allow: ["/"],
        disallow: ["/api/", "/_next/", "/*.json$"],
        crawlDelay: 10,
      },
      {
        userAgent: "SemrushBot",
        allow: ["/"],
        disallow: ["/api/", "/_next/", "/*.json$"],
        crawlDelay: 10,
      },
      // ── All other bots: allow public content, block non-essential routes ───
      {
        userAgent: "*",
        allow: ["/"],
        disallow: [
          "/api/",      // Backend API routes — not for indexing
          "/_next/",    // Next.js build assets
          // NOTE: /og (OG image generator) is intentionally crawlable so Google can
          // fetch og:image / structured-data images for rich results.
          "/*.json$",   // i18n message files
        ],
      },
    ],
    sitemap: "https://www.disciplefy.in/sitemap.xml",
  };
}
