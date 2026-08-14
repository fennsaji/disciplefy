// marketing/components/blog/AdSlot.tsx
// Renders the card inserted by insertAd() (lib/insertAd.ts). Server
// component — no client JS, fixed height, no CLS. Looks up id in ADS;
// silently renders nothing if the id no longer exists (e.g. config edited
// after a page was cached under ISR) rather than showing a broken ad.
import { ADS } from "@/lib/ads";

export function AdSlot({ id }: { id: string }) {
  const ad = ADS.find((a) => a.id === id);
  if (!ad) return null;

  return (
    <div className="not-prose flex items-center gap-3 rounded-xl border border-[var(--border)] bg-[var(--surface)] px-4 py-3 my-6">
      <div
        aria-hidden="true"
        className={`h-9 w-9 flex-shrink-0 rounded-lg bg-gradient-to-br ${ad.gradient}`}
      />
      <div className="min-w-0 flex-1">
        <a
          href={ad.href}
          rel={ad.tagLabel ? "noopener noreferrer" : "sponsored noopener noreferrer"}
          target="_blank"
          className="block text-sm font-semibold text-[var(--text)] hover:text-primary dark:hover:text-indigo-300 transition-colors truncate"
        >
          {ad.title}
        </a>
        <p className="text-xs text-[var(--muted)] truncate">{ad.subtitle}</p>
      </div>
      <span className="flex-shrink-0 text-[10px] uppercase tracking-wide text-[var(--muted)] border border-[var(--border)] px-2 py-0.5 rounded-full">
        {ad.tagLabel ?? "Sponsored"}
      </span>
    </div>
  );
}
