// Landing page for a shared study guide, served at
// go.disciplefy.in/study-guide/<guideId> (see middleware.ts).
//
// A study guide belongs to the person who generated it and is only readable
// through the app, so this page shows no content — just what was shared and
// how to open it. Without it, the link 404'd for anyone without the app.
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { OpenInApp } from "@/components/go/OpenInApp";
import { Wordmark } from "@/components/go/Wordmark";
import { APP_STORE_ID, WEB_APP_URL } from "@/lib/app-links";

type Params = { guideId: string };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function appUrlFor(guideId: string): string {
  return `${WEB_APP_URL}/study-guide/${guideId}`;
}

const TITLE = "A study guide shared with you";
const DESCRIPTION =
  "Open this Bible study guide in Disciplefy — summary, context, interpretation and reflection questions.";

export async function generateMetadata(
  { params }: { params: Promise<Params> },
): Promise<Metadata> {
  const { guideId } = await params;
  return {
    title: TITLE,
    description: DESCRIPTION,
    robots: { index: false, follow: false },
    openGraph: {
      title: TITLE,
      description: DESCRIPTION,
      images: [{ url: `/og-default.png` }],
    },
    twitter: { card: "summary_large_image", title: TITLE, description: DESCRIPTION },
    ...(UUID.test(guideId)
      ? { itunes: { appId: APP_STORE_ID, appArgument: appUrlFor(guideId) } }
      : {}),
  };
}

export default async function SharedStudyGuidePage(
  { params }: { params: Promise<Params> },
) {
  const { guideId } = await params;
  if (!UUID.test(guideId)) notFound();

  return (
    <main className="min-h-screen bg-[#0F172A] px-6 pb-44 pt-12 sm:pt-16">
      <div className="mx-auto w-full max-w-[34rem]">
        <Wordmark />

        <div className="mt-10 border-l-2 border-[#5B4FE9] pl-5 sm:pl-6">
          <p className="text-[13px] font-medium uppercase tracking-wide text-[#8B84F0]">
            Study guide
          </p>
          <h1 className="mt-2 text-[22px] font-semibold leading-snug text-[#E9EDF6] sm:text-[26px]">
            {TITLE}
          </h1>
          <p className="mt-3 text-[15.5px] leading-[1.6] text-[#94A2BD]">
            Open it in Disciplefy to read the summary, context, interpretation,
            related verses and reflection questions.
          </p>
        </div>

        <OpenInApp appUrl={appUrlFor(guideId)} />
      </div>
    </main>
  );
}
