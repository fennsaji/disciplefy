// marketing/components/links/LinkRow.tsx
import type { ReactNode } from "react";

type LinkRowProps = {
  label: string;
  icon: ReactNode;
  /** Tailwind classes for the icon chip background. */
  chipClass: string;
  /** Omit to render a disabled, non-interactive row. */
  href?: string;
  variant?: "default" | "primary";
  /** Small pill on the right, e.g. "SOON". Rendered whenever truthy, regardless of href. */
  badge?: string;
};

const BASE =
  "flex items-center gap-3 rounded-2xl px-3.5 py-3 text-sm font-semibold tracking-tight";

const CHIP = "flex h-8 w-8 shrink-0 items-center justify-center rounded-[10px]";

export function LinkRow({ label, icon, chipClass, href, variant = "default", badge }: LinkRowProps) {
  const isPrimary = variant === "primary";

  const surface = isPrimary
    ? "bg-gradient-to-br from-[#D4930A] to-[#B87C05] text-white shadow-[0_6px_18px_rgba(212,147,10,0.38)] py-3.5 text-[15px] font-bold"
    : "bg-[#1E293B] border border-white/10 text-slate-100";

  const body = (
    <>
      <span className={`${CHIP} ${chipClass}`}>{icon}</span>
      <span>{label}</span>
      {badge ? (
        <span className="ml-auto rounded-full bg-white/[0.13] px-1.5 py-0.5 text-[9px] font-extrabold tracking-widest">
          {badge}
        </span>
      ) : (
        <span className={`ml-auto text-base font-normal ${isPrimary ? "opacity-70" : "opacity-30"}`} aria-hidden="true">
          ›
        </span>
      )}
    </>
  );

  if (!href) {
    return (
      <div className={`${BASE} ${surface} opacity-40`} aria-disabled="true">
        {body}
      </div>
    );
  }

  const isExternal = href.startsWith("http");

  return (
    <a
      href={href}
      {...(isExternal ? { target: "_blank", rel: "noopener noreferrer" } : {})}
      className={`${BASE} ${surface} transition-transform hover:scale-[1.02] active:scale-[0.99]`}
    >
      {body}
    </a>
  );
}
