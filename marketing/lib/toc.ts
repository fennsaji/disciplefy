// marketing/lib/toc.ts
// Extracts a table of contents from markdown. Slugs are generated with
// github-slugger so they match the IDs produced by rehype-slug on the rendered
// headings (used for anchor links and scroll-spy).
import GithubSlugger from "github-slugger";

export interface TocItem {
  id: string;
  text: string;
  level: 2 | 3;
}

/** Pull h2/h3 headings from markdown, skipping fenced code blocks. */
export function extractToc(markdown: string): TocItem[] {
  if (!markdown) return [];
  const slugger = new GithubSlugger();
  const items: TocItem[] = [];
  let inFence = false;

  for (const raw of markdown.split("\n")) {
    const line = raw.trimEnd();
    if (/^\s*(```|~~~)/.test(line)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;

    const m = /^(#{2,3})\s+(.+?)\s*#*$/.exec(line);
    if (!m) continue;

    const level = m[1].length as 2 | 3;
    // Strip common inline markdown so the visible text matches rehype-slug input.
    const text = m[2]
      .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1") // links → text
      .replace(/[*_`~]/g, "")
      .trim();
    if (!text) continue;

    items.push({ id: slugger.slug(text), text, level });
  }
  return items;
}
