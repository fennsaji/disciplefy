// Shown for any go.disciplefy.in link that resolves to nothing: a deleted
// post, a truncated link, a mistyped id. The bare Next 404 gave no way
// forward, which is a poor end for a link someone was sent by a friend.
import Link from "next/link";
import { APP_LINKS_URL, WEB_APP_URL } from "@/lib/app-links";

export default function GoNotFound() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-[#0F172A] px-5 py-10">
      <div className="w-full max-w-[380px]">
        <div className="mb-6 rounded-2xl border border-[#1E293B] bg-[#111C33] p-5">
          <h1 className="mb-2 text-lg font-bold text-[#E2E8F0]">
            This link has expired or moved
          </h1>
          <p className="text-sm leading-relaxed text-[#CBD5E1]">
            The post may have been deleted, or the link may have been cut short
            when it was shared.
          </p>
        </div>

        <div className="flex flex-col gap-3">
          <Link
            href={WEB_APP_URL}
            className="flex h-12 items-center justify-center rounded-xl bg-[#5B4FE9] px-5 text-sm font-semibold text-white transition-colors hover:bg-[#4C41D4]"
          >
            Open Disciplefy
          </Link>
          <Link
            href={APP_LINKS_URL}
            className="flex h-12 items-center justify-center rounded-xl border border-[#334155] px-5 text-sm font-semibold text-[#E2E8F0] transition-colors hover:bg-[#1E293B]"
          >
            Get the app
          </Link>
        </div>
      </div>
    </main>
  );
}
