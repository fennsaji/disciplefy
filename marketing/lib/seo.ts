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
  return { canonical: `${BASE}${path}`, languages };
}

/** JSON-LD for the homepage — SoftwareApplication + Organization */
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

/** JSON-LD for blog posts — BlogPosting */
export function getBlogPostingJsonLd(
  post: { title: string; excerpt: string; published_at: string | null; author: string; slug: string },
  locale: string = "en"
) {
  const prefix = locale === "en" ? "" : `/${locale}`;
  return {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    headline: post.title,
    description: post.excerpt,
    datePublished: post.published_at,
    author: { "@type": "Organization", name: post.author },
    url: `${BASE}${prefix}/blog/${post.slug}`,
  };
}
