// marketing/components/blog/PathsList.tsx
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { Link } from "@/lib/navigation";
import type { LearningPathMeta } from "@/lib/blog";

const PATHS_HERO: Record<string, {
  tagline: string;
  title: string;
  subtitle: string;
  article: string;
  articles: string;
  empty: string;
}> = {
  en: {
    tagline: "Disciplefy Blog",
    title: "Learning Paths",
    subtitle: "Structured study journeys. Pick a path to read every article in it, in order.",
    article: "article",
    articles: "articles",
    empty: "No learning paths yet. Check back soon.",
  },
  hi: {
    tagline: "Disciplefy ब्लॉग",
    title: "अध्ययन पथ",
    subtitle: "संरचित अध्ययन यात्राएं। किसी पथ को चुनें और उसके सभी लेख क्रम से पढ़ें।",
    article: "लेख",
    articles: "लेख",
    empty: "अभी कोई अध्ययन पथ नहीं। जल्द वापस देखें।",
  },
  ml: {
    tagline: "Disciplefy ബ്ലോഗ്",
    title: "പഠന പാതകൾ",
    subtitle: "ക്രമീകൃത പഠന യാത്രകൾ. ഒരു പാത തിരഞ്ഞെടുത്ത് അതിലെ എല്ലാ ലേഖനങ്ങളും ക്രമത്തിൽ വായിക്കൂ.",
    article: "ലേഖനം",
    articles: "ലേഖനങ്ങൾ",
    empty: "ഇതുവരെ പഠന പാതകളൊന്നുമില്ല. ഉടൻ തിരിച്ചുവരൂ.",
  },
};

const GRADIENTS = [
  "from-primary to-violet-500",
  "from-emerald-500 to-teal-500",
  "from-amber-500 to-orange-500",
  "from-sky-500 to-indigo-500",
  "from-rose-500 to-pink-500",
  "from-fuchsia-500 to-purple-500",
];

export function PathsList({
  paths,
  locale,
}: {
  paths: LearningPathMeta[];
  locale: string;
}) {
  const t = PATHS_HERO[locale] ?? PATHS_HERO.en;
  const visible = (paths ?? []).filter((p) => p.post_count > 0);

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

        {/* Paths grid */}
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          {visible.length === 0 ? (
            <div className="text-center py-20">
              <p className="text-[var(--muted)] text-lg">{t.empty}</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {visible.map((path, i) => (
                <Link
                  key={path.slug}
                  href={{ pathname: "/blog", query: { learning_path: path.slug } }}
                  className="group flex flex-col rounded-2xl bg-[var(--surface)] border border-[var(--border)] overflow-hidden hover:border-primary/40 hover:shadow-lg transition-all"
                >
                  <div
                    className={`h-1.5 w-full bg-gradient-to-r ${GRADIENTS[i % GRADIENTS.length]}`}
                  />
                  <div className="flex flex-col flex-1 p-6">
                    <h2 className="font-display font-bold text-xl mb-3 text-[var(--text)] group-hover:text-primary transition-colors">
                      {path.title}
                    </h2>
                    <span className="mt-auto inline-flex items-center text-sm font-medium text-[var(--muted)]">
                      {path.post_count}{" "}
                      {path.post_count === 1 ? t.article : t.articles}
                      <span className="ml-2 transition-transform group-hover:translate-x-1">
                        →
                      </span>
                    </span>
                  </div>
                </Link>
              ))}
            </div>
          )}
        </section>
      </main>
      <Footer />
    </>
  );
}
