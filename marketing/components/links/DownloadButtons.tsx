// marketing/components/links/DownloadButtons.tsx
// The get-the-app block: the visitor's own store as one glowing gold button,
// the other two options beneath it, and on desktop a QR code for the phone.
import Image from "next/image";
import { DeviceSlots } from "@/components/links/DeviceSlots";
import { DOWNLOAD_QR_SRC, FOCUS_RING, linkProps } from "@/components/links/link-data";

export function DownloadButtons() {
  return (
    <DeviceSlots>
      {({ platform, primary, secondary }) => (
        <div className="flex w-full flex-col items-center">
          <a
            {...linkProps(primary.href)}
            aria-label={primary.label}
            className={`flex min-h-[64px] w-full items-center justify-center gap-3 rounded-full bg-gradient-to-b from-[#F6CF76] to-[#D4930A] px-6 text-[#1F1503] shadow-[0_0_0_1px_rgba(243,199,102,0.5),0_14px_40px_-8px_rgba(212,147,10,0.6)] transition-transform active:scale-[0.99] ${FOCUS_RING}`}
          >
            <primary.Icon className="h-7 w-7 shrink-0" />
            <span className="flex flex-col text-left leading-tight">
              <span className="text-[12px] font-medium">{primary.kicker}</span>
              <span className="font-display text-[19px] font-bold">{primary.name}</span>
            </span>
          </a>

          <p className="mt-5 text-[13px] text-[color:var(--muted)]">Also available</p>
          <div className="mt-2 flex w-full gap-2.5">
            {secondary.map((s) => (
              <a
                key={s.id}
                {...linkProps(s.href)}
                aria-label={s.label}
                className={`flex min-h-[48px] flex-1 items-center justify-center gap-2 rounded-full border border-[color:var(--line)] bg-[color:var(--glass)] px-3 text-[14px] font-semibold backdrop-blur-sm transition-colors hover:border-[#D4930A] ${FOCUS_RING}`}
              >
                <s.Icon className="h-[17px] w-[17px] text-[color:var(--gold-ink)]" />
                {s.name}
              </a>
            ))}
          </div>

          {platform === "other" && (
            <div className="mt-6 hidden flex-col items-center gap-3 md:flex">
              <Image
                src={DOWNLOAD_QR_SRC}
                alt=""
                width={120}
                height={120}
                unoptimized
                className="h-[120px] w-[120px] rounded-xl p-1 ring-1 ring-[color:var(--line)]"
              />
              <p className="text-[13px] text-[color:var(--muted)]">Scan with your phone to get the app</p>
            </div>
          )}
        </div>
      )}
    </DeviceSlots>
  );
}
