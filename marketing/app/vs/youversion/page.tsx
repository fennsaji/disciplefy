// marketing/app/vs/youversion/page.tsx
// NOTE: Deploy this page only after Phase 3 authority-building (directory submissions)
// is complete. Set NEXT_PUBLIC_VS_PAGES_ENABLED=true to publish.
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getAlternates } from "@/lib/seo";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import Link from "next/link";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "Disciplefy vs YouVersion — Which Bible App Is Better?",
  description:
    "An honest comparison of Disciplefy and YouVersion. See which Bible study app works better for Indian Christians.",
  alternates: getAlternates("/vs/youversion"),
  openGraph: {
    images: [{
      url: `/og?title=Disciplefy+vs+YouVersion&subtitle=Which+Bible+App+Is+Better?`,
      width: 1200,
      height: 630,
      alt: "Disciplefy vs YouVersion comparison",
    }],
  },
};

const FEATURES = [
  { feature: "AI study guides", disciplefy: true, youversion: false },
  { feature: "Hindi support", disciplefy: true, youversion: false },
  { feature: "Malayalam support", disciplefy: true, youversion: false },
  { feature: "Daily verse", disciplefy: true, youversion: true },
  { feature: "Full Bible text", disciplefy: false, youversion: true },
  { feature: "Audio Bible", disciplefy: false, youversion: true },
  { feature: "Reading plans", disciplefy: true, youversion: true },
  { feature: "Fellowship groups", disciplefy: true, youversion: false },
  { feature: "Free tier", disciplefy: true, youversion: true },
  { feature: "Android app", disciplefy: true, youversion: true },
];

function ComparisonTable() {
  return (
    <div className="overflow-x-auto mb-12">
      <table className="w-full border-collapse text-sm">
        <thead>
          <tr className="border-b border-[var(--border)]">
            <th className="py-3 text-left font-semibold">Feature</th>
            <th className="py-3 text-center font-semibold text-primary">Disciplefy</th>
            <th className="py-3 text-center font-semibold text-[var(--muted)]">YouVersion</th>
          </tr>
        </thead>
        <tbody>
          {FEATURES.map((row) => (
            <tr key={row.feature} className="border-b border-[var(--border)]">
              <td className="py-3">{row.feature}</td>
              <td className="py-3 text-center text-primary">{row.disciplefy ? "✓" : "–"}</td>
              <td className="py-3 text-center text-[var(--muted)]">{row.youversion ? "✓" : "–"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default function VsYouversionPage() {
  if (process.env.NEXT_PUBLIC_VS_PAGES_ENABLED !== 'true') notFound();
  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <Navbar />
      <main className="max-w-3xl mx-auto px-6 sm:px-8 py-16">
        <h1 className="font-display font-extrabold text-4xl sm:text-5xl mb-4">
          Disciplefy vs YouVersion
        </h1>
        <p className="text-[var(--muted)] text-lg mb-10">
          Both are free Bible apps for Android. Here is an honest look at how they differ — and which one works better for Indian Christians who want to go deeper in their study.
        </p>

        <ComparisonTable />

        <section className="mb-12">
          <h2 className="font-display font-bold text-2xl mb-4">Who is Disciplefy for?</h2>
          <p className="text-[var(--muted)]">
            Disciplefy is built for Indian Christians who want to go deeper with AI-powered study guides in Hindi and Malayalam. The AI generates full study guides — context, interpretation, and application — for any verse or topic. YouVersion does not offer this.
          </p>
        </section>

        <section className="mb-12">
          <h2 className="font-display font-bold text-2xl mb-4">Who is YouVersion for?</h2>
          <p className="text-[var(--muted)]">
            YouVersion is excellent if you want the full Bible text, audio Bible, or a wide library of reading plans. It is one of the most downloaded apps in the world and is well-suited for a broad Bible reading habit.
          </p>
        </section>

        <Link
          href="/download"
          className="inline-flex items-center gap-2 bg-black text-white px-5 py-3 rounded-xl text-sm font-semibold hover:bg-gray-900 transition-colors"
        >
          Try Disciplefy Free →
        </Link>
      </main>
      <Footer />
    </NextIntlClientProvider>
  );
}
