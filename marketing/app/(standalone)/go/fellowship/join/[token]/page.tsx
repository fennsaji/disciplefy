// Landing page for a fellowship invite, served at
// go.disciplefy.in/fellowship/join/<token> (see middleware.ts).
//
// The token is never resolved here: an invite is an unguessable secret, and
// naming the fellowship in a preview card would leak it to every chat the
// link passes through. The page carries the reader into the app, which
// validates the token behind a sign-in.
import type { Metadata } from "next";
import { OpenInApp } from "@/components/go/OpenInApp";
import { Wordmark } from "@/components/go/Wordmark";
import { APP_STORE_ID, WEB_APP_URL } from "@/lib/app-links";

export const metadata: Metadata = {
  title: "An invitation to a Disciplefy fellowship",
  description: "Open Disciplefy to accept the invitation and join the group.",
  robots: { index: false, follow: false },
  // iOS shows OPEN when the app is installed and VIEW when it is not. No
  // app-argument here: the invite token is a secret and does not belong in a
  // banner other apps can read.
  itunes: { appId: APP_STORE_ID },
};

export default async function JoinFellowshipPage(
  { params }: { params: Promise<{ token: string }> },
) {
  const { token } = await params;

  return (
    <main className="min-h-screen bg-[#0F172A] px-6 pb-44 pt-12 sm:pt-16">
      <div className="mx-auto w-full max-w-[34rem]">
        <Wordmark />

        <div className="mt-10 border-l-2 border-[#5B4FE9] pl-5 sm:pl-6">
          <h1 className="text-[22px] font-semibold leading-snug text-[#E9EDF6]">
            You&apos;ve been invited to a fellowship
          </h1>
          <p className="mt-3 text-[15px] leading-[1.6] text-[#94A2BD]">
            A fellowship is a small group that studies the Bible together, a
            guide at a time. Open Disciplefy to accept — you&apos;ll sign in
            first, and the group is waiting on the other side.
          </p>
        </div>

        <OpenInApp appUrl={`${WEB_APP_URL}/fellowship/join/${token}`} />
      </div>
    </main>
  );
}
