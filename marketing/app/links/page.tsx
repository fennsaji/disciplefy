// marketing/app/links/page.tsx
// Link-in-bio page. Served at links.disciplefy.in (see middleware.ts) and /links.
// Dark only by design: uses explicit colours, never `dark:` variants, so the
// visitor's stored theme preference cannot change it.
import type { Metadata } from "next";
import Image from "next/image";
import { LinkRow } from "@/components/links/LinkRow";
import { AndroidIcon, AppleIcon, GlobeIcon, MailIcon } from "@/components/links/PlatformIcons";
import { APP_STORE_URL, PLAY_STORE_URL, WEB_APP_URL } from "@/lib/app-links";
import { SOCIAL } from "@/lib/social-links";

export const metadata: Metadata = {
  title: "Disciplefy — All Links",
  description: "Download the Disciplefy app, follow along, or get in touch.",
  alternates: { canonical: "https://links.disciplefy.in/" },
};

const SECTION_LABEL = "mb-2.5 ml-1 mt-5 text-[10px] font-extrabold uppercase tracking-[0.11em] text-[#94A3B8]";

const SOCIAL_ROWS: Array<(typeof SOCIAL)[keyof typeof SOCIAL] & { chipClass: string; displayLabel?: string }> = [
  { ...SOCIAL.instagram, chipClass: "bg-gradient-to-br from-[#FEDA75] via-[#D62976] to-[#4F5BD5] text-white" },
  { ...SOCIAL.youtube, chipClass: "bg-[#FF0000] text-white" },
  { ...SOCIAL.whatsapp, chipClass: "bg-[#25D366] text-white", displayLabel: "WhatsApp Community" },
  { ...SOCIAL.facebook, chipClass: "bg-[#1877F2] text-white" },
];

const GOLD_CHIP = "bg-[#D4930A]/20 text-[#F3C766]";

export default function LinksPage() {
  return (
    <main className="min-h-screen bg-[#0F172A] px-5 py-9">
      <div className="mx-auto w-full max-w-[360px]">
        <Image
          src="/logo-dark.png"
          alt="Disciplefy"
          width={156}
          height={36}
          priority
          className="mx-auto mb-4 h-9 w-auto"
        />
        <p className="mb-6 text-center text-[13px] leading-relaxed text-[#94A3B8]">
          AI-powered Bible study guides
          <br />
          English · हिन्दी · മലയാളം
        </p>

        <p className={SECTION_LABEL}>Get the app</p>
        <div className="flex flex-col gap-2.5">
          <LinkRow
            label="Download for Android"
            href={PLAY_STORE_URL}
            variant="primary"
            chipClass="bg-white/20 text-white"
            icon={<AndroidIcon className="h-[17px] w-[17px]" />}
          />
          <LinkRow
            label="Download for iOS"
            href={APP_STORE_URL ?? undefined}
            badge={APP_STORE_URL ? undefined : "SOON"}
            chipClass="bg-white text-[#111]"
            icon={<AppleIcon className="h-[17px] w-[17px]" />}
          />
          <LinkRow
            label="Use in your browser"
            href={WEB_APP_URL}
            chipClass={GOLD_CHIP}
            icon={<GlobeIcon className="h-[17px] w-[17px]" />}
          />
        </div>

        <p className={SECTION_LABEL}>Follow along</p>
        <div className="flex flex-col gap-2.5">
          {SOCIAL_ROWS.map((s) => (
            <LinkRow
              key={s.label}
              label={s.displayLabel ?? s.label}
              href={s.href}
              chipClass={s.chipClass}
              icon={<s.Icon className="h-[17px] w-[17px]" />}
            />
          ))}
        </div>

        <p className={SECTION_LABEL}>Say hello</p>
        <LinkRow
          label="hello@disciplefy.in"
          href="mailto:hello@disciplefy.in"
          chipClass={GOLD_CHIP}
          icon={<MailIcon className="h-[17px] w-[17px]" />}
        />

        <p className="mt-6 border-t border-white/10 pt-4 text-center text-[11px] text-[#94A3B8]">
          <a href="https://www.disciplefy.in" className="hover:text-slate-300">
            disciplefy.in
          </a>
        </p>
      </div>
    </main>
  );
}
