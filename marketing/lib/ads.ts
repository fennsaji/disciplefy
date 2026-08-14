// marketing/lib/ads.ts
// House ad config. Empty by default — the blog ad feature is a no-op until
// an entry is added here by hand. `gradient` follows the same Tailwind
// "from-x to-y" pattern used for post tag accents in BlogPostContent.tsx.

export type AdLocale = "en" | "hi" | "ml";

// title/subtitle are per-locale so the card matches the post's own content
// language (blog content stays in its own locale independent of site chrome
// — see BlogPostContent.tsx's postLocale). Falls back to "en" for any
// locale missing a translation.
export interface HouseAd {
  id: string;
  title: Record<AdLocale, string>;
  subtitle: Record<AdLocale, string>;
  href: string;
  gradient: string;
  /** Overrides the card's badge text (default "Sponsored"). Use for
   * self-promotion — e.g. the Disciplefy house ad — where "Sponsored" would
   * be inaccurate since nothing is actually being paid for. Brand name,
   * not translated. */
  tagLabel?: string;
}

// Temporary self-promo house ad occupying the slot while ChristianAdNet
// publisher signup is pending. Remove once a real advertiser is confirmed,
// or keep alongside it if the slot should rotate between the two.
export const ADS: HouseAd[] = [
  {
    id: "disciplefy-house",
    title: {
      en: "Generate your own study guide",
      hi: "अपनी खुद की अध्ययन गाइड बनाएं",
      ml: "നിങ്ങളുടെ സ്വന്തം പഠന ഗൈഡ് സൃഷ്ടിക്കുക",
    },
    subtitle: {
      en: "Turn any verse or topic into a full Bible study — free, in your language",
      hi: "किसी भी वचन या विषय को अपनी भाषा में एक पूर्ण बाइबल अध्ययन में बदलें — मुफ़्त",
      ml: "ഏതു വാക്യമോ വിഷയമോ നിങ്ങളുടെ ഭാഷയിൽ പൂർണ്ണമായ ബൈബിൾ പഠനമാക്കി മാറ്റുക — സൗജന്യമായി",
    },
    // Marketing's own /download page (lets the reader pick app vs web),
    // not the web app directly.
    href: "/download",
    gradient: "from-indigo-500 to-violet-500",
    tagLabel: "Disciplefy",
  },
];
