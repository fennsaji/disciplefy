// marketing/components/blog/AdSlot.tsx
// Renders the card inserted by insertAd() (lib/insertAd.ts). Server
// component — no client JS, fixed height, no CLS. Looks up id in ADS;
// silently renders nothing if the id no longer exists (e.g. config edited
// after a page was cached under ISR) rather than showing a broken ad.
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
        width={36}
        height={36}
        className="h-9 w-9 flex-shrink-0 rounded-lg"
      />
    );
  }
  return (
    <div
      aria-hidden="true"
      className={`h-9 w-9 flex-shrink-0 rounded-lg bg-gradient-to-br ${gradient}`}
    />
  );
}

// `locale` arrives from insertAd()'s marker as a plain string attribute
// (MDX doesn't type-check JSX attribute values) — fall back to "en" for
// anything unrecognized rather than crashing the page.
function resolveLocale(locale?: string): AdLocale {
  return locale === "hi" || locale === "ml" ? locale : "en";
}

export function AdSlot({ id, locale }: { id: string; locale?: string }) {
  const ad = ADS.find((a) => a.id === id);
  if (!ad) return null;
  const adLocale = resolveLocale(locale);

  return (
    <div className="not-prose flex items-center gap-3 rounded-xl border border-[var(--border)] bg-[var(--surface)] px-4 py-3 my-6">
      <AdIcon isHouseAd={ad.tagLabel === "Disciplefy"} gradient={ad.gradient} />
      <div className="min-w-0 flex-1">
        <a
          href={ad.href}
          rel={ad.tagLabel ? "noopener noreferrer" : "sponsored noopener noreferrer"}
          target="_blank"
          className="block text-sm font-semibold text-[var(--text)] hover:text-primary dark:hover:text-indigo-300 transition-colors truncate"
        >
          {ad.title[adLocale]}
        </a>
        <p className="text-xs text-[var(--muted)] truncate">{ad.subtitle[adLocale]}</p>
      </div>
      <span className="flex-shrink-0 text-[10px] uppercase tracking-wide text-[var(--muted)] border border-[var(--border)] px-2 py-0.5 rounded-full">
        {ad.tagLabel ?? "Sponsored"}
      </span>
    </div>
  );
}
