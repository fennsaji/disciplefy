// marketing/components/blog/PathsList.tsx
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { PathsBrowser } from "@/components/blog/PathsBrowser";
import type { LearningPathMeta } from "@/lib/blog";

const PATHS_HERO: Record<string, {
  tagline: string;
  title: string;
  subtitle: string;
}> = {
  en: {
    tagline: "Disciplefy Blog",
    title: "Learning Paths",
    subtitle: "Structured study journeys. Pick a path to read every article in it, in order.",
  },
  hi: {
    tagline: "Disciplefy ब्लॉग",
    title: "अध्ययन पथ",
    subtitle: "संरचित अध्ययन यात्राएं। किसी पथ को चुनें और उसके सभी लेख क्रम से पढ़ें।",
  },
  ml: {
    tagline: "Disciplefy ബ്ലോഗ്",
    title: "പഠന പാതകൾ",
    subtitle: "ക്രമീകൃത പഠന യാത്രകൾ. ഒരു പാത തിരഞ്ഞെടുത്ത് അതിലെ എല്ലാ ലേഖനങ്ങളും ക്രമത്തിൽ വായിക്കൂ.",
  },
};

// Filter values carried in the URL, so a shared link opens the same view.
export type PathsFilters = {
  query?: string;
  category?: string;
  level?: string;
};

// Reads the filter query params. A repeated param arrives as an array; only
// the first value is used, since each filter holds one value.
export function readPathsFilters(searchParams?: {
  [key: string]: string | string[] | undefined;
}): PathsFilters {
  const first = (value: string | string[] | undefined) =>
    (Array.isArray(value) ? value[0] : value) ?? "";
  return {
    query: first(searchParams?.q),
    category: first(searchParams?.category),
    level: first(searchParams?.level),
  };
}

export function PathsList({
  paths,
  locale,
  filters,
}: {
  paths: LearningPathMeta[];
  locale: string;
  filters?: PathsFilters;
}) {
  const t = PATHS_HERO[locale] ?? PATHS_HERO.en;

  return (
    <>
      <Navbar />
      <main>
        {/* Hero */}
        <section className="relative border-b border-[var(--border)] bg-[var(--surface)]">
          <div className="absolute inset-0 bg-gradient-to-br from-primary/5 via-transparent to-violet-500/5 pointer-events-none" />
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-20 relative">
            <p className="text-xs font-semibold uppercase tracking-widest text-primary dark:text-indigo-300 mb-3">
              {t.tagline}
            </p>
            <h1 className="font-display font-extrabold text-4xl sm:text-5xl lg:text-6xl mb-4 bg-gradient-to-r from-[var(--text)] to-[var(--muted)] bg-clip-text text-transparent">
              {t.title}
            </h1>
            <p className="text-[var(--muted)] text-lg max-w-2xl break-words">
              {t.subtitle}
            </p>
          </div>
        </section>

        {/* Search, filters and the paths grid */}
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          <PathsBrowser
            paths={paths}
            locale={locale}
            initialQuery={filters?.query ?? ""}
            initialCategory={filters?.category ?? ""}
            initialLevel={filters?.level ?? ""}
          />
        </section>
      </main>
      <Footer />
    </>
  );
}
