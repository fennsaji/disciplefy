// marketing/lib/seo.ts
import { locales } from "@/i18n";

const BASE = "https://disciplefy.in";

/** Returns alternates.languages metadata for all locales for a given path */
export function getAlternates(path: string) {
  const languages: Record<string, string> = {};
  for (const locale of locales) {
    const prefix = locale === "en" ? "" : `/${locale}`;
    languages[locale] = `${BASE}${prefix}${path}`;
  }
  languages["x-default"] = `${BASE}${path}`;
  return { canonical: `${BASE}${path}`, languages };
}

/** JSON-LD for the homepage — SoftwareApplication + MobileApplication + Organization */
export const homepageJsonLd = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "SoftwareApplication",
      name: "Disciplefy",
      applicationCategory: "LifestyleApplication",
      operatingSystem: "iOS, Android, Web",
      description: "AI-powered Bible study app in English, Hindi, and Malayalam for Indian Christians.",
      offers: { "@type": "Offer", price: "0", priceCurrency: "INR" },
      url: BASE,
    },
    {
      "@type": "MobileApplication",
      name: "Disciplefy",
      operatingSystem: "Android",
      applicationCategory: "LifestyleApplication",
      description: "AI-powered Bible study app in English, Hindi, and Malayalam for Indian Christians.",
      installUrl: "https://play.google.com/store/apps/details?id=com.disciplefy.bible_study",
      offers: { "@type": "Offer", price: "0", priceCurrency: "INR" },
      url: BASE,
    },
    {
      "@type": "Organization",
      name: "Disciplefy",
      url: BASE,
      logo: `${BASE}/images/logo.png`,
      contactPoint: { "@type": "ContactPoint", email: "hello@disciplefy.in" },
    },
  ],
};

/** JSON-LD for the pricing page — FAQPage */
export const pricingJsonLd = {
  "@context": "https://schema.org",
  "@type": "FAQPage",
  mainEntity: [
    { "@type": "Question", name: "What is a token?", acceptedAnswer: { "@type": "Answer", text: "Tokens are the currency for AI features in Disciplefy. Each study guide, follow-up, or AI Discipler call uses a small number of tokens." } },
    { "@type": "Question", name: "Can I switch plans?", acceptedAnswer: { "@type": "Answer", text: "Yes, you can upgrade or downgrade at any time. Changes take effect at the start of your next billing cycle." } },
    { "@type": "Question", name: "What languages are supported?", acceptedAnswer: { "@type": "Answer", text: "English, Hindi, and Malayalam. All AI features work in all three languages." } },
  ],
};

const LOCALE_LANG: Record<string, string> = { en: "en-IN", hi: "hi-IN", ml: "ml-IN" };

/** JSON-LD for blog posts — BlogPosting */
export function getBlogPostingJsonLd(
  post: { title: string; excerpt: string; published_at: string | null; author: string; slug: string; tags?: string[] },
  locale: string = "en"
) {
  const prefix = locale === "en" ? "" : `/${locale}`;
  const url = `${BASE}${prefix}/blog/${post.slug}`;
  return {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    headline: post.title,
    description: post.excerpt,
    datePublished: post.published_at,
    dateModified: post.published_at,
    inLanguage: LOCALE_LANG[locale] ?? "en-IN",
    keywords: post.tags?.join(", "),
    url,
    mainEntityOfPage: { "@type": "WebPage", "@id": url },
    author: { "@type": "Organization", name: "Disciplefy", url: BASE },
    publisher: {
      "@type": "Organization",
      name: "Disciplefy",
      url: BASE,
      logo: { "@type": "ImageObject", url: `${BASE}/images/logo.png` },
    },
    image: {
      "@type": "ImageObject",
      url: `${BASE}/og?title=${encodeURIComponent(post.title)}&subtitle=Disciplefy+Blog`,
      width: 1200,
      height: 630,
    },
  };
}

/** JSON-LD BreadcrumbList for blog posts */
export function getBreadcrumbJsonLd(
  post: { title: string; slug: string },
  locale: string = "en"
) {
  const prefix = locale === "en" ? "" : `/${locale}`;
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      { "@type": "ListItem", position: 1, name: "Home", item: BASE },
      { "@type": "ListItem", position: 2, name: "Blog", item: `${BASE}${prefix}/blog` },
      { "@type": "ListItem", position: 3, name: post.title, item: `${BASE}${prefix}/blog/${post.slug}` },
    ],
  };
}

/** JSON-LD for /download page — MobileApplication + FAQPage */
export const downloadPageJsonLd = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "MobileApplication",
      name: "Disciplefy",
      operatingSystem: "Android",
      applicationCategory: "LifestyleApplication",
      description: "AI-powered Bible study app in English, Hindi, and Malayalam for Indian Christians.",
      installUrl: "https://play.google.com/store/apps/details?id=com.disciplefy.bible_study",
      offers: { "@type": "Offer", price: "0", priceCurrency: "INR" },
      url: BASE,
    },
    {
      "@type": "FAQPage",
      mainEntity: [
        {
          "@type": "Question",
          name: "Is Disciplefy free?",
          acceptedAnswer: { "@type": "Answer", text: "Yes — the core app is completely free. Premium plans with more AI tokens are available." },
        },
        {
          "@type": "Question",
          name: "What languages does Disciplefy support?",
          acceptedAnswer: { "@type": "Answer", text: "English, Hindi, and Malayalam." },
        },
        {
          "@type": "Question",
          name: "Is there an iOS app?",
          acceptedAnswer: { "@type": "Answer", text: "Not yet. Android and web app are available. iOS is coming soon." },
        },
        {
          "@type": "Question",
          name: "How does the AI Bible study work?",
          acceptedAnswer: { "@type": "Answer", text: "Enter a Bible verse or question; Disciplefy generates a complete study guide in your language." },
        },
      ],
    },
  ],
};
