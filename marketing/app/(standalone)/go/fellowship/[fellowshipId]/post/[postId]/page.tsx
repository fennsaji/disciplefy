// Landing page for a shared fellowship post, served at
// go.disciplefy.in/fellowship/<id>/post/<id> (see middleware.ts).
//
// Shared links used to point at the Flutter web app, which renders
// client-side: chat apps found no Open Graph tags, so the link had no preview
// card, and their in-app browsers never hand a URL to the installed app. This
// page is server-rendered, so the card has real content, and it offers the app
// and the store before falling back to the browser.
//
// The post is the page. Someone was handed these words by a friend, so they
// are set as reading matter and the actions sit quietly underneath.
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { OpenInApp } from "@/components/go/OpenInApp";
import { Wordmark } from "@/components/go/Wordmark";
import { APP_STORE_ID, WEB_APP_URL } from "@/lib/app-links";
import { fetchSharePreview, postBlocks, previewSnippet } from "@/lib/share-preview";

type Params = { fellowshipId: string; postId: string };

// Posts are routinely Malayalam or Hindi, so the reading stack carries those
// faces rather than dropping to whatever the device happens to have.
const READING_STACK =
  "var(--font-inter), var(--font-noto-malayalam), var(--font-noto-devanagari), sans-serif";

function appUrlFor({ fellowshipId, postId }: Params): string {
  return `${WEB_APP_URL}/fellowship/${fellowshipId}/post/${postId}`;
}

export async function generateMetadata(
  { params }: { params: Promise<Params> },
): Promise<Metadata> {
  const { fellowshipId, postId } = await params;
  const preview = await fetchSharePreview(postId);

  // A private fellowship gets a deliberately contentless card. The preview is
  // fetched by every chat the link is forwarded to, so nothing about the post
  // may appear here.
  if (!preview.is_public) {
    return {
      title: "A post on Disciplefy",
      description: "Open Disciplefy to view this fellowship post.",
      robots: { index: false, follow: false },
      alternates: { canonical: appUrlFor({ fellowshipId, postId }) },
      // iOS shows OPEN when the app is installed and VIEW when it is not —
      // the one thing a web page cannot work out for itself.
      itunes: {
        appId: APP_STORE_ID,
        appArgument: appUrlFor({ fellowshipId, postId }),
      },
    };
  }

  const snippet = previewSnippet(preview.content ?? "");
  const title = `${preview.author_name} in ${preview.fellowship_name}`;
  return {
    title,
    description: snippet,
    alternates: { canonical: appUrlFor({ fellowshipId, postId }) },
    openGraph: {
      title,
      description: snippet,
      type: "article",
      images: [
        { url: `/og?title=${encodeURIComponent(previewSnippet(preview.content ?? "", 90))}` },
      ],
    },
    twitter: { card: "summary_large_image", title, description: snippet },
    // Carries the deep link, so tapping OPEN lands on this post.
    itunes: {
      appId: APP_STORE_ID,
      appArgument: appUrlFor({ fellowshipId, postId }),
    },
  };
}

export default async function SharedPostPage(
  { params }: { params: Promise<Params> },
) {
  const { fellowshipId, postId } = await params;
  const preview = await fetchSharePreview(postId);
  const appUrl = appUrlFor({ fellowshipId, postId });

  // Three outcomes, and they read differently: a public post to show, a
  // private one to explain, and a link that resolves to nothing.
  if (!preview.found) notFound();

  return (
    <main className="min-h-screen bg-[#0F172A] px-6 pb-44 pt-12 sm:pt-16">
      <div className="mx-auto w-full max-w-[34rem]">
        <Wordmark />

        {preview.is_public ? (
          <article className="mt-10">
            {/* The rule marks the borrowed words and stops where they do. */}
            <div
              className="flex flex-col gap-4 border-l-2 border-[#5B4FE9] pl-5 sm:pl-6"
              style={{ fontFamily: READING_STACK }}
            >
              {postBlocks(preview.content ?? "").map((block, index) => {
                if (block.kind === "topic") {
                  return (
                    <p key={index} className="text-[14px] text-[#94A2BD]">
                      {block.text}
                    </p>
                  );
                }
                if (block.kind === "scripture") {
                  return (
                    <p
                      key={index}
                      className="self-start rounded-md bg-[#5B4FE9]/15 px-2.5 py-1 text-[14px] font-medium text-[#B9B2FA]"
                    >
                      {block.text}
                    </p>
                  );
                }
                if (block.kind === "question") {
                  return (
                    <p
                      key={index}
                      className="border-t border-[#22304E] pt-4 text-[15.5px] leading-[1.6] text-[#C7D2E6]"
                    >
                      {block.text}
                    </p>
                  );
                }
                return (
                  <p
                    key={index}
                    className="whitespace-pre-wrap text-[16.5px] leading-[1.7] text-[#E9EDF6] sm:text-[18px]"
                  >
                    {block.text}
                  </p>
                );
              })}
            </div>
            <p className="mt-5 pl-5 text-[13.5px] leading-relaxed text-[#A6B3CC] sm:pl-6">
              {preview.author_name} wrote this in {preview.fellowship_name}
            </p>
          </article>
        ) : (
          <div className="mt-10">
            <div className="border-l-2 border-dashed border-[#2E3D5F] pl-5 sm:pl-6">
              <p className="text-[16.5px] leading-[1.7] text-[#E9EDF6] sm:text-[18px]">
                This post is kept inside a private fellowship.
              </p>
              <p className="mt-2 text-[14px] leading-relaxed text-[#94A2BD]">
                Members can read it in the app.
              </p>
            </div>
          </div>
        )}

        <OpenInApp appUrl={appUrl} />
      </div>
    </main>
  );
}
