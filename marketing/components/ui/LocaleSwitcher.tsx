// marketing/components/ui/LocaleSwitcher.tsx
"use client";
import { useLocale } from "next-intl";
import { usePathname, useRouter } from "@/lib/navigation"; // locale-aware hooks
import { locales, type Locale } from "@/i18n";

const labels: Record<Locale, string> = { en: "EN", hi: "हि", ml: "മ" };

export function LocaleSwitcher() {
  const locale = useLocale() as Locale;
  const router = useRouter();
  const pathname = usePathname();

  function switchLocale(next: Locale) {
    // Defensively strip any locale prefix that usePathname() may have returned
    // (guards against /hi/hi double-prefix bug when already on a locale page)
    let cleanPath = pathname;
    for (const loc of locales) {
      if (cleanPath === `/${loc}`) { cleanPath = "/"; break; }
      if (cleanPath.startsWith(`/${loc}/`)) { cleanPath = cleanPath.slice(`/${loc}`.length); break; }
    }
    router.replace(cleanPath, { locale: next });
    localStorage.setItem("disciplefy-locale", next);
  }

  return (
    <div className="flex items-center gap-1">
      {locales.map((l) => (
        <button
          key={l}
          onClick={() => switchLocale(l as Locale)}
          className={`px-2 py-1 rounded-md text-xs font-semibold transition-colors ${
            locale === l
              ? "bg-primary text-white"
              : "text-[var(--muted)] hover:text-[var(--text)]"
          }`}
        >
          {labels[l as Locale]}
        </button>
      ))}
    </div>
  );
}
