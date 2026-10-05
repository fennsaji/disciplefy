// marketing/components/links/SocialIcons.tsx
// The social channels as a single row of round icon buttons with captions.
import { FOCUS_RING, FOLLOW_LINKS, linkProps } from "@/components/links/link-data";

export function SocialIcons() {
  return (
    <ul className="grid w-full grid-cols-5 gap-1">
      {FOLLOW_LINKS.map((l) => (
        <li key={l.label}>
          <a
            {...linkProps(l.href)}
            aria-label={l.label}
            className={`group flex flex-col items-center gap-2 rounded-xl py-1 ${FOCUS_RING}`}
          >
            <span className="flex h-[52px] w-[52px] items-center justify-center rounded-full border border-[color:var(--line)] bg-[color:var(--glass)] transition-colors group-hover:border-[#D4930A]">
              <l.Icon className="h-[22px] w-[22px]" />
            </span>
            <span className="text-[11.5px] leading-tight text-[color:var(--muted)]">{l.caption}</span>
          </a>
        </li>
      ))}
    </ul>
  );
}
