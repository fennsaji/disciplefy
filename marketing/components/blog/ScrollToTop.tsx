"use client";
// marketing/components/blog/ScrollToTop.tsx
import { useEffect, useState } from "react";

export function ScrollToTop({ label }: { label: string }) {
  const [show, setShow] = useState(false);

  useEffect(() => {
    let raf = 0;
    const onScroll = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => setShow(window.scrollY > 800));
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    return () => {
      window.removeEventListener("scroll", onScroll);
      cancelAnimationFrame(raf);
    };
  }, []);

  const toTop = () => {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    window.scrollTo({ top: 0, behavior: reduce ? "auto" : "smooth" });
  };

  return (
    <button
      type="button"
      onClick={toTop}
      aria-label={label}
      className={`fixed bottom-6 right-6 z-40 inline-flex h-11 w-11 items-center justify-center rounded-full bg-primary text-white shadow-lg transition-all duration-200 hover:bg-primary/90 ${
        show ? "opacity-100 translate-y-0" : "opacity-0 translate-y-2 pointer-events-none"
      }`}
    >
      <svg aria-hidden="true" className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 15.75 12 8.25l7.5 7.5" />
      </svg>
    </button>
  );
}
