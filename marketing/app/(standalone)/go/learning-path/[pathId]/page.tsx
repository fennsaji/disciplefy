// Landing page for a shared learning path, served at
// go.disciplefy.in/learning-path/<pathId> (see middleware.ts).
//
// Learning paths are curated public content, not user-generated, so unlike
// the fellowship post page there is no private variant to guard — a
// not-found path is the only alternative to a full preview.
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { OpenInApp } from "@/components/go/OpenInApp";
import { Wordmark } from "@/components/go/Wordmark";
import { APP_STORE_ID, WEB_APP_URL } from "@/lib/app-links";
import { fetchLearningPathPreview } from "@/lib/learning-path-preview";

type Params = { pathId: string };

function appUrlFor({ pathId }: Params): string {
  return `${WEB_APP_URL}/learning-path/${pathId}?source=share`;
}

export async function generateMetadata(
  { params }: { params: Promise<Params> },
): Promise<Metadata> {
  const { pathId } = await params;
  const preview = await fetchLearningPathPreview(pathId);

  if (!preview.found) {
    return {
      title: "A learning path on Disciplefy",
      robots: { index: false, follow: false },
    };
  }

  const title = preview.title ?? "A guided Bible study path on Disciplefy";
  const description =
    preview.description ?? "Open Disciplefy to follow this study path.";

  return {
    title,
    description,
    alternates: { canonical: appUrlFor({ pathId }) },
    openGraph: {
      title,
      description,
      images: [{ url: `/og?title=${encodeURIComponent(title)}` }],
    },
    twitter: { card: "summary_large_image", title, description },
    // Carries the deep link, so tapping OPEN lands on this path.
    itunes: { appId: APP_STORE_ID, appArgument: appUrlFor({ pathId }) },
  };
}

export default async function SharedLearningPathPage(
  { params }: { params: Promise<Params> },
) {
  const { pathId } = await params;
  const preview = await fetchLearningPathPreview(pathId);
  const appUrl = appUrlFor({ pathId });

  if (!preview.found) notFound();

  return (
    <main className="min-h-screen bg-[#0F172A] px-6 pb-44 pt-12 sm:pt-16">
      <div className="mx-auto w-full max-w-[34rem]">
        <Wordmark />

        <div className="mt-10 border-l-2 border-[#5B4FE9] pl-5 sm:pl-6">
          <p className="text-[13px] font-medium uppercase tracking-wide text-[#8B84F0]">
            Learning path
          </p>
          <h1 className="mt-2 text-[22px] font-semibold leading-snug text-[#E9EDF6] sm:text-[26px]">
            {preview.title}
          </h1>
          {preview.description && (
            <p className="mt-3 text-[15.5px] leading-[1.6] text-[#94A2BD]">
              {preview.description}
            </p>
          )}
          {typeof preview.topics_count === "number" && preview.topics_count > 0 && (
            <p className="mt-4 text-[13.5px] text-[#A6B3CC]">
              {preview.topics_count} {preview.topics_count === 1 ? "study" : "studies"}
              {preview.disciple_level ? ` · ${preview.disciple_level}` : ""}
            </p>
          )}
        </div>

        <OpenInApp appUrl={appUrl} />
      </div>
    </main>
  );
}
