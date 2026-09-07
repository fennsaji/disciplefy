import { APP_LINKS_URL } from "@/lib/app-links";
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
  /** Contextual headline used when the post has a usable tag. `{topic}` is
   * replaced with it. Falls back to `title` when the post has no tag, so a
   * post without tags never renders a dangling template. */
  titleWithTopic?: Record<AdLocale, string>;
  subtitle: Record<AdLocale, string>;
  /** Text of the action affordance. Without one the card reads as a note
   * rather than something to open. */
  ctaLabel: Record<AdLocale, string>;
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
    // Generic headline, used when the post carries no tag to hook onto.
    title: {
      en: "Study any passage deeper",
      hi: "किसी भी अंश का गहरा अध्ययन करें",
      ml: "ഏതു ഭാഗവും ആഴത്തിൽ പഠിക്കാം",
    },
    // Contextual headline — continues the thought the reader is already
    // having instead of interrupting with a different one.
    titleWithTopic: {
      en: "Go deeper on {topic}",
      hi: "{topic} पर और गहराई से जानें",
      ml: "{topic} കൂടുതൽ ആഴത്തിൽ പഠിക്കാം",
    },
    // Written to be wanted, not merely believed. The earlier version listed
    // what a guide contains, which reassures a sceptic but gives nobody a
    // reason to tap. This opens on the reader's live question instead.
    //
    // The angle differs by locale on purpose. "Not translated" is noise to an
    // English reader, who was never going to be handed a translation; to a
    // Hindi or Malayalam reader it is the rarest thing on offer, so it leads.
    // Claims verified: "in seconds" matches howItWorks.step2, "keep asking"
    // is the follow-up chat feature, and native generation is real — see
    // backend llm-config/language-configs.ts, where each language has its own
    // instructions, examples and cultural context.
    subtitle: {
      en: "Whatever you're wondering about this verse, ask it. A full study guide in seconds — then keep asking until it clicks. Free.",
      hi: "आख़िरकार, हिन्दी में लिखी गई असली बाइबल स्टडी — अनुवाद नहीं। कुछ ही सेकंड में पूरी गाइड, फिर समझ आने तक सवाल पूछते रहें। मुफ़्त।",
      ml: "ഒടുവിൽ, മലയാളത്തിൽ സ്വാഭാവികമായി തയ്യാറാക്കിയ യഥാർത്ഥ ബൈബിൾ പഠനം — പരിഭാഷയല്ല. നിമിഷങ്ങൾക്കുള്ളിൽ പൂർണ്ണ ഗൈഡ്, പിന്നെ മനസ്സിലാകുന്നത് വരെ ചോദ്യങ്ങൾ ചോദിച്ചുകൊണ്ടിരിക്കാം. സൗജന്യം.",
    },
    ctaLabel: {
      en: "Open free guide",
      hi: "मुफ़्त गाइड खोलें",
      ml: "സൗജന്യ ഗൈഡ് തുറക്കുക",
    },
    // ?ref=blog-ad mirrors BlogPostCTA's ?ref=blog so the two placements can
    // be compared; without it every click from this card was unattributed.
    href: `${APP_LINKS_URL}?ref=blog-ad`,
    gradient: "from-indigo-500 to-violet-500",
    tagLabel: "Disciplefy",
  },
];
