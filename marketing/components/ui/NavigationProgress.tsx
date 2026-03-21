"use client";
// marketing/components/ui/NavigationProgress.tsx
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";

export function NavigationProgress() {
  const pathname = usePathname();
  const [state, setState] = useState<"idle" | "loading" | "done">("idle");
  const timerRef = useRef<ReturnType<typeof setTimeout>>();

  // Navigation completed — finish the bar then fade out
  useEffect(() => {
    if (state === "loading") {
      setState("done");
      timerRef.current = setTimeout(() => setState("idle"), 500);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pathname]);

  // Detect internal link clicks to start the bar
  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      const anchor = (e.target as HTMLElement).closest("a[href]");
      if (!anchor) return;
      const href = anchor.getAttribute("href") ?? "";
      if (
        href.startsWith("#") ||
        href.startsWith("mailto:") ||
        href.startsWith("tel:") ||
        /^https?:\/\//.test(href)
      )
        return;
      clearTimeout(timerRef.current);
      setState("loading");
    };
    document.addEventListener("click", handleClick);
    return () => document.removeEventListener("click", handleClick);
  }, []);

  if (state === "idle") return null;

  return (
    <div className="fixed top-0 left-0 right-0 z-[9999] h-[2px] pointer-events-none">
      <div
        className="h-full bg-indigo-500"
        style={{
          width: state === "done" ? "100%" : "70%",
          opacity: state === "done" ? 0 : 1,
          transition:
            state === "done"
              ? "width 150ms ease, opacity 400ms ease 100ms"
              : "width 8000ms cubic-bezier(0.1, 0.05, 0, 1)",
        }}
      />
    </div>
  );
}
