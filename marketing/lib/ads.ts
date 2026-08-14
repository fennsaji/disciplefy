// marketing/lib/ads.ts
// House ad config. Empty by default — the blog ad feature is a no-op until
// an entry is added here by hand. `gradient` follows the same Tailwind
// "from-x to-y" pattern used for post tag accents in BlogPostContent.tsx.
import { WEB_APP_URL } from "@/lib/app-links";

export interface HouseAd {
  id: string;
  title: string;
  subtitle: string;
  href: string;
  gradient: string;
  /** Overrides the card's badge text (default "Sponsored"). Use for
   * self-promotion — e.g. the Disciplefy house ad — where "Sponsored" would
   * be inaccurate since nothing is actually being paid for. */
  tagLabel?: string;
}

// Temporary self-promo house ad occupying the slot while ChristianAdNet
// publisher signup is pending. Remove once a real advertiser is confirmed,
// or keep alongside it if the slot should rotate between the two.
export const ADS: HouseAd[] = [
  {
    id: "disciplefy-house",
    title: "Generate your own study guide",
    subtitle: "Turn any verse or topic into a full Bible study — free, in your language",
    href: WEB_APP_URL,
    gradient: "from-indigo-500 to-violet-500",
    tagLabel: "Disciplefy",
  },
];
