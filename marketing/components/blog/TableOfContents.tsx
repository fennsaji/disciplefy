"use client";
// marketing/components/blog/TableOfContents.tsx
import { useEffect, useState } from "react";
import type { TocItem } from "@/lib/toc";

export function TableOfContents({
  items,
  label,
}: {
  items: TocItem[];
  label: string;
}) {
  const [active, setActive] = useState<string>("");

  useEffect(() => {
    const headings = items
      .map((i) => document.getElementById(i.id))
      .filter((el): el is HTMLElement => el !== null);
    if (headings.length === 0) return;

    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);
        if (visible[0]) setActive(visible[0].target.id);
      },
      // Trigger when a heading is near the top of the viewport.
      { rootMargin: "-80px 0px -70% 0px", threshold: 0 },
    );
    headings.forEach((h) => observer.observe(h));
    return () => observer.disconnect();
  }, [items]);

  return (
    <nav aria-label={label} className="text-sm">
      <p className="font-semibold text-[var(--text)] mb-3">{label}</p>
      <ul className="space-y-1.5">
        {items.map((item) => {
          const isActive = active === item.id;
          return (
            <li key={item.id} className={item.level === 3 ? "pl-3" : ""}>
              <a
                href={`#${item.id}`}
                onClick={() => setActive(item.id)}
                className={`block border-l-2 py-0.5 pl-3 -ml-px transition-colors ${
                  isActive
                    ? "border-primary text-primary font-medium"
                    : "border-transparent text-[var(--muted)] hover:text-[var(--text)] hover:border-[var(--border)]"
                }`}
              >
                {item.text}
              </a>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
