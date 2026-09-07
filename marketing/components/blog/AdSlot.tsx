// marketing/components/blog/AdSlot.tsx
// Renders the card inserted by insertAd() (lib/insertAd.ts). Server
// component — no client JS, so it costs nothing at request time. Looks up id
// in ADS; silently renders nothing if the id no longer exists (e.g. config
// edited after a page was cached under ISR) rather than showing a broken ad.
import Image from "next/image";
import { ADS, type AdLocale } from "@/lib/ads";

// House (self-promo) ads carry the Disciplefy tagLabel — show the app icon
// mark for those instead of a generic gradient swatch, which is reserved
// for actual third-party sponsors that don't have a Disciplefy asset.
function AdIcon({ isHouseAd, gradient }: { isHouseAd: boolean; gradient: string }) {
  if (isHouseAd) {
    return (
      <Image
        src="/app-icon.png"
        alt=""
        width={44}
        height={44}
        className="h-10 w-10 flex-shrink-0 rounded-xl sm:h-11 sm:w-11"
      />
    );
  }
  return (
    <div
      aria-hidden="true"
      className={`h-10 w-10 flex-shrink-0 rounded-xl bg-gradient-to-br sm:h-11 sm:w-11 ${gradient}`}
    />
  );
}

// `locale` arrives from insertAd()'s marker as a plain string attribute
// (MDX doesn't type-check JSX attribute values) — fall back to "en" for
// anything unrecognized rather than crashing the page.
function resolveLocale(locale?: string): AdLocale {
  return locale === "hi" || locale === "ml" ? locale : "en";
}

const DEVANAGARI = /[\u0900-\u097F]/;
const MALAYALAM = /[\u0D00-\u0D7F]/;

// Tags arrive from the blog API in English whatever the post's language, and
// "Bible study पर और गहराई से जानें" reads as a translation someone forgot to
// finish. So the contextual headline is only used when the tag is written in
// the reader's own script — if localized tags appear later, this starts
// working for Hindi and Malayalam on its own with no code change.
function topicMatchesLocale(topic: string, adLocale: AdLocale): boolean {
  if (adLocale === "hi") return DEVANAGARI.test(topic);
  if (adLocale === "ml") return MALAYALAM.test(topic);
  return !DEVANAGARI.test(topic) && !MALAYALAM.test(topic);
}

export function AdSlot({
  id,
  locale,
  topic,
}: {
  id: string;
  locale?: string;
  topic?: string;
}) {
  const ad = ADS.find((a) => a.id === id);
  if (!ad) return null;
  const adLocale = resolveLocale(locale);

  // Lead with the reader's own subject when the post has a usable tag; the
  // generic headline is the fallback so a post without tags — or with a tag
  // in the wrong script — never shows a half-translated sentence.
  const headline =
    topic && ad.titleWithTopic && topicMatchesLocale(topic, adLocale)
      ? ad.titleWithTopic[adLocale].replace("{topic}", topic)
      : ad.title[adLocale];

  // The whole card is the link, not just the title: on a phone the title is
  // one short line and the rest of the card looked tappable but did nothing.
  //
  // Layout is two bands rather than one text column hanging off the icon.
  // The copy is three clauses long and Hindi/Malayalam run longer still, so
  // indenting it past a 44px icon cost ~56px of measure — two extra lines on
  // a 390px phone. Identity (icon, badge, headline) sits in the header band;
  // the sentence and the action get the card's full width underneath.
  return (
    <a
      href={ad.href}
      rel={ad.tagLabel ? "noopener noreferrer" : "sponsored noopener noreferrer"}
      target="_blank"
      className="not-prose group my-8 block rounded-2xl border border-primary/25 bg-primary/[0.06] px-4 py-4 no-underline transition-colors hover:border-primary/50 hover:bg-primary/[0.09] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary sm:px-5 sm:py-5 dark:border-indigo-400/25 dark:bg-indigo-400/[0.07] dark:hover:border-indigo-400/50 dark:hover:bg-indigo-400/[0.11]"
    >
      <div className="flex items-center gap-3">
        <AdIcon isHouseAd={ad.tagLabel === "Disciplefy"} gradient={ad.gradient} />

        <div className="min-w-0 flex-1">
          {/* Badge as an eyebrow, not a right-aligned pill: at 390px a pill in
              the headline row squeezed the Hindi and Malayalam headlines into
              three lines. Kept honest — "Disciplefy", never "Sponsored", for
              a house ad. */}
          <span className="block text-[10px] font-semibold uppercase tracking-[0.08em] text-[var(--muted)]">
            {ad.tagLabel ?? "Sponsored"}
          </span>
          {/* No truncation: the sentence is the pitch, and Hindi and Malayalam
              run longer than English, so clipping cost the most where it
              mattered most. */}
          <span className="block text-[15px] font-semibold leading-[1.35] text-[var(--text)]">
            {headline}
          </span>
        </div>
      </div>

      {/* Deliberately small and quiet — this interrupts someone reading
          Scripture. Generous leading keeps Malayalam's tall glyphs and stacked
          conjuncts from crowding; max-w keeps the desktop measure readable
          instead of running the full 68ch column. */}
      <span className="mt-3 block max-w-[58ch] text-[13px] leading-[1.75] text-[var(--muted)]">
        {ad.subtitle[adLocale]}
      </span>

      {/* A soft pill rather than a bare text link: under three lines of body
          copy the plain arrow stopped reading as the thing to tap. Filled
          would read as a banner; a tinted outline reads as an affordance. */}
      <span className="mt-3.5 inline-flex items-center gap-1.5 rounded-full border border-primary/30 bg-primary/10 px-3.5 py-1.5 text-[13px] font-semibold leading-[1.4] text-primary transition-colors group-hover:border-primary/50 group-hover:bg-primary/15 dark:border-indigo-400/35 dark:bg-indigo-400/10 dark:text-indigo-300 dark:group-hover:border-indigo-400/60 dark:group-hover:bg-indigo-400/20">
        {ad.ctaLabel[adLocale]}
        <svg
          aria-hidden="true"
          viewBox="0 0 16 16"
          className="h-3.5 w-3.5 flex-shrink-0 transition-transform group-hover:translate-x-0.5"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M6 3l5 5-5 5" />
        </svg>
      </span>
    </a>
  );
}
